//
//  MentionsView.swift
//  fedi-reader
//
//  Private mentions and direct messages feed
//

import SwiftUI

struct MentionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    private var privateMentions: [MastodonNotification] {
        guard let mentions = timelineService?.mentions else { return [] }
        return mentions.filter { notification in
            guard let status = notification.status else { return false }
            return status.visibility == .private || status.visibility == .direct
        }
    }
    
    private var conversations: [Conversation] {
        buildConversations(from: privateMentions)
    }
    
    var body: some View {
        Group {
            if !conversations.isEmpty {
                ConversationsListView(conversations: conversations)
            } else if timelineService?.isLoadingMentions == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Messages")
        .refreshable {
            await timelineService?.refreshMentions()
        }
        .task {
            await loadMentions()
        }
    }
    
    private func buildConversations(from mentions: [MastodonNotification]) -> [Conversation] {
        // Group mentions by account
        let groupedByAccount = Dictionary(grouping: mentions) { $0.account.id }
        
        return groupedByAccount.values.compactMap { notifications in
            guard let firstNotification = notifications.first,
                  firstNotification.status != nil else { return nil }
            
            // Sort by date (newest first for preview, but we'll reverse in detail view)
            let sortedNotifications = notifications.sorted { $0.createdAt > $1.createdAt }
            
            return Conversation(
                account: firstNotification.account,
                messages: sortedNotifications.map { ChatMessage(notification: $0) }
            )
        }
        .sorted { $0.lastMessageDate > $1.lastMessageDate }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message")
        } description: {
            Text("Private mentions and direct messages will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await timelineService?.refreshMentions()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func loadMentions() async {
        if timelineService?.mentions.isEmpty == true {
            await timelineService?.refreshMentions()
        }
    }
}

// MARK: - Conversation

struct Conversation: Identifiable {
    let id: String
    let account: MastodonAccount
    let messages: [ChatMessage]
    
    var lastMessage: ChatMessage? {
        messages.first
    }
    
    var lastMessageDate: Date {
        guard let lastMessage = lastMessage else {
            return Date.distantPast
        }
        return lastMessage.createdAt
    }
    
    var lastMessagePreview: String {
        guard let lastMessage = lastMessage,
              let status = lastMessage.status else {
            return ""
        }
        return status.content.htmlToPlainText
    }
    
    init(account: MastodonAccount, messages: [ChatMessage]) {
        self.id = account.id
        self.account = account
        self.messages = messages
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let notification: MastodonNotification?
    let status: Status?
    let isSent: Bool // true if this is a sent message (from current user)
    let createdAt: Date
    
    init(notification: MastodonNotification) {
        self.id = notification.id
        self.notification = notification
        self.status = notification.status
        self.isSent = false
        self.createdAt = notification.createdAt
    }
    
    init(status: Status, isSent: Bool = true) {
        self.id = status.id
        self.notification = nil
        self.status = status
        self.isSent = isSent
        self.createdAt = status.createdAt
    }
}

// MARK: - Conversations List View

struct ConversationsListView: View {
    let conversations: [Conversation]
    @Environment(AppState.self) private var appState
    
    var body: some View {
        GlassEffectContainer {
            List(conversations) { conversation in
                NavigationLink {
                    ConversationDetailView(conversation: conversation)
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(8)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: conversation.account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.account.displayName)
                        .font(.roundedHeadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(TimeFormatter.relativeTimeString(from: conversation.lastMessageDate))
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                
                Text(conversation.lastMessagePreview)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - Conversation Detail View

struct ConversationDetailView: View {
    let conversation: Conversation
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    @State private var userReplies: [Status] = []
    @State private var isLoadingReplies = false
    
    // Get updated conversation with latest messages (including user's replies)
    private var updatedConversation: Conversation {
        guard let mentions = timelineService?.mentions else { return conversation }
        
        // Get incoming messages (mentions from the other user)
        let privateMentions = mentions.filter { notification in
            guard let status = notification.status else { return false }
            return (status.visibility == .private || status.visibility == .direct) &&
                   notification.account.id == conversation.account.id
        }
        
        // Get user's replies to this conversation
        let userRepliesToConversation = userReplies.filter { status in
            // Check if this reply mentions the conversation account or is a reply to a message in this conversation
            let mentionsAccount = status.mentions.contains { $0.acct == conversation.account.acct }
            let isReplyToConversation = privateMentions.contains { mention in
                mention.status?.id == status.inReplyToId
            }
            return mentionsAccount || isReplyToConversation
        }
        
        // Combine and sort by date
        var allMessages: [ChatMessage] = []
        allMessages.append(contentsOf: privateMentions.map { ChatMessage(notification: $0) })
        allMessages.append(contentsOf: userRepliesToConversation.map { ChatMessage(status: $0, isSent: true) })
        
        let sortedMessages = allMessages.sorted { $0.createdAt > $1.createdAt }
        return Conversation(account: conversation.account, messages: sortedMessages)
    }
    
    // Group messages for display (consecutive messages from same user)
    private var groupedMessages: [GroupedMessage] {
        groupMessages(updatedConversation.messages)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedMessages) { group in
                            ChatMessageGroup(group: group)
                                .id(group.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    // Scroll to bottom (newest messages) when view appears
                    if let lastGroup = groupedMessages.last {
                        proxy.scrollTo(lastGroup.id, anchor: .bottom)
                    }
                }
                .onChange(of: groupedMessages.count) { _, _ in
                    // Scroll to bottom when new messages arrive
                    if let lastGroup = groupedMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastGroup.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Compose bar
            composeBar
        }
        .navigationTitle(conversation.account.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.navigate(to: .profile(conversation.account))
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .task {
            await loadUserReplies()
        }
        .refreshable {
            await loadUserReplies()
            await timelineService?.refreshMentions()
        }
    }
    
    private func loadUserReplies() async {
        guard let account = appState.currentAccount,
              let token = await appState.getAccessToken(),
              !isLoadingReplies else { return }
        
        isLoadingReplies = true
        defer { isLoadingReplies = false }
        
        do {
            // Extract account ID (format is "instance:accountId")
            let accountId = account.id.components(separatedBy: ":").last ?? account.id
            
            // Fetch user's statuses (replies included)
            let statuses = try await appState.client.getAccountStatuses(
                instance: account.instance,
                accessToken: token,
                accountId: accountId,
                limit: 100,
                excludeReplies: false,
                excludeReblogs: true
            )
            
            // Filter for private/direct replies
            userReplies = statuses.filter { status in
                (status.visibility == .private || status.visibility == .direct) &&
                status.inReplyToId != nil
            }
        } catch {
            print("Failed to load user replies: \(error)")
        }
    }
    
    private var composeBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24))
            
            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 30, height: 30)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? .blue : .gray)
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular)
    }
    
    private func sendMessage() async {
        guard canSend else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            guard let service = timelineService else { return }
            
            // Find the most recent message to reply to
            // Messages are sorted newest first, so first is most recent
            guard let firstMessage = conversation.messages.first,
                  let lastMessage = firstMessage.status else { return }
            
            // Add mention if not already present
            let mention = "@\(conversation.account.acct) "
            let contentWithMention = messageText.hasPrefix("@") ? messageText : "\(mention)\(messageText)"
            
            // Reply to the last message in the conversation
            _ = try await service.reply(to: lastMessage, content: contentWithMention)
            
            // Clear input
            messageText = ""
            
            // Refresh mentions and user replies to get the new message
            await timelineService?.refreshMentions()
            await loadUserReplies()
        } catch {
            // Handle error (could show alert)
            print("Failed to send message: \(error)")
        }
    }
    
    private func groupMessages(_ messages: [ChatMessage]) -> [GroupedMessage] {
        // Reverse so newest appear at bottom (like chat)
        let reversedMessages = Array(messages.reversed())
        
        var groups: [GroupedMessage] = []
        var currentGroup: [ChatMessage] = []
        var currentIsSent: Bool?
        
        for message in reversedMessages {
            // If same sender type and within 5 minutes, add to current group
            if let lastMessage = currentGroup.last,
               message.isSent == currentIsSent,
               abs(message.createdAt.timeIntervalSince(lastMessage.createdAt)) < 300 {
                currentGroup.append(message)
            } else {
                // Start new group
                if !currentGroup.isEmpty, let isSent = currentIsSent {
                    let account = isSent ? (appState.currentAccount?.mastodonAccount ?? conversation.account) : conversation.account
                    groups.append(GroupedMessage(
                        account: account,
                        messages: currentGroup,
                        isSent: isSent
                    ))
                }
                currentGroup = [message]
                currentIsSent = message.isSent
            }
        }
        
        // Add final group
        if !currentGroup.isEmpty, let isSent = currentIsSent {
            let account = isSent ? (appState.currentAccount?.mastodonAccount ?? conversation.account) : conversation.account
            groups.append(GroupedMessage(
                account: account,
                messages: currentGroup,
                isSent: isSent
            ))
        }
        
        return groups
    }
}

// MARK: - Grouped Message

struct GroupedMessage: Identifiable {
    let id: String
    let account: MastodonAccount
    let messages: [ChatMessage]
    let isSent: Bool
    
    init(account: MastodonAccount, messages: [ChatMessage], isSent: Bool = false) {
        self.id = "\(account.id)-\(messages.first?.id ?? UUID().uuidString)"
        self.account = account
        self.messages = messages
        self.isSent = isSent
    }
}

// MARK: - Chat Message Group

struct ChatMessageGroup: View {
    let group: GroupedMessage
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if group.isSent {
            // Sent messages (right-aligned)
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 60)
                
                // Messages
                VStack(alignment: .trailing, spacing: 4) {
                    // Chat bubbles
                    ForEach(group.messages) { message in
                        ChatBubble(message: message, account: group.account, isSent: true)
                    }
                }
                
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        if let currentAccount = appState.currentAccount?.mastodonAccount {
                            appState.navigate(to: .profile(currentAccount))
                        }
                    } label: {
                        AsyncImage(url: group.account.avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.tertiary)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.vertical, 4)
        } else {
            // Received messages (left-aligned)
            HStack(alignment: .bottom, spacing: 8) {
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        appState.navigate(to: .profile(group.account))
                    } label: {
                        AsyncImage(url: group.account.avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.tertiary)
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                }
                
                // Messages
                VStack(alignment: .leading, spacing: 4) {
                    // Account name (only for first message)
                    if group.messages.first != nil {
                        Button {
                            appState.navigate(to: .profile(group.account))
                        } label: {
                            Text(group.account.displayName)
                                .font(.roundedCaption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Chat bubbles
                    ForEach(group.messages) { message in
                        ChatBubble(message: message, account: group.account, isSent: false)
                    }
                }
                
                Spacer(minLength: 60)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    let account: MastodonAccount
    let isSent: Bool
    @Environment(AppState.self) private var appState
    
    var status: Status? {
        message.status
    }
    
    var body: some View {
        if let status = status {
            Button {
                appState.navigate(to: .status(status))
            } label: {
                VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
                    // Message content
                    if #available(iOS 15.0, macOS 12.0, *) {
                        Text(status.content.htmlToAttributedString)
                            .font(.roundedBody)
                            .multilineTextAlignment(isSent ? .trailing : .leading)
                    } else {
                        Text(status.content.htmlToPlainText)
                            .font(.roundedBody)
                            .multilineTextAlignment(isSent ? .trailing : .leading)
                    }
                    
                    // Timestamp
                    HStack {
                        if !isSent { Spacer() }
                        Text(message.createdAt, style: .time)
                            .font(.roundedCaption2)
                            .foregroundStyle(.secondary)
                        if isSent { Spacer() }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSent ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                if !isSent {
                    Button {
                        appState.present(sheet: .compose(replyTo: status))
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    
                    Button {
                        appState.navigate(to: .thread(statusId: status.id))
                    } label: {
                        Label("View Thread", systemImage: "bubble.left.and.bubble.right")
                    }
                    
                    Divider()
                }
                
                Button {
                    appState.navigate(to: .profile(account))
                } label: {
                    Label("View Profile", systemImage: "person")
                }
            }
        }
    }
}

// MARK: - Extension for Notification Hashable

extension MastodonNotification: Equatable {
    static func == (lhs: MastodonNotification, rhs: MastodonNotification) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    NavigationStack {
        MentionsView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

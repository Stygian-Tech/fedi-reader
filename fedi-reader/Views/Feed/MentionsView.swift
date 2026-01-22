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
    
    private var conversations: [MastodonConversation] {
        timelineService?.conversations ?? []
    }
    
    var body: some View {
        Group {
            if !conversations.isEmpty {
                ConversationsListView(conversations: conversations)
            } else if timelineService?.isLoadingConversations == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Messages")
        .refreshable {
            await timelineService?.refreshConversations()
        }
        .task {
            await loadConversations()
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message")
        } description: {
            Text("Private mentions and direct messages will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await timelineService?.refreshConversations()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func loadConversations() async {
        if timelineService?.conversations.isEmpty == true {
            await timelineService?.refreshConversations()
        }
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
    let conversations: [MastodonConversation]
    
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
    let conversation: MastodonConversation
    @Environment(AppState.self) private var appState
    
    private var otherAccount: MastodonAccount? {
        guard let currentAccount = appState.currentAccount?.mastodonAccount else {
            return conversation.accounts.first
        }
        return conversation.accounts.first(where: { $0.id != currentAccount.id }) ?? conversation.accounts.first
    }
    
    private var lastStatus: Status? {
        conversation.lastStatus
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: otherAccount?.avatarURL) { image in
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
                    Text(otherAccount?.displayName ?? "Unknown")
                        .font(.roundedHeadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(TimeFormatter.relativeTimeString(from: lastStatus?.createdAt ?? Date.distantPast))
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                
                Text(lastStatus?.content.htmlToPlainText ?? "")
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
    let conversation: MastodonConversation
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    @State private var statusContext: StatusContext?
    @State private var isLoadingThread = false
    
    private var otherAccount: MastodonAccount? {
        guard let currentAccount = appState.currentAccount?.mastodonAccount else {
            return conversation.accounts.first
        }
        return conversation.accounts.first(where: { $0.id != currentAccount.id }) ?? conversation.accounts.first
    }
    
    private var lastStatus: Status? {
        conversation.lastStatus
    }
    
    private var conversationStatuses: [Status] {
        guard let lastStatus else { return [] }
        
        var statuses: [Status] = [lastStatus]
        if let context = statusContext {
            statuses.append(contentsOf: context.ancestors)
            statuses.append(contentsOf: context.descendants)
        }
        
        let uniqueStatuses = Dictionary(grouping: statuses, by: { $0.id })
            .compactMap { $0.value.first }
            .filter { $0.visibility == .private || $0.visibility == .direct }
        
        return uniqueStatuses.sorted { $0.createdAt < $1.createdAt }
    }
    
    // Group messages for display (consecutive messages from same user)
    private var groupedMessages: [GroupedMessage] {
        let messages = conversationStatuses.map { status in
            ChatMessage(status: status, isSent: isSentMessage(status))
        }
        return groupMessages(messages)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    private func isSentMessage(_ status: Status) -> Bool {
        guard let currentId = appState.currentAccount?.mastodonAccount.id else { return false }
        return status.account.id == currentId
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
        .navigationTitle(otherAccount?.displayName ?? "Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let account = otherAccount {
                        appState.navigate(to: .profile(account))
                    }
                } label: {
                    Image(systemName: "person.circle")
                }
            }
        }
        .task {
            await loadConversationThread()
        }
        .refreshable {
            await timelineService?.refreshConversations()
            await loadConversationThread()
        }
    }
    
    private func loadConversationThread() async {
        guard let lastStatus else {
            statusContext = nil
            return
        }
        
        guard let service = timelineService, !isLoadingThread else { return }
        isLoadingThread = true
        defer { isLoadingThread = false }
        
        do {
            statusContext = try await service.getStatusContext(for: lastStatus)
        } catch {
            statusContext = nil
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
            guard let lastMessage = lastStatus, let otherAccount else { return }
            
            // Add mention if not already present
            let mention = "@\(otherAccount.acct) "
            let contentWithMention = messageText.hasPrefix("@") ? messageText : "\(mention)\(messageText)"
            
            // Reply to the last message in the conversation
            _ = try await service.reply(to: lastMessage, content: contentWithMention)
            
            // Clear input
            messageText = ""
            
            // Refresh mentions and user replies to get the new message
            await timelineService?.refreshConversations()
            await loadConversationThread()
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
        let sentAccount = appState.currentAccount?.mastodonAccount
            ?? otherAccount
            ?? conversation.accounts.first
        let receivedAccount = otherAccount
            ?? conversation.accounts.first
            ?? appState.currentAccount?.mastodonAccount
        
        for message in reversedMessages {
            // If same sender type and within 5 minutes, add to current group
            if let lastMessage = currentGroup.last,
               message.isSent == currentIsSent,
               abs(message.createdAt.timeIntervalSince(lastMessage.createdAt)) < 300 {
                currentGroup.append(message)
            } else {
                // Start new group
                if !currentGroup.isEmpty, let isSent = currentIsSent {
                    let account = isSent ? sentAccount : receivedAccount
                    groups.append(GroupedMessage(
                        account: account ?? MastodonAccount(
                            id: "unknown",
                            username: "unknown",
                            acct: "unknown",
                            displayName: "Unknown",
                            locked: false,
                            bot: false,
                            createdAt: Date(),
                            note: "",
                            url: "",
                            avatar: "",
                            avatarStatic: "",
                            header: "",
                            headerStatic: "",
                            followersCount: 0,
                            followingCount: 0,
                            statusesCount: 0,
                            lastStatusAt: nil,
                            emojis: [],
                            fields: []
                        ),
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
            let account = isSent ? sentAccount : receivedAccount
            groups.append(GroupedMessage(
                account: account ?? MastodonAccount(
                    id: "unknown",
                    username: "unknown",
                    acct: "unknown",
                    displayName: "Unknown",
                    locked: false,
                    bot: false,
                    createdAt: Date(),
                    note: "",
                    url: "",
                    avatar: "",
                    avatarStatic: "",
                    header: "",
                    headerStatic: "",
                    followersCount: 0,
                    followingCount: 0,
                    statusesCount: 0,
                    lastStatusAt: nil,
                    emojis: [],
                    fields: []
                ),
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
                    if let firstMessage = group.messages.first {
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

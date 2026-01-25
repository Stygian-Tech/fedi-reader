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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.present(sheet: .newMessage)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
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

// MARK: - Grouped Conversation (handles both 1:1 and group chats)

struct GroupedConversation: Identifiable {
    let id: String
    let participants: [MastodonAccount] // Other participants (excluding current user)
    let conversations: [MastodonConversation]
    let isGroupChat: Bool
    
    var lastStatus: Status? {
        conversations
            .compactMap { $0.lastStatus }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }
    
    var lastUpdated: Date {
        lastStatus?.createdAt ?? Date.distantPast
    }
    
    var unread: Bool {
        conversations.contains { $0.unread == true }
    }
    
    var displayName: String {
        if isGroupChat {
            let names = participants.prefix(3).map { $0.displayName }
            if participants.count > 3 {
                return names.joined(separator: ", ") + " +\(participants.count - 3)"
            }
            return names.joined(separator: ", ")
        } else {
            return participants.first?.displayName ?? "Unknown"
        }
    }
    
    var primaryAccount: MastodonAccount? {
        participants.first
    }
}

// MARK: - Conversations List View

struct ConversationsListView: View {
    let conversations: [MastodonConversation]
    @Environment(AppState.self) private var appState
    
    // Group conversations by participants
    private var groupedConversations: [GroupedConversation] {
        guard let currentAccountId = appState.currentAccount?.mastodonAccount.id else {
            return []
        }
        
        // Separate group chats from 1:1 conversations
        var oneOnOneGrouped: [String: (account: MastodonAccount, conversations: [MastodonConversation])] = [:]
        var groupChats: [String: (participants: [MastodonAccount], conversations: [MastodonConversation])] = [:]
        
        for conversation in conversations {
            // Get all participants except current user
            let otherParticipants = conversation.accounts.filter { $0.id != currentAccountId }
            
            if otherParticipants.count > 1 {
                // This is a group chat - group by sorted participant IDs
                let participantIds = otherParticipants.map { $0.id }.sorted().joined(separator: "-")
                let groupId = "group-\(participantIds)"
                
                if var existing = groupChats[groupId] {
                    existing.conversations.append(conversation)
                    groupChats[groupId] = existing
                } else {
                    groupChats[groupId] = (participants: otherParticipants, conversations: [conversation])
                }
            } else if let otherAccount = otherParticipants.first ?? conversation.accounts.first {
                // 1:1 conversation
                if var existing = oneOnOneGrouped[otherAccount.id] {
                    existing.conversations.append(conversation)
                    oneOnOneGrouped[otherAccount.id] = existing
                } else {
                    oneOnOneGrouped[otherAccount.id] = (account: otherAccount, conversations: [conversation])
                }
            }
        }
        
        // Convert to GroupedConversation
        var result: [GroupedConversation] = []
        
        // Add 1:1 conversations
        for (id, data) in oneOnOneGrouped {
            result.append(GroupedConversation(
                id: id,
                participants: [data.account],
                conversations: data.conversations,
                isGroupChat: false
            ))
        }
        
        // Add group chats
        for (id, data) in groupChats {
            result.append(GroupedConversation(
                id: id,
                participants: data.participants,
                conversations: data.conversations,
                isGroupChat: true
            ))
        }
        
        // Sort by most recent
        return result.sorted { $0.lastUpdated > $1.lastUpdated }
    }
    
    var body: some View {
        GlassEffectContainer {
            List(groupedConversations) { groupedConvo in
                NavigationLink {
                    GroupedConversationDetailView(groupedConversation: groupedConvo)
                } label: {
                    GroupedConversationRow(groupedConversation: groupedConvo)
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

// MARK: - Grouped Conversation Row

struct GroupedConversationRow: View {
    let groupedConversation: GroupedConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar(s)
            if groupedConversation.isGroupChat {
                // Group chat: show stacked avatars
                GroupAvatarView(participants: groupedConversation.participants)
                    .overlay(alignment: .bottomTrailing) {
                        unreadIndicator
                    }
            } else {
                // 1:1: single avatar
                AsyncImage(url: groupedConversation.primaryAccount?.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    unreadIndicator
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if groupedConversation.isGroupChat {
                        Image(systemName: "person.2.fill")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(groupedConversation.displayName)
                        .font(.roundedHeadline)
                        .fontWeight(groupedConversation.unread ? .bold : .semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(TimeFormatter.relativeTimeString(from: groupedConversation.lastUpdated))
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                
                Text(groupedConversation.lastStatus?.content.htmlToPlainText ?? "")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var unreadIndicator: some View {
        if groupedConversation.unread {
            Circle()
                .fill(.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 2)
                )
        }
    }
}

// MARK: - Group Avatar View

struct GroupAvatarView: View {
    let participants: [MastodonAccount]
    
    var body: some View {
        ZStack {
            // Show up to 4 avatars in a grid pattern
            let avatarsToShow = Array(participants.prefix(4))
            
            if avatarsToShow.count == 2 {
                // Two avatars: diagonal overlap
                HStack(spacing: -16) {
                    avatarImage(for: avatarsToShow[0])
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    
                    avatarImage(for: avatarsToShow[1])
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                .frame(width: 56, height: 56)
            } else if avatarsToShow.count >= 3 {
                // 3-4 avatars: 2x2 grid
                let gridSize: CGFloat = 28
                VStack(spacing: -4) {
                    HStack(spacing: -4) {
                        avatarImage(for: avatarsToShow[0])
                            .frame(width: gridSize, height: gridSize)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                        
                        avatarImage(for: avatarsToShow[1])
                            .frame(width: gridSize, height: gridSize)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                    }
                    HStack(spacing: -4) {
                        avatarImage(for: avatarsToShow[2])
                            .frame(width: gridSize, height: gridSize)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                        
                        if avatarsToShow.count > 3 {
                            avatarImage(for: avatarsToShow[3])
                                .frame(width: gridSize, height: gridSize)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                        } else if participants.count > 3 {
                            // Show +N indicator
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: gridSize, height: gridSize)
                                .overlay(
                                    Text("+\(participants.count - 3)")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                )
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: gridSize, height: gridSize)
                        }
                    }
                }
                .frame(width: 56, height: 56)
            } else {
                // Fallback: single avatar
                avatarImage(for: avatarsToShow.first)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            }
        }
    }
    
    @ViewBuilder
    private func avatarImage(for account: MastodonAccount?) -> some View {
        AsyncImage(url: account?.avatarURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(.tertiary)
        }
    }
}

// MARK: - Grouped Conversation Detail View

struct GroupedConversationDetailView: View {
    let groupedConversation: GroupedConversation
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    @State private var statusContexts: [String: StatusContext] = [:]
    @State private var isLoadingThreads = false
    
    private var participants: [MastodonAccount] {
        groupedConversation.participants
    }
    
    private var isGroupChat: Bool {
        groupedConversation.isGroupChat
    }
    
    // Get the most recent status across all conversations to reply to
    private var mostRecentStatus: Status? {
        groupedConversation.lastStatus
    }
    
    // Combine all statuses from all conversations
    private var allConversationStatuses: [Status] {
        var allStatuses: [Status] = []
        
        // Get statuses from all conversations
        for conversation in groupedConversation.conversations {
            if let lastStatus = conversation.lastStatus {
                allStatuses.append(lastStatus)
            }
        }
        
        // Add statuses from all loaded contexts
        for (_, context) in statusContexts {
            allStatuses.append(contentsOf: context.ancestors)
            allStatuses.append(contentsOf: context.descendants)
        }
        
        // Deduplicate and filter for private/direct messages only
        let uniqueStatuses = Dictionary(grouping: allStatuses, by: { $0.id })
            .compactMap { $0.value.first }
            .filter { $0.visibility == .private || $0.visibility == .direct }
        
        return uniqueStatuses.sorted { $0.createdAt < $1.createdAt }
    }
    
    // Group messages for display (consecutive messages from same user)
    private var groupedMessages: [GroupedMessage] {
        let messages = allConversationStatuses.map { status in
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
        .navigationTitle(groupedConversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isGroupChat {
                    // Group chat: show menu with all participants
                    Menu {
                        ForEach(participants) { participant in
                            Button {
                                appState.navigate(to: .profile(participant))
                            } label: {
                                Label(participant.displayName, systemImage: "person")
                            }
                        }
                    } label: {
                        Image(systemName: "person.2.circle")
                    }
                } else if let account = participants.first {
                    // 1:1 chat: direct profile link
                    Button {
                        appState.navigate(to: .profile(account))
                    } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
        .task {
            await loadAllConversationThreads()
        }
        .refreshable {
            await timelineService?.refreshConversations()
            await loadAllConversationThreads()
        }
    }
    
    private func loadAllConversationThreads() async {
        guard let service = timelineService, !isLoadingThreads else { return }
        isLoadingThreads = true
        defer { isLoadingThreads = false }
        
        // Load context for each conversation's last status
        await withTaskGroup(of: (String, StatusContext?).self) { group in
            for conversation in groupedConversation.conversations {
                guard let lastStatus = conversation.lastStatus else { continue }
                
                group.addTask {
                    do {
                        let context = try await service.getStatusContext(for: lastStatus)
                        return (lastStatus.id, context)
                    } catch {
                        return (lastStatus.id, nil)
                    }
                }
            }
            
            for await (statusId, context) in group {
                if let context {
                    statusContexts[statusId] = context
                }
            }
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
            guard let lastMessage = mostRecentStatus else { return }
            
            // Build mentions for all participants
            let mentions = participants.map { "@\($0.acct)" }.joined(separator: " ")
            let contentWithMentions = messageText.hasPrefix("@") ? messageText : "\(mentions) \(messageText)"
            
            // Reply to the last message in the conversation
            _ = try await service.reply(to: lastMessage, content: contentWithMentions)
            
            // Clear input
            messageText = ""
            
            // Refresh mentions and user replies to get the new message
            await timelineService?.refreshConversations()
            await loadAllConversationThreads()
        } catch {
            // Handle error (could show alert)
            print("Failed to send message: \(error)")
        }
    }
    
    private func groupMessages(_ messages: [ChatMessage]) -> [GroupedMessage] {
        var groups: [GroupedMessage] = []
        var currentGroup: [ChatMessage] = []
        var currentSenderId: String?
        
        for message in messages {
            let senderId = message.status?.account.id ?? "unknown"
            
            // If same sender and within 5 minutes, add to current group
            if let lastMessage = currentGroup.last,
               senderId == currentSenderId,
               abs(message.createdAt.timeIntervalSince(lastMessage.createdAt)) < 300 {
                currentGroup.append(message)
            } else {
                // Start new group
                if !currentGroup.isEmpty, let firstMessage = currentGroup.first {
                    let account = firstMessage.status?.account ?? unknownAccount
                    groups.append(GroupedMessage(
                        account: account,
                        messages: currentGroup,
                        isSent: firstMessage.isSent
                    ))
                }
                currentGroup = [message]
                currentSenderId = senderId
            }
        }
        
        // Add final group
        if !currentGroup.isEmpty, let firstMessage = currentGroup.first {
            let account = firstMessage.status?.account ?? unknownAccount
            groups.append(GroupedMessage(
                account: account,
                messages: currentGroup,
                isSent: firstMessage.isSent
            ))
        }
        
        return groups
    }
    
    private var unknownAccount: MastodonAccount {
        MastodonAccount(
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
        )
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
                    if !group.messages.isEmpty {
                        Button {
                            appState.navigate(to: .profile(group.account))
                        } label: {
                            HStack(spacing: 4) {
                                Text(group.account.displayName)
                                    .font(.roundedCaption.bold())
                                    .foregroundStyle(.secondary)
                                
                                AccountBadgesView(account: group.account, size: .small)
                            }
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
    
    private var mediaAttachments: [MediaAttachment] {
        status?.mediaAttachments.filter { attachment in
            attachment.type == .image || attachment.type == .video || attachment.type == .gifv
        } ?? []
    }
    
    private var hasFavorites: Bool {
        (status?.favouritesCount ?? 0) > 0
    }
    
    private var isFavoritedByMe: Bool {
        status?.favourited == true
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
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(status.content.htmlToPlainText)
                            .font(.roundedBody)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if !mediaAttachments.isEmpty {
                        chatMediaAttachments
                    }
                    
                    // Timestamp
                    Text(message.createdAt, style: .time)
                        .font(.roundedCaption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSent ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                )
                .overlay(alignment: isSent ? .bottomLeading : .bottomTrailing) {
                    // Tapback-style favorite indicator
                    if hasFavorites {
                        TapbackView(count: status.favouritesCount, isMine: isFavoritedByMe)
                            .offset(x: isSent ? -8 : 8, y: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, hasFavorites ? 8 : 0) // Extra space for tapback
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
    
    private var chatMediaAttachments: some View {
        VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
            ForEach(mediaAttachments) { attachment in
                AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.tertiary)
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if attachment.type == .video || attachment.type == .gifv {
                        Image(systemName: attachment.type == .gifv ? "play.circle" : "video")
                            .font(.roundedCaption)
                            .padding(4)
                            .glassEffect(.clear, in: Circle())
                            .padding(6)
                    }
                }
            }
        }
    }
}

// MARK: - Tapback View (iMessage-style reaction indicator)

struct TapbackView: View {
    let count: Int
    let isMine: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isMine ? "star.fill" : "star.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isMine ? .yellow : .secondary)
            
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - New Message View

struct NewMessageView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedRecipients: [MastodonAccount] = []
    @State private var searchResults: [MastodonAccount] = []
    @State private var isSearching = false
    @State private var messageText = ""
    @State private var isSending = false
    @State private var error: Error?
    
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isMessageFocused: Bool
    
    private var canSend: Bool {
        !selectedRecipients.isEmpty && 
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Recipients section
                recipientsSection
                
                Divider()
                
                // Search results or message composer
                if !searchText.isEmpty || isSearchFocused {
                    searchResultsSection
                } else if !selectedRecipients.isEmpty {
                    messageComposerSection
                } else {
                    instructionsSection
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await sendMessage()
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .bold()
                        }
                    }
                    .disabled(!canSend)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                if let error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Recipients Section
    
    private var recipientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "To:" label with selected recipients
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("To:")
                        .font(.roundedBody)
                        .foregroundStyle(.secondary)
                    
                    ForEach(selectedRecipients) { recipient in
                        RecipientChip(account: recipient) {
                            withAnimation {
                                selectedRecipients.removeAll { $0.id == recipient.id }
                            }
                        }
                    }
                    
                    // Search field inline
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .frame(minWidth: 120)
                        .onChange(of: searchText) { _, newValue in
                            Task {
                                await performSearch(query: newValue)
                            }
                        }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        List {
            if isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No users found")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(searchResults) { account in
                    Button {
                        addRecipient(account)
                    } label: {
                        UserSearchRow(account: account, isSelected: selectedRecipients.contains { $0.id == account.id })
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Message Composer Section
    
    private var messageComposerSection: some View {
        VStack(spacing: 0) {
            // Show who the message is going to
            HStack {
                Image(systemName: "lock.fill")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                Text("Private message to \(recipientNames)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemBackground))
            
            // Message text editor
            TextEditor(text: $messageText)
                .focused($isMessageFocused)
                .scrollContentBackground(.hidden)
                .padding()
            
            Spacer()
        }
        .onAppear {
            isMessageFocused = true
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Add Recipients")
                .font(.roundedHeadline)
            
            Text("Search for users to start a private conversation")
                .font(.roundedSubheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private var recipientNames: String {
        let names = selectedRecipients.map { $0.displayName }
        if names.count == 1 {
            return names[0]
        } else if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        } else if names.count > 2 {
            return "\(names.dropLast().joined(separator: ", ")), and \(names.last!)"
        }
        return ""
    }
    
    private func addRecipient(_ account: MastodonAccount) {
        guard !selectedRecipients.contains(where: { $0.id == account.id }) else { return }
        
        withAnimation {
            selectedRecipients.append(account)
            searchText = ""
            searchResults = []
            isSearchFocused = false
        }
    }
    
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            let results = try await appState.client.searchAccounts(query: trimmed, limit: 15)
            // Filter out already selected recipients and current user
            let currentUserId = appState.currentAccount?.mastodonAccount.id
            searchResults = results.filter { account in
                account.id != currentUserId && !selectedRecipients.contains { $0.id == account.id }
            }
        } catch {
            searchResults = []
        }
    }
    
    private func sendMessage() async {
        guard canSend else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            guard let account = appState.currentAccount,
                  let token = await appState.getAccessToken() else {
                throw FediReaderError.noActiveAccount
            }
            
            // Build mentions for all recipients
            let mentions = selectedRecipients.map { "@\($0.acct)" }.joined(separator: " ")
            let fullContent = "\(mentions) \(messageText)"
            
            // Post as a direct message
            _ = try await appState.client.postStatus(
                instance: account.instance,
                accessToken: token,
                status: fullContent,
                sensitive: false,
                spoilerText: nil,
                visibility: .direct
            )
            
            dismiss()
        } catch {
            self.error = error
        }
    }
}

// MARK: - Recipient Chip

struct RecipientChip: View {
    let account: MastodonAccount
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            AsyncImage(url: account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: 20, height: 20)
            .clipShape(Circle())
            
            HStack(spacing: 4) {
                Text(account.displayName)
                    .font(.roundedSubheadline)
                    .lineLimit(1)
                
                AccountBadgesView(account: account, size: .small)
            }
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.15))
        )
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let account: MastodonAccount
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(account.displayName)
                        .font(.roundedBody)
                        .foregroundStyle(.primary)
                    
                    AccountBadgesView(account: account, size: .small)
                }
                
                Text("@\(account.acct)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
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

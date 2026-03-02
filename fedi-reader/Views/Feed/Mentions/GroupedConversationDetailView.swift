import SwiftUI
import os

struct GroupedConversationDetailView: View {
    let groupedConversation: GroupedConversation
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.layoutMode) private var layoutMode
    
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextFieldFocused: Bool
    @AppStorage("themeColor") private var themeColorName = "blue"
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    @State private var statusContexts: [String: StatusContext] = [:]
    @State private var isLoadingThreads = false
    @State private var loadedContextStatusIds = Set<String>()
    
    private var currentGroupedConversation: GroupedConversation {
        guard let service = timelineService,
              let currentAccountId = appState.currentAccount?.mastodonAccount.id else {
            return groupedConversation
        }

        let grouped = ConversationGroupingHelper.groupedConversations(
            from: service.conversations,
            currentAccountId: currentAccountId
        )
        return grouped.first(where: { $0.id == groupedConversation.id }) ?? groupedConversation
    }

    private var participants: [MastodonAccount] {
        currentGroupedConversation.participants
    }
    
    private var isGroupChat: Bool {
        currentGroupedConversation.isGroupChat
    }
    
    // Get the most recent status across all conversations to reply to
    private var mostRecentStatus: Status? {
        currentGroupedConversation.lastStatus
    }
    
    // Combine all statuses from all conversations
    private var allConversationStatuses: [Status] {
        var allStatuses: [Status] = []
        
        // Get statuses from all conversations
        for conversation in currentGroupedConversation.conversations {
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
        
        return uniqueStatuses
    }
    
    // Group messages for display in chronological chat order.
    private var groupedMessages: [GroupedMessage] {
        let chronologicalMessages = allConversationStatuses
            .sorted { $0.createdAt < $1.createdAt }
            .map { status in
                ChatMessage(status: status, isSent: isSentMessage(status))
            }

        return groupMessages(chronologicalMessages)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
    
    private func isSentMessage(_ status: Status) -> Bool {
        guard let currentId = appState.currentAccount?.mastodonAccount.id else { return false }
        return status.account.id == currentId
    }
    
    var body: some View {
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
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let lastGroup = groupedMessages.last {
                    proxy.scrollTo(lastGroup.id, anchor: .bottom)
                }
            }
            .onChange(of: groupedMessages.count) { _, _ in
                if let lastGroup = groupedMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastGroup.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isTextFieldFocused) { _, focused in
                if focused, let lastGroup = groupedMessages.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastGroup.id, anchor: .bottom)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composeBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }
        }
        .navigationTitle(currentGroupedConversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(layoutMode.isCompact ? .hidden : .visible, for: .tabBar)
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
            // Mark all unread conversations in this group as read
            await markConversationsAsRead()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timelineDidRefresh)) { notification in
            guard let timeline = notification.object as? TimelineType, timeline == .mentions else { return }
            Task {
                await loadAllConversationThreads()
                await markConversationsAsRead()
            }
        }
        .refreshable {
            await timelineService?.refreshConversations()
            await loadAllConversationThreads()
        }
    }
    
    private func loadAllConversationThreads() async {
        guard let service = timelineService, !isLoadingThreads else { return }
        let statusesToLoad = currentGroupedConversation.conversations.compactMap(\.lastStatus).filter { lastStatus in
            !loadedContextStatusIds.contains(lastStatus.id)
        }
        guard !statusesToLoad.isEmpty else { return }

        isLoadingThreads = true
        defer { isLoadingThreads = false }
        
        // Load context for each conversation's last status
        await withTaskGroup(of: (String, StatusContext?).self) { group in
            for lastStatus in statusesToLoad {
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
                loadedContextStatusIds.insert(statusId)
            }
        }
    }
    
    private func markConversationsAsRead() async {
        guard let service = timelineService else { return }
        
        // Mark all unread conversations in this group as read
        for conversation in currentGroupedConversation.conversations {
            if conversation.unread == true {
                await service.markConversationAsRead(conversationId: conversation.id)
            }
        }
    }
    
    private var composeBar: some View {
        HStack(spacing: 0) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 10)
            
            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                if isSending {
                    ProgressView()
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(canSend ? ThemeColor.resolved(from: themeColorName).color : .gray)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .frame(width: 36, height: 36)
        }
        .glassEffect(.clear, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }
    
    private func sendMessage() async {
        guard canSend else { return }
        let textToSend = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        messageText = ""
        isSending = true
        defer { isSending = false }
        
        do {
            guard let service = timelineService else { return }
            
            // Find the most recent message to reply to
            guard let lastMessage = mostRecentStatus else { return }
            
            // Build mentions for all participants
            let mentions = participants.map { "@\($0.acct)" }.joined(separator: " ")
            let contentWithMentions = textToSend.hasPrefix("@") ? textToSend : "\(mentions) \(textToSend)"
            
            // Reply to the last message in the conversation
            _ = try await service.reply(to: lastMessage, content: contentWithMentions)
            
            await loadAllConversationThreads()
        } catch {
            Logger(subsystem: "app.fedi-reader", category: "Mentions").error("Failed to send message: \(error.localizedDescription)")
            messageText = textToSend
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
            fields: [],
            source: nil
        )
    }
}

// MARK: - Grouped Message



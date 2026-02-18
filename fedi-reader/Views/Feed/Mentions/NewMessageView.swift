import SwiftUI
import os

struct NewMessageView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedRecipients: [MastodonAccount] = []
    @State private var unresolvedHandleTokens: [String] = []
    @State private var existingConversationMatches: [GroupedConversation] = []
    @State private var searchResults: [MastodonAccount] = []
    @State private var isSearchingSuggestions = false
    @State private var searchGeneration = 0
    @State private var searchTask: Task<Void, Never>?
    @State private var messageText = ""
    @State private var isSending = false
    @State private var error: Error?
    
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isMessageFocused: Bool
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    private var canSend: Bool {
        !selectedRecipients.isEmpty &&
        unresolvedHandleTokens.isEmpty &&
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSending
    }
    
    private var hasActiveSearchToken: Bool {
        HandleInputParser.tokenize(searchText).activeToken != nil
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
        .onAppear {
            refreshExistingConversationMatches()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timelineDidRefresh)) { notification in
            guard let timeline = notification.object as? TimelineType, timeline == .mentions else { return }
            refreshExistingConversationMatches()
        }
        .onDisappear {
            searchTask?.cancel()
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
                            removeRecipient(recipient)
                        }
                    }
                    
                    // Search field inline
                    TextField("Search users or @handles...", text: $searchText)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .focused($isSearchFocused)
                        .frame(minWidth: 120)
                        .onChange(of: searchText) { _, newValue in
                            scheduleHandleInputProcessing(for: newValue)
                        }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            
            if !unresolvedHandleTokens.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Resolve all handles before sending")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
                
                Text(unresolvedHandleTokens.map { "@\($0)" }.joined(separator: ", "))
                    .font(.roundedCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Search Results Section
    
    private var searchResultsSection: some View {
        List {
            if !existingConversationMatches.isEmpty {
                Section("Existing conversations") {
                    ForEach(existingConversationMatches) { groupedConversation in
                        NavigationLink {
                            GroupedConversationDetailView(groupedConversation: groupedConversation)
                        } label: {
                            GroupedConversationRow(groupedConversation: groupedConversation)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            if isSearchingSuggestions && searchResults.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if searchResults.isEmpty && hasActiveSearchToken && !isSearchingSuggestions {
                Text("No users found")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(searchResults) { account in
                Button {
                    addRecipient(account)
                } label: {
                    UserSearchRow(account: account, isSelected: selectedRecipients.contains { $0.id == account.id })
                }
                .listRowBackground(Color.clear)
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
        }
        
        let resolvedCandidates = ConversationGroupingHelper.normalizedHandleCandidates(for: account)
        unresolvedHandleTokens.removeAll { resolvedCandidates.contains($0) }
        searchResults = []
        rebuildSearchText(unresolvedTokens: unresolvedHandleTokens, activeToken: nil)
        isSearchFocused = false
        refreshExistingConversationMatches()
    }
    
    private func removeRecipient(_ account: MastodonAccount) {
        withAnimation {
            selectedRecipients.removeAll { $0.id == account.id }
        }
        refreshExistingConversationMatches()
    }
    
    private func scheduleHandleInputProcessing(for query: String) {
        searchTask?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        searchTask = Task {
            await processHandleInput(query: query, generation: generation)
        }
    }

    private func processHandleInput(query: String, generation: Int) async {
        guard !Task.isCancelled else { return }
        let tokens = HandleInputParser.tokenize(query)
        let currentUserId = appState.currentAccount?.mastodonAccount.id

        var completedTokens: [(raw: String, normalized: String)] = []
        var seenCompletedTokens = Set<String>()
        for rawToken in tokens.completedTokens {
            guard let normalized = HandleInputParser.normalizeHandle(rawToken) else { continue }
            guard seenCompletedTokens.insert(normalized).inserted else { continue }
            completedTokens.append((raw: rawToken, normalized: normalized))
        }

        let rawActiveToken = tokens.activeToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedActiveToken = rawActiveToken.flatMap(HandleInputParser.normalizeHandle)
        if let rawActiveToken, normalizedActiveToken != nil {
            if generation == searchGeneration {
                isSearchingSuggestions = true
            }

            do {
                let results = try await searchAccountsForToken(rawToken: rawActiveToken, limit: 15)
                guard generation == searchGeneration, !Task.isCancelled else { return }
                searchResults = filteredSearchResults(results, currentUserId: currentUserId)
            } catch is CancellationError {
                return
            } catch {
                guard generation == searchGeneration else { return }
                searchResults = []
            }
        } else {
            if generation == searchGeneration {
                searchResults = []
            }
        }

        if generation == searchGeneration {
            isSearchingSuggestions = false
        }

        var knownHandles = Set<String>()
        for recipient in selectedRecipients {
            knownHandles.formUnion(ConversationGroupingHelper.normalizedHandleCandidates(for: recipient))
        }

        var autoResolvedRecipients: [MastodonAccount] = []
        var unresolved: [String] = []
        var unresolvedSuggestions: [MastodonAccount] = []

        for token in completedTokens {
            let normalizedToken = token.normalized
            guard !Task.isCancelled else { return }
            guard !knownHandles.contains(normalizedToken) else { continue }

            do {
                let results = try await searchAccountsForToken(rawToken: token.raw, limit: 15)
                guard generation == searchGeneration, !Task.isCancelled else { return }

                let filteredResults = filteredSearchResults(
                    results,
                    currentUserId: currentUserId,
                    additionalExcludedIds: Set(autoResolvedRecipients.map(\.id))
                )
                let exactMatches = exactMatches(
                    for: normalizedToken,
                    in: filteredResults
                )

                if exactMatches.count == 1, let match = exactMatches.first {
                    autoResolvedRecipients.append(match)
                    knownHandles.formUnion(ConversationGroupingHelper.normalizedHandleCandidates(for: match))
                } else {
                    unresolved.append(normalizedToken)
                    unresolvedSuggestions = filteredResults
                }
            } catch is CancellationError {
                return
            } catch {
                unresolved.append(normalizedToken)
            }
        }

        guard generation == searchGeneration, !Task.isCancelled else { return }

        if !autoResolvedRecipients.isEmpty {
            withAnimation {
                for account in autoResolvedRecipients where !selectedRecipients.contains(where: { $0.id == account.id }) {
                    selectedRecipients.append(account)
                }
            }
        }

        unresolvedHandleTokens = deduplicated(unresolved)
        if tokens.activeToken == nil {
            searchResults = unresolvedSuggestions
        }

        rebuildSearchText(
            unresolvedTokens: unresolvedHandleTokens,
            activeToken: tokens.activeToken
        )
        refreshExistingConversationMatches()
    }
    
    private func filteredSearchResults(
        _ results: [MastodonAccount],
        currentUserId: String?,
        additionalExcludedIds: Set<String> = []
    ) -> [MastodonAccount] {
        results.filter { account in
            account.id != currentUserId &&
            !selectedRecipients.contains(where: { $0.id == account.id }) &&
            !additionalExcludedIds.contains(account.id)
        }
    }
    
    private func exactMatches(for normalizedHandle: String, in results: [MastodonAccount]) -> [MastodonAccount] {
        results.filter { account in
            ConversationGroupingHelper
                .normalizedHandleCandidates(for: account)
                .contains(normalizedHandle)
        }
    }

    private func searchAccountsForToken(rawToken: String, limit: Int) async throws -> [MastodonAccount] {
        let queries = HandleInputParser.searchQueryVariants(for: rawToken)
        let normalizedToken = HandleInputParser.normalizeHandle(rawToken)
        guard !queries.isEmpty || normalizedToken != nil else { return [] }
        guard let account = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            throw FediReaderError.noActiveAccount
        }

        var mergedResults: [MastodonAccount] = []
        var seenIds = Set<String>()
        var hasSuccess = false
        var lastError: Error?

        if let normalizedToken, normalizedToken.contains("@") {
            do {
                let matchedAccount = try await appState.client.lookupAccount(
                    instance: account.instance,
                    accessToken: token,
                    acct: normalizedToken
                )
                hasSuccess = true
                if seenIds.insert(matchedAccount.id).inserted {
                    mergedResults.append(matchedAccount)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        for query in queries {
            do {
                let results = try await appState.client.search(
                    instance: account.instance,
                    accessToken: token,
                    query: query,
                    type: "accounts",
                    limit: limit
                ).accounts
                hasSuccess = true
                for account in results where seenIds.insert(account.id).inserted {
                    mergedResults.append(account)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        if !hasSuccess, let lastError {
            throw lastError
        }

        return mergedResults
    }
    
    private func rebuildSearchText(unresolvedTokens: [String], activeToken: String?) {
        var components = unresolvedTokens.map { "@\($0)" }
        if let activeToken, !activeToken.isEmpty {
            components.append(activeToken)
        }

        var rebuilt = components.joined(separator: " ")
        if !unresolvedTokens.isEmpty && (activeToken == nil || activeToken?.isEmpty == true) {
            rebuilt.append(" ")
        }

        if rebuilt != searchText {
            searchText = rebuilt
        }
    }
    
    private func refreshExistingConversationMatches() {
        guard !selectedRecipients.isEmpty else {
            existingConversationMatches = []
            return
        }
        guard let currentAccountId = appState.currentAccount?.mastodonAccount.id,
              let conversations = timelineService?.conversations else {
            existingConversationMatches = []
            return
        }

        let grouped = ConversationGroupingHelper.groupedConversations(
            from: conversations,
            currentAccountId: currentAccountId
        )
        let handleSet = ConversationGroupingHelper.normalizedHandleSet(for: selectedRecipients)
        existingConversationMatches = ConversationGroupingHelper.exactParticipantMatches(
            in: grouped,
            normalizedHandleSet: handleSet
        )
    }
    
    private func deduplicated(_ values: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for value in values {
            if seen.insert(value).inserted {
                result.append(value)
            }
        }
        return result
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
            let mentions = DirectMessageMentionFormatter.mentionPrefix(for: selectedRecipients)
            let body = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            let fullContent = "\(mentions) \(body)"
            
            // Post as a direct message
            _ = try await appState.client.postStatus(
                instance: account.instance,
                accessToken: token,
                status: fullContent,
                sensitive: false,
                spoilerText: nil,
                visibility: .direct
            )

            // Clear composer state immediately after successful send.
            messageText = ""
            searchText = ""
            selectedRecipients = []
            unresolvedHandleTokens = []
            existingConversationMatches = []
            searchResults = []
            isSearchFocused = false

            await timelineService?.refreshConversations()
            
            dismiss()
        } catch {
            self.error = error
        }
    }
}

// MARK: - Recipient Chip



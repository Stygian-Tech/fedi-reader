import Foundation

enum ConversationGroupingHelper {
    static func groupedConversations(
        from conversations: [MastodonConversation],
        currentAccountId: String
    ) -> [GroupedConversation] {
        var oneOnOneGrouped: [String: (account: MastodonAccount, conversations: [MastodonConversation])] = [:]
        var groupChats: [String: (participants: [MastodonAccount], conversations: [MastodonConversation])] = [:]

        for conversation in conversations {
            let otherParticipants = conversation.accounts.filter { $0.id != currentAccountId }

            if otherParticipants.count > 1 {
                let participantIds = otherParticipants.map { $0.id }.sorted().joined(separator: "-")
                let groupId = "group-\(participantIds)"

                if var existing = groupChats[groupId] {
                    existing.conversations.append(conversation)
                    groupChats[groupId] = existing
                } else {
                    groupChats[groupId] = (participants: otherParticipants, conversations: [conversation])
                }
            } else if let otherAccount = otherParticipants.first ?? conversation.accounts.first {
                if var existing = oneOnOneGrouped[otherAccount.id] {
                    existing.conversations.append(conversation)
                    oneOnOneGrouped[otherAccount.id] = existing
                } else {
                    oneOnOneGrouped[otherAccount.id] = (account: otherAccount, conversations: [conversation])
                }
            }
        }

        var result: [GroupedConversation] = []

        for (id, data) in oneOnOneGrouped {
            result.append(GroupedConversation(
                id: id,
                participants: [data.account],
                conversations: data.conversations,
                isGroupChat: false
            ))
        }

        for (id, data) in groupChats {
            result.append(GroupedConversation(
                id: id,
                participants: data.participants,
                conversations: data.conversations,
                isGroupChat: true
            ))
        }

        return result.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    static func exactParticipantMatches(
        in grouped: [GroupedConversation],
        normalizedHandleSet: Set<String>
    ) -> [GroupedConversation] {
        guard !normalizedHandleSet.isEmpty else { return [] }

        return grouped.filter { conversation in
            Self.normalizedHandleSet(for: conversation.participants) == normalizedHandleSet
        }
    }

    static func normalizedHandleSet(for accounts: [MastodonAccount]) -> Set<String> {
        Set(accounts.compactMap { canonicalNormalizedHandle(for: $0) })
    }

    static func normalizedHandleCandidates(for account: MastodonAccount) -> Set<String> {
        var candidates = Set<String>()

        if let acct = HandleInputParser.normalizeHandle(account.acct) {
            candidates.insert(acct)
        }

        if let username = HandleInputParser.normalizeHandle(account.username) {
            candidates.insert(username)
        }

        if let host = URL(string: account.url)?.host?.lowercased() {
            if let acct = HandleInputParser.normalizeHandle(account.acct), !acct.contains("@") {
                candidates.insert("\(acct)@\(host)")
            }
            if let username = HandleInputParser.normalizeHandle(account.username) {
                candidates.insert("\(username)@\(host)")
            }
        }

        return candidates
    }

    private static func canonicalNormalizedHandle(for account: MastodonAccount) -> String? {
        let candidates = normalizedHandleCandidates(for: account)
        guard !candidates.isEmpty else { return nil }

        if let fullHandle = candidates.sorted().first(where: { $0.contains("@") }) {
            return fullHandle
        }

        return candidates.sorted().first
    }
}



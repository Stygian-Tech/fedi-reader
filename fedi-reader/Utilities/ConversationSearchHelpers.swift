//
//  ConversationSearchHelpers.swift
//  fedi-reader
//
//  Shared helpers for PM handle parsing, conversation grouping, and DM mentions.
//

import Foundation

struct HandleInputTokens {
    let completedTokens: [String]
    let activeToken: String?
}

enum HandleInputParser {
    private static let delimiters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))

    static func tokenize(_ input: String) -> HandleInputTokens {
        let tokens = input
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return HandleInputTokens(completedTokens: [], activeToken: nil)
        }

        let endsWithDelimiter = input.unicodeScalars.last.map { delimiters.contains($0) } ?? false
        if endsWithDelimiter {
            return HandleInputTokens(completedTokens: tokens, activeToken: nil)
        }

        return HandleInputTokens(
            completedTokens: Array(tokens.dropLast()),
            activeToken: tokens.last
        )
    }

    static func normalizeHandle(_ raw: String) -> String? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        while cleaned.hasPrefix("@") {
            cleaned.removeFirst()
        }

        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        guard !cleaned.isEmpty else { return nil }

        return cleaned.lowercased()
    }

    static func searchQueryVariants(for rawToken: String) -> [String] {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var variants: [String] = []
        func appendUnique(_ value: String) {
            guard !value.isEmpty, !variants.contains(value) else { return }
            variants.append(value)
        }

        appendUnique(trimmed)

        guard let normalized = normalizeHandle(trimmed) else {
            return variants
        }

        appendUnique(normalized)

        if trimmed.hasPrefix("@") || normalized.contains("@") {
            appendUnique("@\(normalized)")
        }

        if let atIndex = normalized.firstIndex(of: "@"), atIndex > normalized.startIndex {
            let usernameOnly = String(normalized[..<atIndex])
            appendUnique(usernameOnly)
        }

        return variants
    }
}

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

enum DirectMessageMentionFormatter {
    static func mentionPrefix(for recipients: [MastodonAccount]) -> String {
        var mentions: [String] = []
        var seenHandles = Set<String>()

        for recipient in recipients {
            guard let normalized = HandleInputParser.normalizeHandle(recipient.acct) else { continue }
            guard seenHandles.insert(normalized).inserted else { continue }
            mentions.append("@\(normalized)")
        }

        return mentions.joined(separator: " ")
    }
}

import Foundation

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


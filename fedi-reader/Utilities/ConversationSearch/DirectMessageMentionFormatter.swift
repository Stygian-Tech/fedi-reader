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

    static func hiddenHandles(for accounts: [MastodonAccount]) -> Set<String> {
        var handles = Set<String>()

        for account in accounts {
            insertHandleVariants(from: account.acct, into: &handles)
            insertHandleVariants(from: account.username, into: &handles)
        }

        return handles
    }

    static func stripLeadingMentions(from text: String, hiddenHandles: Set<String>) -> String {
        guard
            !hiddenHandles.isEmpty,
            let prefix = leadingMentionPrefix(in: text, hiddenHandles: hiddenHandles)
        else {
            return text
        }

        return String(text.dropFirst(prefix.count))
    }

    @available(iOS 15.0, macOS 12.0, *)
    static func stripLeadingMentions(
        from attributedString: AttributedString,
        hiddenHandles: Set<String>
    ) -> AttributedString {
        guard !hiddenHandles.isEmpty else {
            return attributedString
        }

        let plainText = String(attributedString.characters)
        guard
            let prefix = leadingMentionPrefix(in: plainText, hiddenHandles: hiddenHandles),
            let range = attributedString.range(of: prefix, options: [.anchored])
        else {
            return attributedString
        }

        var stripped = attributedString
        stripped.removeSubrange(range)
        return stripped
    }

    private static func insertHandleVariants(from rawHandle: String, into handles: inout Set<String>) {
        guard let normalized = HandleInputParser.normalizeHandle(rawHandle) else { return }
        handles.insert(normalized)

        if let atIndex = normalized.firstIndex(of: "@"), atIndex > normalized.startIndex {
            handles.insert(String(normalized[..<atIndex]))
        }
    }

    private static func leadingMentionPrefix(in text: String, hiddenHandles: Set<String>) -> String? {
        var index = text.startIndex
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }

        var matchedMention = false

        while index < text.endIndex {
            guard text[index] == "@" else { break }

            let tokenStart = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }

            let token = String(text[tokenStart..<index])
            guard
                let normalized = HandleInputParser.normalizeHandle(token),
                hiddenHandles.contains(normalized)
            else {
                break
            }

            matchedMention = true

            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
        }

        guard matchedMention else { return nil }
        return String(text[..<index])
    }
}

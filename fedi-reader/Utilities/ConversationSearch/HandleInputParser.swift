import Foundation

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



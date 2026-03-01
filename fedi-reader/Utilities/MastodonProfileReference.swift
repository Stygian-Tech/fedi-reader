import Foundation

enum MastodonProfileReference {
    nonisolated static func normalizedAcct(from handle: String) -> String? {
        let trimmed = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutLeadingAt = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let parts = withoutLeadingAt.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }

        return "\(parts[0])@\(parts[1].lowercased())"
    }

    nonisolated static func acct(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard !pathComponents.isEmpty else { return nil }

        let username: String?
        if let first = pathComponents.first, first.hasPrefix("@"), first.count > 1 {
            username = String(first.dropFirst())
        } else if pathComponents.count >= 2, pathComponents[0].caseInsensitiveCompare("users") == .orderedSame {
            username = pathComponents[1]
        } else {
            username = nil
        }

        guard let username,
              let decodedUsername = username.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !decodedUsername.isEmpty else {
            return nil
        }

        return "\(decodedUsername)@\(host)"
    }

    nonisolated static func acct(handle: String?, profileURL: URL?) -> String? {
        if let handle, let acct = normalizedAcct(from: handle) {
            return acct
        }

        if let profileURL, let acct = acct(from: profileURL) {
            return acct
        }

        return nil
    }
}

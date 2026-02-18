import Foundation

struct SearchResults: Codable, Sendable {
    let accounts: [MastodonAccount]
    let statuses: [Status]
    let hashtags: [Tag]
}

// MARK: - Async Refresh Header

/// Parsed `Mastodon-Async-Refresh` header: `id="<string>", retry=<int>, result_count=<int>` (result_count optional).


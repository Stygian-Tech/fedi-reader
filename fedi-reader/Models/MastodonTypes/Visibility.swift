import Foundation

enum Visibility: String, Codable, Sendable {
    case `public`
    case unlisted
    case `private`
    case direct
}

// MARK: - Account (Remote Mastodon Account)



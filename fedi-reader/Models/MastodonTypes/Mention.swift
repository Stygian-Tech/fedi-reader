import Foundation

struct Mention: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String
    let acct: String
    let url: String
}

// MARK: - Tag (Hashtag)



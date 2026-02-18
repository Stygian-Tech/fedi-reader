import Foundation

struct MastodonConversation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let unread: Bool?
    let accounts: [MastodonAccount]
    let lastStatus: Status?

    enum CodingKeys: String, CodingKey {
        case id, unread, accounts
        case lastStatus = "last_status"
    }
}

// MARK: - Context (Thread)



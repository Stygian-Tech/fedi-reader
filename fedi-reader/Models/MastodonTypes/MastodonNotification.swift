import Foundation

struct MastodonNotification: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: NotificationType
    let createdAt: Date
    let account: MastodonAccount
    let status: Status?
    
    enum CodingKeys: String, CodingKey {
        case id, type, account, status
        case createdAt = "created_at"
    }
}



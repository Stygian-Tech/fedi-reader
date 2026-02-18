import Foundation

struct Relationship: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let following: Bool
    let showingReblogs: Bool
    let notifying: Bool
    let followedBy: Bool
    let blocking: Bool
    let blockedBy: Bool
    let muting: Bool
    let mutingNotifications: Bool
    let requested: Bool
    let domainBlocking: Bool
    let endorsed: Bool
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case id, following, notifying, blocking, muting, requested, endorsed, note
        case showingReblogs = "showing_reblogs"
        case followedBy = "followed_by"
        case blockedBy = "blocked_by"
        case mutingNotifications = "muting_notifications"
        case domainBlocking = "domain_blocking"
    }
}

// MARK: - Instance Info



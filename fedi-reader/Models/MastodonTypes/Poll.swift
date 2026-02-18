import Foundation

struct Poll: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let expiresAt: Date?
    let expired: Bool
    let multiple: Bool
    let votesCount: Int
    let votersCount: Int?
    let options: [PollOption]
    let voted: Bool?
    let ownVotes: [Int]?
    let emojis: [CustomEmoji]
    
    enum CodingKeys: String, CodingKey {
        case id, expired, multiple, options, voted, emojis
        case expiresAt = "expires_at"
        case votesCount = "votes_count"
        case votersCount = "voters_count"
        case ownVotes = "own_votes"
    }
}



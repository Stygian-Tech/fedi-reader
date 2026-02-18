import Foundation

struct PollOption: Codable, Hashable, Sendable {
    let title: String
    let votesCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case title
        case votesCount = "votes_count"
    }
}

// MARK: - Application



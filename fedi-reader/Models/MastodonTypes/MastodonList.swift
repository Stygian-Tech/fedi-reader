import Foundation

struct MastodonList: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let repliesPolicy: RepliesPolicy?
    let exclusive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, exclusive
        case repliesPolicy = "replies_policy"
    }
}



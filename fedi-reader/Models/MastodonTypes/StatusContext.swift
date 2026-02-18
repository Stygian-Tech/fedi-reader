import Foundation

struct StatusContext: Codable, Sendable {
    let ancestors: [Status]
    let descendants: [Status]
    let hasMoreReplies: Bool?
    let asyncRefreshId: String?
    
    enum CodingKeys: String, CodingKey {
        case ancestors, descendants
        case hasMoreReplies = "has_more_replies"
        case asyncRefreshId = "async_refresh_id"
    }
    
    init(ancestors: [Status], descendants: [Status], hasMoreReplies: Bool? = nil, asyncRefreshId: String? = nil) {
        self.ancestors = ancestors
        self.descendants = descendants
        self.hasMoreReplies = hasMoreReplies
        self.asyncRefreshId = asyncRefreshId
    }
}

// MARK: - Author Attribution



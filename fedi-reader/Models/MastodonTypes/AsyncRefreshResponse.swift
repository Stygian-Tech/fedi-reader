import Foundation

struct AsyncRefreshResponse: Codable, Sendable {
    let asyncRefresh: AsyncRefresh
    
    enum CodingKeys: String, CodingKey {
        case asyncRefresh = "async_refresh"
    }
}

// MARK: - Status Context



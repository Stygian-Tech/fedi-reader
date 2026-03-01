import Foundation

struct AsyncRefreshResponse: Codable, Sendable {
    let asyncRefresh: AsyncRefresh
    
    enum CodingKeys: String, CodingKey {
        case asyncRefresh = "async_refresh"
    }

    nonisolated init(asyncRefresh: AsyncRefresh) {
        self.asyncRefresh = asyncRefresh
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asyncRefresh = try container.decode(AsyncRefresh.self, forKey: .asyncRefresh)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(asyncRefresh, forKey: .asyncRefresh)
    }
}

// MARK: - Status Context


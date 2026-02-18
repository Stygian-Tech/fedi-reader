import Foundation

struct InstanceURLs: Codable, Sendable {
    let streamingApi: String?
    
    enum CodingKeys: String, CodingKey {
        case streamingApi = "streaming_api"
    }
}



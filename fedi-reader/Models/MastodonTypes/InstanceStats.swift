import Foundation

struct InstanceStats: Codable, Sendable {
    let userCount: Int?
    let statusCount: Int?
    let domainCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case userCount = "user_count"
        case statusCount = "status_count"
        case domainCount = "domain_count"
    }
}



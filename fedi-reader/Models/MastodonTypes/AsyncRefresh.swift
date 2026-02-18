import Foundation

struct AsyncRefresh: Codable, Sendable {
    let id: String
    let status: String // "running" | "finished"
    let resultCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case resultCount = "result_count"
    }
    
    init(id: String, status: String, resultCount: Int? = nil) {
        self.id = id
        self.status = status
        self.resultCount = resultCount
    }
}



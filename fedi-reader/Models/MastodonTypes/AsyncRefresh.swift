import Foundation

struct AsyncRefresh: Codable, Sendable {
    let id: String
    let status: String // "running" | "finished"
    let resultCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case resultCount = "result_count"
    }
    
    nonisolated init(id: String, status: String, resultCount: Int? = nil) {
        self.id = id
        self.status = status
        self.resultCount = resultCount
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        resultCount = try container.decodeIfPresent(Int.self, forKey: .resultCount)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(resultCount, forKey: .resultCount)
    }
}


import Foundation

struct Tag: Codable, Hashable, Sendable {
    let id: String?
    let name: String
    let url: String
    let history: [TagHistory]?
    let following: Bool?

    init(id: String? = nil, name: String, url: String, history: [TagHistory]? = nil, following: Bool? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.history = history
        self.following = following
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        url = try c.decode(String.self, forKey: .url)
        history = try c.decodeIfPresent([TagHistory].self, forKey: .history)
        following = try c.decodeIfPresent(Bool.self, forKey: .following)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, url, history, following
    }
}



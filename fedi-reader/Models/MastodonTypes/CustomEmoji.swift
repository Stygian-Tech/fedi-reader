import Foundation

struct CustomEmoji: Codable, Hashable, Sendable {
    let shortcode: String
    let url: String
    let staticUrl: String
    let visibleInPicker: Bool
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case shortcode, url, category
        case staticUrl = "static_url"
        case visibleInPicker = "visible_in_picker"
    }

    init(
        shortcode: String,
        url: String,
        staticUrl: String,
        visibleInPicker: Bool,
        category: String?
    ) {
        self.shortcode = shortcode
        self.url = url
        self.staticUrl = staticUrl
        self.visibleInPicker = visibleInPicker
        self.category = category
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortcode = try container.decode(String.self, forKey: .shortcode)
        url = try container.decode(String.self, forKey: .url)
        staticUrl = try container.decode(String.self, forKey: .staticUrl)
        visibleInPicker = try container.decode(Bool.self, forKey: .visibleInPicker)
        category = try container.decodeIfPresent(String.self, forKey: .category)
    }
}

// MARK: - Poll

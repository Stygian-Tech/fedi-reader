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
}

// MARK: - Poll



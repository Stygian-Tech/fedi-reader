import Foundation

struct StatusConfiguration: Codable, Sendable {
    let maxCharacters: Int?
    let maxMediaAttachments: Int?
    let charactersReservedPerUrl: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxCharacters = "max_characters"
        case maxMediaAttachments = "max_media_attachments"
        case charactersReservedPerUrl = "characters_reserved_per_url"
    }
}



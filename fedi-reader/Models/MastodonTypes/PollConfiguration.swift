import Foundation

struct PollConfiguration: Codable, Sendable {
    let maxOptions: Int?
    let maxCharactersPerOption: Int?
    let minExpiration: Int?
    let maxExpiration: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxOptions = "max_options"
        case maxCharactersPerOption = "max_characters_per_option"
        case minExpiration = "min_expiration"
        case maxExpiration = "max_expiration"
    }
}



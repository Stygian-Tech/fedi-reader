import Foundation

struct Tag: Codable, Hashable, Sendable {
    let name: String
    let url: String
    let history: [TagHistory]?
}



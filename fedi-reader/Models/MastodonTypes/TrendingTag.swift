import Foundation

struct TrendingTag: Codable, Hashable, Sendable {
    let name: String
    let url: String
    let history: [TagHistory]
}

// MARK: - OAuth Types



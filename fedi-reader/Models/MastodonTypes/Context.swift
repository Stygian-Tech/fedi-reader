import Foundation

struct Context: Codable, Sendable {
    let ancestors: [Status]
    let descendants: [Status]
}

// MARK: - Relationship



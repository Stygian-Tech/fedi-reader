import Foundation

struct AccountSource: Codable, Hashable, Sendable {
    let note: String?
    let fields: [Field]?
}

// MARK: - Field (Profile fields)



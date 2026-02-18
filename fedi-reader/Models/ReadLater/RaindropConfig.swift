import Foundation
import SwiftData

struct RaindropConfig: Codable, Sendable {
    var collectionId: Int? // Default collection to save to
    var defaultTags: [String]?
}

// MARK: - Save Result



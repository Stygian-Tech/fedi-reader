import Foundation
import SwiftData

struct OmnivoreConfig: Codable, Sendable {
    var apiKey: String
    var labels: [String]?
}



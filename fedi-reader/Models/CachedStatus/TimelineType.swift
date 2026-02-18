import Foundation
import SwiftData

enum TimelineType: String, CaseIterable, Sendable {
    case home
    case mentions
    case explore
    case links // Filtered link feed
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .mentions: return "Messages"
        case .explore: return "Explore"
        case .links: return "Links"
        }
    }
    
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .mentions: return "at"
        case .explore: return "globe"
        case .links: return "link"
        }
    }
}


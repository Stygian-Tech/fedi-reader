import Foundation
import SwiftData

enum ReadLaterServiceType: String, CaseIterable, Sendable, Identifiable {
    case pocket
    case instapaper
    case omnivore
    case readwise
    case raindrop
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pocket: return "Pocket"
        case .instapaper: return "Instapaper"
        case .omnivore: return "Omnivore"
        case .readwise: return "Readwise Reader"
        case .raindrop: return "Raindrop.io"
        }
    }
    
    var iconName: String {
        switch self {
        case .pocket: return "bag"
        case .instapaper: return "doc.text"
        case .omnivore: return "books.vertical"
        case .readwise: return "text.book.closed"
        case .raindrop: return "drop"
        }
    }
    
    var authURL: String {
        switch self {
        case .pocket: return "https://getpocket.com/v3/oauth/request"
        case .instapaper: return "https://www.instapaper.com/api/1/oauth/access_token"
        case .omnivore: return "https://omnivore.app/api/auth"
        case .readwise: return "https://readwise.io/api/v3/"
        case .raindrop: return "https://raindrop.io/oauth/authorize"
        }
    }
    
    var requiresOAuth: Bool {
        switch self {
        case .pocket, .raindrop: return true
        case .instapaper: return true // xAuth
        case .omnivore, .readwise: return false // API key based
        }
    }
    
    var supportsTagging: Bool {
        switch self {
        case .pocket, .instapaper, .omnivore, .raindrop: return true
        case .readwise: return false
        }
    }
}

// MARK: - Service Configuration Types



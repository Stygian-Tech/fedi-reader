//
//  ReadLaterConfig.swift
//  fedi-reader
//
//  Configuration for read-later service integrations
//

import Foundation
import SwiftData

@Model
final class ReadLaterConfig {
    @Attribute(.unique) var id: String
    var serviceType: String // ReadLaterServiceType raw value
    var isEnabled: Bool
    var isPrimary: Bool // Primary service for quick-save
    var lastSyncedAt: Date?
    var createdAt: Date
    
    // Service-specific configuration (stored as JSON)
    var configData: Data?
    
    init(
        id: String = UUID().uuidString,
        serviceType: String,
        isEnabled: Bool = true,
        isPrimary: Bool = false,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        configData: Data? = nil
    ) {
        self.id = id
        self.serviceType = serviceType
        self.isEnabled = isEnabled
        self.isPrimary = isPrimary
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.configData = configData
    }
    
    var service: ReadLaterServiceType? {
        ReadLaterServiceType(rawValue: serviceType)
    }
    
    // Access token stored in Keychain
    var accessTokenKey: String {
        "fedi-reader.readlater.\(serviceType).\(id)"
    }
}

// MARK: - Read Later Service Types

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

struct PocketConfig: Codable, Sendable {
    var consumerKey: String
    var username: String?
}

struct InstapaperConfig: Codable, Sendable {
    var username: String
    var oauthToken: String?
    var oauthTokenSecret: String?
}

struct OmnivoreConfig: Codable, Sendable {
    var apiKey: String
    var labels: [String]?
}

struct ReadwiseConfig: Codable, Sendable {
    var accessToken: String
}

struct RaindropConfig: Codable, Sendable {
    var collectionId: Int? // Default collection to save to
    var defaultTags: [String]?
}

// MARK: - Save Result

struct ReadLaterSaveResult: Sendable {
    let success: Bool
    let url: URL
    let serviceType: ReadLaterServiceType
    let itemId: String?
    let error: Error?
    
    static func success(url: URL, service: ReadLaterServiceType, itemId: String? = nil) -> ReadLaterSaveResult {
        ReadLaterSaveResult(success: true, url: url, serviceType: service, itemId: itemId, error: nil)
    }
    
    static func failure(url: URL, service: ReadLaterServiceType, error: Error) -> ReadLaterSaveResult {
        ReadLaterSaveResult(success: false, url: url, serviceType: service, itemId: nil, error: error)
    }
}

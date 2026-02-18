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


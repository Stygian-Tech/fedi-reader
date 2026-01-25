//
//  ReadLaterManager.swift
//  fedi-reader
//
//  Unified read-later service management
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class ReadLaterManager {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ReadLater")
    private let keychain: KeychainHelper
    
    var configuredServices: [ReadLaterConfig] = []
    var primaryService: ReadLaterConfig?
    var isLoading = false
    var lastSaveResult: ReadLaterSaveResult?
    
    // Individual services
    private var pocketService: PocketService?
    private var instapaperService: InstapaperService?
    private var omnivoreService: OmnivoreService?
    private var readwiseService: ReadwiseService?
    private var raindropService: RaindropService?
    
    init(keychain: KeychainHelper = .shared) {
        self.keychain = keychain
    }
    
    var hasConfiguredServices: Bool {
        !configuredServices.isEmpty
    }
    
    // MARK: - Configuration Loading
    
    func loadConfigurations(from modelContext: ModelContext) {
        Self.logger.info("Loading read-later service configurations")
        let descriptor = FetchDescriptor<ReadLaterConfig>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        do {
            configuredServices = try modelContext.fetch(descriptor)
            primaryService = configuredServices.first(where: { $0.isPrimary }) ?? configuredServices.first
            
            Self.logger.info("Loaded \(self.configuredServices.count) read-later service configurations, primary: \(self.primaryService?.service?.rawValue ?? "none", privacy: .public)")
            
            // Initialize services for configured configs
            for config in configuredServices {
                initializeService(for: config)
            }
        } catch {
            Self.logger.error("Failed to load read-later configs: \(error.localizedDescription)")
        }
    }
    
    private func initializeService(for config: ReadLaterConfig) {
        guard let serviceType = config.service else { return }
        
        switch serviceType {
        case .pocket:
            pocketService = PocketService(config: config, keychain: keychain)
        case .instapaper:
            instapaperService = InstapaperService(config: config, keychain: keychain)
        case .omnivore:
            omnivoreService = OmnivoreService(config: config, keychain: keychain)
        case .readwise:
            readwiseService = ReadwiseService(config: config, keychain: keychain)
        case .raindrop:
            raindropService = RaindropService(config: config, keychain: keychain)
        }
    }
    
    // MARK: - Save to Service
    
    func save(url: URL, title: String?, to serviceType: ReadLaterServiceType) async throws {
        Self.logger.info("Saving to read-later service: \(serviceType.rawValue, privacy: .public), URL: \(url.absoluteString, privacy: .public), title: \(title ?? "nil", privacy: .public)")
        isLoading = true
        defer { isLoading = false }
        
        let result: ReadLaterSaveResult
        
        do {
            switch serviceType {
            case .pocket:
                guard let service = pocketService else {
                    Self.logger.error("Pocket service not configured")
                    throw FediReaderError.readLaterError("Pocket not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .instapaper:
                guard let service = instapaperService else {
                    Self.logger.error("Instapaper service not configured")
                    throw FediReaderError.readLaterError("Instapaper not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .omnivore:
                guard let service = omnivoreService else {
                    Self.logger.error("Omnivore service not configured")
                    throw FediReaderError.readLaterError("Omnivore not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .readwise:
                guard let service = readwiseService else {
                    Self.logger.error("Readwise service not configured")
                    throw FediReaderError.readLaterError("Readwise not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .raindrop:
                guard let service = raindropService else {
                    Self.logger.error("Raindrop service not configured")
                    throw FediReaderError.readLaterError("Raindrop not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
            }
            
            Self.logger.info("Successfully saved to \(serviceType.rawValue, privacy: .public)")
            lastSaveResult = result
            NotificationCenter.default.post(name: .readLaterDidSave, object: result)
        } catch {
            Self.logger.error("Failed to save to \(serviceType.rawValue, privacy: .public): \(error.localizedDescription)")
            lastSaveResult = .failure(url: url, service: serviceType, error: error)
            throw error
        }
    }
    
    // MARK: - Service Configuration
    
    func configureService(
        _ serviceType: ReadLaterServiceType,
        token: String,
        additionalConfig: Data? = nil,
        modelContext: ModelContext
    ) async throws {
        Self.logger.info("Configuring read-later service: \(serviceType.rawValue, privacy: .public)")
        let config = ReadLaterConfig(
            serviceType: serviceType.rawValue,
            configData: additionalConfig
        )
        
        // Save token to keychain
        try await keychain.saveReadLaterToken(token, forService: serviceType, configId: config.id)
        Self.logger.debug("Saved token to Keychain for service: \(serviceType.rawValue, privacy: .public)")
        
        // Save config to SwiftData
        modelContext.insert(config)
        try modelContext.save()
        
        // Update local state
        configuredServices.append(config)
        if primaryService == nil {
            primaryService = config
            config.isPrimary = true
            Self.logger.info("Set as primary service: \(serviceType.rawValue, privacy: .public)")
        }
        
        // Initialize service
        initializeService(for: config)
        Self.logger.info("Service configured successfully: \(serviceType.rawValue, privacy: .public)")
    }
    
    func removeService(_ config: ReadLaterConfig, modelContext: ModelContext) async throws {
        guard let serviceType = config.service else {
            Self.logger.warning("Attempted to remove service with invalid type")
            return
        }
        
        Self.logger.info("Removing read-later service: \(serviceType.rawValue, privacy: .public)")
        
        // Remove token from keychain
        try await keychain.deleteReadLaterToken(forService: serviceType, configId: config.id)
        Self.logger.debug("Removed token from Keychain")
        
        // Remove from SwiftData
        modelContext.delete(config)
        try modelContext.save()
        
        // Update local state
        configuredServices.removeAll { $0.id == config.id }
        
        if primaryService?.id == config.id {
            primaryService = configuredServices.first
            primaryService?.isPrimary = true
            Self.logger.info("Switched primary service to: \(self.primaryService?.service?.rawValue ?? "none", privacy: .public)")
        }
        
        // Clear service instance
        switch serviceType {
        case .pocket: pocketService = nil
        case .instapaper: instapaperService = nil
        case .omnivore: omnivoreService = nil
        case .readwise: readwiseService = nil
        case .raindrop: raindropService = nil
        }
        
        Self.logger.info("Service removed successfully: \(serviceType.rawValue, privacy: .public)")
    }
    
    func setPrimaryService(_ config: ReadLaterConfig, modelContext: ModelContext) {
        for existingConfig in configuredServices {
            existingConfig.isPrimary = false
        }
        
        config.isPrimary = true
        primaryService = config
        
        try? modelContext.save()
    }
}

// MARK: - Read Later Service Protocol

protocol ReadLaterServiceProtocol {
    var isAuthenticated: Bool { get }
    func authenticate() async throws
    func save(url: URL, title: String?) async throws
}

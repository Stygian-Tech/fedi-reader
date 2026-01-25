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
        let descriptor = FetchDescriptor<ReadLaterConfig>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        do {
            configuredServices = try modelContext.fetch(descriptor)
            primaryService = configuredServices.first(where: { $0.isPrimary }) ?? configuredServices.first
            
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
        isLoading = true
        defer { isLoading = false }
        
        let result: ReadLaterSaveResult
        
        do {
            switch serviceType {
            case .pocket:
                guard let service = pocketService else {
                    throw FediReaderError.readLaterError("Pocket not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .instapaper:
                guard let service = instapaperService else {
                    throw FediReaderError.readLaterError("Instapaper not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .omnivore:
                guard let service = omnivoreService else {
                    throw FediReaderError.readLaterError("Omnivore not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .readwise:
                guard let service = readwiseService else {
                    throw FediReaderError.readLaterError("Readwise not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
                
            case .raindrop:
                guard let service = raindropService else {
                    throw FediReaderError.readLaterError("Raindrop not configured")
                }
                try await service.save(url: url, title: title)
                result = .success(url: url, service: serviceType)
            }
            
            lastSaveResult = result
            NotificationCenter.default.post(name: .readLaterDidSave, object: result)
        } catch {
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
        let config = ReadLaterConfig(
            serviceType: serviceType.rawValue,
            configData: additionalConfig
        )
        
        // Save token to keychain
        try await keychain.saveReadLaterToken(token, forService: serviceType, configId: config.id)
        
        // Save config to SwiftData
        modelContext.insert(config)
        try modelContext.save()
        
        // Update local state
        configuredServices.append(config)
        if primaryService == nil {
            primaryService = config
            config.isPrimary = true
        }
        
        // Initialize service
        initializeService(for: config)
    }
    
    func removeService(_ config: ReadLaterConfig, modelContext: ModelContext) async throws {
        guard let serviceType = config.service else { return }
        
        // Remove token from keychain
        try await keychain.deleteReadLaterToken(forService: serviceType, configId: config.id)
        
        // Remove from SwiftData
        modelContext.delete(config)
        try modelContext.save()
        
        // Update local state
        configuredServices.removeAll { $0.id == config.id }
        
        if primaryService?.id == config.id {
            primaryService = configuredServices.first
            primaryService?.isPrimary = true
        }
        
        // Clear service instance
        switch serviceType {
        case .pocket: pocketService = nil
        case .instapaper: instapaperService = nil
        case .omnivore: omnivoreService = nil
        case .readwise: readwiseService = nil
        case .raindrop: raindropService = nil
        }
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

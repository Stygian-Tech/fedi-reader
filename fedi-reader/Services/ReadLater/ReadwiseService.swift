//
//  ReadwiseService.swift
//  fedi-reader
//
//  Readwise Reader service integration
//

import Foundation
import os

final class ReadwiseService: ReadLaterServiceProtocol {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ReadLater.Readwise")
    private let config: ReadLaterConfig
    private let keychain: KeychainHelper
    private let session: URLSession
    
    private var accessToken: String?
    
    var isAuthenticated: Bool {
        accessToken != nil
    }
    
    init(config: ReadLaterConfig, keychain: KeychainHelper) {
        self.config = config
        self.keychain = keychain
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = [
            "Content-Type": "application/json"
        ]
        self.session = URLSession(configuration: sessionConfig)
        
        // Load existing token
        Task {
            accessToken = try? await keychain.getReadLaterToken(forService: .readwise, configId: config.id)
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        // Readwise uses API tokens from user settings
        throw FediReaderError.readLaterError("Use setAccessToken to configure Readwise")
    }
    
    func setAccessToken(_ token: String) async throws {
        Self.logger.info("Setting Readwise access token")
        // Verify token works
        let isValid = try await verifyToken(token)
        guard isValid else {
            Self.logger.error("Readwise token verification failed")
            throw FediReaderError.readLaterError("Invalid Readwise token")
        }
        
        accessToken = token
        try await keychain.saveReadLaterToken(token, forService: .readwise, configId: config.id)
        Self.logger.info("Readwise access token saved to Keychain")
    }
    
    private func verifyToken(_ token: String) async throws -> Bool {
        let url = URL(string: "\(Constants.ReadLater.readwiseAPIURL)/auth")!
        
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200 || httpResponse.statusCode == 204
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        Self.logger.info("Saving to Readwise: \(url.absoluteString, privacy: .public), title: \(title ?? "nil", privacy: .public)")
        guard let accessToken else {
            Self.logger.error("Readwise token not configured")
            throw FediReaderError.readLaterError("Readwise token not configured")
        }
        
        let apiURL = URL(string: Constants.ReadLater.readwiseSaveURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "url": url.absoluteString
        ]
        
        if let title {
            body["title"] = title
        }
        
        // Set category to "article" for Reader
        body["category"] = "article"
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type from Readwise")
            throw FediReaderError.readLaterError("Invalid response from Readwise")
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            Self.logger.info("Successfully saved to Readwise")
            return // Success
        case 401:
            Self.logger.error("Readwise authentication expired")
            throw FediReaderError.readLaterError("Readwise authentication expired")
        case 429:
            Self.logger.warning("Readwise rate limit exceeded")
            throw FediReaderError.readLaterError("Readwise rate limit exceeded")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            Self.logger.error("Readwise error: \(message, privacy: .public)")
            throw FediReaderError.readLaterError("Readwise error: \(message)")
        }
    }
    
    // MARK: - Additional Features
    
    func saveHighlight(url: URL, text: String, note: String? = nil) async throws {
        guard let accessToken else {
            throw FediReaderError.readLaterError("Readwise token not configured")
        }
        
        let apiURL = URL(string: "\(Constants.ReadLater.readwiseAPIURL)/highlights/")!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var highlight: [String: Any] = [
            "text": text,
            "source_url": url.absoluteString
        ]
        
        if let note {
            highlight["note"] = note
        }
        
        let body: [String: Any] = [
            "highlights": [highlight]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw FediReaderError.readLaterError("Failed to save highlight to Readwise")
        }
    }
}

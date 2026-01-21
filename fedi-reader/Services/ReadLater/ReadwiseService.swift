//
//  ReadwiseService.swift
//  fedi-reader
//
//  Readwise Reader service integration
//

import Foundation

final class ReadwiseService: ReadLaterServiceProtocol {
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
        // Verify token works
        let isValid = try await verifyToken(token)
        guard isValid else {
            throw FediReaderError.readLaterError("Invalid Readwise token")
        }
        
        accessToken = token
        try await keychain.saveReadLaterToken(token, forService: .readwise, configId: config.id)
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
        guard let accessToken else {
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
            throw FediReaderError.readLaterError("Invalid response from Readwise")
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            return // Success
        case 401:
            throw FediReaderError.readLaterError("Readwise authentication expired")
        case 429:
            throw FediReaderError.readLaterError("Readwise rate limit exceeded")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
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

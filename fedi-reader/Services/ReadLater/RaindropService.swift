//
//  RaindropService.swift
//  fedi-reader
//
//  Raindrop.io read-later service integration
//

import Foundation

final class RaindropService: ReadLaterServiceProtocol {
    private let config: ReadLaterConfig
    private let keychain: KeychainHelper
    private let session: URLSession
    
    private var accessToken: String?
    private var refreshToken: String?
    
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
        
        // Load existing tokens
        Task {
            if let tokenData = try? await keychain.getReadLaterToken(forService: .raindrop, configId: config.id) {
                let parts = tokenData.split(separator: "|")
                if parts.count >= 1 {
                    accessToken = String(parts[0])
                }
                if parts.count >= 2 {
                    refreshToken = String(parts[1])
                }
            }
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        // Raindrop uses OAuth 2.0
        // This requires app registration at https://app.raindrop.io/settings/integrations
        throw FediReaderError.readLaterError("Use OAuth flow to authenticate with Raindrop")
    }
    
    func buildAuthorizationURL(clientId: String) -> URL? {
        var components = URLComponents(string: Constants.ReadLater.raindropAuthURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: Constants.OAuth.redirectURI),
            URLQueryItem(name: "response_type", value: "code")
        ]
        return components?.url
    }
    
    func exchangeCodeForToken(code: String, clientId: String, clientSecret: String) async throws {
        let url = URL(string: Constants.ReadLater.raindropTokenURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": clientId,
            "client_secret": clientSecret,
            "redirect_uri": Constants.OAuth.redirectURI
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FediReaderError.readLaterError("Failed to get Raindrop access token")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            throw FediReaderError.readLaterError("Invalid Raindrop response")
        }
        
        accessToken = token
        refreshToken = json["refresh_token"] as? String
        
        // Store tokens
        var tokenString = token
        if let refresh = refreshToken {
            tokenString += "|\(refresh)"
        }
        
        try await keychain.saveReadLaterToken(tokenString, forService: .raindrop, configId: config.id)
    }
    
    func setAccessToken(_ token: String, refreshToken: String? = nil) async throws {
        accessToken = token
        self.refreshToken = refreshToken
        
        var tokenString = token
        if let refresh = refreshToken {
            tokenString += "|\(refresh)"
        }
        
        try await keychain.saveReadLaterToken(tokenString, forService: .raindrop, configId: config.id)
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        guard let accessToken else {
            throw FediReaderError.readLaterError("Not authenticated with Raindrop")
        }
        
        let apiURL = URL(string: "\(Constants.ReadLater.raindropAPIURL)/raindrop")!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Get collection ID from config
        let collectionId = getCollectionId()
        
        var body: [String: Any] = [
            "link": url.absoluteString,
            "pleaseParse": [:] // Let Raindrop parse the page
        ]
        
        if let title {
            body["title"] = title
        }
        
        if collectionId >= 0 {
            body["collection"] = ["$id": collectionId]
        }
        
        // Add default tags from config
        if let tags = getDefaultTags(), !tags.isEmpty {
            body["tags"] = tags
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FediReaderError.readLaterError("Invalid response from Raindrop")
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            return // Success
        case 401:
            // Try to refresh token
            if refreshToken != nil {
                try await refreshAccessToken()
                try await save(url: url, title: title)
            } else {
                throw FediReaderError.readLaterError("Raindrop authentication expired")
            }
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FediReaderError.readLaterError("Raindrop error: \(message)")
        }
    }
    
    private func refreshAccessToken() async throws {
        guard refreshToken != nil else {
            throw FediReaderError.readLaterError("No refresh token available")
        }
        
        // Would need client credentials to refresh
        // For now, throw an error requiring re-authentication
        throw FediReaderError.readLaterError("Token refresh requires re-authentication")
    }
    
    // MARK: - Configuration Helpers
    
    private func getCollectionId() -> Int {
        if let configData = config.configData,
           let raindropConfig = try? JSONDecoder().decode(RaindropConfig.self, from: configData) {
            return raindropConfig.collectionId ?? -1
        }
        return -1 // Unsorted
    }
    
    private func getDefaultTags() -> [String]? {
        if let configData = config.configData,
           let raindropConfig = try? JSONDecoder().decode(RaindropConfig.self, from: configData) {
            return raindropConfig.defaultTags
        }
        return nil
    }
    
    // MARK: - Additional Features
    
    func saveWithTags(url: URL, title: String?, tags: [String]) async throws {
        guard let accessToken else {
            throw FediReaderError.readLaterError("Not authenticated with Raindrop")
        }
        
        let apiURL = URL(string: "\(Constants.ReadLater.raindropAPIURL)/raindrop")!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "link": url.absoluteString,
            "tags": tags,
            "pleaseParse": [:]
        ]
        
        if let title {
            body["title"] = title
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw FediReaderError.readLaterError("Failed to save to Raindrop")
        }
    }
    
    func getCollections() async throws -> [[String: Any]] {
        guard let accessToken else {
            throw FediReaderError.readLaterError("Not authenticated with Raindrop")
        }
        
        let apiURL = URL(string: "\(Constants.ReadLater.raindropAPIURL)/collections")!
        
        var request = URLRequest(url: apiURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FediReaderError.readLaterError("Failed to get Raindrop collections")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw FediReaderError.readLaterError("Invalid Raindrop response")
        }
        
        return items
    }
}

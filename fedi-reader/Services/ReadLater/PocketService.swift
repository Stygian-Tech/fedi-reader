//
//  PocketService.swift
//  fedi-reader
//
//  Pocket read-later service integration
//

import Foundation
import os

final class PocketService: ReadLaterServiceProtocol {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ReadLater.Pocket")
    
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
            "Content-Type": "application/json; charset=UTF-8",
            "X-Accept": "application/json"
        ]
        self.session = URLSession(configuration: sessionConfig)
        
        // Load existing token
        Task {
            accessToken = try? await keychain.getReadLaterToken(
                forService: .pocket,
                configId: config.id
            )
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        Self.logger.info("Starting Pocket authentication")
        // Pocket uses a custom OAuth flow
        // Step 1: Obtain request token
        // Step 2: Redirect user to authorize
        // Step 3: Exchange for access token
        
        guard let consumerKey = getConsumerKey() else {
            Self.logger.error("Pocket consumer key not configured")
            throw FediReaderError.readLaterError("Pocket consumer key not configured")
        }
        
        Self.logger.debug("Obtaining Pocket request token")
        let requestToken = try await getRequestToken(consumerKey: consumerKey)
        
        // The authorization URL should be opened in a browser
        // After authorization, call exchangeForAccessToken with the request token
        Self.logger.debug("Exchanging request token for access token")
        _ = try await exchangeForAccessToken(consumerKey: consumerKey, requestToken: requestToken)
        Self.logger.info("Pocket authentication successful")
    }
    
    private func getRequestToken(consumerKey: String) async throws -> String {
        let url = URL(string: Constants.ReadLater.pocketAuthURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body: [String: String] = [
            "consumer_key": consumerKey,
            "redirect_uri": Constants.OAuth.redirectURI
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Pocket request token")
            throw FediReaderError.readLaterError("Failed to get Pocket request token")
        }
        
        guard httpResponse.statusCode == 200 else {
            Self.logger.error("Pocket request token failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Failed to get Pocket request token")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String else {
            Self.logger.error("Invalid Pocket response format")
            throw FediReaderError.readLaterError("Invalid Pocket response")
        }
        
        Self.logger.debug("Pocket request token obtained successfully")
        return code
    }
    
    private func exchangeForAccessToken(consumerKey: String, requestToken: String) async throws -> String {
        let url = URL(string: Constants.ReadLater.pocketAccessTokenURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body: [String: String] = [
            "consumer_key": consumerKey,
            "code": requestToken
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Pocket access token")
            throw FediReaderError.readLaterError("Failed to get Pocket access token")
        }
        
        guard httpResponse.statusCode == 200 else {
            Self.logger.error("Pocket access token exchange failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Failed to get Pocket access token")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            Self.logger.error("Invalid Pocket access token response format")
            throw FediReaderError.readLaterError("Invalid Pocket response")
        }
        
        accessToken = token
        try await keychain.saveReadLaterToken(token, forService: .pocket, configId: config.id)
        Self.logger.debug("Pocket access token saved to Keychain")
        
        return token
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        Self.logger.info("Saving to Pocket: \(url.absoluteString, privacy: .public), title: \(title ?? "nil", privacy: .public)")
        guard let accessToken, let consumerKey = getConsumerKey() else {
            Self.logger.error("Not authenticated with Pocket")
            throw FediReaderError.readLaterError("Not authenticated with Pocket")
        }
        
        let apiURL = URL(string: Constants.ReadLater.pocketAddURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        
        var body: [String: String] = [
            "url": url.absoluteString,
            "consumer_key": consumerKey,
            "access_token": accessToken
        ]
        
        if let title {
            body["title"] = title
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Pocket save")
            throw FediReaderError.readLaterError("Failed to save to Pocket")
        }
        
        guard httpResponse.statusCode == 200 else {
            Self.logger.error("Pocket save failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Failed to save to Pocket")
        }
        
        Self.logger.info("Successfully saved to Pocket")
    }
    
    private func getConsumerKey() -> String? {
        // In production, this would come from config or environment
        // For now, return nil to indicate it needs to be configured
        if let configData = config.configData,
           let pocketConfig = try? JSONDecoder().decode(PocketConfig.self, from: configData) {
            return pocketConfig.consumerKey
        }
        return nil
    }
}

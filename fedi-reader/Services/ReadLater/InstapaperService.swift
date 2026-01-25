//
//  InstapaperService.swift
//  fedi-reader
//
//  Instapaper read-later service integration
//

import Foundation
import os

final class InstapaperService: ReadLaterServiceProtocol {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ReadLater.Instapaper")
    private let config: ReadLaterConfig
    private let keychain: KeychainHelper
    private let session: URLSession
    
    private var oauthToken: String?
    private var oauthTokenSecret: String?
    
    var isAuthenticated: Bool {
        oauthToken != nil && oauthTokenSecret != nil
    }
    
    init(config: ReadLaterConfig, keychain: KeychainHelper) {
        self.config = config
        self.keychain = keychain
        self.session = URLSession.shared
        
        // Load existing credentials
        Task {
            if let tokenData = try? await keychain.getReadLaterToken(forService: .instapaper, configId: config.id),
               let parts = tokenData.split(separator: ":").map({ String($0) }) as? [String],
               parts.count == 2 {
                oauthToken = parts[0]
                oauthTokenSecret = parts[1]
            }
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        // Instapaper uses xAuth (simplified OAuth for trusted apps)
        // This requires getting OAuth credentials from Instapaper directly
        throw FediReaderError.readLaterError("Instapaper authentication not implemented - use API key")
    }
    
    func authenticateWithCredentials(username: String, password: String) async throws {
        Self.logger.info("Authenticating Instapaper with credentials")
        let url = URL(string: Constants.ReadLater.instapaperAuthURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // xAuth requires OAuth signature - simplified implementation
        let body = "x_auth_username=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&x_auth_password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&x_auth_mode=client_auth"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Instapaper authentication")
            throw FediReaderError.readLaterError("Instapaper authentication failed")
        }
        
        guard httpResponse.statusCode == 200 else {
            Self.logger.error("Instapaper authentication failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Instapaper authentication failed")
        }
        
        // Parse OAuth response
        guard let responseString = String(data: data, encoding: .utf8) else {
            Self.logger.error("Invalid Instapaper response format")
            throw FediReaderError.readLaterError("Invalid Instapaper response")
        }
        
        var params: [String: String] = [:]
        for pair in responseString.split(separator: "&") {
            let keyValue = pair.split(separator: "=")
            if keyValue.count == 2 {
                params[String(keyValue[0])] = String(keyValue[1])
            }
        }
        
        guard let token = params["oauth_token"],
              let tokenSecret = params["oauth_token_secret"] else {
            Self.logger.error("Missing OAuth tokens in Instapaper response")
            throw FediReaderError.readLaterError("Missing OAuth tokens")
        }
        
        oauthToken = token
        oauthTokenSecret = tokenSecret
        
        // Store combined token
        try await keychain.saveReadLaterToken(
            "\(token):\(tokenSecret)",
            forService: .instapaper,
            configId: config.id
        )
        Self.logger.info("Instapaper authentication successful")
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        Self.logger.info("Saving to Instapaper: \(url.absoluteString, privacy: .public), title: \(title ?? "nil", privacy: .public)")
        guard isAuthenticated else {
            Self.logger.error("Not authenticated with Instapaper")
            throw FediReaderError.readLaterError("Not authenticated with Instapaper")
        }
        
        let apiURL = URL(string: Constants.ReadLater.instapaperAddURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyParts = ["url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"]
        
        if let title {
            bodyParts.append("title=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
        
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)
        
        // Add OAuth signature (simplified - in production use proper OAuth signing)
        // This would need proper OAuth 1.0a signature implementation
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Instapaper save")
            throw FediReaderError.readLaterError("Failed to save to Instapaper")
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            Self.logger.error("Instapaper save failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Failed to save to Instapaper")
        }
        
        Self.logger.info("Successfully saved to Instapaper")
    }
}

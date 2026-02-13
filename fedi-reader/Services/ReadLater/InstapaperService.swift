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
    private static let formURLEncodedAllowedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
    private let config: ReadLaterConfig
    private let keychain: KeychainHelper
    private let session: URLSession
    
    private var username: String?
    private var password: String?
    
    var isAuthenticated: Bool {
        username != nil && password != nil
    }
    
    init(
        config: ReadLaterConfig,
        keychain: KeychainHelper,
        session: URLSession = .shared,
        loadStoredCredentials: Bool = true
    ) {
        self.config = config
        self.keychain = keychain
        self.session = session
        
        // Load existing credentials
        guard loadStoredCredentials else { return }
        
        Task {
            guard let credentialToken = try? await keychain.getReadLaterToken(forService: .instapaper, configId: config.id) else {
                return
            }
            setCredentials(fromToken: credentialToken)
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        throw FediReaderError.readLaterError("Use account credentials to configure Instapaper")
    }
    
    func authenticateWithCredentials(
        username: String,
        password: String,
        persistCredentials: Bool = true
    ) async throws {
        guard !username.isEmpty, !password.isEmpty else {
            throw FediReaderError.readLaterError("Instapaper username and password are required")
        }
        
        self.username = username
        self.password = password
        
        if persistCredentials {
            try await keychain.saveReadLaterToken(
                "\(username):\(password)",
                forService: .instapaper,
                configId: config.id
            )
        }
        Self.logger.info("Instapaper credentials saved")
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        Self.logger.info("Saving to Instapaper: \(url.absoluteString, privacy: .public), title: \(title ?? "nil", privacy: .public)")
        guard let username, let password else {
            Self.logger.error("Not authenticated with Instapaper")
            throw FediReaderError.readLaterError("Not authenticated with Instapaper")
        }
        
        let apiURL = URL(string: Constants.ReadLater.instapaperAddURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var formFields = [("url", url.absoluteString)]
        if let title, !title.isEmpty {
            formFields.append(("title", title))
        }
        
        request.httpBody = formURLEncodedData(from: formFields)
        request.setValue(
            basicAuthorizationHeader(username: username, password: password),
            forHTTPHeaderField: "Authorization"
        )
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Invalid response type for Instapaper save")
            throw FediReaderError.readLaterError("Failed to save to Instapaper")
        }
        
        switch httpResponse.statusCode {
        case 200, 201:
            Self.logger.info("Successfully saved to Instapaper")
        case 400:
            let message = errorMessage(
                from: data,
                fallback: "Instapaper rejected this URL or request payload"
            )
            Self.logger.error("Instapaper save rejected: \(message, privacy: .public)")
            throw FediReaderError.readLaterError(message)
        case 401, 403:
            Self.logger.error("Instapaper authentication failed with status: \(httpResponse.statusCode)")
            throw FediReaderError.readLaterError("Instapaper authentication failed. Reconnect your account in Settings.")
        default:
            let message = errorMessage(
                from: data,
                fallback: "Instapaper returned status \(httpResponse.statusCode)"
            )
            Self.logger.error("Instapaper save failed with status \(httpResponse.statusCode): \(message, privacy: .public)")
            throw FediReaderError.readLaterError(message)
        }
    }
    
    private func setCredentials(fromToken token: String) {
        let components = token.split(separator: ":", maxSplits: 1).map(String.init)
        guard components.count == 2 else {
            Self.logger.error("Stored Instapaper credentials are invalid")
            return
        }
        
        username = components[0]
        password = components[1]
    }
    
    private func basicAuthorizationHeader(username: String, password: String) -> String {
        let credentials = "\(username):\(password)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
    
    private func errorMessage(from data: Data, fallback: String) -> String {
        let responseText = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let responseText, !responseText.isEmpty else {
            return fallback
        }
        
        return "Instapaper error: \(responseText)"
    }
    
    private func formURLEncodedData(from fields: [(String, String)]) -> Data {
        let encoded = fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: Self.formURLEncodedAllowedCharacters) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: Self.formURLEncodedAllowedCharacters) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        
        return Data(encoded.utf8)
    }
}

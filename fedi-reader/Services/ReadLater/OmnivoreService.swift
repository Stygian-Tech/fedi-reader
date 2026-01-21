//
//  OmnivoreService.swift
//  fedi-reader
//
//  Omnivore read-later service integration
//

import Foundation

final class OmnivoreService: ReadLaterServiceProtocol {
    private let config: ReadLaterConfig
    private let keychain: KeychainHelper
    private let session: URLSession
    
    private var apiKey: String?
    
    var isAuthenticated: Bool {
        apiKey != nil
    }
    
    init(config: ReadLaterConfig, keychain: KeychainHelper) {
        self.config = config
        self.keychain = keychain
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = [
            "Content-Type": "application/json"
        ]
        self.session = URLSession(configuration: sessionConfig)
        
        // Load existing API key
        Task {
            apiKey = try? await keychain.getReadLaterToken(forService: .omnivore, configId: config.id)
        }
    }
    
    // MARK: - Authentication
    
    func authenticate() async throws {
        // Omnivore uses API keys - user provides key from their account settings
        throw FediReaderError.readLaterError("Use setAPIKey to configure Omnivore")
    }
    
    func setAPIKey(_ key: String) async throws {
        apiKey = key
        try await keychain.saveReadLaterToken(key, forService: .omnivore, configId: config.id)
    }
    
    // MARK: - Save
    
    func save(url: URL, title: String?) async throws {
        guard let apiKey else {
            throw FediReaderError.readLaterError("Omnivore API key not configured")
        }
        
        let apiURL = URL(string: Constants.ReadLater.omnivoreAPIURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        // GraphQL mutation for saving URL
        let mutation = """
        mutation SaveUrl($input: SaveUrlInput!) {
            saveUrl(input: $input) {
                ... on SaveSuccess {
                    url
                    clientRequestId
                }
                ... on SaveError {
                    errorCodes
                    message
                }
            }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "url": url.absoluteString,
                "source": "api",
                "clientRequestId": UUID().uuidString
            ]
        ]
        
        let body: [String: Any] = [
            "query": mutation,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FediReaderError.readLaterError("Failed to save to Omnivore")
        }
        
        // Check for GraphQL errors
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataField = json["data"] as? [String: Any],
           let saveUrl = dataField["saveUrl"] as? [String: Any],
           let errorCodes = saveUrl["errorCodes"] as? [String],
           !errorCodes.isEmpty {
            let message = saveUrl["message"] as? String ?? errorCodes.joined(separator: ", ")
            throw FediReaderError.readLaterError("Omnivore error: \(message)")
        }
    }
    
    // MARK: - Additional Features
    
    func saveWithLabels(url: URL, title: String?, labels: [String]) async throws {
        guard let apiKey else {
            throw FediReaderError.readLaterError("Omnivore API key not configured")
        }
        
        let apiURL = URL(string: Constants.ReadLater.omnivoreAPIURL)!
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        let mutation = """
        mutation SaveUrl($input: SaveUrlInput!) {
            saveUrl(input: $input) {
                ... on SaveSuccess {
                    url
                    clientRequestId
                }
                ... on SaveError {
                    errorCodes
                    message
                }
            }
        }
        """
        
        var input: [String: Any] = [
            "url": url.absoluteString,
            "source": "api",
            "clientRequestId": UUID().uuidString
        ]
        
        if !labels.isEmpty {
            input["labels"] = labels.map { ["name": $0] }
        }
        
        let variables: [String: Any] = ["input": input]
        
        let body: [String: Any] = [
            "query": mutation,
            "variables": variables
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw FediReaderError.readLaterError("Failed to save to Omnivore")
        }
    }
}

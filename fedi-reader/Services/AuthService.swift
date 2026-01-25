//
//  AuthService.swift
//  fedi-reader
//
//  OAuth 2.0 authentication flow management
//

import Foundation
import SwiftData
import AuthenticationServices
import os

@Observable
@MainActor
final class AuthService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "Auth")
    private let client: MastodonClient
    private let keychain: KeychainHelper
    
    var currentAccount: Account?
    var accounts: [Account] = []
    var isAuthenticating = false
    var authError: Error?
    
    // Temporary state during OAuth flow
    private var pendingInstance: String?
    private var pendingClientId: String?
    private var pendingClientSecret: String?
    
    init(client: MastodonClient? = nil, keychain: KeychainHelper = .shared) {
        self.client = client ?? MastodonClient()
        self.keychain = keychain
    }
    
    // MARK: - Account Management
    
    func loadAccounts(from modelContext: ModelContext) {
        Self.logger.info("Loading accounts from SwiftData")
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdAt)])

        do {
            accounts = try modelContext.fetch(descriptor)
            currentAccount = accounts.first(where: { $0.isActive }) ?? accounts.first
            Self.logger.info("Loaded \(self.accounts.count) accounts, current: \(self.currentAccount?.username ?? "none", privacy: .public)@\(self.currentAccount?.instance ?? "none", privacy: .public)")
        } catch {
            Self.logger.error("Failed to load accounts: \(error.localizedDescription)")
        }
    }

    /// One-time migration: move OAuth client secrets from SwiftData to Keychain.
    func migrateOAuthClientSecretsToKeychain(modelContext: ModelContext) async {
        let key = "fedi-reader.migrated.oauth_client_secret"
        guard !UserDefaults.standard.bool(forKey: key) else {
            Self.logger.debug("OAuth client secret migration already completed")
            return
        }

        Self.logger.info("Starting OAuth client secret migration to Keychain")
        let descriptor = FetchDescriptor<Account>()
        guard let accounts = try? modelContext.fetch(descriptor) else {
            Self.logger.error("Failed to fetch accounts for migration")
            return
        }

        var migratedCount = 0
        for account in accounts {
            guard let secret = account.clientSecret, !secret.isEmpty else { continue }
            do {
                try await keychain.saveOAuthClientSecret(secret, forAccount: account.id)
                account.clientSecret = nil
                try modelContext.save()
                migratedCount += 1
            } catch {
                Self.logger.error("Migration: failed to move client secret to Keychain for account \(account.id, privacy: .public)")
            }
        }

        UserDefaults.standard.set(true, forKey: key)
        Self.logger.info("OAuth client secret migration complete: \(migratedCount) accounts migrated")
    }
    
    func setActiveAccount(_ account: Account, modelContext: ModelContext) {
        let previousAccount = currentAccount?.id
        Self.logger.notice("Switching active account from \(previousAccount?.prefix(8) ?? "none", privacy: .public) to \(account.id.prefix(8), privacy: .public) (\(account.username, privacy: .public)@\(account.instance, privacy: .public))")
        
        // Deactivate all accounts
        for acc in accounts {
            acc.isActive = false
        }
        
        // Activate selected account
        account.isActive = true
        currentAccount = account
        
        try? modelContext.save()
        
        NotificationCenter.default.post(name: .accountDidChange, object: account)
    }
    
    func getAccessToken(for account: Account) async -> String? {
        do {
            let token = try await keychain.getToken(forAccount: account.id)
            Self.logger.debug("Retrieved access token for account: \(account.id.prefix(8), privacy: .public)")
            return token
        } catch {
            Self.logger.error("Failed to get access token for account \(account.id.prefix(8), privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - OAuth Flow
    
    func initiateLogin(instance: String) async throws -> URL {
        Self.logger.notice("Initiating OAuth login for instance: \(instance, privacy: .public)")
        isAuthenticating = true
        authError = nil
        
        // Normalize instance URL
        let normalizedInstance = normalizeInstance(instance)
        Self.logger.debug("Normalized instance: \(normalizedInstance, privacy: .public)")
        
        do {
            // Register app with instance
            Self.logger.info("Registering app with instance")
            let app = try await client.registerApp(instance: normalizedInstance)
            
            // Store pending auth state
            pendingInstance = normalizedInstance
            pendingClientId = app.clientId
            pendingClientSecret = app.clientSecret
            Self.logger.debug("App registered, client ID: \(app.clientId.prefix(8), privacy: .public)")
            
            // Build authorization URL
            let authURL = try client.buildAuthorizationURL(
                instance: normalizedInstance,
                clientId: app.clientId
            )
            
            Self.logger.info("OAuth authorization URL generated")
            return authURL
        } catch {
            Self.logger.error("Failed to initiate login: \(error.localizedDescription)")
            isAuthenticating = false
            authError = error
            throw error
        }
    }
    
    func handleCallback(url: URL, modelContext: ModelContext) async throws -> Account {
        Self.logger.info("Handling OAuth callback")
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            Self.logger.error("OAuth callback missing authorization code")
            throw FediReaderError.oauthError("Missing authorization code")
        }
        
        guard let instance = pendingInstance,
              let clientId = pendingClientId,
              let clientSecret = pendingClientSecret else {
            Self.logger.error("OAuth callback with no pending authentication state")
            throw FediReaderError.oauthError("No pending authentication")
        }
        
        do {
            // Exchange code for token
            Self.logger.info("Exchanging authorization code for access token")
            let token = try await client.exchangeCodeForToken(
                instance: instance,
                clientId: clientId,
                clientSecret: clientSecret,
                code: code
            )
            
            // Verify credentials and get account info
            Self.logger.info("Verifying credentials")
            let mastodonAccount = try await client.verifyCredentials(
                instance: instance,
                accessToken: token.accessToken
            )
            
            let accountId = "\(instance):\(mastodonAccount.id)"
            let account = Account(
                id: accountId,
                instance: instance,
                username: mastodonAccount.username,
                displayName: mastodonAccount.displayName,
                avatarURL: mastodonAccount.avatar,
                headerURL: mastodonAccount.header,
                acct: mastodonAccount.acct,
                note: mastodonAccount.note.htmlStripped,
                followersCount: mastodonAccount.followersCount,
                followingCount: mastodonAccount.followingCount,
                statusesCount: mastodonAccount.statusesCount,
                isActive: true,
                clientId: clientId,
                clientSecret: nil
            )

            Self.logger.info("Saving token and client secret to Keychain")
            try await keychain.saveToken(token.accessToken, forAccount: account.id)
            try await keychain.saveOAuthClientSecret(clientSecret, forAccount: account.id)
            
            // Deactivate other accounts
            for existingAccount in accounts {
                existingAccount.isActive = false
            }
            
            // Save account to SwiftData
            modelContext.insert(account)
            try modelContext.save()
            
            // Update state
            accounts.append(account)
            currentAccount = account
            
            // Clear pending state
            pendingInstance = nil
            pendingClientId = nil
            pendingClientSecret = nil
            isAuthenticating = false
            
            Self.logger.notice("Login successful: \(account.username, privacy: .public)@\(account.instance, privacy: .public)")
            NotificationCenter.default.post(name: .accountDidLogin, object: account)
            
            return account
        } catch {
            Self.logger.error("OAuth callback failed: \(error.localizedDescription)")
            isAuthenticating = false
            authError = error
            throw error
        }
    }
    
    func logout(account: Account, modelContext: ModelContext) async throws {
        Self.logger.notice("Logging out account: \(account.username, privacy: .public)@\(account.instance, privacy: .public)")
        let token = await getAccessToken(for: account)
        if let clientId = account.clientId,
           let clientSecret = try? await keychain.getOAuthClientSecret(forAccount: account.id),
           let token = token {
            Self.logger.info("Revoking OAuth token")
            try? await client.revokeToken(
                instance: account.instance,
                clientId: clientId,
                clientSecret: clientSecret,
                token: token
            )
        } else {
            Self.logger.debug("Skipping token revocation (missing credentials)")
        }

        Self.logger.info("Removing credentials from Keychain")
        try await keychain.deleteToken(forAccount: account.id)
        try? await keychain.deleteOAuthClientSecret(forAccount: account.id)
        
        // Remove from SwiftData
        modelContext.delete(account)
        try modelContext.save()
        
        // Update state
        accounts.removeAll { $0.id == account.id }
        
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
            currentAccount?.isActive = true
            Self.logger.info("Switched to account: \(self.currentAccount?.username ?? "none", privacy: .public)")
        }
        
        Self.logger.notice("Logout complete for account: \(account.id.prefix(8), privacy: .public)")
        NotificationCenter.default.post(name: .accountDidLogout, object: account)
    }
    
    func refreshAccountInfo(for account: Account, modelContext: ModelContext) async throws {
        guard let token = await getAccessToken(for: account) else {
            throw FediReaderError.unauthorized
        }
        
        let mastodonAccount = try await client.verifyCredentials(
            instance: account.instance,
            accessToken: token
        )
        
        // Update account info
        account.username = mastodonAccount.username
        account.displayName = mastodonAccount.displayName
        account.avatarURL = mastodonAccount.avatar
        account.headerURL = mastodonAccount.header
        account.note = mastodonAccount.note.htmlStripped
        account.followersCount = mastodonAccount.followersCount
        account.followingCount = mastodonAccount.followingCount
        account.statusesCount = mastodonAccount.statusesCount
        
        try modelContext.save()
    }
    
    // MARK: - Token Verification
    
    /// Verifies if the current token is still valid by attempting to verify credentials
    func verifyToken(for account: Account) async -> Bool {
        guard let token = await getAccessToken(for: account) else {
            return false
        }
        
        do {
            _ = try await client.verifyCredentials(
                instance: account.instance,
                accessToken: token
            )
            return true
        } catch {
            // Token is invalid or expired
            return false
        }
    }
    
    /// Handles authentication errors by verifying token and prompting re-auth if needed
    func handleAuthError(for account: Account, modelContext: ModelContext) async throws {
        let isValid = await verifyToken(for: account)
        
        if !isValid {
            // Token is invalid - user needs to re-authenticate
            throw FediReaderError.unauthorized
        }
        
        // Token is valid, might be a temporary network issue
        // Refresh account info to ensure everything is up to date
        try await refreshAccountInfo(for: account, modelContext: modelContext)
    }
    
    // MARK: - Helpers
    
    private func normalizeInstance(_ instance: String) -> String {
        var normalized = instance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove protocol prefix
        if normalized.hasPrefix("https://") {
            normalized = String(normalized.dropFirst(8))
        } else if normalized.hasPrefix("http://") {
            normalized = String(normalized.dropFirst(7))
        }
        
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        
        return normalized
    }
    
    func isValidCallback(url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        
        return components.scheme == Constants.OAuth.redirectScheme &&
               components.host == Constants.OAuth.redirectHost
    }
}

// MARK: - ASWebAuthenticationSession Support

#if canImport(UIKit)
import UIKit

extension AuthService {
    @MainActor
    func authenticateWithWebSession(instance: String, presentationContext: ASWebAuthenticationPresentationContextProviding, modelContext: ModelContext) async throws -> Account {
        let authURL = try await initiateLogin(instance: instance)
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Constants.OAuth.redirectScheme
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: FediReaderError.oauthError("No callback URL"))
                        return
                    }

                    do {
                        let account = try await self.handleCallback(url: callbackURL, modelContext: modelContext)
                        continuation.resume(returning: account)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: FediReaderError.oauthError("Failed to start auth session"))
            }
        }
    }
}
#endif

#if canImport(AppKit)
import AppKit

extension AuthService {
    @MainActor
    func authenticateWithWebSession(instance: String, presentationContext: ASWebAuthenticationPresentationContextProviding, modelContext: ModelContext) async throws -> Account {
        let authURL = try await initiateLogin(instance: instance)

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Constants.OAuth.redirectScheme
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: FediReaderError.oauthError("No callback URL"))
                        return
                    }

                    do {
                        let account = try await self.handleCallback(url: callbackURL, modelContext: modelContext)
                        continuation.resume(returning: account)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.presentationContextProvider = presentationContext
            session.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                continuation.resume(throwing: FediReaderError.oauthError("Failed to start auth session"))
            }
        }
    }
}
#endif

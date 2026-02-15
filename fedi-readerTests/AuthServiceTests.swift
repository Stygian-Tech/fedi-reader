//
//  AuthServiceTests.swift
//  fedi-readerTests
//
//  Unit tests for AuthService (callback validation, etc.)
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("AuthService Tests")
@MainActor
struct AuthServiceTests {

    @Test("Accepts valid OAuth callback URL")
    func acceptsValidCallback() {
        let auth = AuthService(client: nil, keychain: .shared)
        let url = URL(string: "fedi-reader://oauth/callback?code=abc123")!
        #expect(auth.isValidCallback(url: url) == true)
    }

    @Test("Rejects invalid scheme")
    func rejectsInvalidScheme() {
        let auth = AuthService(client: nil, keychain: .shared)
        let url = URL(string: "https://oauth/callback?code=abc")!
        #expect(auth.isValidCallback(url: url) == false)
    }

    @Test("Rejects invalid host")
    func rejectsInvalidHost() {
        let auth = AuthService(client: nil, keychain: .shared)
        let url = URL(string: "fedi-reader://other/callback?code=abc")!
        #expect(auth.isValidCallback(url: url) == false)
    }

    @Test("Accepts callback without query items")
    func acceptsCallbackWithoutQuery() {
        let auth = AuthService(client: nil, keychain: .shared)
        let url = URL(string: "fedi-reader://oauth/callback")!
        #expect(auth.isValidCallback(url: url) == true)
    }

    @Test("fetchVerifiedProfile throws unauthorized when token is missing")
    func fetchVerifiedProfileThrowsUnauthorizedWhenTokenMissing() async {
        let auth = AuthService(client: nil, keychain: .shared)
        let accountID = "example.social:\(UUID().uuidString)"
        let account = Account(
            id: accountID,
            instance: "example.social",
            username: "tester",
            displayName: "Tester",
            acct: "tester@example.social"
        )

        try? await KeychainHelper.shared.deleteToken(forAccount: account.id)

        do {
            _ = try await auth.fetchVerifiedProfile(for: account)
            Issue.record("Expected fetchVerifiedProfile to throw unauthorized")
        } catch let error as FediReaderError {
            #expect(error == .unauthorized)
        } catch {
            Issue.record("Expected FediReaderError.unauthorized, got \(error)")
        }
    }
}

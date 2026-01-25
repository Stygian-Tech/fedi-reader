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
}

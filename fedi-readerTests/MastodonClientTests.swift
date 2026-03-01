import Testing
import Foundation
@testable import fedi_reader

@Suite("Mastodon Client Tests")
@MainActor
struct MastodonClientTests {
    @Test("lookupAccount uses configured session and auth snapshot")
    func lookupAccountUsesConfiguredSession() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }

        let account = makeAccount(acct: "alice@example.com", username: "alice")
        MockURLProtocol.setMockResponse(
            for: lookupAccountURL(instance: "mastodon.social", acct: "alice@example.com"),
            data: try makeEncoder().encode(account)
        )

        let client = makeClient()
        client.currentInstance = "mastodon.social"
        client.currentAccessToken = "secret-token"

        let resolved = try await client.lookupAccount(acct: "alice@example.com")

        #expect(resolved.acct == "alice@example.com")
        #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
    }

    @Test("resolveProfileAccount falls back to search when lookup fails")
    func resolveProfileAccountFallsBackToSearch() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }

        let account = makeAccount(acct: "alice@example.com", username: "alice")
        MockURLProtocol.setMockResponse(
            for: lookupAccountURL(instance: "mastodon.social", acct: "alice@example.com"),
            data: Data("not found".utf8),
            statusCode: 404
        )

        let searchResults = SearchResults(accounts: [account], statuses: [], hashtags: [])
        MockURLProtocol.setMockResponse(
            for: searchURL(instance: "mastodon.social", query: "alice@example.com", type: "accounts", limit: 5),
            data: try makeEncoder().encode(searchResults)
        )

        let client = makeClient()
        client.currentInstance = "mastodon.social"
        client.currentAccessToken = "secret-token"

        let resolved = await client.resolveProfileAccount(handle: "@alice@example.com")

        #expect(resolved?.id == account.id)
        #expect(resolved?.preferredDisplayName == account.displayName)
    }

    private func makeClient() -> MastodonClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return MastodonClient(configuration: configuration)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func lookupAccountURL(instance: String, acct: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/accounts/lookup"
        components.queryItems = [URLQueryItem(name: "acct", value: acct)]
        return components.url!.absoluteString
    }

    private func searchURL(instance: String, query: String, type: String, limit: Int) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v2/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "resolve", value: String(true)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "type", value: type)
        ]
        return components.url!.absoluteString
    }

    private func makeAccount(acct: String, username: String, displayName: String = "Alice Example") -> MastodonAccount {
        MastodonAccount(
            id: UUID().uuidString,
            username: username,
            acct: acct,
            displayName: displayName,
            locked: false,
            bot: false,
            createdAt: Date(),
            note: "<p>bio</p>",
            url: "https://mastodon.social/@\(username)",
            avatar: "https://example.com/avatar.jpg",
            avatarStatic: "https://example.com/avatar.jpg",
            header: "https://example.com/header.jpg",
            headerStatic: "https://example.com/header.jpg",
            followersCount: 10,
            followingCount: 20,
            statusesCount: 30,
            lastStatusAt: nil,
            emojis: [],
            fields: [],
            source: nil
        )
    }
}

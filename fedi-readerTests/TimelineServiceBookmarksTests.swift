import Testing
import Foundation
@testable import fedi_reader

@Suite("Timeline Service Bookmarks Tests", .serialized)
@MainActor
struct TimelineServiceBookmarksTests {
    @Test("refreshBookmarks loads bookmarks from the authenticated account")
    func refreshBookmarksLoadsBookmarks() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = makeAccount()

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let statuses = [
                MockStatusFactory.makeStatus(id: "bookmark-1"),
                MockStatusFactory.makeStatus(id: "bookmark-2")
            ]
            MockURLProtocol.setMockResponse(
                for: bookmarksURL(instance: account.instance, maxId: nil),
                data: try makeEncoder().encode(statuses)
            )

            await service.refreshBookmarks()

            #expect(service.bookmarks.map(\.id) == ["bookmark-1", "bookmark-2"])
            #expect(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")
        }
    }

    @Test("loadMoreBookmarks appends older bookmarked statuses")
    func loadMoreBookmarksAppendsOlderBookmarkedStatuses() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = makeAccount()

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let initialStatuses = [
                MockStatusFactory.makeStatus(id: "bookmark-1"),
                MockStatusFactory.makeStatus(id: "bookmark-2")
            ]
            let olderStatuses = [
                MockStatusFactory.makeStatus(id: "bookmark-3")
            ]
            MockURLProtocol.setMockResponse(
                for: bookmarksURL(instance: account.instance, maxId: nil),
                data: try makeEncoder().encode(initialStatuses)
            )
            MockURLProtocol.setMockResponse(
                for: bookmarksURL(instance: account.instance, maxId: "bookmark-2"),
                data: try makeEncoder().encode(olderStatuses)
            )

            await service.refreshBookmarks()
            await service.loadMoreBookmarks()

            #expect(service.bookmarks.map(\.id) == ["bookmark-1", "bookmark-2", "bookmark-3"])
        }
    }

    @Test("bookmark action inserts newly bookmarked status into bookmarks timeline")
    func bookmarkActionInsertsNewlyBookmarkedStatusIntoBookmarksTimeline() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = makeAccount()

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let status = MockStatusFactory.makeStatus(id: "bookmark-new")
            let updatedStatus = MockStatusFactory.makeStatus(id: "bookmark-new", bookmarked: true)
            MockURLProtocol.setMockResponse(
                for: bookmarkActionURL(instance: account.instance, statusId: status.id),
                data: try makeEncoder().encode(updatedStatus)
            )

            _ = try await service.bookmark(status: status)

            #expect(service.bookmarks.map(\.id) == ["bookmark-new"])
        }
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

    private func makeAccount() -> Account {
        Account(
            id: "mastodon.social:\(UUID().uuidString)",
            instance: "mastodon.social",
            username: "tester",
            displayName: "Tester",
            acct: "tester@mastodon.social",
            isActive: true
        )
    }

    private func bookmarksURL(instance: String, maxId: String?) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/bookmarks"
        components.queryItems = [URLQueryItem(name: "limit", value: String(Constants.Pagination.defaultLimit))]
        if let maxId {
            components.queryItems?.append(URLQueryItem(name: "max_id", value: maxId))
        }
        return components.url!.absoluteString
    }

    private func bookmarkActionURL(instance: String, statusId: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/statuses/\(statusId)/bookmark"
        return components.url!.absoluteString
    }
}

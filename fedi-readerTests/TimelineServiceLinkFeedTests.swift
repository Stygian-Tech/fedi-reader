import Testing
import Foundation
@testable import fedi_reader

@Suite("Timeline Service Link Feed Tests", .serialized)
@MainActor
struct TimelineServiceLinkFeedTests {
    @Test("concurrent list feed loads return the requested list data")
    func concurrentListFeedLoadsReturnRequestedStatuses() async throws {
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

            let listAURL = listTimelineURL(instance: account.instance, listId: "list-a", maxId: nil)
            let listBURL = listTimelineURL(instance: account.instance, listId: "list-b", maxId: nil)
            MockURLProtocol.setMockResponse(
                for: listAURL,
                data: try makeEncoder().encode([MockStatusFactory.makeStatus(id: "list-a-1")])
            )
            MockURLProtocol.setMockResponse(
                for: listBURL,
                data: try makeEncoder().encode([MockStatusFactory.makeStatus(id: "list-b-1")])
            )
            MockURLProtocol.setResponseDelay(for: listAURL, seconds: 0.2)

            let firstTask = Task { await service.loadLinkFeedStatuses(feedId: "list-a") }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let secondTask = Task { await service.loadLinkFeedStatuses(feedId: "list-b") }

            let firstStatuses = await firstTask.value
            let secondStatuses = await secondTask.value

            #expect(firstStatuses.map(\.id) == ["list-a-1"])
            #expect(secondStatuses.map(\.id) == ["list-b-1"])
            #expect(service.hasPreparedLinkFeedState(feedId: "list-b"))
            #expect(MockURLProtocol.requestCount(for: listAURL) == 1)
            #expect(MockURLProtocol.requestCount(for: listBURL) == 1)
        }
    }

    @Test("load more refreshes the selected list when shared list state belongs to another feed")
    func loadMoreRefreshesSelectedListWhenStateBelongsToAnotherFeed() async throws {
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

            let listAURL = listTimelineURL(instance: account.instance, listId: "list-a", maxId: nil)
            let listBURL = listTimelineURL(instance: account.instance, listId: "list-b", maxId: nil)
            MockURLProtocol.setMockResponse(
                for: listAURL,
                data: try makeEncoder().encode([
                    MockStatusFactory.makeStatus(id: "list-a-1"),
                    MockStatusFactory.makeStatus(id: "list-a-2")
                ])
            )
            MockURLProtocol.setMockResponse(
                for: listBURL,
                data: try makeEncoder().encode([
                    MockStatusFactory.makeStatus(id: "list-b-1"),
                    MockStatusFactory.makeStatus(id: "list-b-2")
                ])
            )

            _ = await service.loadLinkFeedStatuses(feedId: "list-a")
            let refreshedStatuses = await service.loadMoreListTimeline(listId: "list-b")

            #expect(refreshedStatuses.map(\.id) == ["list-b-1", "list-b-2"])
            #expect(service.hasPreparedLinkFeedState(feedId: "list-b"))
            #expect(MockURLProtocol.requestCount(for: listBURL) == 1)
        }
    }

    @Test("concurrent hashtag feed loads return the requested hashtag data")
    func concurrentHashtagFeedLoadsReturnRequestedStatuses() async throws {
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

            let swiftURL = hashtagTimelineURL(instance: account.instance, tag: "swift", maxId: nil)
            let iosURL = hashtagTimelineURL(instance: account.instance, tag: "ios", maxId: nil)
            MockURLProtocol.setMockResponse(
                for: swiftURL,
                data: try makeEncoder().encode([MockStatusFactory.makeStatus(id: "swift-1")])
            )
            MockURLProtocol.setMockResponse(
                for: iosURL,
                data: try makeEncoder().encode([MockStatusFactory.makeStatus(id: "ios-1")])
            )
            MockURLProtocol.setResponseDelay(for: swiftURL, seconds: 0.2)

            let firstTask = Task { await service.loadLinkFeedStatuses(feedId: AppState.hashtagFeedID("swift")) }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let secondTask = Task { await service.loadLinkFeedStatuses(feedId: AppState.hashtagFeedID("ios")) }

            let swiftStatuses = await firstTask.value
            let iosStatuses = await secondTask.value

            #expect(swiftStatuses.map(\.id) == ["swift-1"])
            #expect(iosStatuses.map(\.id) == ["ios-1"])
            #expect(service.hasPreparedLinkFeedState(feedId: AppState.hashtagFeedID("ios")))
            #expect(MockURLProtocol.requestCount(for: swiftURL) == 1)
            #expect(MockURLProtocol.requestCount(for: iosURL) == 1)
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

    private func listTimelineURL(instance: String, listId: String, maxId: String?) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/timelines/list/\(listId)"
        components.queryItems = [URLQueryItem(name: "limit", value: String(Constants.Pagination.defaultLimit))]
        if let maxId {
            components.queryItems?.append(URLQueryItem(name: "max_id", value: maxId))
        }
        return components.url!.absoluteString
    }

    private func hashtagTimelineURL(instance: String, tag: String, maxId: String?) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/timelines/tag/\(tag)"
        components.queryItems = [URLQueryItem(name: "limit", value: String(Constants.Pagination.defaultLimit))]
        if let maxId {
            components.queryItems?.append(URLQueryItem(name: "max_id", value: maxId))
        }
        return components.url!.absoluteString
    }
}

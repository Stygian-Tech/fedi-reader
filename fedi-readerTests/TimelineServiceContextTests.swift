import Testing
import Foundation
@testable import fedi_reader

@Suite("Timeline Service Context Tests", .serialized)
@MainActor
struct TimelineServiceContextTests {
    @Test("Initial status context load does not auto-fetch remote replies")
    func initialContextLoadDoesNotAutoFetchRemoteReplies() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = Account(
                id: "mastodon.social:\(UUID().uuidString)",
                instance: "mastodon.social",
                username: "tester",
                displayName: "Tester",
                acct: "tester@mastodon.social",
                isActive: true
            )

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let rootStatus = MockStatusFactory.makeStatus(id: "root-status", repliesCount: 3)
            let partialReply = MockStatusFactory.makeStatus(
                id: "reply-1",
                inReplyToId: rootStatus.id,
                repliesCount: 0
            )
            let partialContext = StatusContext(
                ancestors: [],
                descendants: [partialReply],
                hasMoreReplies: true
            )

            let url = statusContextURL(instance: account.instance, id: rootStatus.id)
            let encoder = makeEncoder()
            MockURLProtocol.setMockResponse(
                for: url,
                data: try encoder.encode(partialContext)
            )

            let loadedContext = try await service.getStatusContext(for: rootStatus)
            try? await Task.sleep(nanoseconds: 50_000_000)

            #expect(loadedContext.descendants.map(\.id) == ["reply-1"])
            #expect(MockURLProtocol.requestCount(for: url) == 1)
        }
    }

    @Test("Refresh with async refresh metadata publishes one final updated context")
    func refreshContextPublishesUpdatedContextAfterAsyncRefreshPolling() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = Account(
                id: "mastodon.social:\(UUID().uuidString)",
                instance: "mastodon.social",
                username: "tester",
                displayName: "Tester",
                acct: "tester@mastodon.social",
                isActive: true
            )

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let rootStatus = MockStatusFactory.makeStatus(id: "root-status", repliesCount: 2)
            let firstReply = MockStatusFactory.makeStatus(id: "reply-1", inReplyToId: rootStatus.id)
            let secondReply = MockStatusFactory.makeStatus(id: "reply-2", inReplyToId: rootStatus.id)

            let partialContext = StatusContext(
                ancestors: [],
                descendants: [firstReply],
                hasMoreReplies: true
            )
            let completedContext = StatusContext(
                ancestors: [],
                descendants: [firstReply, secondReply],
                hasMoreReplies: false
            )
            let refresh = AsyncRefreshResponse(
                asyncRefresh: AsyncRefresh(id: "refresh-123", status: "finished", resultCount: 2)
            )

            let contextURL = statusContextURL(instance: account.instance, id: rootStatus.id)
            let refreshURL = asyncRefreshURL(instance: account.instance, id: "refresh-123")
            let encoder = makeEncoder()

            MockURLProtocol.setQueuedResponses(
                for: contextURL,
                responses: [
                    (
                        data: try encoder.encode(partialContext),
                        statusCode: 200,
                        headerFields: [Constants.RemoteReplies.asyncRefreshHeader: #"id="refresh-123", retry=1"#]
                    ),
                    (data: try encoder.encode(completedContext), statusCode: 200, headerFields: nil)
                ]
            )
            MockURLProtocol.setMockResponse(
                for: refreshURL,
                data: try encoder.encode(refresh)
            )

            var payloads: [StatusContextUpdatePayload] = []
            let observer = NotificationCenter.default.addObserver(
                forName: .statusContextDidUpdate,
                object: nil,
                queue: nil
            ) { notification in
                guard let payload = notification.object as? StatusContextUpdatePayload else { return }
                payloads.append(payload)
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            try await service.refreshContextForStatus(rootStatus)

            let deliveredPayload = await waitForPayload(
                for: rootStatus.id,
                in: { payloads }
            )

            #expect(deliveredPayload?.context.descendants.map(\.id) == ["reply-1", "reply-2"])
            #expect(payloads.count == 1)
            #expect(MockURLProtocol.requestCount(for: contextURL) == 2)
            #expect(MockURLProtocol.requestCount(for: refreshURL) == 1)
        }
    }

    @Test("Refresh falls back to remote reply fetch when async refresh metadata is absent")
    func refreshContextPublishesUpdatedContextAfterFallbackReplyFetch() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = Account(
                id: "mastodon.social:\(UUID().uuidString)",
                instance: "mastodon.social",
                username: "tester",
                displayName: "Tester",
                acct: "tester@mastodon.social",
                isActive: true
            )

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let rootStatus = MockStatusFactory.makeStatus(id: "root-status", repliesCount: 2)
            let firstReply = MockStatusFactory.makeStatus(id: "reply-1", inReplyToId: rootStatus.id)
            let secondReply = MockStatusFactory.makeStatus(id: "reply-2", inReplyToId: rootStatus.id)

            let partialContext = StatusContext(
                ancestors: [],
                descendants: [firstReply],
                hasMoreReplies: true
            )
            let completedContext = StatusContext(
                ancestors: [],
                descendants: [firstReply, secondReply],
                hasMoreReplies: false
            )

            let contextURL = statusContextURL(instance: account.instance, id: rootStatus.id)
            let encoder = makeEncoder()

            MockURLProtocol.setQueuedResponses(
                for: contextURL,
                responses: [
                    (data: try encoder.encode(partialContext), statusCode: 200, headerFields: nil),
                    (data: try encoder.encode(completedContext), statusCode: 200, headerFields: nil)
                ]
            )

            var payloads: [StatusContextUpdatePayload] = []
            let observer = NotificationCenter.default.addObserver(
                forName: .statusContextDidUpdate,
                object: nil,
                queue: nil
            ) { notification in
                guard let payload = notification.object as? StatusContextUpdatePayload else { return }
                payloads.append(payload)
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            try await service.refreshContextForStatus(rootStatus)

            let deliveredPayload = await waitForPayload(
                for: rootStatus.id,
                in: { payloads }
            )

            #expect(deliveredPayload?.context.descendants.map(\.id) == ["reply-1", "reply-2"])
            #expect(payloads.count == 1)
            #expect(MockURLProtocol.requestCount(for: contextURL) == 2)
        }
    }

    @Test("Cancelling refresh suppresses late context publications")
    func cancelRefreshSuppressesLateContextPublication() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
            let service = TimelineService(client: client, authService: auth)
            let account = Account(
                id: "mastodon.social:\(UUID().uuidString)",
                instance: "mastodon.social",
                username: "tester",
                displayName: "Tester",
                acct: "tester@mastodon.social",
                isActive: true
            )

            defer {
                MockURLProtocol.reset()
                Task {
                    try? await KeychainHelper.shared.deleteToken(forAccount: account.id)
                }
            }

            auth.currentAccount = account
            try await KeychainHelper.shared.saveToken("secret-token", forAccount: account.id)

            let rootStatus = MockStatusFactory.makeStatus(id: "root-status", repliesCount: 2)
            let firstReply = MockStatusFactory.makeStatus(id: "reply-1", inReplyToId: rootStatus.id)
            let secondReply = MockStatusFactory.makeStatus(id: "reply-2", inReplyToId: rootStatus.id)

            let partialContext = StatusContext(
                ancestors: [],
                descendants: [firstReply],
                hasMoreReplies: true
            )
            let completedContext = StatusContext(
                ancestors: [],
                descendants: [firstReply, secondReply],
                hasMoreReplies: false
            )
            let refresh = AsyncRefreshResponse(
                asyncRefresh: AsyncRefresh(id: "refresh-123", status: "finished", resultCount: 2)
            )

            let contextURL = statusContextURL(instance: account.instance, id: rootStatus.id)
            let refreshURL = asyncRefreshURL(instance: account.instance, id: "refresh-123")
            let encoder = makeEncoder()

            MockURLProtocol.setQueuedResponses(
                for: contextURL,
                responses: [
                    (
                        data: try encoder.encode(partialContext),
                        statusCode: 200,
                        headerFields: [Constants.RemoteReplies.asyncRefreshHeader: #"id="refresh-123", retry=1"#]
                    ),
                    (data: try encoder.encode(completedContext), statusCode: 200, headerFields: nil)
                ]
            )
            MockURLProtocol.setMockResponse(
                for: refreshURL,
                data: try encoder.encode(refresh)
            )
            MockURLProtocol.setResponseDelay(for: refreshURL, seconds: 0.2)

            var payloads: [StatusContextUpdatePayload] = []
            let observer = NotificationCenter.default.addObserver(
                forName: .statusContextDidUpdate,
                object: nil,
                queue: nil
            ) { notification in
                guard let payload = notification.object as? StatusContextUpdatePayload else { return }
                payloads.append(payload)
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            try await service.refreshContextForStatus(rootStatus)
            service.cancelAsyncRefreshPolling(forStatusId: rootStatus.id)

            try? await Task.sleep(nanoseconds: 400_000_000)

            #expect(payloads.isEmpty)
            #expect(MockURLProtocol.requestCount(for: contextURL) == 1)
            #expect(MockURLProtocol.requestCount(for: refreshURL) == 1)
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

    private func statusContextURL(instance: String, id: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1/statuses/\(id)/context"
        return components.url!.absoluteString
    }

    private func asyncRefreshURL(instance: String, id: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = instance
        components.path = "/api/v1_alpha/async_refreshes/\(id)"
        return components.url!.absoluteString
    }

    private func waitForPayload(
        for statusId: String,
        in payloads: @escaping @MainActor () -> [StatusContextUpdatePayload],
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) async -> StatusContextUpdatePayload? {
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if let payload = payloads().first(where: { $0.statusId == statusId }) {
                return payload
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        return payloads().first(where: { $0.statusId == statusId })
    }
}

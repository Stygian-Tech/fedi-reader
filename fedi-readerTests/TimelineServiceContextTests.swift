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
}

import Testing
import Foundation
@testable import fedi_reader

@Suite("Remote Reply Service Tests", .serialized)
@MainActor
struct RemoteReplyServiceTests {
    @Test("Remote reply fetch retries context requests until replies stabilize")
    func remoteReplyFetchRetriesContextRequestsUntilRepliesStabilize() async throws {
        try await SharedTestResourceGate.withExclusiveAccess {
            MockURLProtocol.reset()

            let client = makeClient()
            let auth = AuthService(client: client, keychain: .shared)
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
            let firstReply = MockStatusFactory.makeStatus(
                id: "reply-1",
                inReplyToId: rootStatus.id,
                repliesCount: 0
            )
            let secondReply = MockStatusFactory.makeStatus(
                id: "reply-2",
                inReplyToId: rootStatus.id,
                repliesCount: 0
            )

            let initialContext = StatusContext(
                ancestors: [],
                descendants: [firstReply],
                hasMoreReplies: true
            )
            let refreshedContext = StatusContext(
                ancestors: [],
                descendants: [firstReply],
                hasMoreReplies: true
            )
            let completedContext = StatusContext(
                ancestors: [],
                descendants: [firstReply, secondReply],
                hasMoreReplies: false
            )

            let encoder = makeEncoder()
            MockURLProtocol.setQueuedResponses(
                for: statusContextURL(instance: account.instance, id: rootStatus.id),
                responses: [
                    (data: try encoder.encode(refreshedContext), statusCode: 200, headerFields: nil),
                    (data: try encoder.encode(completedContext), statusCode: 200, headerFields: nil)
                ]
            )

            let service = RemoteReplyService(
                client: client,
                authService: auth,
                contextRefetchDelaySeconds: 0
            )

            guard let updatedContext = await service.fetchRemoteReplyContext(
                for: rootStatus,
                initialContext: initialContext
            ) else {
                Issue.record("Expected an updated context")
                return
            }

            #expect(updatedContext.descendants.map(\.id) == ["reply-1", "reply-2"])
            #expect(updatedContext.hasMoreReplies == false)
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

import Foundation
import Testing
@testable import fedi_reader

private func makeThreadingServiceStatus(
    id: String,
    inReplyToId: String? = nil,
    createdAt: Date
) -> Status {
    Status(
        id: id,
        uri: "https://mastodon.social/statuses/\(id)",
        url: "https://mastodon.social/@testuser/\(id)",
        createdAt: createdAt,
        account: MockStatusFactory.makeAccount(id: "account-\(id)", username: "user\(id)", displayName: "User \(id)"),
        content: "<p>\(id)</p>",
        visibility: .public,
        sensitive: false,
        spoilerText: "",
        mediaAttachments: [],
        mentions: [],
        tags: [],
        emojis: [],
        reblogsCount: 0,
        favouritesCount: 0,
        repliesCount: 0,
        application: nil,
        language: "en",
        reblog: nil,
        card: nil,
        poll: nil,
        quote: nil,
        favourited: false,
        reblogged: false,
        muted: false,
        bookmarked: false,
        pinned: false,
        inReplyToId: inReplyToId,
        inReplyToAccountId: nil
    )
}

@Suite("Threading Service Tests")
struct ThreadingServiceTests {
    @Test("buildThreadTree returns the same ordered structure through the actor wrapper")
    func buildThreadTreeThroughActor() async {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let root = makeThreadingServiceStatus(id: "root", createdAt: baseDate)
        let earlierReply = makeThreadingServiceStatus(
            id: "reply-earlier",
            inReplyToId: root.id,
            createdAt: baseDate.addingTimeInterval(60)
        )
        let laterReply = makeThreadingServiceStatus(
            id: "reply-later",
            inReplyToId: root.id,
            createdAt: baseDate.addingTimeInterval(120)
        )

        let trees = await ThreadingService().buildThreadTree(
            from: [laterReply, root, earlierReply]
        )

        #expect(trees.count == 1)
        #expect(trees.first?.id == root.id)
        #expect(trees.first?.children.map(\.id) == [earlierReply.id, laterReply.id])
    }
}

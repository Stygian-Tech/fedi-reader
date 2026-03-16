import Foundation
import Testing
@testable import fedi_reader

private func makeThreadStatus(
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

@Suite("ThreadBuilder Tests")
struct ThreadBuilderTests {
    @Test("buildThreadTree nests replies beneath their root in chronological order")
    func buildThreadTreeNestsReplies() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let root = makeThreadStatus(id: "root", createdAt: baseDate)
        let laterReply = makeThreadStatus(
            id: "reply-later",
            inReplyToId: root.id,
            createdAt: baseDate.addingTimeInterval(120)
        )
        let earlierReply = makeThreadStatus(
            id: "reply-earlier",
            inReplyToId: root.id,
            createdAt: baseDate.addingTimeInterval(60)
        )
        let nestedReply = makeThreadStatus(
            id: "reply-child",
            inReplyToId: earlierReply.id,
            createdAt: baseDate.addingTimeInterval(180)
        )

        let trees = ThreadBuilder.buildThreadTree(
            from: [laterReply, nestedReply, root, earlierReply]
        )

        #expect(trees.count == 1)
        guard trees.count == 1 else { return }

        let rootNode = trees[0]
        #expect(rootNode.id == root.id)
        #expect(rootNode.children.map(\.id) == [earlierReply.id, laterReply.id])
        #expect(rootNode.children.first?.children.map(\.id) == [nestedReply.id])
    }

    @Test("findRootStatuses promotes orphaned replies to root threads")
    func findRootStatusesPromotesOrphanedReplies() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let root = makeThreadStatus(id: "root", createdAt: baseDate)
        let child = makeThreadStatus(
            id: "child",
            inReplyToId: root.id,
            createdAt: baseDate.addingTimeInterval(60)
        )
        let orphan = makeThreadStatus(
            id: "orphan",
            inReplyToId: "missing-parent",
            createdAt: baseDate.addingTimeInterval(120)
        )

        let statusMap = Dictionary(uniqueKeysWithValues: [root, child, orphan].map { ($0.id, $0) })
        let roots = ThreadBuilder.findRootStatuses([root, child, orphan], statusMap: statusMap)

        #expect(roots.map(\.id) == [root.id, orphan.id])
    }

    @Test("buildThreadTree prioritizes configured author within each sibling set")
    func buildThreadTreePrioritizesConfiguredAuthor() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let originalAuthor = MockStatusFactory.makeAccount(id: "author-root", username: "root", displayName: "Root")
        let otherAuthor = MockStatusFactory.makeAccount(id: "author-other", username: "other", displayName: "Other")

        let root = Status(
            id: "root",
            uri: "https://mastodon.social/statuses/root",
            url: "https://mastodon.social/@root/root",
            createdAt: baseDate,
            account: originalAuthor,
            content: "<p>root</p>",
            visibility: .direct,
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
            inReplyToId: nil,
            inReplyToAccountId: nil
        )

        let earlierOtherReply = Status(
            id: "reply-other",
            uri: "https://mastodon.social/statuses/reply-other",
            url: "https://mastodon.social/@other/reply-other",
            createdAt: baseDate.addingTimeInterval(60),
            account: otherAuthor,
            content: "<p>reply-other</p>",
            visibility: .direct,
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
            inReplyToId: root.id,
            inReplyToAccountId: nil
        )

        let laterOriginalReply = Status(
            id: "reply-original",
            uri: "https://mastodon.social/statuses/reply-original",
            url: "https://mastodon.social/@root/reply-original",
            createdAt: baseDate.addingTimeInterval(120),
            account: originalAuthor,
            content: "<p>reply-original</p>",
            visibility: .direct,
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
            inReplyToId: root.id,
            inReplyToAccountId: nil
        )

        let trees = ThreadBuilder.buildThreadTree(
            from: [root, earlierOtherReply, laterOriginalReply],
            replyOrdering: .prioritizeAuthor(originalAuthor.id)
        )

        #expect(trees.count == 1)
        #expect(trees.first?.children.map(\.id) == [laterOriginalReply.id, earlierOtherReply.id])
    }
}

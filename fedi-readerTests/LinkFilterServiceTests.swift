//
//  LinkFilterServiceTests.swift
//  fedi-readerTests
//
//  Tests for LinkFilterService
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("Link Filter Service Tests")
@MainActor
struct LinkFilterServiceTests {
    
    let service = LinkFilterService()
    
    // MARK: - Basic Filtering
    
    @Test("Filters statuses with link cards")
    func filtersStatusesWithCards() async {
        let statusWithCard = MockStatusFactory.makeStatus(
            id: "1",
            hasCard: true,
            cardURL: "https://example.com/article"
        )
        let statusWithoutCard = MockStatusFactory.makeStatus(
            id: "2",
            content: "<p>Just a regular post</p>"
        )
        
        let filtered = service.filterToLinks([statusWithCard, statusWithoutCard])
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "1")
    }
    
    @Test("Excludes quote posts from results")
    func excludesQuotePosts() async {
        let regularPostWithLink = MockStatusFactory.makeStatus(
            id: "1",
            hasCard: true,
            cardURL: "https://example.com/article"
        )
        let quotePost = MockStatusFactory.makeStatus(
            id: "2",
            hasCard: true,
            cardURL: "https://example.com/quoted",
            isQuote: true
        )
        
        let filtered = service.filterToLinks([regularPostWithLink, quotePost])
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "1")
    }
    
    @Test("Detects links in HTML content")
    func detectsLinksInContent() async {
        let statusWithContentLink = MockStatusFactory.makeStatus(
            id: "1",
            content: "<p>Check out this article: <a href=\"https://example.com/story\">link</a></p>"
        )
        let statusWithoutLinks = MockStatusFactory.makeStatus(
            id: "2",
            content: "<p>No links here</p>"
        )
        
        let filtered = service.filterToLinks([statusWithContentLink, statusWithoutLinks])
        
        #expect(filtered.count == 1)
        #expect(filtered.first?.id == "1")
    }

    @Test("Includes external preview cards regardless of card type")
    func includesExternalPreviewCardsRegardlessOfCardType() async {
        let photoCard = MockStatusFactory.makeStatus(
            id: "photo-card",
            hasCard: true,
            cardURL: "https://example.com/photo-story",
            cardType: .photo
        )
        let richCard = MockStatusFactory.makeStatus(
            id: "rich-card",
            hasCard: true,
            cardURL: "https://example.com/rich-story",
            cardType: .rich
        )

        let linkStatuses = await service.processStatuses([photoCard, richCard])

        #expect(linkStatuses.count == 2)
        #expect(linkStatuses.contains { $0.id == "photo-card" && $0.primaryURL.absoluteString == "https://example.com/photo-story" })
        #expect(linkStatuses.contains { $0.id == "rich-card" && $0.primaryURL.absoluteString == "https://example.com/rich-story" })
    }

    @Test("Falls back to plain text links when no anchor tags exist")
    func fallsBackToPlainTextLinksWhenNoAnchorTagsExist() async {
        let status = MockStatusFactory.makeStatus(
            id: "plain-text-url",
            content: "<p>Read this next: https://example.com/plain-text-story</p>"
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.id == "plain-text-url")
        #expect(linkStatuses.first?.primaryURL.absoluteString == "https://example.com/plain-text-story")
    }

    @Test("Excludes statuses that only contain internal Mastodon URLs")
    func excludesStatusesThatOnlyContainInternalMastodonURLs() async {
        let internalCardStatus = MockStatusFactory.makeStatus(
            id: "internal-card",
            hasCard: true,
            cardURL: "https://mastodon.social/@testuser/123456"
        )
        let internalContentStatus = MockStatusFactory.makeStatus(
            id: "internal-content",
            content: """
            <p>
            <a href="https://mastodon.social/@someone">profile</a>
            <a href="https://mastodon.social/tags/swift">tag</a>
            <a href="https://mastodon.social/@someone/999">status</a>
            </p>
            """
        )

        let linkStatuses = await service.processStatuses([internalCardStatus, internalContentStatus])

        #expect(linkStatuses.isEmpty)
    }
    
    // MARK: - Quote Post Detection
    
    @Test("Detects quote posts correctly")
    func detectsQuotePosts() async {
        let quotePost = MockStatusFactory.makeStatus(isQuote: true)
        
        let isQuote = service.isQuotePost(quotePost)
        
        #expect(isQuote == true)
    }
    
    @Test("Regular posts are not marked as quotes")
    func regularPostsNotQuotes() async {
        let regularPost = MockStatusFactory.makeStatus(isQuote: false)
        
        let isQuote = service.isQuotePost(regularPost)
        
        #expect(isQuote == false)
    }
    
    // MARK: - Link Extraction
    
    @Test("Extracts external links from status content")
    func extractsExternalLinks() async {
        let status = MockStatusFactory.makeStatus(
            content: """
            <p>Multiple links: 
            <a href="https://example.com/article1">first</a> and 
            <a href="https://other.com/article2">second</a></p>
            """
        )
        
        let links = service.extractExternalLinks(from: status)
        
        #expect(links.count == 2)
        #expect(links.contains { $0.absoluteString == "https://example.com/article1" })
        #expect(links.contains { $0.absoluteString == "https://other.com/article2" })
    }

    @Test("Plain text fallback only runs when anchor links are absent")
    func plainTextFallbackOnlyRunsWhenAnchorLinksAreAbsent() async {
        let status = MockStatusFactory.makeStatus(
            content: """
            <p>
            Anchor first <a href="https://example.com/anchor-story">story</a>
            then https://example.com/plain-text-story
            </p>
            """
        )

        let links = service.extractExternalLinks(from: status)

        #expect(links.count == 1)
        #expect(links.first?.absoluteString == "https://example.com/anchor-story")
    }
    
    // MARK: - Processing
    
    @Test("Processes statuses into link statuses")
    func processesStatuses() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "1",
                hasCard: true,
                cardURL: "https://example.com/article",
                cardTitle: "Test Article"
            ),
            MockStatusFactory.makeStatus(
                id: "2",
                content: "<p>No links</p>"
            )
        ]
        
        let linkStatuses = await service.processStatuses(statuses)
        
        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.title == "Test Article")
        #expect(linkStatuses.first?.primaryURL.absoluteString == "https://example.com/article")
    }

    @Test("Preserves existing attribution when a feed is rebuilt")
    func preservesExistingAttributionWhenReprocessingFeed() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "1",
                hasCard: true,
                cardURL: "https://example.com/article",
                cardTitle: "Test Article"
            )
        ]

        _ = await service.processStatuses(statuses, for: "home")
        service.applyAttribution(
            AuthorAttribution(
                name: "Jane Example",
                url: "https://mastodon.social/@jane",
                source: .metaTag,
                mastodonHandle: "@jane@mastodon.social",
                mastodonProfileURL: "https://mastodon.social/@jane",
                profilePictureURL: "https://example.com/jane.jpg"
            ),
            toLinkStatusID: "1"
        )

        let rebuiltStatuses = await service.processStatuses(statuses, for: "home")

        #expect(rebuiltStatuses.count == 1)
        #expect(rebuiltStatuses.first?.authorAttribution == "Jane Example")
        #expect(rebuiltStatuses.first?.mastodonHandle == "@jane@mastodon.social")
        #expect(rebuiltStatuses.first?.mastodonProfileURL == "https://mastodon.social/@jane")
        #expect(rebuiltStatuses.first?.authorProfilePictureURL == "https://example.com/jane.jpg")
    }

    @Test("Deduplicates API tags case-insensitively")
    func deduplicatesAPITagsCaseInsensitively() async {
        let status = MockStatusFactory.makeStatus(
            id: "1",
            hasCard: true,
            cardURL: "https://example.com/article",
            tags: [
                Tag(name: "Swift", url: "https://mastodon.social/tags/swift", history: nil),
                Tag(name: "swift", url: "https://mastodon.social/tags/swift", history: nil),
                Tag(name: "iOS", url: "https://mastodon.social/tags/ios", history: nil)
            ]
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        let normalizedTags = Set((linkStatuses.first?.tags ?? []).map { $0.lowercased() })
        #expect(normalizedTags == Set(["ios", "swift"]))
    }

    @Test("Deduplicates extracted content tags case-insensitively")
    func deduplicatesExtractedContentTagsCaseInsensitively() async {
        let status = MockStatusFactory.makeStatus(
            id: "1",
            content: "<p>#Swift #swift #iOS</p>",
            hasCard: true,
            cardURL: "https://example.com/article"
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        let normalizedTags = Set((linkStatuses.first?.tags ?? []).map { $0.lowercased() })
        #expect(normalizedTags == Set(["ios", "swift"]))
    }

    @Test("Preserves original hashtag case from post content")
    func preservesOriginalHashtagCaseFromPostContent() async {
        let status = MockStatusFactory.makeStatus(
            id: "1",
            content: "<p>#SwiftUI #OpenAI</p>",
            hasCard: true,
            cardURL: "https://example.com/article",
            tags: [
                Tag(name: "swiftui", url: "https://mastodon.social/tags/swiftui", history: nil),
                Tag(name: "openai", url: "https://mastodon.social/tags/openai", history: nil)
            ]
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.tags.contains("SwiftUI") == true)
        #expect(linkStatuses.first?.tags.contains("OpenAI") == true)
        #expect(linkStatuses.first?.tags.contains("swiftui") == false)
        #expect(linkStatuses.first?.tags.contains("openai") == false)
    }

    @Test("Ignores linked page sections when extracting content tags")
    func ignoresLinkedPageSectionsWhenExtractingContentTags() async {
        let status = MockStatusFactory.makeStatus(
            id: "1",
            content: """
            <p>
            Read <a href="https://example.com/article#overview">#Overview</a>
            and follow #Swift
            </p>
            """,
            hasCard: true,
            cardURL: "https://example.com/article"
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.tags == ["Swift"])
    }

    @Test("Preserves hashtags from Mastodon hashtag links in post content")
    func preservesHashtagsFromMastodonHashtagLinksInPostContent() async {
        let status = MockStatusFactory.makeStatus(
            id: "1",
            content: """
            <p>
            <a href="https://mastodon.social/tags/SwiftUI" class="mention hashtag" rel="tag">
            #<span>SwiftUI</span>
            </a>
            </p>
            """,
            hasCard: true,
            cardURL: "https://example.com/article",
            tags: [
                Tag(name: "swiftui", url: "https://mastodon.social/tags/swiftui", history: nil)
            ]
        )

        let linkStatuses = await service.processStatuses([status])

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.tags == ["SwiftUI"])
    }
    
    // MARK: - Threads/Instagram Exclusion
    
    @Test("Excludes Threads and Instagram links from processed results")
    func excludesThreadsAndInstagramLinks() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "threads-net",
                hasCard: true,
                cardURL: "https://www.threads.net/@user/post/123"
            ),
            MockStatusFactory.makeStatus(
                id: "threads-com",
                hasCard: true,
                cardURL: "https://www.threads.com/some/post"
            ),
            MockStatusFactory.makeStatus(
                id: "instagram",
                hasCard: true,
                cardURL: "https://www.instagram.com/p/xyz"
            ),
            MockStatusFactory.makeStatus(
                id: "content-threads",
                content: "<p>Check this <a href=\"https://threads.net/@x/post/1\">link</a></p>"
            ),
            MockStatusFactory.makeStatus(
                id: "article",
                hasCard: true,
                cardURL: "https://example.com/article"
            )
        ]
        
        let linkStatuses = await service.processStatuses(statuses)
        
        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.id == "article")
        #expect(linkStatuses.first?.primaryURL.absoluteString == "https://example.com/article")
    }
    
    @Test("Includes replies that have article links in content")
    func includesRepliesWithArticleLinks() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "reply-with-article",
                content: "<p>Great point! Here's more: <a href=\"https://example.com/deep-dive\">read this</a></p>",
                inReplyToId: "parent-status-id"
            ),
            MockStatusFactory.makeStatus(
                id: "reply-with-article-card",
                hasCard: true,
                cardURL: "https://news.site/article",
                inReplyToId: "bridged-bluesky-parent"
            ),
            MockStatusFactory.makeStatus(
                id: "reply-mixed-links",
                content: """
                <p>Replying to <a href="https://bsky.app/post/abc">thread</a> —
                also see <a href="https://example.com/related">this article</a></p>
                """,
                inReplyToId: "bluesky-parent"
            )
        ]

        let linkStatuses = await service.processStatuses(statuses)

        #expect(linkStatuses.count == 3)
        #expect(linkStatuses.contains { $0.id == "reply-with-article" && $0.primaryURL.absoluteString == "https://example.com/deep-dive" })
        #expect(linkStatuses.contains { $0.id == "reply-with-article-card" && $0.primaryURL.absoluteString == "https://news.site/article" })
        #expect(linkStatuses.contains { $0.id == "reply-mixed-links" && $0.primaryURL.absoluteString == "https://example.com/related" })
    }

    @Test("Excludes Bluesky and BridgyFed links from processed results")
    func excludesBlueskyLinks() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "bluesky-card",
                hasCard: true,
                cardURL: "https://bsky.app/profile/user.bsky.social/post/abc123"
            ),
            MockStatusFactory.makeStatus(
                id: "bluesky-content",
                content: "<p>Reply <a href=\"https://bsky.app/post/xyz\">to thread</a></p>"
            ),
            MockStatusFactory.makeStatus(
                id: "bridgy-reply",
                hasCard: true,
                cardURL: "https://bsky.social/xrpc/app.bsky.feed.getPost",
                inReplyToId: "parent-id"
            ),
            MockStatusFactory.makeStatus(
                id: "article",
                hasCard: true,
                cardURL: "https://example.com/article"
            )
        ]

        let linkStatuses = await service.processStatuses(statuses)

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.id == "article")
        #expect(linkStatuses.first?.primaryURL.absoluteString == "https://example.com/article")
    }

    @Test("Processes list batches with retrievable links even when no cards are typed as link")
    func processesListBatchesWithRetrievableLinksWhenNoCardsAreTypedAsLink() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "photo-card",
                hasCard: true,
                cardURL: "https://example.com/photo-story",
                cardType: .photo
            ),
            MockStatusFactory.makeStatus(
                id: "rich-card",
                hasCard: true,
                cardURL: "https://example.com/rich-story",
                cardType: .rich
            ),
            MockStatusFactory.makeStatus(
                id: "plain-text",
                content: "<p>Context https://example.com/plain-text-story</p>"
            )
        ]

        let linkStatuses = await service.processStatuses(statuses, for: "list-3")

        #expect(linkStatuses.count == 3)
        #expect(linkStatuses.map(\.id) == ["photo-card", "rich-card", "plain-text"])
    }

    @Test("Processes older pages until empty feeds gain visible content")
    func processesOlderPagesUntilEmptyFeedsGainVisibleContent() async {
        let initialStatuses = [
            MockStatusFactory.makeStatus(id: "no-link-1", content: "<p>No external links here</p>")
        ]
        let olderStatuses = [
            MockStatusFactory.makeStatus(
                id: "older-link",
                hasCard: true,
                cardURL: "https://example.com/older-story"
            )
        ]
        var remainingPages = [olderStatuses]

        let linkStatuses = await service.processStatusesEnsuringVisibleContent(
            initialStatuses,
            for: "list-older",
            canLoadMore: { !remainingPages.isEmpty },
            loadMoreStatuses: { remainingPages.removeFirst() }
        )

        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.id == "older-link")
        #expect(remainingPages.isEmpty)
    }

    @Test("Appends older pages until pagination yields additional visible content")
    func appendsOlderPagesUntilPaginationYieldsAdditionalVisibleContent() async {
        _ = await service.processStatuses(
            [
                MockStatusFactory.makeStatus(
                    id: "existing-link",
                    hasCard: true,
                    cardURL: "https://example.com/existing-story"
                )
            ],
            for: "list-pagination"
        )

        let firstPaginationBatch = [
            MockStatusFactory.makeStatus(id: "no-link-page", content: "<p>Still no links</p>")
        ]
        let olderStatuses = [
            MockStatusFactory.makeStatus(
                id: "older-link",
                hasCard: true,
                cardURL: "https://example.com/older-story"
            )
        ]
        var remainingPages = [olderStatuses]

        let linkStatuses = await service.appendStatusesEnsuringAdditionalContent(
            firstPaginationBatch,
            for: "list-pagination",
            canLoadMore: { !remainingPages.isEmpty },
            loadMoreStatuses: { remainingPages.removeFirst() }
        )

        #expect(linkStatuses.count == 2)
        #expect(linkStatuses.map(\.id) == ["existing-link", "older-link"])
        #expect(remainingPages.isEmpty)
    }

    @Test("Excludes Threads and Instagram subdomains and bare domains")
    func excludesThreadsAndInstagramSubdomainsAndBareDomains() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "lm-threads",
                hasCard: true,
                cardURL: "https://lm.threads.com/post/abc"
            ),
            MockStatusFactory.makeStatus(
                id: "bare-threads",
                hasCard: true,
                cardURL: "https://threads.com/post/xyz"
            ),
            MockStatusFactory.makeStatus(
                id: "lm-insta",
                hasCard: true,
                cardURL: "https://lm.instagram.com/reel/123"
            ),
            MockStatusFactory.makeStatus(
                id: "bare-insta",
                hasCard: true,
                cardURL: "https://instagram.com/p/abc"
            ),
            MockStatusFactory.makeStatus(
                id: "article",
                hasCard: true,
                cardURL: "https://example.com/article"
            )
        ]
        
        let linkStatuses = await service.processStatuses(statuses)
        
        #expect(linkStatuses.count == 1)
        #expect(linkStatuses.first?.id == "article")
        #expect(linkStatuses.first?.primaryURL.absoluteString == "https://example.com/article")
    }
    
    // MARK: - Quote Post Detection (pattern-based)
    
    @Test("Detects quote post via RE: prefix in content")
    func detectsQuotePostViaREPrefix() async {
        let status = MockStatusFactory.makeStatus(
            content: "<p>RE: my take on this</p>",
            isQuote: false
        )
        #expect(service.isQuotePost(status) == true)
    }
    
    @Test("Detects quote post via QT: prefix in content")
    func detectsQuotePostViaQTPrefix() async {
        let status = MockStatusFactory.makeStatus(
            content: "<p>QT: something quoted</p>",
            isQuote: false
        )
        #expect(service.isQuotePost(status) == true)
    }
    
    // MARK: - Account Discovery

    @Test("Gets unique accounts from link statuses")
    func getsUniqueAccountsFromLinkStatuses() async {
        let alice = MockStatusFactory.makeAccount(id: "acct-alice", username: "alice")
        let bob = MockStatusFactory.makeAccount(id: "acct-bob", username: "bob")

        let statuses = [
            MockStatusFactory.makeStatus(id: "1", hasCard: true, cardURL: "https://example.com/a", account: alice),
            MockStatusFactory.makeStatus(id: "2", hasCard: true, cardURL: "https://example.com/b", account: alice),
            MockStatusFactory.makeStatus(id: "3", hasCard: true, cardURL: "https://other.com/c", account: bob)
        ]

        let linkStatuses = await service.processStatuses(statuses)
        let accounts = service.uniqueAccounts(in: linkStatuses)

        #expect(accounts.count == 2)
        #expect(Set(accounts.map(\.id)) == Set(["acct-alice", "acct-bob"]))
    }

    @Test("Unique accounts are sorted by display name")
    func uniqueAccountsAreSortedByDisplayName() async {
        let charlie = MockStatusFactory.makeAccount(id: "acct-charlie", username: "charlie", displayName: "Charlie")
        let alice = MockStatusFactory.makeAccount(id: "acct-alice", username: "alice", displayName: "Alice")

        let statuses = [
            MockStatusFactory.makeStatus(id: "1", hasCard: true, cardURL: "https://example.com/a", account: charlie),
            MockStatusFactory.makeStatus(id: "2", hasCard: true, cardURL: "https://example.com/b", account: alice)
        ]

        _ = await service.processStatuses(statuses)
        let accounts = service.uniqueAccounts()

        #expect(accounts.map(\.id) == ["acct-alice", "acct-charlie"])
    }

    @Test("Feed-scoped data reads from the requested feed even when another feed is active")
    func feedScopedDataReadsRequestedFeedWhenAnotherFeedIsActive() async {
        let homeAccount = MockStatusFactory.makeAccount(id: "acct-home", username: "home")
        let listAccount = MockStatusFactory.makeAccount(id: "acct-list", username: "list")

        let homeStatuses = [
            MockStatusFactory.makeStatus(
                id: "home-1",
                hasCard: true,
                cardURL: "https://example.com/home",
                account: homeAccount
            )
        ]
        let listStatuses = [
            MockStatusFactory.makeStatus(
                id: "list-1",
                hasCard: true,
                cardURL: "https://example.com/list",
                account: listAccount
            )
        ]

        _ = await service.processStatuses(homeStatuses, for: AppState.homeFeedID)
        _ = await service.processStatuses(listStatuses, for: "list-1")
        service.switchToFeed(AppState.homeFeedID)

        let scopedStatuses = FeedScopedLinkData.filteredStatuses(
            in: service,
            feedId: "list-1",
            userFilterAccountId: nil
        )
        let scopedAccounts = FeedScopedLinkData.accounts(in: service, feedId: "list-1")

        #expect(scopedStatuses.map(\.id) == ["list-1"])
        #expect(scopedAccounts.map(\.id) == ["acct-list"])
    }
    
    // MARK: - Filter by Account
    
    @Test("Filter by account ID returns only matching link statuses")
    func filterByAccountIdReturnsOnlyMatching() async {
        let statuses = [
            MockStatusFactory.makeStatus(id: "1", hasCard: true, cardURL: "https://example.com/a"),
            MockStatusFactory.makeStatus(id: "2", hasCard: true, cardURL: "https://example.com/b")
        ]
        let linkStatuses = await service.processStatuses(statuses)
        #expect(linkStatuses.count == 2)
        
        let accountId = linkStatuses[0].status.displayStatus.account.id
        let filtered = service.filter(linkStatuses: linkStatuses, byAccountId: accountId)
        
        #expect(filtered.count == 1)
        #expect(filtered[0].status.displayStatus.account.id == accountId)
    }
    
    @Test("Filter by nil account ID returns all link statuses")
    func filterByNilAccountIdReturnsAll() async {
        let statuses = [
            MockStatusFactory.makeStatus(id: "1", hasCard: true, cardURL: "https://example.com/a"),
            MockStatusFactory.makeStatus(id: "2", hasCard: true, cardURL: "https://example.com/b")
        ]
        let linkStatuses = await service.processStatuses(statuses)
        let filtered = service.filter(linkStatuses: linkStatuses, byAccountId: nil)
        
        #expect(filtered.count == 2)
    }
}

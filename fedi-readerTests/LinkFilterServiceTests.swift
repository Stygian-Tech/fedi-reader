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

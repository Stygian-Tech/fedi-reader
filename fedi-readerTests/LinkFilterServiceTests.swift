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
struct LinkFilterServiceTests {
    
    @MainActor
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
    
    // MARK: - Filtering by Domain
    
    @Test("Filters link statuses by domain")
    func filtersByDomain() async {
        let statuses = [
            MockStatusFactory.makeStatus(
                id: "1",
                hasCard: true,
                cardURL: "https://example.com/article1"
            ),
            MockStatusFactory.makeStatus(
                id: "2",
                hasCard: true,
                cardURL: "https://other.com/article2"
            )
        ]
        
        _ = await service.processStatuses(statuses)
        let exampleLinks = service.filterByDomain("example.com")
        
        #expect(exampleLinks.count == 1)
        #expect(exampleLinks.first?.domain == "example.com")
    }
    
    @Test("Gets unique domains from link statuses")
    func getsUniqueDomains() async {
        let statuses = [
            MockStatusFactory.makeStatus(id: "1", hasCard: true, cardURL: "https://example.com/a"),
            MockStatusFactory.makeStatus(id: "2", hasCard: true, cardURL: "https://example.com/b"),
            MockStatusFactory.makeStatus(id: "3", hasCard: true, cardURL: "https://other.com/c")
        ]
        
        _ = await service.processStatuses(statuses)
        let domains = service.uniqueDomains()
        
        #expect(domains.count == 2)
        #expect(domains.contains("example.com"))
        #expect(domains.contains("other.com"))
    }
}

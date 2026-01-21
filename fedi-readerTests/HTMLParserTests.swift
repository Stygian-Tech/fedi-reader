//
//  HTMLParserTests.swift
//  fedi-readerTests
//
//  Tests for HTMLParser
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("HTML Parser Tests")
struct HTMLParserTests {
    
    // MARK: - Link Extraction
    
    @Test("Extracts links from HTML")
    func extractsLinks() {
        let html = """
        <p>Check out <a href="https://example.com/article">this article</a></p>
        """
        
        let links = HTMLParser.extractLinks(from: html)
        
        #expect(links.count == 1)
        #expect(links.first?.absoluteString == "https://example.com/article")
    }
    
    @Test("Extracts multiple links")
    func extractsMultipleLinks() {
        let html = """
        <p>Links: <a href="https://one.com">one</a>, <a href="https://two.com">two</a></p>
        """
        
        let links = HTMLParser.extractLinks(from: html)
        
        #expect(links.count == 2)
    }
    
    @Test("Handles HTML entities in URLs")
    func handlesHTMLEntities() {
        let html = """
        <p><a href="https://example.com/article?foo=1&amp;bar=2">link</a></p>
        """
        
        let links = HTMLParser.extractLinks(from: html)
        
        #expect(links.count == 1)
        #expect(links.first?.absoluteString == "https://example.com/article?foo=1&bar=2")
    }
    
    @Test("Excludes non-HTTP URLs")
    func excludesNonHTTPURLs() {
        let html = """
        <p><a href="javascript:void(0)">js</a> <a href="https://valid.com">valid</a></p>
        """
        
        let links = HTMLParser.extractLinks(from: html)
        
        #expect(links.count == 1)
        #expect(links.first?.absoluteString == "https://valid.com")
    }
    
    @Test("Filters external links excluding specified domains")
    func filtersExternalLinks() {
        let html = """
        <p>
        <a href="https://mastodon.social/@user">mention</a>
        <a href="https://external.com/article">article</a>
        </p>
        """
        
        let links = HTMLParser.extractExternalLinks(from: html, excludingDomains: ["mastodon.social"])
        
        #expect(links.count == 1)
        #expect(links.first?.host == "external.com")
    }
    
    // MARK: - HTML Stripping
    
    @Test("Strips HTML tags")
    func stripsHTMLTags() {
        let html = "<p>Hello <strong>world</strong>!</p>"
        
        let plain = HTMLParser.stripHTML(html)
        
        #expect(plain == "Hello world!")
    }
    
    @Test("Converts breaks to newlines")
    func convertBreaksToNewlines() {
        let html = "Line one<br>Line two<br/>Line three"
        
        let plain = HTMLParser.convertToPlainText(html)
        
        #expect(plain.contains("\n"))
    }
    
    @Test("Handles paragraph tags")
    func handlesParagraphs() {
        let html = "<p>First paragraph</p><p>Second paragraph</p>"
        
        let plain = HTMLParser.convertToPlainText(html)
        
        #expect(plain.contains("\n"))
        #expect(plain.contains("First paragraph"))
        #expect(plain.contains("Second paragraph"))
    }
    
    // MARK: - HTML Entity Decoding
    
    @Test("Decodes common HTML entities")
    func decodesCommonEntities() {
        let html = "&amp; &lt; &gt; &quot; &apos;"
        
        let decoded = HTMLParser.decodeHTMLEntities(html)
        
        #expect(decoded == "& < > \" '")
    }
    
    @Test("Decodes numeric entities")
    func decodesNumericEntities() {
        let html = "&#65; &#66; &#67;"
        
        let decoded = HTMLParser.decodeHTMLEntities(html)
        
        #expect(decoded == "A B C")
    }
    
    @Test("Decodes hex entities")
    func decodesHexEntities() {
        let html = "&#x41; &#x42; &#x43;"
        
        let decoded = HTMLParser.decodeHTMLEntities(html)
        
        #expect(decoded == "A B C")
    }
    
    // MARK: - Mention and Hashtag Extraction
    
    @Test("Extracts mentions from content")
    func extractsMentions() {
        let html = "<p>Hey @user@mastodon.social and @localuser!</p>"
        
        let mentions = HTMLParser.extractMentions(from: html)
        
        #expect(mentions.count == 2)
        #expect(mentions.contains("@user@mastodon.social"))
        #expect(mentions.contains("@localuser"))
    }
    
    @Test("Extracts hashtags from content")
    func extractsHashtags() {
        let html = "<p>Check out #swift and #programming</p>"
        
        let hashtags = HTMLParser.extractHashtags(from: html)
        
        #expect(hashtags.count == 2)
        #expect(hashtags.contains("#swift"))
        #expect(hashtags.contains("#programming"))
    }
    
    // MARK: - Domain Extraction
    
    @Test("Extracts domain from URL")
    func extractsDomain() {
        let url = URL(string: "https://www.example.com/path")!
        
        let domain = HTMLParser.extractDomain(from: url)
        
        #expect(domain == "example.com")
    }
    
    @Test("Handles URLs without www")
    func handlesURLsWithoutWWW() {
        let url = URL(string: "https://example.com/path")!
        
        let domain = HTMLParser.extractDomain(from: url)
        
        #expect(domain == "example.com")
    }
    
    // MARK: - AttributedString Conversion
    
    @Test("Converts HTML to AttributedString with links")
    @available(iOS 15.0, macOS 12.0, *)
    func convertsToAttributedString() {
        let html = "<p>Check out <a href=\"https://example.com/article\">this article</a></p>"
        
        let attributedString = HTMLParser.convertToAttributedString(html)
        
        #expect(!attributedString.characters.isEmpty)
        // Check that link attribute is set
        let hasLink = attributedString.runs.contains { run in
            run.link != nil
        }
        #expect(hasLink == true)
    }
    
    @Test("Handles multiple links in AttributedString")
    @available(iOS 15.0, macOS 12.0, *)
    func handlesMultipleLinksInAttributedString() {
        let html = "<p>Visit <a href=\"https://one.com\">first</a> and <a href=\"https://two.com\">second</a></p>"
        
        let attributedString = HTMLParser.convertToAttributedString(html)
        
        let linkCount = attributedString.runs.filter { $0.link != nil }.count
        #expect(linkCount >= 2)
    }
    
    @Test("Handles nested tags in link text")
    @available(iOS 15.0, macOS 12.0, *)
    func handlesNestedTagsInLinks() {
        let html = "<p><a href=\"https://example.com\"><strong>bold link</strong></a></p>"
        
        let attributedString = HTMLParser.convertToAttributedString(html)
        
        #expect(!attributedString.characters.isEmpty)
        let hasLink = attributedString.runs.contains { run in
            run.link != nil
        }
        #expect(hasLink == true)
    }
    
    @Test("String extension provides htmlToAttributedString")
    @available(iOS 15.0, macOS 12.0, *)
    func stringExtensionProvidesAttributedString() {
        let html = "<p>Test <a href=\"https://example.com\">link</a></p>"
        
        let attributedString = html.htmlToAttributedString
        
        #expect(!attributedString.characters.isEmpty)
    }
}

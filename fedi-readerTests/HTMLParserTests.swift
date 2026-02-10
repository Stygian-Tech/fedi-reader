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

    @Test("Converts break tags with flexible spacing")
    func convertsBreakTagsWithFlexibleSpacing() {
        let html = "Line one<br   />Line two<BR    >Line three"

        let plain = HTMLParser.convertToPlainText(html)

        #expect(plain == "Line one\nLine two\nLine three")
    }

    @Test("Converts break tags with attributes")
    func convertsBreakTagsWithAttributes() {
        let html = "Line one<br class=\"line-break\" data-test=\"true\">Line two<Br id='bio-break'>Line three"

        let plain = HTMLParser.convertToPlainText(html)

        #expect(plain == "Line one\nLine two\nLine three")
    }

    @Test("Converts closing break tags")
    func convertsClosingBreakTags() {
        let html = "Line one</br>Line two"

        let plain = HTMLParser.convertToPlainTextPreservingNewlines(html)

        #expect(plain == "Line one\nLine two")
    }

    @Test("Preserves consecutive newlines when requested")
    func preservesConsecutiveNewlinesWhenRequested() {
        let html = "<p>Line one<br><br>Line two</p>"

        let plain = HTMLParser.convertToPlainTextPreservingNewlines(html)

        #expect(plain == "Line one\n\nLine two")
    }

    @Test("Normalizes CRLF and Unicode newline separators")
    func normalizesAdditionalNewlineSeparators() {
        let html = "Line one\r\nLine two&#x2028;Line three&#x2029;Line four&#133;Line five"

        let plain = HTMLParser.convertToPlainTextPreservingNewlines(html)

        #expect(plain == "Line one\nLine two\nLine three\nLine four\nLine five")
    }

    @Test("Decodes HTML5 newline entity")
    func decodesHTML5NewlineEntity() {
        let html = "Line one&NewLine;Line two"

        let plain = HTMLParser.convertToPlainTextPreservingNewlines(html)

        #expect(plain == "Line one\nLine two")
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

    @Test("AttributedString preserves bio-style newlines when requested")
    @available(iOS 15.0, macOS 12.0, *)
    func attributedStringPreservesBioStyleNewlinesWhenRequested() {
        let html = "<p>Line one<br><br><br>#swift</p>"
        let hashtagHandler: (String) -> URL? = { tag in URL(string: "hashtag://\(tag)") }

        let preserved = HTMLParser.convertToAttributedString(
            html,
            preserveNewlines: true,
            hashtagHandler: hashtagHandler
        )
        let collapsed = HTMLParser.convertToAttributedString(
            html,
            hashtagHandler: hashtagHandler
        )

        let preservedText = String(preserved.characters)
        let collapsedText = String(collapsed.characters)

        #expect(preservedText.contains("\n\n\n"))
        #expect(collapsedText.contains("\n\n"))
        #expect(!collapsedText.contains("\n\n\n"))
        #expect(preserved.runs.contains { $0.link?.scheme == "hashtag" })
    }

    @Test("Handles several links and hashtags in AttributedString without crashing")
    @available(iOS 15.0, macOS 12.0, *)
    func handlesSeveralLinksAndHashtagsInAttributedString() {
        let html = """
        <p>Check <a href="https://a.com">one</a> and <a href="https://b.com">two</a> and \
        <a href="https://c.com">three</a>. Tags: #swift #ios #mastodon.</p>
        """
        let attributedString = HTMLParser.convertToAttributedString(html) { _ in URL(string: "https://tags.example.com") }
        #expect(!attributedString.characters.isEmpty)
        let linkRuns = attributedString.runs.filter { $0.link != nil }
        #expect(linkRuns.count >= 3)
    }
    
    // MARK: - Emoji Replacement
    
    @Test("Replaces emoji shortcode in HTML")
    func replacesEmojiShortcode() {
        let emoji = CustomEmoji(
            shortcode: "test",
            url: "https://example.com/emoji.png",
            staticUrl: "https://example.com/emoji_static.png",
            visibleInPicker: true,
            category: nil
        )
        let lookup: [String: CustomEmoji] = ["test": emoji]
        
        let html = "Hello :test: world"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: lookup)
        
        #expect(result.contains("emoji.png"))
        #expect(result.contains("<img"))
        #expect(result.contains("alt=\":test:\""))
    }
    
    @Test("Replaces multiple emoji in HTML")
    func replacesMultipleEmoji() {
        let emoji1 = CustomEmoji(shortcode: "smile", url: "https://example.com/smile.png", staticUrl: "", visibleInPicker: true, category: nil)
        let emoji2 = CustomEmoji(shortcode: "wave", url: "https://example.com/wave.png", staticUrl: "", visibleInPicker: true, category: nil)
        let lookup: [String: CustomEmoji] = ["smile": emoji1, "wave": emoji2]
        
        let html = "Hello :smile: and :wave:"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: lookup)
        
        #expect(result.contains("smile.png"))
        #expect(result.contains("wave.png"))
        let imgCount = result.components(separatedBy: "<img").count - 1
        #expect(imgCount == 2)
    }
    
    @Test("Does not replace emoji inside img tags")
    func doesNotReplaceInsideImgTags() {
        let emoji = CustomEmoji(shortcode: "test", url: "https://example.com/test.png", staticUrl: "", visibleInPicker: true, category: nil)
        let lookup: [String: CustomEmoji] = ["test": emoji]
        
        let html = "<img src=\"test.png\" alt=\":test:\" />"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: lookup)
        
        // Should not add another img tag inside
        let imgCount = result.components(separatedBy: "<img").count - 1
        #expect(imgCount == 1)
    }
    
    @Test("Handles invalid shortcodes gracefully")
    func handlesInvalidShortcodes() {
        let lookup: [String: CustomEmoji] = [:]
        
        let html = "Hello :invalid: world"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: lookup)
        
        #expect(result == html)
    }
    
    @Test("Emoji replacement happens before link extraction")
    @available(iOS 15.0, macOS 12.0, *)
    func emojiReplacementBeforeLinkExtraction() {
        let emoji = CustomEmoji(shortcode: "test", url: "https://example.com/emoji.png", staticUrl: "", visibleInPicker: true, category: nil)
        let lookup: [String: CustomEmoji] = ["test": emoji]
        
        let html = "<p>Check :test: and <a href=\"https://example.com/article\">link</a></p>"
        let attributedString = HTMLParser.convertToAttributedString(html, hashtagHandler: nil, emojiLookup: lookup)
        
        // Should have both emoji img and link
        #expect(!attributedString.characters.isEmpty)
        let hasLink = attributedString.runs.contains { $0.link != nil }
        #expect(hasLink == true)
    }
    
    @Test("Handles emoji with special characters in shortcode")
    func handlesEmojiWithSpecialCharacters() {
        let emoji = CustomEmoji(shortcode: "test_emoji+123", url: "https://example.com/test.png", staticUrl: "", visibleInPicker: true, category: nil)
        let lookup: [String: CustomEmoji] = ["test_emoji+123": emoji]
        
        let html = "Hello :test_emoji+123:"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: lookup)
        
        #expect(result.contains("test.png"))
    }
    
    @Test("Handles empty emoji lookup")
    func handlesEmptyEmojiLookup() {
        let html = "Hello :test: world"
        let result = HTMLParser.replaceEmojiShortcodes(html, emojiLookup: [:])
        
        #expect(result == html)
    }
    
    @Test("Handles nil emoji lookup in convertToAttributedString")
    @available(iOS 15.0, macOS 12.0, *)
    func handlesNilEmojiLookup() {
        let html = "<p>Hello :test: <a href=\"https://example.com\">link</a></p>"
        let attributedString = HTMLParser.convertToAttributedString(html, hashtagHandler: nil, emojiLookup: nil)
        
        #expect(!attributedString.characters.isEmpty)
        // Should still process links even without emoji lookup
        let hasLink = attributedString.runs.contains { $0.link != nil }
        #expect(hasLink == true)
    }
}

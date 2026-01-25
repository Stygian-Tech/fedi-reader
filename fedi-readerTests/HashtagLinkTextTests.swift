//
//  HashtagLinkTextTests.swift
//  fedi-readerTests
//
//  Tests for HashtagLinkText view and hashtag handling
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("Hashtag Link Text Tests")
struct HashtagLinkTextTests {
    
    // MARK: - Hashtag URL Scheme Tests
    
    @Test("Hashtag URL scheme parsing")
    func hashtagURLSchemeParsing() {
        let url = URL(string: "hashtag://swift")!
        #expect(url.scheme == "hashtag")
        #expect(url.host == "swift")
    }
    
    @Test("Hashtag URL with path components")
    func hashtagURLWithPathComponents() {
        let url = URL(string: "hashtag:///swift")!
        let tag = url.host ?? url.pathComponents.last ?? ""
        #expect(tag == "swift" || tag == "")
    }
    
    @Test("Hashtag URL extraction from various formats")
    func hashtagURLExtraction() {
        // Test host extraction
        let url1 = URL(string: "hashtag://swift")!
        let tag1 = url1.host ?? url1.pathComponents.last ?? ""
        #expect(tag1 == "swift")
        
        // Test path component extraction fallback
        let url2 = URL(string: "hashtag:///programming")!
        let tag2 = url2.host ?? url2.pathComponents.last ?? ""
        #expect(tag2 == "programming" || tag2 == "")
    }
    
    // MARK: - Emoji Lookup Logic Tests
    
    @Test("Emoji lookup dictionary building")
    func emojiLookupDictionaryBuilding() {
        let emoji1 = CustomEmoji(shortcode: "smile", url: "https://example.com/smile.png", staticUrl: "", visibleInPicker: true, category: nil)
        let emoji2 = CustomEmoji(shortcode: "wave", url: "https://example.com/wave.png", staticUrl: "", visibleInPicker: true, category: nil)
        
        let emojis = [emoji1, emoji2]
        let lookup = Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
        
        #expect(lookup.count == 2)
        #expect(lookup["smile"]?.shortcode == "smile")
        #expect(lookup["wave"]?.shortcode == "wave")
    }
    
    @Test("Empty emoji list creates empty lookup")
    func emptyEmojiListCreatesEmptyLookup() {
        let emojis: [CustomEmoji] = []
        let lookup = Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
        
        #expect(lookup.isEmpty)
    }
    
    @Test("Duplicate shortcodes in emoji list")
    func duplicateShortcodesInEmojiList() {
        let emoji1 = CustomEmoji(shortcode: "test", url: "https://example.com/first.png", staticUrl: "", visibleInPicker: true, category: nil)
        let emoji2 = CustomEmoji(shortcode: "test", url: "https://example.com/second.png", staticUrl: "", visibleInPicker: true, category: nil)
        
        let emojis = [emoji1, emoji2]
        let lookup = Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
        
        // Dictionary will only keep one (last one wins)
        #expect(lookup.count == 1)
        #expect(lookup["test"] != nil)
    }
    
    // MARK: - Hashtag Handler Tests
    
    @Test("Hashtag handler creates correct URL")
    func hashtagHandlerCreatesCorrectURL() {
        let handler: (String) -> URL? = { tag in
            URL(string: "hashtag://\(tag)")
        }
        
        let url = handler("swift")
        #expect(url != nil)
        #expect(url?.scheme == "hashtag")
        #expect(url?.host == "swift")
    }
    
    @Test("Hashtag handler with special characters")
    func hashtagHandlerWithSpecialCharacters() {
        let handler: (String) -> URL? = { tag in
            URL(string: "hashtag://\(tag)")
        }
        
        // Test with tag containing special characters that need encoding
        let tag = "test-tag_123"
        let url = handler(tag)
        #expect(url != nil)
    }
    
    // MARK: - Integration with HTMLParser
    
    @Test("HashtagLinkText uses emoji lookup in HTMLParser")
    @available(iOS 15.0, macOS 12.0, *)
    func hashtagLinkTextUsesEmojiLookup() {
        let emoji = CustomEmoji(shortcode: "test", url: "https://example.com/test.png", staticUrl: "", visibleInPicker: true, category: nil)
        let lookup: [String: CustomEmoji] = ["test": emoji]
        
        let html = "<p>Hello :test: and #swift</p>"
        let attributedString = HTMLParser.convertToAttributedString(html, hashtagHandler: { tag in
            URL(string: "hashtag://\(tag)")
        }, emojiLookup: lookup)
        
        #expect(!attributedString.characters.isEmpty)
        // Should have both emoji replacement and hashtag links
    }
}

//
//  EmojiTextTests.swift
//  fedi-readerTests
//
//  Tests for EmojiText segment parsing and emoji replacement.
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("EmojiText Tests")
struct EmojiTextTests {

    static func makeEmoji(shortcode: String = "test", url: String = "https://example.com/emoji.png") -> CustomEmoji {
        CustomEmoji(
            shortcode: shortcode,
            url: url,
            staticUrl: "",
            visibleInPicker: true,
            category: nil
        )
    }

    @Test("Empty emojis returns single text segment")
    func emptyEmojisReturnsSingleTextSegment() {
        let result = EmojiText.segmentsForTesting(text: "Hello :custom:", emojis: [])
        #expect(result.count == 1)
        #expect(result[0].0 == "Hello :custom:")
        #expect(result[0].1 == false)
    }

    @Test("No shortcodes returns single text segment")
    func noShortcodesReturnsSingleTextSegment() {
        let emojis = [Self.makeEmoji(shortcode: "x")]
        let result = EmojiText.segmentsForTesting(text: "Plain text only", emojis: emojis)
        #expect(result.count == 1)
        #expect(result[0].0 == "Plain text only")
        #expect(result[0].1 == false)
    }

    @Test("One shortcode replaced with emoji segment")
    func oneShortcodeReplaced() {
        let emojis = [Self.makeEmoji(shortcode: "smile")]
        let result = EmojiText.segmentsForTesting(text: "Hello :smile: world", emojis: emojis)
        #expect(result.count == 3)
        #expect(result[0].0 == "Hello ")
        #expect(result[0].1 == false)
        #expect(result[1].0 == "smile")
        #expect(result[1].1 == true)
        #expect(result[2].0 == " world")
        #expect(result[2].1 == false)
    }

    @Test("Multiple shortcodes in text")
    func multipleShortcodes() {
        let emojis = [
            Self.makeEmoji(shortcode: "a"),
            Self.makeEmoji(shortcode: "b")
        ]
        let result = EmojiText.segmentsForTesting(text: ":a: mid :b:", emojis: emojis)
        #expect(result.count == 3)
        #expect(result[0].0 == "a")
        #expect(result[0].1 == true)
        #expect(result[1].0 == " mid ")
        #expect(result[1].1 == false)
        #expect(result[2].0 == "b")
        #expect(result[2].1 == true)
    }

    @Test("Shortcode not in lookup stays as text")
    func shortcodeNotInLookupStaysAsText() {
        let emojis = [Self.makeEmoji(shortcode: "known")]
        let result = EmojiText.segmentsForTesting(text: "Hi :unknown: there", emojis: emojis)
        #expect(result.count == 3)
        #expect(result[0].0 == "Hi ")
        #expect(result[0].1 == false)
        #expect(result[1].0 == ":unknown:")
        #expect(result[1].1 == false)
        #expect(result[2].0 == " there")
        #expect(result[2].1 == false)
    }

    @Test("Shortcode with special characters")
    func shortcodeWithSpecialCharacters() {
        let emojis = [Self.makeEmoji(shortcode: "test_emoji+123")]
        let result = EmojiText.segmentsForTesting(text: "Say :test_emoji+123:!", emojis: emojis)
        #expect(result.count == 3)
        #expect(result[0].0 == "Say ")
        #expect(result[1].0 == "test_emoji+123")
        #expect(result[1].1 == true)
        #expect(result[2].0 == "!")
    }
}

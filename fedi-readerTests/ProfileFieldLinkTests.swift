//
//  ProfileFieldLinkTests.swift
//  fedi-readerTests
//
//  Tests for profile field URL extraction used by profile link rows.
//

import Foundation
import Testing
@testable import fedi_reader

@Suite("Profile Field Link Tests")
struct ProfileFieldLinkTests {
    @Test("Uses first anchor href when present")
    func usesAnchorHref() {
        let field = Field(
            name: "Website",
            value: #"<a href="https://example.com/about">example</a>"#,
            verifiedAt: nil
        )

        #expect(field.profileDestinationURL?.absoluteString == "https://example.com/about")
    }

    @Test("Uses stripped plain-text URL when no anchor exists")
    func usesPlainTextURL() {
        let field = Field(
            name: "Blog",
            value: "   https://example.com/posts/1   ",
            verifiedAt: nil
        )

        #expect(field.profileDestinationURL?.absoluteString == "https://example.com/posts/1")
    }

    @Test("Returns nil for non-HTTP values")
    func returnsNilForNonHTTPValue() {
        let field = Field(
            name: "Handle",
            value: "@sam",
            verifiedAt: nil
        )

        #expect(field.profileDestinationURL == nil)
    }

    @Test("Returns nil for malformed URL strings")
    func returnsNilForMalformedURL() {
        let field = Field(
            name: "Broken",
            value: "https://exa mple.com",
            verifiedAt: nil
        )

        #expect(field.profileDestinationURL == nil)
    }
}

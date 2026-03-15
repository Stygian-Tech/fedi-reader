import Testing
import Foundation
@testable import fedi_reader

@Suite("Message Link Preview Resolver Tests")
struct MessageLinkPreviewResolverTests {

    @Test("Uses preview cards for link and rich cards")
    func usesPreviewCardsForEligibleCardTypes() {
        let linkStatus = MockStatusFactory.makeStatus(
            content: "<p><a href=\"https://example.com/article\">article</a></p>",
            hasCard: true,
            cardURL: "https://example.com/article"
        )
        let richStatus = MockStatusFactory.makeStatus(
            content: "<p>Watch this https://example.com/embed</p>",
            hasCard: true,
            cardURL: "https://example.com/embed",
            cardType: .rich
        )

        let linkCandidate = MessageLinkPreviewResolver.resolve(from: linkStatus)
        let richCandidate = MessageLinkPreviewResolver.resolve(from: richStatus)

        #expect(linkCandidate?.url.absoluteString == "https://example.com/article")
        #expect(linkCandidate?.card?.url == "https://example.com/article")
        #expect(richCandidate?.url.absoluteString == "https://example.com/embed")
        #expect(richCandidate?.card?.url == "https://example.com/embed")
    }

    @Test("Ignores preview cards when their URL is not in message content")
    func ignoresPreviewCardsWhenURLIsNotInMessageContent() {
        let status = MockStatusFactory.makeStatus(
            content: "<p>Read this too <a href=\"https://example.com/secondary\">secondary</a></p>",
            hasCard: true,
            cardURL: "https://example.com/primary"
        )

        let candidate = MessageLinkPreviewResolver.resolve(from: status)

        #expect(candidate?.url.absoluteString == "https://example.com/secondary")
        #expect(candidate?.card == nil)
    }

    @Test("Falls back to first external link when no preview card exists")
    func fallsBackToFirstExternalLinkWhenNoPreviewCardExists() {
        let anchorStatus = MockStatusFactory.makeStatus(
            content: """
            <p>
            <a href="https://mastodon.social/@someone">mention</a>
            <a href="https://example.com/story">story</a>
            </p>
            """
        )
        let plainTextStatus = MockStatusFactory.makeStatus(
            content: "<p>Read this next: https://example.com/plain-text-story</p>"
        )

        let anchorCandidate = MessageLinkPreviewResolver.resolve(from: anchorStatus)
        let plainTextCandidate = MessageLinkPreviewResolver.resolve(from: plainTextStatus)

        #expect(anchorCandidate?.url.absoluteString == "https://example.com/story")
        #expect(anchorCandidate?.card == nil)
        #expect(plainTextCandidate?.url.absoluteString == "https://example.com/plain-text-story")
        #expect(plainTextCandidate?.card == nil)
    }

    @Test("Returns nil when only Mastodon internal links are present")
    func returnsNilWhenOnlyMastodonInternalLinksArePresent() {
        let status = MockStatusFactory.makeStatus(
            content: """
            <p>
            <a href="https://mastodon.social/@someone">profile</a>
            <a href="https://mastodon.social/tags/swift">tag</a>
            </p>
            """
        )

        let candidate = MessageLinkPreviewResolver.resolve(from: status)

        #expect(candidate == nil)
    }

    @Test("Returns nil when no inline external link is present")
    func returnsNilWhenNoInlineExternalLinkIsPresent() {
        let status = MockStatusFactory.makeStatus(
            content: "<p>Just reacting here</p>",
            hasCard: true,
            cardURL: "https://tenor.example/gif",
            cardType: .rich
        )

        let candidate = MessageLinkPreviewResolver.resolve(from: status)

        #expect(candidate == nil)
    }
}

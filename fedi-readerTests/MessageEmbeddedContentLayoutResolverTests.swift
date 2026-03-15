import Foundation
import Testing
@testable import fedi_reader

@Suite("Message Embedded Content Layout Resolver Tests")
struct MessageEmbeddedContentLayoutResolverTests {
    @Test("Keeps text before an embedded link when the link is at the end")
    func keepsLeadingTextWhenLinkEndsMessage() {
        let status = MockStatusFactory.makeStatus(
            content: "<p>Read this <a href=\"https://example.com/story\">https://example.com/story</a></p>",
            hasCard: true,
            cardURL: "https://example.com/story"
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(from: status, hiddenHandles: [])

        #expect(layout.candidate?.url.absoluteString == "https://example.com/story")
        #expect(layout.leadingContent?.htmlToPlainText == "Read this")
        #expect(layout.trailingContent == nil)
    }

    @Test("Keeps text after an embedded link when the link starts the message")
    func keepsTrailingTextWhenLinkStartsMessage() {
        let status = MockStatusFactory.makeStatus(
            content: "<p><a href=\"https://example.com/story\">https://example.com/story</a> worth your time</p>",
            hasCard: true,
            cardURL: "https://example.com/story"
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(from: status, hiddenHandles: [])

        #expect(layout.candidate?.url.absoluteString == "https://example.com/story")
        #expect(layout.leadingContent == nil)
        #expect(layout.trailingContent?.htmlToPlainText == "worth your time")
    }

    @Test("Splits message text around an embedded link in the middle")
    func splitsTextAroundEmbeddedLink() {
        let status = MockStatusFactory.makeStatus(
            content: """
            <p>Before <a href="https://example.com/story">the story</a> after</p>
            """,
            hasCard: true,
            cardURL: "https://example.com/story"
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(from: status, hiddenHandles: [])

        #expect(layout.leadingContent?.htmlToPlainText == "Before")
        #expect(layout.trailingContent?.htmlToPlainText == "after")
    }

    @Test("Drops hidden direct-message mentions before the embedded link")
    func dropsHiddenMentionsBeforeEmbeddedLink() {
        let status = MockStatusFactory.makeStatus(
            content: """
            <p>@alice <a href="https://example.com/story">the story</a> hello there</p>
            """,
            hasCard: true,
            cardURL: "https://example.com/story"
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(
            from: status,
            hiddenHandles: ["alice"]
        )

        #expect(layout.leadingContent == nil)
        #expect(layout.trailingContent?.htmlToPlainText == "hello there")
    }

    @Test("Falls back to plain-text links when no anchor tag exists")
    func fallsBackToPlainTextLinkSplitting() {
        let status = MockStatusFactory.makeStatus(
            content: "<p>Take a look https://example.com/plain next</p>"
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(from: status, hiddenHandles: [])

        #expect(layout.candidate?.url.absoluteString == "https://example.com/plain")
        #expect(layout.leadingContent == "Take a look")
        #expect(layout.trailingContent == "next")
    }

    @Test("Ignores unrelated rich cards that are not inline links")
    func ignoresUnrelatedRichCards() {
        let status = MockStatusFactory.makeStatus(
            content: "<p>Just reacting here</p>",
            hasCard: true,
            cardURL: "https://tenor.example/gif",
            cardType: .rich
        )

        let layout = MessageEmbeddedContentLayoutResolver.resolve(from: status, hiddenHandles: [])

        #expect(layout.candidate == nil)
        #expect(layout.leadingContent == nil)
        #expect(layout.trailingContent == nil)
    }
}

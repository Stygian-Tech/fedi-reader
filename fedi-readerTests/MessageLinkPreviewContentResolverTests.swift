import Testing
import Foundation
@testable import fedi_reader

@Suite("Message Link Preview Content Resolver Tests")
struct MessageLinkPreviewContentResolverTests {

    @Test("Fetches preview metadata when the card title is only the domain")
    func fetchesPreviewMetadataWhenCardTitleIsOnlyTheDomain() {
        let card = PreviewCard(
            url: "https://blog.sam-clemente.me/post",
            title: "blog.sam-clemente.me",
            description: "",
            type: .link,
            authorName: nil,
            authorUrl: nil,
            providerName: "blog.sam-clemente.me",
            providerUrl: nil,
            html: nil,
            width: nil,
            height: nil,
            image: nil,
            blurhash: nil,
            embedUrl: nil
        )
        let candidate = MessageLinkPreviewCandidate(
            url: URL(string: card.url)!,
            card: card
        )

        #expect(MessageLinkPreviewContentResolver.shouldFetchPreview(for: candidate))
    }

    @Test("Uses fetched preview metadata to fill sparse card content")
    func usesFetchedPreviewMetadataToFillSparseCardContent() {
        let card = PreviewCard(
            url: "https://blog.sam-clemente.me/post",
            title: "blog.sam-clemente.me",
            description: "",
            type: .link,
            authorName: nil,
            authorUrl: nil,
            providerName: "blog.sam-clemente.me",
            providerUrl: nil,
            html: nil,
            width: nil,
            height: nil,
            image: nil,
            blurhash: nil,
            embedUrl: nil
        )
        let candidate = MessageLinkPreviewCandidate(
            url: URL(string: card.url)!,
            card: card
        )
        let preview = LinkPreviewService.LinkPreview(
            url: URL(string: "https://blog.sam-clemente.me/post")!,
            finalURL: URL(string: "https://blog.sam-clemente.me/post")!,
            title: "A Better Title",
            description: "Recovered description",
            imageURL: URL(string: "https://blog.sam-clemente.me/feature.jpg"),
            siteName: "Sam Clemente Blog",
            provider: "blog.sam-clemente.me",
            fediverseCreator: "@sam@mastodon.social",
            fediverseCreatorURL: URL(string: "https://mastodon.social/@sam")
        )

        let content = MessageLinkPreviewContentResolver.resolve(
            candidate: candidate,
            linkPreview: preview,
            authorAttribution: nil,
            authorDisplayName: nil
        )

        #expect(content.title == "A Better Title")
        #expect(content.description == "Recovered description")
        #expect(content.imageURL?.absoluteString == "https://blog.sam-clemente.me/feature.jpg")
        #expect(content.providerDisplay == "blog.sam-clemente.me")
        #expect(content.authorName == "@sam@mastodon.social")
        #expect(content.authorURL?.absoluteString == "https://mastodon.social/@sam")
    }

    @Test("Prefers fetched preview image when both card and source metadata provide images")
    func prefersFetchedPreviewImageWhenAvailable() {
        let card = PreviewCard(
            url: "https://blog.sam-clemente.me/post",
            title: "A Better Title",
            description: "Recovered description",
            type: .link,
            authorName: nil,
            authorUrl: nil,
            providerName: "blog.sam-clemente.me",
            providerUrl: nil,
            html: nil,
            width: nil,
            height: nil,
            image: "https://blog.sam-clemente.me/card-image.jpg",
            blurhash: nil,
            embedUrl: nil
        )
        let candidate = MessageLinkPreviewCandidate(
            url: URL(string: card.url)!,
            card: card
        )
        let preview = LinkPreviewService.LinkPreview(
            url: URL(string: "https://blog.sam-clemente.me/post")!,
            finalURL: URL(string: "https://blog.sam-clemente.me/post")!,
            title: "A Better Title",
            description: "Recovered description",
            imageURL: URL(string: "https://blog.sam-clemente.me/feature.jpg"),
            siteName: "Sam Clemente Blog",
            provider: "blog.sam-clemente.me",
            fediverseCreator: nil,
            fediverseCreatorURL: nil
        )

        let content = MessageLinkPreviewContentResolver.resolve(
            candidate: candidate,
            linkPreview: preview,
            authorAttribution: nil,
            authorDisplayName: nil
        )

        #expect(content.imageURL?.absoluteString == "https://blog.sam-clemente.me/feature.jpg")
    }
}

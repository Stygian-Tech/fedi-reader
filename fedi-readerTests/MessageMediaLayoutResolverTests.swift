import Testing
import Foundation
@testable import fedi_reader

@Suite("Message Media Layout Resolver Tests")
struct MessageMediaLayoutResolverTests {

    @Test("Defaults to a square layout when metadata is missing")
    func defaultsToSquareLayoutWhenMetadataIsMissing() {
        let attachment = MediaAttachment(
            id: "attachment-1",
            type: .image,
            url: "https://example.com/image.jpg",
            previewUrl: "https://example.com/preview.jpg",
            remoteUrl: nil,
            description: nil,
            blurhash: nil,
            meta: nil
        )

        let size = MessageMediaLayoutResolver.size(for: attachment)

        #expect(size.width == 260)
        #expect(size.height == 240)
    }

    @Test("Clamps very wide media to a readable chat height")
    func clampsVeryWideMediaToReadableChatHeight() {
        let attachment = MediaAttachment(
            id: "attachment-2",
            type: .gifv,
            url: "https://example.com/clip.mp4",
            previewUrl: "https://example.com/clip.jpg",
            remoteUrl: nil,
            description: nil,
            blurhash: nil,
            meta: MediaMeta(
                original: MediaDimensions(width: 1600, height: 300, size: nil, aspect: 5.3333),
                small: nil,
                focus: nil
            )
        )

        let size = MessageMediaLayoutResolver.size(for: attachment)

        #expect(size.width == 260)
        #expect(abs(size.height - 144.44444) < 0.01)
    }

    @Test("Keeps tall media from collapsing too narrow")
    func keepsTallMediaFromCollapsingTooNarrow() {
        let attachment = MediaAttachment(
            id: "attachment-3",
            type: .image,
            url: "https://example.com/tall.jpg",
            previewUrl: "https://example.com/tall-preview.jpg",
            remoteUrl: nil,
            description: nil,
            blurhash: nil,
            meta: MediaMeta(
                original: MediaDimensions(width: 300, height: 1200, size: nil, aspect: 0.25),
                small: nil,
                focus: nil
            )
        )

        let size = MessageMediaLayoutResolver.size(for: attachment)

        #expect(abs(size.width - 156) < 0.01)
        #expect(size.height == 240)
    }
}

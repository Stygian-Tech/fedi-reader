import Testing
@testable import fedi_reader

@Suite("Media Attachment Playback Policy Tests")
struct MediaAttachmentPlaybackPolicyTests {
    @Test("Images always use a static preview")
    func imagesAlwaysUseStaticPreview() {
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .image, autoPlayGifs: false) == .staticPreview
        )
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .image, autoPlayGifs: true) == .staticPreview
        )
    }

    @Test("GIFV autoplay follows the existing setting")
    func gifvAutoplayDependsOnSetting() {
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .gifv, autoPlayGifs: false) == .staticPreview
        )
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .gifv, autoPlayGifs: true) == .inlineLoopingGifv
        )
    }

    @Test("Videos always require explicit playback")
    func videosAlwaysRequireExplicitPlayback() {
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .video, autoPlayGifs: false) == .explicitVideoPlayback
        )
        #expect(
            MediaAttachmentPlaybackPolicy.resolve(for: .video, autoPlayGifs: true) == .explicitVideoPlayback
        )
    }
}

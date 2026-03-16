import Foundation

enum MediaAttachmentPlaybackPolicy: Sendable, Equatable {
    case staticPreview
    case inlineLoopingGifv
    case explicitVideoPlayback

    static func resolve(for type: MediaType, autoPlayGifs: Bool) -> MediaAttachmentPlaybackPolicy {
        switch type {
        case .gifv:
            autoPlayGifs ? .inlineLoopingGifv : .staticPreview
        case .video:
            .explicitVideoPlayback
        default:
            .staticPreview
        }
    }
}

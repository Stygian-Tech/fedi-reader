import AVFoundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MediaAttachmentThumbnailView: View {
    let attachment: MediaAttachment
    let size: CGSize
    let cornerRadius: CGFloat
    let autoPlayGifs: Bool

    private var playbackPolicy: MediaAttachmentPlaybackPolicy {
        MediaAttachmentPlaybackPolicy.resolve(for: attachment.type, autoPlayGifs: autoPlayGifs)
    }

    private var previewURL: URL? {
        URL(string: attachment.previewUrl ?? attachment.url)
    }

    private var mediaURL: URL? {
        URL(string: attachment.url)
    }

    var body: some View {
        ZStack {
            AsyncImage(url: previewURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
            }

            if playbackPolicy == .inlineLoopingGifv, let mediaURL {
                InlineLoopingVideoView(url: mediaURL)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(alignment: .bottomTrailing) {
            if attachment.type == .video || attachment.type == .gifv {
                Image(systemName: attachment.type == .gifv ? "play.circle" : "play.circle.fill")
                    .font(.roundedCaption)
                    .padding(4)
                    .glassEffect(.clear, in: Circle())
                    .padding(6)
            }
        }
    }
}

struct InlineLoopingVideoView: View {
    let url: URL
    @State private var playerController: LoopingVideoPlayerController?

    var body: some View {
        LoopingVideoLayerView(player: playerController?.player)
            .onAppear {
                guard playerController == nil else {
                    playerController?.play()
                    return
                }

                let controller = LoopingVideoPlayerController(url: url)
                playerController = controller
                controller.play()
            }
            .onDisappear {
                playerController?.stop()
                playerController = nil
            }
    }
}

private final class LoopingVideoPlayerController {
    let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    init(url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.volume = 0
        player.actionAtItemEnd = .none
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = true

        self.player = player
        self.looper = AVPlayerLooper(player: player, templateItem: item)
    }

    func play() {
        player.playImmediately(atRate: 1)
    }

    func stop() {
        player.pause()
        player.removeAllItems()
    }

    deinit {
        stop()
    }
}

#if os(iOS)
private final class LoopingVideoPlayerUIView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private struct LoopingVideoLayerView: UIViewRepresentable {
    typealias UIViewType = LoopingVideoPlayerUIView

    let player: AVPlayer?

    func makeUIView(
        context: UIViewRepresentableContext<LoopingVideoLayerView>
    ) -> LoopingVideoPlayerUIView {
        LoopingVideoPlayerUIView()
    }

    func updateUIView(
        _ uiView: LoopingVideoPlayerUIView,
        context: UIViewRepresentableContext<LoopingVideoLayerView>
    ) {
        uiView.playerLayer.player = player
    }
}
#elseif os(macOS)
private final class LoopingVideoPlayerNSView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = playerLayer
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@MainActor
private struct LoopingVideoLayerView: NSViewRepresentable {
    typealias NSViewType = LoopingVideoPlayerNSView

    let player: AVPlayer?

    func makeNSView(
        context: NSViewRepresentableContext<LoopingVideoLayerView>
    ) -> LoopingVideoPlayerNSView {
        LoopingVideoPlayerNSView()
    }

    func updateNSView(
        _ nsView: LoopingVideoPlayerNSView,
        context: NSViewRepresentableContext<LoopingVideoLayerView>
    ) {
        nsView.playerLayer.player = player
    }
}
#endif

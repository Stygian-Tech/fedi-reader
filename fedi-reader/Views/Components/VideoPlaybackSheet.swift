import AVKit
import SwiftUI

struct VideoPlaybackSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var player = AVPlayer()
    @State private var timeControlObservation: NSKeyValueObservation?
    @State private var playbackEndObserver: NSObjectProtocol?
    @State private var audioSessionCoordinator = VideoPlaybackAudioSessionCoordinator()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            VideoPlayer(player: player)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white, .black.opacity(0.3))
                    .padding()
            }
            .buttonStyle(.plain)
        }
        .task(id: url) {
            configurePlayer()
        }
        .onDisappear {
            tearDownPlayer()
        }
    }

    private func configurePlayer() {
        tearDownPlayer()

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { observedPlayer, _ in
            Task { @MainActor in
                audioSessionCoordinator.updatePlaybackState(
                    isPlaying: observedPlayer.timeControlStatus == .playing
                )
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            Task { @MainActor in
                audioSessionCoordinator.updatePlaybackState(isPlaying: false)
            }
        }

        player.play()
    }

    private func tearDownPlayer() {
        timeControlObservation = nil

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }

        player.pause()
        player.replaceCurrentItem(with: nil)
        audioSessionCoordinator.endPlayback()
    }
}

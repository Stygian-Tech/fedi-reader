import Foundation
import os

#if os(iOS)
import AVFAudio

protocol VideoPlaybackAudioSessionControlling: AnyObject {
    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

final class SystemVideoPlaybackAudioSession: VideoPlaybackAudioSessionControlling {
    private let session: AVAudioSession

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try session.setCategory(category, mode: mode, options: options)
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        try session.setActive(active, options: options)
    }
}

@MainActor
final class VideoPlaybackAudioSessionCoordinator {
    private static let logger = Logger(
        subsystem: "app.fedi-reader",
        category: "VideoPlaybackAudioSession"
    )

    private let session: VideoPlaybackAudioSessionControlling
    private(set) var isSessionActive = false

    init() {
        self.session = SystemVideoPlaybackAudioSession()
    }

    init(session: VideoPlaybackAudioSessionControlling) {
        self.session = session
    }

    func updatePlaybackState(isPlaying: Bool) {
        if isPlaying {
            activateIfNeeded()
        } else {
            deactivateIfNeeded()
        }
    }

    func endPlayback() {
        deactivateIfNeeded()
    }

    private func activateIfNeeded() {
        guard !isSessionActive else { return }

        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true, options: [])
            isSessionActive = true
        } catch {
            Self.logger.error("Failed to activate audio session: \(error.localizedDescription)")
        }
    }

    private func deactivateIfNeeded() {
        guard isSessionActive else { return }

        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            Self.logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }

        isSessionActive = false
    }
}
#else
@MainActor
final class VideoPlaybackAudioSessionCoordinator {
    private(set) var isSessionActive = false

    func updatePlaybackState(isPlaying: Bool) {
        isSessionActive = isPlaying
    }

    func endPlayback() {
        isSessionActive = false
    }
}
#endif

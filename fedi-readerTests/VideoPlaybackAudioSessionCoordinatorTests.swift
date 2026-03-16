#if os(iOS)
import AVFAudio
import Foundation
import Testing
@testable import fedi_reader

@Suite("Video Playback Audio Session Coordinator Tests")
@MainActor
struct VideoPlaybackAudioSessionCoordinatorTests {
    @Test("Activates playback session only while video is playing")
    func activatesPlaybackSessionWhilePlaying() {
        let session = MockVideoPlaybackAudioSession()
        let coordinator = VideoPlaybackAudioSessionCoordinator(session: session)

        coordinator.updatePlaybackState(isPlaying: true)

        #expect(session.categoryCalls.count == 1)
        #expect(session.activeCalls.count == 1)
        #expect(session.activeCalls[0].0)
        #expect(session.activeCalls[0].1.isEmpty)
        #expect(coordinator.isSessionActive)
    }

    @Test("Does not reactivate an already active session")
    func doesNotReactivateActiveSession() {
        let session = MockVideoPlaybackAudioSession()
        let coordinator = VideoPlaybackAudioSessionCoordinator(session: session)

        coordinator.updatePlaybackState(isPlaying: true)
        coordinator.updatePlaybackState(isPlaying: true)

        #expect(session.categoryCalls.count == 1)
        #expect(session.activeCalls.count == 1)
        #expect(session.activeCalls[0].0)
        #expect(session.activeCalls[0].1.isEmpty)
    }

    @Test("Deactivates session and notifies other audio on stop")
    func deactivatesSessionWhenPlaybackStops() {
        let session = MockVideoPlaybackAudioSession()
        let coordinator = VideoPlaybackAudioSessionCoordinator(session: session)

        coordinator.updatePlaybackState(isPlaying: true)
        coordinator.updatePlaybackState(isPlaying: false)

        #expect(session.activeCalls.count == 2)
        #expect(session.activeCalls[1].0 == false)
        #expect(session.activeCalls[1].1 == [.notifyOthersOnDeactivation])
        #expect(!coordinator.isSessionActive)
    }

    @Test("End playback is safe when no session is active")
    func endPlaybackIsSafeWithoutActiveSession() {
        let session = MockVideoPlaybackAudioSession()
        let coordinator = VideoPlaybackAudioSessionCoordinator(session: session)

        coordinator.endPlayback()

        #expect(session.activeCalls.isEmpty)
        #expect(!coordinator.isSessionActive)
    }
}

private final class MockVideoPlaybackAudioSession: VideoPlaybackAudioSessionControlling {
    var categoryCalls: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = []
    var activeCalls: [(Bool, AVAudioSession.SetActiveOptions)] = []

    func setCategory(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        categoryCalls.append((category, mode, options))
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        activeCalls.append((active, options))
    }
}
#endif

import Foundation
import Testing
@testable import fedi_reader

@Suite("Selection Double Tap Tracker Tests")
@MainActor
struct SelectionDoubleTapTrackerTests {
    @Test("Same selection inside the double tap window is detected")
    func sameSelectionInsideWindowIsDetected() async {
        var now = Date(timeIntervalSince1970: 0)
        let tracker = SelectionDoubleTapTracker<String>(
            doubleTapWindow: 0.4,
            now: { now }
        )

        #expect(tracker.recordSelection("home") == false)

        now = now.addingTimeInterval(0.2)

        #expect(tracker.recordSelection("home") == true)
    }

    @Test("Different selections do not count as a double tap")
    func differentSelectionsDoNotCountAsDoubleTap() async {
        var now = Date(timeIntervalSince1970: 0)
        let tracker = SelectionDoubleTapTracker<String>(
            doubleTapWindow: 0.4,
            now: { now }
        )

        #expect(tracker.recordSelection("home") == false)

        now = now.addingTimeInterval(0.2)

        #expect(tracker.recordSelection("list-1") == false)
    }

    @Test("Detection resets after a double tap fires")
    func detectionResetsAfterDoubleTapFires() async {
        var now = Date(timeIntervalSince1970: 0)
        let tracker = SelectionDoubleTapTracker<String>(
            doubleTapWindow: 0.4,
            now: { now }
        )

        #expect(tracker.recordSelection("home") == false)

        now = now.addingTimeInterval(0.2)
        #expect(tracker.recordSelection("home") == true)

        now = now.addingTimeInterval(0.1)
        #expect(tracker.recordSelection("home") == false)
    }

    @Test("Reset clears a pending first tap")
    func resetClearsPendingFirstTap() async {
        var now = Date(timeIntervalSince1970: 0)
        let tracker = SelectionDoubleTapTracker<String>(
            doubleTapWindow: 0.4,
            now: { now }
        )

        #expect(tracker.recordSelection("home") == false)

        tracker.reset()
        now = now.addingTimeInterval(0.2)

        #expect(tracker.recordSelection("home") == false)
    }
}

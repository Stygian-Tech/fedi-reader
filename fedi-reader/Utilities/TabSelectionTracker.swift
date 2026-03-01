//
//  TabSelectionTracker.swift
//  fedi-reader
//
//  Tracks tab selection timing for double-tap detection
//

import Foundation

@MainActor
final class SelectionDoubleTapTracker<Selection: Equatable> {
    private var lastSelectionTime: Date?
    private var lastSelection: Selection?
    private let doubleTapWindow: TimeInterval
    private let now: () -> Date

    init(
        doubleTapWindow: TimeInterval = 0.4,
        now: @escaping () -> Date = Date.init
    ) {
        self.doubleTapWindow = doubleTapWindow
        self.now = now
    }

    func recordSelection(_ selection: Selection) -> Bool {
        let now = now()
        let isDoubleTap: Bool

        if let lastTime = lastSelectionTime,
           let lastSelection,
           lastSelection == selection,
           now.timeIntervalSince(lastTime) < doubleTapWindow {
            isDoubleTap = true
            lastSelectionTime = nil
            self.lastSelection = nil
        } else {
            isDoubleTap = false
            lastSelectionTime = now
            lastSelection = selection
        }

        return isDoubleTap
    }

    func reset() {
        lastSelectionTime = nil
        lastSelection = nil
    }
}

typealias TabSelectionTracker = SelectionDoubleTapTracker<AppTab>

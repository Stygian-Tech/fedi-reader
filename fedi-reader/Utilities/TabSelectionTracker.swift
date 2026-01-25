//
//  TabSelectionTracker.swift
//  fedi-reader
//
//  Tracks tab selection timing for double-tap detection
//

import Foundation

@Observable
@MainActor
final class TabSelectionTracker {
    private var lastSelectionTime: Date?
    private var lastSelectedTab: AppTab?
    private let doubleTapWindow: TimeInterval = 0.4 // Native iOS double-tap timing
    
    func recordSelection(_ tab: AppTab) -> Bool {
        let now = Date()
        let isDoubleTap: Bool
        
        if let lastTime = lastSelectionTime,
           let lastTab = lastSelectedTab,
           lastTab == tab,
           now.timeIntervalSince(lastTime) < doubleTapWindow {
            // Double-tap detected
            isDoubleTap = true
            // Reset to prevent triple-tap from triggering again
            lastSelectionTime = nil
            lastSelectedTab = nil
        } else {
            // First tap or different tab
            isDoubleTap = false
            lastSelectionTime = now
            lastSelectedTab = tab
        }
        
        return isDoubleTap
    }
    
    func reset() {
        lastSelectionTime = nil
        lastSelectedTab = nil
    }
}

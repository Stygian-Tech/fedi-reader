import SwiftUI

enum ToggleActionCount {
    static func optimistic(currentCount: Int, wasActive: Bool) -> Int {
        max(0, currentCount + (wasActive ? -1 : 1))
    }

    static func reconciled(
        originalCount: Int,
        wasActive: Bool,
        serverCount: Int,
        serverIsActive: Bool?
    ) -> Int {
        let normalizedServerCount = max(0, serverCount)
        let expectedActiveState = !wasActive

        guard serverIsActive == expectedActiveState else {
            return normalizedServerCount
        }

        if wasActive {
            // Some instances return stale counts after an un-toggle. Keep the expected local count in that case.
            return normalizedServerCount >= originalCount
                ? optimistic(currentCount: originalCount, wasActive: wasActive)
                : normalizedServerCount
        } else {
            return normalizedServerCount <= originalCount
                ? optimistic(currentCount: originalCount, wasActive: wasActive)
                : normalizedServerCount
        }
    }
}



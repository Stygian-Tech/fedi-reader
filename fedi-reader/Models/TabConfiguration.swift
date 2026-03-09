import Foundation

struct TabConfiguration: Codable, Equatable, Sendable {
    var visibleTabs: [AppTab]
    var hiddenTabs: [AppTab]

    private static let permanentlyVisibleTabs: [AppTab] = [.links, .profile]
    private static let compactTabsBeforeMore = 4
    private static let compactVisibleTabLimitBeforeMore = 5

    static let defaultConfiguration = TabConfiguration(
        visibleTabs: [.links, .explore, .mentions, .profile],
        hiddenTabs: [.lists, .hashtags, .bookmarks]
    )

    func normalized(allTabs: [AppTab] = AppTab.allCases) -> TabConfiguration {
        let availableTabs = Set(allTabs)

        var normalizedVisibleTabs = Self.orderedUniqueTabs(
            visibleTabs.filter { availableTabs.contains($0) }
        )
        var normalizedHiddenTabs = Self.orderedUniqueTabs(
            hiddenTabs.filter { availableTabs.contains($0) }
        )

        for protectedTab in Self.permanentlyVisibleTabs {
            normalizedHiddenTabs.removeAll { $0 == protectedTab }
            if !normalizedVisibleTabs.contains(protectedTab) {
                normalizedVisibleTabs.append(protectedTab)
            }
        }

        let usedTabs = Set(normalizedVisibleTabs).union(normalizedHiddenTabs)
        let missingTabs = allTabs.filter { !usedTabs.contains($0) }
        normalizedHiddenTabs.append(contentsOf: missingTabs)

        normalizedVisibleTabs = Self.ensureProtectedTabsNotBehindMore(normalizedVisibleTabs)

        return TabConfiguration(
            visibleTabs: normalizedVisibleTabs,
            hiddenTabs: normalizedHiddenTabs
        )
    }

    private static func orderedUniqueTabs(_ tabs: [AppTab]) -> [AppTab] {
        var seenTabs = Set<AppTab>()
        return tabs.filter { seenTabs.insert($0).inserted }
    }

    /// Ensures Home and Profile are in the first 4 tabs (not behind More). Preserves user order otherwise.
    private static func ensureProtectedTabsNotBehindMore(_ tabs: [AppTab]) -> [AppTab] {
        guard tabs.count > compactVisibleTabLimitBeforeMore else { return tabs }

        let protectedTabs = Set(permanentlyVisibleTabs)
        let primaryIndices = Array(0..<compactTabsBeforeMore)
        let overflowIndices = Array(compactTabsBeforeMore..<tabs.count)

        let protectedInOverflow = overflowIndices.filter { protectedTabs.contains(tabs[$0]) }
        let unprotectedInPrimary = primaryIndices.filter { !protectedTabs.contains(tabs[$0]) }
        let primaryToSwap = Array(unprotectedInPrimary.suffix(protectedInOverflow.count).reversed())

        guard !protectedInOverflow.isEmpty, protectedInOverflow.count <= primaryToSwap.count else { return tabs }

        var result = tabs
        let pairs = zip(protectedInOverflow, primaryToSwap).sorted { $0.0 > $1.0 }
        for (overflowIdx, primaryIdx) in pairs {
            result.swapAt(overflowIdx, primaryIdx)
        }
        return result
    }
}

import Foundation

enum ListDisplaySortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case alphabetical
    case reverseAlphabetical
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical:
            return "Alphabetical"
        case .reverseAlphabetical:
            return "Reverse Alphabetical"
        case .custom:
            return "Custom"
        }
    }
}

struct AccountListDisplayPreferences: Codable, Equatable, Sendable {
    var sortOrder: ListDisplaySortOrder = .alphabetical
    var hiddenListIDs: [String] = []
    var customVisibleListOrder: [String] = []
}

struct AccountListDisplayResolution: Equatable, Sendable {
    let visibleLists: [MastodonList]
    let hiddenLists: [MastodonList]
    let normalizedPreferences: AccountListDisplayPreferences

    var visibleListIDs: [String] {
        visibleLists.map(\.id)
    }
}

enum AccountListDisplayResolver {
    nonisolated static func resolve(
        lists: [MastodonList],
        preferences: AccountListDisplayPreferences
    ) -> AccountListDisplayResolution {
        let existingListIDs = Set(lists.map(\.id))
        let hiddenListIDs = orderedUniqueIDs(
            preferences.hiddenListIDs.filter { existingListIDs.contains($0) }
        )
        let hiddenListIDSet = Set(hiddenListIDs)

        let visibleSourceLists = lists.filter { !hiddenListIDSet.contains($0.id) }
        let hiddenSourceLists = lists.filter { hiddenListIDSet.contains($0.id) }

        let normalizedCustomVisibleListOrder = normalizedCustomOrder(
            for: visibleSourceLists,
            preferences: preferences,
            hiddenListIDSet: hiddenListIDSet,
            existingListIDs: existingListIDs
        )

        let visibleLists: [MastodonList]
        let hiddenLists: [MastodonList]
        switch preferences.sortOrder {
        case .alphabetical:
            visibleLists = visibleSourceLists.sorted(by: ascendingTitleComparator)
            hiddenLists = hiddenSourceLists.sorted(by: ascendingTitleComparator)
        case .reverseAlphabetical:
            visibleLists = visibleSourceLists.sorted(by: descendingTitleComparator)
            hiddenLists = hiddenSourceLists.sorted(by: descendingTitleComparator)
        case .custom:
            let listsByID = Dictionary(uniqueKeysWithValues: visibleSourceLists.map { ($0.id, $0) })
            let orderedIDs = Set(normalizedCustomVisibleListOrder)
            let orderedVisibleLists = normalizedCustomVisibleListOrder.compactMap { listsByID[$0] }
            let unorderedVisibleLists = visibleSourceLists.filter { !orderedIDs.contains($0.id) }
            visibleLists = orderedVisibleLists + unorderedVisibleLists
            hiddenLists = hiddenSourceLists.sorted(by: ascendingTitleComparator)
        }

        return AccountListDisplayResolution(
            visibleLists: visibleLists,
            hiddenLists: hiddenLists,
            normalizedPreferences: AccountListDisplayPreferences(
                sortOrder: preferences.sortOrder,
                hiddenListIDs: hiddenListIDs,
                customVisibleListOrder: normalizedCustomVisibleListOrder
            )
        )
    }

    private nonisolated static func normalizedCustomOrder(
        for visibleLists: [MastodonList],
        preferences: AccountListDisplayPreferences,
        hiddenListIDSet: Set<String>,
        existingListIDs: Set<String>
    ) -> [String] {
        let filteredSavedOrder = orderedUniqueIDs(
            preferences.customVisibleListOrder.filter {
                existingListIDs.contains($0) && !hiddenListIDSet.contains($0)
            }
        )
        let savedOrderSet = Set(filteredSavedOrder)
        let appendedVisibleIDs = visibleLists
            .map(\.id)
            .filter { !savedOrderSet.contains($0) }
        return filteredSavedOrder + appendedVisibleIDs
    }

    private nonisolated static func orderedUniqueIDs(_ ids: [String]) -> [String] {
        var seenIDs = Set<String>()
        return ids.filter { seenIDs.insert($0).inserted }
    }

    private nonisolated static func ascendingTitleComparator(_ lhs: MastodonList, _ rhs: MastodonList) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private nonisolated static func descendingTitleComparator(_ lhs: MastodonList, _ rhs: MastodonList) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
    }
}

//
//  AppStateTests.swift
//  fedi-readerTests
//
//  Unit tests for AppState (user filter per feed, etc.)
//

import Testing
import Foundation
@testable import fedi_reader

private struct GenericTestError: LocalizedError {
    var errorDescription: String? {
        "Something went wrong"
    }
}

private func makeList(id: String, title: String) -> MastodonList {
    MastodonList(id: id, title: title, repliesPolicy: nil, exclusive: nil)
}

@MainActor
private func withPreservedTabConfiguration(_ operation: () async -> Void) async {
    let defaults = UserDefaults.standard
    let tabConfigurationKey = "tabConfiguration"
    let legacyListsKey = AppState.listsInSeparateTabStorageKey
    let previousConfiguration = defaults.data(forKey: tabConfigurationKey)
    let previousLegacyListsValue = defaults.object(forKey: legacyListsKey)
    defer {
        if let previousConfiguration {
            defaults.set(previousConfiguration, forKey: tabConfigurationKey)
        } else {
            defaults.removeObject(forKey: tabConfigurationKey)
        }

        if let previousLegacyListsValue {
            defaults.set(previousLegacyListsValue, forKey: legacyListsKey)
        } else {
            defaults.removeObject(forKey: legacyListsKey)
        }
    }

    await operation()
}

private func withIsolatedUserDefaults(
    _ operation: (UserDefaults) async -> Void
) async {
    let suiteName = "AppStateTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Failed to create isolated UserDefaults suite")
        return
    }

    defaults.removePersistentDomain(forName: suiteName)
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    await operation(defaults)
}

private func makeAccount(
    id: String = "test.example:account-1",
    instance: String = "test.example",
    username: String = "tester"
) -> Account {
    Account(
        id: id,
        instance: instance,
        username: username,
        displayName: "Test User",
        acct: "\(username)@\(instance)",
        isActive: true
    )
}

@Suite("AppState Tests")
@MainActor
struct AppStateTests {

    @Test("userFilterPerFeedId is initially empty")
    func userFilterPerFeedIdInitiallyEmpty() async {
        let state = AppState()
        #expect(state.userFilterPerFeedId.isEmpty == true)
    }

    @Test("userFilterPerFeedId stores and retrieves filter per feed")
    func userFilterPerFeedIdStoresAndRetrievesPerFeed() async {
        let state = AppState()
        state.userFilterPerFeedId["home"] = "account-1"
        state.userFilterPerFeedId["list-abc"] = "account-2"

        #expect(state.userFilterPerFeedId["home"] == "account-1")
        #expect(state.userFilterPerFeedId["list-abc"] == "account-2")
    }

    @Test("userFilterPerFeedId isolates filters per feed")
    func userFilterPerFeedIdIsolatesPerFeed() async {
        let state = AppState()
        state.userFilterPerFeedId["home"] = "account-home"
        state.userFilterPerFeedId["list-x"] = "account-x"

        state.userFilterPerFeedId.removeValue(forKey: "home")

        #expect(state.userFilterPerFeedId["home"] == nil)
        #expect(state.userFilterPerFeedId["list-x"] == "account-x")
    }

    @Test("userFilterPerFeedId clear for feed leaves others unchanged")
    func userFilterPerFeedIdClearLeavesOthersUnchanged() async {
        let state = AppState()
        state.userFilterPerFeedId["home"] = "a1"
        state.userFilterPerFeedId["list-1"] = "a2"
        state.userFilterPerFeedId["list-2"] = "a3"

        state.userFilterPerFeedId.removeValue(forKey: "list-1")

        #expect(state.userFilterPerFeedId["home"] == "a1")
        #expect(state.userFilterPerFeedId["list-1"] == nil)
        #expect(state.userFilterPerFeedId["list-2"] == "a3")
    }
    
    @Test("handleError shows alert for non-FediReaderError values")
    func handleErrorShowsGenericAlert() async {
        let state = AppState()
        
        state.handleError(GenericTestError())
        
        #expect(state.presentedAlert?.title == "Error")
        #expect(state.presentedAlert?.message == "Something went wrong")
    }

    @Test("requestLinksScrollToTop increments the request id")
    func requestLinksScrollToTopIncrementsRequestId() async {
        let state = AppState()
        let initialRequestID = state.linksScrollToTopRequestID

        state.requestLinksScrollToTop()

        #expect(state.linksScrollToTopRequestID == initialRequestID + 1)
    }

    @Test("navigate routes explore destinations to the explore navigation path")
    func navigateRoutesExploreDestinationsToExplorePath() async {
        let state = AppState()
        let destination = NavigationDestination.article(
            url: URL(string: "https://example.com")!,
            status: nil
        )

        state.selectedTab = .explore
        state.navigate(to: destination)

        #expect(state.exploreNavigationPath == [destination])
        #expect(state.linksNavigationPath.isEmpty == true)
        #expect(state.profileNavigationPath.isEmpty == true)
    }

    @Test("navigate routes bookmarks destinations to the bookmarks navigation path")
    func navigateRoutesBookmarksDestinationsToBookmarksPath() async {
        let state = AppState()
        let destination = NavigationDestination.article(
            url: URL(string: "https://example.com/bookmarks")!,
            status: nil
        )

        state.selectedTab = .bookmarks
        state.navigate(to: destination)

        #expect(state.bookmarksNavigationPath == [destination])
        #expect(state.linksNavigationPath.isEmpty == true)
        #expect(state.exploreNavigationPath.isEmpty == true)
    }

    @Test("navigateBack removes the last explore destination")
    func navigateBackRemovesLastExploreDestination() async {
        let state = AppState()

        state.selectedTab = .explore
        state.navigate(to: .settings)
        state.navigate(to: .readLaterSettings)

        state.navigateBack()

        #expect(state.exploreNavigationPath == [.settings])
    }

    @Test("navigateToRoot clears the explore navigation path")
    func navigateToRootClearsExploreNavigationPath() async {
        let state = AppState()

        state.selectedTab = .explore
        state.navigate(to: .settings)
        state.navigate(to: .readLaterSettings)

        state.navigateToRoot()

        #expect(state.exploreNavigationPath.isEmpty == true)
    }

    @Test("resolved visible tabs default to home explore messages and profile")
    func resolvedVisibleTabsUseDefaultConfiguration() async {
        await withPreservedTabConfiguration {
            let state = AppState()

            #expect(state.resolvedVisibleTabs() == [.links, .explore, .mentions, .profile])
        }
    }

    @Test("setTabVisibility does not hide home")
    func setTabVisibilityDoesNotHideHome() async {
        await withPreservedTabConfiguration {
            let state = AppState()

            state.setTabVisibility(.links, isVisible: false)

            #expect(state.resolvedVisibleTabs().contains(.links))
            #expect(state.resolvedHiddenTabs().contains(.links) == false)
        }
    }

    @Test("setTabVisibility does not hide profile")
    func setTabVisibilityDoesNotHideProfile() async {
        await withPreservedTabConfiguration {
            let state = AppState()

            state.setTabVisibility(.profile, isVisible: false)

            #expect(state.resolvedVisibleTabs().contains(.profile))
            #expect(state.resolvedHiddenTabs().contains(.profile) == false)
        }
    }

    @Test("moveTabs allows home to move away from the first position")
    func moveTabsAllowsHomeToMoveAwayFromFirstPosition() async {
        await withPreservedTabConfiguration {
            let state = AppState()

            state.moveTabs(fromOffsets: IndexSet(integer: 0), toOffset: 2)

            #expect(state.resolvedVisibleTabs() == [.explore, .links, .mentions, .profile])
        }
    }

    @Test("moveTabs keeps home and profile ahead of More when all tabs are visible")
    func moveTabsKeepsHomeAndProfileAheadOfMoreWhenAllTabsAreVisible() async {
        await withPreservedTabConfiguration {
            let state = AppState()
            state.setTabVisibility(.lists, isVisible: true)
            state.setTabVisibility(.bookmarks, isVisible: true)

            state.moveTabs(fromOffsets: IndexSet(integer: 0), toOffset: 6)
            state.moveTabs(fromOffsets: IndexSet(integer: 2), toOffset: 6)

            let primaryTabs = Array(state.resolvedVisibleTabs().prefix(4))
            #expect(primaryTabs.contains(.links))
            #expect(primaryTabs.contains(.profile))
        }
    }

    @Test("moveTabs snaps profile back ahead of More after dragging it to the end")
    func moveTabsSnapsProfileBackAheadOfMoreAfterDraggingItToTheEnd() async {
        await withPreservedTabConfiguration {
            let state = AppState()
            state.setTabVisibility(.lists, isVisible: true)
            state.setTabVisibility(.bookmarks, isVisible: true)

            state.moveTabs(fromOffsets: IndexSet(integer: 3), toOffset: 6)

            let primaryTabs = Array(state.resolvedVisibleTabs().prefix(4))
            #expect(primaryTabs.contains(.profile))
            #expect(TabOrderSettingsFeatures.tabsBehindMore(in: state.resolvedVisibleTabs()).contains(.profile) == false)
        }
    }

    @Test("tab configuration persists reordered visible and hidden tabs across relaunch")
    func tabConfigurationPersistsAcrossRelaunch() async {
        await withIsolatedUserDefaults { defaults in
            let state = AppState(defaults: defaults)

            state.setTabVisibility(.lists, isVisible: true, defaults: defaults)
            state.setTabVisibility(.explore, isVisible: false, defaults: defaults)
            state.moveTabs(fromOffsets: IndexSet(integer: 3), toOffset: 0, defaults: defaults)

            let reloadedState = AppState(defaults: defaults)

            #expect(reloadedState.resolvedVisibleTabs() == [.lists, .links, .mentions, .profile])
            #expect(reloadedState.resolvedHiddenTabs() == [.hashtags, .bookmarks, .explore])
        }
    }

    @Test("legacy separate lists setting migrates lists into visible tabs")
    func legacySeparateListsSettingMigratesIntoVisibleTabs() async {
        await withPreservedTabConfiguration {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "tabConfiguration")
            defaults.set(true, forKey: AppState.listsInSeparateTabStorageKey)

            let state = AppState()

            #expect(state.resolvedVisibleTabs().contains(.lists))
            #expect(state.resolvedHiddenTabs().contains(.lists) == false)
        }
    }

    @Test("apply default link feed uses the current tab configuration for list tab visibility")
    func applyDefaultLinkFeedUsesCurrentTabConfigurationForListTabVisibility() async {
        await withPreservedTabConfiguration {
            let state = AppState()
            state.setTabVisibility(.lists, isVisible: true)

            let feedID = state.applyDefaultLinkFeed(
                defaultListId: "list-2",
                availableListIDs: ["list-1", "list-2"]
            )

            #expect(feedID == "list-2")
            #expect(state.selectedTab == .lists)
            #expect(state.pendingListNavigationListID == "list-2")
        }
    }

    @Test("resolved default link feed falls back to home when the configured list is unavailable")
    func resolvedDefaultLinkFeedFallsBackToHome() async {
        let state = AppState()

        let feedID = state.resolvedDefaultLinkFeedID(
            defaultListId: "missing-list",
            availableListIDs: ["list-1", "list-2"]
        )

        #expect(feedID == AppState.homeFeedID)
    }

    @Test("apply default link feed selects the configured list when available")
    func applyDefaultLinkFeedSelectsConfiguredList() async {
        let state = AppState()

        let feedID = state.applyDefaultLinkFeed(
            defaultListId: "list-2",
            availableListIDs: ["list-1", "list-2"]
        )

        #expect(feedID == "list-2")
        #expect(state.selectedListId == "list-2")
        #expect(state.selectedLinkFeedID == "list-2")
    }

    @Test("apply default link feed resets selection to home when no default list matches")
    func applyDefaultLinkFeedResetsSelectionToHome() async {
        let state = AppState()
        state.selectedListId = "old-list"

        let feedID = state.applyDefaultLinkFeed(
            defaultListId: "missing-list",
            availableListIDs: ["list-1", "list-2"]
        )

        #expect(feedID == AppState.homeFeedID)
        #expect(state.selectedListId == nil)
        #expect(state.selectedLinkFeedID == AppState.homeFeedID)
    }

    @Test("visible list ids exclude hidden lists when resolving default feed selection")
    func visibleListIDsExcludeHiddenLists() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]
        state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
            sortOrder: .alphabetical,
            hiddenListIDs: ["list-2"],
            customVisibleListOrder: []
        )

        let feedID = state.applyDefaultLinkFeed(
            defaultListId: "list-2",
            availableListIDs: state.visibleListIDs(from: rawLists)
        )

        #expect(feedID == AppState.homeFeedID)
        #expect(state.selectedLinkFeedID == AppState.homeFeedID)
    }

    @Test("synchronize clears the selected feed when it becomes hidden")
    func synchronizeClearsHiddenSelectedFeed() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]
        state.selectedListId = "list-2"
        state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
            sortOrder: .alphabetical,
            hiddenListIDs: ["list-2"],
            customVisibleListOrder: []
        )

        _ = state.synchronizeCurrentAccountListDisplayPreferences(with: rawLists)

        #expect(state.selectedListId == nil)
        #expect(state.selectedLinkFeedID == AppState.homeFeedID)
    }

    @Test("synchronize clears the stored default feed when it becomes hidden")
    func synchronizeClearsHiddenDefaultFeed() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]
        let defaults = UserDefaults.standard
        let previousDefaultListID = defaults.string(forKey: AppState.defaultListIdStorageKey)
        defaults.set("list-2", forKey: AppState.defaultListIdStorageKey)
        defer {
            if let previousDefaultListID {
                defaults.set(previousDefaultListID, forKey: AppState.defaultListIdStorageKey)
            } else {
                defaults.removeObject(forKey: AppState.defaultListIdStorageKey)
            }
        }

        state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
            sortOrder: .alphabetical,
            hiddenListIDs: ["list-2"],
            customVisibleListOrder: []
        )

        _ = state.synchronizeCurrentAccountListDisplayPreferences(with: rawLists, defaults: defaults)

        #expect((defaults.string(forKey: AppState.defaultListIdStorageKey) ?? "") == "")
    }

    @Test("custom list order persists after reloading preferences for the same account")
    func customListOrderPersistsAcrossRelaunch() async {
        await withIsolatedUserDefaults { defaults in
            let rawLists = [
                makeList(id: "list-1", title: "Alpha"),
                makeList(id: "list-2", title: "Beta"),
                makeList(id: "list-3", title: "Gamma")
            ]
            let account = makeAccount()

            let state = AppState(defaults: defaults)
            state.authService.currentAccount = account
            state.loadListDisplayPreferencesForCurrentAccount(defaults: defaults)
            state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
                sortOrder: .custom,
                hiddenListIDs: [],
                customVisibleListOrder: ["list-2", "list-3", "list-1"]
            )
            state.persistListDisplayPreferencesForCurrentAccount(defaults: defaults)

            let reloadedState = AppState(defaults: defaults)
            reloadedState.authService.currentAccount = account
            reloadedState.loadListDisplayPreferencesForCurrentAccount(defaults: defaults)

            let resolution = reloadedState.resolvedListDisplay(for: rawLists)

            #expect(reloadedState.currentAccountListDisplayPreferences.sortOrder == .custom)
            #expect(reloadedState.currentAccountListDisplayPreferences.customVisibleListOrder == ["list-2", "list-3", "list-1"])
            #expect(resolution.visibleListIDs == ["list-2", "list-3", "list-1"])
        }
    }

    @Test("non custom list sorts do not overwrite the saved custom order")
    func nonCustomListSortsDoNotOverwriteSavedCustomOrder() async {
        await withIsolatedUserDefaults { defaults in
            let rawLists = [
                makeList(id: "list-1", title: "Alpha"),
                makeList(id: "list-2", title: "Beta"),
                makeList(id: "list-3", title: "Gamma")
            ]
            let account = makeAccount(id: "test.example:account-2", username: "tester2")

            let state = AppState(defaults: defaults)
            state.authService.currentAccount = account
            state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
                sortOrder: .custom,
                hiddenListIDs: [],
                customVisibleListOrder: ["list-3", "list-1", "list-2"]
            )
            state.persistListDisplayPreferencesForCurrentAccount(defaults: defaults)

            state.updateListDisplaySortOrder(.alphabetical, rawLists: rawLists, defaults: defaults)
            state.updateListDisplaySortOrder(.reverseAlphabetical, rawLists: rawLists, defaults: defaults)
            state.updateListDisplaySortOrder(.custom, rawLists: rawLists, defaults: defaults)

            let reloadedState = AppState(defaults: defaults)
            reloadedState.authService.currentAccount = account
            reloadedState.loadListDisplayPreferencesForCurrentAccount(defaults: defaults)

            let resolution = reloadedState.resolvedListDisplay(for: rawLists)

            #expect(reloadedState.currentAccountListDisplayPreferences.customVisibleListOrder == ["list-3", "list-1", "list-2"])
            #expect(resolution.visibleListIDs == ["list-3", "list-1", "list-2"])
        }
    }

    @Test("feed tabs always place home first")
    func feedTabsAlwaysPlaceHomeFirst() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]
        state.currentAccountListDisplayPreferences = AccountListDisplayPreferences(
            sortOrder: .reverseAlphabetical,
            hiddenListIDs: ["list-1"],
            customVisibleListOrder: []
        )

        let tabIDs = state.feedTabs(from: rawLists).map(\.id)

        #expect(tabIDs == [AppState.homeFeedID, "list-2"])
    }

    @Test("app tabs include lists when separate tab mode is enabled")
    func appTabsIncludeListsWhenSeparateTabModeEnabled() async {
        let state = AppState()

        let tabs = state.appTabs(listsInSeparateTab: true)

        #expect(tabs == [.links, .lists, .explore, .mentions, .profile])
    }

    @Test("home feed tabs exclude lists when separate tab mode is enabled")
    func homeFeedTabsExcludeListsWhenSeparateTabModeEnabled() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]

        let tabs = state.homeFeedTabs(from: rawLists, listsInSeparateTab: true)

        #expect(tabs.map(\.id) == [AppState.homeFeedID])
    }

    @Test("list feed tabs exclude home when separate tab mode is enabled")
    func listFeedTabsExcludeHomeWhenSeparateTabModeEnabled() async {
        let state = AppState()
        let rawLists = [
            makeList(id: "list-1", title: "Alpha"),
            makeList(id: "list-2", title: "Beta")
        ]

        let tabs = state.listFeedTabs(from: rawLists)

        #expect(tabs.map(\.id) == ["list-1", "list-2"])
    }

    @Test("apply default link feed selects lists tab when separate tab mode is enabled")
    func applyDefaultLinkFeedSelectsListsTabWhenSeparateTabModeEnabled() async {
        let state = AppState()

        let feedID = state.applyDefaultLinkFeed(
            defaultListId: "list-2",
            availableListIDs: ["list-1", "list-2"],
            listsInSeparateTab: true
        )

        #expect(feedID == "list-2")
        #expect(state.selectedListId == "list-2")
        #expect(state.selectedTab == .lists)
        #expect(state.pendingListNavigationListID == "list-2")
    }

    @Test("apply default link feed keeps home tab when separate tab mode is enabled and list is unavailable")
    func applyDefaultLinkFeedKeepsHomeTabWhenSeparateTabModeEnabledAndListUnavailable() async {
        let state = AppState()
        state.selectedTab = .lists
        state.selectedListId = "old-list"

        let feedID = state.applyDefaultLinkFeed(
            defaultListId: "missing-list",
            availableListIDs: ["list-1", "list-2"],
            listsInSeparateTab: true
        )

        #expect(feedID == AppState.homeFeedID)
        #expect(state.selectedListId == nil)
        #expect(state.selectedTab == .links)
        #expect(state.pendingListNavigationListID == nil)
    }
}

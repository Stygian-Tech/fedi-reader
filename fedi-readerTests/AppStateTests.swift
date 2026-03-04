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
}

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
}

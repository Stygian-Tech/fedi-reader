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
}

import Testing
@testable import fedi_reader

@Suite("List Display Preferences Tests")
struct ListDisplayPreferencesTests {
    @Test("alphabetical sort orders visible and hidden lists ascending")
    func alphabeticalSortOrdersListsAscending() {
        let lists = [
            makeList(id: "3", title: "Charlie"),
            makeList(id: "1", title: "alpha"),
            makeList(id: "2", title: "Beta")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .alphabetical,
            hiddenListIDs: ["2"],
            customVisibleListOrder: []
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.visibleLists.map(\.title) == ["alpha", "Charlie"])
        #expect(resolution.hiddenLists.map(\.title) == ["Beta"])
    }

    @Test("reverse alphabetical sort orders visible and hidden lists descending")
    func reverseAlphabeticalSortOrdersListsDescending() {
        let lists = [
            makeList(id: "1", title: "alpha"),
            makeList(id: "2", title: "Beta"),
            makeList(id: "3", title: "Charlie")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .reverseAlphabetical,
            hiddenListIDs: ["1"],
            customVisibleListOrder: []
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.visibleLists.map(\.title) == ["Charlie", "Beta"])
        #expect(resolution.hiddenLists.map(\.title) == ["alpha"])
    }

    @Test("custom sort respects saved visible order")
    func customSortUsesSavedVisibleOrder() {
        let lists = [
            makeList(id: "1", title: "Alpha"),
            makeList(id: "2", title: "Beta"),
            makeList(id: "3", title: "Gamma")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .custom,
            hiddenListIDs: [],
            customVisibleListOrder: ["3", "1", "2"]
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.visibleListIDs == ["3", "1", "2"])
    }

    @Test("custom sort appends new visible lists after the saved order")
    func customSortAppendsNewVisibleLists() {
        let lists = [
            makeList(id: "1", title: "Alpha"),
            makeList(id: "2", title: "Beta"),
            makeList(id: "3", title: "Gamma")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .custom,
            hiddenListIDs: [],
            customVisibleListOrder: ["2", "1"]
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.visibleListIDs == ["2", "1", "3"])
        #expect(resolution.normalizedPreferences.customVisibleListOrder == ["2", "1", "3"])
    }

    @Test("hidden lists are excluded from visible results")
    func hiddenListsAreExcludedFromVisibleResults() {
        let lists = [
            makeList(id: "1", title: "Alpha"),
            makeList(id: "2", title: "Beta"),
            makeList(id: "3", title: "Gamma")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .custom,
            hiddenListIDs: ["2"],
            customVisibleListOrder: ["2", "3", "1"]
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.visibleListIDs == ["3", "1"])
        #expect(resolution.hiddenLists.map(\.id) == ["2"])
        #expect(resolution.normalizedPreferences.customVisibleListOrder == ["3", "1"])
    }

    @Test("empty list catalog leaves saved preferences unchanged")
    func emptyListCatalogPreservesSavedPreferences() {
        let preferences = AccountListDisplayPreferences(
            sortOrder: .custom,
            hiddenListIDs: ["2"],
            customVisibleListOrder: ["3", "1", "2"]
        )

        let resolution = AccountListDisplayResolver.resolve(lists: [], preferences: preferences)

        #expect(resolution.visibleLists.isEmpty)
        #expect(resolution.hiddenLists.isEmpty)
        #expect(resolution.normalizedPreferences == preferences)
    }

    @Test("missing list identifiers are pruned during normalization")
    func missingListIdentifiersArePruned() {
        let lists = [
            makeList(id: "1", title: "Alpha"),
            makeList(id: "2", title: "Beta")
        ]
        let preferences = AccountListDisplayPreferences(
            sortOrder: .custom,
            hiddenListIDs: ["missing", "2"],
            customVisibleListOrder: ["missing", "1", "2"]
        )

        let resolution = AccountListDisplayResolver.resolve(lists: lists, preferences: preferences)

        #expect(resolution.normalizedPreferences.hiddenListIDs == ["2"])
        #expect(resolution.normalizedPreferences.customVisibleListOrder == ["1"])
    }

    private func makeList(id: String, title: String) -> MastodonList {
        MastodonList(id: id, title: title, repliesPolicy: nil, exclusive: nil)
    }
}

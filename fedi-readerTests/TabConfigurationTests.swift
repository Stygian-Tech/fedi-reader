import Testing
@testable import fedi_reader

@Suite("Tab Configuration Tests")
struct TabConfigurationTests {
    @Test("default configuration shows home explore messages and profile")
    func defaultConfigurationShowsExpectedVisibleTabs() {
        #expect(
            TabConfiguration.defaultConfiguration.visibleTabs == [.links, .explore, .mentions, .profile]
        )
        #expect(
            TabConfiguration.defaultConfiguration.hiddenTabs == [.lists, .bookmarks]
        )
    }

    @Test("normalization keeps home visible even if it was hidden")
    func normalizationKeepsHomeVisible() {
        let configuration = TabConfiguration(
            visibleTabs: [.explore, .mentions, .profile],
            hiddenTabs: [.links, .lists, .bookmarks]
        )

        let normalized = configuration.normalized()

        #expect(normalized.visibleTabs.contains(.links))
        #expect(normalized.hiddenTabs.contains(.links) == false)
    }

    @Test("normalization keeps profile visible even if it was hidden")
    func normalizationKeepsProfileVisible() {
        let configuration = TabConfiguration(
            visibleTabs: [.links, .explore, .mentions],
            hiddenTabs: [.profile, .lists, .bookmarks]
        )

        let normalized = configuration.normalized()

        #expect(normalized.visibleTabs.contains(.profile))
        #expect(normalized.hiddenTabs.contains(.profile) == false)
    }

    @Test("normalization preserves custom home position among visible tabs")
    func normalizationPreservesCustomHomePosition() {
        let configuration = TabConfiguration(
            visibleTabs: [.explore, .links, .mentions, .profile],
            hiddenTabs: [.lists, .bookmarks]
        )

        let normalized = configuration.normalized()

        #expect(normalized.visibleTabs == [.explore, .links, .mentions, .profile])
    }

    @Test("normalization appends missing tabs to the hidden list")
    func normalizationAppendsMissingTabsToHiddenList() {
        let configuration = TabConfiguration(
            visibleTabs: [.links, .explore],
            hiddenTabs: []
        )

        let normalized = configuration.normalized()

        #expect(normalized.visibleTabs == [.links, .explore, .profile])
        #expect(normalized.hiddenTabs == [.lists, .mentions, .bookmarks])
    }
}

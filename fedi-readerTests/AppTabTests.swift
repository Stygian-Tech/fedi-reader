import Testing
import Foundation
@testable import fedi_reader

@Suite("App Tab Tests")
struct AppTabTests {
    
    @Test("All tabs have titles")
    func allTabsHaveTitles() {
        for tab in AppTab.allCases {
            #expect(!tab.title.isEmpty)
        }
    }
    
    @Test("All tabs have system images")
    func allTabsHaveSystemImages() {
        for tab in AppTab.allCases {
            #expect(!tab.systemImage.isEmpty)
        }
    }
    
    @Test("Expected tabs exist")
    func expectedTabsExist() {
        let tabs = AppTab.allCases
        
        #expect(tabs.contains(.links))
        #expect(tabs.contains(.bookmarks))
        #expect(tabs.contains(.explore))
        #expect(tabs.contains(.mentions))
        #expect(tabs.contains(.profile))
    }
    
    @Test("Mentions tab uses Messages title")
    func mentionsTabUsesMessagesTitle() {
        #expect(AppTab.mentions.title == "Messages")
    }

    @Test("Bookmarks tab uses Bookmarks title")
    func bookmarksTabUsesBookmarksTitle() {
        #expect(AppTab.bookmarks.title == "Bookmarks")
    }

    @Test("Bookmarks tab uses bookmark icon")
    func bookmarksTabUsesBookmarkIcon() {
        #expect(AppTab.bookmarks.systemImage == "bookmark.fill")
    }

    @Test("Compact tab items keep their title metadata when labels are hidden")
    func compactTabItemsKeepTheirTitleMetadataWhenLabelsAreHidden() {
        #expect(
            MainTabViewTabItemFeatures.title(for: .profile, useSidebarLayout: false, hideTabBarLabels: true) == "Profile"
        )
    }

    @Test("Compact tab items switch to icon-only presentation when labels are hidden")
    func compactTabItemsSwitchToIconOnlyPresentationWhenLabelsAreHidden() {
        #expect(
            MainTabViewTabItemFeatures.usesIconOnlyLabelStyle(useSidebarLayout: false, hideTabBarLabels: true)
        )
    }

    @Test("Tab order features marks only overflow tabs as behind More")
    func tabOrderFeaturesMarksOnlyOverflowTabsAsBehindMore() {
        let tabsBehindMore = TabOrderSettingsFeatures.tabsBehindMore(
            in: [.links, .explore, .mentions, .profile, .lists, .bookmarks]
        )

        #expect(tabsBehindMore == [.lists, .bookmarks])
    }

    @Test("Tab order features shows no overflow indicator when five or fewer tabs are visible")
    func tabOrderFeaturesShowsNoOverflowIndicatorWhenFiveOrFewerTabsVisible() {
        let tabsBehindMore = TabOrderSettingsFeatures.tabsBehindMore(
            in: [.links, .explore, .mentions, .profile, .lists]
        )

        #expect(tabsBehindMore.isEmpty)
    }

    @Test("Tab order features uses disabled hide control for protected visible tabs")
    func tabOrderFeaturesUsesDisabledHideControlForProtectedVisibleTabs() {
        #expect(
            TabOrderSettingsFeatures.visibilityControlStyle(for: .links, isVisible: true) == .hideDisabled
        )
        #expect(
            TabOrderSettingsFeatures.visibilityControlStyle(for: .profile, isVisible: true) == .hideDisabled
        )
    }

    @Test("Tab order features uses enabled controls for movable tabs")
    func tabOrderFeaturesUsesEnabledControlsForMovableTabs() {
        #expect(
            TabOrderSettingsFeatures.visibilityControlStyle(for: .explore, isVisible: true) == .hideEnabled
        )
        #expect(
            TabOrderSettingsFeatures.visibilityControlStyle(for: .bookmarks, isVisible: false) == .showEnabled
        )
    }

    @Test("Tab order features delays denied move feedback until after the list settles")
    func tabOrderFeaturesDelaysDeniedMoveFeedbackUntilAfterTheListSettles() {
        #expect(TabOrderSettingsFeatures.deniedMoveFeedbackDelay > 0)
    }

    @Test("Tab order features uses shake animation duration for completion-based snap-back")
    func tabOrderFeaturesUsesShakeAnimationDurationForCompletionBasedSnapBack() {
        #expect(TabOrderSettingsFeatures.shakeAnimationDuration > 0.2)
    }

    @Test("Tab order features previews denied moves before snapping back")
    func tabOrderFeaturesPreviewsDeniedMovesBeforeSnappingBack() {
        let moveResult = TabOrderSettingsFeatures.moveResult(
            visibleTabs: [.links, .explore, .mentions, .profile, .lists, .bookmarks],
            fromOffsets: IndexSet(integer: 3),
            toOffset: 6
        )

        #expect(
            moveResult == .denied(
                tabs: [.profile],
                previewVisibleTabs: [.links, .explore, .mentions, .lists, .bookmarks, .profile]
            )
        )
    }

    @Test("Tab order features denies hiding protected tabs")
    func tabOrderFeaturesDeniesHidingProtectedTabs() {
        #expect(TabOrderSettingsFeatures.deniedVisibilityChangeTabs(for: .links, isVisible: false) == [.links])
        #expect(TabOrderSettingsFeatures.deniedVisibilityChangeTabs(for: .profile, isVisible: false) == [.profile])
    }

    @Test("Tab order features allows hiding non protected tabs")
    func tabOrderFeaturesAllowsHidingNonProtectedTabs() {
        #expect(TabOrderSettingsFeatures.deniedVisibilityChangeTabs(for: .explore, isVisible: false).isEmpty)
    }

    @Test("Tab order features denies moving profile behind More")
    func tabOrderFeaturesDeniesMovingProfileBehindMore() {
        let moveResult = TabOrderSettingsFeatures.moveResult(
            visibleTabs: [.links, .explore, .mentions, .profile, .lists, .bookmarks],
            fromOffsets: IndexSet(integer: 3),
            toOffset: 6
        )

        #expect(
            moveResult == .denied(
                tabs: [.profile],
                previewVisibleTabs: [.links, .explore, .mentions, .lists, .bookmarks, .profile]
            )
        )
    }

    @Test("Tab order features denies moves that would push home behind More")
    func tabOrderFeaturesDeniesMovesThatWouldPushHomeBehindMore() {
        let moveResult = TabOrderSettingsFeatures.moveResult(
            visibleTabs: [.links, .explore, .mentions, .profile, .lists, .bookmarks],
            fromOffsets: IndexSet(integer: 4),
            toOffset: 0
        )

        #expect(
            moveResult == .denied(
                tabs: [.profile],
                previewVisibleTabs: [.lists, .links, .explore, .mentions, .profile, .bookmarks]
            )
        )
    }

    @Test("Tab order features allows protected tabs to move within the primary section")
    func tabOrderFeaturesAllowsProtectedTabsToMoveWithinThePrimarySection() {
        let moveResult = TabOrderSettingsFeatures.moveResult(
            visibleTabs: [.links, .explore, .mentions, .profile, .lists, .bookmarks],
            fromOffsets: IndexSet(integer: 3),
            toOffset: 2
        )

        #expect(moveResult == .allowed(visibleTabs: [.links, .explore, .profile, .mentions, .lists, .bookmarks]))
    }

    @Test("Main tab selection falls back to home when the selected tab is no longer visible")
    func mainTabSelectionFallsBackToHomeWhenSelectedTabIsHidden() {
        let resolvedSelection = MainTabViewSelectionFeatures.resolvedSelection(
            selectedTab: .bookmarks,
            visibleTabs: [.links, .explore, .profile]
        )

        #expect(resolvedSelection == .links)
    }

    @Test("Main tab selection preserves a still-visible tab when the tab count shrinks")
    func mainTabSelectionPreservesVisibleSelectionWhenTabCountShrinks() {
        let resolvedSelection = MainTabViewSelectionFeatures.resolvedSelection(
            selectedTab: .explore,
            visibleTabs: [.links, .explore, .profile]
        )

        #expect(resolvedSelection == .explore)
    }
}

// MARK: - Constants Tests



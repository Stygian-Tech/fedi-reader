import SwiftUI
import Testing
@testable import fedi_reader

@Suite("Lists Tab Editing Features Tests")
struct ListsTabEditingFeaturesTests {
    @Test("list section title is hidden when edit mode is inactive")
    func listSectionTitleIsHiddenWhenEditModeIsInactive() {
        #expect(ListsTabEditingFeatures.visibleListsSectionTitle(editMode: .inactive) == nil)
    }

    @Test("list section title becomes visible when edit mode is active")
    func listSectionTitleBecomesVisibleWhenEditModeIsActive() {
        #expect(ListsTabEditingFeatures.visibleListsSectionTitle(editMode: .active) == "Visible")
    }

    @Test("editing features are hidden when edit mode is inactive")
    func editingFeaturesAreHiddenWhenEditModeIsInactive() {
        #expect(!ListsTabEditingFeatures.shouldShowEditor(editMode: .inactive))
    }

    @Test("editing features are shown when edit mode is active")
    func editingFeaturesAreShownWhenEditModeIsActive() {
        #expect(ListsTabEditingFeatures.shouldShowEditor(editMode: .active))
    }
}

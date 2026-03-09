import SwiftUI
import Testing
@testable import fedi_reader

@Suite("List Editor Edit Mode Features Tests")
struct ListEditorEditModeFeaturesTests {
    @Test("tab order editor keeps edit mode active")
    func tabOrderEditorKeepsEditModeActive() {
        #expect(TabOrderSettingsFeatures.defaultEditMode == .active)
    }

    @Test("list display editor uses active edit mode for custom sorting")
    func listDisplayEditorUsesActiveEditModeForCustomSorting() {
        #expect(ListDisplaySettingsFeatures.editMode(isCustomSortOrder: true) == .active)
    }

    @Test("list display editor disables edit mode for non-custom sorting")
    func listDisplayEditorDisablesEditModeForNonCustomSorting() {
        #expect(ListDisplaySettingsFeatures.editMode(isCustomSortOrder: false) == .inactive)
    }
}

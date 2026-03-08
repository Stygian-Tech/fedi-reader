import Testing
@testable import fedi_reader

@Suite("User Filter Toolbar Placement Tests")
struct UserFilterToolbarPlacementTests {
    @Test("default placement stays on the leading side")
    func defaultPlacementStaysOnTheLeadingSide() {
        #expect(UserFilterToolbarPlacement.leading == .leading)
    }

    @Test("lists detail placement moves to the trailing side")
    func listsDetailPlacementMovesToTheTrailingSide() {
        #expect(UserFilterToolbarPlacement.listsDetail == .trailing)
    }
}

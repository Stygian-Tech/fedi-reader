import Testing
@testable import fedi_reader

@Suite("Status Actions Bar Tests")
@MainActor
struct StatusActionsBarTests {
    private func makeBar() -> StatusActionsBar {
        StatusActionsBar(
            status: MockStatusFactory.makeStatus(),
            size: .standard
        )
    }

    @Test("StatusActionsBar omits count label when count is nil")
    func formattedCountLabelOmitsNilCount() {
        let bar = makeBar()

        #expect(bar.formattedCountLabel(for: nil) == nil)
    }

    @Test("StatusActionsBar reports active state without a numeric accessibility value when count is nil")
    func accessibilityValueOmitsNumericCountWhenNil() {
        let bar = makeBar()

        #expect(bar.accessibilityValue(for: nil, isActive: false) == "Inactive")
        #expect(bar.accessibilityValue(for: nil, isActive: true) == "Active")
    }

    @Test("StatusActionsBar still formats visible counts when present")
    func formattedCountLabelFormatsPresentCount() {
        let bar = makeBar()

        #expect(bar.formattedCountLabel(for: 1_200) == "1.2K")
        #expect(bar.accessibilityValue(for: 42, isActive: true) == "Active, 42")
    }
}

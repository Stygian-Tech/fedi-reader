import Testing
@testable import fedi_reader

@Suite("Haptic Feedback Tests")
@MainActor
struct HapticFeedbackTests {
    @Test("Navigation haptics use selection feedback")
    func navigationMapsToSelectionStyle() {
        #expect(HapticFeedback.Event.navigation.style == .selection)
    }

    @Test("Action haptics use light feedback")
    func actionMapsToLightStyle() {
        #expect(HapticFeedback.Event.action.style == .light)
    }

    @Test("State-changing haptics use medium feedback")
    func stateChangeMapsToMediumStyle() {
        #expect(HapticFeedback.Event.stateChange.style == .medium)
    }

    @Test("Confirmation haptics use success feedback")
    func confirmationMapsToSuccessStyle() {
        #expect(HapticFeedback.Event.confirmation.style == .success)
    }
}

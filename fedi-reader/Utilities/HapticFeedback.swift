//
//  HapticFeedback.swift
//  fedi-reader
//
//  Haptic feedback utility. The system automatically respects the user's
//  Settings > Sounds & Haptics > System Haptics preference.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HapticFeedback {
    enum Style: Equatable {
        case light
        case medium
        case heavy
        case selection
        case success
        
        #if os(iOS)
        var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .selection: return .medium // Selection uses medium impact
            case .success: return .medium
            }
        }
        #endif
    }

    enum Event: CaseIterable {
        case navigation
        case action
        case stateChange
        case confirmation

        var style: Style {
            switch self {
            case .navigation:
                return .selection
            case .action:
                return .light
            case .stateChange:
                return .medium
            case .confirmation:
                return .success
            }
        }
    }
    
    #if os(iOS)
    private static var lightGenerator: UIImpactFeedbackGenerator?
    private static var mediumGenerator: UIImpactFeedbackGenerator?
    private static var heavyGenerator: UIImpactFeedbackGenerator?
    private static var selectionGenerator: UISelectionFeedbackGenerator?
    private static var notificationGenerator: UINotificationFeedbackGenerator?
    #endif
    
    static func play(_ style: Style) {
        #if os(iOS)
        switch style {
        case .light:
            if lightGenerator == nil {
                lightGenerator = UIImpactFeedbackGenerator(style: .light)
            }
            lightGenerator?.impactOccurred()
            
        case .medium:
            if mediumGenerator == nil {
                mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            }
            mediumGenerator?.impactOccurred()
            
        case .heavy:
            if heavyGenerator == nil {
                heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            }
            heavyGenerator?.impactOccurred()
            
        case .selection:
            if selectionGenerator == nil {
                selectionGenerator = UISelectionFeedbackGenerator()
            }
            selectionGenerator?.selectionChanged()
        case .success:
            if notificationGenerator == nil {
                notificationGenerator = UINotificationFeedbackGenerator()
            }
            notificationGenerator?.notificationOccurred(.success)
        }
        #endif
    }

    static func play(_ event: Event) {
        play(event.style)
    }
    
    static func prepare(_ style: Style) {
        #if os(iOS)
        switch style {
        case .light:
            if lightGenerator == nil {
                lightGenerator = UIImpactFeedbackGenerator(style: .light)
            }
            lightGenerator?.prepare()
            
        case .medium:
            if mediumGenerator == nil {
                mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
            }
            mediumGenerator?.prepare()
            
        case .heavy:
            if heavyGenerator == nil {
                heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
            }
            heavyGenerator?.prepare()
            
        case .selection:
            if selectionGenerator == nil {
                selectionGenerator = UISelectionFeedbackGenerator()
            }
            selectionGenerator?.prepare()
        case .success:
            if notificationGenerator == nil {
                notificationGenerator = UINotificationFeedbackGenerator()
            }
            notificationGenerator?.prepare()
        }
        #endif
    }

    static func prepare(_ event: Event) {
        prepare(event.style)
    }
}

private struct HapticTapModifier: ViewModifier {
    let event: HapticFeedback.Event

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                HapticFeedback.play(event)
            }
        )
    }
}

extension View {
    func hapticTap(_ event: HapticFeedback.Event) -> some View {
        modifier(HapticTapModifier(event: event))
    }
}

//
//  HapticFeedback.swift
//  fedi-reader
//
//  Haptic feedback utility that respects user settings
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct HapticFeedback {
    enum Style {
        case light
        case medium
        case heavy
        case selection
        
        #if os(iOS)
        var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .selection: return .medium // Selection uses medium impact
            }
        }
        #endif
    }
    
    #if os(iOS)
    private static var lightGenerator: UIImpactFeedbackGenerator?
    private static var mediumGenerator: UIImpactFeedbackGenerator?
    private static var heavyGenerator: UIImpactFeedbackGenerator?
    private static var selectionGenerator: UISelectionFeedbackGenerator?
    #endif
    
    static func play(_ style: Style, enabled: Bool = true) {
        guard enabled else { return }
        
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
        }
        #endif
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
        }
        #endif
    }
}

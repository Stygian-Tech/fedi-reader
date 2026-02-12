//
//  ThemeColorTests.swift
//  fedi-readerTests
//
//  Unit tests for theme color preview behavior.
//

import Testing
@testable import fedi_reader

@Suite("Theme Color Tests")
struct ThemeColorTests {
    
    @Test("Light theme colors use contrast stroke in preview")
    func lightThemeColorsUseContrastStroke() {
        let lightColors: [ThemeColor] = [.yellow, .mint, .cyan]
        
        for color in lightColors {
            #expect(color.requiresContrastStrokeInPreview == true)
        }
    }
    
    @Test("Non-light theme colors do not use contrast stroke in preview")
    func nonLightThemeColorsDoNotUseContrastStroke() {
        let lightColors: Set<ThemeColor> = [.yellow, .mint, .cyan]
        
        for color in ThemeColor.allCases where !lightColors.contains(color) {
            #expect(color.requiresContrastStrokeInPreview == false)
        }
    }
    
    @Test("Theme colors do not include black or white")
    func themeColorsDoNotIncludeBlackOrWhite() {
        let rawValues = Set(ThemeColor.allCases.map(\.rawValue))
        
        #expect(rawValues.contains("black") == false)
        #expect(rawValues.contains("white") == false)
        #expect(rawValues.contains("blue") == true)
    }
}

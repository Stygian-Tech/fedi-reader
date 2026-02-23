//
//  LayoutModeHysteresisTests.swift
//  fedi-readerTests
//
//  Tests for LayoutMode hysteresis transitions while resizing.
//

import CoreGraphics
import Testing
@testable import fedi_reader

@Suite("Layout Mode Hysteresis Tests")
struct LayoutModeHysteresisTests {
    @Test("Compact transitions to medium only at or above 768")
    func compactToMediumThreshold() {
        #expect(LayoutMode.stabilizedMode(for: 767, previous: .compact) == .compact)
        #expect(LayoutMode.stabilizedMode(for: 768, previous: .compact) == .medium)
    }

    @Test("Medium transitions to compact only at or below 720")
    func mediumToCompactThreshold() {
        #expect(LayoutMode.stabilizedMode(for: 721, previous: .medium) == .medium)
        #expect(LayoutMode.stabilizedMode(for: 720, previous: .medium) == .compact)
    }

    @Test("Medium transitions to wide only at or above 1040")
    func mediumToWideThreshold() {
        #expect(LayoutMode.stabilizedMode(for: 1039, previous: .medium) == .medium)
        #expect(LayoutMode.stabilizedMode(for: 1040, previous: .medium) == .wide)
    }

    @Test("Wide transitions to medium only at or below 992")
    func wideToMediumThreshold() {
        #expect(LayoutMode.stabilizedMode(for: 993, previous: .wide) == .wide)
        #expect(LayoutMode.stabilizedMode(for: 992, previous: .wide) == .medium)
    }

    @Test("Mode does not flicker within compact or wide hysteresis bands")
    func noFlickerInsideBands() {
        var compactMode: LayoutMode = .compact
        for width in [730, 742, 750, 760, 767] as [CGFloat] {
            compactMode = LayoutMode.stabilizedMode(for: width, previous: compactMode)
            #expect(compactMode == .compact)
        }

        var wideMode: LayoutMode = .wide
        for width in [1035, 1020, 1010, 1000, 993] as [CGFloat] {
            wideMode = LayoutMode.stabilizedMode(for: width, previous: wideMode)
            #expect(wideMode == .wide)
        }
    }
}

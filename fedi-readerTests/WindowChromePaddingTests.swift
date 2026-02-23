//
//  WindowChromePaddingTests.swift
//  fedi-readerTests
//
//  Tests for top chrome padding rules in windowed layouts.
//

import CoreGraphics
import Testing
@testable import fedi_reader

@Suite("Window Chrome Padding Tests")
struct WindowChromePaddingTests {
    @Test("iPad top chrome padding uses default fallback")
    func iPadPaddingUsesFallbackValue() {
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true) == 12)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true) == WindowChromeLayoutMetrics.iPadTopPadding)
    }

    @Test("non-iPad top chrome padding remains 12")
    func nonIPadPaddingIsTwelve() {
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: false) == 12)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: false) == WindowChromeLayoutMetrics.defaultTopPadding)
    }

    @Test("iPad safe-area-aware padding only applies when safe area is collapsed")
    func iPadSafeAreaAwarePaddingIsConditional() {
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true, safeAreaTop: 0) == 12)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true, safeAreaTop: -1) == 12)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true, safeAreaTop: 1) == 0)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: true, safeAreaTop: 32) == 0)
    }

    @Test("non-iPad safe-area-aware padding remains 12")
    func nonIPadSafeAreaAwarePaddingRemainsDefault() {
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: false, safeAreaTop: 0) == 12)
        #expect(WindowChromeLayoutMetrics.topPadding(isPad: false, safeAreaTop: 44) == 12)
    }
}

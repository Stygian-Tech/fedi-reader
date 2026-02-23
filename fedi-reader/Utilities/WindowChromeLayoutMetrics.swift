//
//  WindowChromeLayoutMetrics.swift
//  fedi-reader
//
//  Shared spacing rules for window chrome clearance.
//

import SwiftUI

enum WindowChromeLayoutMetrics {
    static let defaultTopPadding: CGFloat = 12
    static let iPadTopPadding: CGFloat = 12
    static let leadingPadding: CGFloat = 52

    static func topPadding(isPad: Bool) -> CGFloat {
        isPad ? iPadTopPadding : defaultTopPadding
    }

    static func topPadding(isPad: Bool, safeAreaTop: CGFloat) -> CGFloat {
        guard isPad else { return defaultTopPadding }
        // Windowed iPad layouts can report a collapsed top safe area during live resize.
        // Apply the default chrome offset only in that case to keep header content visible.
        return safeAreaTop <= 0 ? iPadTopPadding : 0
    }
}

//
//  ScrollToTopKey.swift
//  fedi-reader
//
//  Preference key for scroll-to-top coordination.
//

import SwiftUI

struct ScrollToTopKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}

//
//  LayoutMode.swift
//  fedi-reader
//
//  Width-based layout mode for responsive iPadOS and macOS layouts.
//

import SwiftUI

/// Layout mode derived from available width.
/// - compact: < 744pt — single column, iOS-style with bottom tab bar
/// - medium: 744–1016pt — two columns, sidebar tab bar
/// - wide: >= 1016pt — three columns (Links) or two columns (Messages, Settings), sidebar tab bar
///
/// Uses hysteresis (24pt) at breakpoints to prevent layout flicker when resizing.
enum LayoutMode: Sendable {
    case compact
    case medium
    case wide

    private static let compactThreshold: CGFloat = 744
    private static let wideThreshold: CGFloat = 1016
    private static let hysteresisDelta: CGFloat = 24

    /// Stateless breakpoints: compact < 744, medium 744–1016, wide >= 1016
    static func mode(for width: CGFloat) -> LayoutMode {
        if width < compactThreshold {
            return .compact
        }
        if width < wideThreshold {
            return .medium
        }
        return .wide
    }

    /// Stateful resolver with 24pt hysteresis around compact and wide thresholds.
    static func stabilizedMode(for width: CGFloat, previous: LayoutMode) -> LayoutMode {
        switch previous {
        case .compact:
            return width >= compactThreshold + hysteresisDelta ? .medium : .compact
        case .medium:
            if width <= compactThreshold - hysteresisDelta {
                return .compact
            }
            if width >= wideThreshold + hysteresisDelta {
                return .wide
            }
            return .medium
        case .wide:
            return width <= wideThreshold - hysteresisDelta ? .medium : .wide
        }
    }

    var isCompact: Bool {
        self == .compact
    }

    var useSidebarLayout: Bool {
        !isCompact
    }
}

private struct LayoutModeKey: EnvironmentKey {
    static let defaultValue: LayoutMode = .compact
}

extension EnvironmentValues {
    var layoutMode: LayoutMode {
        get { self[LayoutModeKey.self] }
        set { self[LayoutModeKey.self] = newValue }
    }
}

//
//  ArticleViewerPreference.swift
//  fedi-reader
//
//  User preference for how to open article links.
//

import Foundation

enum ArticleViewerPreference: String, CaseIterable, Sendable {
    case inApp = "inApp"
    case safari = "safari"      // iOS only: SFSafariViewController
    case externalBrowser = "external"

    var displayName: String {
        switch self {
        case .inApp: return "FediReader"
        case .safari: return "Safari"
        case .externalBrowser: return "External Browser"
        }
    }

    /// Options available on the current platform (Safari in-app only on iOS).
    static var platformOptions: [ArticleViewerPreference] {
        #if os(iOS)
        return [.inApp, .safari, .externalBrowser]
        #else
        return [.inApp, .externalBrowser]
        #endif
    }

    /// Resolves raw string from storage, defaulting to inApp for invalid values.
    static func from(raw: String) -> ArticleViewerPreference {
        ArticleViewerPreference(rawValue: raw) ?? .inApp
    }

    /// Resolves stored preference with migration from legacy useSafariViewer.
    static func resolved(from storageKey: String = "articleViewerPreference", defaults: UserDefaults = .standard) -> ArticleViewerPreference {
        if let raw = defaults.string(forKey: storageKey), let pref = ArticleViewerPreference(rawValue: raw) {
            return pref
        }
        // Migrate from legacy useSafariViewer
        let legacyKey = "useSafariViewer"
        if defaults.object(forKey: legacyKey) != nil {
            let useSafari = defaults.bool(forKey: legacyKey)
            let migrated: ArticleViewerPreference = useSafari ? .safari : .inApp
            defaults.set(migrated.rawValue, forKey: storageKey)
            defaults.removeObject(forKey: legacyKey)
            return migrated
        }
        return .inApp
    }
}

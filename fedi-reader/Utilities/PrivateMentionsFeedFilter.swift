//
//  PrivateMentionsFeedFilter.swift
//  fedi-reader
//
//  Shared preference and helpers for filtering private mentions from link feeds.
//

import Foundation

enum PrivateMentionsFeedFilter {
    nonisolated static let storageKey = "filterPrivateMentionsFromFeeds"
    nonisolated static let defaultValue = true

    nonisolated static func isPrivateMention(_ status: Status) -> Bool {
        let visibility = status.displayStatus.visibility
        return visibility == .private || visibility == .direct
    }
}

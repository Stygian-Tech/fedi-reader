//
//  TimelineServiceWrapper.swift
//  fedi-reader
//
//  Observable wrapper for TimelineService used with SwiftUI environment.
//

import Foundation

@Observable
@MainActor
final class TimelineServiceWrapper {
    var service: TimelineService?
    private var cachedListsByAccountId: [String: [MastodonList]] = [:]

    init(service: TimelineService? = nil) {
        self.service = service
    }

    func cachedLists(for accountId: String?) -> [MastodonList] {
        guard let accountId else { return [] }
        return cachedListsByAccountId[accountId] ?? []
    }

    func updateCachedLists(_ lists: [MastodonList], for accountId: String?, allowEmpty: Bool = false) {
        guard let accountId else { return }
        guard allowEmpty || !lists.isEmpty else { return }
        cachedListsByAccountId[accountId] = lists
    }

    func clearCachedLists(for accountId: String?) {
        guard let accountId else { return }
        cachedListsByAccountId.removeValue(forKey: accountId)
    }
}

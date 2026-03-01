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
    private var startupLinkFeedLoadTask: Task<Void, Never>?
    private var startupLinkFeedAccountId: String?
    private var completedStartupLinkFeedAccountId: String?

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

    func resetStartupLinkFeedLoad(for accountId: String?) {
        if startupLinkFeedAccountId != accountId {
            startupLinkFeedLoadTask?.cancel()
            startupLinkFeedLoadTask = nil
            startupLinkFeedAccountId = accountId
        }

        if completedStartupLinkFeedAccountId != accountId {
            completedStartupLinkFeedAccountId = nil
        }
    }

    func beginStartupLinkFeedLoad(
        for accountId: String?,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard let accountId else { return }

        resetStartupLinkFeedLoad(for: accountId)

        guard completedStartupLinkFeedAccountId != accountId else { return }
        guard startupLinkFeedLoadTask == nil else { return }

        startupLinkFeedLoadTask = Task { @MainActor [weak self] in
            await operation()

            guard let self, self.startupLinkFeedAccountId == accountId else { return }
            self.completedStartupLinkFeedAccountId = accountId
            self.startupLinkFeedLoadTask = nil
        }
    }

    func waitForStartupLinkFeedLoad() async {
        let task = startupLinkFeedLoadTask
        await task?.value
    }
}

//
//  PaginatedAccountList.swift
//  fedi-reader
//
//  Merge helpers for paginated Mastodon account lists.
//

import Foundation

struct PaginatedAccountListMergeResult {
    let mergedAccounts: [MastodonAccount]
    let nextMaxId: String?
    let hasMore: Bool
}

enum PaginatedAccountList {
    static func merge(
        existing: [MastodonAccount],
        incoming: [MastodonAccount],
        requestedMaxId: String?,
        pageSize: Int
    ) -> PaginatedAccountListMergeResult {
        let existingIDs = Set(existing.map(\.id))
        let uniqueIncoming = incoming.filter { !existingIDs.contains($0.id) }
        let mergedAccounts = existing + uniqueIncoming
        let nextMaxId = incoming.last?.id

        let reachedEndByCount = incoming.count < pageSize
        let repeatedPage = requestedMaxId != nil && (nextMaxId == requestedMaxId || uniqueIncoming.isEmpty)
        let hasMore = !incoming.isEmpty && !reachedEndByCount && !repeatedPage

        return PaginatedAccountListMergeResult(
            mergedAccounts: mergedAccounts,
            nextMaxId: nextMaxId,
            hasMore: hasMore
        )
    }
}

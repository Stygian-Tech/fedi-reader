import Foundation

struct PaginatedAccountListMergeResult {
    let mergedAccounts: [MastodonAccount]
    let nextMaxId: String?
    let hasMore: Bool
}



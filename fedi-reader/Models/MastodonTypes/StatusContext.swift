import Foundation

struct StatusContext: Codable, Sendable {
    let ancestors: [Status]
    let descendants: [Status]
    let hasMoreReplies: Bool?
    let asyncRefreshId: String?
    
    enum CodingKeys: String, CodingKey {
        case ancestors, descendants
        case hasMoreReplies = "has_more_replies"
        case asyncRefreshId = "async_refresh_id"
    }
    
    nonisolated init(ancestors: [Status], descendants: [Status], hasMoreReplies: Bool? = nil, asyncRefreshId: String? = nil) {
        self.ancestors = ancestors
        self.descendants = descendants
        self.hasMoreReplies = hasMoreReplies
        self.asyncRefreshId = asyncRefreshId
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ancestors = try container.decode([Status].self, forKey: .ancestors)
        descendants = try container.decode([Status].self, forKey: .descendants)
        hasMoreReplies = try container.decodeIfPresent(Bool.self, forKey: .hasMoreReplies)
        asyncRefreshId = try container.decodeIfPresent(String.self, forKey: .asyncRefreshId)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ancestors, forKey: .ancestors)
        try container.encode(descendants, forKey: .descendants)
        try container.encodeIfPresent(hasMoreReplies, forKey: .hasMoreReplies)
        try container.encodeIfPresent(asyncRefreshId, forKey: .asyncRefreshId)
    }
}

extension StatusContext {
    nonisolated func parentStatus(for status: Status) -> Status? {
        let targetStatus = status.displayStatus

        guard let replyToId = targetStatus.inReplyToId else {
            return nil
        }

        return ancestors.last(where: { $0.id == replyToId }) ?? ancestors.last
    }

    nonisolated var hasPendingAsyncRefresh: Bool {
        guard let asyncRefreshId else {
            return false
        }

        return !asyncRefreshId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    nonisolated func needsRemoteReplyFetch(for status: Status, localInstance: String? = nil) -> Bool {
        let targetStatus = status.displayStatus

        if hasPendingAsyncRefresh || hasMoreReplies == true {
            return true
        }

        return targetStatus.repliesCount > descendants.count
    }

    nonisolated func resolvedReplyCount(for status: Status) -> Int {
        let targetStatus = status.displayStatus
        let discoveredReplyCount = descendants.count

        if hasPendingAsyncRefresh || hasMoreReplies == true {
            return max(targetStatus.repliesCount, discoveredReplyCount)
        }

        return discoveredReplyCount
    }

    nonisolated func merged(with newerContext: StatusContext) -> StatusContext {
        StatusContext(
            ancestors: mergeStatuses(ancestors, with: newerContext.ancestors),
            descendants: mergeStatuses(descendants, with: newerContext.descendants)
                .sorted { $0.createdAt < $1.createdAt },
            hasMoreReplies: newerContext.hasMoreReplies ?? hasMoreReplies,
            asyncRefreshId: newerContext.hasPendingAsyncRefresh ? newerContext.asyncRefreshId : nil
        )
    }
}

private nonisolated func mergeStatuses(_ existing: [Status], with incoming: [Status]) -> [Status] {
    var mergedById: [String: Status] = [:]
    var orderedIds: [String] = []

    for status in existing + incoming {
        if mergedById[status.id] == nil {
            orderedIds.append(status.id)
        }
        mergedById[status.id] = status
    }

    return orderedIds.compactMap { mergedById[$0] }
}

// MARK: - Author Attribution

import Foundation

enum ThreadBuilder {
    enum ReplyOrdering: Sendable {
        case chronological
        case prioritizeAuthor(String?)
    }

    /// Builds a thread tree from a flat array of statuses
    /// Returns root-level threads (statuses that aren't replies, or whose parent isn't in the set)
    /// Uses O(n) pre-grouping to avoid O(n²) filtering on large reply threads
    nonisolated static func buildThreadTree(
        from statuses: [Status],
        replyOrdering: ReplyOrdering = .chronological
    ) -> [ThreadNode] {
        guard !statuses.isEmpty else { return [] }
        
        let statusMap = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        let repliesByParentId = Dictionary(grouping: statuses) { $0.inReplyToId ?? "" }
        
        let rootStatuses = findRootStatuses(statuses, statusMap: statusMap)
            .sorted(by: makeStatusComparator(replyOrdering: replyOrdering))
        
        return rootStatuses.map { root in
            buildSubtree(root: root, repliesByParentId: repliesByParentId, replyOrdering: replyOrdering)
        }
    }
    
    /// Identifies root-level statuses (top of threads)
    nonisolated static func findRootStatuses(_ statuses: [Status], statusMap: [String: Status]) -> [Status] {
        statuses.filter { status in
            guard let replyToId = status.inReplyToId else {
                return true
            }
            return statusMap[replyToId] == nil
        }
    }
    
    /// Recursively builds a subtree; uses pre-grouped replies for O(1) child lookup
    private nonisolated static func buildSubtree(
        root: Status,
        repliesByParentId: [String: [Status]],
        replyOrdering: ReplyOrdering
    ) -> ThreadNode {
        let directReplies = (repliesByParentId[root.id] ?? [])
            .sorted(by: makeStatusComparator(replyOrdering: replyOrdering))
        let childNodes = directReplies.map {
            buildSubtree(root: $0, repliesByParentId: repliesByParentId, replyOrdering: replyOrdering)
        }
        return ThreadNode(status: root, children: childNodes)
    }
    
    /// Merges multiple thread trees, combining those that share common statuses
    nonisolated static func mergeThreads(_ threads: [ThreadNode]) -> [ThreadNode] {
        // For now, return threads as-is. More sophisticated merging could be added later
        // if needed for cross-conversation threading
        return threads
    }
    
    /// Finds the root thread node containing a specific status
    nonisolated static func findThreadRoot(for status: Status, in threads: [ThreadNode]) -> ThreadNode? {
        for thread in threads {
            if let found = thread.findNode(withId: status.id) {
                // Walk up to find root
                return findRootOfNode(found, in: threads)
            }
        }
        return nil
    }
    
    /// Helper to find the root of a node within a thread forest
    private nonisolated static func findRootOfNode(_ node: ThreadNode, in threads: [ThreadNode]) -> ThreadNode? {
        // Check if this node is a root in any thread
        for thread in threads {
            if thread.id == node.id {
                return thread
            }
            // Check if node is in this thread's subtree
            if thread.findNode(withId: node.id) != nil {
                return thread
            }
        }
        return nil
    }

    private nonisolated static func makeStatusComparator(
        replyOrdering: ReplyOrdering
    ) -> (Status, Status) -> Bool {
        switch replyOrdering {
        case .chronological:
            return chronologicalComparator
        case let .prioritizeAuthor(authorId):
            guard let authorId, !authorId.isEmpty else {
                return chronologicalComparator
            }

            return { lhs, rhs in
                let lhsPriority = lhs.account.id == authorId
                let rhsPriority = rhs.account.id == authorId

                if lhsPriority != rhsPriority {
                    return lhsPriority && !rhsPriority
                }

                return chronologicalComparator(lhs, rhs)
            }
        }
    }

    private nonisolated static func chronologicalComparator(_ lhs: Status, _ rhs: Status) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id < rhs.id
    }
}

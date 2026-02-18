import Foundation

enum ThreadBuilder {
    /// Builds a thread tree from a flat array of statuses
    /// Returns root-level threads (statuses that aren't replies, or whose parent isn't in the set)
    static func buildThreadTree(from statuses: [Status]) -> [ThreadNode] {
        guard !statuses.isEmpty else { return [] }
        
        // Create a lookup map for quick parent finding
        let statusMap = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        
        // Find root statuses (those with no parent or parent not in the set)
        let rootStatuses = findRootStatuses(statuses, statusMap: statusMap)
        
        // Build tree for each root
        return rootStatuses.map { root in
            buildSubtree(root: root, allStatuses: statuses, statusMap: statusMap)
        }
    }
    
    /// Identifies root-level statuses (top of threads)
    static func findRootStatuses(_ statuses: [Status], statusMap: [String: Status]) -> [Status] {
        statuses.filter { status in
            guard let replyToId = status.inReplyToId else {
                // No parent = root
                return true
            }
            // If parent is not in our set, this is effectively a root
            return statusMap[replyToId] == nil
        }
    }
    
    /// Recursively builds a subtree starting from a root status
    static func buildSubtree(root: Status, allStatuses: [Status], statusMap: [String: Status]) -> ThreadNode {
        // Find all direct replies to this status
        let directReplies = allStatuses.filter { $0.inReplyToId == root.id }
        
        // Sort replies chronologically
        let sortedReplies = directReplies.sorted { $0.createdAt < $1.createdAt }
        
        // Recursively build subtrees for each reply
        let childNodes = sortedReplies.map { reply in
            buildSubtree(root: reply, allStatuses: allStatuses, statusMap: statusMap)
        }
        
        return ThreadNode(status: root, children: childNodes)
    }
    
    /// Merges multiple thread trees, combining those that share common statuses
    static func mergeThreads(_ threads: [ThreadNode]) -> [ThreadNode] {
        // For now, return threads as-is. More sophisticated merging could be added later
        // if needed for cross-conversation threading
        return threads
    }
    
    /// Finds the root thread node containing a specific status
    static func findThreadRoot(for status: Status, in threads: [ThreadNode]) -> ThreadNode? {
        for thread in threads {
            if let found = thread.findNode(withId: status.id) {
                // Walk up to find root
                return findRootOfNode(found, in: threads)
            }
        }
        return nil
    }
    
    /// Helper to find the root of a node within a thread forest
    private static func findRootOfNode(_ node: ThreadNode, in threads: [ThreadNode]) -> ThreadNode? {
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
}


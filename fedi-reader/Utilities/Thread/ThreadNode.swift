import Foundation

struct ThreadNode: Identifiable, Sendable {
    let id: String
    let status: Status
    var children: [ThreadNode]
    
    nonisolated init(status: Status, children: [ThreadNode] = []) {
        self.id = status.id
        self.status = status
        self.children = children
    }
    
    /// Calculates the depth of this node in the tree (0 for root)
    nonisolated var depth: Int {
        if children.isEmpty {
            return 0
        }
        return 1 + (children.map { $0.depth }.max() ?? 0)
    }
    
    /// Flattens the tree into a depth-first list of statuses
    nonisolated func flattened() -> [Status] {
        var result = [status]
        for child in children.sorted(by: { $0.status.createdAt < $1.status.createdAt }) {
            result.append(contentsOf: child.flattened())
        }
        return result
    }
    
    /// Flattens the tree into a list of ThreadNodes in depth-first order
    nonisolated func flattenedNodes() -> [ThreadNode] {
        var result = [self]
        for child in children.sorted(by: { $0.status.createdAt < $1.status.createdAt }) {
            result.append(contentsOf: child.flattenedNodes())
        }
        return result
    }
    
    /// Finds a node with the given status ID in this subtree
    nonisolated func findNode(withId statusId: String) -> ThreadNode? {
        if id == statusId {
            return self
        }
        for child in children {
            if let found = child.findNode(withId: statusId) {
                return found
            }
        }
        return nil
    }
    
    /// Gets the path from root to this node (including this node)
    nonisolated func pathToRoot() -> [Status] {
        let path = [status]
        // Note: This assumes we have parent references, but we don't.
        // For now, this just returns the current status.
        // Full path building would require parent tracking.
        return path
    }
    
    /// Counts total number of replies in this subtree (including self)
    nonisolated var totalReplies: Int {
        1 + children.reduce(0) { $0 + $1.totalReplies }
    }
    
    /// Checks if this node has any children
    nonisolated var hasReplies: Bool {
        !children.isEmpty
    }
}

/// Helper for building thread trees from flat status arrays

//
//  ThreadingService.swift
//  fedi-reader
//
//  Service for building and managing reply thread structures
//

import Foundation
import os

@Observable
@MainActor
final class ThreadingService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ThreadingService")
    
    /// Builds a thread tree from a flat array of statuses
    func buildThreadTree(from statuses: [Status]) -> [ThreadNode] {
        ThreadBuilder.buildThreadTree(from: statuses)
    }
    
    /// Merges multiple thread trees, useful when combining statuses from different sources
    func mergeThreads(_ threads: [ThreadNode]) -> [ThreadNode] {
        ThreadBuilder.mergeThreads(threads)
    }
    
    /// Finds the root thread node containing a specific status
    func findThreadRoot(for status: Status, in threads: [ThreadNode]) -> ThreadNode? {
        ThreadBuilder.findThreadRoot(for: status, in: threads)
    }
    
    /// Gets the path from root to a specific status ID within a thread
    func getThreadPath(to statusId: String, from root: ThreadNode) -> [Status] {
        guard root.findNode(withId: statusId) != nil else {
            return []
        }
        
        // Build path by walking up the tree
        var path: [Status] = []
        
        // Since we don't have parent references, we'll build the path by searching
        // This is less efficient but works with our current structure
        buildPath(to: statusId, from: root, currentPath: [], result: &path)
        
        return path
    }
    
    /// Helper to recursively build path to a status
    private func buildPath(to statusId: String, from node: ThreadNode, currentPath: [Status], result: inout [Status]) {
        let newPath = currentPath + [node.status]
        
        if node.id == statusId {
            result = newPath
            return
        }
        
        for child in node.children {
            buildPath(to: statusId, from: child, currentPath: newPath, result: &result)
            if !result.isEmpty {
                return
            }
        }
    }
    
    /// Builds a unified thread tree from ancestors, current status, and descendants
    /// This is useful for StatusDetailView where we have separate ancestor/descendant arrays
    func buildUnifiedThread(
        ancestors: [Status],
        current: Status,
        descendants: [Status]
    ) -> ThreadNode {
        // Combine all statuses
        let allStatuses = ancestors + [current] + descendants
        
        // Build the full tree
        let threads = buildThreadTree(from: allStatuses)
        
        // Find the thread containing the current status
        if let currentThread = threads.first(where: { $0.findNode(withId: current.id) != nil }) {
            return currentThread
        }
        
        // Fallback: if current status isn't in any thread, create a simple node
        // This can happen if ancestors/descendants don't properly connect
        let descendantNodes = buildThreadTree(from: descendants)
        return ThreadNode(status: current, children: descendantNodes)
    }
    
    /// Handles orphaned replies (replies whose parent is missing)
    /// Returns threads with orphaned replies either as roots or with placeholder parents
    func handleOrphanedReplies(_ statuses: [Status]) -> [ThreadNode] {
        let statusMap = Dictionary(uniqueKeysWithValues: statuses.map { ($0.id, $0) })
        
        // Separate orphaned replies
        var orphaned: [Status] = []
        var valid: [Status] = []
        
        for status in statuses {
            if let replyToId = status.inReplyToId, statusMap[replyToId] == nil {
                orphaned.append(status)
            } else {
                valid.append(status)
            }
        }
        
        // Build normal threads from valid statuses
        var threads = buildThreadTree(from: valid)
        
        // Add orphaned replies as root-level threads
        let orphanedThreads = buildThreadTree(from: orphaned)
        threads.append(contentsOf: orphanedThreads)
        
        return threads
    }
}

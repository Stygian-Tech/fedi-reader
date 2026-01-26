//
//  RemoteReplyService.swift
//  fedi-reader
//
//  Service for fetching remote replies to statuses following Mastodon best practices
//

import Foundation
import os

@Observable
@MainActor
final class RemoteReplyService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "RemoteReplyService")
    
    private let client: MastodonClient
    private let authService: AuthService
    
    // Cache for resolved remote statuses to avoid redundant fetches
    private var resolvedStatusCache: [String: Status] = [:]
    private var cacheLock = NSLock()
    
    init(client: MastodonClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }
    
    // MARK: - Public API
    
    /// Fetches remote replies for a given status, resolving any missing remote statuses
    func fetchRemoteReplies(for status: Status) async -> [Status] {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.warning("No active account for remote reply fetch")
            return []
        }
        
        Self.logger.info("Fetching remote replies for status: \(status.id.prefix(8), privacy: .public)")
        
        do {
            // Get context with async refresh support
            let contextWithRefresh = try await client.getStatusContextWithRefresh(
                instance: account.instance,
                accessToken: token,
                id: status.id
            )
            
            let context = contextWithRefresh.context
            
            // Check if we need to fetch missing replies
            let missingReplies = try await fetchMissingReplies(
                context: context,
                status: status,
                instance: account.instance,
                accessToken: token
            )
            
            // Combine known descendants with newly fetched remote replies
            var allReplies = context.descendants
            
            // Add missing replies that aren't already in descendants
            let existingIds = Set(context.descendants.map { $0.id })
            for reply in missingReplies {
                if !existingIds.contains(reply.id) {
                    allReplies.append(reply)
                }
            }
            
            // Sort by creation date (oldest first for thread order)
            allReplies.sort { $0.createdAt < $1.createdAt }
            
            Self.logger.info("Fetched \(allReplies.count) total replies (including \(missingReplies.count) remote)")
            return allReplies
            
        } catch {
            Self.logger.error("Error fetching remote replies: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches missing replies by comparing expected count with known descendants.
    ///
    /// We intentionally return `[]` because the API does not expose specific missing reply URIs.
    /// **Missing replies are handled via async refresh**: when the server returns
    /// `Mastodon-Async-Refresh`, we poll `GET /api/v1_alpha/async_refreshes/:id`, then re-GET
    /// context. That flow (in TimelineService) is what fills in newly fetched replies—not this helper.
    func fetchMissingReplies(
        context: StatusContext,
        status: Status,
        instance: String,
        accessToken: String
    ) async throws -> [Status] {
        let expectedCount = status.repliesCount
        let knownCount = context.descendants.count
        
        guard expectedCount > knownCount else {
            Self.logger.debug("No missing replies detected (expected: \(expectedCount), known: \(knownCount))")
            return []
        }
        
        let missingCount = expectedCount - knownCount
        Self.logger.info("Detected \(missingCount) missing replies, attempting to fetch")
        
        // The /context endpoint may not return all replies (e.g. remote instances, policy filters).
        // We cannot identify which specific replies are missing. Async refresh + re-GET context
        // (see TimelineService) handles those cases; this helper remains a no-op.
        Self.logger.debug("Missing replies: expected \(expectedCount), have \(knownCount). Rely on async refresh + re-GET context.")
        
        return []
    }
    
    /// Resolves a remote status by its URI with comprehensive error handling
    func resolveRemoteStatus(uri: String, instance: String, accessToken: String) async throws -> Status? {
        // Check cache first
        if let cached = getCachedStatus(uri: uri) {
            Self.logger.debug("Using cached status for URI: \(uri.prefix(50), privacy: .public)")
            return cached
        }
        
        // Try to resolve via MastodonClient with error handling
        do {
            guard let resolved = try await client.resolveStatus(
                instance: instance,
                accessToken: accessToken,
                uri: uri
            ) else {
                Self.logger.debug("Could not resolve remote status URI: \(uri.prefix(50), privacy: .public)")
                return nil
            }
            
            // Cache the resolved status
            cacheStatus(uri: uri, status: resolved)
            
            Self.logger.info("Resolved remote status: \(resolved.id.prefix(8), privacy: .public)")
            return resolved
        } catch let error as FediReaderError {
            // Handle specific error types gracefully
            switch error {
            case .rateLimited:
                Self.logger.warning("Rate limited while resolving remote status, will retry later")
                // Don't cache failure, allow retry
                return nil
            case .networkError:
                Self.logger.debug("Network error resolving remote status (instance may be unreachable): \(uri.prefix(50), privacy: .public)")
                return nil
            case .serverError(let code, _):
                if code == 404 {
                    Self.logger.debug("Remote status not found (404): \(uri.prefix(50), privacy: .public)")
                } else {
                    Self.logger.warning("Server error (\(code)) resolving remote status: \(uri.prefix(50), privacy: .public)")
                }
                return nil
            case .unauthorized:
                Self.logger.debug("Unauthorized to access remote status: \(uri.prefix(50), privacy: .public)")
                return nil
            default:
                Self.logger.debug("Error resolving remote status: \(error.localizedDescription)")
                return nil
            }
        } catch {
            // Catch-all for unexpected errors
            Self.logger.debug("Unexpected error resolving remote status: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Caching
    
    private func getCachedStatus(uri: String) -> Status? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return resolvedStatusCache[uri]
    }
    
    private func cacheStatus(uri: String, status: Status) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        resolvedStatusCache[uri] = status
        
        // Limit cache size to prevent memory issues
        if resolvedStatusCache.count > 100 {
            // Remove oldest entries (simple FIFO - in production, use LRU)
            let keysToRemove = Array(resolvedStatusCache.keys.prefix(20))
            for key in keysToRemove {
                resolvedStatusCache.removeValue(forKey: key)
            }
        }
    }
    
    /// Clears the resolved status cache
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        resolvedStatusCache.removeAll()
        Self.logger.debug("Cleared remote reply cache")
    }
}

// MARK: - Timeout Helper

/// Executes an async operation with a timeout, returning nil if timeout occurs
private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping () async throws -> T) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        // Add the actual operation
        group.addTask {
            do {
                return try await operation()
            } catch {
                // Swallow errors - let caller handle them if needed
                return nil
            }
        }
        
        // Add timeout task
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        
        // Return first completed result (either operation or timeout)
        let result = await group.next()
        group.cancelAll()
        return result ?? nil
    }
}

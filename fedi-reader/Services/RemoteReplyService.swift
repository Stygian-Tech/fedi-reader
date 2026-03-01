//
//  RemoteReplyService.swift
//  fedi-reader
//
//  Service for fetching remote replies to statuses following Mastodon best practices
//

import Foundation
import os

final class RemoteReplyService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "RemoteReplyService")
    
    private let client: MastodonClient
    private let authService: AuthService
    private let contextRefetchDelaySeconds: TimeInterval
    
    // Cache for resolved remote statuses to avoid redundant fetches
    private var resolvedStatusCache: [String: Status] = [:]
    private var cacheLock = NSLock()
    
    init(
        client: MastodonClient,
        authService: AuthService,
        contextRefetchDelaySeconds: TimeInterval = Constants.RemoteReplies.contextRefetchDelaySeconds
    ) {
        self.client = client
        self.authService = authService
        self.contextRefetchDelaySeconds = contextRefetchDelaySeconds
    }
    
    // MARK: - Public API
    
    /// Fetches and merges the most complete reply context available for a status.
    func fetchRemoteReplyContext(for status: Status, initialContext: StatusContext? = nil) async -> StatusContext? {
        guard let session = await authService.activeSessionSnapshot() else {
            Self.logger.warning("No active account for remote reply fetch")
            return initialContext
        }
        
        Self.logger.info("Fetching remote replies for status: \(status.id.prefix(8), privacy: .public)")
        
        do {
            let startingContext: StatusContext
            if let initialContext {
                startingContext = initialContext
            } else {
                let contextWithRefresh = try await client.getStatusContextWithRefreshInBackground(
                    instance: session.instance,
                    accessToken: session.accessToken,
                    id: status.id
                )
                startingContext = contextWithRefresh.context
            }

            let updatedContext = try await fetchMissingReplies(
                context: startingContext,
                status: status,
                instance: session.instance,
                accessToken: session.accessToken
            )

            Self.logger.info("Resolved reply context with \(updatedContext.descendants.count) replies")
            return updatedContext
            
        } catch {
            Self.logger.error("Error fetching remote replies: \(error.localizedDescription)")
            return initialContext
        }
    }
    
    /// Re-fetches context when the server hints that additional remote replies exist.
    func fetchMissingReplies(
        context: StatusContext,
        status: Status,
        instance: String,
        accessToken: String
    ) async throws -> StatusContext {
        guard context.needsRemoteReplyFetch(for: status, localInstance: instance) else {
            Self.logger.debug("No missing replies detected for status \(status.id.prefix(8), privacy: .public)")
            return context
        }

        var latestContext = context
        var delaySeconds: TimeInterval = 0
        let maxAttempts = max(Constants.RemoteReplies.maxRetries + 1, 1)

        for attempt in 0..<maxAttempts {
            if Task.isCancelled {
                break
            }

            if attempt > 0, delaySeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }

            do {
                let contextWithRefresh = try await client.getStatusContextWithRefreshInBackground(
                    instance: instance,
                    accessToken: accessToken,
                    id: status.id
                )

                latestContext = latestContext.merged(with: contextWithRefresh.context)
                Self.logger.debug(
                    "Remote reply fetch attempt \(attempt + 1)/\(maxAttempts) returned \(latestContext.descendants.count) replies"
                )

                if !latestContext.needsRemoteReplyFetch(for: status, localInstance: instance) {
                    break
                }

                delaySeconds = nextDelaySeconds(
                    from: contextWithRefresh,
                    currentContext: latestContext
                )
            } catch {
                if attempt == maxAttempts - 1 {
                    throw error
                }

                Self.logger.debug("Retrying remote reply fetch after error: \(error.localizedDescription)")
                delaySeconds = contextRefetchDelaySeconds
            }
        }

        return latestContext
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

    private func nextDelaySeconds(
        from contextWithRefresh: MastodonClient.StatusContextWithRefresh,
        currentContext: StatusContext
    ) -> TimeInterval {
        if let asyncRefreshHeader = contextWithRefresh.asyncRefreshHeader {
            return TimeInterval(asyncRefreshHeader.retrySeconds)
        }

        if currentContext.hasPendingAsyncRefresh {
            return TimeInterval(Constants.RemoteReplies.asyncRefreshFallbackRetrySeconds)
        }

        return contextRefetchDelaySeconds
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

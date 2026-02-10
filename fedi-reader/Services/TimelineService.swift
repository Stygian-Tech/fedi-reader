//
//  TimelineService.swift
//  fedi-reader
//
//  Timeline fetching and pagination management
//

import Foundation
import SwiftData
import os

@Observable
@MainActor
final class TimelineService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "TimelineService")
    
    private let client: MastodonClient
    private let authService: AuthService
    private let remoteReplyService: RemoteReplyService
    
    // Timeline state
    var homeTimeline: [Status] = []
    var exploreStatuses: [Status] = []
    var trendingLinks: [TrendingLink] = []
    var mentions: [MastodonNotification] = []
    var conversations: [MastodonConversation] = []
    
    // List state
    var lists: [MastodonList] = []
    var listTimeline: [Status] = []
    var listAccounts: [MastodonAccount] = []
    
    // Loading state
    var isLoadingHome = false
    var isLoadingExplore = false
    var isLoadingMentions = false
    var isLoadingConversations = false
    var isLoadingMore = false
    var isLoadingLists = false
    var isLoadingListTimeline = false
    var isLoadingListAccounts = false
    
    // Pagination cursors
    private var homeMaxId: String?
    private var homeMinId: String?
    private var exploreMaxId: String?
    private var mentionsMaxId: String?
    private var conversationsMaxId: String?
    private var listTimelineMaxId: String?
    private var listAccountsMaxId: String?
    private var listsLastRefreshedAt: Date?
    private var listsLastRefreshedForAccountId: String?
    
    /// Polling tasks for async refresh, keyed by status ID. Cancelled when starting a new refresh for same status or via cancelAsyncRefreshPolling.
    private var asyncRefreshPollingTasks: [String: Task<Void, Never>] = [:]
    
    // Error state
    var error: Error?
    
    // Unread conversations count
    var unreadConversationsCount: Int {
        conversations.filter { $0.unread == true }.count
    }
    
    init(client: MastodonClient, authService: AuthService) {
        self.client = client
        self.authService = authService
        self.remoteReplyService = RemoteReplyService(client: client, authService: authService)
    }
    
    // MARK: - Home Timeline
    
    func loadHomeTimeline(refresh: Bool = false) async {
        guard !isLoadingHome else {
            Self.logger.debug("Home timeline load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for home timeline load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading home timeline, refresh: \(refresh), current count: \(self.homeTimeline.count), maxId: \(self.homeMaxId?.prefix(8) ?? "nil", privacy: .public)")
        isLoadingHome = true
        error = nil
        
        do {
            let statuses = try await client.getHomeTimeline(
                instance: account.instance,
                accessToken: token,
                maxId: refresh ? nil : homeMaxId,
                limit: Constants.Pagination.defaultLimit
            )
            
            if refresh {
                homeTimeline = statuses
                Self.logger.info("Home timeline refreshed: \(statuses.count) statuses")
            } else {
                homeTimeline.append(contentsOf: statuses)
                Self.logger.info("Home timeline loaded more: \(statuses.count) new statuses, total: \(self.homeTimeline.count)")
            }
            
            // Update pagination cursor
            if statuses.isEmpty {
                homeMaxId = nil
                if refresh {
                    homeMinId = nil
                }
                Self.logger.debug("Home timeline returned no statuses; reached pagination end")
            } else {
                if let lastStatus = statuses.last {
                    homeMaxId = lastStatus.id
                    Self.logger.debug("Updated home timeline maxId: \(lastStatus.id.prefix(8), privacy: .public)")
                }
                if let firstStatus = statuses.first, refresh {
                    homeMinId = firstStatus.id
                    Self.logger.debug("Updated home timeline minId: \(firstStatus.id.prefix(8), privacy: .public)")
                }
            }

            Task {
                await prefetchFediverseCreators(for: statuses)
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.home)
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading home timeline")
            // Token might be expired - verify it
            self.error = err
            // Post notification so UI can handle re-auth
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading home timeline: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingHome = false
    }
    
    func canLoadMoreHomeTimeline() -> Bool {
        homeMaxId != nil
    }
    
    @discardableResult
    func loadMoreHomeTimeline() async -> [Status] {
        guard !isLoadingMore, canLoadMoreHomeTimeline() else { return [] }
        let previousCount = homeTimeline.count
        
        isLoadingMore = true
        await loadHomeTimeline(refresh: false)
        isLoadingMore = false
        
        guard homeTimeline.count > previousCount else { return [] }
        return Array(homeTimeline.dropFirst(previousCount))
    }
    
    func backgroundFetchOlderPosts() async {
        // Continuously fetch older posts in the background
        while canLoadMoreHomeTimeline() && !isLoadingMore {
            let newStatuses = await loadMoreHomeTimeline()
            guard !newStatuses.isEmpty else { break }
            // Small delay to avoid overwhelming the API
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    func refreshHomeTimeline() async {
        homeMaxId = nil
        await loadHomeTimeline(refresh: true)
    }
    
    // MARK: - Explore / Trending
    
    func loadExploreContent() async {
        guard !isLoadingExplore else {
            Self.logger.debug("Explore content load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for explore content load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading explore content")
        isLoadingExplore = true
        error = nil

        let instance = account.instance
        do {
            async let statusesTask = client.getTrendingStatuses(
                instance: instance,
                accessToken: token
            )
            async let linksTask = client.getTrendingLinks(
                instance: instance,
                accessToken: token
            )
            
            let (statuses, links) = try await (statusesTask, linksTask)
            
            exploreStatuses = statuses
            trendingLinks = links
            
            Self.logger.info("Explore content loaded: \(statuses.count) statuses, \(links.count) links")
            
            if let lastStatus = statuses.last {
                exploreMaxId = lastStatus.id
                Self.logger.debug("Updated explore maxId: \(lastStatus.id.prefix(8), privacy: .public)")
            }

            Task {
                await prefetchFediverseCreators(for: statuses)
            }
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading explore content")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading explore content: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingExplore = false
    }
    
    func loadMoreExploreStatuses() async {
        guard !isLoadingMore, exploreMaxId != nil else { return }
        
        guard let account = authService.currentAccount else { return }
        let token = await authService.getAccessToken(for: account)
        
        isLoadingMore = true
        
        do {
            let statuses = try await client.getTrendingStatuses(
                instance: account.instance,
                accessToken: token,
                offset: exploreStatuses.count
            )
            
            exploreStatuses.append(contentsOf: statuses)
            
            if let lastStatus = statuses.last {
                exploreMaxId = lastStatus.id
            }
        } catch {
            self.error = error
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Mentions
    
    func loadMentions(refresh: Bool = false) async {
        guard !isLoadingMentions else {
            Self.logger.debug("Mentions load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for mentions load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading mentions, refresh: \(refresh), current count: \(self.mentions.count), maxId: \(self.mentionsMaxId?.prefix(8) ?? "nil", privacy: .public)")
        isLoadingMentions = true
        error = nil
        
        do {
            let notifications = try await client.getMentions(
                instance: account.instance,
                accessToken: token,
                maxId: refresh ? nil : mentionsMaxId,
                limit: Constants.Pagination.defaultLimit
            )
            
            if refresh {
                mentions = notifications
                Self.logger.info("Mentions refreshed: \(notifications.count) mentions")
            } else {
                mentions.append(contentsOf: notifications)
                Self.logger.info("Mentions loaded more: \(notifications.count) new mentions, total: \(self.mentions.count)")
            }
            
            if let lastMention = notifications.last {
                mentionsMaxId = lastMention.id
                Self.logger.debug("Updated mentions maxId: \(lastMention.id.prefix(8), privacy: .public)")
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.mentions)
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading mentions")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading mentions: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingMentions = false
    }
    
    func loadMoreMentions() async {
        guard !isLoadingMore, mentionsMaxId != nil else { return }
        
        isLoadingMore = true
        await loadMentions(refresh: false)
        isLoadingMore = false
    }
    
    func refreshMentions() async {
        mentionsMaxId = nil
        await loadMentions(refresh: true)
    }
    
    // MARK: - Conversations
    
    func loadConversations(refresh: Bool = false) async {
        guard !isLoadingConversations else {
            Self.logger.debug("Conversations load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for conversations load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading conversations, refresh: \(refresh), current count: \(self.conversations.count), maxId: \(self.conversationsMaxId?.prefix(8) ?? "nil", privacy: .public)")
        isLoadingConversations = true
        error = nil
        
        do {
            let items = try await client.getConversations(
                instance: account.instance,
                accessToken: token,
                maxId: refresh ? nil : conversationsMaxId,
                limit: Constants.Pagination.defaultLimit
            )
            
            if refresh {
                conversations = items
                Self.logger.info("Conversations refreshed: \(items.count) conversations")
            } else {
                conversations.append(contentsOf: items)
                Self.logger.info("Conversations loaded more: \(items.count) new conversations, total: \(self.conversations.count)")
            }
            
            if let lastConversation = items.last {
                conversationsMaxId = lastConversation.id
                Self.logger.debug("Updated conversations maxId: \(lastConversation.id.prefix(8), privacy: .public)")
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.mentions)
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading conversations")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading conversations: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingConversations = false
    }
    
    func loadMoreConversations() async {
        guard !isLoadingMore, conversationsMaxId != nil else { return }
        
        isLoadingMore = true
        await loadConversations(refresh: false)
        isLoadingMore = false
    }
    
    func refreshConversations() async {
        conversationsMaxId = nil
        await loadConversations(refresh: true)
    }
    
    func markConversationAsRead(conversationId: String) async {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for marking conversation as read")
            return
        }
        
        do {
            let updatedConversation = try await client.markConversationAsRead(
                instance: account.instance,
                accessToken: token,
                conversationId: conversationId
            )
            
            // Update the conversation in our local array
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[index] = updatedConversation
                Self.logger.info("Updated conversation \(conversationId.prefix(8), privacy: .public) in local array")
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.mentions)
        } catch {
            Self.logger.error("Error marking conversation as read: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Status Operations
    
    func getStatusContext(for status: Status) async throws -> StatusContext {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let contextWithRefresh = try await client.getStatusContextWithRefresh(
            instance: account.instance,
            accessToken: token,
            id: status.id
        )
        
        let context = contextWithRefresh.context
        
        if let header = contextWithRefresh.asyncRefreshHeader {
            Self.logger.info("Async refresh header present for status \(status.id.prefix(8), privacy: .public), starting polling")
            startAsyncRefreshPolling(status: status, header: header, instance: account.instance, token: token)
        } else if shouldFetchRemoteReplies(context: context, status: status) {
            Self.logger.info("Fetching remote replies for status: \(status.id.prefix(8), privacy: .public)")
            Task { [context] in
                let allReplies = await remoteReplyService.fetchRemoteReplies(for: status)
                let existingIds = Set(context.descendants.map { $0.id })
                var mergedDescendants = context.descendants
                for reply in allReplies {
                    if !existingIds.contains(reply.id) {
                        mergedDescendants.append(reply)
                    }
                }
                mergedDescendants.sort { $0.createdAt < $1.createdAt }
                let updatedContext = StatusContext(
                    ancestors: context.ancestors,
                    descendants: mergedDescendants,
                    hasMoreReplies: context.hasMoreReplies,
                    asyncRefreshId: context.asyncRefreshId
                )
                let payload = StatusContextUpdatePayload(statusId: status.id, context: updatedContext)
                NotificationCenter.default.post(name: .statusContextDidUpdate, object: payload)
            }
        }
        
        return context
    }
    
    /// Re-GETs context for a status, runs async-refresh polling if header present, then updates UI via notification.
    /// Use for "Fetch Remote" and any explicit refresh.
    func refreshContextForStatus(_ status: Status) async throws {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let contextWithRefresh = try await client.getStatusContextWithRefresh(
            instance: account.instance,
            accessToken: token,
            id: status.id
        )
        
        let context = contextWithRefresh.context
        
        if let header = contextWithRefresh.asyncRefreshHeader {
            Self.logger.info("Async refresh header present on refresh for status \(status.id.prefix(8), privacy: .public), starting polling")
            startAsyncRefreshPolling(status: status, header: header, instance: account.instance, token: token)
        } else {
            let payload = StatusContextUpdatePayload(statusId: status.id, context: context)
            NotificationCenter.default.post(name: .statusContextDidUpdate, object: payload)
        }
    }
    
    /// Cancels any active async-refresh polling for the given status. Call when leaving thread or starting a new refresh.
    func cancelAsyncRefreshPolling(forStatusId statusId: String) {
        asyncRefreshPollingTasks[statusId]?.cancel()
        asyncRefreshPollingTasks.removeValue(forKey: statusId)
    }
    
    private func startAsyncRefreshPolling(status: Status, header: AsyncRefreshHeader, instance: String, token: String) {
        asyncRefreshPollingTasks[status.id]?.cancel()
        asyncRefreshPollingTasks.removeValue(forKey: status.id)
        
        let task = Task { [weak self] in
            guard let self else { return }
            var attempts = 0
            let maxAttempts = Constants.RemoteReplies.asyncRefreshMaxPollAttempts
            
            while !Task.isCancelled, attempts < maxAttempts {
                do {
                    let refresh = try await self.client.getAsyncRefresh(instance: instance, accessToken: token, id: header.id)
                    if refresh.status == "finished" {
                        Self.logger.info("Async refresh finished for status \(status.id.prefix(8), privacy: .public)")
                        break
                    }
                } catch let err as FediReaderError {
                    if case .serverError(404, _) = err {
                        Self.logger.debug("Async refresh 404 for id \(header.id.prefix(12), privacy: .public), stopping poll")
                        break
                    }
                    Self.logger.debug("Async refresh poll error: \(err.localizedDescription)")
                } catch {
                    Self.logger.debug("Async refresh poll error: \(error.localizedDescription)")
                }
                
                attempts += 1
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: UInt64(header.retrySeconds) * 1_000_000_000)
            }
            
            if Task.isCancelled { return }
            
            do {
                guard let account = self.authService.currentAccount,
                      let tok = await self.authService.getAccessToken(for: account) else { return }
                let ctxWithRefresh = try await self.client.getStatusContextWithRefresh(
                    instance: account.instance,
                    accessToken: tok,
                    id: status.id
                )
                let payload = StatusContextUpdatePayload(statusId: status.id, context: ctxWithRefresh.context)
                NotificationCenter.default.post(name: .statusContextDidUpdate, object: payload)
            } catch {
                Self.logger.error("Failed to re-fetch context after async refresh: \(error.localizedDescription)")
            }
            
            self.asyncRefreshPollingTasks.removeValue(forKey: status.id)
        }
        
        asyncRefreshPollingTasks[status.id] = task
    }
    
    /// Fetches remote replies for a status and returns updated context
    func fetchRemoteReplies(for status: Status) async throws -> [Status] {
        return await remoteReplyService.fetchRemoteReplies(for: status)
    }
    
    /// Determines if we should fetch remote replies based on context and status
    private func shouldFetchRemoteReplies(context: StatusContext, status: Status) -> Bool {
        // Fetch if we have fewer descendants than expected replies
        if status.repliesCount > context.descendants.count {
            return true
        }
        
        // Fetch if any descendants appear to be remote (different instance)
        if let account = authService.currentAccount {
            let hasRemoteReplies = context.descendants.contains { reply in
                !reply.uri.contains(account.instance)
            }
            if hasRemoteReplies {
                return true
            }
        }
        
        return false
    }
    
    func refreshStatus(id: String) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let updatedStatus = try await client.getStatus(
            instance: account.instance,
            accessToken: token,
            id: id
        )
        
        // Update in local timelines
        updateStatusInTimelines(updatedStatus)
        
        return updatedStatus
    }
    
    // MARK: - Status Actions
    
    func favorite(status: Status) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for favorite action")
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        let isCurrentlyFavorited = targetStatus.favourited == true
        
        Self.logger.info("Toggling favorite for status: \(targetStatus.id.prefix(8), privacy: .public), currently favorited: \(isCurrentlyFavorited)")
        
        let updatedStatus: Status
        if isCurrentlyFavorited {
            updatedStatus = try await client.unfavorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Unfavorited status: \(targetStatus.id.prefix(8), privacy: .public)")
        } else {
            updatedStatus = try await client.favorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Favorited status: \(targetStatus.id.prefix(8), privacy: .public)")
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func setFavorite(status: Status, isFavorited: Bool) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        let updatedStatus: Status = isFavorited
            ? try await client.favorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            : try await client.unfavorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func reblog(status: Status) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for reblog action")
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        let isCurrentlyReblogged = targetStatus.reblogged == true
        
        Self.logger.info("Toggling reblog for status: \(targetStatus.id.prefix(8), privacy: .public), currently reblogged: \(isCurrentlyReblogged)")
        
        let updatedStatus: Status
        if isCurrentlyReblogged {
            updatedStatus = try await client.unreblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Unreblogged status: \(targetStatus.id.prefix(8), privacy: .public)")
        } else {
            updatedStatus = try await client.reblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Reblogged status: \(targetStatus.id.prefix(8), privacy: .public)")
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func setReblog(status: Status, isReblogged: Bool) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        let updatedStatus: Status = isReblogged
            ? try await client.reblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            : try await client.unreblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func bookmark(status: Status) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for bookmark action")
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        let isCurrentlyBookmarked = targetStatus.bookmarked == true
        
        Self.logger.info("Toggling bookmark for status: \(targetStatus.id.prefix(8), privacy: .public), currently bookmarked: \(isCurrentlyBookmarked)")
        
        let updatedStatus: Status
        if isCurrentlyBookmarked {
            updatedStatus = try await client.unbookmark(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Unbookmarked status: \(targetStatus.id.prefix(8), privacy: .public)")
        } else {
            updatedStatus = try await client.bookmark(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
            Self.logger.info("Bookmarked status: \(targetStatus.id.prefix(8), privacy: .public)")
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func reply(to status: Status, content: String) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for reply action")
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        Self.logger.info("Replying to status: \(targetStatus.id.prefix(8), privacy: .public), content length: \(content.count)")
        
        let result = try await client.postStatus(
            instance: account.instance,
            accessToken: token,
            status: content,
            inReplyToId: targetStatus.id,
            visibility: targetStatus.visibility
        )
        
        Self.logger.info("Reply posted successfully: \(result.id.prefix(8), privacy: .public)")
        return result
    }
    
    func quoteBoost(status: Status, content: String) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        // Quote boost support varies by instance
        // Try quote_id parameter first, fall back to including URL
        do {
            return try await client.postStatus(
                instance: account.instance,
                accessToken: token,
                status: content,
                visibility: targetStatus.visibility,
                quoteId: targetStatus.id
            )
        } catch {
            // Fallback: Include the status URL in the content
            let statusURL = targetStatus.url ?? "https://\(account.instance)/@\(targetStatus.account.username)/\(targetStatus.id)"
            let contentWithQuote = "\(content)\n\n\(statusURL)"
            
            return try await client.postStatus(
                instance: account.instance,
                accessToken: token,
                status: contentWithQuote,
                visibility: targetStatus.visibility
            )
        }
    }
    
    // MARK: - Helpers
    
    private func updateStatusInTimelines(_ status: Status) {
        let resolvedStatus = status.displayStatus

        // Update in home timeline
        if let index = homeTimeline.firstIndex(where: { $0.displayStatus.id == resolvedStatus.id }) {
            if homeTimeline[index].reblog != nil {
                homeTimeline[index] = updatedReblogWrapper(from: homeTimeline[index], with: resolvedStatus)
            } else {
                homeTimeline[index] = resolvedStatus
            }
        }
        
        // Update in explore
        if let index = exploreStatuses.firstIndex(where: { $0.displayStatus.id == resolvedStatus.id }) {
            if exploreStatuses[index].reblog != nil {
                exploreStatuses[index] = updatedReblogWrapper(from: exploreStatuses[index], with: resolvedStatus)
            } else {
                exploreStatuses[index] = resolvedStatus
            }
        }
        
        // Update in mentions
        if mentions.contains(where: { $0.status?.id == status.id }) {
            // Notifications are immutable, so we can't easily update them
            // The UI should handle this via the notification
        }
    }

    private func updatedReblogWrapper(from status: Status, with resolvedStatus: Status) -> Status {
        Status(
            id: status.id,
            uri: status.uri,
            url: status.url,
            createdAt: status.createdAt,
            account: status.account,
            content: status.content,
            visibility: status.visibility,
            sensitive: status.sensitive,
            spoilerText: status.spoilerText,
            mediaAttachments: status.mediaAttachments,
            mentions: status.mentions,
            tags: status.tags,
            emojis: status.emojis,
            reblogsCount: status.reblogsCount,
            favouritesCount: status.favouritesCount,
            repliesCount: status.repliesCount,
            application: status.application,
            language: status.language,
            reblog: IndirectStatus(resolvedStatus),
            card: status.card,
            poll: status.poll,
            quote: status.quote,
            favourited: status.favourited,
            reblogged: status.reblogged,
            muted: status.muted,
            bookmarked: status.bookmarked,
            pinned: status.pinned,
            inReplyToId: status.inReplyToId,
            inReplyToAccountId: status.inReplyToAccountId
        )
    }

    private func prefetchFediverseCreators(for statuses: [Status]) async {
        guard !statuses.isEmpty else { return }
        let urls: [URL] = statuses.compactMap { status -> URL? in
            guard let card = status.displayStatus.card,
                  (card.type == .link || card.type == .rich),
                  let url = card.linkURL else {
                return nil
            }
            return url
        }
        guard !urls.isEmpty else { return }
        await LinkPreviewService.shared.prefetchFediverseCreators(for: urls)
    }
    
    func clearAllTimelines() {
        homeTimeline = []
        exploreStatuses = []
        trendingLinks = []
        mentions = []
        conversations = []
        listTimeline = []
        listAccounts = []
        
        homeMaxId = nil
        homeMinId = nil
        exploreMaxId = nil
        mentionsMaxId = nil
        conversationsMaxId = nil
        listTimelineMaxId = nil
        listAccountsMaxId = nil
    }
    
    // MARK: - Lists
    
    func loadLists(forceRefresh: Bool = false) async {
        guard !isLoadingLists else {
            Self.logger.debug("Lists load already in progress, skipping")
            return
        }

        guard let account = authService.currentAccount else {
            Self.logger.error("No active account for lists load")
            error = FediReaderError.noActiveAccount
            return
        }

        if !forceRefresh,
           !lists.isEmpty,
           listsLastRefreshedForAccountId == account.id,
           let lastRefresh = listsLastRefreshedAt {
            let age = Date().timeIntervalSince(lastRefresh)
            if age < Constants.Cache.listsRefreshInterval {
                Self.logger.debug("Skipping lists refresh (age: \(Int(age), privacy: .public)s)")
                return
            }
        }

        guard let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("Missing access token for lists load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading lists")
        isLoadingLists = true
        error = nil
        
        do {
            let fetchedLists = try await client.getLists(instance: account.instance, accessToken: token)
            if fetchedLists != lists {
                lists = fetchedLists
                Self.logger.info("Lists updated: \(self.lists.count) lists")
            } else {
                Self.logger.debug("Lists unchanged (\(self.lists.count) lists)")
            }
            listsLastRefreshedAt = Date()
            listsLastRefreshedForAccountId = account.id
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading lists")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading lists: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingLists = false
    }
    
    func loadListTimeline(listId: String, refresh: Bool = false) async {
        guard !isLoadingListTimeline else {
            Self.logger.debug("List timeline load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for list timeline load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading list timeline \(listId.prefix(8), privacy: .public), refresh: \(refresh), current count: \(self.listTimeline.count), maxId: \(self.listTimelineMaxId?.prefix(8) ?? "nil", privacy: .public)")
        isLoadingListTimeline = true
        error = nil
        
        do {
            let statuses = try await client.getListTimeline(
                instance: account.instance,
                accessToken: token,
                listId: listId,
                maxId: refresh ? nil : listTimelineMaxId,
                limit: Constants.Pagination.defaultLimit
            )
            
            if refresh {
                listTimeline = statuses
                Self.logger.info("List timeline refreshed: \(statuses.count) statuses")
            } else {
                listTimeline.append(contentsOf: statuses)
                Self.logger.info("List timeline loaded more: \(statuses.count) new statuses, total: \(self.listTimeline.count)")
            }
            
            if statuses.isEmpty {
                listTimelineMaxId = nil
                Self.logger.debug("List timeline returned no statuses; reached pagination end")
            } else if let lastStatus = statuses.last {
                listTimelineMaxId = lastStatus.id
                Self.logger.debug("Updated list timeline maxId: \(lastStatus.id.prefix(8), privacy: .public)")
            }
            
            Task {
                await prefetchFediverseCreators(for: statuses)
            }
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading list timeline")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading list timeline: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingListTimeline = false
    }
    
    func canLoadMoreListTimeline() -> Bool {
        listTimelineMaxId != nil
    }
    
    @discardableResult
    func loadMoreListTimeline(listId: String) async -> [Status] {
        guard !isLoadingMore, canLoadMoreListTimeline() else { return [] }
        let previousCount = listTimeline.count
        
        isLoadingMore = true
        await loadListTimeline(listId: listId, refresh: false)
        isLoadingMore = false
        
        guard listTimeline.count > previousCount else { return [] }
        return Array(listTimeline.dropFirst(previousCount))
    }
    
    func refreshListTimeline(listId: String) async {
        listTimelineMaxId = nil
        await loadListTimeline(listId: listId, refresh: true)
    }
    
    func loadListAccounts(listId: String, refresh: Bool = false) async {
        guard !isLoadingListAccounts else {
            Self.logger.debug("List accounts load already in progress, skipping")
            return
        }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            Self.logger.error("No active account for list accounts load")
            error = FediReaderError.noActiveAccount
            return
        }
        
        Self.logger.info("Loading list accounts for list \(listId.prefix(8), privacy: .public), refresh: \(refresh), current count: \(self.listAccounts.count), maxId: \(self.listAccountsMaxId?.prefix(8) ?? "nil", privacy: .public)")
        isLoadingListAccounts = true
        error = nil
        
        do {
            let accounts = try await client.getListAccounts(
                instance: account.instance,
                accessToken: token,
                listId: listId,
                maxId: refresh ? nil : listAccountsMaxId,
                limit: Constants.Pagination.defaultLimit
            )
            
            if refresh {
                listAccounts = accounts
                Self.logger.info("List accounts refreshed: \(accounts.count) accounts")
            } else {
                listAccounts.append(contentsOf: accounts)
                Self.logger.info("List accounts loaded more: \(accounts.count) new accounts, total: \(self.listAccounts.count)")
            }
            
            if let lastAccount = accounts.last {
                listAccountsMaxId = lastAccount.id
                Self.logger.debug("Updated list accounts maxId: \(lastAccount.id.prefix(8), privacy: .public)")
            }
        } catch let err as FediReaderError where err == .unauthorized {
            Self.logger.error("Unauthorized error loading list accounts")
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            Self.logger.error("Error loading list accounts: \(error.localizedDescription)")
            self.error = error
        }
        
        isLoadingListAccounts = false
    }
    
    func loadMoreListAccounts(listId: String) async {
        guard !isLoadingMore, listAccountsMaxId != nil else { return }
        
        isLoadingMore = true
        await loadListAccounts(listId: listId, refresh: false)
        isLoadingMore = false
    }
    
    func refreshListAccounts(listId: String) async {
        listAccountsMaxId = nil
        await loadListAccounts(listId: listId, refresh: true)
    }
    
    func clearListTimeline() {
        listTimeline = []
        listAccounts = []
        listTimelineMaxId = nil
        listAccountsMaxId = nil
    }
    
    /// Fetch list timeline statuses without affecting service state (for prefetching)
    func fetchListTimelineStatuses(listId: String) async -> [Status] {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            return []
        }
        
        do {
            return try await client.getListTimeline(
                instance: account.instance,
                accessToken: token,
                listId: listId,
                limit: Constants.Pagination.defaultLimit
            )
        } catch {
            return []
        }
    }
}

// MARK: - Caching Extension

extension TimelineService {
    func cacheStatuses(_ statuses: [Status], accountId: String, type: TimelineType, modelContext: ModelContext) {
        for status in statuses {
            if let cached = CachedStatus.from(status: status, accountId: accountId, timelineType: type.rawValue) {
                modelContext.insert(cached)
            }
        }
        
        try? modelContext.save()
    }
    
    func loadCachedStatuses(accountId: String, type: TimelineType, modelContext: ModelContext) -> [Status] {
        let typeRawValue = type.rawValue
        let descriptor = FetchDescriptor<CachedStatus>(
            predicate: #Predicate { cached in
                cached.accountId == accountId && cached.timelineType == typeRawValue
            },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        
        guard let cached = try? modelContext.fetch(descriptor) else {
            return []
        }
        
        return cached.compactMap { $0.status }
    }
    
    func clearOldCache(olderThan date: Date, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CachedStatus>(
            predicate: #Predicate { cached in
                cached.fetchedAt < date
            }
        )
        
        guard let oldCached = try? modelContext.fetch(descriptor) else {
            return
        }
        
        for cached in oldCached {
            modelContext.delete(cached)
        }
        
        try? modelContext.save()
    }
}

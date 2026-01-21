//
//  TimelineService.swift
//  fedi-reader
//
//  Timeline fetching and pagination management
//

import Foundation
import SwiftData

@Observable
@MainActor
final class TimelineService {
    private let client: MastodonClient
    private let authService: AuthService
    
    // Timeline state
    var homeTimeline: [Status] = []
    var exploreStatuses: [Status] = []
    var trendingLinks: [TrendingLink] = []
    var mentions: [MastodonNotification] = []
    
    // Loading state
    var isLoadingHome = false
    var isLoadingExplore = false
    var isLoadingMentions = false
    var isLoadingMore = false
    
    // Pagination cursors
    private var homeMaxId: String?
    private var homeMinId: String?
    private var exploreMaxId: String?
    private var mentionsMaxId: String?
    
    // Error state
    var error: Error?
    
    init(client: MastodonClient, authService: AuthService) {
        self.client = client
        self.authService = authService
    }
    
    // MARK: - Home Timeline
    
    func loadHomeTimeline(refresh: Bool = false) async {
        guard !isLoadingHome else { return }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            error = FediReaderError.noActiveAccount
            return
        }
        
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
            } else {
                homeTimeline.append(contentsOf: statuses)
            }
            
            // Update pagination cursor
            if let lastStatus = statuses.last {
                homeMaxId = lastStatus.id
            }
            if let firstStatus = statuses.first, refresh {
                homeMinId = firstStatus.id
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.home)
        } catch let err as FediReaderError where err == .unauthorized {
            // Token might be expired - verify it
            self.error = err
            // Post notification so UI can handle re-auth
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
            self.error = error
        }
        
        isLoadingHome = false
    }
    
    func loadMoreHomeTimeline() async {
        guard !isLoadingMore, homeMaxId != nil else { return }
        
        isLoadingMore = true
        await loadHomeTimeline(refresh: false)
        isLoadingMore = false
    }
    
    func backgroundFetchOlderPosts() async {
        // Continuously fetch older posts in the background
        while homeMaxId != nil && !isLoadingMore {
            await loadMoreHomeTimeline()
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
        guard !isLoadingExplore else { return }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            error = FediReaderError.noActiveAccount
            return
        }
        
        isLoadingExplore = true
        error = nil
        
        do {
            // Load trending statuses and links in parallel
            async let statusesTask = client.getTrendingStatuses(
                instance: account.instance,
                accessToken: token
            )
            async let linksTask = client.getTrendingLinks(
                instance: account.instance,
                accessToken: token
            )
            
            let (statuses, links) = try await (statusesTask, linksTask)
            
            exploreStatuses = statuses
            trendingLinks = links
            
            if let lastStatus = statuses.last {
                exploreMaxId = lastStatus.id
            }
        } catch let err as FediReaderError where err == .unauthorized {
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
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
        guard !isLoadingMentions else { return }
        
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            error = FediReaderError.noActiveAccount
            return
        }
        
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
            } else {
                mentions.append(contentsOf: notifications)
            }
            
            if let lastMention = notifications.last {
                mentionsMaxId = lastMention.id
            }
            
            NotificationCenter.default.post(name: .timelineDidRefresh, object: TimelineType.mentions)
        } catch let err as FediReaderError where err == .unauthorized {
            self.error = err
            NotificationCenter.default.post(name: .accountDidChange, object: nil)
        } catch {
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
    
    // MARK: - Status Operations
    
    func getStatusContext(for status: Status) async throws -> StatusContext {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        return try await client.getStatusContext(
            instance: account.instance,
            accessToken: token,
            id: status.id
        )
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
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        let updatedStatus: Status
        if targetStatus.favourited == true {
            updatedStatus = try await client.unfavorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        } else {
            updatedStatus = try await client.favorite(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func reblog(status: Status) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        let updatedStatus: Status
        if targetStatus.reblogged == true {
            updatedStatus = try await client.unreblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        } else {
            updatedStatus = try await client.reblog(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func bookmark(status: Status) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        let updatedStatus: Status
        if targetStatus.bookmarked == true {
            updatedStatus = try await client.unbookmark(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        } else {
            updatedStatus = try await client.bookmark(
                instance: account.instance,
                accessToken: token,
                statusId: targetStatus.id
            )
        }
        
        updateStatusInTimelines(updatedStatus)
        NotificationCenter.default.post(name: .statusDidUpdate, object: updatedStatus)
        
        return updatedStatus
    }
    
    func reply(to status: Status, content: String) async throws -> Status {
        guard let account = authService.currentAccount,
              let token = await authService.getAccessToken(for: account) else {
            throw FediReaderError.noActiveAccount
        }
        
        let targetStatus = status.displayStatus
        
        return try await client.postStatus(
            instance: account.instance,
            accessToken: token,
            status: content,
            inReplyToId: targetStatus.id,
            visibility: targetStatus.visibility
        )
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
        // Update in home timeline
        if let index = homeTimeline.firstIndex(where: { $0.id == status.id || $0.reblog?.value.id == status.id }) {
            if homeTimeline[index].reblog != nil {
                // This was a reblog, update the inner status
                // Note: Due to immutability, we need to create a new reblog
                // For simplicity, we'll just replace with the updated status
            }
            homeTimeline[index] = status
        }
        
        // Update in explore
        if let index = exploreStatuses.firstIndex(where: { $0.id == status.id }) {
            exploreStatuses[index] = status
        }
        
        // Update in mentions
        if let index = mentions.firstIndex(where: { $0.status?.id == status.id }) {
            // Notifications are immutable, so we can't easily update them
            // The UI should handle this via the notification
        }
    }
    
    func clearAllTimelines() {
        homeTimeline = []
        exploreStatuses = []
        trendingLinks = []
        mentions = []
        
        homeMaxId = nil
        homeMinId = nil
        exploreMaxId = nil
        mentionsMaxId = nil
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

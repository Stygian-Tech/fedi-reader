//
//  LinkFilterService.swift
//  fedi-reader
//
//  Filter timeline posts to only those containing links
//

import Foundation
import os

@Observable
@MainActor
final class LinkFilterService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "LinkFilterService")
    
    private let attributionChecker: AttributionChecker
    
    // Per-feed cached link statuses (feedId -> linkStatuses)
    // "home" key for home timeline, list ID for lists
    private var feedCache: [String: [LinkStatus]] = [:]
    
    // Currently active feed ID
    var activeFeedId: String = "home"
    
    // Filtered statuses with link content for the active feed
    var linkStatuses: [LinkStatus] {
        get { feedCache[activeFeedId] ?? [] }
        set { feedCache[activeFeedId] = newValue }
    }
    
    // Loading state per feed
    private var loadingFeeds: Set<String> = []
    var isLoading: Bool {
        loadingFeeds.contains(activeFeedId)
    }
    var isLoadingAttributions = false
    
    init(attributionChecker: AttributionChecker? = nil) {
        self.attributionChecker = attributionChecker ?? AttributionChecker()
    }
    
    // MARK: - Feed Management
    
    /// Switch to a different feed
    func switchToFeed(_ feedId: String) {
        let previousFeedId = activeFeedId
        activeFeedId = feedId
        Self.logger.info("Switched feed from '\(previousFeedId, privacy: .public)' to '\(feedId, privacy: .public)', cached items: \(self.getCachedContent(for: feedId).count)")
    }
    
    /// Check if feed has cached content
    func hasCachedContent(for feedId: String) -> Bool {
        guard let cached = feedCache[feedId] else { return false }
        return !cached.isEmpty
    }
    
    /// Get cached content for a specific feed
    func getCachedContent(for feedId: String) -> [LinkStatus] {
        feedCache[feedId] ?? []
    }
    
    /// Check if a feed is currently loading
    func isLoadingFeed(_ feedId: String) -> Bool {
        loadingFeeds.contains(feedId)
    }
    
    // MARK: - Filtering
    
    /// Filters statuses to only those with external links (excluding quote posts)
    func filterToLinks(_ statuses: [Status]) -> [Status] {
        Self.logger.debug("Filtering \(statuses.count) statuses to links only")
        let filtered = statuses.filter { status in
            let targetStatus = status.displayStatus
            
            // Exclude quote posts
            if targetStatus.isQuotePost {
                return false
            }
            
            // Check for link card
            if targetStatus.hasLinkCard {
                return true
            }
            
            // Check for links in content
            let links = extractExternalLinks(from: targetStatus)
            return !links.isEmpty
        }
        Self.logger.debug("Filtered to \(filtered.count) link statuses (\(filtered.count * 100 / max(statuses.count, 1))%)")
        return filtered
    }
    
    /// Processes statuses into LinkStatus objects for a specific feed
    func processStatuses(_ statuses: [Status], for feedId: String) async -> [LinkStatus] {
        Self.logger.info("Processing \(statuses.count) statuses for feed '\(feedId, privacy: .public)'")
        loadingFeeds.insert(feedId)
        defer { loadingFeeds.remove(feedId) }
        
        let filtered = filterToLinks(statuses)
        
        var linkStatuses: [LinkStatus] = []
        var cardCount = 0
        var contentLinkCount = 0
        
        for status in filtered {
            let targetStatus = status.displayStatus
            
            // Get primary link (prefer card URL)
            let primaryURL: URL?
            let title: String?
            let description: String?
            let imageURL: URL?
            let providerName: String?
            
            if let card = targetStatus.card, card.type == .link {
                primaryURL = card.linkURL
                title = card.title.isEmpty ? nil : card.title
                description = card.description.isEmpty ? nil : card.description
                imageURL = card.imageURL
                providerName = card.providerName
                cardCount += 1
            } else {
                // Extract from content
                let links = extractExternalLinks(from: targetStatus)
                primaryURL = links.first
                title = nil
                description = nil
                imageURL = nil
                providerName = primaryURL.flatMap { HTMLParser.extractDomain(from: $0) }
                contentLinkCount += 1
            }
            
            guard let url = primaryURL else { continue }
            guard !isThreadsOrInstagramURL(url) else { continue }
            
            let linkStatus = LinkStatus(
                status: status,
                primaryURL: url,
                title: title,
                description: description,
                imageURL: imageURL,
                providerName: providerName,
                authorAttribution: targetStatus.card?.authorName,
                authorURL: targetStatus.card?.authorUrl
            )
            
            linkStatuses.append(linkStatus)
        }
        
        feedCache[feedId] = linkStatuses
        Self.logger.info("Processed feed '\(feedId, privacy: .public)': \(linkStatuses.count) link statuses (\(cardCount) from cards, \(contentLinkCount) from content)")
        return linkStatuses
    }
    
    /// Processes statuses into LinkStatus objects (uses active feed)
    func processStatuses(_ statuses: [Status]) async -> [LinkStatus] {
        await processStatuses(statuses, for: activeFeedId)
    }
    
    /// Enriches link statuses with author attribution from HEAD requests
    func enrichWithAttributions() async {
        guard !linkStatuses.isEmpty else {
            Self.logger.debug("No link statuses to enrich with attributions")
            return
        }
        
        // Check for statuses that need attribution (no attribution at all) OR missing Mastodon attribution
        // This ensures we always check for Mastodon attribution even if authorName exists from card
        let statusesNeedingAttribution = linkStatuses.enumerated().compactMap { (index, linkStatus) -> (Int, LinkStatus)? in
            // Need attribution if: no attribution at all, OR has attribution but missing Mastodon fields
            let needsAttribution = linkStatus.authorAttribution == nil
            let needsMastodonCheck = linkStatus.mastodonHandle == nil && linkStatus.mastodonProfileURL == nil
            
            if needsAttribution || needsMastodonCheck {
                return (index, linkStatus)
            }
            return nil
        }
        
        guard !statusesNeedingAttribution.isEmpty else {
            Self.logger.debug("All link statuses already have full attribution")
            return
        }
        
        Self.logger.info("Enriching \(statusesNeedingAttribution.count) link statuses with attributions (batch size: 5)")
        isLoadingAttributions = true
        defer { isLoadingAttributions = false }
        
        // Process attributions in batches to avoid overwhelming the network
        let batchSize = 5
        let currentFeedId = activeFeedId
        var attributionCount = 0
        
        for batchStart in stride(from: 0, to: statusesNeedingAttribution.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, statusesNeedingAttribution.count)
            let batch = Array(statusesNeedingAttribution[batchStart..<batchEnd])
            
            await withTaskGroup(of: ((Int, Int), AuthorAttribution?).self) { group in
                for (batchIndex, (originalIndex, linkStatus)) in batch.enumerated() {
                    group.addTask {
                        let attribution = await self.attributionChecker.checkAttribution(for: linkStatus.primaryURL)
                        return ((batchStart + batchIndex, originalIndex), attribution)
                    }
                }
                
                for await ((_, originalIndex), attribution) in group {
                    if let attribution,
                       var cached = feedCache[currentFeedId],
                       originalIndex < cached.count {
                        // Create updated LinkStatus with all attribution fields
                        let existing = cached[originalIndex]
                        let updated = LinkStatus(
                            status: existing.status,
                            primaryURL: existing.primaryURL,
                            title: existing.title,
                            description: existing.description,
                            imageURL: existing.imageURL,
                            providerName: existing.providerName,
                            // Preserve existing authorAttribution if it exists, otherwise use new one
                            authorAttribution: existing.authorAttribution ?? attribution.name,
                            // Update URL if we got a better one
                            authorURL: attribution.url ?? existing.authorURL,
                            authorProfilePictureURL: attribution.profilePictureURL ?? existing.authorProfilePictureURL,
                            // Always update Mastodon fields if found
                            mastodonHandle: attribution.mastodonHandle ?? existing.mastodonHandle,
                            mastodonProfileURL: attribution.mastodonProfileURL ?? existing.mastodonProfileURL
                        )
                        cached[originalIndex] = updated
                        feedCache[currentFeedId] = cached
                        attributionCount += 1
                    }
                }
            }
        }
        
        Self.logger.info("Attribution enrichment complete: \(attributionCount) attributions found")
    }
    
    /// Pre-fetch content for adjacent feeds (call in background)
    func prefetchAdjacentFeeds(
        currentFeedId: String,
        allFeedIds: [String],
        loadContent: @escaping (String) async -> [Status]
    ) async {
        guard let currentIndex = allFeedIds.firstIndex(of: currentFeedId) else {
            Self.logger.debug("Current feed ID not found in all feed IDs, skipping prefetch")
            return
        }
        
        // Get adjacent feed IDs (previous and next)
        var adjacentIds: [String] = []
        if currentIndex > 0 {
            adjacentIds.append(allFeedIds[currentIndex - 1])
        }
        if currentIndex < allFeedIds.count - 1 {
            adjacentIds.append(allFeedIds[currentIndex + 1])
        }
        
        Self.logger.debug("Prefetching adjacent feeds: \(adjacentIds.map { $0 }, privacy: .public)")
        
        // Prefetch feeds that don't have cached content
        for feedId in adjacentIds {
            if !hasCachedContent(for: feedId) && !isLoadingFeed(feedId) {
                Self.logger.debug("Prefetching feed '\(feedId, privacy: .public)'")
                let statuses = await loadContent(feedId)
                _ = await processStatuses(statuses, for: feedId)
            } else {
                Self.logger.debug("Skipping prefetch for feed '\(feedId, privacy: .public)' (has cache: \(self.hasCachedContent(for: feedId)), loading: \(self.isLoadingFeed(feedId)))")
            }
        }
    }
    
    // MARK: - Link Extraction
    
    /// Returns true if the URL points to Threads or Instagram (social posts, not articles).
    private func isThreadsOrInstagramURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if host == "threads.net" || host == "www.threads.net" || host.hasSuffix(".threads.net") { return true }
        if host == "threads.com" || host == "www.threads.com" || host.hasSuffix(".threads.com") { return true }
        if host == "instagram.com" || host == "www.instagram.com" || host.hasSuffix(".instagram.com") { return true }
        return false
    }
    
    /// Extracts external links from a status
    func extractExternalLinks(from status: Status) -> [URL] {
        // Get the instance domain to exclude internal links
        var excludeDomains: [String] = []
        if let host = URL(string: status.uri)?.host {
            excludeDomains.append(host)
        }
        
        // Also exclude common Mastodon instances for mentions
        excludeDomains.append(contentsOf: ["mastodon.social", "mastodon.online"])
        
        return HTMLParser.extractExternalLinks(from: status.content, excludingDomains: excludeDomains)
    }
    
    /// Checks if a status is a quote post
    func isQuotePost(_ status: Status) -> Bool {
        let targetStatus = status.displayStatus
        
        // Direct quote indicator
        if targetStatus.quote != nil {
            return true
        }
        
        // Check for quote patterns in content
        // Some instances embed quote URLs in a specific format
        let content = targetStatus.content.lowercased()
        
        // Pattern: Contains a status URL from the same instance
        if let statusURL = targetStatus.url,
           let host = URL(string: statusURL)?.host {
            let quotePattern = "https://\(host)/@"
            if content.contains(quotePattern) && content.contains("/status") {
                return true
            }
        }
        
        // Pattern: RE: or QT: prefix (common conventions)
        let plainText = HTMLParser.stripHTML(targetStatus.content)
        if plainText.hasPrefix("RE:") || plainText.hasPrefix("QT:") {
            return true
        }
        
        return false
    }
    
    // MARK: - Filtering Options
    
    /// Filters link statuses by domain
    func filterByDomain(_ domain: String) -> [LinkStatus] {
        linkStatuses.filter { linkStatus in
            guard let host = linkStatus.primaryURL.host?.lowercased() else { return false }
            return host.contains(domain.lowercased())
        }
    }
    
    /// Filters link statuses by author account ID. Returns all when `accountId` is nil.
    func filter(linkStatuses: [LinkStatus], byAccountId accountId: String?) -> [LinkStatus] {
        guard let accountId = accountId else { return linkStatuses }
        return linkStatuses.filter { $0.status.displayStatus.account.id == accountId }
    }
    
    /// Filters link statuses that have images
    func filterWithImages() -> [LinkStatus] {
        linkStatuses.filter { $0.imageURL != nil }
    }
    
    /// Groups link statuses by domain
    func groupByDomain() -> [String: [LinkStatus]] {
        Dictionary(grouping: linkStatuses) { linkStatus in
            HTMLParser.extractDomain(from: linkStatus.primaryURL) ?? "unknown"
        }
    }
    
    /// Returns unique domains from current link statuses
    func uniqueDomains() -> [String] {
        let domains = linkStatuses.compactMap { HTMLParser.extractDomain(from: $0.primaryURL) }
        return Array(Set(domains)).sorted()
    }
    
    // MARK: - Clear
    
    func clear() {
        let count = linkStatuses.count
        linkStatuses = []
        Self.logger.info("Cleared link statuses: \(count) items removed")
    }
}

// MARK: - Link Status Model

struct LinkStatus: Identifiable, Hashable {
    let id: String
    let status: Status
    let primaryURL: URL
    var title: String?
    var description: String?
    var imageURL: URL?
    var providerName: String?
    var authorAttribution: String?
    var authorURL: String?
    var authorProfilePictureURL: String?
    var mastodonHandle: String?
    var mastodonProfileURL: String?
    
    init(
        status: Status,
        primaryURL: URL,
        title: String? = nil,
        description: String? = nil,
        imageURL: URL? = nil,
        providerName: String? = nil,
        authorAttribution: String? = nil,
        authorURL: String? = nil,
        authorProfilePictureURL: String? = nil,
        mastodonHandle: String? = nil,
        mastodonProfileURL: String? = nil
    ) {
        self.id = status.id
        self.status = status
        self.primaryURL = primaryURL
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.providerName = providerName
        self.authorAttribution = authorAttribution
        self.authorURL = authorURL
        self.authorProfilePictureURL = authorProfilePictureURL
        self.mastodonHandle = mastodonHandle
        self.mastodonProfileURL = mastodonProfileURL
    }
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LinkStatus, rhs: LinkStatus) -> Bool {
        lhs.id == rhs.id
    }
    
    // Computed properties
    var displayTitle: String {
        title ?? primaryURL.host ?? "Link"
    }
    
    var displayDescription: String? {
        description ?? status.displayStatus.content.htmlStripped
    }
    
    var domain: String {
        HTMLParser.extractDomain(from: primaryURL) ?? primaryURL.host ?? "unknown"
    }
    
    var hasImage: Bool {
        imageURL != nil
    }
    
    var displayAuthor: String? {
        authorAttribution ?? providerName
    }
}

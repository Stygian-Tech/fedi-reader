//
//  LinkFilterService.swift
//  fedi-reader
//
//  Filter timeline posts to only those containing links
//

import Foundation

@Observable
@MainActor
final class LinkFilterService {
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
        activeFeedId = feedId
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
        statuses.filter { status in
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
    }
    
    /// Processes statuses into LinkStatus objects for a specific feed
    func processStatuses(_ statuses: [Status], for feedId: String) async -> [LinkStatus] {
        loadingFeeds.insert(feedId)
        defer { loadingFeeds.remove(feedId) }
        
        let filtered = filterToLinks(statuses)
        
        var linkStatuses: [LinkStatus] = []
        
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
            } else {
                // Extract from content
                let links = extractExternalLinks(from: targetStatus)
                primaryURL = links.first
                title = nil
                description = nil
                imageURL = nil
                providerName = primaryURL.flatMap { HTMLParser.extractDomain(from: $0) }
            }
            
            guard let url = primaryURL else { continue }
            
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
        return linkStatuses
    }
    
    /// Processes statuses into LinkStatus objects (uses active feed)
    func processStatuses(_ statuses: [Status]) async -> [LinkStatus] {
        await processStatuses(statuses, for: activeFeedId)
    }
    
    /// Enriches link statuses with author attribution from HEAD requests
    func enrichWithAttributions() async {
        guard !linkStatuses.isEmpty else { return }
        
        isLoadingAttributions = true
        defer { isLoadingAttributions = false }
        
        // Process attributions in batches to avoid overwhelming the network
        let batchSize = 5
        let currentFeedId = activeFeedId
        
        for batchStart in stride(from: 0, to: linkStatuses.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, linkStatuses.count)
            let batch = Array(linkStatuses[batchStart..<batchEnd])
            
            await withTaskGroup(of: (Int, AuthorAttribution?).self) { group in
                for (index, linkStatus) in batch.enumerated() {
                    // Skip if already has attribution
                    if linkStatus.authorAttribution != nil { continue }
                    
                    let globalIndex = batchStart + index
                    
                    group.addTask {
                        let attribution = await self.attributionChecker.checkAttribution(for: linkStatus.primaryURL)
                        return (globalIndex, attribution)
                    }
                }
                
                for await (index, attribution) in group {
                    if let attribution,
                       var cached = feedCache[currentFeedId],
                       index < cached.count {
                        cached[index].authorAttribution = attribution.name
                        cached[index].authorURL = attribution.url
                        feedCache[currentFeedId] = cached
                    }
                }
            }
        }
    }
    
    /// Pre-fetch content for adjacent feeds (call in background)
    func prefetchAdjacentFeeds(
        currentFeedId: String,
        allFeedIds: [String],
        loadContent: @escaping (String) async -> [Status]
    ) async {
        guard let currentIndex = allFeedIds.firstIndex(of: currentFeedId) else { return }
        
        // Get adjacent feed IDs (previous and next)
        var adjacentIds: [String] = []
        if currentIndex > 0 {
            adjacentIds.append(allFeedIds[currentIndex - 1])
        }
        if currentIndex < allFeedIds.count - 1 {
            adjacentIds.append(allFeedIds[currentIndex + 1])
        }
        
        // Prefetch feeds that don't have cached content
        for feedId in adjacentIds {
            if !hasCachedContent(for: feedId) && !isLoadingFeed(feedId) {
                let statuses = await loadContent(feedId)
                _ = await processStatuses(statuses, for: feedId)
            }
        }
    }
    
    // MARK: - Link Extraction
    
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
        linkStatuses = []
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
    
    init(
        status: Status,
        primaryURL: URL,
        title: String? = nil,
        description: String? = nil,
        imageURL: URL? = nil,
        providerName: String? = nil,
        authorAttribution: String? = nil,
        authorURL: String? = nil
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

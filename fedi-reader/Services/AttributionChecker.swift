//
//  AttributionChecker.swift
//  fedi-reader
//
//  Checks for author attribution via HEAD requests and HTML parsing
//

import Foundation
import os

@Observable
@MainActor
final class AttributionChecker {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "AttributionChecker")
    
    private let session: URLSession
    
    // Cache for attribution results
    private var cache: [URL: AuthorAttribution] = [:]
    private let cacheLimit = 500
    
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": Constants.userAgent
        ]
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Checks for author attribution for a given URL
    /// First tries HEAD request for headers, then fetches partial HTML for meta tags
    func checkAttribution(for url: URL) async -> AuthorAttribution? {
        // Check cache first
        if let cached = cache[url] {
            Self.logger.debug("Cache hit for attribution: \(url.absoluteString, privacy: .public), name: \(cached.name ?? "nil", privacy: .public)")
            return cached
        }
        
        Self.logger.debug("Checking attribution for: \(url.absoluteString, privacy: .public)")
        
        // Try HEAD request first (faster, checks headers)
        if let attribution = await checkHeaderAttribution(for: url) {
            Self.logger.info("Attribution found via HEAD: \(url.absoluteString, privacy: .public), name: \(attribution.name ?? "nil", privacy: .public), source: \(attribution.source.rawValue, privacy: .public)")
            cacheResult(attribution, for: url)
            return attribution
        }
        
        // Fall back to fetching HTML meta tags
        if let attribution = await checkMetaAttribution(for: url) {
            Self.logger.info("Attribution found via meta tags: \(url.absoluteString, privacy: .public), name: \(attribution.name ?? "nil", privacy: .public), source: \(attribution.source.rawValue, privacy: .public)")
            cacheResult(attribution, for: url)
            return attribution
        }
        
        Self.logger.debug("No attribution found for: \(url.absoluteString, privacy: .public)")
        return nil
    }
    
    /// Batch check attributions for multiple URLs
    func checkAttributions(for urls: [URL]) async -> [URL: AuthorAttribution] {
        let uniqueURLs = Array(Set(urls))
        Self.logger.info("Batch checking attributions for \(uniqueURLs.count) URLs")
        var results: [URL: AuthorAttribution] = [:]
        
        await withTaskGroup(of: (URL, AuthorAttribution?).self) { group in
            for url in uniqueURLs {
                group.addTask {
                    let attribution = await self.checkAttribution(for: url)
                    return (url, attribution)
                }
            }
            
            for await (url, attribution) in group {
                if let attribution {
                    results[url] = attribution
                }
            }
        }
        
        Self.logger.info("Batch attribution check complete: \(results.count) attributions found from \(uniqueURLs.count) URLs")
        return results
    }
    
    // MARK: - HEAD Request Attribution
    
    private func checkHeaderAttribution(for url: URL) async -> AuthorAttribution? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                Self.logger.debug("Invalid HTTP response for HEAD request: \(url.absoluteString, privacy: .public)")
                return nil
            }
            
            let statusCode = httpResponse.statusCode
            Self.logger.debug("HEAD request for attribution: \(url.absoluteString, privacy: .public) -> \(statusCode)")
            
            // Check Link header for author relation
            if let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") {
                if let attribution = parseLinkHeader(linkHeader) {
                    Self.logger.debug("Found attribution in Link header: \(url.absoluteString, privacy: .public)")
                    return attribution
                }
            }
            
            // Check custom author headers
            if let author = httpResponse.value(forHTTPHeaderField: "X-Author") {
                Self.logger.debug("Found attribution in X-Author header: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .linkHeader)
            }
            
            if let author = httpResponse.value(forHTTPHeaderField: "Author") {
                Self.logger.debug("Found attribution in Author header: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .linkHeader)
            }
            
            return nil
        } catch {
            Self.logger.error("HEAD request failed for attribution check: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseLinkHeader(_ header: String) -> AuthorAttribution? {
        // Parse Link header format: <url>; rel="author", <url2>; rel="other"
        let links = header.components(separatedBy: ",")
        
        for link in links {
            let parts = link.components(separatedBy: ";")
            guard parts.count >= 2 else { continue }
            
            // Check if this is an author relation
            let relPart = parts[1...].joined(separator: ";").lowercased()
            guard relPart.contains("rel=\"author\"") || relPart.contains("rel=author") else {
                continue
            }
            
            // Extract URL
            let urlPart = parts[0].trimmingCharacters(in: .whitespaces)
            guard urlPart.hasPrefix("<") && urlPart.hasSuffix(">") else {
                continue
            }
            
            let urlString = String(urlPart.dropFirst().dropLast())
            
            // The URL might be the author page, try to get the name from it
            if let authorURL = URL(string: urlString) {
                // Try to extract name from URL path (e.g., /author/john-doe)
                let pathComponents = authorURL.pathComponents
                if let lastComponent = pathComponents.last, lastComponent != "/" {
                    let name = lastComponent
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized
                    return AuthorAttribution(name: name, url: urlString, source: .linkHeader)
                }
            }
            
            return AuthorAttribution(name: nil, url: urlString, source: .linkHeader)
        }
        
        return nil
    }
    
    // MARK: - Meta Tag Attribution
    
    private func checkMetaAttribution(for url: URL) async -> AuthorAttribution? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Only request the first part of the document (meta tags are in head)
        request.setValue("bytes=0-16384", forHTTPHeaderField: "Range")
        
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            Self.logger.debug("GET request for meta attribution: \(url.absoluteString, privacy: .public) -> \(statusCode), size: \(data.count) bytes")
            
            guard let html = String(data: data, encoding: .utf8) else {
                Self.logger.debug("Failed to decode HTML for attribution: \(url.absoluteString, privacy: .public)")
                return nil
            }
            
            // Try different meta tag sources in order of preference
            
            // 1. Standard meta author tag
            if let author = extractMetaContent(from: html, name: "author") {
                Self.logger.debug("Found attribution in meta author tag: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .metaTag)
            }
            
            // 2. Open Graph article:author
            if let author = extractMetaProperty(from: html, property: "article:author") {
                Self.logger.debug("Found attribution in OG article:author: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .openGraph)
            }
            
            // 3. Open Graph og:article:author
            if let author = extractMetaProperty(from: html, property: "og:article:author") {
                Self.logger.debug("Found attribution in OG og:article:author: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .openGraph)
            }
            
            // 4. Twitter creator
            if let creator = extractMetaContent(from: html, name: "twitter:creator") {
                // Remove @ prefix if present
                let name = creator.hasPrefix("@") ? String(creator.dropFirst()) : creator
                Self.logger.debug("Found attribution in Twitter creator: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: name, url: nil, source: .twitterCard)
            }

            // 5. Fediverse creator (Mastodon-specific)
            if let creator = extractMetaContent(from: html, name: "fediverse:creator") {
                Self.logger.debug("Found attribution in Fediverse creator: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: creator, url: nil, source: .metaTag)
            }
            
            // 6. JSON-LD structured data
            if let attribution = extractJSONLDAuthor(from: html) {
                Self.logger.debug("Found attribution in JSON-LD: \(url.absoluteString, privacy: .public)")
                return attribution
            }
            
            // 7. Link rel="author" in HTML
            if let authorLink = extractLinkRelAuthor(from: html) {
                Self.logger.debug("Found attribution in link rel=author: \(url.absoluteString, privacy: .public)")
                return authorLink
            }
            
            return nil
        } catch {
            Self.logger.error("GET request failed for meta attribution: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        // Match <meta name="author" content="...">
        let pattern = #"<meta[^>]+name\s*=\s*["']\#(name)["'][^>]+content\s*=\s*["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }
    
    private func extractMetaProperty(from html: String, property: String) -> String? {
        // Match <meta property="og:..." content="...">
        let escapedProperty = NSRegularExpression.escapedPattern(for: property)
        let pattern = #"<meta[^>]+property\s*=\s*["']\#(escapedProperty)["'][^>]+content\s*=\s*["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let content = String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }
    
    private func extractJSONLDAuthor(from html: String) -> AuthorAttribution? {
        // Find JSON-LD script tag
        let pattern = #"<script[^>]+type\s*=\s*["']application/ld\+json["'][^>]*>([^<]+)</script>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }
            
            // Check for author in JSON-LD
            if let author = json["author"] {
                if let authorDict = author as? [String: Any] {
                    if let name = authorDict["name"] as? String {
                        let url = authorDict["url"] as? String
                        return AuthorAttribution(name: name, url: url, source: .jsonLD)
                    }
                } else if let authorName = author as? String {
                    return AuthorAttribution(name: authorName, url: nil, source: .jsonLD)
                } else if let authors = author as? [[String: Any]], let firstAuthor = authors.first {
                    if let name = firstAuthor["name"] as? String {
                        let url = firstAuthor["url"] as? String
                        return AuthorAttribution(name: name, url: url, source: .jsonLD)
                    }
                }
            }
            
            // Check for creator
            if let creator = json["creator"] as? [String: Any],
               let name = creator["name"] as? String {
                let url = creator["url"] as? String
                return AuthorAttribution(name: name, url: url, source: .jsonLD)
            }
        }
        
        return nil
    }
    
    private func extractLinkRelAuthor(from html: String) -> AuthorAttribution? {
        // Match <link rel="author" href="...">
        let pattern = #"<link[^>]+rel\s*=\s*["']author["'][^>]+href\s*=\s*["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let hrefRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let href = String(html[hrefRange])
        
        // Try to extract name from URL
        if let url = URL(string: href) {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let lastComponent = pathComponents.last {
                let name = lastComponent
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                return AuthorAttribution(name: name, url: href, source: .metaTag)
            }
        }
        
        return AuthorAttribution(name: nil, url: href, source: .metaTag)
    }
    
    // MARK: - Cache
    
    private func cacheResult(_ attribution: AuthorAttribution, for url: URL) {
        // Simple LRU-style cache management
        if cache.count >= cacheLimit {
            // Remove oldest entries (this is a simple approach)
            let keysToRemove = Array(cache.keys.prefix(cacheLimit / 4))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
            Self.logger.debug("Attribution cache evicted \(keysToRemove.count) items (limit: \(cacheLimit))")
        }
        
        cache[url] = attribution
        Self.logger.debug("Cached attribution for: \(url.absoluteString, privacy: .public), cache size: \(cache.count)")
    }
    
    func clearCache() {
        let count = cache.count
        cache.removeAll()
        Self.logger.info("Cleared attribution cache: \(count) items removed")
    }

    func cacheCountForTesting() -> Int {
        cache.count
    }
}

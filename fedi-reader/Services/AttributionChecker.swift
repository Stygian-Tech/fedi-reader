//
//  AttributionChecker.swift
//  fedi-reader
//
//  Checks for author attribution via HEAD requests and HTML parsing
//

import Foundation
import os

actor AttributionChecker {
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
            Self.logger.info("Attribution found via HEAD: \(url.absoluteString, privacy: .public), name: \(attribution.name ?? "nil", privacy: .public), source: \(String(describing: attribution.source), privacy: .public)")
            cacheResult(attribution, for: url)
            return attribution
        }
        
        // Fall back to fetching HTML meta tags
        if let attribution = await checkMetaAttribution(for: url) {
            Self.logger.info("Attribution found via meta tags: \(url.absoluteString, privacy: .public), name: \(attribution.name ?? "nil", privacy: .public), source: \(String(describing: attribution.source), privacy: .public)")
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
        let checker = self
        
        await withTaskGroup(of: (URL, AuthorAttribution?).self) { group in
            for url in uniqueURLs {
                group.addTask { [checker] in
                    let attribution = await checker.checkAttribution(for: url)
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
            
            // Check custom author headers (only if they contain actual author info, not derived)
            if let author = httpResponse.value(forHTTPHeaderField: "X-Author"), !author.isEmpty {
                Self.logger.debug("Found attribution in X-Author header: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .linkHeader)
            }
            
            if let author = httpResponse.value(forHTTPHeaderField: "Author"), !author.isEmpty {
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
            
            // Return attribution with URL only - don't make up names from URL paths
            // The URL is valid author attribution, but we need actual meta tags for the name
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
            
            // 1. Fediverse creator (Mastodon-specific) - HIGHEST PRIORITY
            if let creator = extractMetaContent(from: html, name: "fediverse:creator") {
                Self.logger.debug("Found attribution in Fediverse creator: \(url.absoluteString, privacy: .public)")
                let (handle, profileURL) = parseMastodonHandle(creator)
                // Fetch profile picture if we have a Mastodon profile URL
                let profilePicture = profileURL != nil ? await fetchMastodonProfilePicture(profileURL: profileURL!) : nil
                return AuthorAttribution(
                    name: creator,
                    url: nil,
                    source: .metaTag,
                    mastodonHandle: handle,
                    mastodonProfileURL: profileURL,
                    profilePictureURL: profilePicture
                )
            }
            
            // 2. Standard meta author tag
            if let author = extractMetaContent(from: html, name: "author") {
                Self.logger.debug("Found attribution in meta author tag: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .metaTag)
            }
            
            // 3. Open Graph article:author
            if let author = extractMetaProperty(from: html, property: "article:author") {
                Self.logger.debug("Found attribution in OG article:author: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .openGraph)
            }
            
            // 4. Open Graph og:article:author
            if let author = extractMetaProperty(from: html, property: "og:article:author") {
                Self.logger.debug("Found attribution in OG og:article:author: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: author, url: nil, source: .openGraph)
            }
            
            // 5. Twitter creator
            if let creator = extractMetaContent(from: html, name: "twitter:creator") {
                // Remove @ prefix if present
                let name = creator.hasPrefix("@") ? String(creator.dropFirst()) : creator
                Self.logger.debug("Found attribution in Twitter creator: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: name, url: nil, source: .twitterCard)
            }
            
            // 6. JSON-LD structured data
            if let attribution = extractJSONLDAuthor(from: html) {
                Self.logger.debug("Found attribution in JSON-LD: \(url.absoluteString, privacy: .public)")
                // Fetch profile picture if author URL exists
                if let authorURL = attribution.url, let url = URL(string: authorURL) {
                    let profilePicture = await fetchAuthorProfilePicture(from: url)
                    return AuthorAttribution(
                        name: attribution.name,
                        url: attribution.url,
                        source: attribution.source,
                        mastodonHandle: attribution.mastodonHandle,
                        mastodonProfileURL: attribution.mastodonProfileURL,
                        profilePictureURL: profilePicture
                    )
                }
                return attribution
            }
            
            // 7. Link rel="author" in HTML
            if let authorLink = extractLinkRelAuthor(from: html) {
                Self.logger.debug("Found attribution in link rel=author: \(url.absoluteString, privacy: .public)")
                // Fetch profile picture if author URL exists
                if let authorURL = authorLink.url, let url = URL(string: authorURL) {
                    let profilePicture = await fetchAuthorProfilePicture(from: url)
                    return AuthorAttribution(
                        name: authorLink.name,
                        url: authorLink.url,
                        source: authorLink.source,
                        mastodonHandle: authorLink.mastodonHandle,
                        mastodonProfileURL: authorLink.mastodonProfileURL,
                        profilePictureURL: profilePicture
                    )
                }
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
        
        // Return attribution with URL only - don't make up names from URL paths
        // The URL is valid author attribution, but we need actual meta tags for the name
        return AuthorAttribution(name: nil, url: href, source: .metaTag)
    }
    
    // MARK: - Mastodon Handle Parsing
    
    /// Parses a Mastodon handle and returns the handle and profile URL
    /// Format: @username@instance.com or username@instance.com
    private func parseMastodonHandle(_ handle: String) -> (handle: String?, profileURL: String?) {
        var cleanedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove @ prefix if present
        if cleanedHandle.hasPrefix("@") {
            cleanedHandle = String(cleanedHandle.dropFirst())
        }
        
        // Split by @ to get username and instance
        let components = cleanedHandle.components(separatedBy: "@")
        guard components.count == 2 else {
            Self.logger.debug("Invalid Mastodon handle format: \(handle, privacy: .public)")
            return (nil, nil)
        }
        
        let username = components[0]
        let instance = components[1]
        
        // Build profile URL: https://instance/@username
        let profileURL = "https://\(instance)/@\(username)"
        
        return ("@\(cleanedHandle)", profileURL)
    }
    
    // MARK: - Profile Picture Fetching
    
    /// Fetches profile picture from a Mastodon profile URL
    private func fetchMastodonProfilePicture(profileURL: String) async -> String? {
        guard let url = URL(string: profileURL) else { return nil }
        
        // Try to fetch the profile page and extract avatar
        do {
            var request = URLRequest(url: url)
            request.setValue("bytes=0-32768", forHTTPHeaderField: "Range")
            
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Look for Open Graph image or Twitter card image
            if let ogImage = extractMetaProperty(from: html, property: "og:image") {
                return ogImage
            }
            
            if let twitterImage = extractMetaContent(from: html, name: "twitter:image") {
                return twitterImage
            }
            
            // Look for avatar in meta tags
            if let avatar = extractMetaProperty(from: html, property: "og:image:url") {
                return avatar
            }
        } catch {
            Self.logger.debug("Failed to fetch Mastodon profile picture: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fetches profile picture from an author page URL
    private func fetchAuthorProfilePicture(from url: URL) async -> String? {
        do {
            var request = URLRequest(url: url)
            request.setValue("bytes=0-32768", forHTTPHeaderField: "Range")
            
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Look for Open Graph image first (most reliable)
            if let ogImage = extractMetaProperty(from: html, property: "og:image") {
                return ogImage
            }
            
            // Try Twitter card image
            if let twitterImage = extractMetaContent(from: html, name: "twitter:image") {
                return twitterImage
            }
            
            // Try avatar-specific meta tags
            if let avatar = extractMetaProperty(from: html, property: "og:image:url") {
                return avatar
            }
            
            // Look for profile picture in JSON-LD
            if let jsonLDImage = extractJSONLDImage(from: html) {
                return jsonLDImage
            }
        } catch {
            Self.logger.debug("Failed to fetch author profile picture from \(url.absoluteString, privacy: .public): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Extracts image URL from JSON-LD structured data
    private func extractJSONLDImage(from html: String) -> String? {
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
            
            // Check for image in JSON-LD
            if let image = json["image"] as? String {
                return image
            }
            
            if let image = json["image"] as? [String: Any],
               let imageUrl = image["url"] as? String {
                return imageUrl
            }
        }
        
        return nil
    }
    
    // MARK: - Cache
    
    private func cacheResult(_ attribution: AuthorAttribution, for url: URL) {
        // Simple LRU-style cache management
        if cache.count >= cacheLimit {
            // Remove oldest entries (this is a simple approach)
            let keysToRemove = Array(cache.keys.prefix(self.cacheLimit / 4))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
            Self.logger.debug("Attribution cache evicted \(keysToRemove.count) items (limit: \(self.cacheLimit))")
        }
        
        cache[url] = attribution
        Self.logger.debug("Cached attribution for: \(url.absoluteString, privacy: .public), cache size: \(self.cache.count)")
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

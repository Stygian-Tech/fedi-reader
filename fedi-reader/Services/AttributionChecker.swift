//
//  AttributionChecker.swift
//  fedi-reader
//
//  Checks for author attribution via HEAD requests and HTML parsing
//

import Foundation
import os

actor AttributionChecker {
    static let shared = AttributionChecker()
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "AttributionChecker")

    private static let standardAuthorMetaNames = [
        "author",
        "dc.creator",
        "dcterms.creator",
        "parsely-author",
        "sailthru.author",
        "citation_author"
    ]

    private static let standardAuthorMetaProperties = [
        "article:author",
        "og:article:author",
        "author"
    ]
    
    private let session: URLSession
    
    // Cache for attribution results
    private var cache: [URL: AuthorAttribution] = [:]
    private let cacheLimit = 500
    
    init(configuration: URLSessionConfiguration = .default) {
        let config: URLSessionConfiguration
        if configuration === URLSessionConfiguration.default {
            config = URLSessionConfiguration.ephemeral
        } else {
            config = configuration
        }
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

        let headerAttribution = await checkHeaderAttribution(for: url)
        let shouldFetchDocumentAttribution = headerAttribution == nil
            || headerAttribution?.name == nil
            || headerAttribution?.url == nil
            || headerAttribution?.mastodonHandle == nil
            || headerAttribution?.mastodonProfileURL == nil

        let documentAttribution = shouldFetchDocumentAttribution
            ? await checkMetaAttribution(for: url)
            : nil

        if let attribution = await mergedAttribution(
            primary: documentAttribution,
            fallback: headerAttribution
        ) {
            Self.logger.info("Attribution found: \(url.absoluteString, privacy: .public), name: \(attribution.name ?? "nil", privacy: .public), source: \(String(describing: attribution.source), privacy: .public)")
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
                if let attribution = parseLinkHeader(linkHeader, relativeTo: url) {
                    Self.logger.debug("Found attribution in Link header: \(url.absoluteString, privacy: .public)")
                    return attribution
                }
            }
            
            // Check custom author headers (only if they contain actual author info, not derived)
            if let author = httpResponse.value(forHTTPHeaderField: "X-Author"), !author.isEmpty {
                Self.logger.debug("Found attribution in X-Author header: \(url.absoluteString, privacy: .public)")
                let decoded = HTMLParser.decodeHTMLEntities(author).trimmingCharacters(in: .whitespacesAndNewlines)
                return AuthorAttribution(name: decoded.isEmpty ? author : decoded, url: nil, source: .linkHeader)
            }
            
            if let author = httpResponse.value(forHTTPHeaderField: "Author"), !author.isEmpty {
                Self.logger.debug("Found attribution in Author header: \(url.absoluteString, privacy: .public)")
                let decoded = HTMLParser.decodeHTMLEntities(author).trimmingCharacters(in: .whitespacesAndNewlines)
                return AuthorAttribution(name: decoded.isEmpty ? author : decoded, url: nil, source: .linkHeader)
            }
            
            return nil
        } catch {
            Self.logger.error("HEAD request failed for attribution check: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func parseLinkHeader(_ header: String, relativeTo pageURL: URL) -> AuthorAttribution? {
        // Parse Link header format: <url>; rel="author", <url2>; rel="other"
        let links = header.components(separatedBy: ",")
        
        for link in links {
            let parts = link.components(separatedBy: ";")
            guard parts.count >= 2 else { continue }
            
            // Check if this is an author relation
            let relPart = parts[1...].joined(separator: ";")
            guard hasAuthorLinkRelation(in: relPart) else {
                continue
            }
            
            // Extract URL
            let urlPart = parts[0].trimmingCharacters(in: .whitespaces)
            guard urlPart.hasPrefix("<") && urlPart.hasSuffix(">") else {
                continue
            }
            
            let urlString = String(urlPart.dropFirst().dropLast())
            guard let absoluteURL = absoluteURLString(from: urlString, relativeTo: pageURL) else {
                continue
            }
            
            // Return attribution with URL only - don't make up names from URL paths
            // The URL is valid author attribution, but we need actual meta tags for the name
            return makeURLAttribution(urlString: absoluteURL, source: .linkHeader)
        }
        
        return nil
    }
    
    // MARK: - Meta Tag Attribution
    
    private func checkMetaAttribution(for url: URL) async -> AuthorAttribution? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Only request the first part of the document (meta tags are in head)
        request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
        
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            Self.logger.debug("GET request for meta attribution: \(url.absoluteString, privacy: .public) -> \(statusCode), size: \(data.count) bytes")
            
            guard let html = decodeHTML(data, response: response) else {
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

            // 2. JSON-LD structured data
            if let attribution = extractJSONLDAuthor(from: html, pageURL: url) {
                Self.logger.debug("Found attribution in JSON-LD: \(url.absoluteString, privacy: .public)")
                return await attachProfilePictureIfNeeded(to: attribution)
            }

            // 3. Open Graph / article author metadata
            if let author = extractMetaProperty(from: html, properties: Self.standardAuthorMetaProperties),
               let attribution = makeAuthorAttribution(from: author, source: .openGraph, relativeTo: url) {
                Self.logger.debug("Found attribution in author meta property: \(url.absoluteString, privacy: .public)")
                return await attachProfilePictureIfNeeded(to: attribution)
            }

            // 4. Twitter creator
            if let creator = extractMetaContent(from: html, name: "twitter:creator") {
                // Remove @ prefix if present
                let name = creator.hasPrefix("@") ? String(creator.dropFirst()) : creator
                Self.logger.debug("Found attribution in Twitter creator: \(url.absoluteString, privacy: .public)")
                return AuthorAttribution(name: name, url: nil, source: .twitterCard)
            }

            // 5. Standard author-style meta tags
            if let author = extractMetaContent(from: html, names: Self.standardAuthorMetaNames),
               let attribution = makeAuthorAttribution(from: author, source: .metaTag, relativeTo: url) {
                Self.logger.debug("Found attribution in author meta tag: \(url.absoluteString, privacy: .public)")
                return await attachProfilePictureIfNeeded(to: attribution)
            }

            // 6. Link rel="author" in HTML
            if let authorLink = extractLinkRelAuthor(from: html, relativeTo: url) {
                Self.logger.debug("Found attribution in link rel=author: \(url.absoluteString, privacy: .public)")
                return await attachProfilePictureIfNeeded(to: authorLink)
            }
            
            return nil
        } catch {
            Self.logger.error("GET request failed for meta attribution: \(url.absoluteString, privacy: .public), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        HTMLParser.metaContent(in: html, name: name)
    }

    private func extractMetaContent(from html: String, names: [String]) -> String? {
        for name in names {
            if let content = HTMLParser.metaContent(in: html, name: name)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !content.isEmpty {
                return content
            }
        }

        return nil
    }
    
    private func extractMetaProperty(from html: String, property: String) -> String? {
        HTMLParser.metaProperty(in: html, property: property)
    }

    private func extractMetaProperty(from html: String, properties: [String]) -> String? {
        for property in properties {
            if let content = HTMLParser.metaProperty(in: html, property: property)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !content.isEmpty {
                return content
            }
        }

        return nil
    }
    
    private func extractJSONLDAuthor(from html: String, pageURL: URL) -> AuthorAttribution? {
        let pattern = #"<script[^>]+type\s*=\s*["']application/ld\+json["'][^>]*>(.*?)</script>"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = jsonString.data(using: .utf8),
                  let payload = try? JSONSerialization.jsonObject(with: jsonData) else {
                continue
            }

            let nodes = flattenedJSONLDNodes(from: payload)
            var identifierIndex: [String: [String: Any]] = [:]
            for node in nodes {
                if let identifier = node["@id"] as? String, !identifier.isEmpty {
                    identifierIndex[identifier] = node
                }
            }

            for node in nodes {
                if let author = node["author"],
                   let attribution = authorAttribution(fromJSONLD: author, identifierIndex: identifierIndex, pageURL: pageURL) {
                    return attribution
                }

                if let creator = node["creator"],
                   let attribution = authorAttribution(fromJSONLD: creator, identifierIndex: identifierIndex, pageURL: pageURL) {
                    return attribution
                }
            }
        }

        return nil
    }

    private func authorAttribution(fromJSONLD value: Any, identifierIndex: [String: [String: Any]], pageURL: URL) -> AuthorAttribution? {
        if let stringValue = value as? String {
            if let resolved = identifierIndex[stringValue] {
                return authorAttribution(fromJSONLD: resolved, identifierIndex: identifierIndex, pageURL: pageURL)
            }

            let decoded = HTMLParser.decodeHTMLEntities(stringValue).trimmingCharacters(in: .whitespacesAndNewlines)
            return makeAuthorAttribution(from: decoded, source: .jsonLD, relativeTo: pageURL)
        }

        if let arrayValue = value as? [Any] {
            for item in arrayValue {
                if let attribution = authorAttribution(fromJSONLD: item, identifierIndex: identifierIndex, pageURL: pageURL) {
                    return attribution
                }
            }
            return nil
        }

        guard let dictionaryValue = value as? [String: Any] else {
            return nil
        }

        if let identifier = dictionaryValue["@id"] as? String,
           dictionaryValue.count == 1,
           let resolved = identifierIndex[identifier] {
            return authorAttribution(fromJSONLD: resolved, identifierIndex: identifierIndex, pageURL: pageURL)
        }

        let rawName = firstTextValue(in: dictionaryValue["name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.map { HTMLParser.decodeHTMLEntities($0).trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let urlCandidates = urlValues(in: dictionaryValue["url"]) + urlValues(in: dictionaryValue["sameAs"])
        let absoluteURLs = urlCandidates.compactMap { absoluteURLString(from: $0, relativeTo: pageURL) }
        let mastodonProfileURL = absoluteURLs.first(where: isMastodonProfileURL)
        let fallbackURL = absoluteURLs.first

        let mastodonHandle: String?
        if let mastodonProfileURL,
           let resolvedURL = URL(string: mastodonProfileURL),
           let acct = MastodonProfileReference.acct(from: resolvedURL) {
            mastodonHandle = "@\(acct)"
        } else {
            mastodonHandle = nil
        }

        if let trimmedName = name, !trimmedName.isEmpty {
            return AuthorAttribution(
                name: trimmedName,
                url: fallbackURL,
                source: .jsonLD,
                mastodonHandle: mastodonHandle,
                mastodonProfileURL: mastodonProfileURL
            )
        }

        if let fallbackURL {
            return makeURLAttribution(
                urlString: fallbackURL,
                source: .jsonLD,
                mastodonHandle: mastodonHandle,
                mastodonProfileURL: mastodonProfileURL
            )
        }

        if let nestedAuthor = dictionaryValue["author"] {
            return authorAttribution(fromJSONLD: nestedAuthor, identifierIndex: identifierIndex, pageURL: pageURL)
        }

        if let nestedCreator = dictionaryValue["creator"] {
            return authorAttribution(fromJSONLD: nestedCreator, identifierIndex: identifierIndex, pageURL: pageURL)
        }

        return nil
    }

    private func flattenedJSONLDNodes(from payload: Any) -> [[String: Any]] {
        if let dictionary = payload as? [String: Any] {
            var nodes = [dictionary]

            if let graph = dictionary["@graph"] as? [Any] {
                nodes.append(contentsOf: graph.compactMap { $0 as? [String: Any] })
            }

            return nodes
        }

        if let array = payload as? [Any] {
            return array.flatMap(flattenedJSONLDNodes(from:))
        }

        return []
    }

    private func firstTextValue(in value: Any?) -> String? {
        if let stringValue = value as? String {
            return stringValue
        }

        if let arrayValue = value as? [Any] {
            for item in arrayValue {
                if let stringValue = firstTextValue(in: item),
                   !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return stringValue
                }
            }
        }

        return nil
    }

    private func urlValues(in value: Any?) -> [String] {
        if let stringValue = value as? String {
            return [stringValue]
        }

        if let arrayValue = value as? [Any] {
            return arrayValue.flatMap(urlValues(in:))
        }

        if let dictionaryValue = value as? [String: Any],
           let stringValue = dictionaryValue["url"] as? String {
            return [stringValue]
        }

        return []
    }

    private func extractLinkRelAuthor(from html: String, relativeTo pageURL: URL) -> AuthorAttribution? {
        guard let relation = HTMLParser.authorRelation(in: html),
              let absoluteURL = absoluteURLString(from: relation.href, relativeTo: pageURL) else {
            return nil
        }

        let name = relation.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlAttribution = makeURLAttribution(urlString: absoluteURL, source: .metaTag)

        if let name, !name.isEmpty {
            return AuthorAttribution(
                name: name,
                url: urlAttribution.url,
                source: urlAttribution.source,
                mastodonHandle: urlAttribution.mastodonHandle,
                mastodonProfileURL: urlAttribution.mastodonProfileURL,
                profilePictureURL: urlAttribution.profilePictureURL
            )
        }

        return urlAttribution
    }
    
    private func makeAuthorAttribution(from rawValue: String, source: AttributionSource, relativeTo pageURL: URL) -> AuthorAttribution? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        if let absoluteURL = absoluteURLString(from: trimmedValue, relativeTo: pageURL) {
            return makeURLAttribution(urlString: absoluteURL, source: source)
        }

        return AuthorAttribution(name: trimmedValue, url: nil, source: source)
    }

    private func makeURLAttribution(
        urlString: String,
        source: AttributionSource,
        mastodonHandle: String? = nil,
        mastodonProfileURL: String? = nil
    ) -> AuthorAttribution {
        let parsedURL = URL(string: urlString)
        let resolvedAcct = parsedURL.flatMap(MastodonProfileReference.acct(from:))
        let resolvedProfileURL = mastodonProfileURL ?? (resolvedAcct != nil ? urlString : nil)
        let resolvedHandle = mastodonHandle ?? resolvedAcct.map { "@\($0)" }

        return AuthorAttribution(
            name: nil,
            url: urlString,
            source: source,
            mastodonHandle: resolvedHandle,
            mastodonProfileURL: resolvedProfileURL
        )
    }

    private func absoluteURLString(from rawValue: String, relativeTo pageURL: URL) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikePath = trimmedValue.hasPrefix("/") || trimmedValue.hasPrefix("./") || trimmedValue.hasPrefix("../")
        let looksLikeAbsoluteURL = trimmedValue.contains("://") || trimmedValue.hasPrefix("//")
        let looksLikeRelativePath = !trimmedValue.contains(" ") && trimmedValue.contains("/")
        let looksLikeHost = trimmedValue.range(
            of: #"^[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$"#,
            options: .regularExpression
        ) != nil

        guard !trimmedValue.isEmpty,
              looksLikePath || looksLikeAbsoluteURL || looksLikeRelativePath || looksLikeHost,
              let resolvedURL = URL(string: trimmedValue, relativeTo: pageURL)?.absoluteURL,
              let scheme = resolvedURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return resolvedURL.absoluteString
    }

    private func isMastodonProfileURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return MastodonProfileReference.acct(from: url) != nil
    }

    private func mergedAttribution(
        primary: AuthorAttribution?,
        fallback: AuthorAttribution?
    ) async -> AuthorAttribution? {
        let merged = merge(primary: primary, fallback: fallback)
        return await attachProfilePictureIfNeeded(to: merged)
    }

    private func merge(primary: AuthorAttribution?, fallback: AuthorAttribution?) -> AuthorAttribution? {
        switch (primary, fallback) {
        case (nil, nil):
            return nil
        case let (primary?, nil):
            return primary
        case let (nil, fallback?):
            return fallback
        case let (primary?, fallback?):
            return AuthorAttribution(
                name: primary.name ?? fallback.name,
                url: primary.url ?? fallback.url,
                source: primary.source,
                mastodonHandle: primary.mastodonHandle ?? fallback.mastodonHandle,
                mastodonProfileURL: primary.mastodonProfileURL ?? fallback.mastodonProfileURL,
                profilePictureURL: primary.profilePictureURL ?? fallback.profilePictureURL
            )
        }
    }

    private func attachProfilePictureIfNeeded(to attribution: AuthorAttribution?) async -> AuthorAttribution? {
        guard let attribution else {
            return nil
        }

        if attribution.profilePictureURL != nil {
            return attribution
        }

        if let mastodonProfileURL = attribution.mastodonProfileURL {
            let profilePictureURL = await fetchMastodonProfilePicture(profileURL: mastodonProfileURL)
            return AuthorAttribution(
                name: attribution.name,
                url: attribution.url,
                source: attribution.source,
                mastodonHandle: attribution.mastodonHandle,
                mastodonProfileURL: attribution.mastodonProfileURL,
                profilePictureURL: profilePictureURL
            )
        }

        if let authorURL = attribution.url,
           let url = URL(string: authorURL) {
            let profilePictureURL = await fetchAuthorProfilePicture(from: url)
            return AuthorAttribution(
                name: attribution.name,
                url: attribution.url,
                source: attribution.source,
                mastodonHandle: attribution.mastodonHandle,
                mastodonProfileURL: attribution.mastodonProfileURL,
                profilePictureURL: profilePictureURL
            )
        }

        return attribution
    }

    private func decodeHTML(_ data: Data, response: URLResponse?) -> String? {
        if let html = String(data: data, encoding: .utf8) {
            return html
        }

        if let html = String(data: data, encoding: .isoLatin1) {
            return html
        }

        if let response = response as? HTTPURLResponse,
           response.textEncodingName?.caseInsensitiveCompare("windows-1252") == .orderedSame,
           let html = String(data: data, encoding: .windowsCP1252) {
            return html
        }

        return nil
    }

    private func hasAuthorLinkRelation(in parameters: String) -> Bool {
        let pattern = #"rel\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s;]+))"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }

        let range = NSRange(parameters.startIndex..., in: parameters)
        guard let match = regex.firstMatch(in: parameters, options: [], range: range) else {
            return false
        }

        let valueRange = Range(match.range(at: 1), in: parameters)
            ?? Range(match.range(at: 2), in: parameters)
            ?? Range(match.range(at: 3), in: parameters)

        guard let valueRange else {
            return false
        }

        return parameters[valueRange]
            .split(whereSeparator: \.isWhitespace)
            .contains { token in
                token.caseInsensitiveCompare("author") == .orderedSame
            }
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
            request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
            
            let (data, response) = try await session.data(for: request)
            guard let html = decodeHTML(data, response: response) else { return nil }
            
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
            request.setValue("bytes=0-65535", forHTTPHeaderField: "Range")
            
            let (data, response) = try await session.data(for: request)
            guard let html = decodeHTML(data, response: response) else { return nil }
            
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

<<<<<<< Current (Your changes)
=======
//
//  LinkPreviewService.swift
//  fedi-reader
//
//  Fetches lightweight preview metadata for links
//

import Foundation

@MainActor
final class LinkPreviewService {
    static let shared = LinkPreviewService()
    
    private let session: URLSession
    private var cache: [URL: String] = [:]
    private var fediverseCreatorCache: [URL: (name: String, url: URL?)] = [:]
    private let cacheLimit = 500
    
    init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": Constants.userAgent
        ]
        self.session = session ?? URLSession(configuration: config)
    }
    
    func fetchDescription(for url: URL) async -> String? {
        if let cached = cache[url] {
            return cached
        }
        
        let resolvedURL = await resolveURL(for: url) ?? url
        if let cached = cache[resolvedURL] {
            return cached
        }
        
        guard let html = await fetchHeadHTML(from: resolvedURL) else { return nil }
        let description = extractDescription(from: html)
        
        if let description, !description.isEmpty {
            cacheResult(description, for: resolvedURL)
        }
        
        return description
    }
    
    func fetchFediverseCreator(for url: URL) async -> (name: String, url: URL?)? {
        if let cached = fediverseCreatorCache[url] {
            return cached
        }
        
        let resolvedURL = await resolveURL(for: url) ?? url
        if let cached = fediverseCreatorCache[resolvedURL] {
            return cached
        }
        
        guard let html = await fetchHeadHTML(from: resolvedURL),
              let creator = extractMetaContent(from: html, name: "fediverse:creator"),
              !creator.isEmpty else { return nil }
        
        let normalized = normalizeFediverseCreator(creator)
        cacheFediverseCreator(normalized, for: resolvedURL)
        return normalized
    }

    func prefetchFediverseCreators(for urls: [URL]) async {
        let unique = Array(Set(urls))
        guard !unique.isEmpty else { return }
        
        await withTaskGroup(of: Void.self) { group in
            for url in unique {
                group.addTask {
                    _ = await self.fetchFediverseCreator(for: url)
                }
            }
        }
    }
    
    private func resolveURL(for url: URL) async -> URL? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await session.data(for: request)
            return response.url
        } catch {
            return nil
        }
    }
    
    private func fetchHeadHTML(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-32768", forHTTPHeaderField: "Range")
        
        do {
            let (data, _) = try await session.data(for: request)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    private func extractDescription(from html: String) -> String? {
        if let ogDescription = extractMetaProperty(from: html, property: "og:description") {
            return HTMLParser.decodeHTMLEntities(ogDescription)
        }
        
        if let twitterDescription = extractMetaContent(from: html, name: "twitter:description") {
            return HTMLParser.decodeHTMLEntities(twitterDescription)
        }
        
        if let metaDescription = extractMetaContent(from: html, name: "description") {
            return HTMLParser.decodeHTMLEntities(metaDescription)
        }
        
        return nil
    }
    
    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = #"<meta[^>]+name\s*=\s*["']\#(name)["'][^>]+content\s*=\s*["']([^"']+)["']"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractMetaProperty(from html: String, property: String) -> String? {
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
        
        return String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cacheResult(_ description: String, for url: URL) {
        if cache.count >= cacheLimit {
            let keysToRemove = Array(cache.keys.prefix(cacheLimit / 4))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        
        cache[url] = description
    }
    
    private func cacheFediverseCreator(_ creator: (name: String, url: URL?), for url: URL) {
        if fediverseCreatorCache.count >= cacheLimit {
            let keysToRemove = Array(fediverseCreatorCache.keys.prefix(cacheLimit / 4))
            for key in keysToRemove {
                fediverseCreatorCache.removeValue(forKey: key)
            }
        }
        
        fediverseCreatorCache[url] = creator
    }
    
    private func normalizeFediverseCreator(_ creator: String) -> (name: String, url: URL?) {
        let trimmed = creator.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let parts = handle.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            return (name: trimmed, url: nil)
        }
        
        let username = parts[0]
        let instance = parts[1]
        let profileURL = URL(string: "https://\(instance)/@\(username)")
        return (name: "@\(username)@\(instance)", url: profileURL)
    }
}
>>>>>>> Incoming (Background Agent changes)

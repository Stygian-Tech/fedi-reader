//
//  LinkPreviewService.swift
//  fedi-reader
//
//  Fetch lightweight preview metadata (title, description, image) for external URLs.
//

import Foundation
import os

@Observable
@MainActor
final class LinkPreviewService {
    static let shared = LinkPreviewService()
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "LinkPreviewService")

    // MARK: - Types
    struct LinkPreview: Hashable, Sendable {
        let url: URL
        let finalURL: URL?
        let title: String?
        let description: String?
        let imageURL: URL?
        let siteName: String?
        let provider: String? // derived from domain
        let fediverseCreator: String? // from meta name="fediverse:creator"
        let fediverseCreatorURL: URL?
    }

    struct FediverseCreator: Sendable {
        let name: String?
        let url: URL?
    }

    // MARK: - State
    private let session: URLSession
    private var cache: [URL: LinkPreview] = [:]
    private let cacheLimit = 500

    var isLoading = false

    // MARK: - Init
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
    func preview(for url: URL) async -> LinkPreview? {
        if let cached = cache[url] {
            Self.logger.debug("Cache hit for preview: \(url.absoluteString, privacy: .public)")
            return cached
        }
        
        Self.logger.info("Fetching preview for: \(url.absoluteString, privacy: .public)")
        isLoading = true
        defer { isLoading = false }

        // Step 1: HEAD to follow redirects cheaply and detect content-type
        let headResult = await head(url)
        let finalURL = headResult.finalURL ?? url
        let contentType = headResult.contentType ?? "text/html"
        
        if finalURL != url {
            Self.logger.debug("URL redirected: \(url.absoluteString, privacy: .public) -> \(finalURL.absoluteString, privacy: .public)")
        }

        // Only fetch HTML for previews
        guard (contentType.contains("text/html") || contentType.contains("application/xhtml")) else {
            Self.logger.debug("Non-HTML content type (\(contentType, privacy: .public)), skipping HTML fetch")
            let preview = LinkPreview(
                url: url,
                finalURL: finalURL,
                title: nil,
                description: nil,
                imageURL: nil,
                siteName: nil,
                provider: HTMLParser.extractDomain(from: finalURL),
                fediverseCreator: nil,
                fediverseCreatorURL: nil
            )
            cache(preview)
            return preview
        }

        // Step 2: GET first bytes (head) of the document
        let html = await fetchHeadHTML(from: finalURL)
        let parsed = parseHTML(html, baseURL: finalURL)
        let creator = normalizeFediverseCreator(parsed.fediverseCreator)
        let preview = LinkPreview(
            url: url,
            finalURL: finalURL,
            title: parsed.title,
            description: parsed.description,
            imageURL: parsed.imageURL,
            siteName: parsed.siteName,
            provider: HTMLParser.extractDomain(from: finalURL),
            fediverseCreator: creator.name,
            fediverseCreatorURL: creator.url
        )
        
        Self.logger.info("Preview fetched: title=\(parsed.title ?? "nil", privacy: .public), hasImage=\(parsed.imageURL != nil), fediverseCreator=\(creator.name ?? "nil", privacy: .public)")
        cache(preview)
        return preview
    }

    func previews(for urls: [URL]) async -> [URL: LinkPreview] {
        let uniqueURLs = Array(Set(urls))
        Self.logger.info("Fetching previews for \(uniqueURLs.count) URLs")
        var results: [URL: LinkPreview] = [:]
        await withTaskGroup(of: (URL, LinkPreview?).self) { group in
            for url in uniqueURLs {
                group.addTask { [weak self] in
                    guard let self else { return (url, nil) }
                    return (url, await self.preview(for: url))
                }
            }
            for await (url, preview) in group {
                if let preview { results[url] = preview }
            }
        }
        Self.logger.info("Fetched \(results.count) previews from \(uniqueURLs.count) URLs")
        return results
    }

    func fetchDescription(for url: URL) async -> String? {
        let preview = await preview(for: url)
        return preview?.description
    }

    func fetchFediverseCreator(for url: URL) async -> FediverseCreator? {
        let preview = await preview(for: url)
        guard let preview else { return nil }
        return FediverseCreator(name: preview.fediverseCreator, url: preview.fediverseCreatorURL)
    }

    func prefetchFediverseCreators(for urls: [URL]) async {
        let uniqueURLs = Array(Set(urls))
        guard !uniqueURLs.isEmpty else {
            Self.logger.debug("No URLs to prefetch fediverse creators")
            return
        }
        Self.logger.debug("Prefetching fediverse creators for \(uniqueURLs.count) URLs")
        _ = await previews(for: uniqueURLs)
    }

    func clearCache() {
        let count = cache.count
        cache.removeAll()
        Self.logger.info("Cleared preview cache: \(count) items removed")
    }

    // MARK: - Networking
    private func head(_ url: URL) async -> (finalURL: URL?, contentType: String?) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let type = http?.value(forHTTPHeaderField: "Content-Type")
            let finalURL = http?.url
            let statusCode = http?.statusCode ?? 0
            Self.logger.debug("HEAD request: \(url.absoluteString, privacy: .public) -> \(statusCode), contentType: \(type ?? "nil", privacy: .public)")
            return (finalURL, type)
        } catch {
            Self.logger.error("HEAD request failed for \(url.absoluteString, privacy: .public): \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    private func fetchHeadHTML(from url: URL) async -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Request only the first ~32KB; meta tags typically live in <head>
        request.setValue("bytes=0-32767", forHTTPHeaderField: "Range")
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            let html = String(data: data, encoding: .utf8) ?? ""
            Self.logger.debug("Fetched HTML head: \(url.absoluteString, privacy: .public) -> \(statusCode), size: \(data.count) bytes, html length: \(html.count)")
            return html
        } catch {
            Self.logger.error("Failed to fetch HTML head for \(url.absoluteString, privacy: .public): \(error.localizedDescription)")
            return ""
        }
    }

    // MARK: - Parsing
    private func parseHTML(_ html: String, baseURL: URL) -> (title: String?, description: String?, imageURL: URL?, siteName: String?, fediverseCreator: String?) {
        guard !html.isEmpty else { return (nil, nil, nil, nil, nil) }

        func metaContent(name: String) -> String? {
            let pattern = #"<meta[^>]+name\s*=\s*[\"']\#(NSRegularExpression.escapedPattern(for: name))[\"'][^>]+content\s*=\s*[\"']([^\"']+)[\"']"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let range = NSRange(html.startIndex..., in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  let contentRange = Range(match.range(at: 1), in: html) else { return nil }
            return HTMLParser.decodeHTMLEntities(String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        func metaProperty(_ property: String) -> String? {
            let pattern = #"<meta[^>]+property\s*=\s*[\"']\#(NSRegularExpression.escapedPattern(for: property))[\"'][^>]+content\s*=\s*[\"']([^\"']+)[\"']"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            let range = NSRange(html.startIndex..., in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  let contentRange = Range(match.range(at: 1), in: html) else { return nil }
            return HTMLParser.decodeHTMLEntities(String(html[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        func titleTag() -> String? {
            let pattern = #"<title[^>]*>(.*?)</title>"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
            let range = NSRange(html.startIndex..., in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  let textRange = Range(match.range(at: 1), in: html) else { return nil }
            return HTMLParser.convertToPlainText(String(html[textRange])).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Prefer Open Graph, then Twitter, then standard meta, then <title>
        let title = metaProperty("og:title") ?? metaContent(name: "twitter:title") ?? metaContent(name: "title") ?? titleTag()
        let description = metaProperty("og:description") ?? metaContent(name: "twitter:description") ?? metaContent(name: "description")
        let siteName = metaProperty("og:site_name")
        let fediverseCreator = metaContent(name: "fediverse:creator")

        // Image URL resolution
        let imageString = metaProperty("og:image") ?? metaContent(name: "twitter:image")
        let imageURL: URL? = {
            guard let imageString else { return nil }
            let decoded = HTMLParser.decodeHTMLEntities(imageString)
            if let url = URL(string: decoded), url.scheme != nil { return url }
            return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
        }()

        return (title, description, imageURL, siteName, fediverseCreator)
    }

    private func normalizeFediverseCreator(_ creator: String?) -> (name: String?, url: URL?) {
        guard let creator, !creator.isEmpty else { return (nil, nil) }
        let trimmed = creator.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        let parts = handle.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return (trimmed, nil) }
        let username = parts[0]
        let instance = parts[1]
        let profileURL = URL(string: "https://\(instance)/@\(username)")
        return ("@\(username)@\(instance)", profileURL)
    }

    // MARK: - Cache
    private func cache(_ preview: LinkPreview) {
        if cache.count >= cacheLimit {
            let keysToRemove = Array(cache.keys.prefix(self.cacheLimit / 4))
            for key in keysToRemove { cache.removeValue(forKey: key) }
            Self.logger.debug("Cache evicted \(keysToRemove.count) items (limit: \(self.cacheLimit))")
        }
        cache[preview.url] = preview
        Self.logger.debug("Cached preview for: \(preview.url.absoluteString, privacy: .public), cache size: \(self.cache.count)")
    }
}

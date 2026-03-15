//
//  LinkPreviewService.swift
//  fedi-reader
//
//  Fetch lightweight preview metadata (title, description, image) for external URLs.
//

import Foundation
import os

actor LinkPreviewService {
    static let shared = LinkPreviewService()
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "LinkPreviewService")
    private static let previewRangeByteLimit = 65_535

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

    private struct ParsedPreviewMetadata: Sendable {
        let title: String?
        let description: String?
        let imageURL: URL?
        let siteName: String?
        let fediverseCreator: String?

        var isEmpty: Bool {
            title?.isEmpty != false
                && description?.isEmpty != false
                && imageURL == nil
                && siteName?.isEmpty != false
                && fediverseCreator?.isEmpty != false
        }

        var isMissingImportantPreviewMetadata: Bool {
            title?.isEmpty != false
                || imageURL == nil
                || siteName?.isEmpty != false
        }

        func merging(_ other: ParsedPreviewMetadata) -> ParsedPreviewMetadata {
            ParsedPreviewMetadata(
                title: title ?? other.title,
                description: description ?? other.description,
                imageURL: imageURL ?? other.imageURL,
                siteName: siteName ?? other.siteName,
                fediverseCreator: fediverseCreator ?? other.fediverseCreator
            )
        }
    }

    private struct FetchedHTML: Sendable {
        let html: String
        let statusCode: Int
        let usedRangeRequest: Bool
    }

    // MARK: - State
    private let session: URLSession
    private var cache: [URL: LinkPreview] = [:]
    private let cacheLimit = 500

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

        // Step 2: GET first bytes of the document, then fall back to the full HTML
        // only when the head slice has no usable preview metadata.
        let fetchedHeadHTML = await fetchHTML(from: finalURL, useRangeRequest: true)
        var parsed = await Task.detached(priority: .utility) {
            Self.parseHTML(fetchedHeadHTML.html, baseURL: finalURL)
        }.value
        if Self.shouldFetchFullHTML(after: fetchedHeadHTML, parsed: parsed) {
            let fullHTML = await fetchHTML(from: finalURL, useRangeRequest: false)
            let fullParsed = await Task.detached(priority: .utility) {
                Self.parseHTML(fullHTML.html, baseURL: finalURL)
            }.value
            if !fullParsed.isEmpty {
                parsed = parsed.merging(fullParsed)
            }
        }
        let creator = Self.normalizeFediverseCreator(parsed.fediverseCreator)
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
        let service = self
        await withTaskGroup(of: (URL, LinkPreview?).self) { group in
            for url in uniqueURLs {
                group.addTask { [service] in
                    (url, await service.preview(for: url))
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

    private func fetchHTML(from url: URL, useRangeRequest: Bool) async -> FetchedHTML {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if useRangeRequest {
            // Request only the first ~64KB; most preview metadata lives in <head>.
            request.setValue("bytes=0-\(Self.previewRangeByteLimit)", forHTTPHeaderField: "Range")
        }
        do {
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            let html = String(data: data, encoding: .utf8) ?? ""
            let fetchKind = useRangeRequest ? "head" : "full"
            Self.logger.debug("Fetched HTML \(fetchKind, privacy: .public): \(url.absoluteString, privacy: .public) -> \(statusCode), size: \(data.count) bytes, html length: \(html.count)")
            return FetchedHTML(
                html: html,
                statusCode: statusCode,
                usedRangeRequest: useRangeRequest
            )
        } catch {
            let fetchKind = useRangeRequest ? "head" : "full"
            Self.logger.error("Failed to fetch HTML \(fetchKind, privacy: .public) for \(url.absoluteString, privacy: .public): \(error.localizedDescription)")
            return FetchedHTML(
                html: "",
                statusCode: 0,
                usedRangeRequest: useRangeRequest
            )
        }
    }

    private nonisolated static func shouldFetchFullHTML(
        after fetchedHTML: FetchedHTML,
        parsed: ParsedPreviewMetadata
    ) -> Bool {
        guard fetchedHTML.usedRangeRequest else {
            return false
        }

        let partialResponseLikelyIncomplete = fetchedHTML.statusCode == 206
            || fetchedHTML.html.utf8.count >= previewRangeByteLimit

        return parsed.isEmpty || (partialResponseLikelyIncomplete && parsed.isMissingImportantPreviewMetadata)
    }

    // MARK: - Parsing
    private nonisolated static func parseHTML(_ html: String, baseURL: URL) -> ParsedPreviewMetadata {
        guard !html.isEmpty else {
            return ParsedPreviewMetadata(
                title: nil,
                description: nil,
                imageURL: nil,
                siteName: nil,
                fediverseCreator: nil
            )
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
        let title = HTMLParser.metaProperty(in: html, property: "og:title")
            ?? HTMLParser.metaContent(in: html, name: "twitter:title")
            ?? HTMLParser.metaContent(in: html, name: "title")
            ?? titleTag()
        let description = HTMLParser.metaProperty(in: html, property: "og:description")
            ?? HTMLParser.metaContent(in: html, name: "twitter:description")
            ?? HTMLParser.metaContent(in: html, name: "description")
        let siteName = HTMLParser.metaProperty(in: html, property: "og:site_name")
        let fediverseCreator = HTMLParser.metaContent(in: html, name: "fediverse:creator")

        // Image URL resolution
        let imageString = HTMLParser.metaProperty(in: html, property: "og:image")
            ?? HTMLParser.metaContent(in: html, name: "twitter:image")
        let imageURL: URL? = {
            guard let imageString else { return nil }
            let decoded = HTMLParser.decodeHTMLEntities(imageString)
            if let url = URL(string: decoded), url.scheme != nil { return url }
            return URL(string: decoded, relativeTo: baseURL)?.absoluteURL
        }()

        return ParsedPreviewMetadata(
            title: title,
            description: description,
            imageURL: imageURL,
            siteName: siteName,
            fediverseCreator: fediverseCreator
        )
    }

    private nonisolated static func normalizeFediverseCreator(_ creator: String?) -> (name: String?, url: URL?) {
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

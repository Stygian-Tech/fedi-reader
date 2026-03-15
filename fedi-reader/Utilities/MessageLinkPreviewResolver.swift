//
//  MessageLinkPreviewResolver.swift
//  fedi-reader
//
//  Resolves which link, if any, should be previewed for a private/direct message.
//

import Foundation

struct MessageLinkPreviewCandidate: Equatable, Sendable {
    let url: URL
    let card: PreviewCard?
}

enum MessageLinkPreviewResolver {
    nonisolated static func resolve(from status: Status) -> MessageLinkPreviewCandidate? {
        let contentLinks = externalLinks(from: status)
        guard !contentLinks.isEmpty else {
            return nil
        }

        if let card = matchingPreviewCard(from: status, contentLinks: contentLinks),
           let url = card.linkURL {
            return MessageLinkPreviewCandidate(url: url, card: card)
        }

        return MessageLinkPreviewCandidate(url: contentLinks[0], card: nil)
    }

    nonisolated static func previewCard(from status: Status) -> PreviewCard? {
        guard let card = status.displayStatus.card,
              (card.type == .link || card.type == .rich),
              card.linkURL != nil else {
            return nil
        }

        return card
    }

    private nonisolated static func matchingPreviewCard(
        from status: Status,
        contentLinks: [URL]
    ) -> PreviewCard? {
        guard let card = previewCard(from: status),
              let cardURL = card.linkURL,
              contentLinks.contains(where: { urlsMatch($0, cardURL) }) else {
            return nil
        }

        return card
    }

    private nonisolated static func externalLinks(from status: Status) -> [URL] {
        let displayStatus = status.displayStatus
        let excludedDomains = previewExcludedDomains(for: displayStatus)

        let htmlLinks = HTMLParser.extractExternalLinks(
            from: displayStatus.content,
            excludingDomains: excludedDomains
        ).filter {
            isPreviewableExternalURL($0, excludingDomains: excludedDomains)
        }
        if !htmlLinks.isEmpty {
            return htmlLinks
        }

        let plainTextLinks = HTMLParser.extractPlainTextLinks(from: displayStatus.content)
        return plainTextLinks.filter {
            isPreviewableExternalURL($0, excludingDomains: excludedDomains)
        }
    }

    private nonisolated static func previewExcludedDomains(for status: Status) -> [String] {
        var domains: [String] = []

        if let host = URL(string: status.uri)?.host?.lowercased() {
            domains.append(host)
        }

        if let host = URL(string: status.url ?? "")?.host?.lowercased(), !domains.contains(host) {
            domains.append(host)
        }

        return domains
    }

    private nonisolated static func isPreviewableExternalURL(
        _ url: URL,
        excludingDomains domains: [String]
    ) -> Bool {
        guard HTMLParser.isExternalURL(url),
              let host = url.host?.lowercased() else {
            return false
        }

        let path = url.path.lowercased()
        if path.hasPrefix("/@") || path.hasPrefix("/tags/") {
            return false
        }

        return !domains.contains { host.contains($0) }
    }

    private nonisolated static func urlsMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.absoluteString == rhs.absoluteString
            || lhs.standardized.absoluteString == rhs.standardized.absoluteString
    }
}

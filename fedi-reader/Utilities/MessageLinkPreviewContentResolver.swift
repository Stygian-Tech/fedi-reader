//
//  MessageLinkPreviewContentResolver.swift
//  fedi-reader
//
//  Resolves the display content for embedded DM link previews, merging
//  Mastodon card data with fetched HTML metadata when the card is sparse.
//

import Foundation

struct MessageLinkPreviewContent: Equatable, Sendable {
    let title: String
    let description: String
    let imageURL: URL?
    let providerDisplay: String
    let authorName: String?
    let authorURL: URL?
    let isMastodonAttribution: Bool
    let showLinkIcon: Bool
}

enum MessageLinkPreviewContentResolver {
    nonisolated static func shouldFetchPreview(for candidate: MessageLinkPreviewCandidate) -> Bool {
        guard let card = candidate.card else {
            return true
        }

        return isSparseTitle(card.decodedTitle, for: candidate.url)
            || trimmed(card.decodedDescription) == nil
            || card.imageURL == nil
            || trimmed(card.decodedProviderName) == nil
    }

    nonisolated static func resolve(
        candidate: MessageLinkPreviewCandidate,
        linkPreview: LinkPreviewService.LinkPreview?,
        authorAttribution: AuthorAttribution?,
        authorDisplayName: String?
    ) -> MessageLinkPreviewContent {
        let fallbackProvider = HTMLParser.extractDomain(from: candidate.url) ?? candidate.url.absoluteString
        let cardAuthorURL = candidate.card?.authorUrl.flatMap(URL.init(string:))
        let resolvedAuthorURL = authorAttribution?.preferredURL ?? cardAuthorURL ?? linkPreview?.fediverseCreatorURL
        let resolvedAuthorName = trimmed(authorDisplayName)
            ?? trimmed(authorAttribution?.preferredName)
            ?? trimmed(candidate.card?.decodedAuthorName)
            ?? trimmed(linkPreview?.fediverseCreator)

        let providerDisplay = trimmed(candidate.card?.decodedProviderName)
            ?? trimmed(linkPreview?.siteName)
            ?? trimmed(linkPreview?.provider)
            ?? fallbackProvider

        let title = preferredTitle(
            candidate: candidate,
            linkPreview: linkPreview,
            fallbackProvider: providerDisplay
        )

        let description = trimmed(candidate.card?.decodedDescription)
            ?? trimmed(linkPreview?.description)
            ?? ""

        let isMastodonAttribution = authorAttribution?.mastodonHandle != nil
            || authorAttribution?.mastodonProfileURL != nil
            || linkPreview?.fediverseCreator != nil
            || linkPreview?.fediverseCreatorURL != nil
            || resolvedAuthorURL.flatMap { MastodonProfileReference.acct(from: $0) } != nil

        let authorName: String? = if let resolvedAuthorURL {
            resolvedAuthorName ?? (resolvedAuthorURL.absoluteString.isEmpty ? nil : "Author")
        } else {
            resolvedAuthorName
        }

        return MessageLinkPreviewContent(
            title: title,
            description: description,
            imageURL: linkPreview?.imageURL ?? candidate.card?.imageURL,
            providerDisplay: providerDisplay,
            authorName: authorName,
            authorURL: resolvedAuthorURL,
            isMastodonAttribution: isMastodonAttribution,
            showLinkIcon: true
        )
    }

    private nonisolated static func preferredTitle(
        candidate: MessageLinkPreviewCandidate,
        linkPreview: LinkPreviewService.LinkPreview?,
        fallbackProvider: String
    ) -> String {
        if let cardTitle = trimmed(candidate.card?.decodedTitle),
           !isSparseTitle(cardTitle, for: candidate.url) {
            return cardTitle
        }

        if let previewTitle = trimmed(linkPreview?.title),
           !isSparseTitle(previewTitle, for: candidate.url) {
            return previewTitle
        }

        if let cardTitle = trimmed(candidate.card?.decodedTitle) {
            return cardTitle
        }

        if let previewTitle = trimmed(linkPreview?.title) {
            return previewTitle
        }

        return fallbackProvider
    }

    private nonisolated static func isSparseTitle(_ title: String?, for url: URL) -> Bool {
        guard let title = trimmed(title) else {
            return true
        }

        let normalizedTitle = normalizedComparable(title)
        let normalizedURL = normalizedComparable(url.absoluteString)
        let normalizedDomain = HTMLParser.extractDomain(from: url).map(normalizedComparable)

        return normalizedTitle == normalizedURL || normalizedTitle == normalizedDomain
    }

    private nonisolated static func normalizedComparable(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private nonisolated static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

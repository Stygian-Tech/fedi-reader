//
//  LinkCardContent.swift
//  fedi-reader
//
//  Shared link card layout (thumbnail + title, description, provider, author).
//  Used by Explore trending links and status detail link cards.
//

import SwiftUI

struct LinkCardContent: View {
    let title: String
    let description: String
    let imageURL: URL?
    let providerDisplay: String
    let authorName: String?
    let authorURL: URL?
    var isMastodonAttribution: Bool = false
    var showLinkIcon: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.tertiary)
                }
                .frame(width: 100)
                .frame(minHeight: 100, maxHeight: .infinity)
                .clipped()
            } else {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 100)
                    .frame(minHeight: 100, maxHeight: .infinity)
                    .overlay {
                        Image(systemName: "link")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.roundedHeadline)
                    .lineLimit(2)

                if !description.isEmpty {
                    Text(description)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if showLinkIcon {
                        Image(systemName: "link")
                            .font(.roundedCaption2)
                    }

                    Text(providerDisplay)
                        .font(.roundedCaption)
                        .lineLimit(1)

                    if let authorName {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        if let authorURL {
                            Link(destination: authorURL) {
                                AuthorAttributionView(
                                    authorName: authorName,
                                    isMastodonAttribution: isMastodonAttribution,
                                    style: .chip
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(authorName)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.trailing, 12)

            Spacer()
        }
    }
}

// MARK: - Initializers from domain types

extension LinkCardContent {
    init(link: TrendingLink) {
        title = link.decodedTitle
        description = link.decodedDescription
        imageURL = link.imageURL
        providerDisplay = link.decodedProviderName ?? link.url
        authorName = link.decodedAuthorName
        authorURL = link.authorUrl.flatMap { URL(string: $0) }
        isMastodonAttribution = false
        showLinkIcon = false
    }

    init(card: PreviewCard, authorAttribution: AuthorAttribution?, authorDisplayName: String? = nil) {
        title = card.decodedTitle
        description = card.decodedDescription
        imageURL = card.imageURL
        providerDisplay = card.decodedProviderName ?? (URL(string: card.url).flatMap { HTMLParser.extractDomain(from: $0) } ?? card.url)
        let cardAuthorURL = card.authorUrl.flatMap { URL(string: $0) }
        let resolvedAuthorName = authorDisplayName ?? authorAttribution?.preferredName ?? card.decodedAuthorName
        let resolvedAuthorURL = authorAttribution?.preferredURL ?? cardAuthorURL

        if let resolvedAuthorURL {
            authorName = resolvedAuthorName ?? "Author"
            authorURL = resolvedAuthorURL
        } else if let resolvedAuthorName {
            authorName = resolvedAuthorName
            authorURL = nil
        } else {
            authorName = nil
            authorURL = nil
        }
        isMastodonAttribution = authorAttribution?.mastodonHandle != nil
            || authorAttribution?.mastodonProfileURL != nil
        showLinkIcon = true
    }
}

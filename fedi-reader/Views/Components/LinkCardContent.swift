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
                                HStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.roundedCaption2)
                                    Text(authorName)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
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
        title = link.title
        description = link.description
        imageURL = link.imageURL
        providerDisplay = link.providerName ?? link.url
        authorName = link.authorName
        authorURL = link.authorUrl.flatMap { URL(string: $0) }
        showLinkIcon = false
    }

    init(card: PreviewCard, fediverseCreatorName: String?, fediverseCreatorURL: URL?) {
        title = card.title
        description = card.description
        imageURL = card.imageURL
        providerDisplay = card.providerName ?? (URL(string: card.url).flatMap { HTMLParser.extractDomain(from: $0) } ?? card.url)
        if let n = fediverseCreatorName {
            authorName = n
            authorURL = fediverseCreatorURL
        } else if let n = card.authorName {
            authorName = n
            authorURL = card.authorUrl.flatMap { URL(string: $0) }
        } else {
            authorName = nil
            authorURL = nil
        }
        showLinkIcon = true
    }
}

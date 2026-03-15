//
//  LinkCardContent.swift
//  fedi-reader
//
//  Shared link card layout (thumbnail + title, description, provider, author).
//  Used by Explore trending links and status detail link cards.
//

import SwiftUI

struct LinkCardContent: View {
    enum Layout: Sendable {
        case standard
        case compact
        case feed
    }

    let title: String
    let description: String
    let imageURL: URL?
    let providerDisplay: String
    let authorName: String?
    let authorURL: URL?
    var isMastodonAttribution: Bool = false
    var showLinkIcon: Bool = false
    var layout: Layout = .standard

    private var horizontalSpacing: CGFloat {
        switch layout {
        case .standard:
            12
        case .compact:
            8
        case .feed:
            0
        }
    }

    private var thumbnailWidth: CGFloat {
        switch layout {
        case .standard:
            100
        case .compact:
            72
        case .feed:
            0
        }
    }

    private var contentVerticalPadding: CGFloat {
        switch layout {
        case .standard:
            8
        case .compact:
            6
        case .feed:
            8
        }
    }

    private var contentTrailingPadding: CGFloat {
        switch layout {
        case .standard:
            12
        case .compact:
            6
        case .feed:
            12
        }
    }

    private var titleFont: Font {
        switch layout {
        case .standard:
            .roundedHeadline
        case .compact:
            .roundedCallout.weight(.semibold)
        case .feed:
            .roundedTitle3.bold()
        }
    }

    private var titleLineLimit: Int {
        switch layout {
        case .standard:
            2
        case .compact:
            3
        case .feed:
            3
        }
    }

    private var descriptionFont: Font {
        switch layout {
        case .standard:
            .roundedSubheadline
        case .compact:
            .roundedCaption
        case .feed:
            .roundedSubheadline
        }
    }

    private var descriptionLineLimit: Int {
        switch layout {
        case .standard:
            2
        case .compact:
            3
        case .feed:
            3
        }
    }

    var body: some View {
        Group {
            switch layout {
            case .feed:
                feedLayout
            case .standard, .compact:
                horizontalLayout
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: horizontalSpacing) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                titleAndDescription
                footerContent
            }
            .padding(.vertical, contentVerticalPadding)
            .padding(.trailing, contentTrailingPadding)

            Spacer()
        }
    }

    private var feedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            feedImageView

            VStack(alignment: .leading, spacing: 8) {
                titleAndDescription
                footerContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleAndDescription: some View {
        Text(title)
            .font(titleFont)
            .lineLimit(titleLineLimit)

        if !description.isEmpty {
            Text(description)
                .font(descriptionFont)
                .foregroundStyle(.secondary)
                .lineLimit(descriptionLineLimit)
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
            }
            .frame(width: thumbnailWidth)
            .frame(minHeight: thumbnailWidth, maxHeight: .infinity)
            .clipped()
        } else {
            Rectangle()
                .fill(.tertiary)
                .frame(width: thumbnailWidth)
                .frame(minHeight: thumbnailWidth, maxHeight: .infinity)
                .overlay {
                    Image(systemName: "link")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var feedImageView: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color(.tertiarySystemBackground))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemBackground))
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .overlay {
                    Image(systemName: "link")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
        }
    }

    @ViewBuilder
    private var footerContent: some View {
        if layout == .compact, authorName != nil {
            VStack(alignment: .leading, spacing: 4) {
                providerRow

                if let authorName {
                    authorView(name: authorName, foregroundStyle: Color.secondary)
                }
            }
        } else if layout == .feed {
            ViewThatFits(in: .horizontal) {
                footerRow(authorMaximumWidth: 140)
                footerRow(authorMaximumWidth: 96)
                stackedFooter
            }
        } else {
            footerRow()
        }
    }

    @ViewBuilder
    private var stackedFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            providerRow

            if let authorName {
                authorView(name: authorName, foregroundStyle: Color.secondary)
            }
        }
    }

    @ViewBuilder
    private func footerRow(authorMaximumWidth: CGFloat? = nil) -> some View {
        HStack(spacing: 8) {
            providerRow

            if let authorName {
                Text("•")
                    .foregroundStyle(.tertiary)

                if let authorMaximumWidth {
                    authorView(name: authorName, foregroundStyle: Color.secondary)
                        .frame(maxWidth: authorMaximumWidth, alignment: .leading)
                } else {
                    authorView(name: authorName, foregroundStyle: Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var providerRow: some View {
        HStack(spacing: 8) {
            if showLinkIcon {
                Image(systemName: "link")
                    .font(.roundedCaption2)
            }

            Text(providerDisplay)
                .font(.roundedCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .layoutPriority(1)
        .foregroundStyle(.tertiary)
    }

    @ViewBuilder
    private func authorView(name: String, foregroundStyle: Color) -> some View {
        if let authorURL {
            Link(destination: authorURL) {
                AuthorAttributionView(
                    authorName: name,
                    isMastodonAttribution: isMastodonAttribution,
                    style: .chip
                )
            }
            .buttonStyle(.plain)
        } else {
            Text(name)
                .font(.roundedCaption)
                .foregroundStyle(foregroundStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Initializers from domain types

extension LinkCardContent {
    init(link: TrendingLink, layout: Layout = .standard) {
        title = link.decodedTitle
        description = link.decodedDescription
        imageURL = link.imageURL
        providerDisplay = link.decodedProviderName ?? link.url
        authorName = link.decodedAuthorName
        authorURL = link.authorUrl.flatMap { URL(string: $0) }
        isMastodonAttribution = false
        showLinkIcon = false
        self.layout = layout
    }

    init(
        card: PreviewCard,
        authorAttribution: AuthorAttribution?,
        authorDisplayName: String? = nil,
        layout: Layout = .standard
    ) {
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
        self.layout = layout
    }

    init(
        preview: LinkPreviewService.LinkPreview,
        authorAttribution: AuthorAttribution?,
        authorDisplayName: String? = nil,
        layout: Layout = .standard
    ) {
        let resolvedURL = preview.finalURL ?? preview.url
        let fallbackProvider = preview.provider
            ?? preview.siteName
            ?? HTMLParser.extractDomain(from: resolvedURL)
            ?? resolvedURL.absoluteString
        let fallbackTitle = preview.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = (fallbackTitle?.isEmpty == false ? fallbackTitle : nil) ?? fallbackProvider
        let resolvedDescription = preview.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedAuthorName = authorDisplayName
            ?? authorAttribution?.preferredName
            ?? preview.fediverseCreator
        let resolvedAuthorURL = authorAttribution?.preferredURL ?? preview.fediverseCreatorURL

        title = resolvedTitle
        description = resolvedDescription
        imageURL = preview.imageURL
        providerDisplay = preview.siteName ?? fallbackProvider

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
            || preview.fediverseCreator != nil
            || preview.fediverseCreatorURL != nil
        showLinkIcon = true
        self.layout = layout
    }
}

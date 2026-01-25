//
//  LinkStatusRow.swift
//  fedi-reader
//
//  Row view for a link status in the feed.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct LinkStatusRow: View {
    let linkStatus: LinkStatus
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @AppStorage("themeColor") private var themeColorName = "blue"

    @State private var isShowingActions = false
    @State private var blueskyDescription: String?
    @State private var hasLoadedBlueskyDescription = false

    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }

    var body: some View {
        Button {
            appState.navigate(to: .status(linkStatus.status))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if linkStatus.status.isReblog {
                    reblogGradientStrip
                }

                authorHeader

                linkCard

                let tags = TagExtractor.extractTags(from: linkStatus.status)
                if !tags.isEmpty {
                    TagView(tags: tags) { tag in
                        appState.navigate(to: .hashtag(tag))
                    }
                }

                StatusActionsBar(status: linkStatus.status, size: .compact)

                Divider()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuContent
        }
        .task(id: blueskyCardURL?.absoluteString) {
            guard let url = blueskyCardURL, !hasLoadedBlueskyDescription else { return }
            hasLoadedBlueskyDescription = true
            blueskyDescription = await LinkPreviewService.shared.fetchDescription(for: url)
        }
    }

    private var reblogGradientStrip: some View {
        let reblogger = linkStatus.status.account
        return Button {
            appState.navigate(to: .status(linkStatus.status))
        } label: {
            HStack(spacing: 8) {
                ProfileAvatarView(url: reblogger.avatarURL, size: 24, placeholderStyle: .light)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.roundedCaption2)

                        Text("Boosted by")
                            .font(.roundedCaption)
                    }

                    HStack(spacing: 4) {
                        Text(reblogger.displayName)
                            .font(.roundedCaption.bold())
                            .lineLimit(1)

                        AccountBadgesView(account: reblogger, size: .small)
                    }
                }
                .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [
                        themeColor.opacity(0.28),
                        themeColor.opacity(0.15),
                        themeColor.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var authorHeader: some View {
        HStack(spacing: 10) {
            ProfileAvatarView(url: linkStatus.status.displayStatus.account.avatarURL, size: Constants.UI.avatarSize)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(linkStatus.status.displayStatus.account.displayName)
                        .font(.roundedSubheadline.bold())
                        .lineLimit(1)

                    AccountBadgesView(account: linkStatus.status.displayStatus.account, size: .small)
                }
            }

            Spacer()

            Text(TimeFormatter.relativeTimeString(from: linkStatus.status.displayStatus.createdAt))
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
        }
    }

    private var blueskyCardURL: URL? {
        let url = linkStatus.primaryURL
        return isBlueskyURL(url) ? url : nil
    }

    private func isBlueskyURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("bsky.app") || host.contains("bsky.social")
    }

    private var linkCard: some View {
        Button {
            appState.navigate(to: .article(url: linkStatus.primaryURL, status: linkStatus.status))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if let imageURL = linkStatus.imageURL {
                    GeometryReader { geo in
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 220)
                                    .clipped()
                            case .failure:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            case .empty:
                                ProgressView()
                                    .frame(width: geo.size.width, height: 220)
                            @unknown default:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(linkStatus.displayTitle)
                        .font(.roundedTitle3.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    let descriptionText = blueskyDescription ?? linkStatus.displayDescription
                    if let descriptionText, !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(blueskyDescription == nil ? 2 : 8)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.roundedCaption)

                        Text(linkStatus.domain)
                            .font(.roundedCaption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        authorAttributionChip(linkStatus.status.displayStatus.account.displayName)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var placeholderImage: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay {
                Image(systemName: "link")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }

    private func authorAttributionChip(_ authorName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "person.crop.circle")
                .font(.roundedCaption)
            Text(authorName)
                .font(.roundedCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Link(destination: linkStatus.primaryURL) {
            Label("Open in Browser", systemImage: "safari")
        }

        ShareLink(item: linkStatus.primaryURL) {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }

        Button {
            #if os(iOS)
            UIPasteboard.general.url = linkStatus.primaryURL
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(linkStatus.primaryURL.absoluteString, forType: .URL)
            #endif
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }

        Divider()

        if readLaterManager.hasConfiguredServices {
            if let primary = readLaterManager.primaryService, let serviceType = primary.service {
                Button {
                    Task {
                        try? await readLaterManager.save(
                            url: linkStatus.primaryURL,
                            title: linkStatus.title,
                            to: serviceType
                        )
                    }
                } label: {
                    Label("Save to \(serviceType.displayName)", systemImage: "bookmark")
                }
            }

            Menu {
                ForEach(readLaterManager.configuredServices, id: \.id) { config in
                    Button {
                        Task {
                            try? await readLaterManager.save(
                                url: linkStatus.primaryURL,
                                title: linkStatus.title,
                                to: config.service!
                            )
                        }
                    } label: {
                        Label(config.service!.displayName, systemImage: config.service!.iconName)
                    }
                }
            } label: {
                Label("Save to...", systemImage: "bookmark.circle")
            }
        }

        Divider()

        Button {
            appState.present(sheet: .compose(replyTo: linkStatus.status))
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }

        Button {
            appState.present(sheet: .compose(quote: linkStatus.status))
        } label: {
            Label("Quote", systemImage: "quote.bubble")
        }
    }
}

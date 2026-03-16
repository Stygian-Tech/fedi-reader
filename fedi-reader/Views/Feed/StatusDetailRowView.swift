import SwiftUI

enum StatusDetailRowStyle {
    case card
    case embedded
}

struct StatusDetailRowView: View {
    let status: Status
    let style: StatusDetailRowStyle
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false
    @AppStorage("autoPlayGifs") private var autoPlayGifs = false
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue

    @State private var authorAttribution: AuthorAttribution?
    @State private var resolvedAuthorAccount: MastodonAccount?

    init(status: Status, style: StatusDetailRowStyle = .card) {
        self.status = status
        self.style = style
    }

    var displayStatus: Status {
        status.displayStatus
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius, style: .continuous)
    }

    private var cardURL: URL? {
        guard let card = displayStatus.card, (card.type == .link || card.type == .rich) else { return nil }
        return card.linkURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status.isReblog {
                boostAttributionChip
            }

            HStack(spacing: 10) {
                Button {
                    HapticFeedback.play(.navigation)
                    appState.navigate(to: .profile(displayStatus.account))
                } label: {
                    ProfileAvatarView(url: displayStatus.account.avatarURL, size: Constants.UI.avatarSize)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        EmojiText(text: displayStatus.account.displayName, emojis: displayStatus.account.emojis, font: .roundedSubheadline.bold())
                            .lineLimit(1)

                        AccountBadgesView(account: displayStatus.account, size: .small)
                    }
                    if showHandleInFeed {
                        Text("@\(displayStatus.account.acct)")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
            }

            if !displayStatus.spoilerText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    EmojiText(text: displayStatus.spoilerText, emojis: displayStatus.emojis, font: .roundedSubheadline.bold())
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if #available(iOS 15.0, macOS 12.0, *) {
                HashtagLinkText(
                    content: displayStatus.content,
                    onHashtagTap: {
                        HapticFeedback.play(.navigation)
                        appState.navigate(to: .hashtag($0))
                    },
                    emojiLookup: Dictionary(uniqueKeysWithValues: displayStatus.emojis.map { ($0.shortcode, $0) })
                )
                .font(.roundedBody)
            } else {
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedBody)
            }

            if !displayStatus.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayStatus.mediaAttachments) { attachment in
                            mediaAttachmentView(attachment)
                        }
                    }
                }
            }

            if let card = displayStatus.card, card.type == .link {
                Button {
                    if let url = card.linkURL {
                        HapticFeedback.play(.navigation)
                        let pref = ArticleViewerPreference.from(raw: articleViewerPreferenceRaw)
                        switch pref {
                        case .externalBrowser:
                            openURL(url)
                        case .safari:
                            #if os(iOS)
                            appState.present(sheet: .safariView(url: url))
                            #else
                            openURL(url)
                            #endif
                        case .inApp:
                            appState.navigate(to: .article(url: url, status: status))
                        }
                    }
                } label: {
                    LinkCardContent(
                        card: card,
                        authorAttribution: authorAttribution,
                        authorDisplayName: resolvedAuthorAccount?.preferredDisplayName
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .environment(\.openURL, authorLinkOpenURLAction)
                }
                .buttonStyle(.plain)
                .task(id: cardURL?.absoluteString) {
                    guard let url = cardURL else {
                        authorAttribution = nil
                        resolvedAuthorAccount = nil
                        return
                    }

                    authorAttribution = await AttributionChecker.shared.checkAttribution(for: url)
                    resolvedAuthorAccount = await appState.client.resolveProfileAccount(
                        handle: authorAttribution?.mastodonHandle,
                        profileURL: currentAuthorURL(for: card)
                    )
                }
            }

            StatusActionsBar(status: displayStatus, size: .detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(style == .card ? 8 : 0)
        .background {
            if style == .card {
                cardShape
                    .fill(.regularMaterial)
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: style == .card ? Constants.UI.cardCornerRadius : 0,
                style: .continuous
            )
        )
    }
    
    // MARK: - Boost Attribution

    private var boostAttributionChip: some View {
        BoostAttributionChip(account: status.account) {
            HapticFeedback.play(.navigation)
            appState.navigate(to: .profile(status.account))
        }
    }

    @ViewBuilder
    private func mediaAttachmentView(_ attachment: MediaAttachment) -> some View {
        let content = MediaAttachmentThumbnailView(
            attachment: attachment,
            size: CGSize(width: 150, height: 150),
            cornerRadius: 8,
            autoPlayGifs: autoPlayGifs
        )

        let playbackPolicy = MediaAttachmentPlaybackPolicy.resolve(
            for: attachment.type,
            autoPlayGifs: autoPlayGifs
        )

        if playbackPolicy == .explicitVideoPlayback, let videoURL = URL(string: attachment.url) {
            Button {
                appState.present(sheet: .videoPlayer(url: videoURL))
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func currentAuthorURL(for card: PreviewCard) -> URL? {
        authorAttribution?.preferredURL ?? card.authorUrl.flatMap { URL(string: $0) }
    }

    private var authorLinkOpenURLAction: OpenURLAction {
        OpenURLAction { url in
            guard MastodonProfileReference.acct(handle: authorAttribution?.mastodonHandle, profileURL: url) != nil else {
                HapticFeedback.play(.navigation)
                return .systemAction(url)
            }

            HapticFeedback.play(.navigation)
            Task {
                let account = if let resolvedAuthorAccount {
                    resolvedAuthorAccount
                } else {
                    await appState.client.resolveProfileAccount(
                        handle: authorAttribution?.mastodonHandle,
                        profileURL: url
                    )
                }

                if let account {
                    await MainActor.run {
                        resolvedAuthorAccount = account
                        appState.navigate(to: .profile(account))
                    }
                } else {
                    await MainActor.run {
                        openURL(url)
                    }
                }
            }
            return .handled
        }
    }
}

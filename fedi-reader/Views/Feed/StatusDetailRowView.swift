import SwiftUI

struct StatusDetailRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue

    @State private var authorAttribution: AuthorAttribution?
    @State private var resolvedAuthorAccount: MastodonAccount?

    var displayStatus: Status {
        status.displayStatus
    }

    private var cardURL: URL? {
        guard let card = displayStatus.card, (card.type == .link || card.type == .rich) else { return nil }
        return card.linkURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status.isReblog {
                reblogIndicator
            }

            HStack(spacing: 10) {
                Button {
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
                    onHashtagTap: { appState.navigate(to: .hashtag($0)) },
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
                            AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if let card = displayStatus.card, card.type == .link {
                Button {
                    if let url = card.linkURL {
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
        .padding(8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
    
    // MARK: - Reblog Indicator
    
    private var reblogIndicator: some View {
        Button {
            appState.navigate(to: .profile(status.account))
        } label: {
            HStack(spacing: 8) {
                ProfileAvatarView(url: status.account.avatarURL, size: 24)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedCaption2)
                    
                    Text("Boosted by")
                        .font(.roundedCaption)
                    
                    EmojiText(text: status.account.displayName, emojis: status.account.emojis, font: .roundedCaption.bold())
                        .lineLimit(1)
                    
                    AccountBadgesView(account: status.account, size: .small)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func currentAuthorURL(for card: PreviewCard) -> URL? {
        authorAttribution?.preferredURL ?? card.authorUrl.flatMap { URL(string: $0) }
    }

    private var authorLinkOpenURLAction: OpenURLAction {
        OpenURLAction { url in
            guard MastodonProfileReference.acct(handle: authorAttribution?.mastodonHandle, profileURL: url) != nil else {
                return .systemAction(url)
            }

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

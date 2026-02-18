import SwiftUI

struct StatusDetailRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false

    @State private var fediverseCreatorName: String?
    @State private var fediverseCreatorURL: URL?

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
                        appState.navigate(to: .article(url: url, status: status))
                    }
                } label: {
                    LinkCardContent(
                        card: card,
                        fediverseCreatorName: fediverseCreatorName,
                        fediverseCreatorURL: fediverseCreatorURL
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .task(id: cardURL?.absoluteString) {
                    guard let url = cardURL else { return }
                    let creator = await LinkPreviewService.shared.fetchFediverseCreator(for: url)
                    fediverseCreatorName = creator?.name
                    fediverseCreatorURL = creator?.url
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
}



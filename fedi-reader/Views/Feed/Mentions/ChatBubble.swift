import AVKit
import SwiftUI
import os

struct ChatBubble: View {
    let message: ChatMessage
    let account: MastodonAccount
    let isSent: Bool
    let hiddenMentionHandles: Set<String>
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("autoPlayGifs") private var autoPlayGifs = false
    
    var status: Status? {
        message.status
    }
    
    private var mediaAttachments: [MediaAttachment] {
        status?.mediaAttachments.filter { attachment in
            attachment.type == .image || attachment.type == .video || attachment.type == .gifv
        } ?? []
    }
    
    private var hasFavorites: Bool {
        (status?.favouritesCount ?? 0) > 0
    }
    
    private var isFavoritedByMe: Bool {
        status?.favourited == true
    }

    private var displayPlainText: String {
        guard let status else { return "" }
        return DirectMessageMentionFormatter.stripLeadingMentions(
            from: status.content.htmlToPlainText,
            hiddenHandles: hiddenMentionHandles
        )
    }

    private var showsTextContent: Bool {
        !displayPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        if let status = status {
            let embeddedLayout = MessageEmbeddedContentLayoutResolver.resolve(
                from: status,
                hiddenHandles: hiddenMentionHandles
            )

            VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
                if let candidate = embeddedLayout.candidate {
                    embeddedMessageContent(
                        status: status,
                        candidate: candidate,
                        layout: embeddedLayout
                    )
                } else {
                    standardMessageContent(status: status)
                }
            }
            .padding(.bottom, hasFavorites && embeddedLayout.candidate == nil ? 8 : 0) // Extra space for tapback
            .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
            .contextMenu {
                Button {
                    appState.navigate(to: .profile(account))
                } label: {
                    Label("View Profile", systemImage: "person")
                }

                Button {
                    Task {
                        await toggleFavorite(status: status)
                    }
                } label: {
                    Label(
                        isFavoritedByMe ? "Unfavorite Message" : "Favorite Message",
                        systemImage: isFavoritedByMe ? "star.slash" : "star"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func standardMessageContent(status: Status) -> some View {
        Button {
            appState.navigate(to: .status(status))
        } label: {
            VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
                if showsTextContent {
                    messageTextContent(status.content)
                }

                if !mediaAttachments.isEmpty {
                    chatMediaAttachments
                }

                Text(message.createdAt, style: .time)
                    .font(.roundedCaption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(messageBubbleShape.fill(messageBubbleColor))
            .overlay(alignment: isSent ? .bottomLeading : .bottomTrailing) {
                if hasFavorites {
                    TapbackView(count: status.favouritesCount, isMine: isFavoritedByMe)
                        .offset(x: isSent ? -8 : 8, y: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func embeddedMessageContent(
        status: Status,
        candidate: MessageLinkPreviewCandidate,
        layout: MessageEmbeddedContentLayout
    ) -> some View {
        if let leadingContent = layout.leadingContent {
            messageTextBubble(
                content: leadingContent,
                status: status
            )
        }

        MessageLinkPreviewCard(
            status: status,
            candidate: candidate,
            isSent: isSent
        )

        if let trailingContent = layout.trailingContent {
            messageTextBubble(
                content: trailingContent,
                status: status
            )
        }

        if !mediaAttachments.isEmpty {
            Button {
                appState.navigate(to: .status(status))
            } label: {
                chatMediaAttachments
            }
            .buttonStyle(.plain)
        }

        HStack(spacing: 6) {
            Text(message.createdAt, style: .time)
                .font(.roundedCaption2)
                .foregroundStyle(.secondary)

            if hasFavorites {
                TapbackView(count: status.favouritesCount, isMine: isFavoritedByMe)
            }
        }
        .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
    }

    private func toggleFavorite(status: Status) async {
        guard let service = timelineWrapper.service else { return }
        do {
            _ = try await service.setFavorite(status: status, isFavorited: !isFavoritedByMe)
        } catch {
            appState.handleError(error)
        }
    }
    
    private var chatMediaAttachments: some View {
        VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
            ForEach(mediaAttachments) { attachment in
                ChatMediaAttachmentView(
                    attachment: attachment,
                    isSent: isSent,
                    autoPlayGifs: autoPlayGifs
                )
            }
        }
    }

    @ViewBuilder
    private func messageTextContent(_ content: String) -> some View {
        if #available(iOS 15.0, macOS 12.0, *) {
            HashtagLinkText(
                content: content,
                onHashtagTap: { appState.navigate(to: .hashtag($0)) },
                emojiLookup: Dictionary(uniqueKeysWithValues: status?.emojis.map { ($0.shortcode, $0) } ?? []),
                hiddenMentionHandles: hiddenMentionHandles
            )
            .font(.roundedBody)
            .multilineTextAlignment(.leading)
        } else {
            Text(
                DirectMessageMentionFormatter.stripLeadingMentions(
                    from: content.htmlToPlainText,
                    hiddenHandles: hiddenMentionHandles
                )
            )
            .font(.roundedBody)
            .multilineTextAlignment(.leading)
        }
    }

    private func messageTextBubble(content: String, status: Status) -> some View {
        Button {
            appState.navigate(to: .status(status))
        } label: {
            messageTextContent(content)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(messageBubbleShape.fill(messageBubbleColor))
        }
        .buttonStyle(.plain)
    }

    private var messageBubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18)
    }

    private var messageBubbleColor: Color {
        isSent ? ThemeColor.resolved(from: themeColorName).color.opacity(0.2) : Color(.secondarySystemBackground)
    }
}

private struct MessageLinkPreviewCard: View {
    let status: Status
    let candidate: MessageLinkPreviewCandidate
    let isSent: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue

    @State private var linkPreview: LinkPreviewService.LinkPreview?
    @State private var authorAttribution: AuthorAttribution?
    @State private var resolvedAuthorAccount: MastodonAccount?

    private var previewURL: URL? {
        candidate.url
    }

    var body: some View {
        Button {
            openLink(candidate.url)
        } label: {
            linkCardContent(for: candidate)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.clear, in: cardBackgroundShape)
                .clipShape(cardBackgroundShape)
                .environment(\.openURL, authorLinkOpenURLAction)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: maxCardWidth, alignment: isSent ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
        .task(id: previewURL?.absoluteString) {
            await loadPreviewState()
        }
    }

    private var cardBackgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16)
    }

    private var maxCardWidth: CGFloat { 520 }

    private func linkCardContent(for candidate: MessageLinkPreviewCandidate) -> some View {
        let content = MessageLinkPreviewContentResolver.resolve(
            candidate: candidate,
            linkPreview: linkPreview,
            authorAttribution: authorAttribution,
            authorDisplayName: resolvedAuthorAccount?.preferredDisplayName
        )
        return LinkCardContent(
            title: content.title,
            description: content.description,
            imageURL: content.imageURL,
            providerDisplay: content.providerDisplay,
            authorName: content.authorName,
            authorURL: content.authorURL,
            isMastodonAttribution: content.isMastodonAttribution,
            showLinkIcon: content.showLinkIcon,
            layout: .feed
        )
    }

    private func loadPreviewState() async {
        async let fetchedPreview: LinkPreviewService.LinkPreview? = if MessageLinkPreviewContentResolver.shouldFetchPreview(for: candidate) {
            await LinkPreviewService.shared.preview(for: candidate.url)
        } else {
            nil
        }
        async let fetchedAttribution: AuthorAttribution? = AttributionChecker.shared.checkAttribution(for: candidate.url)

        let preview = await fetchedPreview
        let attribution = await fetchedAttribution
        let authorAccount = await appState.client.resolveProfileAccount(
            handle: attribution?.mastodonHandle,
            profileURL: currentAuthorURL(
                for: candidate,
                authorAttribution: attribution,
                linkPreview: preview
            )
        )

        guard !Task.isCancelled else {
            return
        }

        linkPreview = preview
        authorAttribution = attribution
        resolvedAuthorAccount = authorAccount
    }

    private func openLink(_ url: URL) {
        let preference = ArticleViewerPreference.from(raw: articleViewerPreferenceRaw)
        switch preference {
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

    private func currentAuthorURL(
        for candidate: MessageLinkPreviewCandidate,
        authorAttribution: AuthorAttribution?,
        linkPreview: LinkPreviewService.LinkPreview?
    ) -> URL? {
        if let preferredURL = authorAttribution?.preferredURL {
            return preferredURL
        }

        if let cardURL = candidate.card?.authorUrl.flatMap({ URL(string: $0) }) {
            return cardURL
        }

        return linkPreview?.fediverseCreatorURL
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

// MARK: - Chat Media Attachment View

private struct ChatMediaAttachmentView: View {
    let attachment: MediaAttachment
    let isSent: Bool
    let autoPlayGifs: Bool

    private var mediaSize: CGSize {
        MessageMediaLayoutResolver.size(for: attachment)
    }

    private var imageURL: URL? {
        URL(string: attachment.previewUrl ?? attachment.url)
    }

    private var videoURL: URL? {
        (attachment.type == .gifv || attachment.type == .video) ? URL(string: attachment.url) : nil
    }

    private var shouldAutoplayVideo: Bool {
        autoPlayGifs && videoURL != nil
    }

    var body: some View {
        ZStack {
            // Base layer: always show preview/image
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(.tertiary)
            }
            .frame(width: mediaSize.width, height: mediaSize.height)

            // Overlay: video player when autoplay is on
            if shouldAutoplayVideo, let url = videoURL {
                ChatGifvPlayerView(url: url)
                    .frame(width: mediaSize.width, height: mediaSize.height)
            }
        }
        .frame(width: mediaSize.width, height: mediaSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .bottomTrailing) {
            if attachment.type == .video || attachment.type == .gifv {
                Image(systemName: attachment.type == .gifv ? "play.circle" : "video")
                    .font(.roundedCaption)
                    .padding(4)
                    .glassEffect(.clear, in: Circle())
                    .padding(6)
            }
        }
    }
}

// MARK: - Chat GIFV Player View

private struct ChatGifvPlayerView: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .clipped()
                    .onAppear {
                        player.isMuted = true
                        player.play()
                    }
            } else {
                // Transparent until video loads so base AsyncImage preview shows through
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard player == nil else { return }
            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            let loop = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            looper = loop
        }
    }
}

// MARK: - Tapback View (iMessage-style reaction indicator)

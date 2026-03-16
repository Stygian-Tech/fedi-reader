import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let account: MastodonAccount
    let isSent: Bool
    let hiddenMentionHandles: Set<String>
    let showsMetadata: Bool
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
        return displayText(for: status.content)
    }

    private var showsTextContent: Bool {
        !displayPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let bubbleHorizontalInset: CGFloat = 14
    
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
        VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
            bubbleBody(status: status)
            if showsMetadata {
                messageMetadataRow
            }
        }
    }

    @ViewBuilder
    private func embeddedMessageContent(
        status: Status,
        candidate: MessageLinkPreviewCandidate,
        layout: MessageEmbeddedContentLayout
    ) -> some View {
        if let leadingContent = layout.leadingContent {
            messageTextBubble(
                content: leadingContent
            )
        }

        MessageLinkPreviewCard(
            candidate: candidate,
            isSent: isSent
        )

        if let trailingContent = layout.trailingContent {
            messageTextBubble(
                content: trailingContent
            )
        }

        if !mediaAttachments.isEmpty {
            chatMediaAttachments
        }

        if showsMetadata {
            messageMetadataRow
        }
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
                    autoPlayGifs: autoPlayGifs
                )
            }
        }
    }

    private func displayText(for content: String) -> String {
        DirectMessageMentionFormatter.stripLeadingMentions(
            from: content.htmlToPlainText,
            hiddenHandles: hiddenMentionHandles
        )
    }

    private func messageTextContent(_ content: String) -> some View {
        Text(displayText(for: content))
            .font(.roundedBody)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
    }

    private func messageTextBubble(content: String) -> some View {
        messageTextContent(content)
            .padding(.horizontal, bubbleHorizontalInset)
            .padding(.vertical, 10)
            .background(messageBubbleShape.fill(messageBubbleColor))
    }

    @ViewBuilder
    private func bubbleBody(status: Status) -> some View {
        VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
            if showsTextContent {
                messageTextContent(status.content)
            }

            if !mediaAttachments.isEmpty {
                chatMediaAttachments
            }
        }
        .padding(.horizontal, bubbleHorizontalInset)
        .padding(.vertical, 10)
        .background(messageBubbleShape.fill(messageBubbleColor))
    }

    private var messageMetadataRow: some View {
        HStack(spacing: 6) {
            if isSent, hasFavorites {
                TapbackView(count: status?.favouritesCount ?? 0, isMine: isFavoritedByMe)
            }

            Text(message.createdAt, style: .time)
                .font(.roundedCaption2)
                .foregroundStyle(.secondary)

            if !isSent, hasFavorites {
                TapbackView(count: status?.favouritesCount ?? 0, isMine: isFavoritedByMe)
            }
        }
        .padding(.leading, isSent ? 0 : bubbleHorizontalInset)
        .padding(.trailing, isSent ? bubbleHorizontalInset : 0)
        .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
    }

    private var messageBubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18)
    }

    private var messageBubbleColor: Color {
        isSent ? ThemeColor.resolved(from: themeColorName).color.opacity(0.2) : Color(.secondarySystemBackground)
    }
}

private struct MessageLinkPreviewCard: View {
    let candidate: MessageLinkPreviewCandidate
    let isSent: Bool

    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var linkPreview: LinkPreviewService.LinkPreview?
    @State private var authorAttribution: AuthorAttribution?
    @State private var resolvedAuthorAccount: MastodonAccount?

    private var previewURL: URL? {
        candidate.url
    }

    var body: some View {
        linkCardContent(for: candidate)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.clear, in: cardBackgroundShape)
            .clipShape(cardBackgroundShape)
            .environment(\.openURL, authorLinkOpenURLAction)
            .frame(maxWidth: maxCardWidth, alignment: isSent ? .trailing : .leading)
            .frame(maxWidth: .infinity, alignment: isSent ? .trailing : .leading)
            .task(id: previewURL?.absoluteString) {
                await loadPreviewState()
            }
    }

    private var cardBackgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16)
    }

    private var maxCardWidth: CGFloat { 360 }

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
            authorURL: currentAuthorURL(
                for: candidate,
                authorAttribution: authorAttribution,
                linkPreview: linkPreview
            ),
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
    let autoPlayGifs: Bool

    private var mediaSize: CGSize {
        MessageMediaLayoutResolver.size(for: attachment)
    }

    var body: some View {
        MediaAttachmentThumbnailView(
            attachment: attachment,
            size: mediaSize,
            cornerRadius: 12,
            autoPlayGifs: autoPlayGifs
        )
    }
}

// MARK: - Tapback View (iMessage-style reaction indicator)

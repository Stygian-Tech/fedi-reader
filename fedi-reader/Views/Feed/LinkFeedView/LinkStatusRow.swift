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
    let deferPostNavigation: (@escaping () -> Void) -> Void
    let shouldIgnoreTap: () -> Bool
    /// When provided, tapping the link card calls this instead of navigating. Used for 3-column layout.
    var onArticleSelect: ((URL, Status) -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(\.openURL) private var openURL
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue

    @State private var blueskyDescription: String?
    @State private var hasLoadedBlueskyDescription = false
    @State private var localAuthorAttribution: AuthorAttribution?
    @State private var resolvedMastodonAccount: MastodonAccount?
    @State private var isProcessing = false
    @State private var localBookmarked: Bool?
    @State private var isManagingLists = false

    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }
    
    private var isBookmarked: Bool {
        localBookmarked ?? linkStatus.status.displayStatus.bookmarked ?? false
    }

    init(
        linkStatus: LinkStatus,
        deferPostNavigation: @escaping (@escaping () -> Void) -> Void = { action in action() },
        shouldIgnoreTap: @escaping () -> Bool = { false },
        onArticleSelect: ((URL, Status) -> Void)? = nil
    ) {
        self.linkStatus = linkStatus
        self.deferPostNavigation = deferPostNavigation
        self.shouldIgnoreTap = shouldIgnoreTap
        self.onArticleSelect = onArticleSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if linkStatus.status.isReblog {
                reblogGradientStrip
            }

            authorHeader

            linkCard

            let tags = linkStatus.tags
            if !tags.isEmpty {
                TagView(tags: tags) { tag in
                    deferPostNavigation {
                        appState.navigate(to: .hashtag(tag))
                    }
                }
            }

            StatusActionsBar(
                status: linkStatus.status,
                size: .compact,
                shouldIgnoreTap: shouldIgnoreTap
            )

            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !shouldIgnoreTap() else { return }
            deferPostNavigation {
                appState.navigate(to: .status(linkStatus.status))
            }
        }
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            contextMenuContent
        }
        .onReceive(NotificationCenter.default.publisher(for: .statusDidUpdate)) { notification in
            guard let updated = notification.object as? Status else { return }
            if updated.id == linkStatus.status.displayStatus.id {
                localBookmarked = updated.bookmarked
            }
        }
        .sheet(isPresented: $isManagingLists) {
            ListManagementView(account: linkStatus.status.displayStatus.account)
        }
        .task(id: blueskyCardURL?.absoluteString) {
            guard let url = blueskyCardURL, !hasLoadedBlueskyDescription else { return }
            hasLoadedBlueskyDescription = true
            blueskyDescription = await LinkPreviewService.shared.fetchDescription(for: url)
        }
        .task(id: authorAttributionTaskID) {
            await ensureAuthorAttributionLoaded()
        }
    }

    private var reblogGradientStrip: some View {
        let reblogger = linkStatus.status.account
        return HStack(spacing: 8) {
            ProfileAvatarView(url: reblogger.avatarURL, size: 24, placeholderStyle: .light)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedCaption2)

                    Text("Boosted by")
                        .font(.roundedCaption)
                }

                HStack(spacing: 4) {
                    EmojiText(text: reblogger.displayName, emojis: reblogger.emojis, font: .roundedCaption.bold())
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
                    themeColor.opacity(0.35),
                    themeColor.opacity(0.20),
                    themeColor.opacity(0.10),
                    themeColor.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }

    private var authorHeader: some View {
        HStack(spacing: 10) {
            Button {
                deferPostNavigation {
                    appState.navigate(to: .profile(linkStatus.status.displayStatus.account))
                }
            } label: {
                ProfileAvatarView(url: linkStatus.status.displayStatus.account.avatarURL, size: Constants.UI.avatarSize)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    EmojiText(text: linkStatus.status.displayStatus.account.displayName, emojis: linkStatus.status.displayStatus.account.emojis, font: .roundedSubheadline.bold())
                        .lineLimit(1)

                    AccountBadgesView(account: linkStatus.status.displayStatus.account, size: .small)
                }
                if showHandleInFeed {
                    Text("@\(linkStatus.status.displayStatus.account.acct)")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

    private var showsAuthorAttribution: Bool {
        let hasAuthorName = effectiveAuthorAttribution?.preferredName?.isEmpty == false
        let hasAuthorURL = effectiveAuthorAttribution?.preferredURL != nil
        let hasMastodonAttribution = effectiveAuthorAttribution?.mastodonHandle != nil || effectiveAuthorAttribution?.mastodonProfileURL != nil
        return hasAuthorName || hasAuthorURL || hasMastodonAttribution
    }

    private var linkCard: some View {
        Button {
            deferPostNavigation {
                if let onArticleSelect {
                    onArticleSelect(linkStatus.primaryURL, linkStatus.status)
                } else {
                    let pref = ArticleViewerPreference.from(raw: articleViewerPreferenceRaw)
                    switch pref {
                    case .externalBrowser:
                        openURL(linkStatus.primaryURL)
                    case .safari:
                        #if os(iOS)
                        appState.present(sheet: .safariView(url: linkStatus.primaryURL))
                        #else
                        openURL(linkStatus.primaryURL)
                        #endif
                    case .inApp:
                        appState.navigate(to: .article(url: linkStatus.primaryURL, status: linkStatus.status))
                    }
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = linkStatus.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 220, alignment: .top)
                                .clipped()
                        case .failure:
                            placeholderImage
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                        @unknown default:
                            placeholderImage
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(linkStatus.displayTitle)
                        .font(.roundedTitle3.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    if showsAuthorAttribution {
                        authorAttributionView
                    }

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
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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

    // MARK: - Author Attribution
    
    @ViewBuilder
    private var authorAttributionView: some View {
        if showsAuthorAttribution {
            let authorName = resolvedMastodonAccount?.preferredDisplayName
                ?? effectiveAuthorAttribution?.preferredName
                ?? "Author"
            let profilePictureURL = effectiveAuthorAttribution?.profilePictureURL.flatMap { URL(string: $0) }
            let isMastodon = effectiveAuthorAttribution?.mastodonHandle != nil
                || effectiveAuthorAttribution?.mastodonProfileURL != nil
            let showNav = authorURL != nil || effectiveAuthorAttribution?.mastodonHandle != nil

            if showNav {
                Button {
                    deferPostNavigation {
                        handleAuthorAttributionNavigation()
                    }
                } label: {
                    AuthorAttributionView(
                        authorName: authorName,
                        isMastodonAttribution: isMastodon,
                        style: .block(
                            profilePictureURL: profilePictureURL,
                            mastodonHandle: effectiveAuthorAttribution?.mastodonHandle,
                            showNavigationIcon: true
                        )
                    )
                }
                .buttonStyle(.plain)
            } else {
                AuthorAttributionView(
                    authorName: authorName,
                    isMastodonAttribution: isMastodon,
                    style: .block(
                        profilePictureURL: profilePictureURL,
                        mastodonHandle: effectiveAuthorAttribution?.mastodonHandle,
                        showNavigationIcon: false
                    )
                )
            }
        }
    }

    private var authorURL: URL? {
        effectiveAuthorAttribution?.preferredURL
    }

    private var authorResolutionID: String {
        "\(effectiveAuthorAttribution?.mastodonHandle ?? "")|\(authorURL?.absoluteString ?? "")"
    }

    private var authorAttributionTaskID: String {
        "\(linkStatus.id)|\(linkStatus.primaryURL.absoluteString)|\(linkStatus.authorAttribution ?? "")|\(linkStatus.mastodonHandle ?? "")|\(linkStatus.mastodonProfileURL ?? "")"
    }

    private var effectiveAuthorAttribution: AuthorAttribution? {
        localAuthorAttribution ?? linkStatusAuthorAttribution
    }

    private var linkStatusAuthorAttribution: AuthorAttribution? {
        guard linkStatus.authorAttribution != nil
            || linkStatus.authorURL != nil
            || linkStatus.authorProfilePictureURL != nil
            || linkStatus.mastodonHandle != nil
            || linkStatus.mastodonProfileURL != nil else {
            return nil
        }

        return AuthorAttribution(
            name: linkStatus.authorAttribution,
            url: linkStatus.authorURL,
            source: .metaTag,
            mastodonHandle: linkStatus.mastodonHandle,
            mastodonProfileURL: linkStatus.mastodonProfileURL,
            profilePictureURL: linkStatus.authorProfilePictureURL
        )
    }

    private func handleAuthorAttributionNavigation() {
        if let account = resolvedMastodonAccount {
            appState.navigate(to: .profile(account))
            return
        }

        let authorURL = self.authorURL
        let authorHandle = effectiveAuthorAttribution?.mastodonHandle
        Task {
            if let account = await appState.client.resolveProfileAccount(handle: authorHandle, profileURL: authorURL) {
                await MainActor.run {
                    resolvedMastodonAccount = account
                    appState.navigate(to: .profile(account))
                }
            } else if let authorURL {
                await MainActor.run {
                    openURL(authorURL)
                }
            }
        }
    }

    private func preloadResolvedAuthorAccount() async {
        guard resolvedMastodonAccount == nil else { return }
        guard effectiveAuthorAttribution?.mastodonHandle != nil || authorURL != nil else { return }

        if let account = await appState.client.resolveProfileAccount(
            handle: effectiveAuthorAttribution?.mastodonHandle,
            profileURL: authorURL
        ) {
            await MainActor.run {
                resolvedMastodonAccount = account
            }
        }
    }

    private func ensureAuthorAttributionLoaded() async {
        let shouldFetchAttribution = localAuthorAttribution == nil
            && (linkStatusAuthorAttribution == nil
                || linkStatus.mastodonHandle == nil
                || linkStatus.mastodonProfileURL == nil)

        if shouldFetchAttribution,
           let attribution = await AttributionChecker.shared.checkAttribution(for: linkStatus.primaryURL) {
            await MainActor.run {
                localAuthorAttribution = attribution
                linkFilterService.applyAttribution(attribution, toLinkStatusID: linkStatus.id)
            }
        } else if localAuthorAttribution == nil {
            await MainActor.run {
                localAuthorAttribution = linkStatusAuthorAttribution
            }
        }

        await preloadResolvedAuthorAccount()
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
        
        // Bookmark
        Button {
            Task {
                await toggleBookmark()
            }
        } label: {
            Label(
                isBookmarked ? "Remove Bookmark" : "Bookmark",
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            )
        }

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

        Button {
            isManagingLists = true
        } label: {
            Label("Manage Lists", systemImage: "list.bullet")
        }
    }
    
    private func toggleBookmark() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasBookmarked = isBookmarked
        localBookmarked = !wasBookmarked
        
        do {
            let updated = try await service.bookmark(status: linkStatus.status)
            localBookmarked = updated.bookmarked
        } catch {
            localBookmarked = wasBookmarked
            appState.handleError(error)
        }
    }
}

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
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false

    @State private var isShowingActions = false
    @State private var blueskyDescription: String?
    @State private var hasLoadedBlueskyDescription = false
    @State private var resolvedMastodonAccount: MastodonAccount?
    @State private var isProcessing = false
    @State private var localBookmarked: Bool?

    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }
    
    private var isBookmarked: Bool {
        localBookmarked ?? linkStatus.status.displayStatus.bookmarked ?? false
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
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuContent
        }
        .onReceive(NotificationCenter.default.publisher(for: .statusDidUpdate)) { notification in
            guard let updated = notification.object as? Status else { return }
            if updated.id == linkStatus.status.displayStatus.id {
                localBookmarked = updated.bookmarked
            }
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

    private var linkCard: some View {
        Button {
            appState.navigate(to: .article(url: linkStatus.primaryURL, status: linkStatus.status))
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

                    // Prominent author attribution (only if valid author tag exists)
                    if let authorName = linkStatus.authorAttribution, !authorName.isEmpty {
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
        // Show attribution if we have a name, OR if we have a Mastodon handle/profile URL
        let hasAuthorName = linkStatus.authorAttribution != nil && !linkStatus.authorAttribution!.isEmpty
        let hasMastodonAttribution = linkStatus.mastodonHandle != nil || linkStatus.mastodonProfileURL != nil
        
        if hasAuthorName || hasMastodonAttribution {
            let authorName = linkStatus.authorAttribution ?? linkStatus.mastodonHandle ?? "Author"
            let profilePictureURL = linkStatus.authorProfilePictureURL.flatMap { URL(string: $0) }
            let isMastodonProfile = linkStatus.mastodonProfileURL != nil
            let destinationURL: String? = linkStatus.mastodonProfileURL ?? linkStatus.authorURL
            
            if let destinationURL {
                if isMastodonProfile {
                    // Mastodon profile - navigate in-app
                    Button {
                        handleMastodonProfileNavigation(url: destinationURL)
                    } label: {
                        authorAttributionContent(
                            authorName: authorName,
                            profilePictureURL: profilePictureURL,
                            mastodonHandle: linkStatus.mastodonHandle,
                            showNavigationIcon: true
                        )
                    }
                    .buttonStyle(.plain)
                    .task(id: destinationURL) {
                        await resolveMastodonAccount(url: destinationURL)
                    }
                } else if let url = URL(string: destinationURL) {
                    // Regular author URL - open in browser
                    Link(destination: url) {
                        authorAttributionContent(
                            authorName: authorName,
                            profilePictureURL: profilePictureURL,
                            mastodonHandle: linkStatus.mastodonHandle,
                            showNavigationIcon: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    // No valid link, just show attribution
                    authorAttributionContent(
                        authorName: authorName,
                        profilePictureURL: profilePictureURL,
                        mastodonHandle: linkStatus.mastodonHandle,
                        showNavigationIcon: false
                    )
                }
            } else {
                // No link, just show attribution
                authorAttributionContent(
                    authorName: authorName,
                    profilePictureURL: profilePictureURL,
                    mastodonHandle: linkStatus.mastodonHandle,
                    showNavigationIcon: false
                )
            }
        }
    }
    
    private func authorAttributionContent(
        authorName: String,
        profilePictureURL: URL?,
        mastodonHandle: String?,
        showNavigationIcon: Bool
    ) -> some View {
        HStack(spacing: 10) {
            // Profile picture or fallback icon
            if let profilePictureURL {
                ProfileAvatarView(url: profilePictureURL, size: 36, usePersonIconForFallback: true)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Author")
                    .font(.roundedCaption2)
                    .foregroundStyle(.secondary)
                
                Text(authorName)
                    .font(.roundedSubheadline.bold())
                    .lineLimit(1)
                
                if let mastodonHandle {
                    Text(mastodonHandle)
                        .font(.roundedCaption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if showNavigationIcon {
                Image(systemName: "arrow.up.right.square")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground).opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func handleMastodonProfileNavigation(url: String) {
        // If we already resolved the account, use it
        if let account = resolvedMastodonAccount {
            appState.navigate(to: .profile(account))
            return
        }
        
        // Otherwise, try to parse and search for the account
        if let (instance, username) = parseMastodonProfileURL(url) {
            Task {
                await resolveAndNavigateToMastodonAccount(instance: instance, username: username)
            }
        }
    }
    
    private func parseMastodonProfileURL(_ urlString: String) -> (instance: String, username: String)? {
        // Parse URL like https://instance.com/@username
        guard let url = URL(string: urlString),
              let host = url.host else {
            return nil
        }
        
        let path = url.path
        // Remove leading /@
        guard path.hasPrefix("/@") else {
            return nil
        }
        
        let username = String(path.dropFirst(2)) // Remove "/@"
        return (host, username)
    }
    
    private func resolveMastodonAccount(url: String) async {
        guard let (instance, username) = parseMastodonProfileURL(url) else {
            return
        }
        
        await resolveAndNavigateToMastodonAccount(instance: instance, username: username, setState: true)
    }
    
    private func resolveAndNavigateToMastodonAccount(
        instance: String,
        username: String,
        setState: Bool = false
    ) async {
        // Use appState.client for account search
        let client = appState.client
        
        // Try to search for the account
        do {
            let query = "@\(username)@\(instance)"
            let accounts = try await client.searchAccounts(query: query, limit: 1)
            
            if let account = accounts.first,
               account.acct.lowercased() == "\(username)@\(instance)".lowercased() {
                if setState {
                    await MainActor.run {
                        resolvedMastodonAccount = account
                    }
                } else {
                    await MainActor.run {
                        appState.navigate(to: .profile(account))
                    }
                }
            }
        } catch {
            // If search fails, we can't resolve the account
            // The user can still tap to try navigation
        }
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

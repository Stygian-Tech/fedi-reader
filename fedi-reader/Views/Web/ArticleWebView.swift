//
//  ArticleWebView.swift
//  fedi-reader
//
//  Minimal web viewer for articles with action toolbar
//

import SwiftUI
import WebKit

struct ArticleWebView: View {
    let url: URL
    let status: Status
    
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var isLoading = true
    @State private var pageTitle: String?
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webView: WKWebView?
    
    var body: some View {
        WebViewContainer(
            url: url,
            isLoading: $isLoading,
            pageTitle: $pageTitle,
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            webView: $webView
        )
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) {
            actionToolbar
        }
        .navigationTitle(pageTitle ?? url.host ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Navigation
                HStack(spacing: 16) {
                    Button {
                        webView?.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Go back")
                    .accessibilityHint(!canGoBack ? "Back button disabled" : "Returns to previous page")

                    Button {
                        webView?.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Go forward")
                    .accessibilityHint(!canGoForward ? "Forward button disabled" : "Advances to next page")

                    if isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading")
                    } else {
                        Button {
                            webView?.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Reload")
                        .accessibilityHint("Reloads the current page")
                    }
                }
                
                // More options
                Menu {
                    Link(destination: url) {
                        Label("Open in Safari", systemImage: "safari")
                    }
                    
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.url = url
                        #elseif os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .URL)
                        #endif
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }
                    
                    if readLaterManager.hasConfiguredServices {
                        Divider()

                        ForEach(readLaterManager.configuredServices, id: \.id) { config in
                            if let serviceType = config.service {
                                Button {
                                    Task {
                                        try? await readLaterManager.save(
                                            url: url,
                                            title: pageTitle,
                                            to: serviceType
                                        )
                                    }
                                } label: {
                                    Label("Save to \(serviceType.displayName)", systemImage: serviceType.iconName)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
                .accessibilityHint("Open in Safari, share, copy link, or save to read later")
            }
        }
    }

    private var actionToolbar: some View {
        StatusActionsToolbar(status: status)
            .glassEffect(.regular)
            .padding(.horizontal, 5)
            .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview("Article Web View") {
    NavigationStack {
        ArticleWebView(
            url: URL(string: "https://example.com")!,
            status: Status.samplePreview
        )
    }
    .environment(AppState())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

// Preview helper
extension Status {
    static var samplePreview: Status {
        Status(
            id: "preview",
            uri: "https://example.com/status/preview",
            url: "https://example.com/status/preview",
            createdAt: Date(),
            account: MastodonAccount(
                id: "1",
                username: "preview",
                acct: "preview@example.com",
                displayName: "Preview User",
                locked: false,
                bot: false,
                createdAt: Date(),
                note: "",
                url: "https://example.com/@preview",
                avatar: "https://example.com/avatar.png",
                avatarStatic: "https://example.com/avatar.png",
                header: "https://example.com/header.png",
                headerStatic: "https://example.com/header.png",
                followersCount: 0,
                followingCount: 0,
                statusesCount: 0,
                lastStatusAt: nil,
                emojis: [],
                fields: [],
                source: nil
            ),
            content: "<p>Preview content</p>",
            visibility: Visibility.public,
            sensitive: false,
            spoilerText: "",
            mediaAttachments: [],
            mentions: [],
            tags: [],
            emojis: [],
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0,
            application: nil as Application?,
            language: "en",
            reblog: nil,
            card: nil,
            poll: nil,
            quote: nil,
            favourited: false,
            reblogged: false,
            muted: false,
            bookmarked: false,
            pinned: false,
            inReplyToId: nil,
            inReplyToAccountId: nil
        )
    }
}

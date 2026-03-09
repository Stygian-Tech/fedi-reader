//
//  LinkFeedTwoColumnView.swift
//  fedi-reader
//
//  Two-column layout for iPadOS and macOS: pills + posts | article.
//  Reuses LinkFeedContentView for the left column.
//

import SwiftUI

struct LinkFeedTwoColumnView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    let feedTabsOverride: [FeedTabItem]?
    let showsFeedPicker: Bool
    let allowsSwipeNavigation: Bool
    let titleOverride: String?
    let userFilterToolbarPlacement: UserFilterToolbarPlacement

    @State private var selectedArticle: (url: URL, status: Status)?
    @AppStorage("linkFeedTwoColumnPostsWidth") private var persistedPostsWidth: Double = 350
    @AppStorage("useSafariViewer") private var useSafariViewer = false
    @State private var postsWidth: Double = 350

    private static let minPostsWidth: CGFloat = 280
    private static let minArticleWidth: CGFloat = 400
    private static let dividerWidth: CGFloat = 4

    init(
        feedTabsOverride: [FeedTabItem]? = nil,
        showsFeedPicker: Bool = true,
        allowsSwipeNavigation: Bool = true,
        titleOverride: String? = nil,
        userFilterToolbarPlacement: UserFilterToolbarPlacement = .leading
    ) {
        self.feedTabsOverride = feedTabsOverride
        self.showsFeedPicker = showsFeedPicker
        self.allowsSwipeNavigation = allowsSwipeNavigation
        self.titleOverride = titleOverride
        self.userFilterToolbarPlacement = userFilterToolbarPlacement
    }

    private struct TwoColumnLayout {
        let postsWidth: CGFloat
        let articleWidth: CGFloat
        let showsDivider: Bool
        let dividerMaxPostsWidth: CGFloat
    }

    private func sanitizedTotalWidth(_ width: CGFloat) -> CGFloat {
        let fallback = Self.minPostsWidth + Self.minArticleWidth + Self.dividerWidth
        guard width.isFinite, width > 0 else { return fallback }
        return width
    }

    private func resolvedLayout(totalWidth: CGFloat) -> TwoColumnLayout {
        let safeTotalWidth = sanitizedTotalWidth(totalWidth)
        let requiredWidthForResizableSplit = Self.minPostsWidth + Self.minArticleWidth + Self.dividerWidth
        let showsDivider = safeTotalWidth >= requiredWidthForResizableSplit

        let contentWidth = max(
            safeTotalWidth - (showsDivider ? Self.dividerWidth : 0),
            1
        )

        if !showsDivider {
            let posts = max(min(contentWidth * 0.45, contentWidth - 1), 1)
            let article = max(contentWidth - posts, 1)
            return TwoColumnLayout(
                postsWidth: posts,
                articleWidth: article,
                showsDivider: false,
                dividerMaxPostsWidth: posts
            )
        }

        let preferredPostsWidth = CGFloat(postsWidth.isFinite ? postsWidth : Double(Self.minPostsWidth))
        let maxPostsWidth = max(contentWidth - Self.minArticleWidth, Self.minPostsWidth)
        let posts = min(max(preferredPostsWidth, Self.minPostsWidth), maxPostsWidth)
        let article = max(contentWidth - posts, 1)

        return TwoColumnLayout(
            postsWidth: posts,
            articleWidth: article,
            showsDivider: true,
            dividerMaxPostsWidth: maxPostsWidth
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = resolvedLayout(totalWidth: geometry.size.width)

            HStack(spacing: 0) {
                LinkFeedContentView(onArticleSelect: { url, status in
                    #if os(iOS)
                    if useSafariViewer {
                        appState.present(sheet: .safariView(url: url))
                    } else {
                        selectedArticle = (url, status)
                    }
                    #else
                    selectedArticle = (url, status)
                    #endif
                }, feedTabsOverride: feedTabsOverride, showsFeedPicker: showsFeedPicker, allowsSwipeNavigation: allowsSwipeNavigation, titleOverride: titleOverride, userFilterToolbarPlacement: userFilterToolbarPlacement)
                .frame(width: layout.postsWidth)
                .background(Color(.systemBackground))

                if layout.showsDivider {
                    ResizableColumnDivider(
                        width: $postsWidth,
                        minValue: Self.minPostsWidth,
                        maxValue: layout.dividerMaxPostsWidth
                    ) {
                        persistedPostsWidth = postsWidth
                    }
                }

                detailColumn
                    .frame(width: layout.articleWidth)
            }
            .background(Color(.systemBackground))
        }
        .onAppear {
            postsWidth = persistedPostsWidth.isFinite ? persistedPostsWidth : Double(Self.minPostsWidth)
        }
    }

    private var detailColumn: some View {
        Group {
            if let selected = selectedArticle {
                ArticleWebView(url: selected.url, status: selected.status, onClose: { selectedArticle = nil })
            } else {
                ContentUnavailableView {
                    Label("Select an Article", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Tap a link in a post to read the article here.")
                }
            }
        }
    }
}

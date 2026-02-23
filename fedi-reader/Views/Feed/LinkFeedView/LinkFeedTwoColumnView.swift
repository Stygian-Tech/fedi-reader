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

    @State private var selectedArticle: (url: URL, status: Status)?
    @AppStorage("linkFeedTwoColumnPostsWidth") private var persistedPostsWidth: Double = 350
    @State private var postsWidth: Double = 350

    private static let minPostsWidth: CGFloat = 280
    private static let minArticleWidth: CGFloat = 400
    private static let dividerWidth: CGFloat = 4

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
                    selectedArticle = (url, status)
                })
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
                ArticleWebView(url: selected.url, status: selected.status)
                    .overlay(alignment: .topTrailing) {
                        Button {
                            selectedArticle = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(16)
                        .accessibilityLabel("Close article")
                        .accessibilityHint("Closes the article and returns to the empty state")
                    }
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

//
//  LinkFeedPostList.swift
//  fedi-reader
//
//  Reusable post list for link feed. Used by LinkFeedView and LinkFeedThreeColumnView.
//

import SwiftUI

struct LinkFeedPostList: View {
    let statuses: [LinkStatus]
    let isLoading: Bool
    let shouldShowPaginationLoading: Bool
    let deferPostNavigation: (@escaping () -> Void) -> Void
    let shouldBlockPostTaps: () -> Bool
    let onItemAppear: (Int, Int) -> Void
    let onArticleSelect: ((URL, Status) -> Void)?

    @Binding var scrollProxy: ScrollViewProxy?

    var body: some View {
        GlassEffectContainer {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(statuses.enumerated()), id: \.element.id) { index, linkStatus in
                            LinkStatusRow(
                                linkStatus: linkStatus,
                                deferPostNavigation: deferPostNavigation,
                                shouldIgnoreTap: shouldBlockPostTaps,
                                onArticleSelect: onArticleSelect
                            )
                            .id(linkStatus.id)
                            .onAppear {
                                onItemAppear(index, statuses.count)
                            }
                        }

                        if isLoading {
                            loadingRow
                        }

                        if shouldShowPaginationLoading {
                            paginationLoadingRow
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 0)
                    .padding(.bottom, 12)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
                .background(Color(.systemBackground))
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }

    private var paginationLoadingRow: some View {
        HStack(spacing: 10) {
            Spacer()
            ProgressView()
            Text("Loading more posts...")
                .font(.roundedSubheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

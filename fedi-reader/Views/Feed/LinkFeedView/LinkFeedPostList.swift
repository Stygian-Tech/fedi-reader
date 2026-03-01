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
    
    // New: scroll position reporting
    let onFirstVisibleChange: ((String) -> Void)?
    let onListAppear: (() -> Void)?
    
    @State private var rowTopOffsets: [String: CGFloat] = [:]
    @State private var currentFirstVisibleId: String?

    @Binding var scrollProxy: ScrollViewProxy?

    init(
        statuses: [LinkStatus],
        isLoading: Bool,
        shouldShowPaginationLoading: Bool,
        deferPostNavigation: @escaping ((@escaping () -> Void) -> Void),
        shouldBlockPostTaps: @escaping (() -> Bool),
        onItemAppear: @escaping (Int, Int) -> Void,
        onArticleSelect: ((URL, Status) -> Void)? = nil,
        scrollProxy: Binding<ScrollViewProxy?>,
        onFirstVisibleChange: ((String) -> Void)? = nil,
        onListAppear: (() -> Void)? = nil
    ) {
        self.statuses = statuses
        self.isLoading = isLoading
        self.shouldShowPaginationLoading = shouldShowPaginationLoading
        self.deferPostNavigation = deferPostNavigation
        self.shouldBlockPostTaps = shouldBlockPostTaps
        self.onItemAppear = onItemAppear
        self.onArticleSelect = onArticleSelect
        self._scrollProxy = scrollProxy
        self.onFirstVisibleChange = onFirstVisibleChange
        self.onListAppear = onListAppear
    }

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
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .onChange(of: geo.frame(in: .named("feedScroll")).minY) { _, newMinY in
                                            rowTopOffsets[linkStatus.id] = newMinY
                                            reportFirstVisibleIfNeeded()
                                        }
                                }
                            )
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
                .coordinateSpace(name: "feedScroll")
                .onAppear {
                    scrollProxy = proxy
                    onListAppear?()
                    reportFirstVisibleIfNeeded()
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
    
    private func reportFirstVisibleIfNeeded() {
        guard !rowTopOffsets.isEmpty else { return }
        let visibleCandidate = rowTopOffsets
            .filter { $0.value >= 0 }
            .min(by: { $0.value < $1.value })
        let candidate = visibleCandidate
            ?? rowTopOffsets
                .filter { $0.value < 0 }
                .max(by: { $0.value < $1.value })
        guard let (id, _) = candidate else { return }
        if currentFirstVisibleId != id {
            currentFirstVisibleId = id
            onFirstVisibleChange?(id)
        }
    }
}

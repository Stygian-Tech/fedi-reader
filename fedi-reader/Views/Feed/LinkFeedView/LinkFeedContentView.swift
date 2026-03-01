//
//  LinkFeedContentView.swift
//  fedi-reader
//
//  Shared pills + feed content used by LinkFeedView (single column) and LinkFeedTwoColumnView.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

enum HorizontalListPickerGestureFilter {
    static func shouldBlockVerticalPan(velocity: CGPoint) -> Bool {
        abs(velocity.y) > abs(velocity.x)
    }
}

#if os(iOS)
private struct HorizontalListPickerScrollProtector: UIViewRepresentable {
    typealias UIViewType = UIView

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: UIViewRepresentableContext<HorizontalListPickerScrollProtector>) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<HorizontalListPickerScrollProtector>) {
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var scrollView: UIScrollView?
        private weak var blockerRecognizer: UIPanGestureRecognizer?

        func attachIfNeeded(from view: UIView) {
            guard let scrollView = enclosingScrollView(from: view) else {
                return
            }

            configure(scrollView)
        }

        private func enclosingScrollView(from view: UIView) -> UIScrollView? {
            var candidate = view.superview
            while let currentView = candidate {
                if let scrollView = currentView as? UIScrollView {
                    return scrollView
                }
                candidate = currentView.superview
            }
            return nil
        }

        private func configure(_ scrollView: UIScrollView) {
            scrollView.alwaysBounceVertical = false
            scrollView.showsVerticalScrollIndicator = false

            guard self.scrollView !== scrollView else { return }

            if let blockerRecognizer, let previousScrollView = self.scrollView {
                previousScrollView.removeGestureRecognizer(blockerRecognizer)
            }

            let blockerRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleVerticalPan))
            blockerRecognizer.cancelsTouchesInView = true
            blockerRecognizer.delegate = self
            scrollView.addGestureRecognizer(blockerRecognizer)
            scrollView.panGestureRecognizer.require(toFail: blockerRecognizer)

            self.scrollView = scrollView
            self.blockerRecognizer = blockerRecognizer
        }

        @objc
        private func handleVerticalPan(_ gestureRecognizer: UIPanGestureRecognizer) {}

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }

            let velocity = panGestureRecognizer.velocity(in: panGestureRecognizer.view)
            return HorizontalListPickerGestureFilter.shouldBlockVerticalPan(velocity: velocity)
        }
    }
}
#endif

/// Reusable pills and feed content. When `onArticleSelect` is non-nil, articles open inline (two-column).
/// When nil, articles push via parent's NavigationStack (single column).
struct LinkFeedContentView: View {
    private static let pickerHeight: CGFloat = 44

    var onArticleSelect: ((URL, Status) -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    @State private var selectedTabIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isPaginating = false
    @State private var isHorizontalSwipeIntentActive = false
    @State private var postSwipeTapSuppressionDeadline: TimeInterval = 0
    @State private var retainedLists: [MastodonList] = []
    @State private var feedTabSelectionTracker = SelectionDoubleTapTracker<String>()
    @State private var tabFrames: [Int: CGRect] = [:]
    @State private var hasRestoredScrollForCurrentTab: Bool = false

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var accountId: String? {
        appState.currentAccount?.id
    }

    private var liveLists: [MastodonList] {
        timelineService?.lists ?? []
    }

    private var cachedLists: [MastodonList] {
        timelineWrapper.cachedLists(for: accountId)
    }

    private var lists: [MastodonList] {
        if !liveLists.isEmpty {
            return liveLists
        }
        if !retainedLists.isEmpty {
            return retainedLists
        }
        return cachedLists
    }

    private var feedTabs: [FeedTabItem] {
        var tabs = [FeedTabItem.home]
        tabs.append(contentsOf: lists.map { FeedTabItem(id: $0.id, title: $0.title) })
        return tabs
    }

    private var currentTab: FeedTabItem {
        guard selectedTabIndex >= 0, selectedTabIndex < feedTabs.count else {
            return .home
        }
        return feedTabs[selectedTabIndex]
    }

    private var currentAccounts: [MastodonAccount] {
        linkFilterService.uniqueAccounts()
    }

    private var currentUserFilter: String? {
        appState.userFilterPerFeedId[currentTab.id]
    }

    private var filteredStatuses: [LinkStatus] {
        var statuses = linkFilterService.linkStatuses
        statuses = linkFilterService.filter(linkStatuses: statuses, byAccountId: currentUserFilter)
        return statuses
    }

    private func shouldShowPaginationLoadingRow(for statuses: [LinkStatus]) -> Bool {
        (isPaginating || timelineService?.isLoadingMore == true) && !statuses.isEmpty
    }

    private var shouldBlockPostTaps: Bool {
        isHorizontalSwipeIntentActive || Date().timeIntervalSinceReferenceDate < postSwipeTapSuppressionDeadline
    }

    var body: some View {
        @Bindable var state = appState
        let statuses = filteredStatuses

        feedStack(statuses: statuses)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appState.linksScrollToTopRequestID) { _, _ in
            scrollToTop()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.isUserFilterOpen = true
                } label: {
                    Image(systemName: currentUserFilter != nil ? "person.fill" : "person.2")
                }
                .accessibilityLabel(currentUserFilter != nil ? "User filter active" : "Filter by user")
                .accessibilityHint("Opens user filter pane")
            }
            ToolbarItem(placement: .principal) {
                listPickerHeader
            }
        }
        .sheet(isPresented: $state.isUserFilterOpen) {
                UserFilterPane(
                    feedId: currentTab.id,
                    accounts: currentAccounts,
                    onSelectAccount: { account in
                        if let id = account?.id {
                            appState.userFilterPerFeedId[currentTab.id] = id
                        } else {
                            appState.userFilterPerFeedId.removeValue(forKey: currentTab.id)
                        }
                        appState.isUserFilterOpen = false
                    }
                )
                .presentationDetents([.medium, .large])
        }
        .task {
            await loadInitialContent()
        }
        .onChange(of: selectedTabIndex) { _, newIndex in
            handleTabChange(to: newIndex)
        }
        .onChange(of: appState.selectedListId) { _, newListId in
            let targetId = newListId ?? AppState.homeFeedID
            if let index = feedTabs.firstIndex(where: { $0.id == targetId }), selectedTabIndex != index {
                selectedTabIndex = index
            }
        }
        .onChange(of: feedTabs.map(\.id)) { _, tabIds in
            guard !tabIds.isEmpty else {
                selectedTabIndex = 0
                return
            }
            if selectedTabIndex >= tabIds.count {
                selectedTabIndex = 0
            }
        }
        .onChange(of: liveLists) { _, newLists in
            syncRetainedLists(with: newLists, allowEmpty: false)
        }
        .onChange(of: timelineService?.isLoadingLists ?? false) { oldValue, isLoading in
            guard oldValue, !isLoading else { return }
            syncRetainedLists(
                with: liveLists,
                allowEmpty: timelineService?.error == nil
            )
        }
        .refreshable {
            await refreshCurrentFeed()
        }
        .onAppear {
            if retainedLists.isEmpty, !cachedLists.isEmpty {
                retainedLists = cachedLists
            }
            syncRetainedLists(with: liveLists, allowEmpty: false)
            // Attempt to restore scroll to last seen item when returning
            attemptRestoreScrollIfNeeded()
        }
        .onDisappear {
            hasRestoredScrollForCurrentTab = false
            isHorizontalSwipeIntentActive = false
            postSwipeTapSuppressionDeadline = 0
        }
    }

    @ViewBuilder
    private func feedStack(statuses: [LinkStatus]) -> some View {
        Group {
            if statuses.isEmpty, !linkFilterService.isLoading {
                emptyStateView
            } else {
                linkList(statuses: statuses)
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity)
        .id(currentTab.id)
        .simultaneousGesture(
            DragGesture(minimumDistance: FeedSwipeGestureEvaluator.horizontalIntentDistance)
                .onChanged { value in
                    guard !isHorizontalSwipeIntentActive else { return }
                    if FeedSwipeGestureEvaluator.isHorizontalIntent(translation: value.translation) {
                        isHorizontalSwipeIntentActive = true
                    }
                }
                .onEnded { value in
                    defer { isHorizontalSwipeIntentActive = false }
                    let direction = FeedSwipeGestureEvaluator.shouldCommit(
                        translation: value.translation,
                        predictedEndTranslation: value.predictedEndTranslation
                    )
                    switch direction {
                    case .previous:
                        selectTab(at: selectedTabIndex - 1)
                    case .next:
                        selectTab(at: selectedTabIndex + 1)
                    case .none:
                        break
                    }
                    if isHorizontalSwipeIntentActive || direction != .none || FeedSwipeGestureEvaluator.shouldSuppressTapAfterGesture(translation: value.translation) {
                        suppressPostSwipeTaps()
                    }
                }
        )
        .background(Color(.systemBackground))
    }

    private func linkList(statuses: [LinkStatus]) -> some View {
        let canLoadMore = currentTab.isHome
            ? (timelineService?.canLoadMoreHomeTimeline() ?? false)
            : (timelineService?.canLoadMoreListTimeline() ?? false)
        return LinkFeedPostList(
            statuses: statuses,
            isLoading: linkFilterService.isLoading,
            shouldShowPaginationLoading: shouldShowPaginationLoadingRow(for: statuses),
            canLoadMore: canLoadMore,
            deferPostNavigation: { action in
                guard !shouldBlockPostTaps else { return }
                action()
            },
            shouldBlockPostTaps: { shouldBlockPostTaps },
            onItemAppear: { index, totalCount in
                checkLoadMore(at: index, totalCount: totalCount)
            },
            onArticleSelect: onArticleSelect,
            scrollProxy: $scrollProxy,
            onFirstVisibleChange: { statusId in
                appState.linksLastVisibleStatusIdPerFeed[currentTab.id] = statusId
            },
            onListAppear: {
                // When the list appears (e.g., popped back from article), try to restore once
                attemptRestoreScrollIfNeeded()
            },
            onLoadMoreAtBottom: { requestLoadMore() }
        )
    }

    private var listPickerHeader: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 4) {
                        ForEach(Array(feedTabs.enumerated()), id: \.element.id) { index, tab in
                            FeedTabButton(
                                title: tab.title,
                                isSelected: selectedTabIndex == index,
                                pillNamespace: nil
                            ) {
                                handleTabTap(at: index)
                            }
                            .background {
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TabFramePreferenceKey.self,
                                        value: [index: geo.frame(in: .named("tabPillSpace"))]
                                    )
                                }
                            }
                            .id(tab.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    if let frame = tabFrames[selectedTabIndex] {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                            .allowsHitTesting(false)
                    }
                }
                .coordinateSpace(name: "tabPillSpace")
                .onPreferenceChange(TabFramePreferenceKey.self) { frames in
                    tabFrames = frames
                }
                #if os(iOS)
                .background(HorizontalListPickerScrollProtector())
                #endif
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .onAppear {
                if selectedTabIndex < feedTabs.count {
                    proxy.scrollTo(feedTabs[selectedTabIndex].id, anchor: .center)
                }
            }
            .onChange(of: selectedTabIndex) { _, newIndex in
                if newIndex < feedTabs.count {
                    proxy.scrollTo(feedTabs[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.pickerHeight, maxHeight: Self.pickerHeight, alignment: .leading)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Links Yet", systemImage: "link.badge.plus")
        } description: {
            Text("Posts with links from your \(currentTab.isHome ? "home timeline" : "list") will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await refreshCurrentFeed()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func suppressPostSwipeTaps() {
        let suppressionSeconds = Double(FeedSwipeGestureEvaluator.postSwipeSuppressionNanoseconds) / 1_000_000_000
        postSwipeTapSuppressionDeadline = Date().timeIntervalSinceReferenceDate + suppressionSeconds
    }

    private func selectTab(at index: Int) {
        guard index >= 0, index < feedTabs.count, index != selectedTabIndex else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTabIndex = index
        }
    }

    private func handleTabTap(at index: Int) {
        guard index >= 0, index < feedTabs.count else { return }

        let tab = feedTabs[index]
        let isSelected = index == selectedTabIndex
        let isDoubleTap = feedTabSelectionTracker.recordSelection(tab.id)

        if isSelected, isDoubleTap {
            HapticFeedback.play(.medium, enabled: hapticFeedback)
            appState.requestLinksScrollToTop()
            return
        }

        selectTab(at: index)
    }

    private func handleTabChange(to newIndex: Int) {
        hasRestoredScrollForCurrentTab = false
        guard newIndex >= 0, newIndex < feedTabs.count else { return }

        let tab = feedTabs[newIndex]
        let listId = tab.isHome ? nil : tab.id

        if appState.selectedListId != listId {
            appState.selectedListId = listId
        }
        linkFilterService.switchToFeed(tab.id)

        Task {
            await loadContentForTabIfNeeded(tab)
            let allFeedIDs = feedTabs.map(\.id)
            Task(priority: .background) {
                await prefetchAdjacentFeeds(currentFeedId: tab.id, allFeedIds: allFeedIDs)
            }
        }
    }

    private func scrollToTop() {
        guard let proxy = scrollProxy, !filteredStatuses.isEmpty else { return }
        HapticFeedback.prepare(.medium)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let firstStatus = filteredStatuses.first {
                proxy.scrollTo(firstStatus.id, anchor: .top)
            }
        }
    }

    private func checkLoadMore(at index: Int, totalCount: Int) {
        guard let service = timelineService else { return }
        guard !isPaginating, !service.isLoadingMore else { return }

        if index >= totalCount - Constants.Pagination.prefetchThreshold {
            requestLoadMore()
        }
    }

    private func requestLoadMore() {
        guard let service = timelineService else { return }
        guard !isPaginating, !service.isLoadingMore else { return }

        let tab = currentTab
        let canLoadMore = tab.isHome ? service.canLoadMoreHomeTimeline() : service.canLoadMoreListTimeline()
        guard canLoadMore else { return }

        isPaginating = true
        Task {
            await loadMoreForCurrentTab(tab, using: service)
        }
    }

    private func syncRetainedLists(with incomingLists: [MastodonList], allowEmpty: Bool) {
        if incomingLists.isEmpty {
            guard allowEmpty else { return }
            if !retainedLists.isEmpty {
                retainedLists = []
            }
            return
        }

        if retainedLists != incomingLists {
            retainedLists = incomingLists
        }
        if cachedLists != incomingLists {
            timelineWrapper.updateCachedLists(incomingLists, for: accountId)
        }
    }

    private func loadInitialContent() async {
        await timelineWrapper.waitForStartupLinkFeedLoad()
        guard let service = timelineService else { return }

        await service.loadLists(forceRefresh: liveLists.isEmpty)
        syncRetainedLists(with: service.lists, allowEmpty: service.error == nil)

        if let index = feedTabs.firstIndex(where: { $0.id == appState.selectedLinkFeedID }) {
            selectedTabIndex = index
        }

        linkFilterService.switchToFeed(currentTab.id)

        if linkFilterService.hasCachedContent(for: currentTab.id) {
            Task {
                await linkFilterService.enrichWithAttributions()
            }
        } else {
            await loadContentForTab(currentTab, forceRefresh: true)
        }

        let currentFeedID = currentTab.id
        let allFeedIDs = feedTabs.map(\.id)
        Task(priority: .background) {
            await prefetchAdjacentFeeds(currentFeedId: currentFeedID, allFeedIds: allFeedIDs)
        }
    }

    private func loadContentForTab(_ tab: FeedTabItem, forceRefresh: Bool = false) async {
        guard let service = timelineService else { return }

        linkFilterService.switchToFeed(tab.id)
        let statuses = await service.loadLinkFeedStatuses(feedId: tab.id, forceRefreshHome: forceRefresh)
        _ = await linkFilterService.processStatuses(statuses, for: tab.id)
        Task {
            await linkFilterService.enrichWithAttributions()
        }
    }

    private func loadContentForTabIfNeeded(_ tab: FeedTabItem) async {
        guard !linkFilterService.hasCachedContent(for: tab.id) else { return }
        await loadContentForTab(tab)
    }

    private func refreshCurrentFeed() async {
        guard let service = timelineService else { return }
        let tab = currentTab

        if tab.isHome {
            await service.refreshHomeTimeline()
            _ = await linkFilterService.processStatuses(service.homeTimeline, for: tab.id)
        } else {
            await service.refreshListTimeline(listId: tab.id)
            _ = await linkFilterService.processStatuses(service.listTimeline, for: tab.id)
        }
        Task {
            await linkFilterService.enrichWithAttributions()
        }
    }

    private func prefetchAdjacentFeeds(currentFeedId: String, allFeedIds: [String]) async {
        guard let service = timelineWrapper.service else { return }
        await linkFilterService.prefetchAdjacentFeeds(
            currentFeedId: currentFeedId,
            allFeedIds: allFeedIds
        ) { feedId in
            await service.prefetchLinkFeedStatuses(feedId: feedId)
        }
    }

    @MainActor
    private func loadMoreForCurrentTab(_ tab: FeedTabItem, using service: TimelineService) async {
        defer { isPaginating = false }

        let loadMore: () async -> [Status] = {
            if tab.isHome {
                return await service.loadMoreHomeTimeline()
            } else {
                return await service.loadMoreListTimeline(listId: tab.id)
            }
        }
        let canLoadMore: () -> Bool = {
            tab.isHome ? service.canLoadMoreHomeTimeline() : service.canLoadMoreListTimeline()
        }

        // Keep fetching until we add link posts or exhaust the API (link feed can get batches with 0 links)
        var previousLinkCount = linkFilterService.getCachedContent(for: tab.id).count
        while canLoadMore() {
            let newStatuses = await loadMore()
            guard !newStatuses.isEmpty else { break }

            _ = await linkFilterService.appendStatuses(newStatuses, for: tab.id)
            let newLinkCount = linkFilterService.getCachedContent(for: tab.id).count
            if newLinkCount > previousLinkCount { break }
            previousLinkCount = newLinkCount
        }
    }

    // MARK: - Scroll Position Preservation

    private func attemptRestoreScrollIfNeeded() {
        guard let proxy = scrollProxy else { return }
        guard !hasRestoredScrollForCurrentTab else { return }
        let feedId = currentTab.id
        guard let statusId = appState.linksLastVisibleStatusIdPerFeed[feedId] else { return }
        // Avoid animating to reduce visual jump
        DispatchQueue.main.async {
            withAnimation(nil) {
                proxy.scrollTo(statusId, anchor: .top)
            }
            hasRestoredScrollForCurrentTab = true
        }
    }
}

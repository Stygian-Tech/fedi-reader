//
//  LinkFeedContentView.swift
//  fedi-reader
//
//  Shared pills + feed content used by LinkFeedView (single column) and LinkFeedTwoColumnView.
//

import SwiftUI

private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

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
            let targetId = newListId ?? "home"
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
        LinkFeedPostList(
            statuses: statuses,
            isLoading: linkFilterService.isLoading,
            shouldShowPaginationLoading: shouldShowPaginationLoadingRow(for: statuses),
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
            }
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
            }
            .scrollBounceBehavior(.basedOnSize)
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
            Task.detached(priority: .background) { [feedTabs] in
                await prefetchAdjacentFeeds(currentIndex: newIndex, tabs: feedTabs)
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

        if index >= totalCount - (Constants.Pagination.prefetchThreshold * 2) {
            let tab = currentTab
            let canLoadMore = tab.isHome ? service.canLoadMoreHomeTimeline() : service.canLoadMoreListTimeline()
            guard canLoadMore else { return }

            isPaginating = true
            Task {
                await loadMoreForCurrentTab(tab, using: service)
            }
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
        guard let service = timelineService else { return }

        await service.loadLists(forceRefresh: liveLists.isEmpty)
        syncRetainedLists(with: service.lists, allowEmpty: service.error == nil)

        if let listId = appState.selectedListId,
           let index = feedTabs.firstIndex(where: { $0.id == listId }) {
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

        Task.detached(priority: .background) { [feedTabs, selectedTabIndex] in
            await prefetchAdjacentFeeds(currentIndex: selectedTabIndex, tabs: feedTabs)
        }
    }

    private func loadContentForTab(_ tab: FeedTabItem, forceRefresh: Bool = false) async {
        guard let service = timelineService else { return }

        linkFilterService.switchToFeed(tab.id)

        if tab.isHome {
            if forceRefresh || service.homeTimeline.isEmpty {
                await service.refreshHomeTimeline()
            }
            _ = await linkFilterService.processStatuses(service.homeTimeline, for: tab.id)
        } else {
            await service.refreshListTimeline(listId: tab.id)
            _ = await linkFilterService.processStatuses(service.listTimeline, for: tab.id)
        }
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

    private func prefetchAdjacentFeeds(currentIndex: Int, tabs: [FeedTabItem]) async {
        guard let service = timelineWrapper.service else { return }

        var indicesToPrefetch: [Int] = []
        if currentIndex > 0 { indicesToPrefetch.append(currentIndex - 1) }
        if currentIndex < tabs.count - 1 { indicesToPrefetch.append(currentIndex + 1) }

        for index in indicesToPrefetch {
            let tab = tabs[index]
            guard !linkFilterService.hasCachedContent(for: tab.id),
                  !linkFilterService.isLoadingFeed(tab.id) else { continue }

            if tab.isHome {
                if service.homeTimeline.isEmpty {
                    await service.refreshHomeTimeline()
                }
                _ = await linkFilterService.processStatuses(service.homeTimeline, for: tab.id)
            } else {
                let statuses = await service.fetchListTimelineStatuses(listId: tab.id)
                if !statuses.isEmpty {
                    _ = await linkFilterService.processStatuses(statuses, for: tab.id)
                }
            }
        }
    }

    @MainActor
    private func loadMoreForCurrentTab(_ tab: FeedTabItem, using service: TimelineService) async {
        defer { isPaginating = false }

        if tab.isHome {
            let newStatuses = await service.loadMoreHomeTimeline()
            guard !newStatuses.isEmpty else { return }
            _ = await linkFilterService.appendStatuses(newStatuses, for: tab.id)
        } else {
            let newStatuses = await service.loadMoreListTimeline(listId: tab.id)
            guard !newStatuses.isEmpty else { return }
            _ = await linkFilterService.appendStatuses(newStatuses, for: tab.id)
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

//
//  LinkFeedThreeColumnView.swift
//  fedi-reader
//
//  Three-column layout for iPadOS and macOS: lists | posts | article/empty.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LinkFeedThreeColumnView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.layoutMode) private var layoutMode
    @AppStorage(PrivateMentionsFeedFilter.storageKey)
    private var filterPrivateMentionsFromFeeds = PrivateMentionsFeedFilter.defaultValue

    @State private var selectedTabIndex: Int = 0
    @State private var selectedArticle: (url: URL, status: Status)?
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue
    @State private var scrollProxy: ScrollViewProxy?
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("threeColumnListsWidth") private var persistedListsWidth: Double = 200
    @AppStorage("threeColumnPostsWidth") private var persistedPostsWidth: Double = 300
    @State private var listsWidth: Double = 200
    @State private var postsWidth: Double = 300
    @State private var isPaginating = false
    @State private var retainedLists: [MastodonList] = []
    @State private var feedTabSelectionTracker = SelectionDoubleTapTracker<String>()
    @State private var hasRestoredScrollForCurrentTab = false

    private static let minListsWidth: CGFloat = 150
    private static let minPostsWidth: CGFloat = 200
    private static let minArticleWidth: CGFloat = 400
    private static let dividerWidth: CGFloat = 4
    private static let dividerCount: CGFloat = 2

    private var sidebarTopPadding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad ? 0 : WindowChromeLayoutMetrics.defaultTopPadding
        #else
        WindowChromeLayoutMetrics.defaultTopPadding
        #endif
    }

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

    private var rawLists: [MastodonList] {
        if !liveLists.isEmpty {
            return liveLists
        }
        if !retainedLists.isEmpty {
            return retainedLists
        }
        return cachedLists
    }

    private var feedTabs: [FeedTabItem] {
        appState.feedTabs(from: rawLists)
    }

    private var currentTab: FeedTabItem {
        guard selectedTabIndex >= 0, selectedTabIndex < feedTabs.count else {
            return .home
        }
        return feedTabs[selectedTabIndex]
    }

    private var currentAccounts: [MastodonAccount] {
        FeedScopedLinkData.accounts(
            in: linkFilterService,
            feedId: currentTab.id,
            filterPrivateMentionsFromFeeds: filterPrivateMentionsFromFeeds
        )
    }

    private var currentUserFilter: String? {
        appState.userFilterPerFeedId[currentTab.id]
    }

    private var filteredStatuses: [LinkStatus] {
        FeedScopedLinkData.filteredStatuses(
            in: linkFilterService,
            feedId: currentTab.id,
            userFilterAccountId: currentUserFilter,
            filterPrivateMentionsFromFeeds: filterPrivateMentionsFromFeeds
        )
    }

    private func shouldShowPaginationLoadingRow(for statuses: [LinkStatus]) -> Bool {
        (isPaginating || timelineService?.isLoadingMore == true) && !statuses.isEmpty
    }

    private struct ThreeColumnLayout {
        let listsWidth: CGFloat
        let postsWidth: CGFloat
        let articleWidth: CGFloat
        let showsDividers: Bool
        let firstDividerMaxListsWidth: CGFloat
        let secondDividerMaxPostsWidth: CGFloat
    }

    private func sanitizedTotalWidth(_ width: CGFloat) -> CGFloat {
        let fallback =
            Self.minListsWidth + Self.minPostsWidth + Self.minArticleWidth + (Self.dividerWidth * Self.dividerCount)
        guard width.isFinite, width > 0 else { return fallback }
        return width
    }

    private func resolvedLayout(totalWidth: CGFloat) -> ThreeColumnLayout {
        let safeTotalWidth = sanitizedTotalWidth(totalWidth)
        let requiredWidthForResizableLayout =
            Self.minListsWidth + Self.minPostsWidth + Self.minArticleWidth + (Self.dividerWidth * Self.dividerCount)
        let showsDividers = safeTotalWidth >= requiredWidthForResizableLayout

        let contentWidth = max(safeTotalWidth - (showsDividers ? (Self.dividerWidth * Self.dividerCount) : 0), 1)

        if !showsDividers {
            let lists = max(min(contentWidth * 0.2, contentWidth - 2), 1)
            let posts = max(min(contentWidth * 0.35, contentWidth - lists - 1), 1)
            let article = max(contentWidth - lists - posts, 1)
            return ThreeColumnLayout(
                listsWidth: lists,
                postsWidth: posts,
                articleWidth: article,
                showsDividers: false,
                firstDividerMaxListsWidth: lists,
                secondDividerMaxPostsWidth: posts
            )
        }

        let preferredListsWidth = CGFloat(listsWidth.isFinite ? listsWidth : Double(Self.minListsWidth))
        let maxListsWidth = max(contentWidth - Self.minPostsWidth - Self.minArticleWidth, Self.minListsWidth)
        let resolvedListsWidth = min(max(preferredListsWidth, Self.minListsWidth), maxListsWidth)

        let preferredPostsWidth = CGFloat(postsWidth.isFinite ? postsWidth : Double(Self.minPostsWidth))
        let maxPostsWidth = max(contentWidth - resolvedListsWidth - Self.minArticleWidth, Self.minPostsWidth)
        let resolvedPostsWidth = min(max(preferredPostsWidth, Self.minPostsWidth), maxPostsWidth)

        let resolvedArticleWidth = max(contentWidth - resolvedListsWidth - resolvedPostsWidth, 1)

        return ThreeColumnLayout(
            listsWidth: resolvedListsWidth,
            postsWidth: resolvedPostsWidth,
            articleWidth: resolvedArticleWidth,
            showsDividers: true,
            firstDividerMaxListsWidth: maxListsWidth,
            secondDividerMaxPostsWidth: maxPostsWidth
        )
    }

    var body: some View {
        @Bindable var state = appState

        GeometryReader { geometry in
            let layout = resolvedLayout(totalWidth: geometry.size.width)

            HStack(spacing: 0) {
                // Column 1: Lists
                listsColumn
                    .frame(width: layout.listsWidth)
                    .zIndex(1)

                if layout.showsDividers {
                    ResizableColumnDivider(
                        width: $listsWidth,
                        minValue: Self.minListsWidth,
                        maxValue: layout.firstDividerMaxListsWidth
                    ) {
                        persistedListsWidth = listsWidth
                    }
                }

                // Column 2: Posts
                postsColumnContent(statuses: filteredStatuses)
                    .frame(width: layout.postsWidth)

                if layout.showsDividers {
                    ResizableColumnDivider(
                        width: $postsWidth,
                        minValue: Self.minPostsWidth,
                        maxValue: layout.secondDividerMaxPostsWidth
                    ) {
                        persistedPostsWidth = postsWidth
                    }
                }

                // Column 3: Article
                detailColumn
                    .frame(width: layout.articleWidth)
            }
        }
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
        .onAppear {
            listsWidth = persistedListsWidth.isFinite ? persistedListsWidth : Double(Self.minListsWidth)
            postsWidth = persistedPostsWidth.isFinite ? persistedPostsWidth : Double(Self.minPostsWidth)
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
        .onChange(of: feedTabs.map(\.id)) { _, tabIDs in
            guard !tabIDs.isEmpty else {
                selectedTabIndex = 0
                return
            }
            let targetTabID = tabIDs.contains(appState.selectedLinkFeedID)
                ? appState.selectedLinkFeedID
                : AppState.homeFeedID
            if let index = feedTabs.firstIndex(where: { $0.id == targetTabID }) {
                selectedTabIndex = index
            } else {
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
            appState.synchronizeCurrentAccountListDisplayPreferences(with: rawLists)
            syncRetainedLists(with: liveLists, allowEmpty: false)
            attemptRestoreScrollIfNeeded()
        }
        .onDisappear {
            hasRestoredScrollForCurrentTab = false
        }
    }

    // MARK: - Column 1: Lists

    private var listsColumn: some View {
        ZStack {
            Color(.systemBackground)

            GlassEffectContainer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(feedTabs.enumerated()), id: \.element.id) { index, tab in
                            Button {
                                handleTabTap(at: index)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tab.isHome ? "house.fill" : "list.bullet")
                                        .font(.title3)
                                        .foregroundStyle(selectedTabIndex == index ? .primary : .secondary)
                                    Text(tab.title)
                                        .font(.roundedBody)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedTabIndex == index ? ThemeColor.resolved(from: themeColorName).color.opacity(0.12) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .padding(.top, layoutMode.useSidebarLayout ? sidebarTopPadding : 0)
            }
        }
    }

    // MARK: - Column 2: Posts

    private func postsColumnContent(statuses: [LinkStatus]) -> some View {
        Group {
            if statuses.isEmpty, !FeedScopedLinkData.isLoading(in: linkFilterService, feedId: currentTab.id) {
                emptyStateView
            } else {
                let canLoadMore = currentTab.isHome
                    ? (timelineService?.canLoadMoreHomeTimeline() ?? false)
                    : (timelineService?.canLoadMoreListTimeline(listId: currentTab.id) ?? false)
                LinkFeedPostList(
                    statuses: statuses,
                    isLoading: FeedScopedLinkData.isLoading(in: linkFilterService, feedId: currentTab.id),
                    shouldShowPaginationLoading: shouldShowPaginationLoadingRow(for: statuses),
                    canLoadMore: canLoadMore,
                    showsFollowedHashtagAttribution: currentTab.isHome,
                    followedTags: currentTab.isHome ? (timelineService?.followedTags ?? []) : [],
                    deferPostNavigation: { action in action() },
                    shouldBlockPostTaps: { false },
                    onItemAppear: { checkLoadMore(at: $0, totalCount: $1) },
                    onArticleSelect: { url, status in
                        let pref = ArticleViewerPreference.from(raw: articleViewerPreferenceRaw)
                        switch pref {
                        case .externalBrowser:
                            openURL(url)
                        case .safari:
                            #if os(iOS)
                            appState.present(sheet: .safariView(url: url))
                            #else
                            openURL(url)
                            #endif
                        case .inApp:
                            selectedArticle = (url: url, status: status)
                        }
                    },
                    scrollProxy: $scrollProxy,
                    onFirstVisibleChange: { statusId in
                        appState.linksLastVisibleStatusIdPerFeed[currentTab.id] = statusId
                    },
                    onListAppear: {
                        attemptRestoreScrollIfNeeded()
                    },
                    onLoadMoreAtBottom: { requestLoadMore() }
                )
            }
        }
        .id(currentTab.id)
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

    // MARK: - Column 3: Article or empty

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

    // MARK: - Actions

    private func selectTab(at index: Int) {
        guard index >= 0, index < feedTabs.count, index != selectedTabIndex else { return }
        selectedTabIndex = index
    }

    private func handleTabTap(at index: Int) {
        guard index >= 0, index < feedTabs.count else { return }

        let tab = feedTabs[index]
        let isSelected = index == selectedTabIndex
        let isDoubleTap = feedTabSelectionTracker.recordSelection(tab.id)

        if isSelected, isDoubleTap {
            HapticFeedback.play(.navigation)
            appState.requestLinksScrollToTop()
            return
        }

        HapticFeedback.play(.navigation)
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
        HapticFeedback.prepare(.navigation)
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
        guard canLoadMore(for: tab, using: service) else { return }

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
            appState.synchronizeCurrentAccountListDisplayPreferences(
                with: [],
                allowEmptyListSet: true
            )
            return
        }

        if retainedLists != incomingLists {
            retainedLists = incomingLists
        }
        if cachedLists != incomingLists {
            timelineWrapper.updateCachedLists(incomingLists, for: accountId)
        }
        appState.synchronizeCurrentAccountListDisplayPreferences(with: incomingLists)
    }

    // MARK: - Data Loading

    private func loadInitialContent() async {
        await timelineWrapper.waitForStartupLinkFeedLoad()
        guard let service = timelineService else { return }

        await service.loadLists(forceRefresh: liveLists.isEmpty)
        syncRetainedLists(with: service.lists, allowEmpty: service.error == nil)

        if let index = feedTabs.firstIndex(where: { $0.id == appState.selectedLinkFeedID }) {
            selectedTabIndex = index
        }

        await ensureHomeFollowedTagsLoadedIfNeeded(for: currentTab, using: service)
        linkFilterService.switchToFeed(currentTab.id)

        let hasPreparedFeedState = service.hasPreparedLinkFeedState(feedId: currentTab.id)
        if linkFilterService.hasCachedContent(for: currentTab.id) && hasPreparedFeedState {
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

        await ensureHomeFollowedTagsLoadedIfNeeded(for: tab, using: service)
        linkFilterService.switchToFeed(tab.id)
        let statuses = await service.loadLinkFeedStatuses(feedId: tab.id, forceRefreshHome: forceRefresh)
        _ = await linkFilterService.processStatusesEnsuringVisibleContent(
            statuses,
            for: tab.id,
            canLoadMore: { canLoadMore(for: tab, using: service) },
            loadMoreStatuses: { await loadMoreStatuses(for: tab, using: service) }
        )
        Task {
            await linkFilterService.enrichWithAttributions()
        }
    }

    private func loadContentForTabIfNeeded(_ tab: FeedTabItem) async {
        guard let service = timelineService else { return }
        let hasCachedContent = linkFilterService.hasCachedContent(for: tab.id)
        let hasPreparedFeedState = service.hasPreparedLinkFeedState(feedId: tab.id)
        guard !hasCachedContent || !hasPreparedFeedState else { return }
        await loadContentForTab(tab)
    }

    private func refreshCurrentFeed() async {
        guard let service = timelineService else { return }
        let tab = currentTab
        let statuses: [Status]

        await ensureHomeFollowedTagsLoadedIfNeeded(for: tab, using: service)

        if tab.isHome {
            await service.refreshHomeTimeline()
            statuses = service.homeTimeline
        } else {
            await service.refreshListTimeline(listId: tab.id)
            statuses = service.listTimeline
        }

        _ = await linkFilterService.processStatusesEnsuringVisibleContent(
            statuses,
            for: tab.id,
            canLoadMore: { canLoadMore(for: tab, using: service) },
            loadMoreStatuses: { await loadMoreStatuses(for: tab, using: service) }
        )
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

        let newStatuses = await loadMoreStatuses(for: tab, using: service)
        guard !newStatuses.isEmpty else { return }

        _ = await linkFilterService.appendStatusesEnsuringAdditionalContent(
            newStatuses,
            for: tab.id,
            canLoadMore: { canLoadMore(for: tab, using: service) },
            loadMoreStatuses: { await loadMoreStatuses(for: tab, using: service) }
        )
    }

    private func canLoadMore(for tab: FeedTabItem, using service: TimelineService) -> Bool {
        tab.isHome ? service.canLoadMoreHomeTimeline() : service.canLoadMoreListTimeline(listId: tab.id)
    }

    private func loadMoreStatuses(for tab: FeedTabItem, using service: TimelineService) async -> [Status] {
        if tab.isHome {
            return await service.loadMoreHomeTimeline()
        }
        return await service.loadMoreListTimeline(listId: tab.id)
    }

    private func ensureHomeFollowedTagsLoadedIfNeeded(for tab: FeedTabItem, using service: TimelineService) async {
        guard tab.isHome, service.followedTags.isEmpty else { return }
        await service.loadFollowedTags(refresh: true)
    }

    private func attemptRestoreScrollIfNeeded() {
        guard let proxy = scrollProxy else { return }
        guard !hasRestoredScrollForCurrentTab else { return }
        guard let statusId = appState.linksLastVisibleStatusIdPerFeed[currentTab.id] else { return }

        DispatchQueue.main.async {
            withAnimation(nil) {
                proxy.scrollTo(statusId, anchor: .top)
            }
            hasRestoredScrollForCurrentTab = true
        }
    }
}

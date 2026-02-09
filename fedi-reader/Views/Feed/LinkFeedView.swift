//
//  LinkFeedView.swift
//  fedi-reader
//
//  Main filtered link feed showing posts with links
//

import SwiftUI

// MARK: - Feed Tab Item

struct FeedTabItem: Identifiable, Hashable {
    let id: String
    let title: String
    let isHome: Bool
    
    init(id: String, title: String, isHome: Bool = false) {
        self.id = id
        self.title = title
        self.isHome = isHome
    }
    
    static let home = FeedTabItem(id: "home", title: "Home", isHome: true)
}

// MARK: - Link Feed View

struct LinkFeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var selectedDomain: String?
    @State private var selectedTabIndex: Int = 0
    @State private var scrollProxy: ScrollViewProxy?
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var titleBarTapTracker = TabSelectionTracker()
    @State private var isPaginating = false
    @State private var isHorizontalSwipeIntentActive = false
    @State private var postSwipeTapSuppressionDeadline: TimeInterval = 0
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    private var lists: [MastodonList] {
        timelineService?.lists ?? []
    }
    
    private var feedTabs: [FeedTabItem] {
        var tabs = [FeedTabItem.home]
        tabs.append(contentsOf: lists.map { FeedTabItem(id: $0.id, title: $0.title) })
        return tabs
    }
    
    private var currentTab: FeedTabItem {
        guard selectedTabIndex >= 0 && selectedTabIndex < feedTabs.count else {
            return .home
        }
        return feedTabs[selectedTabIndex]
    }
    
    private var currentAccounts: [MastodonAccount] {
        guard let service = timelineService else { return [] }
        return service.listAccounts
    }
    
    private var currentUserFilter: String? {
        appState.userFilterPerFeedId[currentTab.id]
    }
    
    private var filteredStatuses: [LinkStatus] {
        var statuses = linkFilterService.linkStatuses
        
        if let domain = selectedDomain {
            statuses = linkFilterService.filterByDomain(domain)
        }
        
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
        
        VStack(spacing: 0) {
            // Horizontal scrollable list picker
            listPickerHeader
            
            // Single content view (no TabView to avoid crashes)
            ZStack {
                Group {
                    if statuses.isEmpty && !linkFilterService.isLoading {
                        emptyStateView
                    } else {
                        linkList(statuses: statuses)
                    }
                }
                .id(currentTab.id)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: FeedSwipeGestureEvaluator.horizontalIntentDistance)
                    .onChanged { value in
                        handleSwipeChanged(value)
                    }
                    .onEnded { value in
                        handleSwipeEnded(value)
                    }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .onPreferenceChange(ScrollToTopKey.self) { shouldScroll in
            if shouldScroll {
                scrollToTop()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    let isDoubleTap = titleBarTapTracker.recordSelection(.links)
                    if isDoubleTap {
                        scrollToTop()
                        HapticFeedback.play(.medium, enabled: hapticFeedback)
                    }
                } label: {
                    Text(currentTab.isHome ? "Home" : currentTab.title)
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(currentTab.isHome ? "Home" : currentTab.title)
                .accessibilityHint("Double tap to scroll to top")
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.isUserFilterOpen = true
                } label: {
                    Image(systemName: currentUserFilter != nil ? "person.fill" : "person.2")
                }
                .accessibilityLabel(currentUserFilter != nil ? "User filter active" : "Filter by user")
                .accessibilityHint("Opens user filter pane")
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Domain filter
                    if !linkFilterService.uniqueDomains().isEmpty {
                        Section("Filter by Domain") {
                            Button("All Domains") {
                                selectedDomain = nil
                            }
                            
                            ForEach(linkFilterService.uniqueDomains(), id: \.self) { domain in
                                Button(domain) {
                                    selectedDomain = domain
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            Task {
                                await linkFilterService.enrichWithAttributions()
                            }
                        } label: {
                            Label("Load Author Info", systemImage: "person.text.rectangle")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filter and options")
                .accessibilityHint("Filter by domain or load author info")
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
            // Sync tab selection if changed from outside
            let targetId = newListId ?? "home"
            if let index = feedTabs.firstIndex(where: { $0.id == targetId }) {
                if selectedTabIndex != index {
                    selectedTabIndex = index
                }
            }
        }
        .refreshable {
            await refreshCurrentFeed()
        }
        .onDisappear {
            isHorizontalSwipeIntentActive = false
            postSwipeTapSuppressionDeadline = 0
        }
    }
    
    private var listPickerHeader: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(feedTabs.enumerated()), id: \.element.id) { index, tab in
                        FeedTabButton(
                            title: tab.title,
                            isSelected: selectedTabIndex == index
                        ) {
                            selectTab(at: index)
                        }
                        .id(tab.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedTabIndex) { _, newIndex in
                if newIndex < feedTabs.count {
                    withAnimation {
                        proxy.scrollTo(feedTabs[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
    }
    
    private func linkList(statuses: [LinkStatus]) -> some View {
        return GlassEffectContainer {
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(statuses.enumerated()), id: \.element.id) { index, linkStatus in
                        LinkStatusRow(
                            linkStatus: linkStatus,
                            deferPostNavigation: deferPostNavigation,
                            shouldIgnoreTap: { shouldBlockPostTaps }
                        )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .onAppear {
                                checkLoadMore(at: index, totalCount: statuses.count)
                            }
                    }
                    
                    if linkFilterService.isLoading {
                        loadingRow
                    }
                    
                    if shouldShowPaginationLoadingRow(for: statuses) {
                        paginationLoadingRow
                    }
                }
                .listStyle(.plain)
                .transaction { transaction in
                    transaction.animation = nil
                }
                .scrollContentBackground(.hidden)
                .listRowSpacing(8)
                .padding(.horizontal, 12)
                .contentMargins(.top, 0, for: .scrollContent)
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
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
    
    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
        .listRowSeparator(.hidden)
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
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Gesture Handling

    private func handleSwipeChanged(_ value: DragGesture.Value) {
        guard !isHorizontalSwipeIntentActive else { return }
        if FeedSwipeGestureEvaluator.isHorizontalIntent(translation: value.translation) {
            isHorizontalSwipeIntentActive = true
        }
    }

    private func handleSwipeEnded(_ value: DragGesture.Value) {
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

    private func deferPostNavigation(_ action: @escaping () -> Void) {
        guard !shouldBlockPostTaps else { return }
        action()
    }

    private func suppressPostSwipeTaps() {
        let suppressionSeconds = Double(FeedSwipeGestureEvaluator.postSwipeSuppressionNanoseconds) / 1_000_000_000
        postSwipeTapSuppressionDeadline = Date().timeIntervalSinceReferenceDate + suppressionSeconds
    }
    
    // MARK: - Data Loading
    
    private func loadInitialContent() async {
        guard let service = timelineService else { return }
        
        // Keep list tabs stable and only refresh occasionally.
        await service.loadLists()
        
        // Apply initial list selection from AppState
        if let listId = appState.selectedListId,
           let index = feedTabs.firstIndex(where: { $0.id == listId }) {
            selectedTabIndex = index
        }
        
        // Load content for current tab (force refresh on initial load)
        await loadContentForTab(currentTab, forceRefresh: true)
        
        // Pre-fetch adjacent feeds in background
        Task.detached(priority: .background) { [feedTabs, selectedTabIndex] in
            await self.prefetchAdjacentFeeds(currentIndex: selectedTabIndex, tabs: feedTabs)
        }
    }
    
    private func handleTabChange(to newIndex: Int) {
        guard newIndex >= 0 && newIndex < feedTabs.count else { return }
        
        let tab = feedTabs[newIndex]
        let listId = tab.isHome ? nil : tab.id
        
        // Update app state
        if appState.selectedListId != listId {
            appState.selectedListId = listId
        }
        selectedDomain = nil
        
        // Switch the active feed in LinkFilterService
        linkFilterService.switchToFeed(tab.id)
        
        // Load content if not cached
        Task {
            await loadContentForTabIfNeeded(tab)

            // Pre-fetch adjacent feeds
            Task.detached(priority: .background) { [feedTabs] in
                await self.prefetchAdjacentFeeds(currentIndex: newIndex, tabs: feedTabs)
            }
        }
    }

    private func selectTab(at index: Int) {
        guard index >= 0 && index < feedTabs.count else { return }
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index
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
            // Load list timeline
            await service.refreshListTimeline(listId: tab.id)
            await service.refreshListAccounts(listId: tab.id)
            _ = await linkFilterService.processStatuses(service.listTimeline, for: tab.id)
        }
        Task {
            await linkFilterService.enrichWithAttributions()
        }
    }
    
    private func loadContentForTabIfNeeded(_ tab: FeedTabItem) async {
        // Check if content is already cached
        if linkFilterService.hasCachedContent(for: tab.id) {
            return
        }
        
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
        
        // Get adjacent indices
        var indicesToPrefetch: [Int] = []
        if currentIndex > 0 {
            indicesToPrefetch.append(currentIndex - 1)
        }
        if currentIndex < tabs.count - 1 {
            indicesToPrefetch.append(currentIndex + 1)
        }
        
        for index in indicesToPrefetch {
            let tab = tabs[index]
            
            // Skip if already cached or loading
            guard !linkFilterService.hasCachedContent(for: tab.id),
                  !linkFilterService.isLoadingFeed(tab.id) else {
                continue
            }
            
            // Load content for this tab
            if tab.isHome {
                if service.homeTimeline.isEmpty {
                    await service.refreshHomeTimeline()
                }
                _ = await linkFilterService.processStatuses(service.homeTimeline, for: tab.id)
            } else {
                // For lists, fetch without affecting main state
                let statuses = await service.fetchListTimelineStatuses(listId: tab.id)
                if !statuses.isEmpty {
                    _ = await linkFilterService.processStatuses(statuses, for: tab.id)
                }
            }
        }
    }
    
    private func scrollToTop() {
        guard let proxy = scrollProxy, !filteredStatuses.isEmpty else { return }
        // Play haptic feedback (already played in MainTabView, but ensure it's ready)
        HapticFeedback.prepare(.medium)
        // Use spring animation for snappy, native feel
        // Scroll to first item
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
}

#Preview {
    NavigationStack {
        LinkFeedView()
    }
    .environment(AppState())
    .environment(LinkFilterService())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

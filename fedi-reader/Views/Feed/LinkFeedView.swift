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
    @GestureState private var dragOffset: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy?
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var titleBarTapTracker = TabSelectionTracker()
    
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
    
    private var filteredStatuses: [LinkStatus] {
        var statuses = linkFilterService.linkStatuses
        
        if let domain = selectedDomain {
            statuses = linkFilterService.filterByDomain(domain)
        }
        
        if let userFilter = appState.selectedUserFilter {
            statuses = statuses.filter { linkStatus in
                linkStatus.status.displayStatus.account.id == userFilter
            }
        }
        
        return statuses
    }
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            // Horizontal scrollable list picker
            listPickerHeader
            
            // Single content view (no TabView to avoid crashes)
            ZStack {
                if filteredStatuses.isEmpty && !linkFilterService.isLoading {
                    emptyStateView
                } else {
                    linkList
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        // Only switch tabs on predominantly horizontal swipes
                        guard abs(dx) > abs(dy) else { return }
                        let threshold: CGFloat = 50
                        if dx > threshold && selectedTabIndex > 0 {
                            // Swipe right - go to previous tab
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTabIndex -= 1
                            }
                        } else if dx < -threshold && selectedTabIndex < feedTabs.count - 1 {
                            // Swipe left - go to next tab
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTabIndex += 1
                            }
                        }
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
                    // Detect double-tap on title bar
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
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    appState.isUserFilterOpen = true
                } label: {
                    Image(systemName: appState.selectedUserFilter != nil ? "person.fill" : "person.2")
                }
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
            }
        }
        .sheet(isPresented: $state.isUserFilterOpen) {
            UserFilterPane(
                accounts: currentAccounts,
                onSelectAccount: { account in
                    appState.selectedUserFilter = account?.id
                    appState.isUserFilterOpen = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            await loadInitialContent()
        }
        .onChange(of: selectedTabIndex) { oldIndex, newIndex in
            handleTabChange(from: oldIndex, to: newIndex)
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
    }
    
    private var listPickerHeader: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(feedTabs.enumerated()), id: \.element.id) { index, tab in
                        FeedTabButton(
                            title: tab.title,
                            isSelected: selectedTabIndex == index,
                            isLoading: linkFilterService.isLoadingFeed(tab.id)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTabIndex = index
                            }
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
    
    private var linkList: some View {
        GlassEffectContainer {
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredStatuses) { linkStatus in
                        LinkStatusRow(linkStatus: linkStatus)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .onAppear {
                                checkLoadMore(linkStatus)
                            }
                    }
                    
                    if linkFilterService.isLoading {
                        loadingRow
                    }
                }
                .listStyle(.plain)
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
    
    // MARK: - Data Loading
    
    private func loadInitialContent() async {
        guard let service = timelineService else { return }
        
        // Load lists first
        if service.lists.isEmpty {
            await service.loadLists()
        }
        
        // Apply initial list selection from AppState
        if let listId = appState.selectedListId,
           let index = feedTabs.firstIndex(where: { $0.id == listId }) {
            selectedTabIndex = index
        }
        
        // Load content for current tab
        await loadContentForTab(currentTab)
        
        // Pre-fetch adjacent feeds in background
        Task.detached(priority: .background) { [feedTabs, selectedTabIndex] in
            await self.prefetchAdjacentFeeds(currentIndex: selectedTabIndex, tabs: feedTabs)
        }
    }
    
    private func handleTabChange(from oldIndex: Int, to newIndex: Int) {
        guard newIndex >= 0 && newIndex < feedTabs.count else { return }
        
        let tab = feedTabs[newIndex]
        let listId = tab.isHome ? nil : tab.id
        
        // Update app state
        if appState.selectedListId != listId {
            appState.selectedListId = listId
        }
        appState.selectedUserFilter = nil
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
    
    private func loadContentForTab(_ tab: FeedTabItem) async {
        guard let service = timelineService else { return }
        
        linkFilterService.switchToFeed(tab.id)
        
        if tab.isHome {
            if service.homeTimeline.isEmpty {
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
    
    private func checkLoadMore(_ linkStatus: LinkStatus) {
        guard let service = timelineService else { return }
        
        let statuses = filteredStatuses
        guard let index = statuses.firstIndex(of: linkStatus) else { return }
        
        if index >= statuses.count - (Constants.Pagination.prefetchThreshold * 2) {
            Task {
                let tab = currentTab
                if tab.isHome {
                    await service.loadMoreHomeTimeline()
                    _ = await linkFilterService.processStatuses(service.homeTimeline, for: tab.id)
                } else {
                    await service.loadMoreListTimeline(listId: tab.id)
                    _ = await linkFilterService.processStatuses(service.listTimeline, for: tab.id)
                }
            }
        }
    }
}

// MARK: - Feed Tab Button

struct FeedTabButton: View {
    let title: String
    let isSelected: Bool
    var isLoading: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.roundedSubheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Link Status Row

struct LinkStatusRow: View {
    let linkStatus: LinkStatus
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @AppStorage("themeColor") private var themeColorName = "blue"
    
    @State private var isShowingActions = false
    @State private var blueskyDescription: String?
    @State private var hasLoadedBlueskyDescription = false
    
    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }
    
    var body: some View {
        Button {
            appState.navigate(to: .status(linkStatus.status))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                if linkStatus.status.isReblog {
                    reblogGradientStrip
                }
                
                // Author info
                authorHeader
                
                // Link card
                linkCard
                
                // Tags
                let tags = TagExtractor.extractTags(from: linkStatus.status)
                if !tags.isEmpty {
                    TagView(tags: tags) { tag in
                        appState.navigate(to: .hashtag(tag))
                    }
                }
                
                // Actions bar
                StatusActionsBar(status: linkStatus.status, size: .compact)

                Divider()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuContent
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
                AsyncImage(url: reblogger.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.white.opacity(0.5))
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
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
                        themeColor.opacity(0.28),
                        themeColor.opacity(0.15),
                        themeColor.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var authorHeader: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: linkStatus.status.displayStatus.account.avatar)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: Constants.UI.avatarSize, height: Constants.UI.avatarSize)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(linkStatus.status.displayStatus.account.displayName)
                        .font(.roundedSubheadline.bold())
                        .lineLimit(1)
                    
                    AccountBadgesView(account: linkStatus.status.displayStatus.account, size: .small)
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
            VStack(alignment: .leading, spacing: 12) {
                // Large image
                if let imageURL = linkStatus.imageURL {
                    GeometryReader { geo in
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 220)
                                    .clipped()
                            case .failure:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            case .empty:
                                ProgressView()
                                    .frame(width: geo.size.width, height: 220)
                            @unknown default:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Title and domain
                VStack(alignment: .leading, spacing: 8) {
                    Text(linkStatus.displayTitle)
                        .font(.roundedTitle3.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
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
                        
                        authorAttributionChip(linkStatus.status.displayStatus.account.displayName)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
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
    
    private func authorAttributionChip(_ authorName: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "person.crop.circle")
                .font(.roundedCaption)
            Text(authorName)
                .font(.roundedCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.tertiarySystemBackground), in: Capsule())
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        // Open in browser
        Link(destination: linkStatus.primaryURL) {
            Label("Open in Browser", systemImage: "safari")
        }
        
        // Share
        ShareLink(item: linkStatus.primaryURL) {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }
        
        // Copy link
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
        
        // Read Later options
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
                ForEach(readLaterManager.configuredServices) { config in
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
        
        // Status actions
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

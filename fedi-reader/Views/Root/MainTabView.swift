import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.layoutMode) private var layoutMode

    @State private var tabTracker = TabSelectionTracker()
    @AppStorage("hideTabBarLabels") private var hideTabBarLabels = false

    private var unreadMentionsCount: Int {
        timelineWrapper.service?.unreadConversationsCount ?? 0
    }

    private var useSidebarLayout: Bool {
        layoutMode.useSidebarLayout
    }

    private var visibleTabs: [AppTab] {
        appState.resolvedVisibleTabs()
    }

    private var listsInSeparateTab: Bool {
        appState.listsInSeparateTab
    }

    var body: some View {
        @Bindable var state = appState

        mainTabView()
            .animation(.easeInOut(duration: 0.25), value: hideTabBarLabels)
            .onChange(of: state.selectedTab) { oldValue, newValue in
            HapticFeedback.play(.selection)
            let primaryTabs = Array(visibleTabs.prefix(4))
            if primaryTabs.contains(newValue) {
                state.moreTabPath.removeAll()
            }
            if oldValue == .profile {
                state.profileNavigationPath.removeAll()
            }
            if oldValue == .lists {
                state.listsNavigationPath.removeAll()
            }
            if oldValue == .hashtags {
                state.hashtagsNavigationPath.removeAll()
            }
            if oldValue == .bookmarks {
                state.bookmarksNavigationPath.removeAll()
            }
            if oldValue == .mentions {
                state.mentionsNavigationPath.removeAll()
            }
            if newValue == .mentions {
                Task {
                    await timelineWrapper.service?.refreshMentions()
                    await timelineWrapper.service?.refreshConversations()
                }
                tabTracker.reset()
            } else if newValue != .links {
                tabTracker.reset()
            }
        }
        .onChange(of: visibleTabs) { oldVisibleTabs, newVisibleTabs in
            let wasCompact = oldVisibleTabs.count > 5
            let isCompact = newVisibleTabs.count > 5
            let moreTabs = Array(newVisibleTabs.dropFirst(4))

            if wasCompact, !isCompact, case .moreTab(let tab)? = state.moreTabPath.first {
                let destinations = Array(state.moreTabPath.dropFirst())
                switch tab {
                case .mentions: state.mentionsNavigationPath = destinations
                case .lists: state.listsNavigationPath = destinations
                case .hashtags: state.hashtagsNavigationPath = destinations
                case .bookmarks: state.bookmarksNavigationPath = destinations
                case .explore: state.exploreNavigationPath = destinations
                case .profile: state.profileNavigationPath = destinations
                default: break
                }
                state.moreTabPath.removeAll()
            } else if !wasCompact, isCompact, moreTabs.contains(state.selectedTab) {
                let destinations: [NavigationDestination]
                switch state.selectedTab {
                case .mentions: destinations = state.mentionsNavigationPath
                case .lists: destinations = state.listsNavigationPath
                case .hashtags: destinations = state.hashtagsNavigationPath
                case .bookmarks: destinations = state.bookmarksNavigationPath
                case .explore: destinations = state.exploreNavigationPath
                case .profile: destinations = state.profileNavigationPath
                default: destinations = []
                }
                if !destinations.isEmpty {
                    state.moreTabPath = [.moreTab(state.selectedTab)] + destinations
                }
            }

            let resolvedSelection = MainTabViewSelectionFeatures.resolvedSelection(
                selectedTab: state.selectedTab,
                visibleTabs: newVisibleTabs
            )
            if state.selectedTab != resolvedSelection {
                state.selectedTab = resolvedSelection
            }
        }
        .onChange(of: useSidebarLayout) { _, _ in
            Task {
                await ensureListsAvailableAfterLayoutTransition()
            }
        }
    }

    @ViewBuilder
    private func mainTabView() -> some View {
        @Bindable var state = appState

        if useSidebarLayout || visibleTabs.count <= 5 {
            standardTabView()
        } else {
            compactTabViewWithMoreList()
        }
    }

    @ViewBuilder
    private func standardTabView() -> some View {
        @Bindable var state = appState

        TabView(
            selection: Binding(
                get: {
                    MainTabViewSelectionFeatures.resolvedSelection(
                        selectedTab: state.selectedTab,
                        visibleTabs: visibleTabs
                    )
                },
                set: { newValue in
                    handleTabSelection(
                        MainTabViewSelectionFeatures.resolvedSelection(
                            selectedTab: newValue,
                            visibleTabs: visibleTabs
                        )
                    )
                }
            )
        ) {
            ForEach(visibleTabs) { tab in
                if tab == .mentions && unreadMentionsCount > 0 {
                    tabContent(for: tab)
                        .tag(tab)
                        .tabItem {
                            tabItemLabel(for: tab)
                        }
                        .badge(unreadMentionsCount)
                } else {
                    tabContent(for: tab)
                        .tag(tab)
                        .tabItem {
                            tabItemLabel(for: tab)
                        }
                }
            }
        }
        .modifier(ConditionalTabViewStyle(useSidebarLayout: useSidebarLayout))
        .id(hideTabBarLabels)
    }

    private enum CompactTabSelection: Hashable {
        case primary(AppTab)
        case more
    }

    @ViewBuilder
    private func compactTabViewWithMoreList() -> some View {
        @Bindable var state = appState
        let primaryTabs = Array(visibleTabs.prefix(4))
        let moreTabs = Array(visibleTabs.dropFirst(4))

        TabView(
            selection: Binding(
                get: {
                    let resolved = MainTabViewSelectionFeatures.resolvedSelection(
                        selectedTab: state.selectedTab,
                        visibleTabs: visibleTabs
                    )
                    if primaryTabs.contains(resolved) {
                        return .primary(resolved)
                    }
                    return .more
                },
                set: { (newValue: CompactTabSelection) in
                    switch newValue {
                    case .primary(let tab):
                        handleTabSelection(tab)
                    case .more:
                        if let first = moreTabs.first {
                            state.selectedTab = first
                        }
                    }
                }
            )
        ) {
            ForEach(primaryTabs) { tab in
                if tab == .mentions && unreadMentionsCount > 0 {
                    tabContent(for: tab)
                        .tag(CompactTabSelection.primary(tab))
                        .tabItem {
                            tabItemLabel(for: tab)
                        }
                        .badge(unreadMentionsCount)
                } else {
                    tabContent(for: tab)
                        .tag(CompactTabSelection.primary(tab))
                        .tabItem {
                            tabItemLabel(for: tab)
                        }
                }
            }

            moreTabContent(moreTabs: moreTabs)
                .tag(CompactTabSelection.more)
                .tabItem {
                    Group {
                        if hideTabBarLabels {
                            Label("More", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                        } else {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    }
                    .accessibilityLabel("More")
                }
        }
        .tabViewStyle(.automatic)
        .id(hideTabBarLabels)
    }

    @ViewBuilder
    private func moreTabContent(moreTabs: [AppTab]) -> some View {
        @Bindable var state = appState

        NavigationStack(path: $state.moreTabPath) {
            moreTabList(moreTabs: moreTabs)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func moreTabList(moreTabs: [AppTab]) -> some View {
        List {
            ForEach(moreTabs) { tab in
                NavigationLink(value: NavigationDestination.moreTab(tab)) {
                    Label {
                        Text(tab.title)
                    } icon: {
                        Image(systemName: tab.systemImage)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func moreTabRootView(for tab: AppTab) -> some View {
        switch tab {
        case .lists:
            ListsTabRootView()
        case .hashtags:
            HashtagsTabRootView()
        case .bookmarks:
            LinkFeedView(
                feedTabsOverride: [FeedTabItem(id: AppState.bookmarksFeedID, title: "Bookmarks")],
                showsFeedPicker: false,
                allowsSwipeNavigation: false,
                titleOverride: "Bookmarks",
                userFilterToolbarPlacement: .trailing
            )
        case .explore:
            ExploreFeedView()
        case .mentions:
            MentionsView()
        case .profile:
            ProfileView()
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func tabItemLabel(for tab: AppTab) -> some View {
        let title = MainTabViewTabItemFeatures.title(
            for: tab,
            useSidebarLayout: useSidebarLayout,
            hideTabBarLabels: hideTabBarLabels
        )
        let tabsBehindMore = Set(TabOrderSettingsFeatures.tabsBehindMore(in: visibleTabs))
        let useIconOnly = MainTabViewTabItemFeatures.usesIconOnlyLabelStyle(
            useSidebarLayout: useSidebarLayout,
            hideTabBarLabels: hideTabBarLabels
        ) && !tabsBehindMore.contains(tab)

        if useIconOnly {
            Label(title, systemImage: tab.systemImage)
                .labelStyle(.iconOnly)
                .accessibilityLabel(title)
        } else {
            Label(title, systemImage: tab.systemImage)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        @Bindable var state = appState

        switch tab {
        case .links:
            linksTabContent()
        case .lists:
            NavigationStack(path: $state.listsNavigationPath) {
                ListsTabRootView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
        case .hashtags:
            NavigationStack(path: $state.hashtagsNavigationPath) {
                HashtagsTabRootView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
        case .bookmarks:
            NavigationStack(path: $state.bookmarksNavigationPath) {
                LinkFeedView(
                    feedTabsOverride: [FeedTabItem(id: AppState.bookmarksFeedID, title: "Bookmarks")],
                    showsFeedPicker: false,
                    allowsSwipeNavigation: false,
                    titleOverride: "Bookmarks",
                    userFilterToolbarPlacement: .trailing
                )
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destinationView(for: destination)
                }
            }
        case .explore:
            NavigationStack(path: $state.exploreNavigationPath) {
                ExploreFeedView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
        case .mentions:
            mentionsTabContent()
        case .profile:
            NavigationStack(path: $state.profileNavigationPath) {
                ProfileView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
        }
    }

    @ViewBuilder
    private func linksTabContent() -> some View {
        @Bindable var state = appState

        Group {
            switch layoutMode {
            case .wide:
                NavigationStack(path: $state.linksNavigationPath) {
                    Group {
                        if listsInSeparateTab {
                            LinkFeedTwoColumnView(
                                feedTabsOverride: [.home],
                                showsFeedPicker: false,
                                allowsSwipeNavigation: false,
                                titleOverride: "Home"
                            )
                        } else {
                            LinkFeedThreeColumnView()
                        }
                    }
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            splitLayoutDestinationView(for: destination)
                        }
                }
            case .medium:
                NavigationStack(path: $state.linksNavigationPath) {
                    LinkFeedTwoColumnView(
                        feedTabsOverride: listsInSeparateTab ? [.home] : nil,
                        showsFeedPicker: !listsInSeparateTab,
                        allowsSwipeNavigation: !listsInSeparateTab,
                        titleOverride: listsInSeparateTab ? "Home" : nil
                    )
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            splitLayoutDestinationView(for: destination)
                        }
                }
            case .compact:
                NavigationStack(path: $state.linksNavigationPath) {
                    LinkFeedView(
                        feedTabsOverride: listsInSeparateTab ? [.home] : nil,
                        showsFeedPicker: !listsInSeparateTab,
                        allowsSwipeNavigation: !listsInSeparateTab,
                        titleOverride: listsInSeparateTab ? "Home" : nil
                    )
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
        .id("links-layout-\(layoutMode.id)")
        .animation(.none, value: layoutMode)
    }

    @ViewBuilder
    private func mentionsTabContent() -> some View {
        @Bindable var state = appState

        Group {
            if useSidebarLayout {
                NavigationStack(path: $state.mentionsNavigationPath) {
                    MentionsTwoColumnView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            } else {
                NavigationStack(path: $state.mentionsNavigationPath) {
                    MentionsView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
    }

    private func handleTabSelection(_ newValue: AppTab) {
        let currentValue = appState.selectedTab

        if newValue == .links {
            if currentValue == .links {
                let isDoubleTap = tabTracker.recordSelection(.links)
                if isDoubleTap {
                    appState.requestLinksScrollToTop()
                    HapticFeedback.play(.medium)
                }
            } else {
                tabTracker.reset()
            }
        } else {
            tabTracker.reset()
        }

        guard newValue != currentValue else { return }
        appState.selectedTab = newValue
    }

    @ViewBuilder
    private func splitLayoutDestinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .article:
            EmptyView()
        default:
            destinationView(for: destination)
        }
    }

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .moreTab(let tab):
            moreTabRootView(for: tab)
                .navigationDestination(for: NavigationDestination.self) { dest in
                    destinationViewContent(for: dest)
                }
        default:
            destinationViewContent(for: destination)
        }
    }

    @ViewBuilder
    private func destinationViewContent(for destination: NavigationDestination) -> some View {
        switch destination {
        case .moreTab:
            EmptyView()
        case .status(let status):
            StatusDetailView(status: status)
        case .conversation(let groupedConversation):
            GroupedConversationDetailView(groupedConversation: groupedConversation)
        case .profile(let account):
            ProfileDetailView(account: account)
        case .listFeed(let list):
            ListFeedDetailView(list: list)
        case .hashtagFeed(let tag):
            HashtagFeedDetailView(tag: tag)
        case .article(let url, let status):
            ArticleWebView(url: url, status: status)
        case .thread(let statusId):
            ThreadPlaceholderView(statusId: statusId)
        case .hashtag(let tag):
            HashtagPlaceholderView(tag: tag)
        case .settings:
            SettingsView()
        case .tabOrder:
            TabOrderSettingsView()
        case .listDisplay:
            ListDisplaySettingsView()
        case .accountSettings:
            AccountSettingsView()
        case .readLaterSettings:
            ReadLaterSettingsView()
        case .accountPosts(let accountId, let account):
            PostsListView(accountId: accountId, account: account)
        case .accountFollowing(let accountId, let account):
            FollowingListView(accountId: accountId, account: account)
        case .accountFollowers(let accountId, let account):
            FollowersListView(accountId: accountId, account: account)
        }
    }

    @MainActor
    private func ensureListsAvailableAfterLayoutTransition() async {
        guard let service = timelineWrapper.service else { return }
        guard service.lists.isEmpty else { return }

        await service.loadLists(forceRefresh: true)
        if !service.lists.isEmpty {
            timelineWrapper.updateCachedLists(service.lists, for: appState.currentAccount?.id)
        }
    }
}

enum MainTabViewTabItemFeatures {
    static func title(for tab: AppTab, useSidebarLayout: Bool, hideTabBarLabels: Bool) -> String {
        tab.title
    }

    static func usesIconOnlyLabelStyle(useSidebarLayout: Bool, hideTabBarLabels: Bool) -> Bool {
        !useSidebarLayout && hideTabBarLabels
    }
}

enum MainTabViewSelectionFeatures {
    static func resolvedSelection(selectedTab: AppTab, visibleTabs: [AppTab]) -> AppTab {
        if visibleTabs.contains(selectedTab) {
            return selectedTab
        }

        if visibleTabs.contains(.links) {
            return .links
        }

        return visibleTabs.first ?? .links
    }
}

private extension LayoutMode {
    var id: String {
        switch self {
        case .compact:
            return "compact"
        case .medium:
            return "medium"
        case .wide:
            return "wide"
        }
    }
}

// MARK: - Conditional Tab View Style

private struct ConditionalTabViewStyle: ViewModifier {
    let useSidebarLayout: Bool

    func body(content: Content) -> some View {
        if useSidebarLayout {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content.tabViewStyle(.automatic)
        }
    }
}


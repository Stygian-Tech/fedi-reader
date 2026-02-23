import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.layoutMode) private var layoutMode

    @State private var tabTracker = TabSelectionTracker()
    @State private var scrollToTopTrigger = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("hideTabBarLabels") private var hideTabBarLabels = false
    
    private var unreadMentionsCount: Int {
        timelineWrapper.service?.unreadConversationsCount ?? 0
    }

    private var useSidebarLayout: Bool {
        layoutMode.useSidebarLayout
    }

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(useSidebarLayout ? "Home" : (hideTabBarLabels ? "" : "Home"), systemImage: "house", value: .links) {
                Group {
                    switch layoutMode {
                    case .wide:
                        NavigationStack(path: $state.linksNavigationPath) {
                            LinkFeedThreeColumnView()
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    splitLayoutDestinationView(for: destination)
                                }
                                .onAppear {
                                    if state.selectedTab == .links {
                                        let isDoubleTap = tabTracker.recordSelection(.links)
                                        if isDoubleTap {
                                            scrollToTopTrigger.toggle()
                                            HapticFeedback.play(.medium, enabled: false)
                                        }
                                    }
                                }
                        }
                    case .medium:
                        NavigationStack(path: $state.linksNavigationPath) {
                            LinkFeedTwoColumnView()
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    splitLayoutDestinationView(for: destination)
                                }
                                .onAppear {
                                    if state.selectedTab == .links {
                                        let isDoubleTap = tabTracker.recordSelection(.links)
                                        if isDoubleTap {
                                            scrollToTopTrigger.toggle()
                                            HapticFeedback.play(.medium, enabled: false)
                                        }
                                    }
                                }
                        }
                    case .compact:
                        NavigationStack(path: $state.linksNavigationPath) {
                            LinkFeedView()
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    destinationView(for: destination)
                                }
                                .onAppear {
                                    if state.selectedTab == .links {
                                        let isDoubleTap = tabTracker.recordSelection(.links)
                                        if isDoubleTap {
                                            scrollToTopTrigger.toggle()
                                            HapticFeedback.play(.medium, enabled: hapticFeedback)
                                        }
                                    }
                                }
                        }
                    }
                }
                .id("links-layout-\(layoutMode.id)")
                .animation(.none, value: layoutMode)
            }

            Tab(useSidebarLayout ? "Explore" : (hideTabBarLabels ? "" : "Explore"), systemImage: "globe", value: .explore) {
                NavigationStack {
                    ExploreFeedView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            Tab(useSidebarLayout ? "Messages" : (hideTabBarLabels ? "" : "Messages"), systemImage: "at", value: .mentions) {
                Group {
                    if useSidebarLayout {
                        MentionsTwoColumnView()
                    } else {
                        NavigationStack {
                            MentionsView()
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    destinationView(for: destination)
                                }
                        }
                    }
                }
            }
            .badge(unreadMentionsCount)

            Tab(useSidebarLayout ? "Profile" : (hideTabBarLabels ? "" : "Profile"), systemImage: "person", value: .profile) {
                NavigationStack(path: $state.profileNavigationPath) {
                    ProfileView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
        .modifier(ConditionalTabViewStyle(useSidebarLayout: useSidebarLayout))
        .onChange(of: state.selectedTab) { oldValue, newValue in
            HapticFeedback.play(.selection, enabled: hapticFeedback && !useSidebarLayout)
            if oldValue == .profile {
                state.profileNavigationPath.removeAll()
            }
            if newValue == .links {
                let isDoubleTap = tabTracker.recordSelection(.links)
                if isDoubleTap {
                    scrollToTopTrigger.toggle()
                    HapticFeedback.play(.medium, enabled: hapticFeedback && !useSidebarLayout)
                }
            } else if newValue == .mentions {
                Task {
                    await timelineWrapper.service?.refreshMentions()
                    await timelineWrapper.service?.refreshConversations()
                }
                tabTracker.reset()
            } else {
                tabTracker.reset()
            }
        }
        .onChange(of: useSidebarLayout) { _, _ in
            Task {
                await ensureListsAvailableAfterLayoutTransition()
            }
        }
        .preference(key: ScrollToTopKey.self, value: scrollToTopTrigger)
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
        case .status(let status):
            StatusDetailView(status: status)
        case .profile(let account):
            ProfileDetailView(account: account)
        case .article(let url, let status):
            ArticleWebView(url: url, status: status)
        case .thread(let statusId):
            ThreadPlaceholderView(statusId: statusId)
        case .hashtag(let tag):
            HashtagPlaceholderView(tag: tag)
        case .settings:
            SettingsView()
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

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
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("hideTabBarLabels") private var hideTabBarLabels = false
    @AppStorage("themeColor") private var themeColorName = "blue"

    private var unreadMentionsCount: Int {
        timelineWrapper.service?.unreadConversationsCount ?? 0
    }

    private var useSidebarLayout: Bool {
        layoutMode.useSidebarLayout
    }


    var body: some View {
        @Bindable var state = appState

        mainTabView()
            .onChange(of: state.selectedTab) { oldValue, newValue in
            HapticFeedback.play(.selection, enabled: hapticFeedback && !useSidebarLayout)
            if oldValue == .profile {
                state.profileNavigationPath.removeAll()
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
        .onChange(of: useSidebarLayout) { _, _ in
            Task {
                await ensureListsAvailableAfterLayoutTransition()
            }
        }
    }

    @ViewBuilder
    private func mainTabView() -> some View {
        @Bindable var state = appState

        TabView(
            selection: Binding(
                get: { state.selectedTab },
                set: { handleTabSelection($0) }
            )
        ) {
            Tab(useSidebarLayout ? "Home" : (hideTabBarLabels ? "" : "Home"), systemImage: "house", value: .links) {
                linksTabContent()
            }

            Tab(useSidebarLayout ? "Explore" : (hideTabBarLabels ? "" : "Explore"), systemImage: "globe", value: .explore) {
                NavigationStack(path: $state.exploreNavigationPath) {
                    ExploreFeedView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            Tab(useSidebarLayout ? "Messages" : (hideTabBarLabels ? "" : "Messages"), systemImage: "at", value: AppTab.mentions) {
                mentionsTabContent()
            }

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
        .overlay {
            unreadDotOverlay
        }
    }

    @ViewBuilder
    private var unreadDotOverlay: some View {
        if !useSidebarLayout, unreadMentionsCount > 0 {
            GeometryReader { geometry in
                Circle()
                    .fill(ThemeColor.resolved(from: themeColorName).color)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .position(
                        x: geometry.size.width * (2.5 / 4),
                        y: geometry.size.height - 35
                    )
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func linksTabContent() -> some View {
        @Bindable var state = appState

        Group {
            switch layoutMode {
            case .wide:
                NavigationStack(path: $state.linksNavigationPath) {
                    LinkFeedThreeColumnView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            splitLayoutDestinationView(for: destination)
                        }
                }
            case .medium:
                NavigationStack(path: $state.linksNavigationPath) {
                    LinkFeedTwoColumnView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            splitLayoutDestinationView(for: destination)
                        }
                }
            case .compact:
                NavigationStack(path: $state.linksNavigationPath) {
                    LinkFeedView()
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

    private func handleTabSelection(_ newValue: AppTab) {
        let currentValue = appState.selectedTab

        if newValue == .links {
            if currentValue == .links {
                let isDoubleTap = tabTracker.recordSelection(.links)
                if isDoubleTap {
                    appState.requestLinksScrollToTop()
                    HapticFeedback.play(.medium, enabled: hapticFeedback && !useSidebarLayout)
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


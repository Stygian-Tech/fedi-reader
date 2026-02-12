//
//  MainTabView.swift
//  fedi-reader
//
//  Main tab navigation with Home, Explore, Messages, Profile.
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var tabTracker = TabSelectionTracker()
    @State private var scrollToTopTrigger = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("hideTabBarLabels") private var hideTabBarLabels = false
    
    private var unreadMentionsCount: Int {
        timelineWrapper.service?.unreadConversationsCount ?? 0
    }

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab(hideTabBarLabels ? "" : "Home", systemImage: "house", value: .links) {
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

            Tab(hideTabBarLabels ? "" : "Explore", systemImage: "globe", value: .explore) {
                NavigationStack {
                    ExploreFeedView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }

            Tab(hideTabBarLabels ? "" : "Messages", systemImage: "at", value: .mentions) {
                NavigationStack {
                    MentionsView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
            .badge(unreadMentionsCount)

            Tab(hideTabBarLabels ? "" : "Profile", systemImage: "person", value: .profile) {
                NavigationStack(path: $state.profileNavigationPath) {
                    ProfileView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: state.selectedTab) { oldValue, newValue in
            HapticFeedback.play(.selection, enabled: hapticFeedback)
            if oldValue == .profile {
                state.profileNavigationPath.removeAll()
            }
            if newValue == .links {
                let isDoubleTap = tabTracker.recordSelection(.links)
                if isDoubleTap {
                    scrollToTopTrigger.toggle()
                    HapticFeedback.play(.medium, enabled: hapticFeedback)
                }
            } else if newValue == .mentions {
                // Refresh conversations when switching to mentions tab to get latest unread count
                Task {
                    await timelineWrapper.service?.refreshConversations()
                }
                tabTracker.reset()
            } else {
                tabTracker.reset()
            }
        }
        .preference(key: ScrollToTopKey.self, value: scrollToTopTrigger)
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
}

// MARK: - Profile Tab Label

struct ProfileTabLabel: View {
    let account: Account?

    var body: some View {
        Label {
            Text("Profile")
        } icon: {
            ProfileAvatarView(
                url: account.flatMap { $0.avatarURL }.flatMap { URL(string: $0) },
                size: 24,
                usePersonIconForFallback: true
            )
        }
    }
}

// MARK: - Account Tab Accessory

#if os(iOS)
struct AccountTabAccessory: View {
    let account: Account
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.present(sheet: .accountSwitcher)
        } label: {
            HStack(spacing: 8) {
                ProfileAvatarView(url: URL(string: account.avatarURL ?? ""), size: 24)

                Text("@\(account.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
#endif

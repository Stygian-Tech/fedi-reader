//
//  ContentView.swift
//  fedi-reader
//
//  Main tab view with Liquid Glass styling
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()
    @State private var timelineWrapper = TimelineServiceWrapper()
    @State private var linkFilterService = LinkFilterService()
    @State private var readLaterManager = ReadLaterManager()
    
    var body: some View {
        Group {
            if appState.hasAccount {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .environment(appState)
        .environment(linkFilterService)
        .environment(readLaterManager)
        .environment(timelineWrapper)
        .onAppear {
            setupServices()
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .sheet(item: $appState.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(item: $appState.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func setupServices() {
        // Initialize timeline service with dependencies
        timelineWrapper.service = TimelineService(
            client: appState.client,
            authService: appState.authService
        )
        
        // Load accounts from SwiftData
        appState.authService.loadAccounts(from: modelContext)
        
        // Load read-later configurations
        readLaterManager.loadConfigurations(from: modelContext)
    }
    
    private func handleOpenURL(_ url: URL) {
        if appState.authService.isValidCallback(url: url) {
            Task {
                do {
                    _ = try await appState.authService.handleCallback(url: url, modelContext: modelContext)
                } catch {
                    appState.handleError(error)
                }
            }
        }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: SheetDestination) -> some View {
        switch sheet {
        case .login:
            LoginView()
                .environment(appState)
        case .compose(let replyTo, let quote):
            ComposeView(replyTo: replyTo, quote: quote)
                .environment(appState)
        case .newMessage:
            NewMessageView()
                .environment(appState)
        case .readLaterLogin(let serviceType):
            ReadLaterLoginView(serviceType: serviceType)
                .environment(readLaterManager)
        case .shareSheet(let url):
            ShareSheet(url: url)
        case .accountSwitcher:
            AccountSwitcherView()
                .environment(appState)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    var body: some View {
        @Bindable var state = appState
        
        TabView(selection: $state.selectedTab) {
            Tab("Links", systemImage: "link", value: .links) {
                NavigationStack(path: $state.navigationPath) {
                    LinkFeedView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
            
            Tab("Explore", systemImage: "globe", value: .explore) {
                NavigationStack {
                    ExploreFeedView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
            
            Tab("Mentions", systemImage: "at", value: .mentions) {
                NavigationStack {
                    MentionsView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
            
            Tab("Profile", systemImage: "person", value: .profile) {
                NavigationStack(path: $state.navigationPath) {
                    ProfileView()
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
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
            if let account = account, let avatarURL = account.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        Image(systemName: "person")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    @unknown default:
                        Image(systemName: "person")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
            } else {
                Image(systemName: "person")
            }
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
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
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

// MARK: - Welcome View

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon and title
            VStack(spacing: 16) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)
                
                Text("Fedi Reader")
                    .font(.roundedLargeTitle.bold())
                
                Text("Your link-focused Mastodon feed")
                    .font(.roundedTitle3)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "link",
                    title: "Link-Focused Feed",
                    description: "See only posts with interesting links"
                )
                
                FeatureRow(
                    icon: "bookmark",
                    title: "Read Later Integration",
                    description: "Save to Pocket, Instapaper, and more"
                )
                
                FeatureRow(
                    icon: "globe",
                    title: "Explore Trending",
                    description: "Discover what's popular on your instance"
                )
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Login button
            Button {
                appState.present(sheet: .login)
            } label: {
                Text("Connect Mastodon Account")
                    .font(.roundedHeadline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
            }
            .buttonStyle(.liquidGlass)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background {
            GradientBackground()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .glassEffect(.clear, in: Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.roundedHeadline)
                
                Text(description)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct GradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Adaptive base color
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color.accentColor.opacity(0.15),
                    Color.clear,
                    Color.accentColor.opacity(0.08)
                ] : [
                    Color.accentColor.opacity(0.08),
                    Color.clear,
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Timeline Service Wrapper

@Observable
@MainActor
final class TimelineServiceWrapper {
    var service: TimelineService?
    
    init(service: TimelineService? = nil) {
        self.service = service
    }
}

// MARK: - Share Sheet

struct ShareSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share")
                .font(.headline)
            
            ShareLink(item: url) {
                Label("Share Link", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .frame(minWidth: 300)
    }
}

// MARK: - Placeholder Views

struct ThreadPlaceholderView: View {
    let statusId: String
    @Environment(AppState.self) private var appState
    @State private var status: Status?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let status = status {
                StatusDetailView(status: status)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Post Not Found", systemImage: "bubble.left")
            }
        }
        .navigationTitle("Thread")
        .task {
            await loadStatus()
        }
    }
    
    private func loadStatus() async {
        let client = appState.client
        
        do {
            status = try await client.getStatus(id: statusId)
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

struct HashtagPlaceholderView: View {
    let tag: String
    @Environment(AppState.self) private var appState
    @State private var statuses: [Status] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if !statuses.isEmpty {
                List(statuses) { status in
                    StatusRowView(status: status)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSpacing(8)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Posts", systemImage: "number")
            }
        }
        .navigationTitle("#\(tag)")
        .task {
            await loadHashtagTimeline()
        }
    }
    
    private func loadHashtagTimeline() async {
        let client = appState.client
        
        do {
            statuses = try await client.getHashtagTimeline(tag: tag)
        } catch {
            // Handle error
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Content View") {
    ContentView()
        .modelContainer(for: [Account.self, CachedStatus.self, ReadLaterConfig.self], inMemory: true)
}

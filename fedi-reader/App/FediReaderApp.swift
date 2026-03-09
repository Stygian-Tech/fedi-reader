//
//  FediReaderApp.swift
//  fedi-reader
//
//  Main app entry point
//

import SwiftUI
import SwiftData
import AppIntents
#if os(iOS)
import UIKit
#endif

@available(iOS 16.0, *)
private enum AppIntentsDependency {
    static let intentType: (any AppIntent.Type)? = nil
}

@main
struct FediReaderApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _ = ArticleViewerPreference.resolved()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Account.self,
            CachedStatus.self,
            ReadLaterConfig.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("defaultListId") private var defaultListId = ""
    @State private var appState = AppState()
    @State private var timelineWrapper = TimelineServiceWrapper()
    @State private var linkFilterService = LinkFilterService()
    @State private var readLaterManager = ReadLaterManager()

    private var modelContext: ModelContext {
        sharedModelContainer.mainContext
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(linkFilterService)
                .environment(readLaterManager)
                .environment(timelineWrapper)
                .tint(ThemeColor.resolved(from: themeColorName).color)
                .onAppear {
                    setupServices()
                    updateInboxAutoRefresh(for: scenePhase)
                    startInitialLinkFeedLoadIfNeeded()
                    #if os(iOS)
                    configureTabBarBadgeColor(themeColorName)
                    #endif
                }
                .onChange(of: themeColorName) { _, newValue in
                    #if os(iOS)
                    configureTabBarBadgeColor(newValue)
                    #endif
                }
                .task {
                    await appState.authService.migrateOAuthClientSecretsToKeychain(modelContext: modelContext)
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    updateInboxAutoRefresh(for: newPhase)
                }
                .onChange(of: appState.currentAccount?.id) { _, _ in
                    updateInboxAutoRefresh(for: scenePhase)
                    appState.loadListDisplayPreferencesForCurrentAccount()
                    if let service = timelineWrapper.service {
                        service.lists = timelineWrapper.cachedLists(for: appState.currentAccount?.id)
                    }
                    timelineWrapper.resetStartupLinkFeedLoad(for: appState.currentAccount?.id)
                    startInitialLinkFeedLoadIfNeeded()
                    Task {
                        await appState.authService.refreshClientAuthenticationState()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .readLaterDidSave)) { notification in
                    guard let result = notification.object as? ReadLaterSaveResult else { return }
                    handleReadLaterSaveResult(result)
                }
        }
        .modelContainer(sharedModelContainer)
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
                .environment(timelineWrapper)
                .environment(readLaterManager)
        }
        #endif
    }

    #if os(iOS)
    private func configureTabBarBadgeColor(_ themeColorName: String) {
        let color = ThemeColor.resolved(from: themeColorName).color
        let tabBarAppearance = UITabBarAppearance()
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.badgeBackgroundColor = UIColor(color)
        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    #endif

    @MainActor
    private func setupServices() {
        appState.authService.loadAccounts(from: modelContext)
        appState.loadListDisplayPreferencesForCurrentAccount()
        Task {
            await appState.authService.refreshClientAuthenticationState()
        }

        if timelineWrapper.service == nil {
            timelineWrapper.service = TimelineService(
                client: appState.client,
                authService: appState.authService
            )
        }

        if let accountId = appState.currentAccount?.id,
           let service = timelineWrapper.service,
           service.lists.isEmpty {
            let cachedLists = timelineWrapper.cachedLists(for: accountId)
            if !cachedLists.isEmpty {
                service.lists = cachedLists
            }
        }

        readLaterManager.loadConfigurations(from: modelContext)

        if let instance = appState.getCurrentInstance() {
            Task {
                await appState.emojiService.fetchCustomEmojis(for: instance)
            }
        }

        updateInboxAutoRefresh(for: scenePhase)
    }

    @MainActor
    private func updateInboxAutoRefresh(for phase: ScenePhase) {
        guard let service = timelineWrapper.service else { return }
        if appState.hasAccount, phase == .active {
            service.startInboxAutoRefresh()
        } else {
            service.stopInboxAutoRefresh()
        }
    }

    @MainActor
    private func startInitialLinkFeedLoadIfNeeded() {
        guard let accountId = appState.currentAccount?.id,
              let service = timelineWrapper.service else { return }

        timelineWrapper.beginStartupLinkFeedLoad(for: accountId) {
            let initialFeedID = await loadListsAndApplyDefault(using: service)
            guard self.appState.currentAccount?.id == accountId else { return }

            self.linkFilterService.switchToFeed(initialFeedID)

            if !self.linkFilterService.hasCachedContent(for: initialFeedID) {
                let statuses = await service.loadLinkFeedStatuses(
                    feedId: initialFeedID,
                    forceRefreshHome: true
                )
                _ = await self.linkFilterService.processStatuses(statuses, for: initialFeedID)
            }

            Task {
                await self.linkFilterService.enrichWithAttributions()
            }

            let allFeedIDs = [AppState.homeFeedID] + self.appState.visibleListIDs(from: service.lists)
            await self.linkFilterService.prefetchAdjacentFeeds(
                currentFeedId: initialFeedID,
                allFeedIds: allFeedIDs
            ) { feedId in
                await service.prefetchLinkFeedStatuses(feedId: feedId)
            }
        }
    }

    @MainActor
    private func loadListsAndApplyDefault(using service: TimelineService) async -> String {
        guard appState.hasAccount else { return AppState.homeFeedID }

        await service.loadLists()
        let resolution = appState.synchronizeCurrentAccountListDisplayPreferences(
            with: service.lists,
            allowEmptyListSet: true
        )
        if !service.lists.isEmpty {
            timelineWrapper.updateCachedLists(service.lists, for: appState.currentAccount?.id)
        }

        let persistedDefaultListID =
            UserDefaults.standard.string(forKey: AppState.defaultListIdStorageKey) ?? defaultListId
        return appState.applyDefaultLinkFeed(
            defaultListId: persistedDefaultListID,
            availableListIDs: resolution.visibleListIDs
        )
    }

    @MainActor
    private func handleOpenURL(_ url: URL) {
        if appState.authService.isValidCallback(url: url) {
            Task {
                do {
                    let account = try await appState.authService.handleCallback(url: url, modelContext: modelContext)
                    await appState.emojiService.fetchCustomEmojis(for: account.instance)
                } catch {
                    appState.handleError(error)
                }
            }
        }
    }

    @MainActor
    private func handleReadLaterSaveResult(_ result: ReadLaterSaveResult) {
        if result.success {
            let message = result.url.host ?? result.url.absoluteString
            appState.presentedAlert = AlertItem(
                title: "Saved to \(result.serviceType.displayName)",
                message: message
            )
            return
        }

        if let error = result.error {
            appState.handleError(error)
        } else {
            appState.presentedAlert = AlertItem(
                title: "Save Failed",
                message: "Could not save to \(result.serviceType.displayName)"
            )
        }
    }
}

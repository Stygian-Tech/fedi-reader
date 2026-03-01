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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("defaultListId") private var defaultListId = ""
    @State private var appState = AppState()
    @State private var timelineWrapper = TimelineServiceWrapper()
    @State private var linkFilterService = LinkFilterService()
    @State private var readLaterManager = ReadLaterManager()
    @State private var hasAppliedDefaultList = false
    @State private var stabilizedLayoutMode: LayoutMode = .compact

    var body: some View {
        GeometryReader { geometry in
            let topChromePadding = resolvedTopChromePadding(for: geometry.safeAreaInsets.top)
            Group {
                if appState.hasAccount {
                    MainTabView()
                } else {
                    WelcomeView()
                }
            }
            .environment(\.layoutMode, stabilizedLayoutMode)
            #if os(macOS)
            .windowBackgroundColor(colorScheme: colorScheme)
            #endif
            .safeAreaPadding(.top, topChromePadding)
            .modifier(LeadingSafeAreaForWindowChrome(geometry: geometry))
            #if os(macOS)
            .containerBackground(colorScheme == .dark ? Color(red: 0, green: 0, blue: 0) : Color.white, for: .window)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            #else
            .background {
                (colorScheme == .dark ? Color(red: 0, green: 0, blue: 0) : Color.white)
                    .ignoresSafeArea()
            }
            #endif
            .onAppear {
                stabilizedLayoutMode = LayoutMode.mode(for: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                stabilizedLayoutMode = LayoutMode.stabilizedMode(
                    for: newWidth,
                    previous: stabilizedLayoutMode
                )
            }
        }
        .environment(appState)
        .environment(linkFilterService)
        .environment(readLaterManager)
        .environment(timelineWrapper)
        .onAppear {
            setupServices()
            updateInboxAutoRefresh(for: scenePhase)
        }
        .task {
            await appState.authService.migrateOAuthClientSecretsToKeychain(modelContext: modelContext)
            await loadListsAndApplyDefault()
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .onChange(of: scenePhase) { _, newPhase in
            updateInboxAutoRefresh(for: newPhase)
        }
        .onChange(of: appState.currentAccount?.id) { _, _ in
            updateInboxAutoRefresh(for: scenePhase)
            Task {
                await appState.authService.refreshClientAuthenticationState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readLaterDidSave)) { notification in
            guard let result = notification.object as? ReadLaterSaveResult else { return }
            handleReadLaterSaveResult(result)
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
        appState.authService.loadAccounts(from: modelContext)
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
        
        // Fetch emoji for current account's instance
        if let instance = appState.getCurrentInstance() {
            Task {
                await appState.emojiService.fetchCustomEmojis(for: instance)
            }
        }

        updateInboxAutoRefresh(for: scenePhase)
    }

    private func updateInboxAutoRefresh(for phase: ScenePhase) {
        guard let service = timelineWrapper.service else { return }
        if appState.hasAccount, phase == .active {
            service.startInboxAutoRefresh()
        } else {
            service.stopInboxAutoRefresh()
        }
    }

    private func loadListsAndApplyDefault() async {
        guard appState.hasAccount, !hasAppliedDefaultList else { return }

        if let service = timelineWrapper.service {
            await service.loadLists()
            if !service.lists.isEmpty {
                timelineWrapper.updateCachedLists(service.lists, for: appState.currentAccount?.id)
            }
            if !defaultListId.isEmpty {
                let listExists = service.lists.contains { $0.id == defaultListId }
                if listExists {
                    appState.selectedListId = defaultListId
                }
            }
        }
        hasAppliedDefaultList = true
    }

    private func handleOpenURL(_ url: URL) {
        if appState.authService.isValidCallback(url: url) {
            Task {
                do {
                    let account = try await appState.authService.handleCallback(url: url, modelContext: modelContext)
                    // Fetch custom emoji for the newly logged-in instance
                    await appState.emojiService.fetchCustomEmojis(for: account.instance)
                } catch {
                    appState.handleError(error)
                }
            }
        }
    }
    
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

    private func resolvedTopChromePadding(for safeAreaTop: CGFloat) -> CGFloat {
        #if os(iOS)
        return WindowChromeLayoutMetrics.topPadding(
            isPad: UIDevice.current.userInterfaceIdiom == .pad,
            safeAreaTop: safeAreaTop
        )
        #else
        return WindowChromeLayoutMetrics.defaultTopPadding
        #endif
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
                .environment(timelineWrapper)
        case .newMessage:
            NewMessageView()
                .environment(appState)
                .environment(timelineWrapper)
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

// MARK: - Leading Safe Area for Window Chrome

private struct LeadingSafeAreaForWindowChrome: ViewModifier {
    let geometry: GeometryProxy

    func body(content: Content) -> some View {
        #if os(macOS)
        content.safeAreaPadding(.leading, WindowChromeLayoutMetrics.leadingPadding)
        #else
        content.safeAreaPadding(
            .leading,
            geometry.size.width >= 744 ? WindowChromeLayoutMetrics.leadingPadding : 0
        )
        #endif
    }
}

// MARK: - Preview

#Preview("Content View") {
    ContentView()
        .modelContainer(for: [Account.self, CachedStatus.self, ReadLaterConfig.self], inMemory: true)
}

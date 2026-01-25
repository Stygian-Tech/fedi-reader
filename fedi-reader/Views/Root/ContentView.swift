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
    @AppStorage("defaultListId") private var defaultListId = ""
    @State private var appState = AppState()
    @State private var timelineWrapper = TimelineServiceWrapper()
    @State private var linkFilterService = LinkFilterService()
    @State private var readLaterManager = ReadLaterManager()
    @State private var hasAppliedDefaultList = false

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
        .task {
            await appState.authService.migrateOAuthClientSecretsToKeychain(modelContext: modelContext)
            await loadListsAndApplyDefault()
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
        timelineWrapper.service = TimelineService(
            client: appState.client,
            authService: appState.authService
        )
        appState.authService.loadAccounts(from: modelContext)
        readLaterManager.loadConfigurations(from: modelContext)
    }

    private func loadListsAndApplyDefault() async {
        guard appState.hasAccount, !hasAppliedDefaultList else { return }

        if let service = timelineWrapper.service {
            await service.loadLists()
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

// MARK: - Preview

#Preview("Content View") {
    ContentView()
        .modelContainer(for: [Account.self, CachedStatus.self, ReadLaterConfig.self], inMemory: true)
}

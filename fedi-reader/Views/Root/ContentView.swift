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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(ReadLaterManager.self) private var readLaterManager
    @State private var stabilizedLayoutMode: LayoutMode = .compact

    var body: some View {
        @Bindable var state = appState

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
                Rectangle()
                    .fill(.ultraThinMaterial)
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
        .sheet(item: $state.presentedSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert(item: $state.presentedAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
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
    let appState = AppState()
    let timelineWrapper = TimelineServiceWrapper()
    let readLaterManager = ReadLaterManager()

    ContentView()
        .environment(appState)
        .environment(timelineWrapper)
        .environment(readLaterManager)
        .modelContainer(for: [Account.self, CachedStatus.self, ReadLaterConfig.self], inMemory: true)
}

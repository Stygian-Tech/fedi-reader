//
//  FediReaderApp.swift
//  fedi-reader
//
//  Main app entry point
//

import SwiftUI
import SwiftData
import AppIntents

@available(iOS 16.0, *)
private enum AppIntentsDependency {
    static let intentType: (any AppIntent.Type)? = nil
}

@main
struct FediReaderApp: App {
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(ThemeColor.resolved(from: themeColorName).color)
        }
        .modelContainer(sharedModelContainer)
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(AppState())
        }
        #endif
    }
}

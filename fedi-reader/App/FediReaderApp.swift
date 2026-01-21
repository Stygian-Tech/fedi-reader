//
//  FediReaderApp.swift
//  fedi-reader
//
//  Main app entry point
//

import SwiftUI
import SwiftData

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
                .tint(ThemeColor(rawValue: themeColorName)?.color ?? .blue)
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

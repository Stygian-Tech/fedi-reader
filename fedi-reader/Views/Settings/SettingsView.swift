//
//  SettingsView.swift
//  fedi-reader
//
//  App settings view
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @AppStorage("refreshInterval") private var refreshInterval = 5
    @AppStorage("showImages") private var showImages = true
    @AppStorage("autoPlayGifs") private var autoPlayGifs = false
    @AppStorage("defaultVisibility") private var defaultVisibility = "public"
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("defaultListId") private var defaultListId = ""
    
    private var lists: [MastodonList] {
        timelineWrapper.service?.lists ?? []
    }
    
    var body: some View {
        List {
            // Display
            Section("Display") {
                Toggle("Show Images", isOn: $showImages)
                Toggle("Auto-play GIFs", isOn: $autoPlayGifs)
                
                Picker("Theme Color", selection: $themeColorName) {
                    ForEach(ThemeColor.allCases, id: \.rawValue) { color in
                        HStack {
                            Circle()
                                .fill(color.color)
                                .frame(width: 20, height: 20)
                            Text(color.displayName)
                        }
                        .tag(color.rawValue)
                    }
                }
            }
            
            // Timeline
            Section("Timeline") {
                Picker("Default Feed", selection: $defaultListId) {
                    Text("Home").tag("")
                    ForEach(lists) { list in
                        Text(list.title).tag(list.id)
                    }
                }
                
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("Manual").tag(0)
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
            }
            
            // Posting
            Section("Posting") {
                Picker("Default Visibility", selection: $defaultVisibility) {
                    Label("Public", systemImage: "globe").tag("public")
                    Label("Unlisted", systemImage: "lock.open").tag("unlisted")
                    Label("Followers Only", systemImage: "lock").tag("private")
                }
            }
            
            // Accessibility
            Section("Accessibility") {
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }
            
            // About
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(Constants.appVersion) (\(Constants.appBuild))")
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: Constants.OAuth.appWebsite)!) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://github.com/fedi-reader/fedi-reader/issues")!) {
                    HStack {
                        Text("Report an Issue")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Debug (only in debug builds)
            #if DEBUG
            Section("Debug") {
                Button("Clear Cache") {
                    // Clear caches
                }
                
                Button("Reset All Settings", role: .destructive) {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                }
            }
            #endif
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Read Later Settings View

struct ReadLaterSettingsView: View {
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            // Configured services
            if !readLaterManager.configuredServices.isEmpty {
                Section("Configured Services") {
                    ForEach(readLaterManager.configuredServices) { config in
                        if let serviceType = config.service {
                            ReadLaterServiceRow(
                                config: config,
                                serviceType: serviceType,
                                isPrimary: config.isPrimary
                            )
                        }
                    }
                    .onDelete(perform: removeServices)
                }
            }
            
            // Add service
            Section("Add Service") {
                ForEach(ReadLaterServiceType.allCases) { serviceType in
                    if !isServiceConfigured(serviceType) {
                        Button {
                            appState.present(sheet: .readLaterLogin(serviceType))
                        } label: {
                            Label(serviceType.displayName, systemImage: serviceType.iconName)
                        }
                    }
                }
            }
            
            // Info
            Section {
                Text("Read-later services let you save articles for later reading. Configure your preferred service to enable quick-save from the link feed.")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Read Later")
    }
    
    private func isServiceConfigured(_ serviceType: ReadLaterServiceType) -> Bool {
        readLaterManager.configuredServices.contains { $0.service == serviceType }
    }
    
    private func removeServices(at offsets: IndexSet) {
        for index in offsets {
            let config = readLaterManager.configuredServices[index]
            Task {
                try? await readLaterManager.removeService(config, modelContext: modelContext)
            }
        }
    }
}

// MARK: - Read Later Service Row

struct ReadLaterServiceRow: View {
    let config: ReadLaterConfig
    let serviceType: ReadLaterServiceType
    let isPrimary: Bool
    
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            Label(serviceType.displayName, systemImage: serviceType.iconName)
            
            Spacer()
            
            if isPrimary {
                Text("Primary")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.clear, in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            if !isPrimary {
                Button {
                    readLaterManager.setPrimaryService(config, modelContext: modelContext)
                } label: {
                    Label("Set as Primary", systemImage: "star")
                }
            }
            
            Button(role: .destructive) {
                Task {
                    try? await readLaterManager.removeService(config, modelContext: modelContext)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

// MARK: - Theme Color

enum ThemeColor: String, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray
    case black
    case white
    case primary
    case secondary
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .teal: return .teal
        case .cyan: return .cyan
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .brown: return .brown
        case .gray: return .gray
        case .black: return .black
        case .white: return .white
        case .primary: return .primary
        case .secondary: return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

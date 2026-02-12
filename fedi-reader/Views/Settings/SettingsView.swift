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
    @AppStorage("hideTabBarLabels") private var hideTabBarLabels = false
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("defaultListId") private var defaultListId = ""
    @AppStorage("showQuoteBoost") private var showQuoteBoost = true
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false
    
    private var lists: [MastodonList] {
        timelineWrapper.service?.lists ?? []
    }
    
    var body: some View {
        List {
            // Display
            Section("Display") {
                Toggle("Show Images", isOn: $showImages)
                Toggle("Auto-play GIFs", isOn: $autoPlayGifs)
                Toggle("Hide Tab Bar Labels", isOn: $hideTabBarLabels)
                Toggle("Show Handle in Feed", isOn: $showHandleInFeed)
                
                NavigationLink {
                    ThemeColorSelectionView(selection: $themeColorName)
                } label: {
                    HStack {
                        Text("Theme Color")
                        Spacer()
                        if let selectedColor = ThemeColor(rawValue: themeColorName) {
                            ThemeColorPreviewCircle(themeColor: selectedColor)
                            Text(selectedColor.displayName)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(themeColorName.capitalized)
                                .foregroundStyle(.secondary)
                        }
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
                
                Toggle("Show Quote Boost Option", isOn: $showQuoteBoost)
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

// MARK: - Theme Color

private struct ThemeColorPreviewCircle: View {
    let themeColor: ThemeColor
    
    var body: some View {
        Circle()
            .fill(.thinMaterial)
            .overlay {
                Circle()
                    .inset(by: 3)
                    .fill(themeColor.color)
                    .overlay {
                        if themeColor.requiresContrastStrokeInPreview {
                            Circle()
                                .stroke(.secondary.opacity(0.35), lineWidth: 1)
                        }
                    }
            }
            .overlay {
                Circle()
                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
            }
            .frame(width: 22, height: 22)
    }
}

private struct ThemeColorSelectionView: View {
    @Binding var selection: String
    
    var body: some View {
        List {
            ForEach(ThemeColor.allCases, id: \.rawValue) { color in
                Button {
                    selection = color.rawValue
                } label: {
                    HStack(spacing: 12) {
                        ThemeColorPreviewCircle(themeColor: color)
                        Text(color.displayName)
                        Spacer()
                        if selection == color.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Theme Color")
    }
}

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
        }
    }
    
    var requiresContrastStrokeInPreview: Bool {
        switch self {
        case .yellow, .mint, .cyan:
            return true
        default:
            return false
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

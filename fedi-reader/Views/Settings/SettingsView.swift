import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.layoutMode) private var layoutMode
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
    
    private var selectedThemeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    private var isCompactDevice: Bool {
        #if os(macOS)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom != .pad
        #endif
    }
    
    var body: some View {
        Group {
            if layoutMode.useSidebarLayout {
                SettingsTwoColumnView(
                    refreshInterval: $refreshInterval,
                    showImages: $showImages,
                    autoPlayGifs: $autoPlayGifs,
                    defaultVisibility: $defaultVisibility,
                    hapticFeedback: $hapticFeedback,
                    hideTabBarLabels: $hideTabBarLabels,
                    themeColorName: $themeColorName,
                    defaultListId: $defaultListId,
                    showQuoteBoost: $showQuoteBoost,
                    showHandleInFeed: $showHandleInFeed,
                    lists: lists,
                    isCompactDevice: isCompactDevice
                )
            } else {
                settingsListContent
            }
        }
        .navigationTitle("Settings")
        .tint(selectedThemeColor)
        .id("settings-theme-\(themeColorName)")
    }

    private var settingsListContent: some View {
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
                        let selectedColor = ThemeColor.resolved(from: themeColorName)
                        ThemeColorPreviewCircle(themeColor: selectedColor)
                        Text(selectedColor.displayName)
                            .foregroundStyle(.secondary)
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
            if isCompactDevice {
                Section("Accessibility") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
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
                
                Link(destination: URL(string: "\(Constants.OAuth.appWebsite)/issues")!) {
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
    }
}

// MARK: - Settings Two Column View

private struct SettingsTwoColumnView: View {
    @Binding var refreshInterval: Int
    @Binding var showImages: Bool
    @Binding var autoPlayGifs: Bool
    @Binding var defaultVisibility: String
    @Binding var hapticFeedback: Bool
    @Binding var hideTabBarLabels: Bool
    @Binding var themeColorName: String
    @Binding var defaultListId: String
    @Binding var showQuoteBoost: Bool
    @Binding var showHandleInFeed: Bool
    let lists: [MastodonList]
    let isCompactDevice: Bool

    @State private var selectedSection: SettingsSection = .display
    @AppStorage("settingsSectionsWidth") private var persistedSectionsWidth: Double = 200
    @State private var sectionsWidth: Double = 200

    private static let minSectionsWidth: CGFloat = 160
    private static let minDetailWidth: CGFloat = 280

    private var selectedThemeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    enum SettingsSection: String, CaseIterable, Identifiable {
        case display
        case timeline
        case posting
        case accessibility
        case about
        case debug

        var id: String { rawValue }

        var title: String {
            switch self {
            case .display: return "Display"
            case .timeline: return "Timeline"
            case .posting: return "Posting"
            case .accessibility: return "Accessibility"
            case .about: return "About"
            case .debug: return "Debug"
            }
        }

        var systemImage: String {
            switch self {
            case .display: return "photo"
            case .timeline: return "list.bullet"
            case .posting: return "square.and.pencil"
            case .accessibility: return "accessibility"
            case .about: return "info.circle"
            case .debug: return "ant"
            }
        }
    }

    private var visibleSections: [SettingsSection] {
        var sections: [SettingsSection] = [.display, .timeline, .posting]
        if isCompactDevice {
            sections.append(.accessibility)
        }
        sections.append(.about)
        #if DEBUG
        sections.append(.debug)
        #endif
        return sections
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dividerTotal: CGFloat = 8
            let availableWidth = totalWidth - dividerTotal
            let resolvedSectionsWidth = min(
                max(CGFloat(sectionsWidth), Self.minSectionsWidth),
                availableWidth - Self.minDetailWidth
            )

            HStack(spacing: 0) {
                // Column 1: Section list
                GlassEffectContainer {
                    List(visibleSections) { section in
                        Button {
                            selectedSection = section
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: section.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(selectedSection == section ? .primary : .secondary)
                                Text(section.title)
                                    .font(.roundedBody)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedSection == section ? selectedThemeColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .frame(width: resolvedSectionsWidth)

                ResizableColumnDivider(
                    width: $sectionsWidth,
                    minValue: Self.minSectionsWidth,
                    maxValue: availableWidth - Self.minDetailWidth
                ) {
                    persistedSectionsWidth = sectionsWidth
                }

                // Column 2: Section content
                ScrollView {
                    sectionContent
                        .padding()
                }
                .frame(minWidth: Self.minDetailWidth, maxWidth: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            sectionsWidth = persistedSectionsWidth
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch selectedSection {
            case .display:
                displaySection
            case .timeline:
                timelineSection
            case .posting:
                postingSection
            case .accessibility:
                accessibilitySection
            case .about:
                aboutSection
            case .debug:
                debugSection
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display").font(.headline)
            VStack(spacing: 0) {
                settingsToggleRow("Show Images", isOn: $showImages)
                settingsToggleRow("Auto-play GIFs", isOn: $autoPlayGifs)
                settingsToggleRow("Hide Tab Bar Labels", isOn: $hideTabBarLabels)
                settingsToggleRow("Show Handle in Feed", isOn: $showHandleInFeed)
                NavigationLink {
                    ThemeColorSelectionView(selection: $themeColorName)
                } label: {
                    HStack {
                        Text("Theme Color")
                        Spacer()
                        ThemeColorPreviewCircle(themeColor: ThemeColor.resolved(from: themeColorName))
                        Text(ThemeColor.resolved(from: themeColorName).displayName)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline").font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Feed").font(.subheadline)
                    Picker("Default Feed", selection: $defaultListId) {
                        Text("Home").tag("")
                        ForEach(lists) { list in
                            Text(list.title).tag(list.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Refresh Interval").font(.subheadline)
                    Picker("Refresh Interval", selection: $refreshInterval) {
                        Text("Manual").tag(0)
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var postingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Posting").font(.headline)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Visibility").font(.subheadline)
                    Picker("Default Visibility", selection: $defaultVisibility) {
                        Label("Public", systemImage: "globe").tag("public")
                        Label("Unlisted", systemImage: "lock.open").tag("unlisted")
                        Label("Followers Only", systemImage: "lock").tag("private")
                    }
                    .pickerStyle(.menu)
                }
                settingsToggleRow("Show Quote Boost Option", isOn: $showQuoteBoost)
            }
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accessibility").font(.headline)
            settingsToggleRow("Haptic Feedback", isOn: $hapticFeedback)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About").font(.headline)
            VStack(alignment: .leading, spacing: 12) {
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
                Link(destination: URL(string: "\(Constants.OAuth.appWebsite)/issues")!) {
                    HStack {
                        Text("Report an Issue")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 16) {
            Text("Debug").font(.headline)
            VStack(spacing: 12) {
                Button("Clear Cache") {
                    // Clear caches
                }
                Button("Reset All Settings", role: .destructive) {
                    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                }
            }
        }
        #else
        EmptyView()
        #endif
    }

    private func settingsToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
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
    
    private var selectedThemeColor: Color {
        ThemeColor.resolved(from: selection).color
    }
    
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
        .tint(selectedThemeColor)
    }
}



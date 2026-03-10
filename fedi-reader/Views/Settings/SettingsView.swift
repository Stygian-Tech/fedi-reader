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
    @AppStorage("articleViewerPreference") private var articleViewerPreferenceRaw = ArticleViewerPreference.inApp.rawValue

    private var accountID: String? {
        appState.currentAccount?.id
    }

    private var rawLists: [MastodonList] {
        let liveLists = timelineWrapper.service?.lists ?? []
        if !liveLists.isEmpty {
            return liveLists
        }
        return timelineWrapper.cachedLists(for: accountID)
    }
    
    private var lists: [MastodonList] {
        return appState.visibleLists(from: rawLists)
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
                    articleViewerPreferenceRaw: $articleViewerPreferenceRaw,
                    lists: lists,
                    isCompactDevice: isCompactDevice
                )
            } else {
                settingsListContent
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(selectedThemeColor)
        .onAppear {
            _ = appState.synchronizeCurrentAccountListDisplayPreferences(with: rawLists)
        }
        .onChange(of: lists.map(\.id)) { _, visibleListIDs in
            if !defaultListId.isEmpty, !visibleListIDs.contains(defaultListId) {
                defaultListId = ""
            }
        }
    }

    private var settingsListContent: some View {
        List {
            // Display
            Section {
                Toggle("Show Images", isOn: $showImages)
                Toggle("Auto-play GIFs", isOn: $autoPlayGifs)
                Toggle("Hide Tab Bar Labels", isOn: $hideTabBarLabels)
                Toggle("Show Handle in Feed", isOn: $showHandleInFeed)

                Picker("Article Viewer", selection: $articleViewerPreferenceRaw) {
                    ForEach(ArticleViewerPreference.platformOptions, id: \.rawValue) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }

                NavigationLink(value: NavigationDestination.tabOrder) {
                    Label("Tab Order", systemImage: "rectangle.3.group")
                }

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
            } header: {
                Text("Display")
            }
            
            // Lists
            Section("Lists") {
                NavigationLink(value: NavigationDestination.listDisplay) {
                    Label("List Display", systemImage: "list.bullet.rectangle")
                }
            }

            // Read Later
            Section("Read Later") {
                NavigationLink(value: NavigationDestination.readLaterSettings) {
                    Label("Read Later Services", systemImage: "bookmark")
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
                    VisibilityPickerOption(icon: "globe", title: "Public").tag("public")
                    VisibilityPickerOption(icon: "lock.open", title: "Unlisted").tag("unlisted")
                    VisibilityPickerOption(icon: "lock", title: "Followers Only").tag("private")
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
        .id(themeColorName)
        .tint(selectedThemeColor)
        .listStyle(.insetGrouped)
        .contentMargins(.vertical, 16, for: .scrollContent)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity, alignment: .center)
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
    @Binding var articleViewerPreferenceRaw: String
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
        case lists
        case readLater
        case timeline
        case posting
        case accessibility
        case about
        case debug

        var id: String { rawValue }

        var title: String {
            switch self {
            case .display: return "Display"
            case .lists: return "Lists"
            case .readLater: return "Read Later"
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
            case .lists: return "list.bullet.rectangle"
            case .readLater: return "bookmark"
            case .timeline: return "list.bullet"
            case .posting: return "square.and.pencil"
            case .accessibility: return "accessibility"
            case .about: return "info.circle"
            case .debug: return "ant"
            }
        }
    }

    private var visibleSections: [SettingsSection] {
        var sections: [SettingsSection] = [.display, .lists, .readLater, .timeline, .posting]
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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedSection == section ? selectedThemeColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(Self.sidebarRowInsets)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.horizontal, 6, for: .scrollContent)
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
                sectionContent
                    .frame(minWidth: Self.minDetailWidth, maxWidth: Self.detailPaneMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemBackground))
            }
        }
        .onAppear {
            sectionsWidth = persistedSectionsWidth
        }
    }

    private static let detailPaneMaxWidth: CGFloat = 780
    private static let detailPanePadding: CGFloat = 24
    private static let detailPaneHorizontalPadding: CGFloat = 32
    private static let detailRowInsets = EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
    private static let sidebarRowInsets = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)

    @ViewBuilder
    private var sectionContent: some View {
        List {
            switch selectedSection {
            case .display:
                Section {
                    settingsToggleRow("Show Images", isOn: $showImages)
                    settingsToggleRow("Auto-play GIFs", isOn: $autoPlayGifs)
                    settingsToggleRow("Hide Tab Bar Labels", isOn: $hideTabBarLabels)
                    settingsToggleRow("Show Handle in Feed", isOn: $showHandleInFeed)
                    Picker(selection: $articleViewerPreferenceRaw) {
                        ForEach(ArticleViewerPreference.platformOptions, id: \.rawValue) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    } label: {
                        Text("Article Viewer").font(.roundedBody)
                    }
                    .pickerStyle(.menu)
                    .listRowInsets(Self.detailRowInsets)
                    NavigationLink(value: NavigationDestination.tabOrder) {
                        Label("Tab Order", systemImage: "rectangle.3.group")
                            .font(.roundedBody)
                    }
                    .listRowInsets(Self.detailRowInsets)
                    NavigationLink {
                        ThemeColorSelectionView(selection: $themeColorName)
                    } label: {
                        HStack {
                            Text("Theme Color")
                                .font(.roundedBody)
                            Spacer()
                            ThemeColorPreviewCircle(themeColor: ThemeColor.resolved(from: themeColorName))
                            Text(ThemeColor.resolved(from: themeColorName).displayName)
                                .font(.roundedBody)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("Display").font(.roundedTitle3)
                }

            case .lists:
                Section {
                    NavigationLink {
                        ListDisplaySettingsView()
                    } label: {
                        Label("List Display", systemImage: "list.bullet.rectangle")
                            .font(.roundedBody)
                    }
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("Lists").font(.roundedTitle3)
                }

            case .readLater:
                Section {
                    NavigationLink {
                        ReadLaterSettingsView()
                    } label: {
                        Label("Read Later Services", systemImage: "bookmark")
                            .font(.roundedBody)
                    }
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("Read Later").font(.roundedTitle3)
                }

            case .timeline:
                Section {
                    Picker(selection: $defaultListId) {
                        Text("Home").tag("")
                        ForEach(lists) { list in
                            Text(list.title).tag(list.id)
                        }
                    } label: {
                        Text("Default Feed").font(.roundedBody)
                    }
                    .pickerStyle(.menu)
                    .listRowInsets(Self.detailRowInsets)

                    Picker(selection: $refreshInterval) {
                        Text("Manual").tag(0)
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                    } label: {
                        Text("Refresh Interval").font(.roundedBody)
                    }
                    .pickerStyle(.menu)
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("Timeline").font(.roundedTitle3)
                }

            case .posting:
                Section {
                    Picker(selection: $defaultVisibility) {
                        VisibilityPickerOption(icon: "globe", title: "Public").tag("public")
                        VisibilityPickerOption(icon: "lock.open", title: "Unlisted").tag("unlisted")
                        VisibilityPickerOption(icon: "lock", title: "Followers Only").tag("private")
                    } label: {
                        Text("Default Visibility").font(.roundedBody)
                    }
                    .pickerStyle(.menu)
                    .listRowInsets(Self.detailRowInsets)

                    settingsToggleRow("Show Quote Boost Option", isOn: $showQuoteBoost)
                } header: {
                    Text("Posting").font(.roundedTitle3)
                }

            case .accessibility:
                Section {
                    settingsToggleRow("Haptic Feedback", isOn: $hapticFeedback)
                } header: {
                    Text("Accessibility").font(.roundedTitle3)
                }

            case .about:
                Section {
                    HStack {
                        Text("Version")
                            .font(.roundedBody)
                        Spacer()
                        Text("\(Constants.appVersion) (\(Constants.appBuild))")
                            .font(.roundedBody)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(Self.detailRowInsets)
                    Link(destination: URL(string: Constants.OAuth.appWebsite)!) {
                        HStack {
                            Text("GitHub")
                                .font(.roundedBody)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowInsets(Self.detailRowInsets)
                    Link(destination: URL(string: "\(Constants.OAuth.appWebsite)/issues")!) {
                        HStack {
                            Text("Report an Issue")
                                .font(.roundedBody)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("About").font(.roundedTitle3)
                }

            case .debug:
                #if DEBUG
                Section {
                    Button("Clear Cache") {
                        // Clear caches
                    }
                    .font(.roundedBody)
                    .listRowInsets(Self.detailRowInsets)

                    Button("Reset All Settings", role: .destructive) {
                        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                    }
                    .font(.roundedBody)
                    .listRowInsets(Self.detailRowInsets)
                } header: {
                    Text("Debug").font(.roundedTitle3)
                }
                #else
                EmptyView()
                #endif
            }
        }
        .id(themeColorName)
        .tint(selectedThemeColor)
        .contentMargins(.vertical, Self.detailPanePadding, for: .scrollContent)
        .contentMargins(.horizontal, Self.detailPaneHorizontalPadding, for: .scrollContent)
        #if os(macOS)
        .listStyle(.grouped)
        #else
        .listStyle(.insetGrouped)
        #endif
    }

    private func settingsToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.roundedBody)
            .listRowInsets(Self.detailRowInsets)
    }
}

// MARK: - Visibility Picker Option

private struct VisibilityPickerOption: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
            Text(title)
        }
        .fixedSize(horizontal: true, vertical: false)
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

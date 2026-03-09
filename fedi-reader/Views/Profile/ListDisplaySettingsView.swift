import SwiftUI

enum ListDisplaySettingsFeatures {
    static func editMode(isCustomSortOrder: Bool) -> EditMode {
        isCustomSortOrder ? .active : .inactive
    }
}

struct ListDisplaySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var isLoading = false
    @State private var editMode: EditMode = .inactive

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var accountID: String? {
        appState.currentAccount?.id
    }

    private var liveLists: [MastodonList] {
        timelineService?.lists ?? []
    }

    private var cachedLists: [MastodonList] {
        timelineWrapper.cachedLists(for: accountID)
    }

    private var rawLists: [MastodonList] {
        if !liveLists.isEmpty {
            return liveLists
        }
        return cachedLists
    }

    private var resolution: AccountListDisplayResolution {
        appState.resolvedListDisplay(for: rawLists)
    }

    private var isCustomSortOrder: Bool {
        resolution.normalizedPreferences.sortOrder == .custom
    }

    var body: some View {
        List {
            ListDisplayEditorSections(
                rawLists: rawLists,
                resolution: resolution,
                isLoading: isLoading,
                showHomeNote: true,
                showsVisibleSection: true
            )
        }
        .navigationTitle("List Display")
        .environment(\.editMode, $editMode)
        .task {
            await loadLists()
        }
        .onAppear {
            editMode = ListDisplaySettingsFeatures.editMode(isCustomSortOrder: isCustomSortOrder)
            if !rawLists.isEmpty {
                appState.synchronizeCurrentAccountListDisplayPreferences(with: rawLists)
            }
        }
        .onChange(of: isCustomSortOrder) { _, newValue in
            editMode = ListDisplaySettingsFeatures.editMode(isCustomSortOrder: newValue)
        }
        .onChange(of: liveLists) { _, newLists in
            appState.synchronizeCurrentAccountListDisplayPreferences(with: newLists)
        }
    }

    private func loadLists() async {
        guard let timelineService else { return }
        isLoading = true
        await timelineService.loadLists(forceRefresh: rawLists.isEmpty)
        appState.synchronizeCurrentAccountListDisplayPreferences(
            with: timelineService.lists,
            allowEmptyListSet: true
        )
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        ListDisplaySettingsView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

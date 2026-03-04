import SwiftUI

struct ListDisplaySettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var isLoading = false

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
            Section("Order") {
                Picker("Sort Order", selection: sortOrderBinding) {
                    ForEach(ListDisplaySortOrder.allCases) { sortOrder in
                        Text(sortOrder.title).tag(sortOrder)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Label("Home always stays first and visible.", systemImage: "house.fill")
                    .foregroundStyle(.secondary)
            }

            Section("Visible") {
                if isLoading && rawLists.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if resolution.visibleLists.isEmpty {
                    Text("No visible lists.")
                        .foregroundStyle(.secondary)
                } else if resolution.normalizedPreferences.sortOrder == .custom {
                    ForEach(resolution.visibleLists) { list in
                        listVisibilityRow(for: list, isVisible: true)
                    }
                    .onMove(perform: moveVisibleLists)
                } else {
                    ForEach(resolution.visibleLists) { list in
                        listVisibilityRow(for: list, isVisible: true)
                    }
                }
            }

            Section("Hidden") {
                if resolution.hiddenLists.isEmpty {
                    Text("No hidden lists.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(resolution.hiddenLists) { list in
                        listVisibilityRow(for: list, isVisible: false)
                    }
                }
            }
        }
        .navigationTitle("List Display")
        .environment(\.editMode, .constant(isCustomSortOrder ? .active : .inactive))
        .task {
            await loadLists()
        }
        .onAppear {
            if !rawLists.isEmpty {
                appState.synchronizeCurrentAccountListDisplayPreferences(with: rawLists)
            }
        }
        .onChange(of: liveLists) { _, newLists in
            appState.synchronizeCurrentAccountListDisplayPreferences(with: newLists)
        }
    }

    private var sortOrderBinding: Binding<ListDisplaySortOrder> {
        Binding(
            get: { appState.currentAccountListDisplayPreferences.sortOrder },
            set: { newSortOrder in
                appState.updateListDisplaySortOrder(newSortOrder, rawLists: rawLists)
            }
        )
    }

    private func listVisibilityRow(for list: MastodonList, isVisible: Bool) -> some View {
        HStack(spacing: 12) {
            Text(list.title)

            Spacer(minLength: 0)

            Button {
                setVisibility(for: list, isVisible: !isVisible)
            } label: {
                Image(systemName: isVisible ? "minus.circle" : "plus.circle")
                    .foregroundStyle(isVisible ? Color.red : Color.accentColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide \(list.title)" : "Show \(list.title)")
        }
    }

    private func setVisibility(for list: MastodonList, isVisible: Bool) {
        appState.setListVisibility(
            listID: list.id,
            isVisible: isVisible,
            rawLists: rawLists
        )
    }

    private func moveVisibleLists(fromOffsets: IndexSet, toOffset: Int) {
        appState.moveVisibleLists(
            fromOffsets: fromOffsets,
            toOffset: toOffset,
            rawLists: rawLists
        )
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

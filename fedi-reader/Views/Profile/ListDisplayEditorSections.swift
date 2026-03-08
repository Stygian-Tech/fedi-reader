import SwiftUI

struct ListDisplayEditorSections: View {
    @Environment(AppState.self) private var appState

    let rawLists: [MastodonList]
    let resolution: AccountListDisplayResolution
    let isLoading: Bool
    let showHomeNote: Bool
    let showsVisibleSection: Bool

    var body: some View {
        Section("Order") {
            Picker("Sort Order", selection: sortOrderBinding) {
                ForEach(ListDisplaySortOrder.allCases) { sortOrder in
                    Text(sortOrder.title).tag(sortOrder)
                }
            }
            .pickerStyle(.menu)
        }

        if showHomeNote {
            Section {
                Label("Home always stays first and visible.", systemImage: "house.fill")
                    .foregroundStyle(.secondary)
            }
        }

        if showsVisibleSection {
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
}

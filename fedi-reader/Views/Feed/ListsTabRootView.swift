import SwiftUI

enum ListsTabEditingFeatures {
    static func shouldShowEditor(editMode: EditMode) -> Bool {
        editMode.isEditing
    }

    static func visibleListsSectionTitle(editMode: EditMode) -> String? {
        shouldShowEditor(editMode: editMode) ? "Visible" : nil
    }
}

struct ListsTabRootView: View {
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

    private var shouldShowEditor: Bool {
        ListsTabEditingFeatures.shouldShowEditor(editMode: editMode)
    }

    private var visibleListsSectionTitle: String? {
        ListsTabEditingFeatures.visibleListsSectionTitle(editMode: editMode)
    }

    var body: some View {
        List {
            if let visibleListsSectionTitle {
                Section(visibleListsSectionTitle) {
                    visibleListsContent(editable: true)
                }
            } else {
                Section {
                    visibleListsContent(editable: false)
                }
            }

            if shouldShowEditor {
                ListDisplayEditorSections(
                    rawLists: rawLists,
                    resolution: resolution,
                    isLoading: isLoading,
                    showHomeNote: false,
                    showsVisibleSection: false
                )
            }
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .task {
            await loadLists()
        }
        .onAppear {
            appState.synchronizeCurrentAccountListDisplayPreferences(
                with: rawLists,
                allowEmptyListSet: true
            )
            navigateToPendingListIfNeeded()
        }
        .onChange(of: liveLists) { _, newLists in
            appState.synchronizeCurrentAccountListDisplayPreferences(
                with: newLists,
                allowEmptyListSet: true
            )
            navigateToPendingListIfNeeded()
        }
    }

    private func loadLists() async {
        guard let timelineService else { return }
        isLoading = true
        await timelineService.loadLists(forceRefresh: rawLists.isEmpty)
        if !timelineService.lists.isEmpty {
            timelineWrapper.updateCachedLists(timelineService.lists, for: accountID)
        }
        appState.synchronizeCurrentAccountListDisplayPreferences(
            with: timelineService.lists,
            allowEmptyListSet: true
        )
        isLoading = false
        navigateToPendingListIfNeeded()
    }

    private func navigateToPendingListIfNeeded() {
        guard appState.selectedTab == .lists else { return }
        guard appState.listsNavigationPath.isEmpty else { return }
        guard let pendingListID = appState.pendingListNavigationListID else { return }
        guard let list = resolution.visibleLists.first(where: { $0.id == pendingListID }) else { return }

        appState.listsNavigationPath = [.listFeed(list)]
        appState.pendingListNavigationListID = nil
    }

    @ViewBuilder
    private func visibleListsContent(editable: Bool) -> some View {
        if isLoading && rawLists.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if resolution.visibleLists.isEmpty {
            Text("No visible lists.")
                .foregroundStyle(.secondary)
        } else if editable {
            if resolution.normalizedPreferences.sortOrder == .custom {
                Group {
                    ForEach(resolution.visibleLists) { list in
                        editableVisibleListRow(for: list)
                            .id(ListsTabRootView.editableRowIdentity(listID: list.id))
                    }
                    .onMove(perform: moveVisibleLists)
                }
                .id(ListsTabRootView.sortedVisibleListIDsIdentity(resolution.visibleLists))
                .animation(nil, value: ListsTabRootView.sortedVisibleListIDsIdentity(resolution.visibleLists))
            } else {
                ForEach(resolution.visibleLists) { list in
                    editableVisibleListRow(for: list)
                        .id(ListsTabRootView.editableRowIdentity(listID: list.id))
                }
            }
        } else {
            ForEach(resolution.visibleLists) { list in
                NavigationLink(value: NavigationDestination.listFeed(list)) {
                    Label(list.title, systemImage: "list.bullet")
                }
            }
        }
    }

    private static func sortedVisibleListIDsIdentity(_ lists: [MastodonList]) -> String {
        lists.map(\.id).sorted().joined(separator: "\u{1e}")
    }

    private static func editableRowIdentity(listID: String) -> String {
        "\(listID)\u{1e}listsTab-editable"
    }

    private func editableVisibleListRow(for list: MastodonList) -> some View {
        HStack(spacing: 12) {
            Text(list.title)

            Spacer(minLength: 0)

            Button {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    appState.setListVisibility(
                        listID: list.id,
                        isVisible: false,
                        rawLists: rawLists
                    )
                }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Color.red)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide \(list.title)")
        }
    }

    private func moveVisibleLists(fromOffsets: IndexSet, toOffset: Int) {
        appState.moveVisibleLists(
            fromOffsets: fromOffsets,
            toOffset: toOffset,
            rawLists: rawLists
        )
    }
}

struct ListFeedDetailView: View {
    @Environment(\.layoutMode) private var layoutMode

    let list: MastodonList

    private var listFeedTab: FeedTabItem {
        FeedTabItem(id: list.id, title: list.title)
    }

    var body: some View {
        Group {
            switch layoutMode {
            case .wide, .medium:
                LinkFeedTwoColumnView(
                    feedTabsOverride: [listFeedTab],
                    showsFeedPicker: false,
                    allowsSwipeNavigation: false,
                    titleOverride: list.title,
                    userFilterToolbarPlacement: .listsDetail
                )
            case .compact:
                LinkFeedView(
                    feedTabsOverride: [listFeedTab],
                    showsFeedPicker: false,
                    allowsSwipeNavigation: false,
                    titleOverride: list.title,
                    userFilterToolbarPlacement: .listsDetail
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ListsTabRootView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

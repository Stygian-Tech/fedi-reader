//
//  ListManagementView.swift
//  fedi-reader
//
//  Manage list membership for an account.
//

import SwiftUI

struct ListManagementView: View {
    let account: MastodonAccount

    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(\.dismiss) private var dismiss

    @State private var selectedListIds = Set<String>()
    @State private var updatingListIds = Set<String>()
    @State private var isLoading = true
    @State private var isCreatingList = false
    @State private var newListTitle = ""

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var lists: [MastodonList] {
        timelineService?.lists ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Lists") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if lists.isEmpty {
                        Text("No lists yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(lists) { list in
                            Toggle(isOn: binding(for: list)) {
                                Text(list.title)
                            }
                            .disabled(updatingListIds.contains(list.id))
                        }
                    }
                }

                Section("Create New List") {
                    TextField("List name", text: $newListTitle)
                    Button {
                        createList()
                    } label: {
                        Label("Create & Add", systemImage: "plus")
                    }
                    .disabled(newListTitle.trimmed().isEmpty || isCreatingList)
                }
            }
            .navigationTitle("Manage Lists")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadListMembership()
        }
    }

    private func binding(for list: MastodonList) -> Binding<Bool> {
        Binding(
            get: { selectedListIds.contains(list.id) },
            set: { shouldInclude in
                Task {
                    await updateMembership(listId: list.id, shouldInclude: shouldInclude)
                }
            }
        )
    }

    private func loadListMembership() async {
        guard let service = timelineService else { return }
        isLoading = true
        await service.loadLists()
        let accountLists = await service.fetchListsContainingAccount(accountId: account.id)
        selectedListIds = Set(accountLists.map { $0.id })
        isLoading = false
    }

    private func updateMembership(listId: String, shouldInclude: Bool) async {
        guard let service = timelineService else { return }
        guard !updatingListIds.contains(listId) else { return }
        updatingListIds.insert(listId)

        let previousValue = selectedListIds.contains(listId)
        if shouldInclude {
            selectedListIds.insert(listId)
        } else {
            selectedListIds.remove(listId)
        }

        let success: Bool
        if shouldInclude {
            success = await service.addAccount(account.id, toList: listId)
        } else {
            success = await service.removeAccount(account.id, fromList: listId)
        }

        if success {
            await refreshCurrentListIfNeeded(listId: listId)
        } else {
            if previousValue {
                selectedListIds.insert(listId)
            } else {
                selectedListIds.remove(listId)
            }
            if let error = service.error {
                appState.handleError(error)
            }
        }

        updatingListIds.remove(listId)
    }

    private func createList() {
        guard let service = timelineService else { return }
        let title = newListTitle.trimmed()
        guard !title.isEmpty else { return }

        isCreatingList = true
        Task {
            let list = await service.createList(title: title)
            if let list {
                selectedListIds.insert(list.id)
                let added = await service.addAccount(account.id, toList: list.id)
                if !added {
                    selectedListIds.remove(list.id)
                }
                await refreshCurrentListIfNeeded(listId: list.id)
            }

            if let error = service.error {
                appState.handleError(error)
            }

            newListTitle = ""
            isCreatingList = false
        }
    }

    private func refreshCurrentListIfNeeded(listId: String) async {
        guard let service = timelineService else { return }
        guard appState.selectedListId == listId else { return }
        await service.refreshListTimeline(listId: listId)
        await service.refreshListAccounts(listId: listId)
    }
}

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ListManagementView(
        account: MastodonAccount(
            id: "1",
            username: "user",
            acct: "user@example.com",
            displayName: "Example User",
            locked: false,
            bot: false,
            createdAt: Date(),
            note: "",
            url: "https://example.com/@user",
            avatar: "",
            avatarStatic: "",
            header: "",
            headerStatic: "",
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            lastStatusAt: nil,
            emojis: [],
            fields: []
        )
    )
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

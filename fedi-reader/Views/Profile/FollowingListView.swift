import SwiftUI
import os

struct FollowingListView: View {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "FollowingListView")
    let accountId: String
    let account: MastodonAccount
    @Environment(AppState.self) private var appState
    @State private var accounts: [MastodonAccount] = []
    @State private var isLoading = true
    @State private var maxId: String?
    @State private var hasMore = true
    
    var body: some View {
        Group {
            if !accounts.isEmpty {
                List(accounts) { listedAccount in
                    AccountRowView(account: listedAccount)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.navigate(to: .profile(listedAccount))
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .onAppear {
                        if listedAccount.id == accounts.last?.id {
                            loadMore()
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .listRowSpacing(8)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Not Following Anyone", systemImage: "person.2")
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: accountId) {
            maxId = nil
            hasMore = true
            accounts = []
            isLoading = true
            await loadFollowing()
        }
    }
    
    private func loadFollowing() async {
        guard let currentAccount = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            isLoading = false
            return
        }
        
        defer { isLoading = false }

        do {
            let requestMaxId = maxId
            let following = try await appState.client.getAccountFollowing(
                instance: currentAccount.instance,
                accessToken: token,
                accountId: accountId,
                maxId: requestMaxId
            )

            let mergeResult = PaginatedAccountList.merge(
                existing: requestMaxId == nil ? [] : accounts,
                incoming: following,
                requestedMaxId: requestMaxId,
                pageSize: Constants.Pagination.defaultLimit
            )

            accounts = mergeResult.mergedAccounts
            maxId = mergeResult.nextMaxId
            hasMore = mergeResult.hasMore
        } catch {
            Self.logger.error("Failed to load following: \(error.localizedDescription)")
        }
    }
    
    private func loadMore() {
        guard !isLoading, hasMore, maxId != nil else { return }
        isLoading = true
        Task {
            await loadFollowing()
        }
    }
}



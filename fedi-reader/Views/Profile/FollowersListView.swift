//
//  FollowersListView.swift
//  fedi-reader
//
//  List of accounts that follow a user
//

import SwiftUI
import os

struct FollowersListView: View {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "FollowersListView")
    let accountId: String
    let account: MastodonAccount
    @Environment(AppState.self) private var appState
    @State private var accounts: [MastodonAccount] = []
    @State private var isLoading = true
    @State private var maxId: String?
    
    var body: some View {
        Group {
            if !accounts.isEmpty {
                List(accounts) { account in
                    NavigationLink {
                        ProfileDetailView(account: account)
                    } label: {
                        AccountRowView(account: account)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    .onAppear {
                        if account.id == accounts.last?.id {
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
                ContentUnavailableView("No Followers", systemImage: "person.2")
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFollowers()
        }
    }
    
    private func loadFollowers() async {
        guard let currentAccount = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let followers = try await appState.client.getAccountFollowers(
                instance: currentAccount.instance,
                accessToken: token,
                accountId: accountId,
                maxId: maxId
            )
            
            if maxId == nil {
                accounts = followers
            } else {
                accounts.append(contentsOf: followers)
            }
            
            maxId = followers.last?.id
        } catch {
            Self.logger.error("Failed to load followers: \(error.localizedDescription)")
        }
    }
    
    private func loadMore() {
        guard !isLoading, maxId != nil else { return }
        Task {
            await loadFollowers()
        }
    }
}

#Preview {
    NavigationStack {
        FollowersListView(
            accountId: "123",
            account: MastodonAccount(
                id: "123",
                username: "test",
                acct: "test@example.com",
                displayName: "Test User",
                locked: false,
                bot: false,
                createdAt: Date(),
                note: "",
                url: "https://example.com/@test",
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
    }
    .environment(AppState())
}

//
//  FollowingListView.swift
//  fedi-reader
//
//  List of accounts that a user follows
//

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
                ContentUnavailableView("Not Following Anyone", systemImage: "person.2")
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFollowing()
        }
    }
    
    private func loadFollowing() async {
        guard let currentAccount = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let following = try await appState.client.getAccountFollowing(
                instance: currentAccount.instance,
                accessToken: token,
                accountId: accountId,
                maxId: maxId
            )
            
            if maxId == nil {
                accounts = following
            } else {
                accounts.append(contentsOf: following)
            }
            
            maxId = following.last?.id
        } catch {
            Self.logger.error("Failed to load following: \(error.localizedDescription)")
        }
    }
    
    private func loadMore() {
        guard !isLoading, maxId != nil else { return }
        Task {
            await loadFollowing()
        }
    }
}

struct AccountRowView: View {
    let account: MastodonAccount
    @State private var isManagingLists = false
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(url: account.avatarURL, size: 50)
                .contextMenu {
                    Button {
                        isManagingLists = true
                    } label: {
                        Label("Manage Lists", systemImage: "list.bullet")
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(account.displayName)
                        .font(.roundedHeadline)
                        .lineLimit(1)
                    
                    AccountBadgesView(account: account, size: .small)
                }
                
                Text("@\(account.acct)")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)
        }
        .sheet(isPresented: $isManagingLists) {
            ListManagementView(account: account)
        }
    }
}

#Preview {
    NavigationStack {
        FollowingListView(
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

//
//  PostsListView.swift
//  fedi-reader
//
//  List of posts for a specific account
//

import SwiftUI
import os

struct PostsListView: View {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "PostsListView")
    let accountId: String
    let account: MastodonAccount
    @Environment(AppState.self) private var appState
    @State private var statuses: [Status] = []
    @State private var isLoading = true
    @State private var maxId: String?
    
    var body: some View {
        Group {
            if !statuses.isEmpty {
                List(statuses) { status in
                    StatusRowView(status: status)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .onAppear {
                            if status.id == statuses.last?.id {
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
                ContentUnavailableView("No Posts", systemImage: "text.bubble")
            }
        }
        .navigationTitle("Posts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPosts()
        }
    }
    
    private func loadPosts() async {
        guard let currentAccount = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            isLoading = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let posts = try await appState.client.getAccountStatuses(
                instance: currentAccount.instance,
                accessToken: token,
                accountId: accountId,
                maxId: maxId,
                excludeReplies: false,
                excludeReblogs: false
            )
            
            if maxId == nil {
                statuses = posts
            } else {
                statuses.append(contentsOf: posts)
            }
            
            maxId = posts.last?.id
        } catch {
            Self.logger.error("Failed to load posts: \(error.localizedDescription)")
        }
    }
    
    private func loadMore() {
        guard !isLoading, maxId != nil else { return }
        Task {
            await loadPosts()
        }
    }
}

#Preview {
    NavigationStack {
        PostsListView(
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
                fields: [],
                source: nil
            )
        )
    }
    .environment(AppState())
}

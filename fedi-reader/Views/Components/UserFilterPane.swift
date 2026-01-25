//
//  UserFilterPane.swift
//  fedi-reader
//
//  Slide-over pane for filtering feed by user
//

import SwiftUI

struct UserFilterPane: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    let accounts: [MastodonAccount]
    let onSelectAccount: (MastodonAccount?) -> Void
    
    @State private var searchText = ""
    
    private var filteredAccounts: [MastodonAccount] {
        if searchText.isEmpty {
            return accounts
        }
        return accounts.filter { account in
            account.displayName.localizedCaseInsensitiveContains(searchText) ||
            account.username.localizedCaseInsensitiveContains(searchText) ||
            account.acct.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search users", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // All users option
                Button {
                    onSelectAccount(nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.title3)
                            .frame(width: Constants.UI.avatarSize, height: Constants.UI.avatarSize)
                            .foregroundStyle(.tint)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Users")
                                .font(.roundedSubheadline.bold())
                            
                            Text("Show posts from everyone")
                                .font(.roundedCaption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        if appState.selectedUserFilter == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.horizontal)
                
                // Account list
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No Users", systemImage: "person.slash")
                    } description: {
                        Text("No users found in this list")
                    }
                } else {
                    List {
                        ForEach(filteredAccounts) { account in
                            UserFilterRow(
                                account: account,
                                isSelected: appState.selectedUserFilter == account.id,
                                onSelect: {
                                    onSelectAccount(account)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Filter by User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        appState.isUserFilterOpen = false
                    }
                }
            }
        }
    }
}

// MARK: - User Filter Row

struct UserFilterRow: View {
    let account: MastodonAccount
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ProfileAvatarView(url: account.avatarURL, size: Constants.UI.avatarSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.roundedSubheadline.bold())
                        .lineLimit(1)
                    
                    Text("@\(account.acct)")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    UserFilterPane(
        accounts: [],
        onSelectAccount: { _ in }
    )
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

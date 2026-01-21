//
//  AccountSwitcherView.swift
//  fedi-reader
//
//  Multi-account switcher view
//

import SwiftUI
import SwiftData

struct AccountSwitcherView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Current accounts
                Section("Accounts") {
                    ForEach(appState.authService.accounts, id: \.id) { account in
                        AccountRow(
                            account: account,
                            isActive: account.id == appState.currentAccount?.id
                        ) {
                            selectAccount(account)
                        }
                    }
                    .onDelete(perform: deleteAccounts)
                }
                
                // Add account
                Section {
                    Button {
                        appState.present(sheet: .login)
                        dismiss()
                    } label: {
                        Label("Add Account", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectAccount(_ account: Account) {
        appState.authService.setActiveAccount(account, modelContext: modelContext)
        dismiss()
    }
    
    private func deleteAccounts(at offsets: IndexSet) {
        for index in offsets {
            let account = appState.authService.accounts[index]
            Task {
                try? await appState.authService.logout(account: account, modelContext: modelContext)
            }
        }
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .font(.roundedHeadline)
                    
                    Text(account.fullHandle)
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Active indicator
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Account Settings View

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            if let account = appState.currentAccount {
                // Account info
                Section {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(.tertiary)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.displayName)
                                .font(.roundedHeadline)
                            
                            Text(account.fullHandle)
                                .font(.roundedSubheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(account.instance)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Actions
                Section {
                    Button {
                        Task {
                            isRefreshing = true
                            try? await appState.authService.refreshAccountInfo(for: account, modelContext: modelContext)
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Label("Refresh Account Info", systemImage: "arrow.clockwise")
                            
                            if isRefreshing {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRefreshing)
                    
                    Link(destination: URL(string: "https://\(account.instance)/settings/profile")!) {
                        Label("Edit Profile on Web", systemImage: "safari")
                    }
                }
                
                // Danger zone
                Section {
                    Button(role: .destructive) {
                        Task {
                            try? await appState.authService.logout(account: account, modelContext: modelContext)
                        }
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Account",
                    systemImage: "person.slash",
                    description: Text("Please log in first")
                )
            }
        }
        .navigationTitle("Account Settings")
    }
}

#Preview {
    AccountSwitcherView()
        .environment(AppState())
}

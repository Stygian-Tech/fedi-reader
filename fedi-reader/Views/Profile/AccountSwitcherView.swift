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

#Preview {
    AccountSwitcherView()
        .environment(AppState())
}

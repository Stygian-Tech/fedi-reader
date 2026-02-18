//
//  ProfileView.swift
//  fedi-reader
//
//  Current user's profile view
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var profileFieldsByAccountID: [String: [Field]] = [:]
    @State private var fetchedProfileFieldAccounts: Set<String> = []
    @State private var loadingProfileFieldAccounts: Set<String> = []

    var body: some View {
        Group {
            if let account = appState.currentAccount {
                profileContent(account)
            } else {
                notLoggedInView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func profileContent(_ account: Account) -> some View {
        List {
            ProfileSummaryView(account: account.mastodonAccount, fields: profileFields(for: account))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)

            Section("Account") {
                Button {
                    appState.present(sheet: .accountSwitcher)
                } label: {
                    Label("Switch Account", systemImage: "person.2")
                }
                
                Button {
                    appState.navigate(to: .accountSettings)
                } label: {
                    Label("Account Settings", systemImage: "person.crop.circle.badge.checkmark")
                }
            }
            
            // Read Later
            Section("Read Later") {
                Button {
                    appState.navigate(to: .readLaterSettings)
                } label: {
                    Label("Read Later Services", systemImage: "bookmark")
                }
            }
            
            // App settings
            Section("App") {
                Button {
                    appState.navigate(to: .settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
            
            // Logout
            Section {
                Button(role: .destructive) {
                    Task {
                        try? await appState.authService.logout(account: account, modelContext: modelContext)
                    }
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
            
            // App info
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Fedi Reader")
                        .font(.roundedCaption.bold())
                    Text("Version \(Constants.appVersion) (\(Constants.appBuild))")
                        .font(.roundedCaption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
        .task(id: account.id) {
            await loadProfileFieldsIfNeeded(for: account)
        }
    }
    
    private var notLoggedInView: some View {
        ContentUnavailableView {
            Label("Not Logged In", systemImage: "person.slash")
        } description: {
            Text("Log in to view your profile")
        } actions: {
            Button("Log In") {
                appState.present(sheet: .login)
            }
            .buttonStyle(.bordered)
        }
    }

    private func profileFields(for account: Account) -> [Field] {
        profileFieldsByAccountID[account.id] ?? []
    }

    @MainActor
    private func loadProfileFieldsIfNeeded(for account: Account) async {
        guard !fetchedProfileFieldAccounts.contains(account.id),
              !loadingProfileFieldAccounts.contains(account.id) else {
            return
        }

        loadingProfileFieldAccounts.insert(account.id)
        defer {
            loadingProfileFieldAccounts.remove(account.id)
        }

        do {
            let profile = try await appState.authService.fetchVerifiedProfile(for: account)
            profileFieldsByAccountID[account.id] = profile.preferredFields
            fetchedProfileFieldAccounts.insert(account.id)
        } catch {
            if profileFieldsByAccountID[account.id] == nil {
                profileFieldsByAccountID[account.id] = []
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AppState())
}

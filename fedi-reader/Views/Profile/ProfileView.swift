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
            // Profile header
            Section {
                ProfileHeaderView(account: account)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            // Stats
            Section {
                HStack {
                    statButton(count: account.statusesCount, label: "Posts", account: account)
                    Divider()
                    statButton(count: account.followingCount, label: "Following", account: account)
                    Divider()
                    statButton(count: account.followersCount, label: "Followers", account: account)
                }
                .padding(.vertical, 8)
            }
            
            // Account actions
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
                
                Link(destination: URL(string: Constants.OAuth.appWebsite)!) {
                    Label("About Fedi Reader", systemImage: "info.circle")
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
            Section {
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
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 0, for: .scrollContent)
        .ignoresSafeArea(edges: .top)
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.roundedTitle2.bold())
            
            Text(label)
                .font(.roundedCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func statButton(count: Int, label: String, account: Account) -> some View {
        Button {
            let accountId = account.id.components(separatedBy: ":").last ?? account.id
            let mastodonAccount = account.mastodonAccount
            
            switch label {
            case "Posts":
                appState.navigate(to: .accountPosts(accountId: accountId, account: mastodonAccount))
            case "Following":
                appState.navigate(to: .accountFollowing(accountId: accountId, account: mastodonAccount))
            case "Followers":
                appState.navigate(to: .accountFollowers(accountId: accountId, account: mastodonAccount))
            default:
                break
            }
        } label: {
            statItem(count: count, label: label)
        }
        .buttonStyle(.plain)
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
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AppState())
}

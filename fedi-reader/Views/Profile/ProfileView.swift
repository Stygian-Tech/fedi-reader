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
    @Environment(\.openURL) private var openURL

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

            // Profile links
            if !profileFields(for: account).isEmpty {
                Section("Links") {
                    ForEach(Array(profileFields(for: account).enumerated()), id: \.offset) { _, field in
                        let destinationURL = profileFieldDestinationURL(for: field)

                        Button {
                            if let destinationURL {
                                openURL(destinationURL)
                            }
                        } label: {
                            profileLinkRow(field: field, destinationURL: destinationURL)
                        }
                        .buttonStyle(.plain)
                        .disabled(destinationURL == nil)
                    }
                }
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
        .task(id: account.id) {
            await loadProfileFieldsIfNeeded(for: account)
        }
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

    private func profileFields(for account: Account) -> [Field] {
        profileFieldsByAccountID[account.id] ?? []
    }

    private func profileLinkRow(field: Field, destinationURL: URL?) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(field.name)
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if field.verifiedAt != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.roundedCaption2)
                            .foregroundStyle(.green)
                    }
                }

                Text(field.value.htmlStripped)
                    .font(.roundedSubheadline)
                    .foregroundStyle(destinationURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Image(systemName: destinationURL == nil ? "link.slash" : "arrow.up.right.square")
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func profileFieldDestinationURL(for field: Field) -> URL? {
        if let url = field.value.extractedLinks.first {
            return url
        }

        let stripped = field.value.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix("http://") || stripped.hasPrefix("https://") else {
            return nil
        }
        return URL(string: stripped)
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

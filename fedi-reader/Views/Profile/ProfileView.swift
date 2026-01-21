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

// MARK: - Profile Header View

struct ProfileHeaderView: View {
    let account: Account
    
    var body: some View {
        VStack(spacing: 0) {
            // Header image
            if let headerURL = account.headerURL, let url = URL(string: headerURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.tertiary)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            
            // Avatar and info
            VStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(Circle().stroke(.background, lineWidth: 4))
                .offset(y: account.headerURL != nil ? -40 : 0)
                .padding(.bottom, account.headerURL != nil ? -40 : 0)
                .padding(.top, account.headerURL != nil ? 0 : 16)
                
                // Name and handle
                VStack(spacing: 4) {
                    Text(account.displayName)
                        .font(.roundedTitle2.bold())
                    
                    Text(account.fullHandle)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Bio
                if let note = account.note, !note.isEmpty {
                    Text(note)
                        .font(.roundedSubheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Profile Detail View (Other Users)

struct ProfileDetailView: View {
    let account: MastodonAccount
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                if let headerURL = account.headerURL {
                    AsyncImage(url: headerURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                
                // Avatar and info
                VStack(spacing: 12) {
                    AsyncImage(url: account.avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(.tertiary)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.background, lineWidth: 4))
                    .offset(y: account.headerURL != nil ? -40 : 0)
                    .padding(.bottom, account.headerURL != nil ? -40 : 0)
                    .padding(.top, account.headerURL != nil ? 0 : 16)
                    
                    VStack(spacing: 4) {
                        Text(account.displayName)
                            .font(.roundedTitle2.bold())
                        
                        Text("@\(account.acct)")
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(account.note.htmlToPlainText)
                        .font(.roundedSubheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    // Stats
                    HStack(spacing: 24) {
                        statButton(count: account.statusesCount, label: "Posts", account: account)
                        statButton(count: account.followingCount, label: "Following", account: account)
                        statButton(count: account.followersCount, label: "Followers", account: account)
                    }
                    .padding(.top, 8)
                    
                    // Fields (Profile Links)
                    if !account.fields.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(account.fields, id: \.name) { field in
                                    FieldCardView(field: field)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(account.displayName)
                    .font(.roundedHeadline)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Link(destination: URL(string: account.url)!) {
                    Image(systemName: "safari")
                }
            }
        }
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.roundedHeadline)
            
            Text(label)
                .font(.roundedCaption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func statButton(count: Int, label: String, account: MastodonAccount) -> some View {
        Button {
            switch label {
            case "Posts":
                appState.navigate(to: .accountPosts(accountId: account.id, account: account))
            case "Following":
                appState.navigate(to: .accountFollowing(accountId: account.id, account: account))
            case "Followers":
                appState.navigate(to: .accountFollowers(accountId: account.id, account: account))
            default:
                break
            }
        } label: {
            statItem(count: count, label: label)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Field Card View

struct FieldCardView: View {
    let field: Field
    
    var body: some View {
        Button {
            // Extract URL from field value (could be HTML)
            if let urlString = extractURL(from: field.value),
               let url = URL(string: urlString) {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if field.verifiedAt != nil {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.roundedCaption)
                    }
                    
                    Text(field.name)
                        .font(.roundedCaption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(field.value.htmlStripped)
                    .font(.roundedSubheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 200)
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private func extractURL(from html: String) -> String? {
        // Try to extract href from HTML link
        let pattern = #"href=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               let urlRange = Range(match.range(at: 1), in: html) {
                return String(html[urlRange])
            }
        }
        
        // If no href found, check if the stripped text is a URL
        let stripped = html.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if stripped.hasPrefix("http://") || stripped.hasPrefix("https://") {
            return stripped
        }
        
        return nil
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(AppState())
}

//
//  ProfileDetailView.swift
//  fedi-reader
//
//  Profile view for other users (MastodonAccount).
//

import SwiftUI

struct ProfileDetailView: View {
    let account: MastodonAccount
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let headerURL = account.headerURL {
                    GeometryReader { geo in
                        let top = geo.safeAreaInsets.top
                        let horizontal = geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
                        let scaleX = geo.size.width > 0 ? 1 + horizontal / geo.size.width : 1
                        let scaleY = 1 + top / 200

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
                        .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
                        .ignoresSafeArea(edges: [.top, .horizontal])
                    }
                    .frame(height: 200)
                    .clipped()
                }

                VStack(spacing: 12) {
                    ProfileAvatarView(url: account.avatarURL, size: 80)
                        .overlay(Circle().stroke(.background, lineWidth: 4))
                        .offset(y: account.headerURL != nil ? -40 : 0)
                        .padding(.bottom, account.headerURL != nil ? -40 : 0)
                        .padding(.top, account.headerURL != nil ? 0 : 16)

                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text(account.displayName)
                                .font(.roundedTitle2.bold())

                            AccountBadgesView(account: account, size: .medium)
                        }

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

                    HStack(spacing: 24) {
                        statButton(count: account.statusesCount, label: "Posts", account: account)
                        statButton(count: account.followingCount, label: "Following", account: account)
                        statButton(count: account.followersCount, label: "Followers", account: account)
                    }
                    .padding(.top, 8)

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

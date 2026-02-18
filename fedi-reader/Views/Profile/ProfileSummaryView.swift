//
//  ProfileSummaryView.swift
//  fedi-reader
//
//  Shared profile presentation used by own-profile and other-profile views.
//

import SwiftUI

struct ProfileSummaryView: View {
    let account: MastodonAccount
    let fields: [Field]

    @Environment(AppState.self) private var appState
    @State private var featuredTagNames: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            if let headerURL = account.headerURL {
                GeometryReader { geo in
                    let topInset = geo.safeAreaInsets.top
                    let leadingInset = geo.safeAreaInsets.leading
                    let trailingInset = geo.safeAreaInsets.trailing
                    let fullWidth = geo.size.width + leadingInset + trailingInset
                    let fullHeight = 200 + topInset

                    AsyncImage(url: headerURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                    }
                    .frame(width: fullWidth, height: fullHeight)
                    .clipped()
                    .offset(x: -leadingInset, y: -topInset)
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
                        EmojiText(text: account.displayName, emojis: account.emojis, font: .roundedTitle2.bold())

                        AccountBadgesView(account: account, size: .medium)
                    }

                    Text("@\(account.acct)")
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                }

                if !account.preferredNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        ProfileBioText(content: account.preferredNote, emojis: account.emojis)
                            .font(.roundedSubheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    } else {
                        Text(account.preferredNote.htmlToPlainTextPreservingNewlines)
                            .font(.roundedSubheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                }

                HStack(spacing: 24) {
                    statButton(count: account.statusesCount, label: "Posts")
                    statButton(count: account.followingCount, label: "Following")
                    statButton(count: account.followersCount, label: "Followers")
                }
                .padding(.top, 8)

                if !featuredTagNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Featured Tags")
                            .font(.roundedCaption.bold())
                            .foregroundStyle(.secondary)

                        TagView(tags: featuredTagNames, onTagTap: { tag in
                            appState.navigate(to: .hashtag(tag))
                        }, showAllTags: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if !fields.isEmpty {
                    ProfileLinksListView(fields: fields)
                        .padding(.top, 8)
                }
            }
            .padding(.bottom, 16)
        }
        .task(id: account.id) {
            await loadFeaturedTags()
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

    private func statButton(count: Int, label: String) -> some View {
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

    @MainActor
    private func loadFeaturedTags() async {
        guard let currentAccount = appState.currentAccount,
              let token = await appState.getAccessToken() else {
            featuredTagNames = []
            return
        }

        do {
            let featuredTags = try await appState.client.getAccountFeaturedTags(
                instance: currentAccount.instance,
                accessToken: token,
                accountId: account.id
            )

            var seen: Set<String> = []
            featuredTagNames = featuredTags
                .map(\.name)
                .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        } catch {
            featuredTagNames = []
        }
    }
}

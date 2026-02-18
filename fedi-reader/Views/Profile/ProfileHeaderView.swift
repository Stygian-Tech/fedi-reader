//
//  ProfileHeaderView.swift
//  fedi-reader
//
//  Profile header for current user (Account).
//

import SwiftUI
import SwiftData

struct ProfileHeaderView: View {
    let account: Account
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            if let headerURL = account.headerURL, let url = URL(string: headerURL) {
                GeometryReader { geo in
                    let topInset = geo.safeAreaInsets.top
                    let leadingInset = geo.safeAreaInsets.leading
                    let trailingInset = geo.safeAreaInsets.trailing
                    let fullWidth = geo.size.width + leadingInset + trailingInset
                    let fullHeight = 200 + topInset

                    AsyncImage(url: url) { image in
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
                ProfileAvatarView(url: URL(string: account.avatarURL ?? ""), size: 80)
                    .overlay(Circle().stroke(.background, lineWidth: 4))
                    .offset(y: account.headerURL != nil ? -40 : 0)
                    .padding(.bottom, account.headerURL != nil ? -40 : 0)
                    .padding(.top, account.headerURL != nil ? 0 : 16)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        EmojiText(text: account.displayName, emojis: appState.emojiService.getCustomEmojis(for: account.instance), font: .roundedTitle2.bold())
                    }

                    Text(account.fullHandle)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                }

                if let note = account.note, !note.isEmpty {
                    if #available(iOS 15.0, macOS 12.0, *) {
                        ProfileBioText(content: note, emojis: appState.emojiService.getCustomEmojis(for: account.instance))
                            .font(.roundedSubheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal)
                    } else {
                        Text(note.htmlToPlainTextPreservingNewlines)
                            .font(.roundedSubheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                            .foregroundStyle(.secondary)
                            .layoutPriority(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }
}

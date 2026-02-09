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
                        Text(account.displayName)
                            .font(.roundedTitle2.bold())
                    }

                    Text(account.fullHandle)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                }

                if let note = account.note, !note.isEmpty {
                    Text(note.htmlToPlainText)
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

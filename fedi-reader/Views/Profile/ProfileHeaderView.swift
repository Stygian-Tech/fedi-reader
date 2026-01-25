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
                    let top = geo.safeAreaInsets.top
                    let horizontal = geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
                    let scaleX = geo.size.width > 0 ? 1 + horizontal / geo.size.width : 1
                    let scaleY = 1 + top / 200

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
                    .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
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

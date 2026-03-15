//
//  AuthorAttributionView.swift
//  fedi-reader
//
//  Shared author attribution component with block and chip styles.
//  Mastodon attributions use theme color accents to stand out.
//

import SwiftUI

struct AuthorAttributionView: View {
    enum Style {
        case block(profilePictureURL: URL?, mastodonHandle: String?, showNavigationIcon: Bool)
        case chip
    }

    let authorName: String
    let isMastodonAttribution: Bool
    let style: Style

    @AppStorage("themeColor") private var themeColorName = "blue"

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    var body: some View {
        switch style {
        case .block(let profilePictureURL, let mastodonHandle, let showNavigationIcon):
            blockContent(
                profilePictureURL: profilePictureURL,
                mastodonHandle: mastodonHandle,
                showNavigationIcon: showNavigationIcon
            )
        case .chip:
            chipContent
        }
    }

    // MARK: - Block Style

    private func blockContent(
        profilePictureURL: URL?,
        mastodonHandle: String?,
        showNavigationIcon: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if let profilePictureURL {
                ProfileAvatarView(url: profilePictureURL, size: 36, usePersonIconForFallback: true)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isMastodonAttribution ? themeColor : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Author")
                    .font(.roundedCaption2)
                    .foregroundStyle(.secondary)

                Text(authorName)
                    .font(.roundedSubheadline.bold())
                    .lineLimit(1)

                if let mastodonHandle {
                    Text(mastodonHandle)
                        .font(.roundedCaption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if showNavigationIcon {
                Image(systemName: "arrow.up.right.square")
                    .font(.roundedSubheadline)
                    .foregroundStyle(isMastodonAttribution ? themeColor : .secondary)
            }
        }
        .padding(12)
        .background {
            ZStack {
                Color(.secondarySystemBackground).opacity(0.5)
                if isMastodonAttribution {
                    themeColor.opacity(0.12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if isMastodonAttribution {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeColor.opacity(0.35), lineWidth: 1)
            }
        }
    }

    // MARK: - Chip Style

    private var chipContent: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.crop.circle")
                .font(.roundedCaption2)
                .foregroundStyle(isMastodonAttribution ? themeColor : .secondary)

            Text(authorName)
                .font(.roundedCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            ZStack {
                Color(.tertiarySystemBackground)
                if isMastodonAttribution {
                    themeColor.opacity(0.12)
                }
            }
        }
        .clipShape(Capsule())
        .overlay {
            if isMastodonAttribution {
                Capsule()
                    .stroke(themeColor.opacity(0.35), lineWidth: 1)
            }
        }
    }
}

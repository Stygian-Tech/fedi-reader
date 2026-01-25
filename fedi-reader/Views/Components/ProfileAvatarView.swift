//
//  ProfileAvatarView.swift
//  fedi-reader
//
//  Shared avatar component used across feeds, profiles, and messages.
//

import SwiftUI

/// Placeholder style for the avatar when loading or when URL is nil.
enum ProfileAvatarPlaceholderStyle {
    case standard
    case light
}

struct ProfileAvatarView: View {
    let url: URL?
    var size: CGFloat = Constants.UI.avatarSize
    var placeholderStyle: ProfileAvatarPlaceholderStyle = .standard
    var usePersonIconForFallback: Bool = false

    private var placeholderFill: AnyShapeStyle {
        switch placeholderStyle {
        case .standard: AnyShapeStyle(.tertiary)
        case .light: AnyShapeStyle(Color.white.opacity(0.5))
        }
    }

    var body: some View {
        Group {
            if usePersonIconForFallback {
                phaseBasedAvatar
            } else {
                simpleAvatar
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    @ViewBuilder
    private var phaseBasedAvatar: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Image(systemName: "person")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                @unknown default:
                    Image(systemName: "person")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        } else {
            Image(systemName: "person")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    @ViewBuilder
    private var simpleAvatar: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(placeholderFill)
        }
    }
}

import SwiftUI
import os

struct GroupAvatarView: View {
    let participants: [MastodonAccount]
    
    var body: some View {
        ZStack {
            // Show up to 4 avatars in a grid pattern
            let avatarsToShow = Array(participants.prefix(4))
            
            if avatarsToShow.count == 2 {
                // Two avatars: diagonal overlap
                HStack(spacing: -16) {
                    ProfileAvatarView(url: avatarsToShow[0].avatarURL, size: 40)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))

                    ProfileAvatarView(url: avatarsToShow[1].avatarURL, size: 40)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
                .frame(width: 56, height: 56)
            } else if avatarsToShow.count >= 3 {
                // 3-4 avatars: 2x2 grid
                let gridSize: CGFloat = 28
                VStack(spacing: -4) {
                    HStack(spacing: -4) {
                        ProfileAvatarView(url: avatarsToShow[0].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))

                        ProfileAvatarView(url: avatarsToShow[1].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                    }
                    HStack(spacing: -4) {
                        ProfileAvatarView(url: avatarsToShow[2].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))

                        if avatarsToShow.count > 3 {
                            ProfileAvatarView(url: avatarsToShow[3].avatarURL, size: gridSize)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                        } else if participants.count > 3 {
                            // Show +N indicator
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: gridSize, height: gridSize)
                                .overlay(
                                    Text("+\(participants.count - 3)")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                )
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: gridSize, height: gridSize)
                        }
                    }
                }
                .frame(width: 56, height: 56)
            } else {
                // Fallback: single avatar
                ProfileAvatarView(url: avatarsToShow.first?.avatarURL, size: 56)
            }
        }
    }
}

// MARK: - Grouped Conversation Detail View



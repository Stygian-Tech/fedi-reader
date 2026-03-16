import SwiftUI
import os

struct GroupAvatarView: View {
    let participants: [MastodonAccount]
    var size: CGFloat = 56

    private var twoAvatarSize: CGFloat {
        size * (40 / 56)
    }

    private var gridSize: CGFloat {
        size * 0.5
    }

    private var overlapSpacing: CGFloat {
        -(size * (16 / 56))
    }

    private var strokeWidth: CGFloat {
        max(1, size * (2 / 56))
    }
    
    var body: some View {
        ZStack {
            // Show up to 4 avatars in a grid pattern
            let avatarsToShow = Array(participants.prefix(4))
            
            if avatarsToShow.count == 2 {
                // Two avatars: diagonal overlap
                HStack(spacing: overlapSpacing) {
                    ProfileAvatarView(url: avatarsToShow[0].avatarURL, size: twoAvatarSize)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))

                    ProfileAvatarView(url: avatarsToShow[1].avatarURL, size: twoAvatarSize)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))
                }
                .frame(width: size, height: size)
            } else if avatarsToShow.count >= 3 {
                // 3-4 avatars: 2x2 grid
                let gridSpacing = -(size * (4 / 56))
                VStack(spacing: gridSpacing) {
                    HStack(spacing: gridSpacing) {
                        ProfileAvatarView(url: avatarsToShow[0].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))

                        ProfileAvatarView(url: avatarsToShow[1].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))
                    }
                    HStack(spacing: gridSpacing) {
                        ProfileAvatarView(url: avatarsToShow[2].avatarURL, size: gridSize)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))

                        if avatarsToShow.count > 3 {
                            ProfileAvatarView(url: avatarsToShow[3].avatarURL, size: gridSize)
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: strokeWidth))
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
                .frame(width: size, height: size)
            } else {
                // Fallback: single avatar
                ProfileAvatarView(url: avatarsToShow.first?.avatarURL, size: size)
            }
        }
    }
}

// MARK: - Grouped Conversation Detail View


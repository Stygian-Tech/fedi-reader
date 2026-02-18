import SwiftUI
import os

struct RecipientChip: View {
    let account: MastodonAccount
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            ProfileAvatarView(url: account.avatarURL, size: 20)

            HStack(spacing: 4) {
                EmojiText(text: account.displayName, emojis: account.emojis, font: .roundedSubheadline)
                    .lineLimit(1)
                
                AccountBadgesView(account: account, size: .small)
            }
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.15))
        )
    }
}

// MARK: - User Search Row



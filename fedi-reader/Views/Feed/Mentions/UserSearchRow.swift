import SwiftUI
import os

struct UserSearchRow: View {
    let account: MastodonAccount
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(url: account.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    EmojiText(text: account.displayName, emojis: account.emojis, font: .roundedBody)
                        .foregroundStyle(.primary)
                    
                    AccountBadgesView(account: account, size: .small)
                }
                
                Text("@\(account.acct)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Extension for Notification Hashable



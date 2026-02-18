import SwiftUI

struct UserFilterRow: View {
    let account: MastodonAccount
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ProfileAvatarView(url: account.avatarURL, size: Constants.UI.avatarSize)

                VStack(alignment: .leading, spacing: 2) {
                    EmojiText(text: account.displayName, emojis: account.emojis, font: .roundedSubheadline.bold())
                        .lineLimit(1)
                    
                    Text("@\(account.acct)")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    UserFilterPane(
        feedId: "home",
        accounts: [],
        onSelectAccount: { _ in }
    )
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}


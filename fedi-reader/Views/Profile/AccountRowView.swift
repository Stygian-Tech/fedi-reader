import SwiftUI

struct AccountRowView: View {
    let account: MastodonAccount
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatarView(url: account.avatarURL, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    EmojiText(text: account.displayName, emojis: account.emojis, font: .roundedHeadline)
                        .lineLimit(1)
                    
                    AccountBadgesView(account: account, size: .small)
                }
                
                Text("@\(account.acct)")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.roundedCaption)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 8)
        }
    }
}

#Preview {
    NavigationStack {
        FollowingListView(
            accountId: "123",
            account: MastodonAccount(
                id: "123",
                username: "test",
                acct: "test@example.com",
                displayName: "Test User",
                locked: false,
                bot: false,
                createdAt: Date(),
                note: "",
                url: "https://example.com/@test",
                avatar: "",
                avatarStatic: "",
                header: "",
                headerStatic: "",
                followersCount: 0,
                followingCount: 0,
                statusesCount: 0,
                lastStatusAt: nil,
                emojis: [],
                fields: [],
                source: nil
            )
        )
    }
    .environment(AppState())
}


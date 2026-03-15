import SwiftUI

struct AttributionChipContainer<Content: View>: View {
    var action: (() -> Void)? = nil
    private let content: Content

    @AppStorage("themeColor") private var themeColorName = "blue"

    init(
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.content = content()
    }

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
            } else {
                chipContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chipContent: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                ZStack {
                    Color(.secondarySystemBackground).opacity(0.65)
                    themeColor.opacity(0.10)
                }
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(themeColor.opacity(0.25), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

struct BoostAttributionChip: View {
    let account: MastodonAccount
    var action: (() -> Void)? = nil

    @AppStorage("themeColor") private var themeColorName = "blue"

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    var body: some View {
        AttributionChipContainer(action: action) {
            chipContent
        }
    }

    private var chipContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.2.squarepath")
                .font(.roundedCaption2)
                .foregroundStyle(themeColor)

            ProfileAvatarView(url: account.avatarURL, size: 20)

            Text("Boosted by")
                .font(.roundedCaption)
                .foregroundStyle(.secondary)

            EmojiText(text: account.preferredDisplayName, emojis: account.emojis, font: .roundedCaption.bold())
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            AccountBadgesView(account: account, size: .small)
        }
    }
}

struct FollowedHashtagAttributionChip: View {
    let hashtag: String
    var action: (() -> Void)? = nil

    @AppStorage("themeColor") private var themeColorName = "blue"

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }

    var body: some View {
        AttributionChipContainer(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .font(.roundedCaption2)
                    .foregroundStyle(themeColor)

                Text("Following")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)

                Text(hashtag)
                    .font(.roundedCaption.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
        }
    }
}

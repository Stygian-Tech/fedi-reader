//
//  AccountRow.swift
//  fedi-reader
//
//  Account row for account switcher list.
//

import SwiftUI
import SwiftData

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    @Environment(AppState.self) private var appState

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: account.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    EmojiText(text: account.displayName, emojis: appState.emojiService.getCustomEmojis(for: account.instance), font: .roundedHeadline)

                    Text(account.fullHandle)
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

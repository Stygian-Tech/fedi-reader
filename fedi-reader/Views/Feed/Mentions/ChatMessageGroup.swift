import SwiftUI
import os

struct ChatMessageGroup: View {
    let group: GroupedMessage
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if group.isSent {
            // Sent messages (right-aligned)
            HStack(alignment: .bottom, spacing: 8) {
                Spacer(minLength: 60)
                
                // Messages
                VStack(alignment: .trailing, spacing: 4) {
                    // Chat bubbles
                    ForEach(group.messages) { message in
                        ChatBubble(message: message, account: group.account, isSent: true)
                    }
                }
                
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        if let currentAccount = appState.currentAccount?.mastodonAccount {
                            appState.navigate(to: .profile(currentAccount))
                        }
                    } label: {
                        ProfileAvatarView(url: group.account.avatarURL, size: 32)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.vertical, 4)
        } else {
            // Received messages (left-aligned)
            HStack(alignment: .bottom, spacing: 8) {
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        appState.navigate(to: .profile(group.account))
                    } label: {
                        ProfileAvatarView(url: group.account.avatarURL, size: 32)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 32, height: 32)
                }
                
                // Messages
                VStack(alignment: .leading, spacing: 4) {
                    // Account name (only for first message)
                    if !group.messages.isEmpty {
                        HStack(spacing: 4) {
                            Button {
                                appState.navigate(to: .profile(group.account))
                            } label: {
                                HStack(spacing: 4) {
                                    EmojiText(text: group.account.displayName, emojis: group.account.emojis, font: .roundedCaption.bold())
                                        .foregroundStyle(.secondary)
                                    
                                    AccountBadgesView(account: group.account, size: .small)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Chat bubbles
                    ForEach(group.messages) { message in
                        ChatBubble(message: message, account: group.account, isSent: false)
                    }
                }
                
                Spacer(minLength: 60)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Chat Bubble



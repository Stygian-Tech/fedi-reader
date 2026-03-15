import SwiftUI
import os

struct ChatMessageGroup: View {
    let group: GroupedMessage
    let hiddenMentionHandles: Set<String>
    @Environment(AppState.self) private var appState
    
    private let opposingSideMinimumSpace: CGFloat = 16
    
    var body: some View {
        if group.isSent {
            // Sent messages (right-aligned)
            HStack(alignment: .bottom, spacing: 6) {
                Spacer(minLength: opposingSideMinimumSpace)
                
                // Messages
                VStack(alignment: .trailing, spacing: 4) {
                    // Chat bubbles
                    ForEach(group.messages) { message in
                        ChatBubble(
                            message: message,
                            account: group.account,
                            isSent: true,
                            hiddenMentionHandles: hiddenMentionHandles
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        if let currentAccount = appState.currentAccount?.mastodonAccount {
                            appState.navigate(to: .profile(currentAccount))
                        }
                    } label: {
                        ProfileAvatarView(url: group.account.avatarURL, size: 28)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.vertical, 4)
        } else {
            // Received messages (left-aligned)
            HStack(alignment: .bottom, spacing: 6) {
                // Avatar (only shown for first message in group)
                if group.messages.first != nil {
                    Button {
                        appState.navigate(to: .profile(group.account))
                    } label: {
                        ProfileAvatarView(url: group.account.avatarURL, size: 28)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer to align messages
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 28, height: 28)
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
                        ChatBubble(
                            message: message,
                            account: group.account,
                            isSent: false,
                            hiddenMentionHandles: hiddenMentionHandles
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: opposingSideMinimumSpace)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Chat Bubble

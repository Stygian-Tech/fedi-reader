import SwiftUI
import os

struct ChatMessageGroup: View {
    let group: GroupedMessage
    let hiddenMentionHandles: Set<String>
    let maxContentWidth: CGFloat
    @Environment(AppState.self) private var appState
    
    private let opposingSideMinimumSpace: CGFloat = 20
    private let avatarSize: CGFloat = 28
    private let messageTextInset: CGFloat = 14
    private let metadataBottomOffset: CGFloat = 18
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var showsIncomingAvatar: Bool {
        !group.isSent && group.isGroupChat
    }
    
    var body: some View {
        if group.isSent {
            HStack(alignment: .bottom, spacing: 6) {
                Spacer(minLength: opposingSideMinimumSpace)
                
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                        ChatBubble(
                            message: message,
                            account: group.account,
                            isSent: true,
                            hiddenMentionHandles: hiddenMentionHandles,
                            showsMetadata: shouldShowMetadata(for: index)
                        )
                    }
                }
                .frame(maxWidth: maxContentWidth, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 4)
        } else {
            HStack(alignment: .bottom, spacing: 6) {
                if showsIncomingAvatar {
                    Button {
                        appState.navigate(to: .profile(group.account))
                    } label: {
                        ProfileAvatarView(url: group.account.avatarURL, size: avatarSize)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, metadataBottomOffset)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if group.isGroupChat && !group.messages.isEmpty {
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
                        .padding(.leading, messageTextInset)
                    }
                    
                    // Chat bubbles
                    ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                        ChatBubble(
                            message: message,
                            account: group.account,
                            isSent: false,
                            hiddenMentionHandles: hiddenMentionHandles,
                            showsMetadata: shouldShowMetadata(for: index)
                        )
                    }
                }
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: opposingSideMinimumSpace)
            }
            .padding(.vertical, 4)
        }
    }

    private func shouldShowMetadata(for index: Int) -> Bool {
        guard group.messages.indices.contains(index) else { return true }
        guard index < group.messages.index(before: group.messages.endIndex) else { return true }
        return timestampKey(for: group.messages[index]) != timestampKey(for: group.messages[index + 1])
    }

    private func timestampKey(for message: ChatMessage) -> String {
        Self.timestampFormatter.string(from: message.createdAt)
    }
}

// MARK: - Chat Bubble

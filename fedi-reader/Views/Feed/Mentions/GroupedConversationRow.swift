import SwiftUI
import os

struct GroupedConversationRow: View {
    let groupedConversation: GroupedConversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar(s)
            if groupedConversation.isGroupChat {
                // Group chat: show stacked avatars
                GroupAvatarView(participants: groupedConversation.participants)
                    .overlay(alignment: .bottomTrailing) {
                        unreadIndicator
                    }
            } else {
                // 1:1: single avatar
                ProfileAvatarView(url: groupedConversation.primaryAccount?.avatarURL, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        unreadIndicator
                    }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if groupedConversation.isGroupChat {
                        Image(systemName: "person.2.fill")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(groupedConversation.displayName)
                        .font(.roundedHeadline)
                        .fontWeight(groupedConversation.unread ? .bold : .semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(TimeFormatter.relativeTimeString(from: groupedConversation.lastUpdated))
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                }
                
                Text(groupedConversation.lastStatus?.content.htmlToPlainText ?? "")
                    .font(.roundedSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var unreadIndicator: some View {
        if groupedConversation.unread {
            Circle()
                .fill(.blue)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(.systemBackground), lineWidth: 2)
                )
        }
    }
}

// MARK: - Group Avatar View



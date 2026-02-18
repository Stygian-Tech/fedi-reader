import SwiftUI

struct CompactStatusRowView: View {
    let status: Status
    let depth: Int
    @Environment(AppState.self) private var appState
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false
    
    var displayStatus: Status {
        status.displayStatus
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Author header
            HStack(spacing: 5) {
                Button {
                    appState.navigate(to: .profile(displayStatus.account))
                } label: {
                    ProfileAvatarView(url: displayStatus.account.avatarURL, size: 32)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        EmojiText(text: displayStatus.account.displayName, emojis: displayStatus.account.emojis, font: .roundedSubheadline.bold())
                            .lineLimit(1)
                        
                        AccountBadgesView(account: displayStatus.account, size: .small)
                    }
                    
                    if showHandleInFeed {
                        Text("@\(displayStatus.account.acct)")
                            .font(.roundedCaption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                        .font(.roundedCaption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
            }
            
            // Content
            if !displayStatus.spoilerText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    EmojiText(text: displayStatus.spoilerText, emojis: displayStatus.emojis, font: .roundedCaption.bold())
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            } else {
                if #available(iOS 15.0, macOS 12.0, *) {
                    HashtagLinkText(
                        content: displayStatus.content,
                        onHashtagTap: { appState.navigate(to: .hashtag($0)) },
                        emojiLookup: Dictionary(uniqueKeysWithValues: displayStatus.emojis.map { ($0.shortcode, $0) })
                    )
                    .font(.roundedBody)
                } else {
                    Text(displayStatus.content.htmlToPlainText)
                        .font(.roundedBody)
                }
            }
            
            // Media attachments (compact)
            if !displayStatus.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(displayStatus.mediaAttachments.prefix(3)) { attachment in
                            AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            
            // Actions bar (compact)
            StatusActionsBar(status: displayStatus, size: .standard)
        }
        .padding(.horizontal, depth > 0 ? 5 : 11)
        .padding(.vertical, depth > 0 ? 4 : 8)
        .background(
            depth > 0
                ? Color(.secondarySystemBackground).opacity(0.5)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if depth > 0 {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 1)
                    .padding(.leading, 0)
            }
        }
    }
}

// MARK: - Reply Indicator



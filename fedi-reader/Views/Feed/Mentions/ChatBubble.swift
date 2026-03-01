import AVKit
import SwiftUI
import os

struct ChatBubble: View {
    let message: ChatMessage
    let account: MastodonAccount
    let isSent: Bool
    @Environment(AppState.self) private var appState
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("autoPlayGifs") private var autoPlayGifs = false
    
    var status: Status? {
        message.status
    }
    
    private var mediaAttachments: [MediaAttachment] {
        status?.mediaAttachments.filter { attachment in
            attachment.type == .image || attachment.type == .video || attachment.type == .gifv
        } ?? []
    }
    
    private var hasFavorites: Bool {
        (status?.favouritesCount ?? 0) > 0
    }
    
    private var isFavoritedByMe: Bool {
        status?.favourited == true
    }
    
    var body: some View {
        if let status = status {
            Button {
                appState.navigate(to: .status(status))
            } label: {
                VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
                    // Message content
                    if #available(iOS 15.0, macOS 12.0, *) {
                        HashtagLinkText(
                            content: status.content,
                            onHashtagTap: { appState.navigate(to: .hashtag($0)) },
                            emojiLookup: Dictionary(uniqueKeysWithValues: status.emojis.map { ($0.shortcode, $0) })
                        )
                        .font(.roundedBody)
                        .multilineTextAlignment(.leading)
                    } else {
                        Text(status.content.htmlToPlainText)
                            .font(.roundedBody)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if !mediaAttachments.isEmpty {
                        chatMediaAttachments
                    }
                    
                    // Timestamp
                    Text(message.createdAt, style: .time)
                        .font(.roundedCaption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isSent ? ThemeColor.resolved(from: themeColorName).color.opacity(0.2) : Color(.secondarySystemBackground))
                )
                .overlay(alignment: isSent ? .bottomLeading : .bottomTrailing) {
                    // Tapback-style favorite indicator
                    if hasFavorites {
                        TapbackView(count: status.favouritesCount, isMine: isFavoritedByMe)
                            .offset(x: isSent ? -8 : 8, y: 8)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, hasFavorites ? 8 : 0) // Extra space for tapback
            .contextMenu {
                if !isSent {
                    Button {
                        appState.present(sheet: .compose(replyTo: status))
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                    }
                    
                    Button {
                        appState.navigate(to: .thread(statusId: status.id))
                    } label: {
                        Label("View Thread", systemImage: "bubble.left.and.bubble.right")
                    }
                    
                    Divider()
                }
                
                Button {
                    appState.navigate(to: .profile(account))
                } label: {
                    Label("View Profile", systemImage: "person")
                }
            }
        }
    }
    
    private var chatMediaAttachments: some View {
        VStack(alignment: isSent ? .trailing : .leading, spacing: 6) {
            ForEach(mediaAttachments) { attachment in
                ChatMediaAttachmentView(
                    attachment: attachment,
                    isSent: isSent,
                    autoPlayGifs: autoPlayGifs
                )
            }
        }
    }
}

// MARK: - Chat Media Attachment View

private struct ChatMediaAttachmentView: View {
    let attachment: MediaAttachment
    let isSent: Bool
    let autoPlayGifs: Bool

    var body: some View {
        Group {
            if (attachment.type == .gifv || attachment.type == .video), autoPlayGifs, let url = URL(string: attachment.url) {
                ChatGifvPlayerView(url: url)
                    .frame(maxWidth: 220, maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: attachment.type == .gifv ? "play.circle" : "video")
                            .font(.roundedCaption)
                            .padding(4)
                            .glassEffect(.clear, in: Circle())
                            .padding(6)
                    }
            } else {
                AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.tertiary)
                }
                .frame(maxWidth: 220, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    if attachment.type == .video || attachment.type == .gifv {
                        Image(systemName: attachment.type == .gifv ? "play.circle" : "video")
                            .font(.roundedCaption)
                            .padding(4)
                            .glassEffect(.clear, in: Circle())
                            .padding(6)
                    }
                }
            }
        }
    }
}

// MARK: - Chat GIFV Player View

private struct ChatGifvPlayerView: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.isMuted = true
                        player.play()
                    }
            } else {
                Rectangle()
                    .fill(.tertiary)
            }
        }
        .onAppear {
            guard player == nil else { return }
            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(playerItem: item)
            let loop = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            looper = loop
        }
    }
}

// MARK: - Tapback View (iMessage-style reaction indicator)



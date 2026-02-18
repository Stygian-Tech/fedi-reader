//
//  ThreadView.swift
//  fedi-reader
//
//  Thread visualization components for displaying reply hierarchies
//

import SwiftUI

// MARK: - Thread Node View

struct ThreadNodeView: View {
    let node: ThreadNode
    let depth: Int
    let isLastSibling: Bool
    @Environment(AppState.self) private var appState
    @State private var isExpanded = true
    @State private var showAllReplies = false
    
    private let indentPerLevel: CGFloat = 4
    private let connectorWidth: CGFloat = 1
    private let maxVisibleReplies = 4
    
    private var visibleChildren: [ThreadNode] {
        if node.children.count <= maxVisibleReplies || showAllReplies {
            return node.children
        } else {
            return Array(node.children.prefix(maxVisibleReplies))
        }
    }
    
    private var hasMoreReplies: Bool {
        node.children.count > maxVisibleReplies && !showAllReplies
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // Thread connectors
                if depth > 0 {
                    threadConnectors
                }
                
                // Status content
                VStack(alignment: .leading, spacing: 0) {
                    CompactStatusRowView(status: node.status, depth: depth)
                    
                    // Children
                    if !node.children.isEmpty && isExpanded {
                        ForEach(Array(visibleChildren.enumerated()), id: \.element.id) { index, child in
                            ThreadNodeView(
                                node: child,
                                depth: depth + 1,
                                isLastSibling: index == visibleChildren.count - 1 && !hasMoreReplies
                            )
                        }
                        
                        // "See more" button
                        if hasMoreReplies {
                            Button {
                                withAnimation {
                                    showAllReplies = true
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("See \(node.children.count - maxVisibleReplies) more replies")
                                        .font(.roundedSubheadline)
                                        .foregroundStyle(.blue)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                }
                                .padding(.horizontal, depth > 0 ? 5 : 11)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, CGFloat(depth) * indentPerLevel)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var threadConnectors: some View {
        HStack(spacing: 0) {
            // Vertical line for depth levels
            ForEach(0..<depth, id: \.self) { level in
                if level == depth - 1 {
                    // Current level: show connector based on sibling position
                    VStack(spacing: 0) {
                        // Horizontal line to status
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 3, height: connectorWidth)
                        
                        // Vertical line if not last sibling
                        if !isLastSibling {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: connectorWidth)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: indentPerLevel)
                } else {
                    // Previous levels: show vertical line if not last sibling
                    VStack(spacing: 0) {
                        if !isLastSibling {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: connectorWidth)
                                .frame(maxHeight: .infinity)
                        } else {
                            Spacer()
                                .frame(width: connectorWidth)
                        }
                    }
                    .frame(width: indentPerLevel)
                }
            }
        }
        .frame(width: CGFloat(depth) * indentPerLevel)
    }
}

// MARK: - Thread View

struct ThreadView: View {
    let threads: [ThreadNode]
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(threads) { thread in
                ThreadNodeView(
                    node: thread,
                    depth: 0,
                    isLastSibling: thread.id == threads.last?.id
                )
            }
        }
    }
}

// MARK: - Compact Thread View (for single card display)

struct CompactThreadView: View {
    let threads: [ThreadNode]
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(threads) { thread in
                ThreadNodeView(
                    node: thread,
                    depth: 0,
                    isLastSibling: thread.id == threads.last?.id
                )
            }
        }
    }
}

// MARK: - Compact Status Row View (for thread display)

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

struct ReplyIndicator: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let replyToId = status.inReplyToId {
            Button {
                appState.navigate(to: .thread(statusId: replyToId))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    if status.inReplyToAccountId != nil {
                        Text("Replying")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Thread Status Row View (for timeline displays)

struct ThreadStatusRowView: View {
    let status: Status
    let showReplyIndicator: Bool
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showReplyIndicator, status.inReplyToId != nil {
                ReplyIndicator(status: status)
            }
            
            StatusRowView(status: status)
        }
    }
}

// MARK: - Thread Connector (standalone component)

struct ThreadConnector: View {
    let hasSiblingBelow: Bool
    let depth: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // Vertical line
            if hasSiblingBelow {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 2)
            } else {
                Spacer()
                    .frame(width: 2)
            }
        }
        .frame(width: 20)
    }
}

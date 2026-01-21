//
//  StatusRowView.swift
//  fedi-reader
//
//  Reusable status/post row component
//

import SwiftUI

struct StatusRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var displayStatus: Status {
        status.displayStatus
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Reblog indicator
            if status.isReblog {
                reblogHeader
            }
            
            // Author info
            authorHeader
            
            // Content warning
            if !displayStatus.spoilerText.isEmpty {
                contentWarning
            } else {
                contentView
            }
            
            // Media attachments
            if !displayStatus.mediaAttachments.isEmpty {
                mediaAttachments
            }
            
            // Link card
            if let card = displayStatus.card, card.type == .link {
                linkCard(card)
            }
            
            // Poll
            if let poll = displayStatus.poll {
                pollView(poll)
            }
            
            // Actions bar
            StatusActionsBar(status: status, compact: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
    
    // MARK: - Reblog Header
    
    private var reblogHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)
            
            Text("\(status.account.displayName) boosted")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.leading, Constants.UI.avatarSize + 10)
    }
    
    // MARK: - Author Header
    
    private var authorHeader: some View {
        HStack(spacing: 10) {
            Button {
                appState.navigate(to: .profile(displayStatus.account))
            } label: {
                AsyncImage(url: displayStatus.account.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: Constants.UI.avatarSize, height: Constants.UI.avatarSize)
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.avatarCornerRadius))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayStatus.account.displayName)
                    .font(.roundedSubheadline.bold())
                    .lineLimit(1)
                
                Text("@\(displayStatus.account.acct)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
                
                if displayStatus.visibility != .public {
                    Image(systemName: visibilityIcon)
                        .font(.roundedCaption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
    
    private var visibilityIcon: String {
        switch displayStatus.visibility {
        case .public: return "globe"
        case .unlisted: return "lock.open"
        case .private: return "lock"
        case .direct: return "envelope"
        }
    }
    
    // MARK: - Content Warning
    
    @State private var isContentRevealed = false
    
    private var contentWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                
                Text(displayStatus.spoilerText)
                    .font(.roundedSubheadline.bold())
                
                Spacer()
                
                Button(isContentRevealed ? "Hide" : "Show") {
                    withAnimation {
                        isContentRevealed.toggle()
                    }
                }
                .font(.roundedCaption.bold())
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if isContentRevealed {
                contentView
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Content
    
    private var contentView: some View {
        Group {
            if #available(iOS 15.0, macOS 12.0, *) {
                HashtagLinkText(
                    content: displayStatus.content,
                    onHashtagTap: { tag in
                        appState.navigate(to: .hashtag(tag))
                    }
                )
                .font(.roundedBody)
                .lineLimit(Constants.UI.maxContentPreviewLines)
            } else {
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedBody)
                    .lineLimit(Constants.UI.maxContentPreviewLines)
            }
        }
    }
    
    // MARK: - Media Attachments
    
    private var mediaAttachments: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(displayStatus.mediaAttachments) { attachment in
                    mediaAttachmentView(attachment)
                }
            }
            .padding(.horizontal, 1) // Prevent edge clipping
        }
    }
    
    private func mediaAttachmentView(_ attachment: MediaAttachment) -> some View {
        AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(.tertiary)
        }
        .frame(width: 150, height: 150)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
    
    // MARK: - Link Card
    
    private func linkCard(_ card: PreviewCard) -> some View {
        Button {
            if let url = card.linkURL {
                appState.navigate(to: .article(url: url, status: status))
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Large image
                if let imageURL = card.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.title)
                        .font(.roundedTitle3.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    if !card.description.isEmpty {
                        Text(card.description)
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.roundedCaption)
                        
                        Text(card.providerName ?? HTMLParser.extractDomain(from: URL(string: card.url)!) ?? card.url)
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    // MARK: - Poll
    
    private func pollView(_ poll: Poll) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                pollOptionView(option, index: index, poll: poll)
            }
            
            HStack {
                Text("\(poll.votesCount) votes")
                
                if let votersCount = poll.votersCount {
                    Text("•")
                    Text("\(votersCount) people")
                }
                
                if poll.expired {
                    Text("•")
                    Text("Closed")
                } else if let expiresAt = poll.expiresAt {
                    Text("•")
                    Text("Ends \(expiresAt, style: .relative)")
                }
            }
            .font(.roundedCaption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
    }
    
    private func pollOptionView(_ option: PollOption, index: Int, poll: Poll) -> some View {
        let percentage: Double = {
            guard let votes = option.votesCount, poll.votesCount > 0 else { return 0 }
            return Double(votes) / Double(poll.votesCount)
        }()
        
        let isVoted = poll.ownVotes?.contains(index) ?? false
        
        return HStack {
            Text(option.title)
                .font(.roundedSubheadline)
            
            Spacer()
            
            Text("\(Int(percentage * 100))%")
                .font(.roundedCaption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            GeometryReader { geo in
                Rectangle()
                    .fill(isVoted ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.2))
                    .frame(width: geo.size.width * percentage)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isVoted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Compact Status Row

struct CompactStatusRow: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var displayStatus: Status {
        status.displayStatus
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AsyncImage(url: displayStatus.account.avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayStatus.account.displayName)
                        .font(.roundedSubheadline.bold())
                        .lineLimit(1)
                    
                    Text("@\(displayStatus.account.acct)")
                        .font(.roundedCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(displayStatus.createdAt, style: .relative)
                        .font(.roundedCaption)
                        .foregroundStyle(.tertiary)
                }
                
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedSubheadline)
                    .lineLimit(3)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Preview would need mock data
            Text("Status Row Preview")
        }
        .padding()
    }
}

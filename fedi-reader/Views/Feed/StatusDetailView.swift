//
//  StatusDetailView.swift
//  fedi-reader
//
//  Full status detail with thread context (ancestors, replies).
//

import SwiftUI

struct StatusDetailRowView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @AppStorage("showHandleInFeed") private var showHandleInFeed = false

    @State private var fediverseCreatorName: String?
    @State private var fediverseCreatorURL: URL?

    var displayStatus: Status {
        status.displayStatus
    }

    private var cardURL: URL? {
        guard let card = displayStatus.card, (card.type == .link || card.type == .rich) else { return nil }
        return card.linkURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if status.isReblog {
                reblogIndicator
            }

            HStack(spacing: 10) {
                Button {
                    appState.navigate(to: .profile(displayStatus.account))
                } label: {
                    ProfileAvatarView(url: displayStatus.account.avatarURL, size: Constants.UI.avatarSize)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayStatus.account.displayName)
                            .font(.roundedSubheadline.bold())
                            .lineLimit(1)

                        AccountBadgesView(account: displayStatus.account, size: .small)
                    }
                    if showHandleInFeed {
                        Text("@\(displayStatus.account.acct)")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(TimeFormatter.relativeTimeString(from: displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
            }

            if !displayStatus.spoilerText.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text(displayStatus.spoilerText)
                        .font(.roundedSubheadline.bold())
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if #available(iOS 15.0, macOS 12.0, *) {
                Text(displayStatus.content.htmlToAttributedString)
                    .font(.roundedBody)
            } else {
                Text(displayStatus.content.htmlToPlainText)
                    .font(.roundedBody)
            }

            if !displayStatus.mediaAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(displayStatus.mediaAttachments) { attachment in
                            AsyncImage(url: URL(string: attachment.previewUrl ?? attachment.url)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            if let card = displayStatus.card, card.type == .link {
                Button {
                    if let url = card.linkURL {
                        appState.navigate(to: .article(url: url, status: status))
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let imageURL = card.imageURL {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(.tertiary)
                            }
                            .frame(width: 80, height: 80)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.roundedSubheadline.bold())
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if !card.description.isEmpty {
                                Text(card.description)
                                    .font(.roundedCaption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.roundedCaption2)

                                Text(card.providerName ?? HTMLParser.extractDomain(from: URL(string: card.url)!) ?? card.url)
                                    .font(.roundedCaption)
                                    .lineLimit(1)

                                if let authorName = fediverseCreatorName,
                                   let authorURL = fediverseCreatorURL {
                                    Link(destination: authorURL) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                                .font(.roundedCaption2)

                                            Text(authorName)
                                                .font(.roundedCaption)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.tertiarySystemBackground), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else if let authorName = fediverseCreatorName {
                                    Text(authorName)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                } else if let authorName = card.authorName,
                                          let authorUrlString = card.authorUrl,
                                          let authorURL = URL(string: authorUrlString) {
                                    Link(destination: authorURL) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.crop.circle")
                                                .font(.roundedCaption2)

                                            Text(authorName)
                                                .font(.roundedCaption)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.tertiarySystemBackground), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else if let author = card.authorName {
                                    Text(author)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                }
                            }
                            .foregroundStyle(.tertiary)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .task(id: cardURL?.absoluteString) {
                    guard let url = cardURL else { return }
                    let creator = await LinkPreviewService.shared.fetchFediverseCreator(for: url)
                    fediverseCreatorName = creator?.name
                    fediverseCreatorURL = creator?.url
                }
            }

            StatusActionsBar(status: displayStatus, size: .detail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
    }
    
    // MARK: - Reblog Indicator
    
    private var reblogIndicator: some View {
        Button {
            appState.navigate(to: .profile(status.account))
        } label: {
            HStack(spacing: 8) {
                ProfileAvatarView(url: status.account.avatarURL, size: 24)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedCaption2)
                    
                    Text("Boosted by")
                        .font(.roundedCaption)
                    
                    Text(status.account.displayName)
                        .font(.roundedCaption.bold())
                        .lineLimit(1)
                    
                    AccountBadgesView(account: status.account, size: .small)
                }
                .foregroundStyle(.secondary)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

struct StatusDetailView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var context: StatusContext?
    @State private var isLoading = true
    @State private var isLoadingRemoteReplies = false
    
    private let threadingService = ThreadingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Parent post as its own card at the top
                StatusDetailRowView(status: status)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let context = context {
                    // Build thread tree from descendants only (exclude parent/current post)
                    let replyTrees = threadingService.buildThreadTree(from: context.descendants)
                    
                    if !context.descendants.isEmpty {
                        // Single card containing reply thread (without parent)
                        VStack(alignment: .leading, spacing: 0) {
                            // Header with controls
                            HStack {
                                Text("Replies")
                                    .font(.roundedHeadline)
                                
                                if isLoadingRemoteReplies {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.leading, 4)
                                }
                                
                                Spacer()
                                
                                // Show expected count if we have more replies
                                if status.repliesCount > context.descendants.count {
                                    Text("\(context.descendants.count) of \(status.repliesCount)")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Button to fetch remote replies
                                if status.repliesCount > context.descendants.count && !isLoadingRemoteReplies {
                                    Button {
                                        Task {
                                            await refreshReplies()
                                        }
                                    } label: {
                                        Label("Fetch Remote", systemImage: "arrow.down.circle")
                                            .font(.roundedCaption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            
                            Divider()
                            
                            // Display reply thread tree (only descendants, no parent)
                            CompactThreadView(threads: replyTrees)
                                .padding(.vertical, 5)
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    } else if status.repliesCount > 0 {
                        // Show message if we expect replies but don't have any yet
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Replies")
                                    .font(.roundedHeadline)
                                
                                if isLoadingRemoteReplies {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.leading, 4)
                                }
                                
                                Spacer()
                                
                                // Button to fetch remote replies
                                if !isLoadingRemoteReplies {
                                    Button {
                                        Task {
                                            await refreshReplies()
                                        }
                                    } label: {
                                        Label("Fetch Remote", systemImage: "arrow.down.circle")
                                            .font(.roundedCaption)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
                            if isLoadingRemoteReplies {
                                HStack {
                                    Text("Loading remote replies...")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadContext()
        }
        .refreshable {
            await refreshReplies()
        }
        .onDisappear {
            timelineWrapper.service?.cancelAsyncRefreshPolling(forStatusId: status.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .statusContextDidUpdate)) { notification in
            // Update context when remote replies are fetched
            if let payload = notification.object as? StatusContextUpdatePayload,
               payload.statusId == status.id {
                // Replace context with updated one (it already contains all replies)
                context = payload.context
                isLoadingRemoteReplies = false
            }
        }
    }

    private func loadContext() async {
        guard let service = timelineWrapper.service else {
            isLoading = false
            return
        }

        do {
            let loadedContext = try await service.getStatusContext(for: status)
            context = loadedContext
            isLoading = false
            
            // Check if we need to fetch remote replies
            // Note: getStatusContext already triggers remote reply fetching in background
            // We just need to show loading state
            if shouldFetchRemoteReplies(context: loadedContext) {
                isLoadingRemoteReplies = true
            }
        } catch {
            isLoading = false
            isLoadingRemoteReplies = false
        }
    }
    
    private func shouldFetchRemoteReplies(context: StatusContext) -> Bool {
        // Fetch if we have fewer descendants than expected
        if status.repliesCount > context.descendants.count {
            return true
        }
        
        // Fetch if async refresh is indicated
        if context.asyncRefreshId != nil {
            return true
        }
        
        return false
    }
    
    private func refreshReplies() async {
        guard let service = timelineWrapper.service else { return }
        
        isLoadingRemoteReplies = true
        
        do {
            try await service.refreshContextForStatus(status)
            // Context updated via notification (immediate if no async refresh, else when polling finishes)
        } catch {
            isLoadingRemoteReplies = false
        }
    }
}

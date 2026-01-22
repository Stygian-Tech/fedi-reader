//
//  LinkFeedView.swift
//  fedi-reader
//
//  Main filtered link feed showing posts with links
//

import SwiftUI

struct LinkFeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(LinkFilterService.self) private var linkFilterService
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var isRefreshing = false
    @State private var selectedDomain: String?
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    var body: some View {
        Group {
            if linkFilterService.linkStatuses.isEmpty && !linkFilterService.isLoading {
                emptyStateView
            } else {
                linkList
            }
        }
        .navigationTitle("Links")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !linkFilterService.uniqueDomains().isEmpty {
                        Section("Filter by Domain") {
                            Button("All Domains") {
                                selectedDomain = nil
                            }
                            
                            ForEach(linkFilterService.uniqueDomains(), id: \.self) { domain in
                                Button(domain) {
                                    selectedDomain = domain
                                }
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            Task {
                                await linkFilterService.enrichWithAttributions()
                            }
                        } label: {
                            Label("Load Author Info", systemImage: "person.text.rectangle")
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable {
            await refreshFeed()
        }
        .task {
            await loadInitialContent()
            // Start background fetching of older posts
            if let service = timelineService {
                Task(priority: .background) {
                    await service.backgroundFetchOlderPosts()
                }
            }
        }
    }
    
    private var linkList: some View {
        GlassEffectContainer {
            List {
                ForEach(filteredStatuses) { linkStatus in
                    LinkStatusRow(linkStatus: linkStatus)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .onAppear {
                            checkLoadMore(linkStatus)
                        }
                }
                
                if linkFilterService.isLoading {
                    loadingRow
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(8)
            .padding(.horizontal, 12)
        }
    }
    
    private var filteredStatuses: [LinkStatus] {
        if let domain = selectedDomain {
            return linkFilterService.filterByDomain(domain)
        }
        return linkFilterService.linkStatuses
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Links Yet", systemImage: "link.badge.plus")
        } description: {
            Text("Posts with links from your home timeline will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await refreshFeed()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
    
    private func loadInitialContent() async {
        guard let service = timelineService else { return }
        
        if service.homeTimeline.isEmpty {
            await service.refreshHomeTimeline()
        }
        
        _ = await linkFilterService.processStatuses(service.homeTimeline)
    }
    
    private func refreshFeed() async {
        guard let service = timelineService else { return }
        
        isRefreshing = true
        await service.refreshHomeTimeline()
        _ = await linkFilterService.processStatuses(service.homeTimeline)
        isRefreshing = false
    }
    
    private func checkLoadMore(_ linkStatus: LinkStatus) {
        guard let service = timelineService else { return }
        
        let statuses = linkFilterService.linkStatuses
        guard let index = statuses.firstIndex(of: linkStatus) else { return }
        
        // Load more when approaching the end - trigger earlier for smoother scrolling
        if index >= statuses.count - (Constants.Pagination.prefetchThreshold * 2) {
            Task {
                await service.loadMoreHomeTimeline()
                _ = await linkFilterService.processStatuses(service.homeTimeline)
            }
        }
    }
}

// MARK: - Link Status Row

struct LinkStatusRow: View {
    let linkStatus: LinkStatus
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    
    @State private var isShowingActions = false
    @State private var blueskyDescription: String?
    @State private var hasLoadedBlueskyDescription = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if linkStatus.status.isReblog {
                reblogHeader
            }
            
            // Author info
            authorHeader
            
            // Link card
            linkCard
            
            // Post content preview
            if let description = linkStatus.displayDescription, !description.isEmpty {
                Button {
                    appState.navigate(to: .status(linkStatus.status))
                } label: {
                    Text(description)
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            // Tags
            let tags = TagExtractor.extractTags(from: linkStatus.status)
            if !tags.isEmpty {
                TagView(tags: tags) { tag in
                    appState.navigate(to: .hashtag(tag))
                }
            }
            
            // Actions bar
            StatusActionsBar(status: linkStatus.status, compact: true)

            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            contextMenuContent
        }
    }

    private var reblogHeader: some View {
        let reblogger = linkStatus.status.account
        return Button {
            appState.navigate(to: .profile(reblogger))
        } label: {
            HStack(spacing: 8) {
                AsyncImage(url: reblogger.avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.tertiary)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.roundedCaption2)
                            .foregroundStyle(.secondary)
                        
                        Text("Boosted by")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Text(reblogger.displayName)
                            .font(.roundedCaption.bold())
                            .lineLimit(1)
                        
                        Text("@\(reblogger.acct)")
                            .font(.roundedCaption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: blueskyCardURL?.absoluteString) {
            guard let url = blueskyCardURL, !hasLoadedBlueskyDescription else { return }
            hasLoadedBlueskyDescription = true
            blueskyDescription = await LinkPreviewService.shared.fetchDescription(for: url)
        }
    }
    
    private var authorHeader: some View {
        HStack(spacing: 10) {
            AsyncImage(url: URL(string: linkStatus.status.displayStatus.account.avatar)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(.tertiary)
            }
            .frame(width: Constants.UI.avatarSize, height: Constants.UI.avatarSize)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.avatarCornerRadius))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(linkStatus.status.displayStatus.account.displayName)
                    .font(.roundedSubheadline.bold())
                    .lineLimit(1)
                
                Text("@\(linkStatus.status.displayStatus.account.acct)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(TimeFormatter.relativeTimeString(from: linkStatus.status.displayStatus.createdAt))
                    .font(.roundedCaption)
                    .foregroundStyle(.tertiary)
        }
    }

    private var blueskyCardURL: URL? {
        let url = linkStatus.primaryURL
        return isBlueskyURL(url) ? url : nil
    }

    private func isBlueskyURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("bsky.app") || host.contains("bsky.social")
    }

    private var linkCard: some View {
        Button {
            appState.navigate(to: .article(url: linkStatus.primaryURL, status: linkStatus.status))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Large image
                if let imageURL = linkStatus.imageURL {
                    GeometryReader { geo in
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: 220)
                                    .clipped()
                            case .failure:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            case .empty:
                                ProgressView()
                                    .frame(width: geo.size.width, height: 220)
                            @unknown default:
                                placeholderImage
                                    .frame(width: geo.size.width, height: 220)
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Title and domain
                VStack(alignment: .leading, spacing: 8) {
                    Text(linkStatus.displayTitle)
                        .font(.roundedTitle3.bold())
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    let descriptionText = blueskyDescription ?? linkStatus.displayDescription
                    if let descriptionText, !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(blueskyDescription == nil ? 2 : 8)
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.roundedCaption)
                        
                        Text(linkStatus.domain)
                            .font(.roundedCaption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if let authorName = linkStatus.authorAttribution,
                           let authorUrlString = linkStatus.authorURL,
                           let authorURL = URL(string: authorUrlString) {
                            Link(destination: authorURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.roundedCaption)
                                    
                                    Text(authorName)
                                        .font(.roundedCaption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.tertiarySystemBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        } else if let author = linkStatus.displayAuthor {
                            Text(author)
                                .font(.roundedCaption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay {
                Image(systemName: "link")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        // Open in browser
        Link(destination: linkStatus.primaryURL) {
            Label("Open in Browser", systemImage: "safari")
        }
        
        // Share
        ShareLink(item: linkStatus.primaryURL) {
            Label("Share Link", systemImage: "square.and.arrow.up")
        }
        
        // Copy link
        Button {
            #if os(iOS)
            UIPasteboard.general.url = linkStatus.primaryURL
            #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(linkStatus.primaryURL.absoluteString, forType: .URL)
            #endif
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        // Read Later options
        if readLaterManager.hasConfiguredServices {
            if let primary = readLaterManager.primaryService, let serviceType = primary.service {
                Button {
                    Task {
                        try? await readLaterManager.save(
                            url: linkStatus.primaryURL,
                            title: linkStatus.title,
                            to: serviceType
                        )
                    }
                } label: {
                    Label("Save to \(serviceType.displayName)", systemImage: "bookmark")
                }
            }
            
            Menu {
                ForEach(readLaterManager.configuredServices) { config in
                    Button {
                        Task {
                            try? await readLaterManager.save(
                                url: linkStatus.primaryURL,
                                title: linkStatus.title,
                                to: config.service!
                            )
                        }
                    } label: {
                        Label(config.service!.displayName, systemImage: config.service!.iconName)
                    }
                }
            } label: {
                Label("Save to...", systemImage: "bookmark.circle")
            }
        }
        
        Divider()
        
        // Status actions
        Button {
            appState.present(sheet: .compose(replyTo: linkStatus.status))
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        
        Button {
            appState.present(sheet: .compose(quote: linkStatus.status))
        } label: {
            Label("Quote", systemImage: "quote.bubble")
        }
    }
}

#Preview {
    NavigationStack {
        LinkFeedView()
    }
    .environment(AppState())
    .environment(LinkFilterService())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

//
//  ExploreFeedView.swift
//  fedi-reader
//
//  Instance trending/explore feed
//

import SwiftUI

struct ExploreFeedView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var selectedSegment: ExploreSegment = .links
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Explore", selection: $selectedSegment) {
                ForEach(ExploreSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            Group {
                switch selectedSegment {
                case .links:
                    trendingLinksView
                case .posts:
                    trendingPostsView
                case .tags:
                    trendingTagsView
                }
            }
        }
        .navigationTitle("Explore")
        .refreshable {
            await timelineService?.loadExploreContent()
        }
        .task {
            await timelineService?.loadExploreContent()
        }
    }
    
    private var trendingLinksView: some View {
        Group {
            if let links = timelineService?.trendingLinks, !links.isEmpty {
                GlassEffectContainer {
                    List(links, id: \.url) { link in
                        TrendingLinkRow(link: link)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .listRowSpacing(8)
                }
            } else if timelineService?.isLoadingExplore == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Trending Links",
                    systemImage: "link.badge.plus",
                    description: Text("Trending links from your instance will appear here.")
                )
            }
        }
    }
    
    private var trendingPostsView: some View {
        Group {
            if let statuses = timelineService?.exploreStatuses, !statuses.isEmpty {
                GlassEffectContainer {
                    List(statuses) { status in
                        StatusRowView(status: status)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .onAppear {
                                checkLoadMore(status)
                            }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .listRowSpacing(8)
                }
            } else if timelineService?.isLoadingExplore == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Trending Posts",
                    systemImage: "text.bubble",
                    description: Text("Trending posts from your instance will appear here.")
                )
            }
        }
    }
    
    private var trendingTagsView: some View {
        ContentUnavailableView(
            "Trending Tags",
            systemImage: "number",
            description: Text("Coming soon")
        )
    }
    
    private func checkLoadMore(_ status: Status) {
        guard let statuses = timelineService?.exploreStatuses,
              let index = statuses.firstIndex(of: status) else { return }
        
        if index >= statuses.count - Constants.Pagination.prefetchThreshold {
            Task {
                await timelineService?.loadMoreExploreStatuses()
            }
        }
    }
}

// MARK: - Explore Segment

enum ExploreSegment: String, CaseIterable, Identifiable {
    case links
    case posts
    case tags
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .links: return "Links"
        case .posts: return "Posts"
        case .tags: return "Tags"
        }
    }
}

// MARK: - Trending Link Row

struct TrendingLinkRow: View {
    let link: TrendingLink
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    
    var body: some View {
        Button {
            if let url = link.linkURL {
                // Create a minimal status wrapper or navigate directly
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
        } label: {
            HStack(spacing: 12) {
                // Image
                if let imageURL = link.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(.tertiary)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.tertiary)
                        .frame(width: 100, height: 100)
                        .overlay {
                            Image(systemName: "link")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(link.title)
                        .font(.roundedHeadline)
                        .lineLimit(2)
                    
                    if !link.description.isEmpty {
                        Text(link.description)
                            .font(.roundedSubheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 8) {
                        if let provider = link.providerName {
                            Text(provider)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        if let author = link.authorName {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            
                            Text(author)
                                .font(.roundedCaption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let url = link.linkURL {
                Link(destination: url) {
                    Label("Open in Browser", systemImage: "safari")
                }
                
                ShareLink(item: url) {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    #if os(iOS)
                    UIPasteboard.general.url = url
                    #elseif os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .URL)
                    #endif
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                }
                
                if readLaterManager.hasConfiguredServices {
                    Divider()
                    
                    if let primary = readLaterManager.primaryService, let serviceType = primary.service {
                        Button {
                            Task {
                                try? await readLaterManager.save(
                                    url: url,
                                    title: link.title,
                                    to: serviceType
                                )
                            }
                        } label: {
                            Label("Save to \(serviceType.displayName)", systemImage: "bookmark")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExploreFeedView()
    }
    .environment(AppState())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

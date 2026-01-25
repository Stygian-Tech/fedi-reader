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
#if os(iOS)
                    .listRowSpacing(8)
#endif
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
#if os(iOS)
                    .listRowSpacing(8)
#endif
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

#Preview {
    NavigationStack {
        ExploreFeedView()
    }
    .environment(AppState())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

import SwiftUI

struct HashtagsTabRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var followedTags: [Tag] {
        timelineService?.followedTags ?? []
    }

    private var isLoading: Bool {
        timelineService?.isLoadingFollowedTags ?? false
    }

    var body: some View {
        List {
            if isLoading && followedTags.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if followedTags.isEmpty {
                ContentUnavailableView {
                    Label("No Followed Hashtags", systemImage: "number")
                } description: {
                    Text("Follow hashtags from the Explore tab or by tapping # in posts. They will appear here.")
                }
            } else {
                Section {
                    ForEach(followedTags, id: \.name) { tag in
                        NavigationLink(value: NavigationDestination.hashtagFeed(tag)) {
                            Label("#\(tag.name)", systemImage: "number")
                        }
                    }
                }
            }
        }
        .navigationTitle("Hashtags")
        .refreshable {
            await timelineService?.loadFollowedTags(refresh: true)
        }
        .task {
            await loadFollowedTags()
        }
    }

    private func loadFollowedTags() async {
        guard let timelineService else { return }
        if followedTags.isEmpty {
            await timelineService.loadFollowedTags(refresh: true)
        }
    }
}

struct HashtagFeedDetailView: View {
    @Environment(\.layoutMode) private var layoutMode

    let tag: Tag

    private var hashtagFeedTab: FeedTabItem {
        FeedTabItem(id: AppState.hashtagFeedID(tag.name), title: "#\(tag.name)")
    }

    var body: some View {
        Group {
            switch layoutMode {
            case .wide, .medium:
                LinkFeedTwoColumnView(
                    feedTabsOverride: [hashtagFeedTab],
                    showsFeedPicker: false,
                    allowsSwipeNavigation: false,
                    titleOverride: "#\(tag.name)",
                    userFilterToolbarPlacement: .trailing
                )
            case .compact:
                LinkFeedView(
                    feedTabsOverride: [hashtagFeedTab],
                    showsFeedPicker: false,
                    allowsSwipeNavigation: false,
                    titleOverride: "#\(tag.name)",
                    userFilterToolbarPlacement: .trailing
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        HashtagsTabRootView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

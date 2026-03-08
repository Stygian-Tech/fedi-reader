import SwiftUI

struct LinkFeedView: View {
    let feedTabsOverride: [FeedTabItem]?
    let showsFeedPicker: Bool
    let allowsSwipeNavigation: Bool
    let titleOverride: String?
    let userFilterToolbarPlacement: UserFilterToolbarPlacement

    init(
        feedTabsOverride: [FeedTabItem]? = nil,
        showsFeedPicker: Bool = true,
        allowsSwipeNavigation: Bool = true,
        titleOverride: String? = nil,
        userFilterToolbarPlacement: UserFilterToolbarPlacement = .leading
    ) {
        self.feedTabsOverride = feedTabsOverride
        self.showsFeedPicker = showsFeedPicker
        self.allowsSwipeNavigation = allowsSwipeNavigation
        self.titleOverride = titleOverride
        self.userFilterToolbarPlacement = userFilterToolbarPlacement
    }

    var body: some View {
        LinkFeedContentView(
            onArticleSelect: nil,
            feedTabsOverride: feedTabsOverride,
            showsFeedPicker: showsFeedPicker,
            allowsSwipeNavigation: allowsSwipeNavigation,
            titleOverride: titleOverride,
            userFilterToolbarPlacement: userFilterToolbarPlacement
        )
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

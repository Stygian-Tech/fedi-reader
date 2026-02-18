import SwiftUI

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


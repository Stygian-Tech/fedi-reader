import SwiftUI

struct LinkFeedView: View {
    var body: some View {
        LinkFeedContentView(onArticleSelect: nil)
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

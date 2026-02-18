import SwiftUI

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



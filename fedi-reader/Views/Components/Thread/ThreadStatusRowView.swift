import SwiftUI

struct ThreadStatusRowView: View {
    let status: Status
    let showReplyIndicator: Bool
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showReplyIndicator, status.inReplyToId != nil {
                ReplyIndicator(status: status)
            }
            
            StatusRowView(status: status)
        }
    }
}

// MARK: - Thread Connector (standalone component)



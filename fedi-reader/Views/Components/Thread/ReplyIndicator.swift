import SwiftUI

struct ReplyIndicator: View {
    let status: Status
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let replyToId = status.inReplyToId {
            Button {
                appState.navigate(to: .thread(statusId: replyToId))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    if status.inReplyToAccountId != nil {
                        Text("Replying")
                            .font(.roundedCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Thread Status Row View (for timeline displays)



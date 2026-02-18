import SwiftUI
import os

struct MentionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    private var timelineService: TimelineService? {
        timelineWrapper.service
    }
    
    private var conversations: [MastodonConversation] {
        timelineService?.conversations ?? []
    }
    
    var body: some View {
        Group {
            if !conversations.isEmpty {
                ConversationsListView(conversations: conversations)
            } else if timelineService?.isLoadingConversations == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.present(sheet: .newMessage)
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New message")
                .accessibilityHint("Opens composer to write a new direct message")
            }
        }
        .refreshable {
            await timelineService?.refreshConversations()
        }
        .task {
            await loadConversations()
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Messages", systemImage: "message")
        } description: {
            Text("Private mentions and direct messages will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await timelineService?.refreshConversations()
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func loadConversations() async {
        if timelineService?.conversations.isEmpty == true {
            await timelineService?.refreshConversations()
        }
    }
}


#Preview {
    NavigationStack {
        MentionsView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}


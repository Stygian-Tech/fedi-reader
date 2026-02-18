import SwiftUI
import os

struct ConversationsListView: View {
    let conversations: [MastodonConversation]
    @Environment(AppState.self) private var appState
    
    // Group conversations by participants
    private var groupedConversations: [GroupedConversation] {
        guard let currentAccountId = appState.currentAccount?.mastodonAccount.id else {
            return []
        }

        return ConversationGroupingHelper.groupedConversations(
            from: conversations,
            currentAccountId: currentAccountId
        )
    }
    
    var body: some View {
        GlassEffectContainer {
            List(groupedConversations) { groupedConvo in
                NavigationLink {
                    GroupedConversationDetailView(groupedConversation: groupedConvo)
                } label: {
                    GroupedConversationRow(groupedConversation: groupedConvo)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(8)
        }
    }
}

// MARK: - Grouped Conversation Row



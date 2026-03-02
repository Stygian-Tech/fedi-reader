import SwiftUI
import os

struct ConversationsListView: View {
    let conversations: [MastodonConversation]
    var selection: Binding<GroupedConversation?>? = nil
    @Environment(AppState.self) private var appState
    @AppStorage("themeColor") private var themeColorName = "blue"

    private var twoColumnMode: Bool {
        selection != nil
    }

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
                rowContent(for: groupedConvo)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowSpacing(8)
        }
    }

    @ViewBuilder
    private func rowContent(for groupedConvo: GroupedConversation) -> some View {
        if twoColumnMode, let selection {
            Button {
                selection.wrappedValue = groupedConvo
            } label: {
                GroupedConversationRow(groupedConversation: groupedConvo)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                selection.wrappedValue?.id == groupedConvo.id
                    ? ThemeColor.resolved(from: themeColorName).color.opacity(0.12)
                    : Color.clear
            )
        } else {
            NavigationLink(value: NavigationDestination.conversation(groupedConvo)) {
                GroupedConversationRow(groupedConversation: groupedConvo)
            }
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - Grouped Conversation Row



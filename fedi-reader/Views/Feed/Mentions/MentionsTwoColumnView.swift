//
//  MentionsTwoColumnView.swift
//  fedi-reader
//
//  Two-column layout for messages: conversations list | conversation detail.
//

import SwiftUI

struct MentionsTwoColumnView: View {
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var selectedConversation: GroupedConversation?
    @AppStorage("mentionsConversationsWidth") private var persistedConversationsWidth: Double = 280
    @State private var conversationsWidth: Double = 280

    private static let minConversationsWidth: CGFloat = 200
    private static let minDetailWidth: CGFloat = 300

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var conversations: [MastodonConversation] {
        timelineService?.conversations ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dividerTotal: CGFloat = 8
            let availableWidth = totalWidth - dividerTotal
            let resolvedConversationsWidth = min(
                max(CGFloat(conversationsWidth), Self.minConversationsWidth),
                availableWidth - Self.minDetailWidth
            )

            HStack(spacing: 0) {
                // Column 1: Conversations list
                VStack(spacing: 0) {
                    HStack {
                        Text("Messages")
                            .font(.roundedTitle2.bold())
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))

                    if !conversations.isEmpty {
                        ConversationsListView(conversations: conversations, selection: $selectedConversation)
                    } else if timelineService?.isLoadingConversations == true {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        emptyStateView
                    }
                }
                .frame(width: resolvedConversationsWidth)
                .background(Color(.systemBackground))
                .zIndex(1)

                ResizableColumnDivider(
                    width: $conversationsWidth,
                    minValue: Self.minConversationsWidth,
                    maxValue: availableWidth - Self.minDetailWidth
                ) {
                    persistedConversationsWidth = conversationsWidth
                }

                // Column 2: Conversation detail
                Group {
                    if let selected = selectedConversation {
                        GroupedConversationDetailView(groupedConversation: selected)
                    } else {
                        ContentUnavailableView {
                            Label("Select a Conversation", systemImage: "message")
                        } description: {
                            Text("Choose a conversation from the list to view messages.")
                        }
                    }
                }
                .frame(minWidth: Self.minDetailWidth, maxWidth: .infinity)
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            conversationsWidth = persistedConversationsWidth
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadConversations() async {
        if timelineService?.conversations.isEmpty == true {
            await timelineService?.refreshConversations()
        }
    }
}

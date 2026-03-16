import SwiftUI

struct StatusDetailView: View {
    let status: Status
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var context: StatusContext?
    @State private var replyThreads: [ThreadNode] = []
    @State private var isLoading = true
    @State private var isLoadingRemoteReplies = false

    private let threadingService = ThreadingService.shared

    private var threadStatus: Status {
        status.displayStatus
    }

    private var parentStatus: Status? {
        context?.parentStatus(for: status)
    }

    private var replyTreeSource: [Status] {
        context?.descendants ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let parentStatus {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("In Reply To", systemImage: "arrow.turn.down.right")
                            .font(.roundedCaption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        StatusDetailRowView(status: parentStatus)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                }

                StatusDetailRowView(status: status)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let context = context {
                    let shouldFetchMoreReplies = shouldFetchRemoteReplies(context: context)
                    
                    if !context.descendants.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            replyHeader(
                                discoveredReplyCount: context.descendants.count,
                                shouldFetchMoreReplies: shouldFetchMoreReplies,
                                includeHorizontalPadding: true
                            )

                            ForEach(replyThreads) { thread in
                                ReplyThreadCard(thread: thread)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    } else if shouldFetchMoreReplies || threadStatus.repliesCount > 0 {
                        // Show message if we expect replies but don't have any yet
                        VStack(alignment: .leading, spacing: 0) {
                            replyHeader(
                                discoveredReplyCount: context.descendants.count,
                                shouldFetchMoreReplies: shouldFetchMoreReplies,
                                includeHorizontalPadding: true
                            )
                            
                            if isLoadingRemoteReplies {
                                HStack {
                                    Text("Loading remote replies...")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: threadStatus.id) {
            await loadContext()
        }
        .task(id: replyTreeSource) {
            await rebuildReplyTrees(from: replyTreeSource)
        }
        .refreshable {
            await refreshReplies()
        }
        .onDisappear {
            timelineWrapper.service?.cancelAsyncRefreshPolling(forStatusId: threadStatus.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .statusContextDidUpdate)) { notification in
            if let payload = notification.object as? StatusContextUpdatePayload,
               payload.statusId == threadStatus.id {
                context = payload.context
                isLoadingRemoteReplies = false
            }
        }
    }

    private func loadContext() async {
        context = nil
        isLoading = true
        isLoadingRemoteReplies = false

        guard let service = timelineWrapper.service else {
            isLoading = false
            return
        }

        do {
            let loadedContext = try await service.getStatusContext(for: threadStatus)
            context = loadedContext
            isLoading = false
            isLoadingRemoteReplies = false
        } catch {
            isLoading = false
            isLoadingRemoteReplies = false
        }
    }

    private func rebuildReplyTrees(from descendants: [Status]) async {
        if descendants.isEmpty {
            replyThreads = []
            return
        }

        let trees = await threadingService.buildThreadTree(
            from: descendants,
            replyOrdering: .prioritizeAuthor(threadStatus.account.id)
        )
        guard !Task.isCancelled else { return }
        replyThreads = trees
    }
    
    private func shouldFetchRemoteReplies(context: StatusContext) -> Bool {
        context.needsRemoteReplyFetch(for: threadStatus)
    }
    
    private func refreshReplies() async {
        guard let service = timelineWrapper.service else { return }
        
        isLoadingRemoteReplies = true
        
        do {
            try await service.refreshContextForStatus(threadStatus)
            // Context updated via notification (immediate if no async refresh, else when polling finishes)
        } catch {
            isLoadingRemoteReplies = false
        }
    }

    @ViewBuilder
    private func replyHeader(
        discoveredReplyCount: Int,
        shouldFetchMoreReplies: Bool,
        includeHorizontalPadding: Bool
    ) -> some View {
        HStack {
            Text("Replies")
                .font(.roundedHeadline)

            if isLoadingRemoteReplies {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.leading, 4)
            }

            Spacer()

            if threadStatus.repliesCount > discoveredReplyCount {
                Text("\(discoveredReplyCount) of \(threadStatus.repliesCount)")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            } else if context?.hasMoreReplies == true {
                Text("More available")
                    .font(.roundedCaption)
                    .foregroundStyle(.secondary)
            }

            if shouldFetchMoreReplies && !isLoadingRemoteReplies {
                Button {
                    Task {
                        await refreshReplies()
                    }
                } label: {
                    Label("Fetch Remote", systemImage: "arrow.down.circle")
                        .font(.roundedCaption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, includeHorizontalPadding ? 0 : 11)
                        .padding(.vertical, 6)
    }
}

import SwiftUI

struct StatusDetailView: View {
    let status: Status
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var context: StatusContext?
    @State private var replyTrees: [ThreadNode] = []
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
                        // Single card containing reply thread (without parent)
                        VStack(alignment: .leading, spacing: 0) {
                            // Header with controls
                            HStack {
                                Text("Replies")
                                    .font(.roundedHeadline)
                                
                                if isLoadingRemoteReplies {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.leading, 4)
                                }
                                
                                Spacer()
                                
                                // Show expected count if we have more replies
                                if threadStatus.repliesCount > context.descendants.count {
                                    Text("\(context.descendants.count) of \(threadStatus.repliesCount)")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                } else if context.hasMoreReplies == true {
                                    Text("More available")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Button to fetch remote replies
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
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            
                            Divider()
                            
                            // Display reply thread tree (only descendants, no parent)
                            CompactThreadView(threads: replyTrees)
                                .padding(.vertical, 5)
                        }
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    } else if shouldFetchMoreReplies || threadStatus.repliesCount > 0 {
                        // Show message if we expect replies but don't have any yet
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Replies")
                                    .font(.roundedHeadline)
                                
                                if isLoadingRemoteReplies {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .padding(.leading, 4)
                                }
                                
                                Spacer()
                                
                                // Button to fetch remote replies
                                if !isLoadingRemoteReplies {
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
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            
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
            replyTrees = []
            return
        }

        let trees = await threadingService.buildThreadTree(from: descendants)
        guard !Task.isCancelled else { return }
        replyTrees = trees
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
}

import SwiftUI

struct StatusDetailView: View {
    let status: Status
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    @State private var context: StatusContext?
    @State private var isLoading = true
    @State private var isLoadingRemoteReplies = false
    
    private let threadingService = ThreadingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Parent post as its own card at the top
                StatusDetailRowView(status: status)
                    .padding(.horizontal)
                    .padding(.vertical, 5)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let context = context {
                    // Build thread tree from descendants only (exclude parent/current post)
                    let replyTrees = threadingService.buildThreadTree(from: context.descendants)
                    
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
                                if status.repliesCount > context.descendants.count {
                                    Text("\(context.descendants.count) of \(status.repliesCount)")
                                        .font(.roundedCaption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Button to fetch remote replies
                                if status.repliesCount > context.descendants.count && !isLoadingRemoteReplies {
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
                    } else if status.repliesCount > 0 {
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
        .task {
            await loadContext()
        }
        .refreshable {
            await refreshReplies()
        }
        .onDisappear {
            timelineWrapper.service?.cancelAsyncRefreshPolling(forStatusId: status.id)
        }
        .onReceive(NotificationCenter.default.publisher(for: .statusContextDidUpdate)) { notification in
            // Update context when remote replies are fetched
            if let payload = notification.object as? StatusContextUpdatePayload,
               payload.statusId == status.id {
                // Replace context with updated one (it already contains all replies)
                context = payload.context
                isLoadingRemoteReplies = false
            }
        }
    }

    private func loadContext() async {
        guard let service = timelineWrapper.service else {
            isLoading = false
            return
        }

        do {
            let loadedContext = try await service.getStatusContext(for: status)
            context = loadedContext
            isLoading = false
            
            // Check if we need to fetch remote replies
            // Note: getStatusContext already triggers remote reply fetching in background
            // We just need to show loading state
            if shouldFetchRemoteReplies(context: loadedContext) {
                isLoadingRemoteReplies = true
            }
        } catch {
            isLoading = false
            isLoadingRemoteReplies = false
        }
    }
    
    private func shouldFetchRemoteReplies(context: StatusContext) -> Bool {
        // Fetch if we have fewer descendants than expected
        if status.repliesCount > context.descendants.count {
            return true
        }
        
        // Fetch if async refresh is indicated
        if context.asyncRefreshId != nil {
            return true
        }
        
        return false
    }
    
    private func refreshReplies() async {
        guard let service = timelineWrapper.service else { return }
        
        isLoadingRemoteReplies = true
        
        do {
            try await service.refreshContextForStatus(status)
            // Context updated via notification (immediate if no async refresh, else when polling finishes)
        } catch {
            isLoadingRemoteReplies = false
        }
    }
}


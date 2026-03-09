import SwiftUI

struct BookmarksFeedView: View {
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper

    private var timelineService: TimelineService? {
        timelineWrapper.service
    }

    private var bookmarks: [Status] {
        timelineService?.bookmarks ?? []
    }

    var body: some View {
        Group {
            if !bookmarks.isEmpty {
                GlassEffectContainer {
                    List(bookmarks) { status in
                        StatusRowView(status: status)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .onAppear {
                                checkLoadMore(status)
                            }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
#if os(iOS)
                    .listRowSpacing(8)
#endif
                }
            } else if timelineService?.isLoadingBookmarks == true {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Bookmarks")
        .refreshable {
            await timelineService?.refreshBookmarks()
        }
        .task {
            await loadBookmarks()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Bookmarks", systemImage: "bookmark")
        } description: {
            Text("Posts you bookmark will appear here.")
        } actions: {
            Button("Refresh") {
                Task {
                    await timelineService?.refreshBookmarks()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func loadBookmarks() async {
        if timelineService?.bookmarks.isEmpty == true {
            await timelineService?.refreshBookmarks()
        }
    }

    private func checkLoadMore(_ status: Status) {
        guard let bookmarks = timelineService?.bookmarks,
              let index = bookmarks.firstIndex(of: status) else { return }

        if index >= bookmarks.count - Constants.Pagination.prefetchThreshold {
            Task {
                await timelineService?.loadMoreBookmarks()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookmarksFeedView()
    }
    .environment(AppState())
    .environment(TimelineServiceWrapper())
}

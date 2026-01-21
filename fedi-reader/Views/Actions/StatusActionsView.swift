//
//  StatusActionsView.swift
//  fedi-reader
//
//  Status action buttons (star, boost, reply, etc.)
//

import SwiftUI

// MARK: - Status Actions Bar

struct StatusActionsBar: View {
    let status: Status
    let compact: Bool
    
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var isProcessing = false
    @State private var localFavorited: Bool?
    @State private var localReblogged: Bool?
    @State private var localFavoriteCount: Int?
    @State private var localReblogCount: Int?
    
    private var displayStatus: Status {
        status.displayStatus
    }
    
    private var isFavorited: Bool {
        localFavorited ?? displayStatus.favourited ?? false
    }
    
    private var isReblogged: Bool {
        localReblogged ?? displayStatus.reblogged ?? false
    }
    
    private var favoriteCount: Int {
        localFavoriteCount ?? displayStatus.favouritesCount
    }
    
    private var reblogCount: Int {
        localReblogCount ?? displayStatus.reblogsCount
    }
    
    var body: some View {
        HStack(spacing: compact ? 16 : 24) {
            // Reply
            actionButton(
                icon: "arrowshape.turn.up.left",
                count: displayStatus.repliesCount,
                isActive: false,
                activeColor: .accentColor
            ) {
                appState.present(sheet: .compose(replyTo: status))
            }
            
            // Boost
            actionButton(
                icon: "arrow.2.squarepath",
                count: reblogCount,
                isActive: isReblogged,
                activeColor: .green
            ) {
                await toggleReblog()
            }
            
            // Favorite
            actionButton(
                icon: isFavorited ? "star.fill" : "star",
                count: favoriteCount,
                isActive: isFavorited,
                activeColor: .yellow
            ) {
                await toggleFavorite()
            }
            
            // Quote (if not compact)
            if !compact {
                actionButton(
                    icon: "quote.bubble",
                    count: nil,
                    isActive: false,
                    activeColor: .accentColor
                ) {
                    appState.present(sheet: .compose(quote: status))
                }
            }
            
            Spacer()
            
            // Share
            ShareLink(item: URL(string: displayStatus.url ?? "") ?? URL(string: "https://example.com")!) {
                Image(systemName: "square.and.arrow.up")
                    .font(compact ? .roundedCaption : .roundedSubheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .disabled(isProcessing)
    }
    
    @ViewBuilder
    private func actionButton(
        icon: String,
        count: Int?,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(compact ? .roundedCaption : .roundedSubheadline)
                    .foregroundStyle(isActive ? activeColor : .secondary)
                
                // Always show count, even if 0, for consistency
                Text(formatCount(count ?? 0))
                    .font(compact ? .roundedCaption2 : .roundedCaption)
                    .foregroundStyle(isActive ? activeColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    
    private func toggleFavorite() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Optimistic update
        let wasFavorited = isFavorited
        localFavorited = !wasFavorited
        localFavoriteCount = favoriteCount + (wasFavorited ? -1 : 1)
        
        do {
            let updatedStatus = try await service.favorite(status: status)
            localFavorited = updatedStatus.favourited
            localFavoriteCount = updatedStatus.favouritesCount
        } catch {
            // Revert optimistic update
            localFavorited = wasFavorited
            localFavoriteCount = favoriteCount + (wasFavorited ? 0 : -1)
            appState.handleError(error)
        }
    }
    
    private func toggleReblog() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Optimistic update
        let wasReblogged = isReblogged
        localReblogged = !wasReblogged
        localReblogCount = reblogCount + (wasReblogged ? -1 : 1)
        
        do {
            let updatedStatus = try await service.reblog(status: status)
            localReblogged = updatedStatus.reblogged
            localReblogCount = updatedStatus.reblogsCount
        } catch {
            // Revert optimistic update
            localReblogged = wasReblogged
            localReblogCount = reblogCount + (wasReblogged ? 0 : -1)
            appState.handleError(error)
        }
    }
}

// MARK: - Expanded Actions Toolbar (for Web View)

struct StatusActionsToolbar: View {
    let status: Status
    
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @State private var isProcessing = false
    @State private var localFavorited: Bool?
    @State private var localReblogged: Bool?
    @State private var localBookmarked: Bool?
    
    private var displayStatus: Status {
        status.displayStatus
    }
    
    private var isFavorited: Bool {
        localFavorited ?? displayStatus.favourited ?? false
    }
    
    private var isReblogged: Bool {
        localReblogged ?? displayStatus.reblogged ?? false
    }
    
    private var isBookmarked: Bool {
        localBookmarked ?? displayStatus.bookmarked ?? false
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Reply
            toolbarButton(
                icon: "arrowshape.turn.up.left",
                label: "Reply",
                isActive: false,
                activeColor: .accentColor
            ) {
                appState.present(sheet: .compose(replyTo: status))
            }
            
            // Boost
            toolbarButton(
                icon: "arrow.2.squarepath",
                label: "Boost",
                isActive: isReblogged,
                activeColor: .green
            ) {
                await toggleReblog()
            }
            
            // Favorite
            toolbarButton(
                icon: isFavorited ? "star.fill" : "star",
                label: "Star",
                isActive: isFavorited,
                activeColor: .yellow
            ) {
                await toggleFavorite()
            }
            
            // Bookmark
            toolbarButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                label: "Bookmark",
                isActive: isBookmarked,
                activeColor: .orange
            ) {
                await toggleBookmark()
            }
            
            // Quote
            toolbarButton(
                icon: "quote.bubble",
                label: "Quote",
                isActive: false,
                activeColor: .accentColor
            ) {
                appState.present(sheet: .compose(quote: status))
            }
            
            // Read Later (if configured)
            if readLaterManager.hasConfiguredServices, let url = displayStatus.card?.linkURL {
                Menu {
                    ForEach(readLaterManager.configuredServices) { config in
                        if let serviceType = config.service {
                            Button {
                                Task {
                                    try? await readLaterManager.save(
                                        url: url,
                                        title: displayStatus.card?.title,
                                        to: serviceType
                                    )
                                }
                            } label: {
                                Label(serviceType.displayName, systemImage: serviceType.iconName)
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.title3)
                        
                        Text("Save")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .disabled(isProcessing)
    }
    
    @ViewBuilder
    private func toolbarButton(
        icon: String,
        label: String,
        isActive: Bool,
        activeColor: Color,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.roundedTitle3)
                            .foregroundStyle(isActive ? activeColor : .secondary)
                        
                        Text(label)
                            .font(.roundedCaption2)
                            .foregroundStyle(isActive ? activeColor : .secondary)
                    }
                }
        .buttonStyle(.plain)
    }
    
    private func toggleFavorite() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasFavorited = isFavorited
        localFavorited = !wasFavorited
        
        do {
            let updated = try await service.favorite(status: status)
            localFavorited = updated.favourited
        } catch {
            localFavorited = wasFavorited
            appState.handleError(error)
        }
    }
    
    private func toggleReblog() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasReblogged = isReblogged
        localReblogged = !wasReblogged
        
        do {
            let updated = try await service.reblog(status: status)
            localReblogged = updated.reblogged
        } catch {
            localReblogged = wasReblogged
            appState.handleError(error)
        }
    }
    
    private func toggleBookmark() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasBookmarked = isBookmarked
        localBookmarked = !wasBookmarked
        
        do {
            let updated = try await service.bookmark(status: status)
            localBookmarked = updated.bookmarked
        } catch {
            localBookmarked = wasBookmarked
            appState.handleError(error)
        }
    }
}

#Preview("Status Actions View") {
    VStack(spacing: 20) {
        Text("Compact")
        StatusActionsBar(status: Status.samplePreview, compact: true)
        
        Divider()
        
        Text("Full")
        StatusActionsBar(status: Status.samplePreview, compact: false)
        
        Divider()
        
        Text("Toolbar")
        StatusActionsToolbar(status: Status.samplePreview)
    }
    .padding()
    .environment(AppState())
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

// MARK: - Preview Helper

extension Status {
    static var preview: Status {
        // This would need actual mock data in a real implementation
        fatalError("Preview not implemented - needs mock data")
    }
}

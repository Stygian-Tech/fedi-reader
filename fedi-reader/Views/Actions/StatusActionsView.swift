//
//  StatusActionsView.swift
//  fedi-reader
//
//  Status action buttons (star, boost, reply, etc.)
//

import SwiftUI

// MARK: - Status Actions Bar

enum StatusActionsBarSize {
    case compact   // Link feed — medium
    case standard  // Main feed (Explore, etc.) — full
    case detail    // Post detail view — small
}

struct StatusActionsBar: View {
    let status: Status
    let size: StatusActionsBarSize
    
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    @Environment(ReadLaterManager.self) private var readLaterManager
    
    @AppStorage("showQuoteBoost") private var showQuoteBoost = true
    
    @State private var isProcessing = false
    @State private var localFavorited: Bool?
    @State private var localReblogged: Bool?
    @State private var localBookmarked: Bool?
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
    
    private var isBookmarked: Bool {
        localBookmarked ?? displayStatus.bookmarked ?? false
    }
    
    private var statusURL: URL? {
        displayStatus.card?.linkURL ?? URL(string: displayStatus.url ?? "")
    }
    
    var body: some View {
        actionsRow
            .disabled(isProcessing)
            .onReceive(NotificationCenter.default.publisher(for: .statusDidUpdate)) { notification in
                guard let updated = notification.object as? Status else { return }
                applyUpdatedStatus(updated)
            }
    }
    
    @ViewBuilder
    private func actionButton(
        icon: String,
        count: Int?,
        isActive: Bool,
        activeColor: Color,
        accessibilityLabel: String,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard !isProcessing else { return }
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(iconFont)
                    .foregroundStyle(isActive ? activeColor : .secondary)

                Text(formatCount(count ?? 0))
                    .font(countFont)
                    .foregroundStyle(isActive ? activeColor : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isActive ? "Active, \(formatCount(count ?? 0))" : formatCount(count ?? 0))
        .accessibilityHint("Double tap to \(accessibilityLabel.lowercased())")
    }
    
    private var iconFont: Font {
        switch size {
        case .compact: return .roundedHeadline
        case .standard: return .roundedHeadline
        case .detail: return .roundedTitle3
        }
    }
    
    private var countFont: Font {
        switch size {
        case .compact: return .roundedCaption
        case .standard: return .roundedCaption
        case .detail: return .roundedSubheadline
        }
    }

    private var actionsRow: some View {
        HStack(spacing: rowSpacing) {
            actionButtons
            Spacer()
            trailingActions
        }
    }
    
    private var rowSpacing: CGFloat {
        switch size {
        case .compact: return 12
        case .standard: return 14
        case .detail: return 18
        }
    }

    private var actionButtons: some View {
        Group {
            // Reply
            actionButton(
                icon: "arrowshape.turn.up.left",
                count: displayStatus.repliesCount,
                isActive: false,
                activeColor: .accentColor,
                accessibilityLabel: "Reply"
            ) {
                appState.present(sheet: .compose(replyTo: displayStatus))
            }

            // Boost (with optional Quote Boost menu)
            boostButton

            // Favorite
            actionButton(
                icon: isFavorited ? "star.fill" : "star",
                count: favoriteCount,
                isActive: isFavorited,
                activeColor: .yellow,
                accessibilityLabel: "Favorite"
            ) {
                await toggleFavorite()
            }
        }
        .layoutPriority(1)
    }
    
    @ViewBuilder
    private var boostButton: some View {
        if isReblogged {
            // Already boosted - show menu with Unboost option
            Menu {
                Button {
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Unboost", systemImage: "arrow.2.squarepath")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(iconFont)
                        .foregroundStyle(.green)

                    Text(formatCount(reblogCount))
                        .font(countFont)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Boost")
            .accessibilityValue("Active, \(formatCount(reblogCount))")
        } else if showQuoteBoost {
            // Not boosted and quote boost enabled - show menu with both options
            Menu {
                Button {
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Boost", systemImage: "arrow.2.squarepath")
                }
                
                Button {
                    appState.present(sheet: .compose(quote: status))
                } label: {
                    Label("Quote Boost", systemImage: "quote.bubble")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(iconFont)
                        .foregroundStyle(.secondary)

                    Text(formatCount(reblogCount))
                        .font(countFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Boost")
            .accessibilityValue(formatCount(reblogCount))
        } else {
            // Not boosted and quote boost disabled - show direct button
            actionButton(
                icon: "arrow.2.squarepath",
                count: reblogCount,
                isActive: false,
                activeColor: .green,
                accessibilityLabel: "Boost"
            ) {
                await toggleReblog()
            }
        }
    }

    private var trailingActions: some View {
        HStack(spacing: rowSpacing) {
            // Bookmark
            actionButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                count: nil,
                isActive: isBookmarked,
                activeColor: .orange,
                accessibilityLabel: "Bookmark"
            ) {
                await toggleBookmark()
            }

            // Read Later (if configured and URL available)
            if readLaterManager.hasConfiguredServices, let url = statusURL {
                Menu {
                    if let primary = readLaterManager.primaryService, let serviceType = primary.service {
                        Button {
                            Task {
                                try? await readLaterManager.save(
                                    url: url,
                                    title: displayStatus.card?.title,
                                    to: serviceType
                                )
                            }
                        } label: {
                            Label("Save to \(serviceType.displayName)", systemImage: serviceType.iconName)
                        }
                    }
                    
                    Menu {
                        ForEach(readLaterManager.configuredServices, id: \.id) { config in
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
                        Label("Save to...", systemImage: "bookmark.circle")
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(iconFont)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Share
            ShareLink(item: URL(string: displayStatus.url ?? "") ?? URL(string: "https://example.com")!) {
                Image(systemName: "square.and.arrow.up")
                    .font(iconFont)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .layoutPriority(0)
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
            let updatedStatus = try await service.setFavorite(status: status, isFavorited: !wasFavorited)
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
            let updatedStatus = try await service.setReblog(status: status, isReblogged: !wasReblogged)
            localReblogged = updatedStatus.reblogged
            localReblogCount = updatedStatus.reblogsCount
        } catch {
            // Revert optimistic update
            localReblogged = wasReblogged
            localReblogCount = reblogCount + (wasReblogged ? 0 : -1)
            appState.handleError(error)
        }
    }
    
    private func toggleBookmark() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Optimistic update
        let wasBookmarked = isBookmarked
        localBookmarked = !wasBookmarked
        
        do {
            let updatedStatus = try await service.bookmark(status: status)
            localBookmarked = updatedStatus.bookmarked
        } catch {
            // Revert optimistic update
            localBookmarked = wasBookmarked
            appState.handleError(error)
        }
    }

    private func applyUpdatedStatus(_ updated: Status) {
        guard updated.id == displayStatus.id else { return }
        localFavorited = updated.favourited
        localReblogged = updated.reblogged
        localBookmarked = updated.bookmarked
        localFavoriteCount = updated.favouritesCount
        localReblogCount = updated.reblogsCount
    }
}

// MARK: - Expanded Actions Toolbar (for Web View)

struct StatusActionsToolbar: View {
    let status: Status
    
    @Environment(AppState.self) private var appState
    @Environment(ReadLaterManager.self) private var readLaterManager
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @AppStorage("showQuoteBoost") private var showQuoteBoost = true
    
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
        HStack(spacing: 12) {
            // Reply
            toolbarButton(
                icon: "arrowshape.turn.up.left",
                label: "Reply",
                isActive: false,
                activeColor: .accentColor
            ) {
                appState.present(sheet: .compose(replyTo: displayStatus))
            }
            
            // Boost (with optional Quote Boost menu)
            boostToolbarButton
            
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
                    VStack(spacing: 2) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.roundedSubheadline)
                        
                        Text("Save")
                            .font(.roundedCaption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .disabled(isProcessing)
        .onReceive(NotificationCenter.default.publisher(for: .statusDidUpdate)) { notification in
            guard let updated = notification.object as? Status else { return }
            applyUpdatedStatus(updated)
        }
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
            guard !isProcessing else { return }
            Task {
                await action()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.roundedSubheadline)
                    .foregroundStyle(isActive ? activeColor : .secondary)

                Text(label)
                    .font(.roundedCaption2)
                    .foregroundStyle(isActive ? activeColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .accessibilityHint("Double tap to \(label.lowercased())")
    }
    
    @ViewBuilder
    private var boostToolbarButton: some View {
        if isReblogged {
            // Already boosted - show menu with Unboost option
            Menu {
                Button {
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Unboost", systemImage: "arrow.2.squarepath")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedSubheadline)
                        .foregroundStyle(.green)

                    Text("Boost")
                        .font(.roundedCaption2)
                        .foregroundStyle(.green)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Boost")
            .accessibilityValue("Active")
        } else if showQuoteBoost {
            // Not boosted and quote boost enabled - show menu with both options
            Menu {
                Button {
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Boost", systemImage: "arrow.2.squarepath")
                }
                
                Button {
                    appState.present(sheet: .compose(quote: status))
                } label: {
                    Label("Quote Boost", systemImage: "quote.bubble")
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.roundedSubheadline)
                        .foregroundStyle(.secondary)

                    Text("Boost")
                        .font(.roundedCaption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Boost")
        } else {
            // Not boosted and quote boost disabled - show direct button
            toolbarButton(
                icon: "arrow.2.squarepath",
                label: "Boost",
                isActive: false,
                activeColor: .green
            ) {
                await toggleReblog()
            }
        }
    }

    private func toggleFavorite() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasFavorited = isFavorited
        localFavorited = !wasFavorited
        
        do {
            let updated = try await service.setFavorite(status: status, isFavorited: !wasFavorited)
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
            let updated = try await service.setReblog(status: status, isReblogged: !wasReblogged)
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

    private func applyUpdatedStatus(_ updated: Status) {
        guard updated.id == displayStatus.id else { return }
        localFavorited = updated.favourited
        localReblogged = updated.reblogged
        localBookmarked = updated.bookmarked
    }
}

#Preview("Status Actions View") {
    VStack(spacing: 20) {
        Text("Compact (link feed)")
        StatusActionsBar(status: Status.samplePreview, size: .compact)
        
        Divider()
        
        Text("Standard (main feed)")
        StatusActionsBar(status: Status.samplePreview, size: .standard)
        
        Divider()
        
        Text("Detail")
        StatusActionsBar(status: Status.samplePreview, size: .detail)
        
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

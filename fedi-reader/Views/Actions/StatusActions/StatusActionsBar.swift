import SwiftUI

struct StatusActionsBar: View {
    let status: Status
    let size: StatusActionsBarSize
    let shouldIgnoreTap: (() -> Bool)?
    
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

    private var isTapSuppressed: Bool {
        shouldIgnoreTap?() == true
    }

    init(
        status: Status,
        size: StatusActionsBarSize,
        shouldIgnoreTap: (() -> Bool)? = nil
    ) {
        self.status = status
        self.size = size
        self.shouldIgnoreTap = shouldIgnoreTap
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
            guard !isProcessing, !isTapSuppressed else { return }
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
                    guard !isTapSuppressed else { return }
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
                    guard !isTapSuppressed else { return }
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Boost", systemImage: "arrow.2.squarepath")
                }
                
                Button {
                    guard !isTapSuppressed else { return }
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
                            guard !isTapSuppressed else { return }
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
                                    guard !isTapSuppressed else { return }
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
        let originalFavoriteCount = favoriteCount
        let wasFavorited = isFavorited
        localFavorited = !wasFavorited
        localFavoriteCount = ToggleActionCount.optimistic(currentCount: originalFavoriteCount, wasActive: wasFavorited)
        
        do {
            let updatedStatus = try await service.setFavorite(status: status, isFavorited: !wasFavorited)
            localFavorited = updatedStatus.favourited
            localFavoriteCount = ToggleActionCount.reconciled(
                originalCount: originalFavoriteCount,
                wasActive: wasFavorited,
                serverCount: updatedStatus.favouritesCount,
                serverIsActive: updatedStatus.favourited
            )
        } catch {
            // Revert optimistic update
            localFavorited = wasFavorited
            localFavoriteCount = originalFavoriteCount
            appState.handleError(error)
        }
    }
    
    private func toggleReblog() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Optimistic update
        let originalReblogCount = reblogCount
        let wasReblogged = isReblogged
        localReblogged = !wasReblogged
        localReblogCount = ToggleActionCount.optimistic(currentCount: originalReblogCount, wasActive: wasReblogged)
        
        do {
            let updatedStatus = try await service.setReblog(status: status, isReblogged: !wasReblogged)
            let resolvedStatus = updatedStatus.displayStatus
            localReblogged = resolvedStatus.reblogged
            localReblogCount = ToggleActionCount.reconciled(
                originalCount: originalReblogCount,
                wasActive: wasReblogged,
                serverCount: resolvedStatus.reblogsCount,
                serverIsActive: resolvedStatus.reblogged
            )
        } catch {
            // Revert optimistic update
            localReblogged = wasReblogged
            localReblogCount = originalReblogCount
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
        let resolvedStatus = updated.displayStatus
        guard resolvedStatus.id == displayStatus.id else { return }
        localFavorited = resolvedStatus.favourited
        localReblogged = resolvedStatus.reblogged
        localBookmarked = resolvedStatus.bookmarked
        localFavoriteCount = resolvedStatus.favouritesCount
        localReblogCount = resolvedStatus.reblogsCount
    }
}

// MARK: - Expanded Actions Toolbar (for Web View)



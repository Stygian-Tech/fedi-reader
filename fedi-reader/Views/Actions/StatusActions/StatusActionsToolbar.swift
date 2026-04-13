import SwiftUI

struct StatusActionsToolbar: View {
    let status: Status
    
    @Environment(AppState.self) private var appState
    @Environment(TimelineServiceWrapper.self) private var timelineWrapper
    
    @AppStorage("showQuoteBoost") private var showQuoteBoost = true
    @AppStorage("themeColor") private var themeColorName = "blue"
    
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

    private var themeColor: Color {
        ThemeColor.resolved(from: themeColorName).color
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Reply
            toolbarButton(
                icon: "arrowshape.turn.up.left",
                label: "Reply",
                isActive: false,
                activeColor: themeColor,
                hapticEvent: .action
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
                activeColor: themeColor,
                hapticEvent: .confirmation
            ) {
                await toggleFavorite()
            }

            toolbarButton(
                icon: isBookmarked ? "bookmark.fill" : "bookmark",
                label: "Bookmark",
                isActive: isBookmarked,
                activeColor: themeColor,
                hapticEvent: .confirmation
            ) {
                await toggleBookmark()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .controlSize(.regular)
        .allowsHitTesting(!isProcessing)
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
        hapticEvent: HapticFeedback.Event,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            guard !isProcessing else { return }
            HapticFeedback.play(hapticEvent)
            Task {
                await action()
            }
        } label: {
            toolbarItemLabel(
                icon: icon,
                label: label,
                foreground: isActive ? activeColor : themeColor
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityValue(isActive ? "Active" : "Inactive")
        .accessibilityHint("Double tap to \(label.lowercased())")
    }

    @ViewBuilder
    private func toolbarItemLabel(
        icon: String,
        label: String,
        foreground: Color
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.roundedSubheadline.weight(.semibold))

            Text(label)
                .font(.roundedCaption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 34)
        .foregroundStyle(foreground)
    }
    
    @ViewBuilder
    private var boostToolbarButton: some View {
        if isReblogged {
            // Already boosted - show menu with Unboost option
            Menu {
                Button {
                    HapticFeedback.play(.confirmation)
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Unboost", systemImage: "arrow.2.squarepath")
                }
            } label: {
                toolbarItemLabel(
                    icon: "arrow.2.squarepath",
                    label: "Boost",
                    foreground: themeColor
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Boost")
            .accessibilityValue("Active")
        } else if showQuoteBoost {
            // Not boosted and quote boost enabled - show menu with both options
            Menu {
                Button {
                    HapticFeedback.play(.confirmation)
                    Task {
                        await toggleReblog()
                    }
                } label: {
                    Label("Boost", systemImage: "arrow.2.squarepath")
                }
                
                Button {
                    HapticFeedback.play(.action)
                    appState.present(sheet: .compose(quote: status))
                } label: {
                    Label("Quote Boost", systemImage: "quote.bubble")
                }
            } label: {
                toolbarItemLabel(
                    icon: "arrow.2.squarepath",
                    label: "Boost",
                    foreground: themeColor
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Boost")
        } else {
            // Not boosted and quote boost disabled - show direct button
            toolbarButton(
                icon: "arrow.2.squarepath",
                label: "Boost",
                isActive: false,
                activeColor: themeColor,
                hapticEvent: .confirmation
            ) {
                await toggleReblog()
            }
        }
    }

    private static let actionTimeout: UInt64 = 15_000_000_000 // 15 seconds

    private func toggleFavorite() async {
        guard let service = timelineWrapper.service else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let wasFavorited = isFavorited
        localFavorited = !wasFavorited
        
        do {
            let updated = try await withThrowingTaskGroup(of: Status.self) { group in
                group.addTask {
                    try await service.setFavorite(status: status, isFavorited: !wasFavorited)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.actionTimeout)
                    throw URLError(.timedOut)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
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
            let updated = try await withThrowingTaskGroup(of: Status.self) { group in
                group.addTask {
                    try await service.setReblog(status: status, isReblogged: !wasReblogged)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.actionTimeout)
                    throw URLError(.timedOut)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            localReblogged = updated.displayStatus.reblogged
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
            let updated = try await withThrowingTaskGroup(of: Status.self) { group in
                group.addTask {
                    try await service.bookmark(status: status)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.actionTimeout)
                    throw URLError(.timedOut)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            localBookmarked = updated.bookmarked
        } catch {
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
    .environment(TimelineServiceWrapper())
}

// MARK: - Preview Helper

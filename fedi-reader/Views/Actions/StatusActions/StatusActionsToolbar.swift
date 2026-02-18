import SwiftUI

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
        HStack(spacing: 6) {
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
                    toolbarItemLabel(
                        icon: "tray.and.arrow.down",
                        label: "Save",
                        foreground: .secondary
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: 300)
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
            toolbarItemLabel(
                icon: icon,
                label: label,
                foreground: isActive ? activeColor : .secondary
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
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
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.roundedSubheadline)

            Text(label)
                .font(.roundedCaption2)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 4)
        .foregroundStyle(foreground)
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
                toolbarItemLabel(
                    icon: "arrow.2.squarepath",
                    label: "Boost",
                    foreground: .green
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
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
                toolbarItemLabel(
                    icon: "arrow.2.squarepath",
                    label: "Boost",
                    foreground: .secondary
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
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
            let updated = try await service.bookmark(status: status)
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
    .environment(ReadLaterManager())
    .environment(TimelineServiceWrapper())
}

// MARK: - Preview Helper



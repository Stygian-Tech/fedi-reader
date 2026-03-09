import SwiftUI

enum TabOrderVisibilityControlStyle: Equatable {
    case hideEnabled
    case hideDisabled
    case showEnabled
}

enum TabOrderMoveResult: Equatable {
    case allowed(visibleTabs: [AppTab])
    case denied(tabs: [AppTab], previewVisibleTabs: [AppTab])
}

private struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

enum TabOrderSettingsFeatures {
    private static let compactPrimaryTabCountBeforeMore = 4
    private static let compactVisibleTabLimitBeforeMore = 5
    private static let protectedTabsBeforeMore: Set<AppTab> = [.links, .profile]
    static let defaultEditMode: EditMode = .inactive
    static let deniedMoveFeedbackDelay: TimeInterval = 0.18
    /// Duration of the shake animation; snap-back runs when this animation completes.
    static let shakeAnimationDuration: TimeInterval = 0.35

    static func tabsBehindMore(in visibleTabs: [AppTab]) -> [AppTab] {
        guard visibleTabs.count > compactVisibleTabLimitBeforeMore else { return [] }
        return Array(visibleTabs.dropFirst(compactPrimaryTabCountBeforeMore))
    }

    static func visibilityControlStyle(for tab: AppTab, isVisible: Bool) -> TabOrderVisibilityControlStyle {
        if isVisible {
            return tab == .links || tab == .profile ? .hideDisabled : .hideEnabled
        }

        return .showEnabled
    }

    static func deniedVisibilityChangeTabs(for tab: AppTab, isVisible: Bool) -> [AppTab] {
        guard !isVisible, protectedTabsBeforeMore.contains(tab) else { return [] }
        return [tab]
    }

    static func moveResult(visibleTabs: [AppTab], fromOffsets: IndexSet, toOffset: Int) -> TabOrderMoveResult {
        let proposedVisibleTabs = movedTabs(
            visibleTabs,
            fromOffsets: fromOffsets,
            toOffset: toOffset
        )
        let deniedTabs = tabsBehindMore(in: proposedVisibleTabs).filter { protectedTabsBeforeMore.contains($0) }

        if deniedTabs.isEmpty {
            return .allowed(visibleTabs: proposedVisibleTabs)
        }

        return .denied(tabs: deniedTabs, previewVisibleTabs: proposedVisibleTabs)
    }

    private static func movedTabs(_ tabs: [AppTab], fromOffsets: IndexSet, toOffset: Int) -> [AppTab] {
        var movedTabs = tabs
        let movingItems = fromOffsets.map { movedTabs[$0] }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        for offset in fromOffsets.sorted(by: >) {
            movedTabs.remove(at: offset)
        }
        let adjustedOffset = max(0, min(movedTabs.count, toOffset - removedBeforeDestination))
        movedTabs.insert(contentsOf: movingItems, at: adjustedOffset)
        return movedTabs
    }
}

struct TabOrderSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var editMode: EditMode = TabOrderSettingsFeatures.defaultEditMode
    @State private var deniedMoveAttempts: [AppTab: Int] = [:]
    @State private var previewVisibleTabs: [AppTab]? = nil
    @AppStorage("hapticFeedback") private var hapticFeedback = true

    private var visibleTabs: [AppTab] {
        previewVisibleTabs ?? appState.resolvedVisibleTabs()
    }

    private var hiddenTabs: [AppTab] {
        appState.resolvedHiddenTabs()
    }

    private var tabsBehindMore: Set<AppTab> {
        Set(TabOrderSettingsFeatures.tabsBehindMore(in: visibleTabs))
    }

    var body: some View {
        List {
            Section {
                Label("Home and Profile always stay visible in the main tab bar and never move behind More.", systemImage: "rectangle.3.group.fill")
                    .foregroundStyle(.secondary)
            }

            Section("Visible") {
                ForEach(visibleTabs) { tab in
                    tabVisibilityRow(for: tab, isVisible: true)
                }
                .onMove(perform: moveVisibleTabs)
            }

            Section("Hidden") {
                if hiddenTabs.isEmpty {
                    Text("No hidden tabs.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(hiddenTabs) { tab in
                        tabVisibilityRow(for: tab, isVisible: false)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Tab Order")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tabVisibilityRow(for tab: AppTab, isVisible: Bool) -> some View {
        let controlStyle = TabOrderSettingsFeatures.visibilityControlStyle(for: tab, isVisible: isVisible)

        return HStack(spacing: 12) {
            Label(tab.title, systemImage: tab.systemImage)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .trailing) {
            HStack(spacing: 8) {
                if isVisible, tabsBehindMore.contains(tab) {
                    Label("In More", systemImage: "ellipsis.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch controlStyle {
                case .hideEnabled, .showEnabled:
                    Button {
                        appState.setTabVisibility(tab, isVisible: !isVisible)
                    } label: {
                        Image(systemName: controlStyle == .showEnabled ? "plus.circle" : "minus.circle")
                            .foregroundStyle(controlStyle == .showEnabled ? Color.accentColor : Color.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isVisible ? "Hide \(tab.title)" : "Show \(tab.title)")
                case .hideDisabled:
                    Button {
                        triggerDeniedFeedback(for: [tab])
                    } label: {
                        Image(systemName: "minus.circle")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.title) is always visible")
                }
            }
        }
        .modifier(ShakeEffect(animatableData: CGFloat(deniedMoveAttempts[tab] ?? 0)))
    }

    private func moveVisibleTabs(fromOffsets: IndexSet, toOffset: Int) {
        switch TabOrderSettingsFeatures.moveResult(
            visibleTabs: visibleTabs,
            fromOffsets: fromOffsets,
            toOffset: toOffset
        ) {
        case .allowed:
            appState.moveTabs(fromOffsets: fromOffsets, toOffset: toOffset)
        case .denied(let tabs, let previewVisibleTabs):
            self.previewVisibleTabs = previewVisibleTabs
            triggerDeniedFeedback(
                for: tabs,
                after: TabOrderSettingsFeatures.deniedMoveFeedbackDelay
            ) {
                withAnimation(.default) {
                    self.previewVisibleTabs = nil
                }
            }
        }
    }

    private func triggerDeniedFeedback(
        for tabs: [AppTab],
        after delay: TimeInterval = 0,
        onShakeComplete: (() -> Void)? = nil
    ) {
        guard !tabs.isEmpty else { return }

        let shakeDuration = TabOrderSettingsFeatures.shakeAnimationDuration

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            HapticFeedback.play(.medium, enabled: hapticFeedback)
            withAnimation(.easeInOut(duration: shakeDuration)) {
                for tab in tabs {
                    deniedMoveAttempts[tab, default: 0] += 1
                }
            } completion: {
                onShakeComplete?()
            }
        }
    }
}

#Preview {
    NavigationStack {
        TabOrderSettingsView()
    }
    .environment(AppState())
}

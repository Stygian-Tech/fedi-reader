import SwiftUI

struct TagView: View {
    let tags: [String]
    let onTagTap: ((String) -> Void)?
    let showAllTags: Bool
    
    @State private var visibleTags: [String] = []
    @State private var hiddenTags: [String] = []
    @State private var tagSizes: [String: CGSize] = [:]
    @State private var availableWidth: CGFloat = 0
    @State private var isExpanded: Bool = false
    
    init(tags: [String], onTagTap: ((String) -> Void)? = nil, showAllTags: Bool = false) {
        self.tags = tags
        self.onTagTap = onTagTap
        self.showAllTags = showAllTags
        // Initialize with all tags visible, will be recalculated when width is known
        _visibleTags = State(initialValue: tags)
    }
    
    var body: some View {
        if !tags.isEmpty {
            if showAllTags {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        LiquidGlassTag(tag) {
                            onTagTap?(tag)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FlowLayout(spacing: 8) {
                    if isExpanded {
                        expandedTagsContent
                    } else {
                        collapsedTagsContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: isExpanded ? nil : 32, alignment: .topLeading)
                .clipped()
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: TagContainerWidthPreferenceKey.self, value: geometry.size.width)
                    }
                }
                .onPreferenceChange(TagContainerWidthPreferenceKey.self) { width in
                    guard width > 0 else { return }
                    let hasWidthChanged = abs(width - availableWidth) > 0.5
                    guard hasWidthChanged else { return }

                    availableWidth = width
                    if !isExpanded {
                        calculateVisibleTags(availableWidth: width)
                    }
                }
                .onAppear {
                    if !isExpanded {
                        calculateVisibleTags(availableWidth: availableWidth)
                    }
                }
                .onChange(of: tagSizes) { oldSizes, newSizes in
                    if !isExpanded && newSizes.count > oldSizes.count {
                        calculateVisibleTags(availableWidth: availableWidth)
                    }
                }
                .onChange(of: isExpanded) { _, newValue in
                    if !newValue {
                        calculateVisibleTags(availableWidth: availableWidth)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }

    private struct TagContainerWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            let candidate = nextValue()
            if candidate > 0 {
                value = candidate
            }
        }
    }

    private var collapsedTagsContent: some View {
        Group {
            ForEach(visibleTags, id: \.self) { tag in
                TagSizeReader(tag: tag) { size in
                    tagSizes[tag] = size
                } content: {
                    LiquidGlassTag(tag) {
                        onTagTap?(tag)
                    }
                }
            }

            if !hiddenTags.isEmpty {
                LiquidGlassTag("+\(hiddenTags.count)") {
                    withAnimation {
                        isExpanded = true
                    }
                }
            }
        }
    }

    private var expandedTagsContent: some View {
        Group {
            ForEach(tags, id: \.self) { tag in
                LiquidGlassTag(tag) {
                    onTagTap?(tag)
                }
            }

            lessButton
        }
    }
    
    private var lessButton: some View {
        Button {
            withAnimation {
                isExpanded = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.roundedCaption2)
                Text("Show less")
                    .font(.roundedCaption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
            }
            .overlay {
                Capsule()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func calculateVisibleTags(availableWidth: CGFloat) {
        let partition = TagView.partitionTags(
            tags,
            availableWidth: availableWidth,
            measuredTagSizes: tagSizes
        )
        visibleTags = partition.visible
        hiddenTags = partition.hidden
    }

    nonisolated static func partitionTags(
        _ tags: [String],
        availableWidth: CGFloat,
        measuredTagSizes: [String: CGSize],
        spacing: CGFloat = 8,
        moreButtonWidth: CGFloat = 50
    ) -> (visible: [String], hidden: [String]) {
        guard availableWidth > 0 else {
            return (tags, [])
        }

        var currentWidth: CGFloat = 0
        var visible: [String] = []
        var hidden: [String] = []

        for tag in tags {
            let tagWidth = measuredTagSizes[tag]?.width ?? CGFloat(tag.count * 7 + 20)
            let needsMoreButton = !hidden.isEmpty || (
                currentWidth + tagWidth + spacing + moreButtonWidth > availableWidth &&
                currentWidth > 0
            )

            if currentWidth + tagWidth + spacing <= availableWidth && !needsMoreButton {
                visible.append(tag)
                currentWidth += tagWidth + spacing
            } else {
                hidden.append(tag)
            }
        }

        if visible.isEmpty, let firstTag = tags.first {
            return ([firstTag], Array(tags.dropFirst()))
        }

        return (visible, hidden)
    }
}

// MARK: - Tag Size Reader

private struct TagSizeReader<Content: View>: View {
    let tag: String
    let onSizeChange: (CGSize) -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: TagSizePreferenceKey.self, value: [tag: geometry.size])
                }
            )
            .onPreferenceChange(TagSizePreferenceKey.self) { sizes in
                if let size = sizes[tag] {
                    onSizeChange(size)
                }
            }
    }
}

private struct TagSizePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGSize] = [:]
    
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Tag Extraction Helper



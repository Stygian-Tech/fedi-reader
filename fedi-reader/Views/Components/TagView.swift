//
//  TagView.swift
//  fedi-reader
//
//  Tag display component with liquid glass styling
//

import SwiftUI
import os

// MARK: - Tag View

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

struct TagExtractor {
    nonisolated static func deduplicateCaseInsensitive(_ tags: [String]) -> [String] {
        var seenCanonicalTags = Set<String>()
        var deduplicatedTags: [String] = []
        deduplicatedTags.reserveCapacity(tags.count)

        for tag in tags {
            let canonicalTag = tag.lowercased()
            if seenCanonicalTags.insert(canonicalTag).inserted {
                deduplicatedTags.append(tag)
            }
        }

        return deduplicatedTags.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    /// Extract tags from status content (hashtags)
    nonisolated static func extractTags(from content: String) -> [String] {
        // Strip HTML first to avoid matching HTML entities like &#39; as #39
        let plainText = HTMLParser.stripHTML(content)
        
        // Extract hashtags from plain text
        // Pattern requires at least one letter to avoid pure number tags
        let pattern = #"#([a-zA-Z][\w]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(plainText.startIndex..., in: plainText)
        let matches = regex.matches(in: plainText, options: [], range: range)
        
        var tags: [String] = []
        var seenCanonicalTags = Set<String>()
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: plainText) {
                let tag = String(plainText[tagRange])
                let canonicalTag = tag.lowercased()
                // Additional safety: filter out tags that are pure numbers (shouldn't happen with pattern, but just in case)
                if !tag.allSatisfy(\.isNumber) && seenCanonicalTags.insert(canonicalTag).inserted {
                    tags.append(tag)
                }
            }
        }
        
        return tags
    }
    
    /// Extract tags from status, checking multiple sources
    nonisolated static func extractTags(from status: Status) -> [String] {
        var tags: [String] = []

        // Prefer hashtag casing from the rendered post content when available.
        tags.append(contentsOf: extractTags(from: status.displayStatus.content))

        // Include API hashtags as a fallback source for tags missing from content.
        tags.append(contentsOf: status.displayStatus.tags.map(\.name))

        return deduplicateCaseInsensitive(tags)
    }
}

// MARK: - Preview

#Preview("Tag View") {
    VStack(spacing: 20) {
        TagView(tags: ["semantic search", "chat with notes", "auto-tagging", "encrypted"]) { tag in
            Logger(subsystem: "app.fedi-reader", category: "TagView").debug("Tapped: \(tag)")
        }
        
        TagView(tags: TagExtractor.extractTags(from: "Check out #swiftui #ios #design #glassmorphism"))
    }
    .padding()
    .background(Color.black)
}

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
    
    @State private var visibleTags: [String] = []
    @State private var hiddenTags: [String] = []
    @State private var tagSizes: [String: CGSize] = [:]
    @State private var isExpanded: Bool = false
    
    init(tags: [String], onTagTap: ((String) -> Void)? = nil) {
        self.tags = tags
        self.onTagTap = onTagTap
        // Initialize with all tags visible, will be recalculated when width is known
        _visibleTags = State(initialValue: tags)
    }
    
    var body: some View {
        if !tags.isEmpty {
            GeometryReader { geometry in
                FlowLayout(spacing: 8) {
                    if isExpanded {
                        // Show all tags when expanded
                        ForEach(tags, id: \.self) { tag in
                            LiquidGlassTag(tag) {
                                onTagTap?(tag)
                            }
                        }
                        
                        // "Less" button to collapse - styled distinctly from tags
                        lessButton
                    } else {
                        // Collapsed state: show visible tags + count button
                        ForEach(visibleTags, id: \.self) { tag in
                            TagSizeReader(tag: tag) { size in
                                tagSizes[tag] = size
                            } content: {
                                LiquidGlassTag(tag) {
                                    onTagTap?(tag)
                                }
                            }
                        }
                        
                        // Show count of hidden tags only
                        if !hiddenTags.isEmpty {
                            LiquidGlassTag("+\(hiddenTags.count)") {
                                withAnimation {
                                    isExpanded = true
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    if !isExpanded {
                        calculateVisibleTags(availableWidth: geometry.size.width)
                    }
                }
                .onChange(of: geometry.size.width) { oldWidth, newWidth in
                    if !isExpanded && newWidth != oldWidth && newWidth > 0 {
                        calculateVisibleTags(availableWidth: newWidth)
                    }
                }
                .onChange(of: tagSizes) { oldSizes, newSizes in
                    if !isExpanded && newSizes.count > oldSizes.count {
                        calculateVisibleTags(availableWidth: geometry.size.width)
                    }
                }
                .onChange(of: isExpanded) { oldValue, newValue in
                    // Recalculate when collapsing
                    if !newValue {
                        calculateVisibleTags(availableWidth: geometry.size.width)
                    }
                }
            }
            .frame(height: isExpanded ? nil : 32) // Fixed height when collapsed, natural height when expanded
            .fixedSize(horizontal: false, vertical: !isExpanded)
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
        guard availableWidth > 0 else {
            // If width not available yet, show all tags initially
            visibleTags = tags
            hiddenTags = []
            return
        }
        
        var currentWidth: CGFloat = 0
        var visible: [String] = []
        var hidden: [String] = []
        let spacing: CGFloat = 8
        let moreButtonWidth: CGFloat = 50 // Approximate width for "+X" button
        
        for tag in tags {
            // Use measured size if available, otherwise estimate
            let tagWidth: CGFloat
            if let size = tagSizes[tag] {
                tagWidth = size.width
            } else {
                // Estimate: ~7-8px per character + 20px padding
                tagWidth = CGFloat(tag.count * 7 + 20)
            }
            
            // Check if we need the "more" button
            let needsMoreButton = !hidden.isEmpty || (currentWidth + tagWidth + spacing + moreButtonWidth > availableWidth && currentWidth > 0)
            
            if currentWidth + tagWidth + spacing <= availableWidth && !needsMoreButton {
                visible.append(tag)
                currentWidth += tagWidth + spacing
            } else {
                hidden.append(tag)
            }
        }
        
        visibleTags = visible
        hiddenTags = hidden
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
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: plainText) {
                let tag = String(plainText[tagRange])
                // Additional safety: filter out tags that are pure numbers (shouldn't happen with pattern, but just in case)
                if !tag.allSatisfy(\.isNumber) && !tags.contains(tag) {
                    tags.append(tag)
                }
            }
        }
        
        return tags
    }
    
    /// Extract tags from status, checking multiple sources
    static func extractTags(from status: Status) -> [String] {
        var tags: [String] = []
        
        // Prefer API hashtags when available
        tags.append(contentsOf: status.displayStatus.tags.map(\.name))
        
        // Fall back to content extraction
        tags.append(contentsOf: extractTags(from: status.displayStatus.content))
        
        return Array(Set(tags)).sorted() // Remove duplicates and sort
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

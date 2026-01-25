//
//  TagView.swift
//  fedi-reader
//
//  Tag display component with liquid glass styling
//

import SwiftUI

// MARK: - Tag View

struct TagView: View {
    let tags: [String]
    let onTagTap: ((String) -> Void)?
    
    init(tags: [String], onTagTap: ((String) -> Void)? = nil) {
        self.tags = tags
        self.onTagTap = onTagTap
    }
    
    var body: some View {
        if !tags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    LiquidGlassTag(tag) {
                        onTagTap?(tag)
                    }
                }
            }
        }
    }
}

// MARK: - Tag Extraction Helper

struct TagExtractor {
    /// Extract tags from status content (hashtags)
    static func extractTags(from content: String) -> [String] {
        // Extract hashtags from HTML content
        let pattern = #"#(\w+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        var tags: [String] = []
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: content) {
                let tag = String(content[tagRange])
                if !tags.contains(tag) {
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
            print("Tapped: \(tag)")
        }
        
        TagView(tags: TagExtractor.extractTags(from: "Check out #swiftui #ios #design #glassmorphism"))
    }
    .padding()
    .background(Color.black)
}

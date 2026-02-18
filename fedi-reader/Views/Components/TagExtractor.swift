import SwiftUI
import os

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

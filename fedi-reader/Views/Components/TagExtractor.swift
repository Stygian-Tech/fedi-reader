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
        let plainText = plainTextForTagExtraction(from: content)
        
        // Extract hashtags from plain text
        // Pattern requires at least one letter and avoids matching URL fragments like /story#section.
        let pattern = #"(?<![\w/])#([a-zA-Z][\w]*)"#
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

    private nonisolated static func plainTextForTagExtraction(from html: String) -> String {
        let linkPattern = #"<a\b[^>]*>(.*?)</a\s*>"#
        guard let regex = try? NSRegularExpression(
            pattern: linkPattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return HTMLParser.stripHTML(html)
        }

        var sanitizedHTML = html
        let range = NSRange(sanitizedHTML.startIndex..., in: sanitizedHTML)
        let matches = regex.matches(in: sanitizedHTML, options: [], range: range)

        for match in matches.reversed() {
            guard let elementRange = Range(match.range, in: sanitizedHTML),
                  let innerRange = Range(match.range(at: 1), in: sanitizedHTML) else {
                continue
            }

            let anchorHTML = String(sanitizedHTML[elementRange])
            let innerHTML = String(sanitizedHTML[innerRange])
            let replacement = shouldPreserveLinkedHashtag(anchorHTML) ? innerHTML : " "

            sanitizedHTML.replaceSubrange(elementRange, with: replacement)
        }

        return HTMLParser.stripHTML(sanitizedHTML)
    }

    private nonisolated static func shouldPreserveLinkedHashtag(_ anchorHTML: String) -> Bool {
        guard let tagEnd = anchorHTML.firstIndex(of: ">") else {
            return false
        }

        let openingTag = String(anchorHTML[...tagEnd])
        let classNames = attribute(named: "class", in: openingTag)?
            .split(whereSeparator: \.isWhitespace)
            .map { $0.lowercased() } ?? []

        if classNames.contains("hashtag") {
            return true
        }

        guard let rawHref = attribute(named: "href", in: openingTag)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }

        let href = HTMLParser.decodeHTMLEntities(rawHref)
        guard let url = URL(string: href) else {
            return href.lowercased().hasPrefix("/tags/") || href.lowercased().hasPrefix("/tagged/")
        }

        let path = url.path.lowercased()
        return path.hasPrefix("/tags/") || path.hasPrefix("/tagged/")
    }

    private nonisolated static func attribute(named name: String, in tag: String) -> String? {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let pattern = #"\b\#(escapedName)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(tag.startIndex..., in: tag)) else {
            return nil
        }

        for captureIndex in 1...3 {
            if let valueRange = Range(match.range(at: captureIndex), in: tag) {
                return String(tag[valueRange])
            }
        }

        return nil
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

//
//  MessageEmbeddedContentLayoutResolver.swift
//  fedi-reader
//
//  Splits direct-message content around an embedded link so the preview can
//  replace the inline URL while preserving any surrounding text.
//

import Foundation

struct MessageEmbeddedContentLayout: Equatable, Sendable {
    let candidate: MessageLinkPreviewCandidate?
    let leadingContent: String?
    let trailingContent: String?
}

enum MessageEmbeddedContentLayoutResolver {
    nonisolated static func resolve(
        from status: Status,
        hiddenHandles: Set<String>
    ) -> MessageEmbeddedContentLayout {
        guard let candidate = MessageLinkPreviewResolver.resolve(from: status) else {
            return MessageEmbeddedContentLayout(
                candidate: nil,
                leadingContent: nil,
                trailingContent: nil
            )
        }

        if let htmlSegments = splitHTMLContent(status.content, around: candidate.url) {
            return MessageEmbeddedContentLayout(
                candidate: candidate,
                leadingContent: displayableHTMLSegment(htmlSegments.leading, hiddenHandles: hiddenHandles),
                trailingContent: displayableHTMLSegment(htmlSegments.trailing, hiddenHandles: hiddenHandles)
            )
        }

        let plainTextContent = DirectMessageMentionFormatter.stripLeadingMentions(
            from: status.content.htmlToPlainTextPreservingNewlines,
            hiddenHandles: hiddenHandles
        )

        if let plainTextSegments = splitPlainTextContent(plainTextContent, around: candidate.url) {
            return MessageEmbeddedContentLayout(
                candidate: candidate,
                leadingContent: displayablePlainTextSegment(plainTextSegments.leading),
                trailingContent: displayablePlainTextSegment(plainTextSegments.trailing)
            )
        }

        return MessageEmbeddedContentLayout(
            candidate: candidate,
            leadingContent: nil,
            trailingContent: nil
        )
    }

    private nonisolated static func splitHTMLContent(
        _ html: String,
        around url: URL
    ) -> (leading: String, trailing: String)? {
        let pattern = #"<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>.*?</a>"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, options: [], range: range) {
            guard let elementRange = Range(match.range, in: html),
                  let hrefRange = Range(match.range(at: 1), in: html) else {
                continue
            }

            let href = HTMLParser.decodeHTMLEntities(String(html[hrefRange]))
            guard let candidateURL = URL(string: href), urlsMatch(candidateURL, url) else {
                continue
            }

            return (
                leading: String(html[..<elementRange.lowerBound]),
                trailing: String(html[elementRange.upperBound...])
            )
        }

        return nil
    }

    private nonisolated static func splitPlainTextContent(
        _ text: String,
        around url: URL
    ) -> (leading: String, trailing: String)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return splitPlainTextContentByLiteralMatch(text, around: url)
        }

        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, options: [], range: range) {
            guard let detectedURL = match.url,
                  urlsMatch(detectedURL, url),
                  let matchRange = Range(match.range, in: text) else {
                continue
            }

            return (
                leading: String(text[..<matchRange.lowerBound]),
                trailing: String(text[matchRange.upperBound...])
            )
        }

        return splitPlainTextContentByLiteralMatch(text, around: url)
    }

    private nonisolated static func splitPlainTextContentByLiteralMatch(
        _ text: String,
        around url: URL
    ) -> (leading: String, trailing: String)? {
        guard let range = text.range(of: url.absoluteString) else {
            return nil
        }

        return (
            leading: String(text[..<range.lowerBound]),
            trailing: String(text[range.upperBound...])
        )
    }

    private nonisolated static func displayableHTMLSegment(
        _ content: String,
        hiddenHandles: Set<String>
    ) -> String? {
        let visibleText = DirectMessageMentionFormatter.stripLeadingMentions(
            from: content.htmlToPlainTextPreservingNewlines,
            hiddenHandles: hiddenHandles
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !visibleText.isEmpty else { return nil }
        return content
    }

    private nonisolated static func displayablePlainTextSegment(_ content: String) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private nonisolated static func urlsMatch(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.absoluteString == rhs.absoluteString
            || lhs.standardized.absoluteString == rhs.standardized.absoluteString
    }
}

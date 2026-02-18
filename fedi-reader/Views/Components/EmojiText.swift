//
//  EmojiText.swift
//  fedi-reader
//
//  Renders plain text with :shortcode: replaced by custom emoji images.
//

import SwiftUI

/// Renders text that may contain Mastodon-style :shortcode: with inline custom emoji images.
struct EmojiText: View {
    let text: String
    let emojis: [CustomEmoji]
    let font: Font?

    private static let shortcodePattern = #":([a-zA-Z0-9_+-]+):"#
    private static let emojiHeight: CGFloat = 20

    init(text: String, emojis: [CustomEmoji], font: Font? = nil) {
        self.text = text
        self.emojis = emojis
        self.font = font
    }

    private var lookup: [String: CustomEmoji] {
        Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
    }

    private var segments: [Segment] {
        Self.parse(text: text, lookup: lookup)
    }

    var body: some View {
        if emojis.isEmpty {
            textView(text)
        } else {
            let segs = segments
            if segs.count == 1, case .text(let s) = segs[0], !s.isEmpty {
                textView(s)
            } else {
                HStack(alignment: .center, spacing: 2) {
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, segment in
                        segmentView(segment)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func textView(_ string: String) -> some View {
        if let font {
            Text(string)
                .font(font)
        } else {
            Text(string)
        }
    }

    @ViewBuilder
    private func segmentView(_ segment: Segment) -> some View {
        switch segment {
        case .text(let s):
            if let font {
                Text(s)
                    .font(font)
            } else {
                Text(s)
            }
        case .emoji(let emoji):
            if let url = URL(string: emoji.url),
               (url.scheme == "https" || url.scheme == "http") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Text(":\(emoji.shortcode):")
                            .font(font ?? .body)
                    case .empty:
                        Text(":\(emoji.shortcode):")
                            .font(font ?? .body)
                    @unknown default:
                        Text(":\(emoji.shortcode):")
                            .font(font ?? .body)
                    }
                }
                .frame(height: Self.emojiHeight)
            } else {
                Text(":\(emoji.shortcode):")
                    .font(font ?? .body)
            }
        }
    }

    private enum Segment: Sendable {
        case text(String)
        case emoji(CustomEmoji)
    }

    private static func parse(text: String, lookup: [String: CustomEmoji]) -> [Segment] {
        guard let regex = try? NSRegularExpression(pattern: shortcodePattern, options: []),
              !lookup.isEmpty else {
            return [.text(text)]
        }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        if matches.isEmpty {
            return [.text(text)]
        }
        var segments: [Segment] = []
        var lastEnd = text.startIndex
        for match in matches {
            guard let fullRange = Range(match.range, in: text),
                  let shortcodeRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            let before = String(text[lastEnd..<fullRange.lowerBound])
            if !before.isEmpty {
                segments.append(.text(before))
            }
            let shortcode = String(text[shortcodeRange])
            if shortcode.count <= 50, let emoji = lookup[shortcode] {
                segments.append(.emoji(emoji))
            } else {
                segments.append(.text(String(text[fullRange])))
            }
            lastEnd = fullRange.upperBound
        }
        let remainder = String(text[lastEnd...])
        if !remainder.isEmpty {
            segments.append(.text(remainder))
        }
        return segments.isEmpty ? [.text(text)] : segments
    }

    // MARK: - Test support

    /// Returns segment contents for unit testing: (content, isEmoji).
    internal static func segmentsForTesting(text: String, emojis: [CustomEmoji]) -> [(String, Bool)] {
        let lookup = Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
        let segs = parse(text: text, lookup: lookup)
        return segs.map { segment in
            switch segment {
            case .text(let s): return (s, false)
            case .emoji(let e): return (e.shortcode, true)
            }
        }
    }
}

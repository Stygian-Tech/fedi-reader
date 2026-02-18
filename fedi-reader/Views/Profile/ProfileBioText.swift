//
//  ProfileBioText.swift
//  fedi-reader
//
//  Inline profile bio renderer with hashtag navigation.
//

import SwiftUI
import os

@available(iOS 15.0, macOS 12.0, *)
struct ProfileBioText: View {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "ProfileBioText")

    let content: String
    var emojis: [CustomEmoji] = []

    @Environment(AppState.self) private var appState
    @AppStorage("themeColor") private var themeColorName = "blue"

    private var themeColor: Color {
        ThemeColor(rawValue: themeColorName)?.color ?? .blue
    }

    var body: some View {
        let attributedBio = makeAttributedBio(from: content)

        #if os(iOS)
        if #available(iOS 16.0, *) {
            Text(attributedBio)
                .environment(\.openURL, OpenURLAction { url in
                    handleLinkTap(url)
                })
        } else {
            Text(attributedBio)
        }
        #else
        Text(attributedBio)
            .environment(\.openURL, OpenURLAction { url in
                handleLinkTap(url)
            })
        #endif
    }

    private func handleLinkTap(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "hashtag" else {
            return .systemAction
        }

        let tag = url.host ?? url.pathComponents.last ?? ""
        guard !tag.isEmpty else {
            Self.logger.warning("Hashtag URL missing tag identifier")
            return .discarded
        }

        appState.navigate(to: .hashtag(tag))
        return .handled
    }

    private func makeAttributedBio(from content: String) -> AttributedString {
        let emojiLookup: [String: CustomEmoji]? = emojis.isEmpty ? nil : Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
        var attributedBio = HTMLParser.convertToAttributedString(
            content,
            preserveNewlines: true,
            hashtagHandler: { tag in
                URL(string: "hashtag://\(tag)")
            },
            emojiLookup: emojiLookup
        )

        applyThemeColorToHashtags(in: &attributedBio)
        return attributedBio
    }

    private func applyThemeColorToHashtags(in attributedBio: inout AttributedString) {
        let plainText = String(attributedBio.characters)
        let hashtagPattern = #"#[\w]+"#

        guard let regex = try? NSRegularExpression(pattern: hashtagPattern, options: []) else {
            return
        }

        let textRange = NSRange(plainText.startIndex..., in: plainText)
        let matches = regex.matches(in: plainText, options: [], range: textRange)

        for match in matches {
            guard let hashtagRange = Range(match.range, in: plainText),
                  let start = AttributedString.Index(hashtagRange.lowerBound, within: attributedBio),
                  let end = AttributedString.Index(hashtagRange.upperBound, within: attributedBio),
                  start < end else {
                continue
            }

            attributedBio[start..<end].foregroundColor = themeColor
        }
    }
}

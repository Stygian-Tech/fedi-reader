//
//  HashtagLinkText.swift
//  fedi-reader
//
//  Text view that handles hashtag links
//

import SwiftUI
import os

@available(iOS 15.0, macOS 12.0, *)
struct HashtagLinkText: View {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "HashtagLinkText")
    
    let content: String
    let onHashtagTap: (String) -> Void
    @Environment(AppState.self) private var appState
    
    var body: some View {
        // Get emoji lookup from emoji service
        let emojiLookup: [String: CustomEmoji] = {
            if let instance = appState.getCurrentInstance() {
                let emojis = appState.emojiService.getCustomEmojis(for: instance)
                let lookup = Dictionary(uniqueKeysWithValues: emojis.map { ($0.shortcode, $0) })
                Self.logger.debug("Built emoji lookup with \(lookup.count) entries for instance: \(instance, privacy: .public)")
                return lookup
            } else {
                Self.logger.debug("No current instance available for emoji lookup")
                return [:]
            }
        }()
        
        let attributedString = HTMLParser.convertToAttributedString(content, hashtagHandler: { tag in
            // Return a custom URL that we can detect
            guard let url = URL(string: "hashtag://\(tag)") else {
                Self.logger.warning("Failed to create hashtag URL for tag: \(tag, privacy: .public)")
                return nil
            }
            return url
        }, emojiLookup: emojiLookup)
        
        #if os(iOS)
        if #available(iOS 16.0, *) {
            Text(attributedString)
                .accessibilityLabel("Post content with hashtags")
                .accessibilityHint("Double tap hashtags to view related posts")
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "hashtag" {
                        let tag = url.host ?? url.pathComponents.last ?? ""
                        if !tag.isEmpty {
                            Self.logger.debug("Hashtag tapped: \(tag, privacy: .public)")
                            onHashtagTap(tag)
                            return .handled
                        } else {
                            Self.logger.warning("Hashtag URL missing tag identifier")
                        }
                    }
                    return .systemAction
                })
        } else {
            // For iOS 15, use a simpler approach
            Text(attributedString)
                .accessibilityLabel("Post content with hashtags")
                .accessibilityHint("Double tap hashtags to view related posts")
                .onTapGesture {
                    // Extract hashtags and make them tappable
                    // This is a fallback - links in AttributedString should still work
                }
        }
        #else
        Text(attributedString)
            .accessibilityLabel("Post content with hashtags")
            .accessibilityHint("Double tap hashtags to view related posts")
        #endif
    }
}

//
//  HashtagLinkText.swift
//  fedi-reader
//
//  Text view that handles hashtag links
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct HashtagLinkText: View {
    let content: String
    let onHashtagTap: (String) -> Void
    
    var body: some View {
        let attributedString = HTMLParser.convertToAttributedString(content) { tag in
            // Return a custom URL that we can detect
            URL(string: "hashtag://\(tag)")
        }
        
        #if os(iOS)
        if #available(iOS 16.0, *) {
            Text(attributedString)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "hashtag" {
                        let tag = url.host ?? url.pathComponents.last ?? ""
                        onHashtagTap(tag)
                        return .handled
                    }
                    return .systemAction
                })
        } else {
            // For iOS 15, use a simpler approach
            Text(attributedString)
                .onTapGesture {
                    // Extract hashtags and make them tappable
                    // This is a fallback - links in AttributedString should still work
                }
        }
        #else
        Text(attributedString)
        #endif
    }
}

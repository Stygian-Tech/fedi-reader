//
//  FontExtensions.swift
//  fedi-reader
//
//  Font extensions for SF Rounded
//

import SwiftUI

extension Font {
    /// SF Rounded font variants
    static func rounded(_ style: TextStyle) -> Font {
        .system(style, design: .rounded)
    }
    
    static func rounded(size: CGFloat, weight: Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    
    // Convenience methods for common text styles
    static var roundedLargeTitle: Font {
        .rounded(.largeTitle)
    }
    
    static var roundedTitle: Font {
        .rounded(.title)
    }
    
    static var roundedTitle2: Font {
        .rounded(.title2)
    }
    
    static var roundedTitle3: Font {
        .rounded(.title3)
    }
    
    static var roundedHeadline: Font {
        .rounded(.headline)
    }
    
    static var roundedBody: Font {
        .rounded(.body)
    }
    
    static var roundedCallout: Font {
        .rounded(.callout)
    }
    
    static var roundedSubheadline: Font {
        .rounded(.subheadline)
    }
    
    static var roundedFootnote: Font {
        .rounded(.footnote)
    }
    
    static var roundedCaption: Font {
        .rounded(.caption)
    }
    
    static var roundedCaption2: Font {
        .rounded(.caption2)
    }
}

extension View {
    /// Apply SF Rounded font to the view
    func roundedFont(_ style: Font.TextStyle) -> some View {
        self.font(.rounded(style))
    }
}

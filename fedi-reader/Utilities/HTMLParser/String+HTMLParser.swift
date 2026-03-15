import Foundation

extension String {
    nonisolated var htmlStripped: String {
        HTMLParser.stripHTML(self)
    }
    
    nonisolated var htmlToPlainText: String {
        HTMLParser.convertToPlainText(self)
    }

    nonisolated var htmlToPlainTextPreservingNewlines: String {
        HTMLParser.convertToPlainTextPreservingNewlines(self)
    }
    
    nonisolated var extractedLinks: [URL] {
        HTMLParser.extractLinks(from: self)
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    nonisolated var htmlToAttributedString: AttributedString {
        HTMLParser.convertToAttributedString(self)
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    nonisolated func htmlToAttributedStringWithHashtags(hashtagHandler: @escaping (String) -> URL?) -> AttributedString {
        HTMLParser.convertToAttributedString(self, hashtagHandler: hashtagHandler)
    }

    @available(iOS 15.0, macOS 12.0, *)
    nonisolated func htmlToAttributedStringPreservingNewlinesWithHashtags(hashtagHandler: @escaping (String) -> URL?) -> AttributedString {
        HTMLParser.convertToAttributedString(self, preserveNewlines: true, hashtagHandler: hashtagHandler)
    }
}

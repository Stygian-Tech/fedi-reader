import Foundation

extension String {
    var htmlStripped: String {
        HTMLParser.stripHTML(self)
    }
    
    var htmlToPlainText: String {
        HTMLParser.convertToPlainText(self)
    }

    var htmlToPlainTextPreservingNewlines: String {
        HTMLParser.convertToPlainTextPreservingNewlines(self)
    }
    
    var extractedLinks: [URL] {
        HTMLParser.extractLinks(from: self)
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    var htmlToAttributedString: AttributedString {
        HTMLParser.convertToAttributedString(self)
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    func htmlToAttributedStringWithHashtags(hashtagHandler: @escaping (String) -> URL?) -> AttributedString {
        HTMLParser.convertToAttributedString(self, hashtagHandler: hashtagHandler)
    }

    @available(iOS 15.0, macOS 12.0, *)
    func htmlToAttributedStringPreservingNewlinesWithHashtags(hashtagHandler: @escaping (String) -> URL?) -> AttributedString {
        HTMLParser.convertToAttributedString(self, preserveNewlines: true, hashtagHandler: hashtagHandler)
    }
}


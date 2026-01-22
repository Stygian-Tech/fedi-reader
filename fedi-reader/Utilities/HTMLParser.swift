//
//  HTMLParser.swift
//  fedi-reader
//
//  HTML content parsing and link extraction
//

import Foundation

struct HTMLParser: Sendable {
    
    // MARK: - Link Extraction
    
    /// Extracts all URLs from HTML content
    static func extractLinks(from html: String) -> [URL] {
        // Match href attributes in anchor tags
        let pattern = #"<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: range)
        
        var urls: [URL] = []
        
        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: html) else { continue }
            let urlString = String(html[urlRange])
            
            // Decode HTML entities
            let decodedURL = decodeHTMLEntities(urlString)
            
            if let url = URL(string: decodedURL), isExternalURL(url) {
                urls.append(url)
            }
        }
        
        return urls
    }
    
    /// Extracts external links (excludes Mastodon internal links like mentions and hashtags)
    static func extractExternalLinks(from html: String, excludingDomains domains: [String] = []) -> [URL] {
        extractLinks(from: html).filter { url in
            guard let host = url.host?.lowercased() else { return false }
            
            // Exclude common Mastodon internal link patterns
            let isMentionOrTag = url.path.hasPrefix("/@") || url.path.hasPrefix("/tags/")
            if isMentionOrTag { return false }
            
            // Exclude specified domains
            for domain in domains {
                if host.contains(domain.lowercased()) { return false }
            }
            
            return true
        }
    }
    
    // MARK: - HTML to Plain Text
    
    /// Converts HTML to plain text, stripping all tags
    static func stripHTML(_ html: String) -> String {
        var result = html
        
        // Replace common block elements with newlines
        let blockElements = ["</p>", "</div>", "</br>", "<br>", "<br/>", "<br />"]
        for element in blockElements {
            result = result.replacingOccurrences(of: element, with: "\n", options: .caseInsensitive)
        }
        
        // Remove all remaining HTML tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Decode HTML entities
        result = decodeHTMLEntities(result)
        
        // Normalize whitespace
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Converts HTML to attributed text-friendly plain text with some formatting preserved
    static func convertToPlainText(_ html: String) -> String {
        var result = html
        
        // Convert line breaks
        result = result.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<br />", with: "\n", options: .caseInsensitive)
        
        // Convert paragraphs to double newlines
        result = result.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "<p>", with: "", options: .caseInsensitive)
        
        // Remove all other tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Decode HTML entities
        result = decodeHTMLEntities(result)
        
        // Collapse multiple newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - HTML Entity Decoding
    
    static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        
        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}"
        ]
        
        for (entity, character) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        
        // Numeric entities (decimal)
        let decimalPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)
            
            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = Int(result[codeRange]),
                      let scalar = Unicode.Scalar(codePoint) else {
                    break
                }
                
                let character = String(Character(scalar))
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: character)
                searchRange = NSRange(result.startIndex..., in: result)
            }
        }

        // Numeric entities (decimal) without semicolon
        let decimalNoSemicolonPattern = #"&#(\d+)(?!;)"#
        if let regex = try? NSRegularExpression(pattern: decimalNoSemicolonPattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)

            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = Int(result[codeRange]),
                      let scalar = Unicode.Scalar(codePoint) else {
                    break
                }

                let character = String(Character(scalar))
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: character)
                searchRange = NSRange(result.startIndex..., in: result)
            }
        }
        
        // Numeric entities (hexadecimal)
        let hexPattern = #"&#x([0-9A-Fa-f]+);"#
        if let regex = try? NSRegularExpression(pattern: hexPattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)
            
            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = Int(result[codeRange], radix: 16),
                      let scalar = Unicode.Scalar(codePoint) else {
                    break
                }
                
                let character = String(Character(scalar))
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: character)
                searchRange = NSRange(result.startIndex..., in: result)
            }
        }

        // Numeric entities (hexadecimal) without semicolon
        let hexNoSemicolonPattern = #"&#x([0-9A-Fa-f]+)(?!;)"#
        if let regex = try? NSRegularExpression(pattern: hexNoSemicolonPattern, options: []) {
            var searchRange = NSRange(result.startIndex..., in: result)

            while let match = regex.firstMatch(in: result, options: [], range: searchRange) {
                guard let codeRange = Range(match.range(at: 1), in: result),
                      let codePoint = Int(result[codeRange], radix: 16),
                      let scalar = Unicode.Scalar(codePoint) else {
                    break
                }

                let character = String(Character(scalar))
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: character)
                searchRange = NSRange(result.startIndex..., in: result)
            }
        }
        
        return result
    }
    
    // MARK: - URL Helpers
    
    /// Checks if a URL is external (not a relative or javascript URL)
    static func isExternalURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    
    /// Extracts the domain from a URL
    static func extractDomain(from url: URL) -> String? {
        guard let host = url.host else { return nil }
        
        // Remove www. prefix
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        
        return host
    }
    
    // MARK: - Mention and Hashtag Extraction
    
    /// Extracts mentions (@username@instance) from HTML
    static func extractMentions(from html: String) -> [String] {
        let pattern = #"@[\w]+(@[\w.-]+)?"#
        
        let plainText = stripHTML(html)
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(plainText.startIndex..., in: plainText)
        let matches = regex.matches(in: plainText, options: [], range: range)
        
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: plainText) else { return nil }
            return String(plainText[matchRange])
        }
    }
    
    /// Extracts hashtags from HTML
    static func extractHashtags(from html: String) -> [String] {
        let pattern = #"#[\w]+"#
        
        let plainText = stripHTML(html)
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let range = NSRange(plainText.startIndex..., in: plainText)
        let matches = regex.matches(in: plainText, options: [], range: range)
        
        return matches.compactMap { match in
            guard let matchRange = Range(match.range, in: plainText) else { return nil }
            return String(plainText[matchRange])
        }
    }
    
    // MARK: - HTML to AttributedString with Links
    
    /// Converts HTML to AttributedString with clickable links and hashtags
    @available(iOS 15.0, macOS 12.0, *)
    static func convertToAttributedString(_ html: String, hashtagHandler: ((String) -> URL?)? = nil) -> AttributedString {
        let plainText = convertToPlainText(html)
        var attributedString = AttributedString(plainText)
        
        // Extract links with their text content (handles nested tags)
        // Pattern matches: <a href="url">content</a> where content can include nested tags
        let linkPattern = #"<a[^>]+href\s*=\s*["']([^"']+)["'][^>]*>(.*?)</a>"#
        
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return attributedString
        }
        
        let htmlRange = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, options: [], range: htmlRange)
        
        // Process matches in reverse order to maintain correct indices
        for match in matches.reversed() {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            
            let urlString = String(html[urlRange])
            let linkHTML = String(html[textRange])
            
            // Decode URL and link text
            let decodedURL = decodeHTMLEntities(urlString)
            let decodedLinkText = convertToPlainText(linkHTML)
            
            guard let url = URL(string: decodedURL),
                  !decodedLinkText.isEmpty else {
                continue
            }
            
            // Find the link text in the plain text version
            if let plainTextRange = plainText.range(of: decodedLinkText) {
                let attributedRange = AttributedString.Index(plainTextRange.lowerBound, within: attributedString)
                let attributedEnd = AttributedString.Index(plainTextRange.upperBound, within: attributedString)
                
                if let start = attributedRange, let end = attributedEnd {
                    let range = start..<end
                    attributedString[range].link = url
                }
            }
        }
        
        // Extract and link hashtags
        let hashtagPattern = #"#[\w]+"#
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let plainTextRange = NSRange(plainText.startIndex..., in: plainText)
            let hashtagMatches = hashtagRegex.matches(in: plainText, options: [], range: plainTextRange)
            
            // Process in reverse order to maintain indices
            for match in hashtagMatches.reversed() {
                guard let matchRange = Range(match.range, in: plainText) else { continue }
                let hashtag = String(plainText[matchRange])
                
                // Remove # for the tag name
                let tagName = String(hashtag.dropFirst())
                
                // Create URL for hashtag (using custom handler if provided)
                if let url = hashtagHandler?(tagName) ?? URL(string: "fedi-reader://hashtag/\(tagName)") {
                    let attributedRange = AttributedString.Index(matchRange.lowerBound, within: attributedString)
                    let attributedEnd = AttributedString.Index(matchRange.upperBound, within: attributedString)
                    
                    if let start = attributedRange, let end = attributedEnd {
                        let range = start..<end
                        attributedString[range].link = url
                    }
                }
            }
        }
        
        return attributedString
    }
}

// MARK: - String Extension

extension String {
    var htmlStripped: String {
        HTMLParser.stripHTML(self)
    }
    
    var htmlToPlainText: String {
        HTMLParser.convertToPlainText(self)
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
}

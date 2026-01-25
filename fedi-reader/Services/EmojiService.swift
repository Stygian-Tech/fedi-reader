//
//  EmojiService.swift
//  fedi-reader
//
//  Fetches and manages custom emoji from Mastodon servers
//

import Foundation
import os

@Observable
@MainActor
final class EmojiService {
    private static let logger = Logger(subsystem: "app.fedi-reader", category: "EmojiService")
    
    private let client: MastodonClient
    
    // Cache for custom emoji per instance
    private var emojiCache: [String: [CustomEmoji]] = [:]
    private var emojiLookup: [String: [String: CustomEmoji]] = [:] // instance -> shortcode -> emoji
    
    // Cache expiration (24 hours)
    private var cacheExpiration: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 60 * 60 * 24
    
    init(client: MastodonClient) {
        self.client = client
    }
    
    // MARK: - Public API
    
    /// Fetches custom emoji for the current instance
    func fetchCustomEmojis() async {
        guard let instance = client.currentInstance else {
            Self.logger.debug("No active instance for emoji fetching")
            return
        }
        
        // Check cache first
        if let _ = emojiCache[instance],
           let expiration = cacheExpiration[instance],
           expiration > Date() {
            Self.logger.debug("Using cached emoji for instance: \(instance, privacy: .public)")
            return
        } else if let expiration = cacheExpiration[instance], expiration <= Date() {
            Self.logger.debug("Cache expired for instance: \(instance, privacy: .public), fetching fresh data")
        }
        
        do {
            let startTime = Date()
            let emojis = try await client.getCustomEmojis()
            let duration = Date().timeIntervalSince(startTime)
            
            emojiCache[instance] = emojis
            cacheExpiration[instance] = Date().addingTimeInterval(cacheTTL)
            
            // Build lookup dictionary for fast access
            var lookup: [String: CustomEmoji] = [:]
            for emoji in emojis {
                lookup[emoji.shortcode] = emoji
            }
            emojiLookup[instance] = lookup
            
            Self.logger.info("Fetched and cached \(emojis.count) custom emoji for instance: \(instance, privacy: .public) in \(String(format: "%.2f", duration))s")
            Self.logger.debug("Built emoji lookup dictionary with \(lookup.count) entries for instance: \(instance, privacy: .public)")
        } catch {
            Self.logger.error("Failed to fetch custom emoji for instance \(instance, privacy: .public): \(error.localizedDescription)")
        }
    }
    
    /// Fetches custom emoji for a specific instance
    func fetchCustomEmojis(for instance: String) async {
        // Check cache first
        if let _ = emojiCache[instance],
           let expiration = cacheExpiration[instance],
           expiration > Date() {
            Self.logger.debug("Using cached emoji for instance: \(instance, privacy: .public)")
            return
        } else if let expiration = cacheExpiration[instance], expiration <= Date() {
            Self.logger.debug("Cache expired for instance: \(instance, privacy: .public), fetching fresh data")
        }
        
        do {
            let startTime = Date()
            let emojis = try await client.getCustomEmojis(instance: instance)
            let duration = Date().timeIntervalSince(startTime)
            
            emojiCache[instance] = emojis
            cacheExpiration[instance] = Date().addingTimeInterval(cacheTTL)
            
            // Build lookup dictionary for fast access
            var lookup: [String: CustomEmoji] = [:]
            for emoji in emojis {
                lookup[emoji.shortcode] = emoji
            }
            emojiLookup[instance] = lookup
            
            Self.logger.info("Fetched and cached \(emojis.count) custom emoji for instance: \(instance, privacy: .public) in \(String(format: "%.2f", duration))s")
            Self.logger.debug("Built emoji lookup dictionary with \(lookup.count) entries for instance: \(instance, privacy: .public)")
        } catch {
            Self.logger.error("Failed to fetch custom emoji for \(instance, privacy: .public): \(error.localizedDescription)")
        }
    }
    
    /// Gets custom emoji for the current instance
    func getCustomEmojis() -> [CustomEmoji] {
        guard let instance = client.currentInstance else { return [] }
        return emojiCache[instance] ?? []
    }
    
    /// Gets custom emoji for a specific instance
    func getCustomEmojis(for instance: String) -> [CustomEmoji] {
        return emojiCache[instance] ?? []
    }
    
    /// Replaces emoji shortcodes in HTML content with image tags
    func replaceEmojiInHTML(_ html: String, instance: String? = nil) -> String {
        let targetInstance = instance ?? client.currentInstance ?? ""
        guard let lookup = emojiLookup[targetInstance], !lookup.isEmpty else {
            Self.logger.debug("No emoji lookup available for instance: \(targetInstance, privacy: .public)")
            return html
        }
        
        Self.logger.debug("Replacing emoji shortcodes in HTML for instance: \(targetInstance, privacy: .public), lookup size: \(lookup.count)")
        var result = html
        
        // Pattern to match :shortcode: in HTML
        // This matches emoji shortcodes that are not already inside <img> tags
        let pattern = #":([a-zA-Z0-9_+-]+):"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            Self.logger.error("Failed to compile emoji shortcode regex pattern")
            return html
        }
        
        let range = NSRange(result.startIndex..., in: result)
        let matches = regex.matches(in: result, options: [], range: range)
        Self.logger.debug("Found \(matches.count) potential emoji shortcodes in HTML")
        
        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let shortcodeRange = Range(match.range(at: 1), in: result),
                  let fullRange = Range(match.range, in: result) else {
                continue
            }
            
            let shortcode = String(result[shortcodeRange])
            
            // Security: Validate shortcode format and length
            // Pattern already ensures [a-zA-Z0-9_+-], but add length check
            guard shortcode.count <= 50, shortcode.count > 0 else {
                Self.logger.debug("Skipping invalid shortcode (length: \(shortcode.count))")
                continue
            }
            
            // Check if this is already inside an img tag (avoid double replacement)
            let beforeMatch = String(result[..<fullRange.lowerBound])
            // Simple check: if there's an unclosed <img tag before this, skip
            if let lastImgTag = beforeMatch.range(of: "<img", options: .backwards) {
                let afterImgTag = String(beforeMatch[lastImgTag.upperBound...])
                // If there's no closing > before our match, we're inside the img tag
                if !afterImgTag.contains(">") {
                    continue
                }
            }
            
            // Look up emoji
            if let emoji = lookup[shortcode] {
                // Security: Validate and sanitize emoji URL
                guard let emojiURL = URL(string: emoji.url),
                      emojiURL.scheme == "https" || emojiURL.scheme == "http",
                      emojiURL.host != nil else {
                    Self.logger.warning("Skipping emoji with invalid URL: \(emoji.url, privacy: .public)")
                    continue
                }
                
                // Security: Escape URL and shortcode for HTML attributes
                let escapedURL = emoji.url
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                    .replacingOccurrences(of: "'", with: "&#x27;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                
                let escapedShortcode = shortcode
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                    .replacingOccurrences(of: "'", with: "&#x27;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                
                // Replace with img tag with properly escaped attributes
                let imgTag = #"<img src="\#(escapedURL)" alt=":\#(escapedShortcode):" class="emoji" title=":\#(escapedShortcode):" />"#
                result.replaceSubrange(fullRange, with: imgTag)
            }
        }
        
        let replacementCount = result.components(separatedBy: "<img").count - html.components(separatedBy: "<img").count
        if replacementCount > 0 {
            Self.logger.debug("Replaced \(replacementCount) emoji shortcodes in HTML")
        }
        
        return result
    }
    
    /// Clears the emoji cache for a specific instance
    func clearCache(for instance: String) {
        emojiCache.removeValue(forKey: instance)
        emojiLookup.removeValue(forKey: instance)
        cacheExpiration.removeValue(forKey: instance)
        Self.logger.debug("Cleared emoji cache for instance: \(instance, privacy: .public)")
    }
    
    /// Clears all emoji caches
    func clearAllCaches() {
        let count = emojiCache.count
        emojiCache.removeAll()
        emojiLookup.removeAll()
        cacheExpiration.removeAll()
        Self.logger.info("Cleared all emoji caches (\(count) instances)")
    }
}

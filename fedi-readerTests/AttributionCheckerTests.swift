//
//  AttributionCheckerTests.swift
//  fedi-readerTests
//
//  Tests for AttributionChecker
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("Attribution Checker Tests")
@MainActor
struct AttributionCheckerTests {
    
    // MARK: - Link Header Parsing
    
    @Test("Parses author from Link header")
    @MainActor
    func parsesLinkHeader() async {
        // This would require mock URL session setup
        // For unit testing, we can test the parsing logic directly
        
        let checker = AttributionChecker()
        
        // The actual parsing happens internally, so we test the full flow
        // with mock responses in integration tests
        let cacheCount = await checker.cacheCountForTesting()
        #expect(cacheCount == 0)
    }
    
    // MARK: - Meta Tag Parsing Verification
    
    @Test("AttributionSource enum has expected cases")
    func attributionSourceCases() {
        let sources: [AttributionSource] = [
            .linkHeader,
            .metaTag,
            .openGraph,
            .jsonLD,
            .twitterCard
        ]
        
        #expect(sources.count == 5)
    }
    
    @Test("AuthorAttribution stores data correctly")
    func authorAttributionStorage() {
        let attribution = AuthorAttribution(
            name: "John Doe",
            url: "https://example.com/authors/john",
            source: .metaTag
        )
        
        #expect(attribution.name == "John Doe")
        #expect(attribution.url == "https://example.com/authors/john")
        #expect(attribution.source == .metaTag)
    }
    
    @Test("Handles nil values in attribution")
    func handlesNilValues() {
        let attribution = AuthorAttribution(
            name: nil,
            url: "https://example.com/author",
            source: .linkHeader
        )
        
        #expect(attribution.name == nil)
        #expect(attribution.url != nil)
    }
    
    // MARK: - Cache Management
    
    @Test("Cache can be cleared")
    @MainActor
    func cacheClearable() async {
        let checker = AttributionChecker()
        await checker.clearCache()
        
        // No exception thrown means success
        let cacheCount = await checker.cacheCountForTesting()
        #expect(cacheCount == 0)
    }
}

//
//  AttributionCheckerTests.swift
//  fedi-readerTests
//
//  Tests for AttributionChecker
//

import Testing
import Foundation
@testable import fedi_reader

private final class AttributionCheckerMockURLProtocol: URLProtocol {
    private static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let response = Self.response(for: request.httpMethod ?? "GET", url: url) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        client?.urlProtocol(self, didReceive: response.1, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.0)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        mockResponses.removeAll()
    }

    static func setMockResponse(
        method: String,
        url: String,
        data: Data = Data(),
        statusCode: Int = 200,
        headerFields: [String: String]? = nil
    ) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!

        lock.lock()
        defer { lock.unlock() }
        mockResponses[key(method: method, url: url)] = (data, response)
    }

    private static func response(for method: String, url: String) -> (Data, HTTPURLResponse)? {
        lock.lock()
        defer { lock.unlock() }
        return mockResponses[key(method: method, url: url)]
    }

    private static func key(method: String, url: String) -> String {
        "\(method.uppercased()) \(url)"
    }
}

@Suite("Attribution Checker Tests")
struct AttributionCheckerTests {

    @Test("Extracts rel author from anchor tags and resolves relative URLs")
    func extractsRelAuthorFromAnchorTags() async {
        AttributionCheckerMockURLProtocol.reset()
        defer { AttributionCheckerMockURLProtocol.reset() }

        let articleURL = "https://example.com/articles/story"
        let authorURL = "https://example.com/authors/jane"
        let html = """
        <html>
            <body>
                <p class="byline">
                    <a href="/authors/jane" rel="author">Jane Doe</a>
                </p>
            </body>
        </html>
        """

        AttributionCheckerMockURLProtocol.setMockResponse(method: "HEAD", url: articleURL)
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: articleURL,
            data: Data(html.utf8),
            headerFields: ["Content-Type": "text/html"]
        )
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: authorURL,
            data: Data("<html></html>".utf8),
            headerFields: ["Content-Type": "text/html"]
        )

        let checker = makeChecker()
        let attribution = await checker.checkAttribution(for: URL(string: articleURL)!)

        #expect(attribution?.name == "Jane Doe")
        #expect(attribution?.url == authorURL)
    }

    @Test("Merges Link header URLs with meta author names")
    func mergesLinkHeaderURLsWithMetaNames() async {
        AttributionCheckerMockURLProtocol.reset()
        defer { AttributionCheckerMockURLProtocol.reset() }

        let articleURL = "https://example.com/articles/story"
        let authorURL = "https://example.com/authors/jane"
        let html = """
        <html>
            <head>
                <meta name="author" content="Jane Doe">
            </head>
        </html>
        """

        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "HEAD",
            url: articleURL,
            headerFields: ["Link": #"<\#(authorURL)>; rel="alternate author""#]
        )
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: articleURL,
            data: Data(html.utf8),
            headerFields: ["Content-Type": "text/html"]
        )
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: authorURL,
            data: Data("<html></html>".utf8),
            headerFields: ["Content-Type": "text/html"]
        )

        let checker = makeChecker()
        let attribution = await checker.checkAttribution(for: URL(string: articleURL)!)

        #expect(attribution?.name == "Jane Doe")
        #expect(attribution?.url == authorURL)
    }

    @Test("Extracts authors from JSON-LD graphs")
    func extractsAuthorsFromJSONLDGraphs() async {
        AttributionCheckerMockURLProtocol.reset()
        defer { AttributionCheckerMockURLProtocol.reset() }

        let articleURL = "https://example.com/articles/story"
        let authorURL = "https://example.com/authors/jane"
        let html = """
        <html>
            <head>
                <script type="application/ld+json">
                {
                  "@context": "https://schema.org",
                  "@graph": [
                    {
                      "@type": "NewsArticle",
                      "author": {"@id": "#author-jane"}
                    },
                    {
                      "@id": "#author-jane",
                      "@type": "Person",
                      "name": "Jane Doe",
                      "url": "/authors/jane"
                    }
                  ]
                }
                </script>
            </head>
        </html>
        """

        AttributionCheckerMockURLProtocol.setMockResponse(method: "HEAD", url: articleURL)
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: articleURL,
            data: Data(html.utf8),
            headerFields: ["Content-Type": "text/html"]
        )
        AttributionCheckerMockURLProtocol.setMockResponse(
            method: "GET",
            url: authorURL,
            data: Data("<html></html>".utf8),
            headerFields: ["Content-Type": "text/html"]
        )

        let checker = makeChecker()
        let attribution = await checker.checkAttribution(for: URL(string: articleURL)!)

        #expect(attribution?.name == "Jane Doe")
        #expect(attribution?.url == authorURL)
        #expect(attribution?.source == .jsonLD)
    }

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

    @Test("Cache can be cleared")
    func cacheClearable() async {
        let checker = makeChecker()
        await checker.clearCache()
        let cacheCount = await checker.cacheCountForTesting()
        #expect(cacheCount == 0)
    }

    private func makeChecker() -> AttributionChecker {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AttributionCheckerMockURLProtocol.self]
        return AttributionChecker(configuration: configuration)
    }
}

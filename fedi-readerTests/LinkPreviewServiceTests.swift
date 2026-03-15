import Testing
import Foundation
@testable import fedi_reader

private final class LinkPreviewServiceMockURLProtocol: URLProtocol {
    static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]
    static var queuedResponses: [String: [(Data, HTTPURLResponse)]] = [:]
    static var requestHandler: ((URLRequest) -> (Data, HTTPURLResponse)?)?
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let (data, response) = Self.response(for: request) else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        mockResponses.removeAll()
        queuedResponses.removeAll()
        requestHandler = nil
    }

    static func setMockResponse(
        for url: String,
        data: Data,
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
        mockResponses[url] = (data, response)
    }

    static func queueMockResponses(
        for url: String,
        responses: [(data: Data, statusCode: Int, headerFields: [String: String]?)]
    ) {
        lock.lock()
        defer { lock.unlock() }
        queuedResponses[url] = responses.map { response in
            let httpResponse = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: response.statusCode,
                httpVersion: nil,
                headerFields: response.headerFields
            )!
            return (response.data, httpResponse)
        }
    }

    private static func response(for request: URLRequest) -> (Data, HTTPURLResponse)? {
        lock.lock()
        defer { lock.unlock() }
        if let requestHandler {
            return requestHandler(request)
        }
        guard let url = request.url?.absoluteString else {
            return nil
        }
        if var queued = queuedResponses[url], !queued.isEmpty {
            let response = queued.removeFirst()
            if queued.isEmpty {
                queuedResponses.removeValue(forKey: url)
            } else {
                queuedResponses[url] = queued
            }
            return response
        }
        return mockResponses[url]
    }
}

@Suite("Link Preview Service Tests", .serialized)
struct LinkPreviewServiceTests {

    @Test("Fetches fediverse creator when meta attributes are reversed")
    func fetchesFediverseCreatorWhenMetaAttributesAreReversed() async {
        LinkPreviewServiceMockURLProtocol.reset()

        let url = "https://example.com/article"
        let html = """
        <html>
            <head>
                <meta content="@alice@mastodon.social" name="fediverse:creator">
            </head>
            <body>Example</body>
        </html>
        """

        LinkPreviewServiceMockURLProtocol.setMockResponse(
            for: url,
            data: Data(html.utf8),
            headerFields: ["Content-Type": "text/html"]
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LinkPreviewServiceMockURLProtocol.self]
        let service = LinkPreviewService(configuration: configuration)

        let creator = await service.fetchFediverseCreator(for: URL(string: url)!)

        #expect(creator?.name == "@alice@mastodon.social")
        #expect(creator?.url?.absoluteString == "https://mastodon.social/@alice")
    }

    @Test("Falls back to full HTML fetch when the head range lacks preview metadata")
    func fallsBackToFullHTMLFetchWhenHeadRangeLacksPreviewMetadata() async {
        LinkPreviewServiceMockURLProtocol.reset()

        let url = "https://example.com/article"
        let sparseHTML = """
        <html>
            <head>
                <meta charset="utf-8">
            </head>
            <body>Partial</body>
        </html>
        """
        let fullHTML = """
        <html>
            <head>
                <meta property="og:title" content="Recovered Title">
                <meta property="og:image" content="https://example.com/feature.jpg">
                <meta property="og:site_name" content="Example Site">
            </head>
            <body>Full</body>
        </html>
        """

        LinkPreviewServiceMockURLProtocol.requestHandler = { request in
            guard request.url?.absoluteString == url else { return nil }

            let statusCode: Int
            let data: Data

            if request.httpMethod == "HEAD" {
                statusCode = 200
                data = Data()
            } else if request.value(forHTTPHeaderField: "Range") != nil {
                statusCode = 206
                data = Data(sparseHTML.utf8)
            } else {
                statusCode = 200
                data = Data(fullHTML.utf8)
            }

            let response = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html"]
            )!

            return (data, response)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LinkPreviewServiceMockURLProtocol.self]
        let service = LinkPreviewService(configuration: configuration)

        let preview = await service.preview(for: URL(string: url)!)

        #expect(preview?.title == "Recovered Title")
        #expect(preview?.imageURL?.absoluteString == "https://example.com/feature.jpg")
        #expect(preview?.siteName == "Example Site")
    }

    @Test("Falls back to full HTML fetch when the head range has a title but no image")
    func fallsBackToFullHTMLFetchWhenHeadRangeHasTitleButNoImage() async {
        LinkPreviewServiceMockURLProtocol.reset()

        let url = "https://example.com/article"
        let sparseHTML = """
        <html>
            <head>
                <meta property="og:title" content="Recovered Title">
                <meta property="og:site_name" content="Example Site">
            </head>
            <body>Partial</body>
        </html>
        """
        let fullHTML = """
        <html>
            <head>
                <meta property="og:title" content="Recovered Title">
                <meta property="og:image" content="https://example.com/feature.jpg">
                <meta property="og:site_name" content="Example Site">
            </head>
            <body>Full</body>
        </html>
        """

        LinkPreviewServiceMockURLProtocol.requestHandler = { request in
            guard request.url?.absoluteString == url else { return nil }

            let statusCode: Int
            let data: Data

            if request.httpMethod == "HEAD" {
                statusCode = 200
                data = Data()
            } else if request.value(forHTTPHeaderField: "Range") != nil {
                statusCode = 206
                data = Data(sparseHTML.utf8)
            } else {
                statusCode = 200
                data = Data(fullHTML.utf8)
            }

            let response = HTTPURLResponse(
                url: URL(string: url)!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/html"]
            )!

            return (data, response)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LinkPreviewServiceMockURLProtocol.self]
        let service = LinkPreviewService(configuration: configuration)

        let preview = await service.preview(for: URL(string: url)!)

        #expect(preview?.title == "Recovered Title")
        #expect(preview?.imageURL?.absoluteString == "https://example.com/feature.jpg")
        #expect(preview?.siteName == "Example Site")
    }
}

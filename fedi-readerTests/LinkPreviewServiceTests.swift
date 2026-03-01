import Testing
import Foundation
@testable import fedi_reader

private final class LinkPreviewServiceMockURLProtocol: URLProtocol {
    static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url?.absoluteString,
              let (data, response) = Self.response(for: url) else {
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

    private static func response(for url: String) -> (Data, HTTPURLResponse)? {
        lock.lock()
        defer { lock.unlock() }
        return mockResponses[url]
    }
}

@Suite("Link Preview Service Tests")
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
}

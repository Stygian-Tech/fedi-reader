import Foundation
@testable import fedi_reader

enum MockStatusFactory {
    static func makeStatus(
        id: String = UUID().uuidString,
        content: String = "<p>Test post content</p>",
        hasCard: Bool = false,
        cardURL: String? = nil,
        cardType: CardType = .link,
        cardTitle: String? = nil,
        uri: String? = nil,
        url: String? = nil,
        tags: [Tag] = [],
        account: MastodonAccount? = nil,
        isReblog: Bool = false,
        isQuote: Bool = false,
        favourited: Bool = false,
        reblogged: Bool = false,
        bookmarked: Bool = false,
        visibility: Visibility = .public,
        inReplyToId: String? = nil,
        repliesCount: Int = 2
    ) -> Status {
        let account = account ?? makeAccount()
        
        var card: PreviewCard? = nil
        if hasCard, let url = cardURL {
            card = PreviewCard(
                url: url,
                title: cardTitle ?? "Test Article",
                description: "Test description",
                type: cardType,
                authorName: "Test Author",
                authorUrl: nil,
                providerName: "test.com",
                providerUrl: nil,
                html: nil,
                width: nil,
                height: nil,
                image: "https://example.com/image.jpg",
                blurhash: nil,
                embedUrl: nil
            )
        }
        
        return Status(
            id: id,
            uri: uri ?? "https://mastodon.social/statuses/\(id)",
            url: url ?? "https://mastodon.social/@testuser/\(id)",
            createdAt: Date(),
            account: account,
            content: content,
            visibility: visibility,
            sensitive: false,
            spoilerText: "",
            mediaAttachments: [],
            mentions: [],
            tags: tags,
            emojis: [],
            reblogsCount: 5,
            favouritesCount: 10,
            repliesCount: repliesCount,
            application: nil,
            language: "en",
            reblog: nil,
            card: card,
            poll: nil,
            quote: isQuote ? IndirectStatus(makeQuotedStatus()) : nil,
            favourited: favourited,
            reblogged: reblogged,
            muted: false,
            bookmarked: bookmarked,
            pinned: false,
            inReplyToId: inReplyToId,
            inReplyToAccountId: nil
        )
    }
    
    static func makeQuotedStatus() -> Status {
        let account = makeAccount(username: "quoteduser")
        
        return Status(
            id: UUID().uuidString,
            uri: "https://mastodon.social/statuses/quoted",
            url: "https://mastodon.social/@quoteduser/quoted",
            createdAt: Date().addingTimeInterval(-3600),
            account: account,
            content: "<p>This is the quoted status</p>",
            visibility: .public,
            sensitive: false,
            spoilerText: "",
            mediaAttachments: [],
            mentions: [],
            tags: [],
            emojis: [],
            reblogsCount: 0,
            favouritesCount: 0,
            repliesCount: 0,
            application: nil,
            language: "en",
            reblog: nil,
            card: nil,
            poll: nil,
            quote: nil,
            favourited: false,
            reblogged: false,
            muted: false,
            bookmarked: false,
            pinned: false,
            inReplyToId: nil,
            inReplyToAccountId: nil
        )
    }
    
    static func makeAccount(
        id: String = UUID().uuidString,
        username: String = "testuser",
        displayName: String = "Test User"
    ) -> MastodonAccount {
        MastodonAccount(
            id: id,
            username: username,
            acct: username,
            displayName: displayName,
            locked: false,
            bot: false,
            createdAt: Date(),
            note: "<p>Test bio</p>",
            url: "https://mastodon.social/@\(username)",
            avatar: "https://example.com/avatar.jpg",
            avatarStatic: "https://example.com/avatar.jpg",
            header: "https://example.com/header.jpg",
            headerStatic: "https://example.com/header.jpg",
            followersCount: 100,
            followingCount: 50,
            statusesCount: 200,
            lastStatusAt: nil,
            emojis: [],
            fields: [],
            source: nil
        )
    }
    
    static func makeNotification(
        id: String = UUID().uuidString,
        type: NotificationType = .mention,
        status: Status? = nil
    ) -> MastodonNotification {
        MastodonNotification(
            id: id,
            type: type,
            createdAt: Date(),
            account: makeAccount(),
            status: status ?? makeStatus()
        )
    }
    
    static func makeTrendingLink(
        url: String = "https://example.com/article",
        title: String = "Test Article",
        description: String = "Test description"
    ) -> TrendingLink {
        TrendingLink(
            url: url,
            title: title,
            description: description,
            type: .link,
            authorName: "Test Author",
            authorUrl: nil,
            providerName: "example.com",
            providerUrl: nil,
            html: nil,
            width: nil,
            height: nil,
            image: "https://example.com/image.jpg",
            blurhash: nil,
            history: nil
        )
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var mockResponses: [String: (Data, HTTPURLResponse)] = [:]
    static var queuedResponses: [String: [(Data, HTTPURLResponse)]] = [:]
    static var mockErrors: [String: Error] = [:]
    static var responseDelays: [String: TimeInterval] = [:]
    static var requestCounts: [String: Int] = [:]
    static var lastRequest: URLRequest?
    private static let lock = NSLock()
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        Self.lock.lock()
        Self.lastRequest = request
        guard let url = request.url?.absoluteString else {
            Self.lock.unlock()
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        Self.requestCounts[url, default: 0] += 1

        let error = Self.mockErrors[url]
        var queuedResponse: (Data, HTTPURLResponse)?
        if var responses = Self.queuedResponses[url], !responses.isEmpty {
            queuedResponse = responses.removeFirst()
            if responses.isEmpty {
                Self.queuedResponses.removeValue(forKey: url)
            } else {
                Self.queuedResponses[url] = responses
            }
        }
        let mockResponse = queuedResponse ?? Self.mockResponses[url]
        let responseDelay = Self.responseDelays[url] ?? 0
        Self.lock.unlock()

        if responseDelay > 0 {
            Thread.sleep(forTimeInterval: responseDelay)
        }
        
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let (data, response) = mockResponse {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
    
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        mockResponses.removeAll()
        queuedResponses.removeAll()
        mockErrors.removeAll()
        responseDelays.removeAll()
        requestCounts.removeAll()
        lastRequest = nil
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

    static func setQueuedResponses(
        for url: String,
        responses: [(data: Data, statusCode: Int, headerFields: [String: String]?)]
    ) {
        let queued = responses.map { response in
            (
                response.data,
                HTTPURLResponse(
                    url: URL(string: url)!,
                    statusCode: response.statusCode,
                    httpVersion: nil,
                    headerFields: response.headerFields
                )!
            )
        }

        lock.lock()
        defer { lock.unlock() }
        queuedResponses[url] = queued
    }
    
    static func setMockError(for url: String, error: Error) {
        lock.lock()
        defer { lock.unlock() }
        mockErrors[url] = error
    }

    static func setResponseDelay(for url: String, seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        responseDelays[url] = seconds
    }

    static func requestCount(for url: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCounts[url, default: 0]
    }
}

// MARK: - Mock Keychain Helper

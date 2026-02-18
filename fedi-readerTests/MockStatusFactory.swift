import Foundation
@testable import fedi_reader

enum MockStatusFactory {
    static func makeStatus(
        id: String = UUID().uuidString,
        content: String = "<p>Test post content</p>",
        hasCard: Bool = false,
        cardURL: String? = nil,
        cardTitle: String? = nil,
        tags: [Tag] = [],
        account: MastodonAccount? = nil,
        isReblog: Bool = false,
        isQuote: Bool = false,
        favourited: Bool = false,
        reblogged: Bool = false,
        visibility: Visibility = .public,
        inReplyToId: String? = nil
    ) -> Status {
        let account = account ?? makeAccount()
        
        var card: PreviewCard? = nil
        if hasCard, let url = cardURL {
            card = PreviewCard(
                url: url,
                title: cardTitle ?? "Test Article",
                description: "Test description",
                type: .link,
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
            uri: "https://mastodon.social/statuses/\(id)",
            url: "https://mastodon.social/@testuser/\(id)",
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
            repliesCount: 2,
            application: nil,
            language: "en",
            reblog: nil,
            card: card,
            poll: nil,
            quote: isQuote ? IndirectStatus(makeQuotedStatus()) : nil,
            favourited: favourited,
            reblogged: reblogged,
            muted: false,
            bookmarked: false,
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
    static var mockErrors: [String: Error] = [:]
    static var lastRequest: URLRequest?
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override func startLoading() {
        Self.lastRequest = request
        
        guard let url = request.url?.absoluteString else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        if let error = Self.mockErrors[url] {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let (data, response) = Self.mockResponses[url] {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
    
    static func reset() {
        mockResponses.removeAll()
        mockErrors.removeAll()
        lastRequest = nil
    }
    
    static func setMockResponse(for url: String, data: Data, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        mockResponses[url] = (data, response)
    }
    
    static func setMockError(for url: String, error: Error) {
        mockErrors[url] = error
    }
}

// MARK: - Mock Keychain Helper



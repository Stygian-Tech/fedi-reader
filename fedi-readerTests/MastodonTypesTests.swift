//
//  MastodonTypesTests.swift
//  fedi-readerTests
//
//  Tests for Mastodon API types
//

import Testing
import Foundation
@testable import fedi_reader

@Suite("Mastodon Types Tests")
@MainActor
struct MastodonTypesTests {
    
    // MARK: - Status Tests
    
    @Test("Status correctly identifies reblog")
    func statusIdentifiesReblog() {
        let status = MockStatusFactory.makeStatus()
        
        #expect(status.isReblog == false)
    }
    
    @Test("Status correctly identifies quote post")
    func statusIdentifiesQuotePost() {
        let quotePost = MockStatusFactory.makeStatus(isQuote: true)
        let regularPost = MockStatusFactory.makeStatus(isQuote: false)
        
        #expect(quotePost.isQuotePost == true)
        #expect(regularPost.isQuotePost == false)
    }
    
    @Test("Status correctly identifies link card")
    func statusIdentifiesLinkCard() {
        let withCard = MockStatusFactory.makeStatus(hasCard: true, cardURL: "https://example.com")
        let withoutCard = MockStatusFactory.makeStatus(hasCard: false)
        
        #expect(withCard.hasLinkCard == true)
        #expect(withoutCard.hasLinkCard == false)
    }
    
    @Test("Status displayStatus returns correct status")
    func statusDisplayStatus() {
        let status = MockStatusFactory.makeStatus()
        
        // For non-reblog, displayStatus should return self
        #expect(status.displayStatus.id == status.id)
    }
    
    // MARK: - Visibility Tests
    
    @Test("Visibility raw values are correct")
    func visibilityRawValues() {
        #expect(Visibility.public.rawValue == "public")
        #expect(Visibility.unlisted.rawValue == "unlisted")
        #expect(Visibility.private.rawValue == "private")
        #expect(Visibility.direct.rawValue == "direct")
    }
    
    // MARK: - Card Type Tests
    
    @Test("CardType raw values are correct")
    func cardTypeRawValues() {
        #expect(CardType.link.rawValue == "link")
        #expect(CardType.photo.rawValue == "photo")
        #expect(CardType.video.rawValue == "video")
        #expect(CardType.rich.rawValue == "rich")
    }
    
    // MARK: - Notification Type Tests
    
    @Test("NotificationType raw values are correct")
    func notificationTypeRawValues() {
        #expect(NotificationType.mention.rawValue == "mention")
        #expect(NotificationType.favourite.rawValue == "favourite")
        #expect(NotificationType.reblog.rawValue == "reblog")
        #expect(NotificationType.follow.rawValue == "follow")
    }
    
    // MARK: - Account Tests
    
    @Test("MastodonAccount has valid URLs")
    func accountHasValidURLs() {
        let account = MockStatusFactory.makeAccount()
        
        #expect(account.avatarURL != nil)
        #expect(account.headerURL != nil)
    }

    @Test("MastodonAccount prefers source note when available")
    func accountPrefersSourceNote() {
        let account = makeAccount(
            note: "<p>HTML bio line one<br />HTML bio line two</p>",
            sourceNote: "Source line one\r\nSource line two"
        )

        #expect(account.preferredNote == "Source line one\r\nSource line two")
    }

    @Test("MastodonAccount falls back to note when source note is empty")
    func accountFallsBackToNoteWhenSourceNoteEmpty() {
        let account = makeAccount(
            note: "<p>HTML bio line one<br />HTML bio line two</p>",
            sourceNote: "   "
        )

        #expect(account.preferredNote == "<p>HTML bio line one<br />HTML bio line two</p>")
    }

    @Test("MastodonAccount preferredFields uses source fields when top-level fields are empty")
    func accountPreferredFieldsUsesSourceFieldsFallback() {
        let sourceField = Field(
            name: "Website",
            value: "<a href=\"https://example.com\">example.com</a>",
            verifiedAt: nil
        )
        let account = makeAccount(
            note: "<p>bio</p>",
            sourceNote: "bio",
            fields: [],
            sourceFields: [sourceField]
        )

        #expect(account.preferredFields.count == 1)
        #expect(account.preferredFields.first?.name == "Website")
    }

    @Test("MastodonAccount preferredFields favors top-level fields")
    func accountPreferredFieldsPrefersTopLevelFields() {
        let topLevelField = Field(
            name: "Top",
            value: "<a href=\"https://top.example\">top.example</a>",
            verifiedAt: nil
        )
        let sourceField = Field(
            name: "Source",
            value: "<a href=\"https://source.example\">source.example</a>",
            verifiedAt: nil
        )
        let account = makeAccount(
            note: "<p>bio</p>",
            sourceNote: "bio",
            fields: [topLevelField],
            sourceFields: [sourceField]
        )

        #expect(account.preferredFields.count == 1)
        #expect(account.preferredFields.first?.name == "Top")
    }
    
    // MARK: - Preview Card Tests
    
    @Test("PreviewCard has valid URLs")
    func previewCardHasValidURLs() {
        let status = MockStatusFactory.makeStatus(hasCard: true, cardURL: "https://example.com/article")
        
        #expect(status.card?.linkURL != nil)
        #expect(status.card?.linkURL?.absoluteString == "https://example.com/article")
    }
    
    @Test("PreviewCard image URL is valid")
    func previewCardImageURL() {
        let status = MockStatusFactory.makeStatus(hasCard: true, cardURL: "https://example.com")
        
        #expect(status.card?.imageURL != nil)
    }
    
    // MARK: - IndirectStatus Wrapper Tests
    
    @Test("IndirectStatus wrapper preserves value")
    func indirectStatusPreservesValue() {
        let originalStatus = MockStatusFactory.makeStatus()
        let indirectStatus = IndirectStatus(originalStatus)
        
        #expect(indirectStatus.value.id == originalStatus.id)
    }
    
    // MARK: - JSON Encoding/Decoding
    
    @Test("Status can be encoded and decoded")
    func statusEncodingDecoding() throws {
        let status = MockStatusFactory.makeStatus()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Status.self, from: data)
        
        #expect(decoded.id == status.id)
        #expect(decoded.content == status.content)
    }
    
    @Test("MastodonAccount can be encoded and decoded")
    func accountEncodingDecoding() throws {
        let account = MockStatusFactory.makeAccount()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(account)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MastodonAccount.self, from: data)
        
        #expect(decoded.id == account.id)
        #expect(decoded.username == account.username)
    }

    @Test("MastodonAccount decoding tolerates missing fields key")
    func accountDecodingMissingFieldsKey() throws {
        let json = """
        {
          "id": "123",
          "username": "testuser",
          "acct": "testuser",
          "display_name": "Test User",
          "locked": false,
          "bot": false,
          "created_at": "2024-01-01T00:00:00Z",
          "note": "<p>bio</p>",
          "url": "https://example.com/@testuser",
          "avatar": "https://example.com/avatar.jpg",
          "avatar_static": "https://example.com/avatar.jpg",
          "header": "https://example.com/header.jpg",
          "header_static": "https://example.com/header.jpg",
          "followers_count": 1,
          "following_count": 2,
          "statuses_count": 3,
          "last_status_at": null,
          "emojis": []
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(MastodonAccount.self, from: Data(json.utf8))

        #expect(decoded.fields.isEmpty)
    }

    @Test("Field decoding tolerates empty verified_at")
    func fieldDecodingWithEmptyVerifiedAt() throws {
        let json = """
        {
          "name": "Website",
          "value": "<a href=\\"https://example.com\\">example.com</a>",
          "verified_at": ""
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Field.self, from: Data(json.utf8))

        #expect(decoded.verifiedAt == nil)
    }
    
    // MARK: - AsyncRefreshHeader Parse Tests
    
    @Test("AsyncRefreshHeader parses valid header")
    func asyncRefreshHeaderParsesValid() {
        let raw = #"id="ImNvbnRleHQ6MTEzNjQwNTczMzAzNzg1MTc4OnJlZnJlc2gi--c526259eb4a1f3ef0d4b91cf8c99bf501330a815", retry=5, result_count=2"#
        let parsed = AsyncRefreshHeader.parse(headerValue: raw)
        #expect(parsed != nil)
        #expect(parsed?.id == "ImNvbnRleHQ6MTEzNjQwNTczMzAzNzg1MTc4OnJlZnJlc2gi--c526259eb4a1f3ef0d4b91cf8c99bf501330a815")
        #expect(parsed?.retrySeconds == 5)
        #expect(parsed?.resultCount == 2)
    }
    
    @Test("AsyncRefreshHeader parses header without result_count")
    func asyncRefreshHeaderParsesWithoutResultCount() {
        let raw = #"id="abc123", retry=10"#
        let parsed = AsyncRefreshHeader.parse(headerValue: raw)
        #expect(parsed != nil)
        #expect(parsed?.id == "abc123")
        #expect(parsed?.retrySeconds == 10)
        #expect(parsed?.resultCount == nil)
    }
    
    @Test("AsyncRefreshHeader returns nil for missing id")
    func asyncRefreshHeaderMissingId() {
        let raw = #"retry=5, result_count=2"#
        #expect(AsyncRefreshHeader.parse(headerValue: raw) == nil)
    }
    
    @Test("AsyncRefreshHeader returns nil for missing retry")
    func asyncRefreshHeaderMissingRetry() {
        let raw = #"id="abc", result_count=2"#
        #expect(AsyncRefreshHeader.parse(headerValue: raw) == nil)
    }
    
    @Test("AsyncRefreshHeader returns nil for malformed or empty")
    func asyncRefreshHeaderMalformed() {
        #expect(AsyncRefreshHeader.parse(headerValue: nil) == nil)
        #expect(AsyncRefreshHeader.parse(headerValue: "") == nil)
        #expect(AsyncRefreshHeader.parse(headerValue: "  ") == nil)
        #expect(AsyncRefreshHeader.parse(headerValue: "junk") == nil)
        #expect(AsyncRefreshHeader.parse(headerValue: #"id="x", retry=0"#) == nil)
    }

    private func makeAccount(
        note: String,
        sourceNote: String?,
        fields: [Field] = [],
        sourceFields: [Field]? = nil
    ) -> MastodonAccount {
        MastodonAccount(
            id: "123",
            username: "testuser",
            acct: "testuser",
            displayName: "Test User",
            locked: false,
            bot: false,
            createdAt: Date(),
            note: note,
            url: "https://example.com/@testuser",
            avatar: "https://example.com/avatar.jpg",
            avatarStatic: "https://example.com/avatar.jpg",
            header: "https://example.com/header.jpg",
            headerStatic: "https://example.com/header.jpg",
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            lastStatusAt: nil,
            emojis: [],
            fields: fields,
            source: sourceNote.map { AccountSource(note: $0, fields: sourceFields) }
        )
    }
}

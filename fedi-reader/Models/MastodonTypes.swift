//
//  MastodonTypes.swift
//  fedi-reader
//
//  Mastodon API response types
//

import Foundation

// MARK: - Status (Post/Toot)

struct Status: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let uri: String
    let url: String?
    let createdAt: Date
    let account: MastodonAccount
    let content: String
    let visibility: Visibility
    let sensitive: Bool
    let spoilerText: String
    let mediaAttachments: [MediaAttachment]
    let mentions: [Mention]
    let tags: [Tag]
    let emojis: [CustomEmoji]
    let reblogsCount: Int
    let favouritesCount: Int
    let repliesCount: Int
    let application: Application?
    let language: String?
    let reblog: IndirectStatus?
    let card: PreviewCard?
    let poll: Poll?
    let quote: IndirectStatus? // For instances supporting quote posts
    let favourited: Bool?
    let reblogged: Bool?
    let muted: Bool?
    let bookmarked: Bool?
    let pinned: Bool?
    let inReplyToId: String?
    let inReplyToAccountId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, uri, url, content, visibility, sensitive, mentions, tags, emojis
        case reblogsCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case repliesCount = "replies_count"
        case createdAt = "created_at"
        case account
        case spoilerText = "spoiler_text"
        case mediaAttachments = "media_attachments"
        case application, language, reblog, card, poll, quote
        case favourited, reblogged, muted, bookmarked, pinned
        case inReplyToId = "in_reply_to_id"
        case inReplyToAccountId = "in_reply_to_account_id"
    }
    
    // Manual initializer for creating Status instances (e.g., in previews)
    init(
        id: String,
        uri: String,
        url: String?,
        createdAt: Date,
        account: MastodonAccount,
        content: String,
        visibility: Visibility,
        sensitive: Bool,
        spoilerText: String,
        mediaAttachments: [MediaAttachment],
        mentions: [Mention],
        tags: [Tag],
        emojis: [CustomEmoji],
        reblogsCount: Int,
        favouritesCount: Int,
        repliesCount: Int,
        application: Application?,
        language: String?,
        reblog: IndirectStatus?,
        card: PreviewCard?,
        poll: Poll?,
        quote: IndirectStatus?,
        favourited: Bool?,
        reblogged: Bool?,
        muted: Bool?,
        bookmarked: Bool?,
        pinned: Bool?,
        inReplyToId: String?,
        inReplyToAccountId: String?
    ) {
        self.id = id
        self.uri = uri
        self.url = url
        self.createdAt = createdAt
        self.account = account
        self.content = content
        self.visibility = visibility
        self.sensitive = sensitive
        self.spoilerText = spoilerText
        self.mediaAttachments = mediaAttachments
        self.mentions = mentions
        self.tags = tags
        self.emojis = emojis
        self.reblogsCount = reblogsCount
        self.favouritesCount = favouritesCount
        self.repliesCount = repliesCount
        self.application = application
        self.language = language
        self.reblog = reblog
        self.card = card
        self.poll = poll
        self.quote = quote
        self.favourited = favourited
        self.reblogged = reblogged
        self.muted = muted
        self.bookmarked = bookmarked
        self.pinned = pinned
        self.inReplyToId = inReplyToId
        self.inReplyToAccountId = inReplyToAccountId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        uri = try container.decode(String.self, forKey: .uri)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        account = try container.decode(MastodonAccount.self, forKey: .account)
        content = try container.decode(String.self, forKey: .content)
        visibility = try container.decode(Visibility.self, forKey: .visibility)
        sensitive = try container.decode(Bool.self, forKey: .sensitive)
        spoilerText = try container.decode(String.self, forKey: .spoilerText)
        mediaAttachments = try container.decode([MediaAttachment].self, forKey: .mediaAttachments)
        mentions = try container.decode([Mention].self, forKey: .mentions)
        tags = try container.decode([Tag].self, forKey: .tags)
        emojis = try container.decode([CustomEmoji].self, forKey: .emojis)
        reblogsCount = try container.decode(Int.self, forKey: .reblogsCount)
        favouritesCount = try container.decode(Int.self, forKey: .favouritesCount)
        repliesCount = try container.decode(Int.self, forKey: .repliesCount)
        application = try container.decodeIfPresent(Application.self, forKey: .application)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        reblog = try container.decodeIfPresent(IndirectStatus.self, forKey: .reblog)
        card = try container.decodeIfPresent(PreviewCard.self, forKey: .card)
        poll = try container.decodeIfPresent(Poll.self, forKey: .poll)
        
        // Handle quote decoding gracefully - some instances may send incomplete quote objects
        quote = try? container.decodeIfPresent(IndirectStatus.self, forKey: .quote)
        
        favourited = try container.decodeIfPresent(Bool.self, forKey: .favourited)
        reblogged = try container.decodeIfPresent(Bool.self, forKey: .reblogged)
        muted = try container.decodeIfPresent(Bool.self, forKey: .muted)
        bookmarked = try container.decodeIfPresent(Bool.self, forKey: .bookmarked)
        pinned = try container.decodeIfPresent(Bool.self, forKey: .pinned)
        inReplyToId = try container.decodeIfPresent(String.self, forKey: .inReplyToId)
        inReplyToAccountId = try container.decodeIfPresent(String.self, forKey: .inReplyToAccountId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(uri, forKey: .uri)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(account, forKey: .account)
        try container.encode(content, forKey: .content)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(sensitive, forKey: .sensitive)
        try container.encode(spoilerText, forKey: .spoilerText)
        try container.encode(mediaAttachments, forKey: .mediaAttachments)
        try container.encode(mentions, forKey: .mentions)
        try container.encode(tags, forKey: .tags)
        try container.encode(emojis, forKey: .emojis)
        try container.encode(reblogsCount, forKey: .reblogsCount)
        try container.encode(favouritesCount, forKey: .favouritesCount)
        try container.encode(repliesCount, forKey: .repliesCount)
        try container.encodeIfPresent(application, forKey: .application)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(reblog, forKey: .reblog)
        try container.encodeIfPresent(card, forKey: .card)
        try container.encodeIfPresent(poll, forKey: .poll)
        try container.encodeIfPresent(quote, forKey: .quote)
        try container.encodeIfPresent(favourited, forKey: .favourited)
        try container.encodeIfPresent(reblogged, forKey: .reblogged)
        try container.encodeIfPresent(muted, forKey: .muted)
        try container.encodeIfPresent(bookmarked, forKey: .bookmarked)
        try container.encodeIfPresent(pinned, forKey: .pinned)
        try container.encodeIfPresent(inReplyToId, forKey: .inReplyToId)
        try container.encodeIfPresent(inReplyToAccountId, forKey: .inReplyToAccountId)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Status, rhs: Status) -> Bool {
        lhs.id == rhs.id
    }
    
    // Convenience computed properties
    nonisolated var displayStatus: Status {
        reblog?.value ?? self
    }
    
    nonisolated var isReblog: Bool {
        reblog != nil
    }
    
    nonisolated var isQuotePost: Bool {
        quote != nil
    }
    
    nonisolated var hasLinkCard: Bool {
        card?.type == .link
    }
    
    nonisolated var cardURL: URL? {
        guard let urlString = card?.url else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - IndirectStatus wrapper for recursive Status references

final class IndirectStatus: Codable, Hashable, @unchecked Sendable {
    let value: Status
    
    init(_ value: Status) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(Status.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(value.id)
    }
    
    static func == (lhs: IndirectStatus, rhs: IndirectStatus) -> Bool {
        lhs.value.id == rhs.value.id
    }
}

// MARK: - Visibility

enum Visibility: String, Codable, Sendable {
    case `public`
    case unlisted
    case `private`
    case direct
}

// MARK: - Account (Remote Mastodon Account)

struct MastodonAccount: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String
    let acct: String
    let displayName: String
    let locked: Bool
    let bot: Bool
    let createdAt: Date
    let note: String
    let url: String
    let avatar: String
    let avatarStatic: String
    let header: String
    let headerStatic: String
    let followersCount: Int
    let followingCount: Int
    let statusesCount: Int
    let lastStatusAt: String?
    let emojis: [CustomEmoji]
    let fields: [Field]
    let source: AccountSource?
    
    enum CodingKeys: String, CodingKey {
        case id, username, acct, locked, bot, note, url, avatar, header, emojis, fields, source
        case displayName = "display_name"
        case createdAt = "created_at"
        case avatarStatic = "avatar_static"
        case headerStatic = "header_static"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case statusesCount = "statuses_count"
        case lastStatusAt = "last_status_at"
    }

    init(
        id: String,
        username: String,
        acct: String,
        displayName: String,
        locked: Bool,
        bot: Bool,
        createdAt: Date,
        note: String,
        url: String,
        avatar: String,
        avatarStatic: String,
        header: String,
        headerStatic: String,
        followersCount: Int,
        followingCount: Int,
        statusesCount: Int,
        lastStatusAt: String?,
        emojis: [CustomEmoji],
        fields: [Field],
        source: AccountSource?
    ) {
        self.id = id
        self.username = username
        self.acct = acct
        self.displayName = displayName
        self.locked = locked
        self.bot = bot
        self.createdAt = createdAt
        self.note = note
        self.url = url
        self.avatar = avatar
        self.avatarStatic = avatarStatic
        self.header = header
        self.headerStatic = headerStatic
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.statusesCount = statusesCount
        self.lastStatusAt = lastStatusAt
        self.emojis = emojis
        self.fields = fields
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        acct = try container.decode(String.self, forKey: .acct)
        displayName = try container.decode(String.self, forKey: .displayName)
        locked = try container.decode(Bool.self, forKey: .locked)
        bot = try container.decode(Bool.self, forKey: .bot)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        note = try container.decode(String.self, forKey: .note)
        url = try container.decode(String.self, forKey: .url)
        avatar = try container.decode(String.self, forKey: .avatar)
        avatarStatic = try container.decode(String.self, forKey: .avatarStatic)
        header = try container.decode(String.self, forKey: .header)
        headerStatic = try container.decode(String.self, forKey: .headerStatic)
        followersCount = try container.decode(Int.self, forKey: .followersCount)
        followingCount = try container.decode(Int.self, forKey: .followingCount)
        statusesCount = try container.decode(Int.self, forKey: .statusesCount)
        lastStatusAt = try container.decodeIfPresent(String.self, forKey: .lastStatusAt)
        emojis = try container.decode([CustomEmoji].self, forKey: .emojis)
        fields = try container.decodeIfPresent([Field].self, forKey: .fields) ?? []
        source = try container.decodeIfPresent(AccountSource.self, forKey: .source)
    }
    
    var avatarURL: URL? {
        URL(string: avatar)
    }
    
    var headerURL: URL? {
        URL(string: header)
    }

    var preferredNote: String {
        if let sourceNote = source?.note,
           !sourceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sourceNote
        }
        return note
    }

    var preferredFields: [Field] {
        if !fields.isEmpty {
            return fields
        }
        return source?.fields ?? []
    }
}

struct AccountSource: Codable, Hashable, Sendable {
    let note: String?
    let fields: [Field]?
}

// MARK: - Field (Profile fields)

struct Field: Codable, Hashable, Sendable {
    let name: String
    let value: String
    let verifiedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case name, value
        case verifiedAt = "verified_at"
    }

    init(name: String, value: String, verifiedAt: Date?) {
        self.name = name
        self.value = value
        self.verifiedAt = verifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)

        if let decodedDate = try? container.decode(Date.self, forKey: .verifiedAt) {
            verifiedAt = decodedDate
            return
        }

        guard let decodedDateString = try? container.decode(String.self, forKey: .verifiedAt),
              !decodedDateString.isEmpty else {
            verifiedAt = nil
            return
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: decodedDateString) {
            verifiedAt = parsed
            return
        }

        formatter.formatOptions = [.withInternetDateTime]
        verifiedAt = formatter.date(from: decodedDateString)
    }
}

// MARK: - Media Attachment

struct MediaAttachment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: MediaType
    let url: String
    let previewUrl: String?
    let remoteUrl: String?
    let description: String?
    let blurhash: String?
    let meta: MediaMeta?
    
    enum CodingKeys: String, CodingKey {
        case id, type, url, description, blurhash, meta
        case previewUrl = "preview_url"
        case remoteUrl = "remote_url"
    }
}

enum MediaType: String, Codable, Sendable {
    case image
    case video
    case gifv
    case audio
    case unknown
}

struct MediaMeta: Codable, Hashable, Sendable {
    let original: MediaDimensions?
    let small: MediaDimensions?
    let focus: MediaFocus?
}

struct MediaDimensions: Codable, Hashable, Sendable {
    let width: Int?
    let height: Int?
    let size: String?
    let aspect: Double?
}

struct MediaFocus: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
}

// MARK: - Preview Card (Link cards)

struct PreviewCard: Codable, Hashable, Sendable {
    let url: String
    let title: String
    let description: String
    let type: CardType
    let authorName: String?
    let authorUrl: String?
    let providerName: String?
    let providerUrl: String?
    let html: String?
    let width: Int?
    let height: Int?
    let image: String?
    let blurhash: String?
    let embedUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case url, title, description, type, html, width, height, image, blurhash
        case authorName = "author_name"
        case authorUrl = "author_url"
        case providerName = "provider_name"
        case providerUrl = "provider_url"
        case embedUrl = "embed_url"
    }
    
    nonisolated var imageURL: URL? {
        guard let image else { return nil }
        return URL(string: image)
    }
    
    nonisolated var linkURL: URL? {
        URL(string: url)
    }
}

enum CardType: String, Codable, Sendable {
    case link
    case photo
    case video
    case rich
}

// MARK: - Mention

struct Mention: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let username: String
    let acct: String
    let url: String
}

// MARK: - Tag (Hashtag)

struct Tag: Codable, Hashable, Sendable {
    let name: String
    let url: String
    let history: [TagHistory]?
}

struct TagHistory: Codable, Hashable, Sendable {
    let day: String
    let uses: String
    let accounts: String
}

// MARK: - Custom Emoji

struct CustomEmoji: Codable, Hashable, Sendable {
    let shortcode: String
    let url: String
    let staticUrl: String
    let visibleInPicker: Bool
    let category: String?
    
    enum CodingKeys: String, CodingKey {
        case shortcode, url, category
        case staticUrl = "static_url"
        case visibleInPicker = "visible_in_picker"
    }
}

// MARK: - Poll

struct Poll: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let expiresAt: Date?
    let expired: Bool
    let multiple: Bool
    let votesCount: Int
    let votersCount: Int?
    let options: [PollOption]
    let voted: Bool?
    let ownVotes: [Int]?
    let emojis: [CustomEmoji]
    
    enum CodingKeys: String, CodingKey {
        case id, expired, multiple, options, voted, emojis
        case expiresAt = "expires_at"
        case votesCount = "votes_count"
        case votersCount = "voters_count"
        case ownVotes = "own_votes"
    }
}

struct PollOption: Codable, Hashable, Sendable {
    let title: String
    let votesCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case title
        case votesCount = "votes_count"
    }
}

// MARK: - Application

struct Application: Codable, Hashable, Sendable {
    let name: String
    let website: String?
}

// MARK: - Notification

struct MastodonNotification: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: NotificationType
    let createdAt: Date
    let account: MastodonAccount
    let status: Status?
    
    enum CodingKeys: String, CodingKey {
        case id, type, account, status
        case createdAt = "created_at"
    }
}

enum NotificationType: String, Codable, Sendable {
    case mention
    case status
    case reblog
    case follow
    case followRequest = "follow_request"
    case favourite
    case poll
    case update
    case adminSignUp = "admin.sign_up"
    case adminReport = "admin.report"
}

// MARK: - Conversation

struct MastodonConversation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let unread: Bool?
    let accounts: [MastodonAccount]
    let lastStatus: Status?

    enum CodingKeys: String, CodingKey {
        case id, unread, accounts
        case lastStatus = "last_status"
    }
}

// MARK: - Context (Thread)

struct Context: Codable, Sendable {
    let ancestors: [Status]
    let descendants: [Status]
}

// MARK: - Relationship

struct Relationship: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let following: Bool
    let showingReblogs: Bool
    let notifying: Bool
    let followedBy: Bool
    let blocking: Bool
    let blockedBy: Bool
    let muting: Bool
    let mutingNotifications: Bool
    let requested: Bool
    let domainBlocking: Bool
    let endorsed: Bool
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case id, following, notifying, blocking, muting, requested, endorsed, note
        case showingReblogs = "showing_reblogs"
        case followedBy = "followed_by"
        case blockedBy = "blocked_by"
        case mutingNotifications = "muting_notifications"
        case domainBlocking = "domain_blocking"
    }
}

// MARK: - Instance Info

struct Instance: Codable, Sendable {
    let uri: String
    let title: String
    let shortDescription: String?
    let description: String
    let email: String?
    let version: String
    let urls: InstanceURLs?
    let stats: InstanceStats?
    let thumbnail: String?
    let languages: [String]?
    let registrations: Bool?
    let approvalRequired: Bool?
    let invitesEnabled: Bool?
    let configuration: InstanceConfiguration?
    let contactAccount: MastodonAccount?
    let rules: [InstanceRule]?
    
    enum CodingKeys: String, CodingKey {
        case uri, title, description, email, version, urls, stats, thumbnail, languages, registrations, configuration, rules
        case shortDescription = "short_description"
        case approvalRequired = "approval_required"
        case invitesEnabled = "invites_enabled"
        case contactAccount = "contact_account"
    }
}

struct InstanceURLs: Codable, Sendable {
    let streamingApi: String?
    
    enum CodingKeys: String, CodingKey {
        case streamingApi = "streaming_api"
    }
}

struct InstanceStats: Codable, Sendable {
    let userCount: Int?
    let statusCount: Int?
    let domainCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case userCount = "user_count"
        case statusCount = "status_count"
        case domainCount = "domain_count"
    }
}

struct InstanceConfiguration: Codable, Sendable {
    let statuses: StatusConfiguration?
    let mediaAttachments: MediaConfiguration?
    let polls: PollConfiguration?
}

struct StatusConfiguration: Codable, Sendable {
    let maxCharacters: Int?
    let maxMediaAttachments: Int?
    let charactersReservedPerUrl: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxCharacters = "max_characters"
        case maxMediaAttachments = "max_media_attachments"
        case charactersReservedPerUrl = "characters_reserved_per_url"
    }
}

struct MediaConfiguration: Codable, Sendable {
    let supportedMimeTypes: [String]?
    let imageSizeLimit: Int?
    let imageMatrixLimit: Int?
    let videoSizeLimit: Int?
    let videoFrameRateLimit: Int?
    let videoMatrixLimit: Int?
    
    enum CodingKeys: String, CodingKey {
        case supportedMimeTypes = "supported_mime_types"
        case imageSizeLimit = "image_size_limit"
        case imageMatrixLimit = "image_matrix_limit"
        case videoSizeLimit = "video_size_limit"
        case videoFrameRateLimit = "video_frame_rate_limit"
        case videoMatrixLimit = "video_matrix_limit"
    }
}

struct PollConfiguration: Codable, Sendable {
    let maxOptions: Int?
    let maxCharactersPerOption: Int?
    let minExpiration: Int?
    let maxExpiration: Int?
    
    enum CodingKeys: String, CodingKey {
        case maxOptions = "max_options"
        case maxCharactersPerOption = "max_characters_per_option"
        case minExpiration = "min_expiration"
        case maxExpiration = "max_expiration"
    }
}

struct InstanceRule: Codable, Identifiable, Sendable {
    let id: String
    let text: String
}

// MARK: - Trending

struct TrendingLink: Codable, Hashable, Sendable {
    let url: String
    let title: String
    let description: String
    let type: CardType
    let authorName: String?
    let authorUrl: String?
    let providerName: String?
    let providerUrl: String?
    let html: String?
    let width: Int?
    let height: Int?
    let image: String?
    let blurhash: String?
    let history: [TagHistory]?
    
    enum CodingKeys: String, CodingKey {
        case url, title, description, type, html, width, height, image, blurhash, history
        case authorName = "author_name"
        case authorUrl = "author_url"
        case providerName = "provider_name"
        case providerUrl = "provider_url"
    }
    
    var imageURL: URL? {
        guard let image else { return nil }
        return URL(string: image)
    }
    
    var linkURL: URL? {
        URL(string: url)
    }
}

struct TrendingTag: Codable, Hashable, Sendable {
    let name: String
    let url: String
    let history: [TagHistory]
}

// MARK: - OAuth Types

struct OAuthApplication: Codable, Sendable {
    let id: String
    let name: String
    let website: String?
    let redirectUri: String
    let clientId: String
    let clientSecret: String
    let vapidKey: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, website
        case redirectUri = "redirect_uri"
        case clientId = "client_id"
        case clientSecret = "client_secret"
        case vapidKey = "vapid_key"
    }
}

struct OAuthToken: Codable, Sendable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let createdAt: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case createdAt = "created_at"
    }
}

// MARK: - Search Results

struct SearchResults: Codable, Sendable {
    let accounts: [MastodonAccount]
    let statuses: [Status]
    let hashtags: [Tag]
}

// MARK: - Async Refresh Header

/// Parsed `Mastodon-Async-Refresh` header: `id="<string>", retry=<int>, result_count=<int>` (result_count optional).
struct AsyncRefreshHeader: Sendable {
    let id: String
    let retrySeconds: Int
    let resultCount: Int?
    
    /// Parses the raw header value. Returns nil if missing or malformed.
    static func parse(headerValue: String?) -> AsyncRefreshHeader? {
        guard let raw = headerValue?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        var id: String?
        var retrySeconds: Int?
        var resultCount: Int?
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            if part.hasPrefix("id=\"") && part.hasSuffix("\"") {
                let start = part.index(part.startIndex, offsetBy: 4)
                let end = part.index(part.endIndex, offsetBy: -1)
                id = String(part[start..<end])
            } else if part.hasPrefix("retry=") {
                retrySeconds = Int(part.dropFirst(6))
            } else if part.hasPrefix("result_count=") {
                resultCount = Int(part.dropFirst(13))
            }
        }
        guard let id = id, let retry = retrySeconds, !id.isEmpty, retry > 0 else { return nil }
        return AsyncRefreshHeader(id: id, retrySeconds: retry, resultCount: resultCount)
    }
}

// MARK: - Async Refresh (API entity)

struct AsyncRefresh: Codable, Sendable {
    let id: String
    let status: String // "running" | "finished"
    let resultCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case resultCount = "result_count"
    }
    
    init(id: String, status: String, resultCount: Int? = nil) {
        self.id = id
        self.status = status
        self.resultCount = resultCount
    }
}

struct AsyncRefreshResponse: Codable, Sendable {
    let asyncRefresh: AsyncRefresh
    
    enum CodingKeys: String, CodingKey {
        case asyncRefresh = "async_refresh"
    }
}

// MARK: - Status Context

struct StatusContext: Codable, Sendable {
    let ancestors: [Status]
    let descendants: [Status]
    let hasMoreReplies: Bool?
    let asyncRefreshId: String?
    
    enum CodingKeys: String, CodingKey {
        case ancestors, descendants
        case hasMoreReplies = "has_more_replies"
        case asyncRefreshId = "async_refresh_id"
    }
    
    init(ancestors: [Status], descendants: [Status], hasMoreReplies: Bool? = nil, asyncRefreshId: String? = nil) {
        self.ancestors = ancestors
        self.descendants = descendants
        self.hasMoreReplies = hasMoreReplies
        self.asyncRefreshId = asyncRefreshId
    }
}

// MARK: - Author Attribution

struct AuthorAttribution: Sendable {
    let name: String?
    let url: String?
    let source: AttributionSource
    let mastodonHandle: String?  // @username@instance.com format
    let mastodonProfileURL: String?  // https://instance.com/@username
    let profilePictureURL: String?  // Avatar/profile picture URL
    
    nonisolated init(
        name: String? = nil,
        url: String? = nil,
        source: AttributionSource,
        mastodonHandle: String? = nil,
        mastodonProfileURL: String? = nil,
        profilePictureURL: String? = nil
    ) {
        self.name = name
        self.url = url
        self.source = source
        self.mastodonHandle = mastodonHandle
        self.mastodonProfileURL = mastodonProfileURL
        self.profilePictureURL = profilePictureURL
    }
}

enum AttributionSource: Sendable {
    case linkHeader
    case metaTag
    case openGraph
    case jsonLD
    case twitterCard
}

// MARK: - List

struct MastodonList: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let repliesPolicy: RepliesPolicy?
    let exclusive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, exclusive
        case repliesPolicy = "replies_policy"
    }
}

enum RepliesPolicy: String, Codable, Sendable {
    case followed
    case list
    case none
}

import Foundation

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



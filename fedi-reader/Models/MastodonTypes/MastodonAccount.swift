import Foundation

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



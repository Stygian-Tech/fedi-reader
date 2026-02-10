//
//  Account.swift
//  fedi-reader
//
//  Mastodon account model stored in SwiftData
//

import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: String
    var instance: String
    var username: String
    var displayName: String
    var avatarURL: String?
    var headerURL: String?
    var acct: String // username@instance format
    var note: String? // Bio/description
    var followersCount: Int
    var followingCount: Int
    var statusesCount: Int
    var isActive: Bool
    var clientId: String?
    var clientSecret: String?
    var createdAt: Date
    
    // Access token stored separately in Keychain for security
    // This is just a reference key
    var accessTokenKey: String {
        "fedi-reader.token.\(id)"
    }
    
    init(
        id: String,
        instance: String,
        username: String,
        displayName: String,
        avatarURL: String? = nil,
        headerURL: String? = nil,
        acct: String,
        note: String? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        statusesCount: Int = 0,
        isActive: Bool = false,
        clientId: String? = nil,
        clientSecret: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.instance = instance
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.headerURL = headerURL
        self.acct = acct
        self.note = note
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.statusesCount = statusesCount
        self.isActive = isActive
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.createdAt = createdAt
    }
    
    var fullHandle: String {
        "@\(username)@\(instance)"
    }
    
    var instanceURL: URL? {
        URL(string: "https://\(instance)")
    }
    
    // Convert to MastodonAccount for API usage
    var mastodonAccount: MastodonAccount {
        MastodonAccount(
            id: id.components(separatedBy: ":").last ?? id,
            username: username,
            acct: acct,
            displayName: displayName,
            locked: false,
            bot: false,
            createdAt: createdAt,
            note: note ?? "",
            url: "https://\(instance)/@\(username)",
            avatar: avatarURL ?? "",
            avatarStatic: avatarURL ?? "",
            header: headerURL ?? "",
            headerStatic: headerURL ?? "",
            followersCount: followersCount,
            followingCount: followingCount,
            statusesCount: statusesCount,
            lastStatusAt: nil,
            emojis: [],
            fields: [],
            source: nil
        )
    }
}

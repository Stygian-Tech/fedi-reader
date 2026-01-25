//
//  AccountBadgesView.swift
//  fedi-reader
//
//  Reusable component for displaying account badges (bot, locked, etc.)
//

import SwiftUI

struct AccountBadgesView: View {
    let account: MastodonAccount
    let size: BadgeSize
    
    enum BadgeSize {
        case small
        case medium
        case large
        
        var iconSize: Font {
            switch self {
            case .small: return .roundedCaption2
            case .medium: return .roundedCaption
            case .large: return .roundedSubheadline
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if account.bot {
                botBadge
            }
            
            if account.locked {
                lockedBadge
            }
        }
    }
    
    private var botBadge: some View {
        Image(systemName: "cpu")
            .font(size.iconSize)
            .foregroundStyle(.blue)
    }
    
    private var lockedBadge: some View {
        Image(systemName: "lock.fill")
            .font(size.iconSize)
            .foregroundStyle(.orange)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Bot Account")
            AccountBadgesView(
                account: MastodonAccount(
                    id: "1",
                    username: "bot",
                    acct: "bot@example.com",
                    displayName: "Bot Account",
                    locked: false,
                    bot: true,
                    createdAt: Date(),
                    note: "",
                    url: "https://example.com/@bot",
                    avatar: "",
                    avatarStatic: "",
                    header: "",
                    headerStatic: "",
                    followersCount: 0,
                    followingCount: 0,
                    statusesCount: 0,
                    lastStatusAt: nil,
                    emojis: [],
                    fields: []
                ),
                size: .medium
            )
        }
        
        HStack {
            Text("Locked Account")
            AccountBadgesView(
                account: MastodonAccount(
                    id: "2",
                    username: "locked",
                    acct: "locked@example.com",
                    displayName: "Locked Account",
                    locked: true,
                    bot: false,
                    createdAt: Date(),
                    note: "",
                    url: "https://example.com/@locked",
                    avatar: "",
                    avatarStatic: "",
                    header: "",
                    headerStatic: "",
                    followersCount: 0,
                    followingCount: 0,
                    statusesCount: 0,
                    lastStatusAt: nil,
                    emojis: [],
                    fields: []
                ),
                size: .medium
            )
        }
        
        HStack {
            Text("Bot & Locked")
            AccountBadgesView(
                account: MastodonAccount(
                    id: "3",
                    username: "both",
                    acct: "both@example.com",
                    displayName: "Bot & Locked",
                    locked: true,
                    bot: true,
                    createdAt: Date(),
                    note: "",
                    url: "https://example.com/@both",
                    avatar: "",
                    avatarStatic: "",
                    header: "",
                    headerStatic: "",
                    followersCount: 0,
                    followingCount: 0,
                    statusesCount: 0,
                    lastStatusAt: nil,
                    emojis: [],
                    fields: []
                ),
                size: .medium
            )
        }
    }
    .padding()
}

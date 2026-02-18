//
//  ConversationSearchHelpersTests.swift
//  fedi-readerTests
//
//  Tests for PM handle token parsing and exact conversation matching helpers.
//

import Foundation
import Testing
@testable import fedi_reader

@Suite("Conversation Search Helpers Tests")
struct ConversationSearchHelpersTests {
    @Test("Tokenizes handle input with spaces, commas, and newlines")
    func tokenizesHandleInputWithDelimiters() {
        let tokens = HandleInputParser.tokenize("@alice@alpha.social, @bob@beta.social\n@carol@gamma.social ")

        #expect(tokens.completedTokens == ["@alice@alpha.social", "@bob@beta.social", "@carol@gamma.social"])
        #expect(tokens.activeToken == nil)
    }

    @Test("Detects active token separately from completed tokens")
    func tokenizesActiveTokenSeparately() {
        let tokens = HandleInputParser.tokenize("@alice@alpha.social @bo")

        #expect(tokens.completedTokens == ["@alice@alpha.social"])
        #expect(tokens.activeToken == "@bo")
    }

    @Test("Normalizes handles by removing leading at signs")
    func normalizesHandles() {
        let normalized = HandleInputParser.normalizeHandle("@@Alice@Example.COM")

        #expect(normalized == "alice@example.com")
    }

    @Test("Builds resilient search query variants for full handles")
    func buildsSearchQueryVariants() {
        let variants = HandleInputParser.searchQueryVariants(for: "@Alice@Example.COM")

        #expect(variants == ["@Alice@Example.COM", "alice@example.com", "@alice@example.com", "alice"])
    }

    @Test("Matches exact one-on-one conversation by handle set")
    func matchesExactSingleHandleConversation() {
        let me = makeAccount(id: "me", username: "me", acct: "me@local.social", host: "local.social")
        let alice = makeAccount(id: "alice", username: "alice", acct: "alice@alpha.social", host: "alpha.social")
        let bob = makeAccount(id: "bob", username: "bob", acct: "bob@beta.social", host: "beta.social")

        let conversations = [
            makeConversation(id: "one-on-one", accounts: [me, alice]),
            makeConversation(id: "group", accounts: [me, alice, bob])
        ]

        let grouped = ConversationGroupingHelper.groupedConversations(from: conversations, currentAccountId: me.id)
        let matches = ConversationGroupingHelper.exactParticipantMatches(
            in: grouped,
            normalizedHandleSet: ["alice@alpha.social"]
        )

        #expect(matches.count == 1)
        #expect(Set(matches[0].participants.map(\.id)) == Set(["alice"]))
    }

    @Test("Matches exact group conversation by handle set")
    func matchesExactGroupConversation() {
        let me = makeAccount(id: "me", username: "me", acct: "me@local.social", host: "local.social")
        let alice = makeAccount(id: "alice", username: "alice", acct: "alice@alpha.social", host: "alpha.social")
        let bob = makeAccount(id: "bob", username: "bob", acct: "bob@beta.social", host: "beta.social")
        let carol = makeAccount(id: "carol", username: "carol", acct: "carol@gamma.social", host: "gamma.social")

        let conversations = [
            makeConversation(id: "group-exact", accounts: [me, alice, bob]),
            makeConversation(id: "group-superset", accounts: [me, alice, bob, carol])
        ]

        let grouped = ConversationGroupingHelper.groupedConversations(from: conversations, currentAccountId: me.id)
        let matches = ConversationGroupingHelper.exactParticipantMatches(
            in: grouped,
            normalizedHandleSet: ["alice@alpha.social", "bob@beta.social"]
        )

        #expect(matches.count == 1)
        #expect(Set(matches[0].participants.map(\.id)) == Set(["alice", "bob"]))
    }

    @Test("Superset and subset participant sets do not match")
    func doesNotMatchSupersetOrSubset() {
        let me = makeAccount(id: "me", username: "me", acct: "me@local.social", host: "local.social")
        let alice = makeAccount(id: "alice", username: "alice", acct: "alice@alpha.social", host: "alpha.social")
        let bob = makeAccount(id: "bob", username: "bob", acct: "bob@beta.social", host: "beta.social")
        let carol = makeAccount(id: "carol", username: "carol", acct: "carol@gamma.social", host: "gamma.social")

        let subsetOnlyConversation = [
            makeConversation(id: "subset-target", accounts: [me, alice, bob])
        ]
        let groupedSubsetOnly = ConversationGroupingHelper.groupedConversations(
            from: subsetOnlyConversation,
            currentAccountId: me.id
        )
        let subsetMatches = ConversationGroupingHelper.exactParticipantMatches(
            in: groupedSubsetOnly,
            normalizedHandleSet: ["alice@alpha.social"]
        )

        #expect(subsetMatches.isEmpty)

        let supersetOnlyConversation = [
            makeConversation(id: "superset-target", accounts: [me, alice, bob])
        ]
        let groupedSupersetOnly = ConversationGroupingHelper.groupedConversations(
            from: supersetOnlyConversation,
            currentAccountId: me.id
        )
        let supersetMatches = ConversationGroupingHelper.exactParticipantMatches(
            in: groupedSupersetOnly,
            normalizedHandleSet: ["alice@alpha.social", "bob@beta.social", "carol@gamma.social"]
        )

        #expect(supersetMatches.isEmpty)
    }

    @Test("Mention prefix includes recipients once in deterministic order")
    func mentionPrefixIncludesEachRecipientOnce() {
        let alice = makeAccount(id: "alice", username: "alice", acct: "alice@alpha.social", host: "alpha.social")
        let bob = makeAccount(id: "bob", username: "bob", acct: "bob@beta.social", host: "beta.social")

        let prefix = DirectMessageMentionFormatter.mentionPrefix(for: [alice, bob, alice])

        #expect(prefix == "@alice@alpha.social @bob@beta.social")
    }

    @Test("Mention prefix preserves recipient order")
    func mentionPrefixPreservesOrder() {
        let bob = makeAccount(id: "bob", username: "bob", acct: "bob@beta.social", host: "beta.social")
        let alice = makeAccount(id: "alice", username: "alice", acct: "alice@alpha.social", host: "alpha.social")

        let prefix = DirectMessageMentionFormatter.mentionPrefix(for: [bob, alice])

        #expect(prefix == "@bob@beta.social @alice@alpha.social")
    }

    private func makeConversation(id: String, accounts: [MastodonAccount]) -> MastodonConversation {
        let sender = accounts.first ?? makeAccount(id: "fallback", username: "fallback", acct: "fallback", host: "local.social")
        let status = MockStatusFactory.makeStatus(
            id: "status-\(id)",
            account: sender,
            visibility: .direct
        )
        return MastodonConversation(
            id: id,
            unread: false,
            accounts: accounts,
            lastStatus: status
        )
    }

    private func makeAccount(
        id: String,
        username: String,
        acct: String,
        host: String
    ) -> MastodonAccount {
        MastodonAccount(
            id: id,
            username: username,
            acct: acct,
            displayName: username.capitalized,
            locked: false,
            bot: false,
            createdAt: Date(),
            note: "",
            url: "https://\(host)/@\(username)",
            avatar: "https://example.com/avatar-\(id).png",
            avatarStatic: "https://example.com/avatar-\(id).png",
            header: "https://example.com/header-\(id).png",
            headerStatic: "https://example.com/header-\(id).png",
            followersCount: 0,
            followingCount: 0,
            statusesCount: 0,
            lastStatusAt: nil,
            emojis: [],
            fields: [],
            source: nil
        )
    }
}

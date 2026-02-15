//
//  PaginatedAccountListTests.swift
//  fedi-readerTests
//
//  Tests for follower/following paginated list merge behavior.
//

import Foundation
import Testing
@testable import fedi_reader

@Suite("Paginated Account List Tests")
struct PaginatedAccountListTests {
    @Test("Initial short page ends pagination")
    func initialShortPageEndsPagination() {
        let incoming = [makeAccount(id: "3"), makeAccount(id: "2"), makeAccount(id: "1")]

        let result = PaginatedAccountList.merge(
            existing: [],
            incoming: incoming,
            requestedMaxId: nil,
            pageSize: 40
        )

        #expect(result.mergedAccounts.map(\.id) == ["3", "2", "1"])
        #expect(result.nextMaxId == "1")
        #expect(result.hasMore == false)
    }

    @Test("Full unique page keeps pagination enabled")
    func fullUniquePageKeepsPaginationEnabled() {
        let incoming = (1...40).map { makeAccount(id: "\($0)") }

        let result = PaginatedAccountList.merge(
            existing: [],
            incoming: incoming,
            requestedMaxId: nil,
            pageSize: 40
        )

        #expect(result.mergedAccounts.count == 40)
        #expect(result.hasMore == true)
    }

    @Test("Duplicate incoming page is ignored and pagination stops")
    func duplicateIncomingPageStopsPagination() {
        let existing = [makeAccount(id: "4"), makeAccount(id: "3"), makeAccount(id: "2"), makeAccount(id: "1")]
        let incoming = [makeAccount(id: "4"), makeAccount(id: "3"), makeAccount(id: "2"), makeAccount(id: "1")]

        let result = PaginatedAccountList.merge(
            existing: existing,
            incoming: incoming,
            requestedMaxId: "1",
            pageSize: 4
        )

        #expect(result.mergedAccounts.count == 4)
        #expect(result.hasMore == false)
    }

    @Test("Repeated cursor stops pagination")
    func repeatedCursorStopsPagination() {
        let existing = [makeAccount(id: "5"), makeAccount(id: "4"), makeAccount(id: "3")]
        let incoming = [makeAccount(id: "2"), makeAccount(id: "1"), makeAccount(id: "3")]

        let result = PaginatedAccountList.merge(
            existing: existing,
            incoming: incoming,
            requestedMaxId: "3",
            pageSize: 3
        )

        #expect(result.nextMaxId == "3")
        #expect(result.hasMore == false)
    }

    private func makeAccount(id: String) -> MastodonAccount {
        MastodonAccount(
            id: id,
            username: "user\(id)",
            acct: "user\(id)@example.com",
            displayName: "User \(id)",
            locked: false,
            bot: false,
            createdAt: Date(),
            note: "",
            url: "https://example.com/@user\(id)",
            avatar: "",
            avatarStatic: "",
            header: "",
            headerStatic: "",
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

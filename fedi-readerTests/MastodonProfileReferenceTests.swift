import Testing
import Foundation
@testable import fedi_reader

@Suite("Mastodon Profile Reference Tests")
struct MastodonProfileReferenceTests {

    @Test("Normalizes handles with or without leading at sign")
    func normalizesHandles() {
        #expect(MastodonProfileReference.normalizedAcct(from: "@alice@mastodon.social") == "alice@mastodon.social")
        #expect(MastodonProfileReference.normalizedAcct(from: "alice@mastodon.social") == "alice@mastodon.social")
    }

    @Test("Parses Mastodon style at-sign profile URLs")
    func parsesAtSignProfileURLs() {
        let url = URL(string: "https://mastodon.social/@alice")!

        #expect(MastodonProfileReference.acct(from: url) == "alice@mastodon.social")
    }

    @Test("Parses users profile URLs")
    func parsesUsersProfileURLs() {
        let url = URL(string: "https://hachyderm.io/users/alice")!

        #expect(MastodonProfileReference.acct(from: url) == "alice@hachyderm.io")
    }

    @Test("Prefers explicit handles over URLs")
    func prefersHandleWhenBothHandleAndURLExist() {
        let url = URL(string: "https://example.com/@ignored")!

        #expect(
            MastodonProfileReference.acct(
                handle: "@alice@mastodon.social",
                profileURL: url
            ) == "alice@mastodon.social"
        )
    }
}

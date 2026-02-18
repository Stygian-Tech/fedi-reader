import Foundation

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



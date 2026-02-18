import Foundation

enum Constants {
    // MARK: - App Info
    
    nonisolated static let appName = "Fedi Reader"
    static let appBundleId = "app.fedi-reader"
    nonisolated static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    nonisolated static let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - OAuth
    
    enum OAuth {
        static let redirectScheme = "fedi-reader"
        static let redirectHost = "oauth"
        static let redirectURI = "\(redirectScheme)://\(redirectHost)/callback"
        
        static let scopes = "read write follow push"
        
        nonisolated static let appWebsite = "https://github.com/stygian-tech/fedi-reader"
    }
    
    // MARK: - API
    
    enum API {
        static let defaultTimeout: TimeInterval = 30
        static let uploadTimeout: TimeInterval = 120
        
        // Mastodon API paths
        static let apps = "/api/v1/apps"
        static let oauthAuthorize = "/oauth/authorize"
        static let oauthToken = "/oauth/token"
        static let oauthRevoke = "/oauth/revoke"
        
        static let verifyCredentials = "/api/v1/accounts/verify_credentials"
        static let homeTimeline = "/api/v1/timelines/home"
        static let publicTimeline = "/api/v1/timelines/public"
        static let notifications = "/api/v1/notifications"
        static let conversations = "/api/v1/conversations"
        static let conversationRead = "/api/v1/conversations" // Use with /:id/read
        
        static let statuses = "/api/v1/statuses"
        static let asyncRefreshes = "/api/v1_alpha/async_refreshes"
        static let accounts = "/api/v1/accounts"
        static let search = "/api/v2/search"
        
        static let instance = "/api/v1/instance"
        static let instanceV2 = "/api/v2/instance"
        static let customEmojis = "/api/v1/custom_emojis"
        
        static let trendingStatuses = "/api/v1/trends/statuses"
        static let trendingTags = "/api/v1/trends/tags"
        static let trendingLinks = "/api/v1/trends/links"
        
        // Lists
        static let lists = "/api/v1/lists"
        static let listTimeline = "/api/v1/timelines/list"
        
        // Rate limiting
        static let defaultRateLimit = 300 // requests per 5 minutes
        static let rateLimitWindow: TimeInterval = 300 // 5 minutes
    }
    
    // MARK: - Pagination
    
    enum Pagination {
        nonisolated static let defaultLimit = 40
        nonisolated static let maxLimit = 80
        nonisolated static let prefetchThreshold = 10 // Load more when this many items from end
    }
    
    // MARK: - Cache
    
    enum Cache {
        static let maxStatusAge: TimeInterval = 60 * 60 * 24 * 7 // 7 days
        static let maxCachedStatuses = 1000
        static let imageMemoryCacheLimit = 100 * 1024 * 1024 // 100 MB
        static let imageDiskCacheLimit = 500 * 1024 * 1024 // 500 MB
        static let listsRefreshInterval: TimeInterval = 60 * 60 // 1 hour
    }
    
    // MARK: - UI
    
    enum UI {
        static let defaultAnimationDuration: Double = 0.3
        static let hapticFeedbackEnabled = true
        static let maxContentPreviewLines = 6
        static let avatarSize: CGFloat = 40
        static let smallAvatarSize: CGFloat = 28
        static let cardImageHeight: CGFloat = 180
        static let cardCornerRadius: CGFloat = 12
        nonisolated static let messagesAutoRefreshInterval: TimeInterval = 8
    }
    
    // MARK: - Read Later Services
    
    enum ReadLater {
        // Pocket
        static let pocketConsumerKey = "" // User must provide their own
        static let pocketAuthURL = "https://getpocket.com/v3/oauth/request"
        static let pocketAuthorizeURL = "https://getpocket.com/auth/authorize"
        static let pocketAccessTokenURL = "https://getpocket.com/v3/oauth/authorize"
        static let pocketAddURL = "https://getpocket.com/v3/add"
        
        // Instapaper
        static let instapaperAuthURL = "https://www.instapaper.com/api/1/oauth/access_token"
        static let instapaperAddURL = "https://www.instapaper.com/api/add"
        
        // Omnivore
        static let omnivoreAPIURL = "https://api-prod.omnivore.app/api/graphql"
        
        // Readwise Reader
        static let readwiseAPIURL = "https://readwise.io/api/v3"
        static let readwiseSaveURL = "https://readwise.io/api/v3/save/"
        
        // Raindrop.io
        static let raindropAuthURL = "https://raindrop.io/oauth/authorize"
        static let raindropTokenURL = "https://raindrop.io/oauth/access_token"
        static let raindropAPIURL = "https://api.raindrop.io/rest/v1"
    }
    
    // MARK: - Author Attribution Headers
    
    enum Attribution {
        static let linkHeaderRel = "author"
        static let metaAuthor = "author"
        static let ogAuthor = "og:article:author"
        static let ogSiteName = "og:site_name"
        static let twitterCreator = "twitter:creator"
        static let articleAuthor = "article:author"
        
        static let jsonLDTypes = ["Person", "Organization"]
        
        // Headers to check in HEAD request
        static let headersToCheck = [
            "Link",
            "X-Author",
            "Author"
        ]
    }
    
    // MARK: - User Agent
    
    static nonisolated var userAgent: String {
        "\(appName)/\(appVersion) (+\(OAuth.appWebsite))"
    }
    
    // MARK: - ActivityPub
    
    enum ActivityPub {
        static let acceptHeader = "application/activity+json, application/ld+json; profile=\"https://www.w3.org/ns/activitystreams\""
        static let contentType = "application/activity+json"
    }
    
    // MARK: - Remote Replies
    
    enum RemoteReplies {
        static let asyncRefreshHeader = "Mastodon-Async-Refresh"
        static let fetchTimeout: TimeInterval = 10
        static let maxConcurrentFetches = 5
        static let maxRetries = 2
        /// Fallback retry interval when server provides only async_refresh_id without header metadata.
        static let asyncRefreshFallbackRetrySeconds = 5
        /// Max polling attempts for async refresh before giving up (~2 min at typical retry=5–10s).
        static let asyncRefreshMaxPollAttempts = 15
    }
}

// MARK: - Notification Names



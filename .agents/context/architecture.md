# Fedi Reader — Architecture

Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.

## Data Flow

```
MastodonClient (OAuth + REST)
  → TimelineService (fetch & paginate)
    → LinkFilterService (extract link-only posts)
      → AttributionChecker (enrich with author metadata)
  → ReadLaterManager (save to Pocket/Instapaper/Omnivore/Readwise/Raindrop)
```

## Key Services

| Service | Purpose |
|---------|---------|
| `MastodonClient` | OAuth 2.0 flow, authenticated REST calls, rate limiting |
| `AuthService` | Account management, credential storage, OAuth flow |
| `TimelineService` | Timeline fetching with `maxId`/`minId` pagination |
| `LinkFilterService` | Link extraction, domain filtering, per-feed caching |
| `AttributionChecker` | Author extraction via Link headers, OG tags, JSON-LD |
| `AppState` | Global observable state (navigation, sheets, errors) |
| `ReadLaterManager` | Unified interface to 5 read-later service adapters |
| `EmojiService` | Custom emoji caching per Mastodon instance |

## File Layout

```
fedi-reader/
├── App/                    # FediReaderApp.swift (entry point, SwiftData ModelContainer)
├── Models/                 # SwiftData models (Account, CachedStatus, ReadLaterConfig)
│                           # + MastodonTypes.swift (API types with CodingKeys)
├── Services/               # @Observable @MainActor service classes
│   └── ReadLater/          # Protocol-based adapters (Pocket, Instapaper, etc.)
├── Views/                  # SwiftUI views by feature
│   ├── Actions/            # ComposeView, StatusActionsView
│   ├── Auth/               # LoginView, ReadLaterLoginView
│   ├── Components/         # Reusable UI (avatars, badges, thread view, filters)
│   ├── Feed/               # LinkFeedView, ExploreFeedView, MentionsView, StatusDetailView
│   ├── Profile/            # ProfileView, AccountSettingsView, followers/following
│   ├── Root/               # ContentView, MainTabView, WelcomeView
│   ├── Settings/           # SettingsView, ReadLaterSettingsView
│   └── Web/                # ArticleWebView, WebViewComponents
└── Utilities/              # HTMLParser, KeychainHelper, Constants, TimeFormatter
```

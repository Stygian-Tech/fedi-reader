# CLAUDE.md — Fedi Reader

Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.

## Build & Test Commands

```bash
# Build (iOS Simulator)
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build

# Run all tests
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test

# Unit tests only
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests test

# Single test suite
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests/HTMLParserTests test

# Single test method
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests/HTMLParserTests/extractsLinks test

# Clean
xcodebuild -scheme "fedi-reader" clean
```

## Architecture

Flat, service-oriented design. Views consume `@Observable` services directly via `@Environment` — no ViewModels.

### Data Flow

```
MastodonClient (OAuth + REST)
  → TimelineService (fetch & paginate)
    → LinkFilterService (extract link-only posts)
      → AttributionChecker (enrich with author metadata)
  → ReadLaterManager (save to Pocket/Instapaper/Omnivore/Readwise/Raindrop)
```

### Key Services

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

## Code Conventions

### Patterns to Follow

- **Service classes**: `@Observable @MainActor final class`
- **Dependency injection**: Services created in `ContentView`, passed via `@Environment`
- **Concurrency**: `async`/`await` throughout, no Combine
- **Error handling**: Guard-based early returns; errors as enums conforming to `LocalizedError`
- **Logging**: `Logger(subsystem: "app.fedi-reader", category: "ServiceName")`
- **API types**: `Codable` structs with `CodingKeys` mapping snake_case JSON
- **SwiftData models**: `@Model final class` with `@Attribute(.unique)` for IDs
- **Section organization**: `// MARK: -` comments to group related code

### Testing

- **Framework**: Swift Testing (`import Testing`, `@Test`, `@Suite`) — not XCTest
- **Assertions**: `#expect()` — not `XCTAssert`
- **Mocks**: `MockURLProtocol` for network isolation; `MockStatusFactory` for domain objects
- **Test files**: `fedi-readerTests/` directory, ~2,100 LOC across 11 test files

### Style

- No linter or formatter configured (no SwiftLint/SwiftFormat)
- PascalCase for types, camelCase for properties/methods
- No external dependencies — all functionality via Apple frameworks

## Linear workflow

Branches are linked to Linear issues via the branch name (e.g. `FED-123-feature-name`, `sam/FED-456-fix`). Follow this workflow:

1. **Check for linked issue**: When starting work, parse the current branch name for a Linear issue ID (e.g. `FED-123`, `PROJ-456`). Use Linear MCP `get_issue` or `list_issues` to confirm the issue exists.

2. **Set In Progress**: If the issue exists, update it to **In Progress** via `save_issue` with `state: "In Progress"` (or equivalent state name in your workspace).

3. **Add comments as you work**: Use `create_comment` to describe the work being done—what was implemented, key decisions, or blockers. This keeps the issue history useful for PR review and future reference.

4. **Do not mark Done**: Let the Linear–GitHub integration set Done when the PR is merged. Manually setting Done bypasses that flow. PRs opened in GitHub will drive status updates from here.

## Configuration

- **URL scheme**: `fedi-reader://` (OAuth callbacks, registered in Info.plist)
- **Credentials**: Stored in Keychain via `KeychainHelper`
- **Targets**: iOS 26.0+ / macOS 26.0+, Xcode 26.0+
- **No CI/CD** pipeline configured
- **BSP**: `buildServer.json` for IDE build-server integration

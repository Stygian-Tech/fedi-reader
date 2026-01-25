# Fedi Reader – Agent Context

Link-focused Mastodon news reader for iOS and macOS. SwiftUI + SwiftData, `@Observable` service classes, no MVVM view models. Views consume Observable services directly.

## Dev environment

- **Xcode** 16.0+
- Open [fedi-reader.xcodeproj](fedi-reader.xcodeproj), scheme **fedi-reader**
- [buildServer.json](buildServer.json) configures BSP for IDE/build-server integration

## Build and run

- **Build** (iOS Simulator):
  ```bash
  xcodebuild -scheme "fedi-reader" -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build
  ```
- **Run all tests**:
  ```bash
  xcodebuild -scheme "fedi-reader" -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' test
  ```
- **Unit tests only**: `-only-testing:fedi-readerTests`
- **UI tests only**: `-only-testing:fedi-readerUITests`

For more commands (clean, single-suite/single-test runs), see [WARP.md](WARP.md).

## Architecture

Flat, service-oriented design:

- **Services**: `MastodonClient` (OAuth + REST), `AuthService`, `TimelineService`, `LinkFilterService`, `AttributionChecker`, `ReadLaterManager` (Pocket, Instapaper, Omnivore, Readwise Reader, Raindrop), `AppState`
- **Models**: SwiftData (`Account`, `CachedStatus`, `ReadLaterConfig`) + Mastodon API types in [MastodonTypes.swift](fedi-reader/Models/MastodonTypes.swift)
- **Views**: [Views/](fedi-reader/Views/) by feature — Auth, Feed, Profile, Settings, Web, Actions, Root

Data flow: MastodonClient → TimelineService → LinkFilterService (link-focused feed); AttributionChecker enriches links; ReadLaterManager saves to read-later providers.

## Code and testing

- **Swift** 5.9+, `@Observable` + `@MainActor`, `async`/`await`
- **Tests**: Swift Testing (`import Testing`, `@Test` / `@Suite`). Unit tests in `fedi-readerTests`, UI tests in `fedi-readerUITests`. MockURLProtocol for network; mock factories for domain objects.
- No SwiftLint/SwiftFormat.

## File layout

```
fedi-reader/
├── App/                    # Entry point (FediReaderApp.swift)
├── Models/                 # SwiftData models & Mastodon API types
├── Services/               # @Observable service classes
│   └── ReadLater/          # Read-later integrations
├── Views/                  # SwiftUI by feature
│   ├── Actions/            # Post actions & composer
│   ├── Auth/               # Login
│   ├── Feed/               # Timelines, explore, mentions
│   ├── Profile/            # Account & profile
│   ├── Root/               # Main container, tabs
│   ├── Settings/           # Settings
│   └── Web/                # Article web viewer
└── Utilities/              # HTMLParser, KeychainHelper, etc.
```

## Configuration

- **URL scheme**: `fedi-reader://` for OAuth callbacks
- **Read-later**: Configure in-app (Profile → Read Later Services). Credentials in Keychain; no analytics; HTTPS-only.

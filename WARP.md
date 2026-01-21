# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Commands

- Discover available schemes (useful if scheme names change):
  ```bash
  xcodebuild -list -json | jq '.'
  ```
- Open the project in Xcode:
  ```bash
  open fedi-reader.xcodeproj
  ```
- Build (iOS Simulator):
  ```bash
  xcodebuild \
    -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    build
  ```
- Clean build artifacts:
  ```bash
  xcodebuild -scheme "fedi-reader" clean
  ```
- Run all unit tests (iOS Simulator):
  ```bash
  xcodebuild \
    -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    test
  ```
- Run only the unit-test target:
  ```bash
  xcodebuild \
    -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:fedi-readerTests \
    test
  ```
- Run a single test suite or test (example):
  ```bash
  # Suite
  xcodebuild -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:fedi-readerTests/HTMLParserTests \
    test

  # Single test method
  xcodebuild -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:fedi-readerTests/HTMLParserTests/extractsLinks \
    test
  ```
- Run UI tests only:
  ```bash
  xcodebuild \
    -scheme "fedi-reader" \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:fedi-readerUITests \
    test
  ```

Notes
- No repository-configured linter/formatter (e.g., SwiftLint/SwiftFormat) is present.
- Building for a physical device will require setting a valid signing team; Simulator builds do not.

## High-level Architecture

This is a SwiftUI app that prefers a flat, service-oriented design using @Observable services. Views consume these services directly rather than via classic MVVM view models.

Core modules (big picture)
- App (App/FediReaderApp.swift): Entry point and top-level composition.
- Services (Services/*):
  - MastodonClient: OAuth 2.0 + REST client for Mastodon.
  - AuthService: Sign-in state and flows.
  - TimelineService: Fetch, paginate, and manage timelines.
  - LinkFilterService: Reduce a timeline to posts that include external links; also extracts and filters domains.
  - AttributionChecker: Derives author metadata from linked pages (link headers, meta tags, Open Graph, JSON-LD, Twitter cards).
  - ReadLater (Services/ReadLater/*): Adapters for Pocket, Instapaper, Omnivore, Readwise Reader, Raindrop via a unified ReadLaterManager.
  - AppState: Shared application state container.
- Models (Models/*): SwiftData models and Mastodon API types used across services and views.
- Utilities (Utilities/*): Cross-cutting helpers such as HTMLParser, KeychainHelper, TimeFormatter, font and constants.
- Views (Views/*): SwiftUI screens grouped by feature (Auth, Feed, Profile, Settings, Web, Actions, Root). Views bind to services and models directly.

Data flow (typical)
- MastodonClient handles authenticated HTTP calls.
- TimelineService retrieves raw statuses and hands them to LinkFilterService to derive a link-focused feed.
- AttributionChecker enriches link entries with author data where available.
- ReadLaterManager exposes a consistent interface for saving to third-party read-later providers.
- Views render the link-first experience and expose Mastodon interactions (favorite, boost, reply, bookmark, share).

## Testing

- Framework: Swift Testing (import Testing) with test bundles:
  - fedi-readerTests (unit/component tests)
  - fedi-readerUITests (UI tests)
- Common suites include HTMLParserTests, LinkFilterServiceTests, AttributionCheckerTests, MastodonTypesTests.
- Network behavior is isolated with MockURLProtocol, and domain objects are fabricated via MockStatusFactory for deterministic tests.
- See Commands above for running all tests, a single bundle, a suite, or a single test.

## Configuration & Behavior (from README)

- URL scheme: The app registers the custom scheme `fedi-reader://` for OAuth callbacks.
- Read-later services: Pocket, Instapaper, Omnivore, Readwise Reader, Raindrop are supported via in-app authentication (Profile → Read Later Services).
- Privacy: Credentials are stored in Keychain; no analytics or tracking; HTTPS-only API access.

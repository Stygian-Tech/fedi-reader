# Fedi Reader

A link-focused Mastodon news reader for iOS and macOS. Fedi Reader filters your home timeline to show only posts containing external links, making it easy to discover articles and content shared by people you follow.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2026%20%7C%20macOS%2026-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

### Link-Focused Feed
- Automatically filters your home timeline to posts with external links
- Excludes quote posts and reblogs-with-comment to focus on original link shares
- Displays rich link cards with images, titles, and descriptions
- Filter by domain to focus on specific sources

### Author Attribution
- Checks linked articles for author information via HEAD requests
- Supports multiple attribution sources:
  - Link headers with `rel="author"`
  - HTML meta tags (`<meta name="author">`)
  - Open Graph tags (`og:article:author`)
  - JSON-LD structured data
  - Twitter cards (`twitter:creator`)

### Multi-Account Support
- Connect multiple Mastodon accounts
- Quick account switcher
- Secure credential storage in Keychain

### Read Later Integration
Save articles to your favorite read-later service:
- **Pocket**
- **Instapaper**
- **Omnivore**
- **Readwise Reader**
- **Raindrop.io**

### Full Mastodon Interactions
- ⭐ Favorite/Star posts
- 🔄 Boost/Reblog
- 💬 Reply to posts
- 📝 Quote boost (on supporting instances)
- 🔖 Bookmark
- 📤 Share via native share sheet

### Explore Tab
- Trending links on your instance
- Trending posts
- Trending hashtags

### Private Mentions
- Dedicated tab for mentions and direct messages
- Quick reply functionality

### Minimal Web Viewer
- In-app article reading
- Persistent action toolbar for Mastodon interactions
- Quick save to read-later services
- Back/forward navigation

## Requirements

- iOS 26.0+ / macOS 26.0+
- Xcode 16.0+
- Swift 5.9+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/fedi-reader/fedi-reader.git
cd fedi-reader
```

2. Open in Xcode:
```bash
open fedi-reader.xcodeproj
```

3. Build and run on your device or simulator.

## Architecture

Fedi Reader uses Apple's modern **@Observable** pattern with service classes, avoiding traditional MVVM in favor of a flat, service-oriented structure where Views directly consume Observable services.

```
fedi-reader/
├── App/                    # App entry point
├── Models/                 # SwiftData models & API types
├── Services/               # @Observable service classes
│   └── ReadLater/          # Read-later integrations
├── Views/                  # SwiftUI views
│   ├── Actions/            # Post actions & composer
│   ├── Auth/               # Login views
│   ├── Feed/               # Timeline views
│   ├── Profile/            # Profile & account views
│   ├── Root/               # Main container
│   ├── Settings/           # Settings views
│   └── Web/                # Article web viewer
└── Utilities/              # Helpers & constants
```

### Key Services

| Service | Purpose |
|---------|---------|
| `MastodonClient` | Core API client with OAuth 2.0 |
| `AuthService` | Authentication flow management |
| `TimelineService` | Timeline fetching & pagination |
| `LinkFilterService` | Filters posts to links only |
| `AttributionChecker` | Author metadata extraction |
| `ReadLaterManager` | Unified read-later interface |

## Configuration

### Read Later Services

Each read-later service requires authentication:

| Service | Authentication |
|---------|---------------|
| Pocket | Consumer key + OAuth |
| Instapaper | Username/password (xAuth) |
| Omnivore | API key |
| Readwise | Access token |
| Raindrop | OAuth or API token |

Configure services in **Profile → Read Later Services**.

### URL Scheme

Fedi Reader registers the `fedi-reader://` URL scheme for OAuth callbacks.

## Testing

The project includes comprehensive tests using Swift Testing:

```bash
# Run all tests
xcodebuild test -scheme fedi-reader -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Test Coverage

- `LinkFilterServiceTests` - Link filtering logic
- `HTMLParserTests` - HTML parsing and entity decoding
- `AttributionCheckerTests` - Author attribution
- `MastodonTypesTests` - API type encoding/decoding

## ActivityPub Best Practices

Fedi Reader follows ActivityPub and Mastodon API best practices:

- Respects `Cache-Control` headers
- Honors rate limits (`X-RateLimit-*` headers)
- Uses appropriate `Accept` headers for ActivityPub
- Handles federation delays gracefully
- Displays content warnings appropriately
- Proper User-Agent identification

## Privacy

- Credentials are stored securely in the system Keychain
- No analytics or tracking
- No data shared with third parties
- All API communication uses HTTPS

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/) and [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- Uses the [Mastodon API](https://docs.joinmastodon.org/api/)
- Inspired by the Fediverse community

## Support

- [Report Issues](https://github.com/fedi-reader/fedi-reader/issues)
- [Discussions](https://github.com/fedi-reader/fedi-reader/discussions)

---

Made with ❤️ for the Fediverse

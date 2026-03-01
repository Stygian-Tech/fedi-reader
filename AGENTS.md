# Fedi Reader – Agent Context

Link-focused Mastodon news reader for iOS and macOS. SwiftUI + SwiftData, `@Observable` service classes, no MVVM view models. Views consume Observable services directly.

## Context routing

Project context lives under [.agents/](.agents/):

| Task | Read |
|------|------|
| **Starting work** | [.agents/rules/linear-workflow.md](.agents/rules/linear-workflow.md) — **MANDATORY first step** |
| **Architecture** | [.agents/context/architecture.md](.agents/context/architecture.md) |
| **Code style** | [.agents/context/conventions.md](.agents/context/conventions.md) |
| **Build & test** | [.agents/context/build-commands.md](.agents/context/build-commands.md) or [WARP.md](WARP.md) |

## Dev environment

- **Xcode** 26.0+
- Open [fedi-reader.xcodeproj](fedi-reader.xcodeproj), scheme **fedi-reader**
- [buildServer.json](buildServer.json) configures BSP for IDE/build-server integration

## Configuration

- **URL scheme**: `fedi-reader://` for OAuth callbacks
- **Read-later**: Configure in-app (Profile → Read Later Services). Credentials in Keychain; no analytics; HTTPS-only.

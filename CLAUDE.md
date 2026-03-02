# CLAUDE.md — Fedi Reader

Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.

**Agent context is under [.agents/](.agents/).** Read the following as needed:

- **Always first (GATE):** [.agents/rules/linear-workflow.md](.agents/rules/linear-workflow.md) — run `git branch --show-current`, set Linear issue In Progress if FED-XXX in branch, add completion comment before claiming done. Do this before any code edits.
- **Architecture:** [.agents/context/architecture.md](.agents/context/architecture.md)
- **Conventions:** [.agents/context/conventions.md](.agents/context/conventions.md)
- **Build & test:** [.agents/context/build-commands.md](.agents/context/build-commands.md)

See [AGENTS.md](AGENTS.md) for full routing and dev environment.

# Fedi Reader – Agent Instructions

**Single source of truth for all agents.** Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.

## GATE (first action on any request)

**Linear is the source of truth, not GitHub.** Before any code edits or plan creation:

1. Run `git branch --show-current`. Parse for Linear ID (e.g. `FED-123`). Valid patterns: `FED-123-feature-name`, `sam/FED-456-fix`.
2. **If Linear ID found**: Use Linear MCP `get_issue` to confirm, then `save_issue` with `state: "In Progress"` before touching code or creating plans.
3. **If no Linear ID** (e.g. `main`): Proceed without Linear updates.

Apply in **both plan mode and implementation**—do not skip because you are "only planning."

### Full Linear workflow

- **During planning**: Add comments via `create_comment`—when drafting a plan, summarize the approach or key decisions on the Linear issue.
- **While implementing**: Include the full plan via `create_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment. Add comments as you work—implementations, decisions, blockers.
- **Before claiming done**: Add a completion comment via `create_comment`—summarize changes made and how to verify. Do not mark Done—let Linear–GitHub integration set Done when the PR is merged.

## Context routing

| Task                  | Read                                                                                            |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| **Architecture**      | [.agents/context/architecture.md](.agents/context/architecture.md)                               |
| **Code style**        | [.agents/context/conventions.md](.agents/context/conventions.md)                                 |
| **Build & test**      | [.agents/context/build-commands.md](.agents/context/build-commands.md) or [WARP.md](WARP.md)     |

## Dev environment

- **Xcode** 26.0+
- Open [fedi-reader.xcodeproj](fedi-reader.xcodeproj), scheme **fedi-reader**
- [buildServer.json](buildServer.json) configures BSP for IDE/build-server integration

## Configuration

- **URL scheme**: `fedi-reader://` for OAuth callbacks
- **Read-later**: Configure in-app (Settings → Read Later Services). Credentials in Keychain; no analytics; HTTPS-only.

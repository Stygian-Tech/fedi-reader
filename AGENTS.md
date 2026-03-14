# Fedi Reader – Agent Instructions

**Single source of truth for all agents.** Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.
**Linear is the operational source of truth for planning, implementation status, blockers, and verification. Keep it current at all times.**

## GATE (first action on any request)

**Linear is the source of truth for all work tracking, not GitHub.** Before any code edits or plan creation:

1. Run `git branch --show-current`. Parse for Linear ID (e.g. `FEDI-123`). Valid patterns: `FEDI-123-feature-name`, `sam/FEDI-456-fix`, `CountableNewt/issue92-...`.
2. **If Linear ID found**: Use Linear MCP `get_issue` to confirm, then `save_issue` with `state: "In Progress"` before touching code or creating plans.
3. **If no Linear ID but branch has GitHub issue** (e.g. `issue92`, `CountableNewt/issue92-haptic-feedback`): Every GitHub issue has a Linear comment linking the issue. Use Linear MCP `list_issues` with a `query` matching the branch/task (e.g. "haptic feedback") to find the linked Linear issue, then proceed as above.
4. **If no Linear ID** (e.g. `main`): Proceed without Linear updates.

Apply in **both plan mode and implementation**—do not skip because you are "only planning."
Do not batch updates until the end of the task. If status, scope, blockers, decisions, or verification change, update Linear before continuing.

### Full Linear workflow

- **During planning**: Add comments via `create_comment`—when drafting a plan, summarize the approach or key decisions on the Linear issue.
- **While implementing**: Include the full plan via `create_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment. Add comments as you work—implementations, decisions, blockers.
- **At all times**: Keep the issue current. When scope, status, blockers, implementation details, or verification results change, reflect that in Linear immediately.
- **When new bugs surface during implementation**: If the bug was introduced by the current branch, fix it under the parent issue and document it there. If the bug was not introduced by the current branch, create a Linear sub-issue under the current issue, move tracking there, and note the split on the parent issue. If the issue was discovered by an agent while working another task, apply the `Source/Agent` label.
- **When work moves to a sub-issue**: Comment directly on the sub-issue as the work progresses. Plans, implementation notes, blockers, verification, and completion notes for that work belong on the sub-issue itself. The parent issue should only record the split and high-level coordination updates.
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

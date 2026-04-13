# Fedi Reader – Agent Instructions

**Single source of truth for all agents.** Link-focused Mastodon news reader for iOS/macOS. Pure Swift, SwiftUI + SwiftData, `@Observable` services — no MVVM, no external dependencies.
**Linear is the operational source of truth for planning, implementation status, blockers, and verification. Keep it current at all times.**

## GATE (first action on any request)

0. **Load the shared (agnostic) Linear workflow** — Before the Fedi-specific steps below, load the canonical generic skill: prefer MCP `fetch_mcp_resource` with URI `ctx://skill/linear-workflow` on the MyContextProtocol server in your environment (in Cursor this is often `user-MyContextProtocol`). If that is unavailable, open the same content at [linear-workflow/SKILL.md (raw)](https://raw.githubusercontent.com/CountableNewt/skills/main/linear-workflow/SKILL.md) and follow it for general process. This file then adds **Fedi-only** requirements.

**Linear is the source of truth for all work tracking, not GitHub.** Before any code edits or plan creation:

1. Run `git branch --show-current`. Parse for Linear ID (e.g. `FEDI-123`). Valid patterns: `FEDI-123-feature-name`, `sam/FEDI-456-fix`, `CountableNewt/issue92-...`.
2. **If Linear ID found**: Use Linear MCP `get_issue` to confirm, then `save_issue` with `state: "In Progress"` before touching code or creating plans.
3. **If no Linear ID but branch has GitHub issue** (e.g. `issue92`, `CountableNewt/issue92-haptic-feedback`): Every GitHub issue has a Linear comment linking the issue. Use Linear MCP `list_issues` with a `query` matching the branch/task (e.g. "haptic feedback") to find the linked Linear issue, then proceed as above.
4. **If no Linear ID** (e.g. `main`): Proceed without Linear updates.

**Linear MCP tools in this workspace** (Cursor Linear plugin): `get_issue`, `save_issue`, `list_issues`, `save_comment` (creates or updates a comment; use `issueId` + `body` when creating). Map any other phrasing to these tool names.

Apply in **both plan mode and implementation**—do not skip because you are "only planning."
Do not batch updates until the end of the task. If status, scope, blockers, decisions, or verification change, update Linear before continuing.

### Full Linear workflow

- **During planning**: Add comments via `save_comment`—when drafting a plan, summarize the approach or key decisions on the Linear issue.
- **While implementing**: Include the full plan via `save_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment. Add comments as you work—implementations, decisions, blockers.
- **At all times**: Keep the issue current. When scope, status, blockers, implementation details, or verification results change, reflect that in Linear immediately.
- **When new issues surface during implementation**: Distinguish between regressions introduced by the current branch and independent issues discovered while doing the work. If the current branch introduced the regression, create a Linear sub-issue under the current parent issue and track the regression there. If you discover a separate issue that is not a regression from the current branch, create a separate Linear issue rather than a sub-issue. In both cases, note the split on the current issue before continuing.
- **Label and metadata requirements for agent-created issues**: Any issue created by an agent through Codex should use the `Agent` label in MCP calls, even when the underlying problem was reported by the user during the session. In Linear UI this may appear under the `Source` group. Also carry over the relevant inferred metadata from the parent context whenever applicable, including product/platform labels, project association, priority, and any other labels that clearly match the affected area.
- **Assignee requirements for agent-created issues**: Assign issues created by an agent to the human Linear user by default. In this workspace that is currently `Sam Clemente`. If that changes later, resolve the correct non-agent human user before creating or updating the issue.
- **When work moves to a split issue**: Comment directly on the new sub-issue or separate issue as the work progresses. Plans, implementation notes, blockers, verification, and completion notes for that work belong on the issue where the work is now tracked. The parent issue should only record the split and high-level coordination updates.
- **Before claiming done**: Add a completion comment via `save_comment`—summarize changes made and how to verify. Do not mark Done—let Linear–GitHub integration set Done when the PR is merged.

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

## Learned User Preferences

- List display choices (sort mode, custom order, hidden lists) are expected to survive relaunch and account reload; treat unexpected resets as correctness bugs, not optional polish.

## Learned Workspace Facts

- For `AppState` + `@Observable`, mutating `currentAccountListDisplayPreferences` in place (nested arrays, `sortOrder`, etc.) can fail to persist reliably; copy into a local `var`, apply changes, then assign the **whole** `AccountListDisplayPreferences` value back before saving.
- After user-driven list-display mutations (sort, hide/show, reorder), ensure **`persistListDisplayPreferencesForCurrentAccount`** runs so disk matches memory; do not rely only on `synchronize` when that path can short-circuit.
- `synchronizeCurrentAccountListDisplayPreferences` must not treat an **empty** list catalog as authoritative for pruning stored IDs; callers that may pass `[]` should use **`allowEmptyListSet: true`** so empty snapshots do not drop persistence or skip the intended save path.
- If list-display prefs “revert to alphabetical” after launch, check decode/load: log or handle decode failures instead of silently resetting to defaults.
- On Linear, **Agent** and **GitHub** labels can sit in the same exclusive **Source** group; if an issue must carry **Agent**, do not also set **GitHub**—use the GitHub link attachment for origin.

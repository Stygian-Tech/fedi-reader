# .agents/ — Agent context and instructions

This directory holds project-specific context for AI agents. Structure follows the [dotagents](https://github.com/bgreenwell/dotagents) convention.

| Directory | Purpose |
|-----------|---------|
| `rules/` | Behavioral guidelines (Linear workflow, etc.) |
| `context/` | Static reference (architecture, conventions, file layout) |
| `skills/` | Optional repo-local [agentskills.io](https://agentskills.io) packages. The shared **linear-workflow** skill is not vendored here; load it via MyContext MCP (`ctx://skill/linear-workflow`) or the URL in [AGENTS.md](../AGENTS.md) GATE step 0. |

**Entry point:** Root [AGENTS.md](../AGENTS.md) is the single source of truth for all agents. Read it first.
**Linear policy:** Linear is the source of truth for planning, status, blockers, and verification. Agents must keep it up to date throughout the task.
**Issue-splitting policy:** Regressions introduced by the current branch become Linear sub-issues under the current parent issue. Separate issues discovered while doing the work become separate Linear issues rather than sub-issues. In both cases, note the split on the current issue before continuing.
**Labeling policy:** Any issue created by an agent through Codex should use the `Agent` label in MCP calls, even when the problem was reported by the user in the current session. In Linear UI this may appear under the `Source` group. Also carry over the relevant inferred metadata from the current context, including product or platform labels, project association, priority, and any area labels that clearly fit the affected surface.
**Assignment policy:** Assign issues created by an agent to the human Linear user by default. In this workspace that is currently `Sam Clemente`. If the workspace setup changes later, resolve the correct non-agent human user before filing or updating the issue.
**Split-issue commenting policy:** Once work is tracked in a sub-issue or separate issue, ongoing comments for that work go on that issue itself. Keep the parent issue to split notices and high-level coordination.

**Cursor compatibility:** `.cursor/rules/` references AGENTS.md for always-apply rules. Enable the **MyContextProtocol** MCP server in Cursor when you want GATE step 0 to use `fetch_mcp_resource` instead of opening the raw GitHub skill file.

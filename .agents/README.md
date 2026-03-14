# .agents/ — Agent context and instructions

This directory holds project-specific context for AI agents. Structure follows the [dotagents](https://github.com/bgreenwell/dotagents) convention.

| Directory | Purpose |
|-----------|---------|
| `rules/` | Behavioral guidelines (Linear workflow, etc.) |
| `context/` | Static reference (architecture, conventions, file layout) |
| `skills/` | Executable capabilities ([agentskills.io](https://agentskills.io) compliant) |

**Entry point:** Root [AGENTS.md](../AGENTS.md) is the single source of truth for all agents. Read it first.
**Linear policy:** Linear is the source of truth for planning, status, blockers, and verification. Agents must keep it up to date throughout the task.
**Issue-splitting policy:** Branch-caused regressions stay on the current parent issue. Unrelated bugs discovered while working become Linear sub-issues under that parent. If the bug was discovered by an agent during that work, apply the `Source/Agent` label.
**Sub-issue commenting policy:** Once work is tracked in a sub-issue, ongoing comments for that work go on the sub-issue itself. Keep the parent issue to split notices and high-level coordination.

**Cursor compatibility:** `.cursor/rules/` references AGENTS.md for always-apply rules.

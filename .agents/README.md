# .agents/ — Agent context and instructions

This directory holds project-specific context for AI agents. Structure follows the [dotagents](https://github.com/bgreenwell/dotagents) convention.

| Directory | Purpose |
|-----------|---------|
| `rules/` | Behavioral guidelines (Linear workflow, etc.) |
| `context/` | Static reference (architecture, conventions, file layout) |
| `skills/` | Executable capabilities ([agentskills.io](https://agentskills.io) compliant) |

**Entry point:** Root [AGENTS.md](../AGENTS.md) is the single source of truth for all agents. Read it first.
**Linear policy:** Linear is the source of truth for planning, status, blockers, and verification. Agents must keep it up to date throughout the task.
**Issue-splitting policy:** Regressions introduced by the current branch become Linear sub-issues under the current parent issue. Separate issues discovered while doing the work become separate Linear issues rather than sub-issues. In both cases, note the split on the current issue before continuing.
**Labeling policy:** If an agent discovered the issue while working another task, apply the `Agent` label in MCP calls. In Linear UI this may appear under the `Source` group. Also carry over the relevant inferred metadata from the current context, including product or platform labels, project association, priority, and any area labels that clearly fit the affected surface.
**Split-issue commenting policy:** Once work is tracked in a sub-issue or separate issue, ongoing comments for that work go on that issue itself. Keep the parent issue to split notices and high-level coordination.

**Cursor compatibility:** `.cursor/rules/` references AGENTS.md for always-apply rules.

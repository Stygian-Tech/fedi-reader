# .agents/ — Agent context and instructions

This directory holds project-specific context for AI agents. Structure follows the [dotagents](https://github.com/bgreenwell/dotagents) convention.

| Directory | Purpose |
|-----------|---------|
| `rules/` | Behavioral guidelines (Linear workflow, etc.) |
| `context/` | Static reference (architecture, conventions, file layout) |
| `skills/` | Executable capabilities ([agentskills.io](https://agentskills.io) compliant) |

**Entry point:** Root `AGENTS.md` routes agents here. Read it first.

**Cursor compatibility:** `.cursor/rules/` mirrors or references `.agents/rules/` for rules that must apply to Cursor sessions.

# Cursor rules

Project rules in this directory apply to Cursor Agent sessions. Canonical source for all agent instructions is [AGENTS.md](../AGENTS.md).

- `linear-workflow.mdc` — Always applies; points at [AGENTS.md](../AGENTS.md). Agents load the shared **linear-workflow** skill via MyContext MCP (`ctx://skill/linear-workflow`) or the raw GitHub fallback in GATE step 0, then follow Fedi-specific rules in AGENTS.md.

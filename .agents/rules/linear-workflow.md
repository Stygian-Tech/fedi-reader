# Linear Workflow

**See [AGENTS.md](../../AGENTS.md) in the project root.** All agent instructions, including the full Linear workflow, are consolidated there.
**Linear remains the source of truth for work tracking and must stay current throughout execution.**
**Issue-tracking rule:** Regressions introduced by the current branch must be tracked as Linear sub-issues under the current issue. Separate issues discovered during the work that are not regressions from the current branch must be tracked as separate Linear issues rather than sub-issues.
**Labeling rule:** Any issue created by an agent through Codex should use the `Agent` label in MCP calls, even when the user reported the underlying problem in the current session. In Linear UI this may appear under the `Source` group. Also add the other relevant inferred labels and metadata from the current context.
**Assignment rule:** Assign issues created by an agent to the human Linear user by default. In this workspace that is currently `Sam Clemente`. If the workspace setup changes later, resolve the correct non-agent human user before filing or updating the issue.
**Split-issue comment rule:** After work is split to a sub-issue or separate issue, put implementation comments, blockers, verification, and completion updates on that issue itself.

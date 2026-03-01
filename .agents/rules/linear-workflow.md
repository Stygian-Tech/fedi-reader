# Linear Workflow (MANDATORY)

**Agents MUST ALWAYS check for a linked Linear issue before starting work.** Linear–GitHub integration depends on correct branch names and issue updates.

## Steps (do first, every time)

1. **Parse branch name** for a Linear issue ID (e.g. `FED-123`, `PROJ-456`). Valid patterns: `FED-123-feature-name`, `sam/FED-456-fix`, `feature/FED-789-thing`.

2. **Confirm issue exists** via Linear MCP `get_issue` or `list_issues`.

3. **Set In Progress** via `save_issue` with `state: "In Progress"` before making code changes. Do this before touching code.

4. **Add comments as you work** via `create_comment`—implementations, decisions, blockers. Keeps issue history useful for PR review.

5. **Do not mark Done**—let Linear–GitHub integration set Done when the PR is merged. Manual Done bypasses that flow.

If no Linear issue exists (e.g. branch is `main` or doesn’t match patterns), proceed without Linear updates—but **always check first**.

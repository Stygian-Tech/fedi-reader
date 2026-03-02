# Linear Workflow (MANDATORY)

**GATE: Do NOT make any code edits until you complete the "Before code" steps below.** Linear–GitHub integration depends on correct branch names and issue updates.

## Before code (first actions—do these before any read_file, search_replace, or write)

1. Run `git branch --show-current`. Parse for Linear ID (e.g. `FED-123`). Valid patterns: `FED-123-feature-name`, `sam/FED-456-fix`.

2. **If Linear ID found**: Use Linear MCP `get_issue` to confirm, then `save_issue` with `state: "In Progress"` before touching code.

3. **If no Linear ID** (e.g. `main`): Proceed without Linear updates.

## While implementing

4. **Include the full plan** via `create_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment.

5. **Add comments as you work** via `create_comment`—implementations, decisions, blockers.

## Before claiming work complete

6. **Add a completion comment** via `create_comment`—summarize changes made and how to verify. Do not skip this step.

7. **Do not mark Done**—let Linear–GitHub integration set Done when the PR is merged.

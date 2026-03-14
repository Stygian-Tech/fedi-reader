---
name: linear-workflow
description: ALWAYS check for linked Linear issue and follow conventions before starting work. Use when on a feature branch, when beginning any coding task, or when in plan mode.
---

# Linear Workflow

**MANDATORY:** Linear is the source of truth, not GitHub. Check for a linked Linear issue before starting work. Linear–GitHub integration depends on correct branch names and issue updates.

## When to Use (invoke this skill FIRST)

- **Every** coding task, fix, or implementation—before any other actions
- **Plan mode**—when creating, writing, or drafting a plan (e.g. `.plan.md`). Do not skip Linear updates because you are "only planning."
- When switching to a new branch
- When the user asks you to implement, fix, change something, or create a plan

**Do not skip.** If you will edit code or create plans, invoke this skill and complete the workflow before touching files.

## Instructions

1. **Check branch** via `git branch --show-current`. Parse for Linear ID (e.g. `FEDI-123`, `PROJ-456`). Valid patterns: `FEDI-123-feature-name`, `sam/FEDI-456-fix`, `CountableNewt/issue92-feature-name`.

2. **If no Linear ID but branch has GitHub issue** (e.g. `issue92`): Every GitHub issue has a Linear comment linking the issue. Use `list_issues` with a `query` matching the branch/task to find the linked Linear issue.

3. **Confirm issue exists** via Linear MCP `get_issue` or `list_issues`.

4. **Set In Progress** via `save_issue` with `state: "In Progress"` before making code changes or creating plans.

5. **During planning**: Add comments via `save_comment`—when drafting a plan, summarize the approach or key decisions on the Linear issue.

6. **During implementation**: Include the full plan via `save_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment so reviewers have full context.

7. **Add comments as you work** via `save_comment`—implementations, decisions, blockers.

8. **Do not mark Done**—let Linear–GitHub integration set Done when the PR is merged.

If no Linear issue exists (e.g. branch is `main` or doesn’t match patterns), proceed without Linear updates—but **always check first**.

## Reference

See [AGENTS.md](../../../AGENTS.md) for the full workflow.

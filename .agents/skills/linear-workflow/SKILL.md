---
name: linear-workflow
description: ALWAYS check for linked Linear issue and follow conventions before starting work. Use when on a feature branch or when beginning any coding task.
---

# Linear Workflow

**MANDATORY:** Check for a linked Linear issue before starting work. Linear–GitHub integration depends on correct branch names and issue updates.

## When to Use (invoke this skill FIRST)

- **Every** coding task, fix, or implementation—before any other actions
- When switching to a new branch
- When the user asks you to implement, fix, or change something

**Do not skip.** If you will edit code, invoke this skill and complete the workflow before touching files.

## Instructions

1. **Check GitHub issue** for a comment from Linear that has the Linear ticket ID (e.g. `FED-123`, `PROJ-456`). Valid patterns: `FED-123-feature-name`, `sam/FED-456-fix`, `feature/FED-789-thing`.

2. **Confirm issue exists** via Linear MCP `get_issue` or `list_issues`.

3. **Set In Progress** via `save_issue` with `state: "In Progress"` before making code changes.

4. **Include the full plan** via `create_comment`—when implementing from a `.plan.md` file, paste the **entire plan content** as a Linear comment so reviewers have full context.

5. **Add comments as you work** via `create_comment`—implementations, decisions, blockers.

6. **Do not mark Done**—let Linear–GitHub integration set Done when the PR is merged.

If no Linear issue exists (e.g. branch is `main` or doesn’t match patterns), proceed without Linear updates—but **always check first**.

## Reference

See `.agents/rules/linear-workflow.md` for the full rule.

---
name: phase
description: "Phase lifecycle management. Use 'start N [description]' to begin a phase (branch + PLAN.md update) or 'finish [N]' to complete it (gate + PR creation)."
disable-model-invocation: true
---

# Phase Workflow: Start and Finish Phases

## Overview

Manages the lifecycle of PLAN.md phases: starting a phase (creating a branch, updating status) and finishing it (running gates, creating PRs). Enforces the branch-per-phase convention and ensures PRs are never created without validation.

## Arguments

- `/plangate:phase start N [description]` — Start phase N with optional description
- `/plangate:phase finish [N]` — Finish current or specified phase

---

## Mode: Start

### Step 1: Validate Git State

```bash
git status
```

Verify:
- Working tree is clean (no uncommitted changes)
- Currently on `main` or a base branch
- No untracked files that should be committed

If working tree is dirty, warn the user and ask whether to stash or commit first.

### Step 2: Read PLAN.md

Read `PLAN.md` and find Phase {N}. Extract:
- Phase title/description
- Task list for this phase
- Any prerequisites or dependencies on previous phases

If the argument doesn't include a description, derive one from the phase title in PLAN.md.

### Step 3: Create Branch

Generate branch name following convention:
```
feat/phase-{N}-{kebab-case-description}
```

Examples:
- `feat/phase-1-foundation-and-setup`
- `feat/phase-2-core-api-endpoints`
- `feat/phase-3-auth-and-permissions`

```bash
git checkout -b feat/phase-{N}-{description}
```

### Step 4: Update PLAN.md Status

Change the phase status to "In Progress":
- Find the phase heading in PLAN.md
- If there's a status indicator, update it (e.g., `**Status: In Progress**`)
- Commit this change: `git commit -m "chore: start phase {N} — {description}"`

### Step 5: Report

```
Phase {N} started.
Branch: feat/phase-{N}-{description}
Tasks: {count} tasks to complete

Ready to implement. Use /plangate:orchestrate {N} to begin task execution.
```

---

## Mode: Finish

### Step 1: Identify Current Phase

If phase number is provided, use it. Otherwise, detect from current branch name:
```bash
git branch --show-current
```

Parse `feat/phase-{N}-...` to extract N.

### Step 2: Verify Phase Completion

Read PLAN.md and check that ALL tasks for this phase are checked off (`- [x]`).

If any tasks are unchecked (`- [ ]`), warn:
```
Phase {N} has {count} uncompleted tasks:
- [ ] {task 1}
- [ ] {task 2}

Complete all tasks before finishing the phase.
```

STOP — do not proceed with incomplete tasks.

### Step 3: Run Pre-PR Gate

Invoke the `plangate:gate` skill. This runs typecheck + lint + build + tests.

If the gate fails, STOP. Report the failures and do not proceed to PR creation.

### Step 4: Update PLAN.md Status

Update the phase status to "Complete":
- Change status indicator to `**Status: Complete**`
- Commit: `git commit -m "chore: complete phase {N}"`

### Step 5: Push and Create PR

```bash
git push -u origin feat/phase-{N}-{description}
```

Create PR using the user's template:
```bash
gh pr create --base main --head feat/phase-{N}-{description} \
  --title "feat(phase-{N}): {phase title}" \
  --body "$(cat <<'EOF'
## Summary
{2-3 bullet points summarizing what this phase implemented}

## Implementation
{Key technical decisions and approaches}

## Testing
{What was tested and how}

## Technical Details
{Architecture notes, migration details, etc.}

## Next Phase
{What Phase N+1 will cover, if applicable}

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### Step 6: Report

```
Phase {N} complete!
PR: {PR_URL}
Branch: feat/phase-{N}-{description}

Summary:
- {count} tasks completed
- All gates passed (typecheck, lint, build, tests)
- PR created and ready for review
```

---

## Key Principles

### Never Skip the Gate
The pre-PR gate is mandatory. Even if you "just ran it" during orchestration, run it again. Code may have changed.

### Clean Commits
Phase start and finish get their own clean commits (`chore:` prefix). Implementation commits use `feat:` or `fix:` prefixes.

### One Phase Per Branch
Each phase gets its own branch. Never mix phases on a single branch.

## Integration

- Works with `plangate:orchestrate` for task execution within a phase
- Uses `plangate:gate` for validation before PR creation
- Follows the branch naming convention from CLAUDE.md

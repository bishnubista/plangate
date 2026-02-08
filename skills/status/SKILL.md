---
name: status
description: "Show current phase, task progress, and orchestration state. Use when the user says 'status', 'progress', 'where are we', or 'what's left'."
---

# Status: Project Progress Overview

## Overview

Provides a quick snapshot of where you are in the plangate workflow: which phase is active, which tasks are done, and what stage the orchestrator reached. Read-only — no side effects.

## The Process

### Step 1: Detect Current Phase

Read the current git branch:

```bash
git branch --show-current
```

Parse `feat/phase-{N}-...` to extract the phase number. If not on a phase branch, report "No active phase (on branch: {name})".

### Step 2: Read PLAN.md

If `PLAN.md` exists, scan it for:
- All phases and their status indicators
- For the active phase: count total tasks, completed tasks (`- [x]`), and remaining tasks (`- [ ]`)
- List remaining task names

If no `PLAN.md` exists, report "No PLAN.md found".

### Step 3: Read Orchestration State

If `.plangate/orchestration-state.json` exists, read it and extract:
- Which task is currently in progress
- What stage it's at (implement / gate / review)
- Retry counts for any tasks

If no state file exists, report "No active orchestration".

### Step 4: Report

Output in this format:

```text
## Plangate Status

**Branch:** feat/phase-2-core-api
**Phase:** 2 — Core API Endpoints
**Status:** In Progress

### Task Progress

| # | Task | Status |
|---|------|--------|
| 2.1 | Create user model | Done |
| 2.2 | Add auth endpoints | In Progress (gate) |
| 2.3 | Protected route middleware | Pending |

Progress: 1/3 tasks complete

### Orchestration

Current task: 2.2 — Add auth endpoints
Current stage: gate (retry 1/2)
Started: 2026-02-08T14:30:00Z
```

If no orchestration is active:

```text
## Plangate Status

**Branch:** feat/phase-2-core-api
**Phase:** 2 — Core API Endpoints
**Status:** In Progress

### Task Progress

| # | Task | Status |
|---|------|--------|
| 2.1 | Create user model | Done |
| 2.2 | Add auth endpoints | Pending |
| 2.3 | Protected route middleware | Pending |

Progress: 1/3 tasks complete

No active orchestration. Run `/plangate:orchestrate 2` to continue.
```

## Key Principles

### Read-Only
This skill never modifies files, creates branches, or runs commands. It only reads and reports.

### Quick and Focused
Output should be scannable in under 5 seconds. No verbose explanations — just the current state.

## Integration

- Can be invoked anytime during a session
- Useful after context compaction or session resume to re-orient
- Complements `plangate:orchestrate` (check progress) and `plangate:phase` (lifecycle management)

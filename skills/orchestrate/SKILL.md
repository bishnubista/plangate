---
name: orchestrate
description: "Stack-aware orchestrator for PLAN.md execution. Sequential pipeline: implementer agent > build gate > reviewer agent. Fresh context per stage prevents bias."
disable-model-invocation: true
---

# Orchestrate: Sequential Gate-Based Task Execution

## Overview

Execute PLAN.md tasks sequentially with fresh subagents per stage, build gates between implementation and review, and retry loops until each task passes. The orchestrator (you) stays active at every checkpoint — never fire-and-forget.

## Prerequisites

Before starting:
1. Read `PLAN.md` to identify the current phase and its tasks
2. Read the `Commands:` line from `<plangate-manifest>` in session context. It contains the pre-resolved typecheck, lint, build, and test commands. If a command is `SKIP`, skip that stage. If the manifest is not available, fall back to the [Stack Commands](#stack-commands) table below.
3. If `.plangate.json` exists, its commands override the manifest (see [Custom Validation Commands](#custom-validation-commands))
4. Create tasks via TaskCreate for all tasks from the target phase

## Stack Commands

Select commands based on detected stack. The session hook auto-detects and reports this in `<plangate-manifest>`.

| Stack | Typecheck | Lint | Build | Test |
|-------|-----------|------|-------|------|
| **bun** | `bunx tsc --noEmit` | `bunx eslint . --max-warnings=0` | `bun run build` | `bun test` |
| **pnpm** | `pnpm tsc --noEmit` | `pnpm eslint . --max-warnings=0` | `pnpm build` | `pnpm test` |
| **yarn** | `yarn tsc --noEmit` | `yarn eslint . --max-warnings=0` | `yarn build` | `yarn test` |
| **npm** | `npx tsc --noEmit` | `npx eslint . --max-warnings=0` | `npm run build` | `npm test` |
| **uv/Python** | `uv run pyright` | `uv run ruff check .` | — | `uv run pytest` |
| **gradle/Kotlin** | `./gradlew compileKotlin` | `./gradlew detekt` | `./gradlew build` | `./gradlew test` |
| **go** | `go vet ./...` | `golangci-lint run` | `go build ./...` | `go test ./...` |
| **cargo/Rust** | `cargo check` | `cargo clippy -- -D warnings` | `cargo build` | `cargo test` |
| **spm/Swift** | `swift build` | `swiftlint` | `swift build -c release` | `swift test` |

### Custom Validation Commands

If `.plangate.json` exists in the project root, its `commands` block overrides the stack-detected defaults:

```json
{
  "commands": {
    "typecheck": "./gradlew compileKotlin",
    "lint": "./gradlew detekt",
    "build": "./gradlew build",
    "test": "./gradlew test"
  }
}
```

Read this file at the start of orchestration and use its commands throughout the pipeline.

## Checkpoint and Resume

Orchestration can be interrupted by context limits, session timeouts, or crashes. To enable resumption, maintain a checkpoint file at `.plangate/orchestration-state.json`.

### Writing Checkpoints

After each stage completes for each task, update the checkpoint file:

```json
{
  "phase": 1,
  "started_at": "2026-02-07T14:30:00Z",
  "tasks": [
    {
      "id": "1.1",
      "text": "Create project structure",
      "status": "complete",
      "stages": {
        "implement": "complete",
        "gate": "complete",
        "review": "complete"
      }
    },
    {
      "id": "1.2",
      "text": "Add health-check endpoint",
      "status": "in_progress",
      "stages": {
        "implement": "complete",
        "gate": "failed",
        "review": "pending"
      },
      "retry_count": 1
    },
    {
      "id": "1.3",
      "text": "Set up error handling",
      "status": "pending",
      "stages": {
        "implement": "pending",
        "gate": "pending",
        "review": "pending"
      }
    }
  ]
}
```

### Reading Checkpoints

When `/plangate:orchestrate N` is invoked:

1. Check if `.plangate/orchestration-state.json` exists for phase N
2. If it exists, read it and skip tasks/stages that are already "complete"
3. Resume from the first non-complete task/stage
4. Report: "Resuming phase {N} from task {id} ({stage})"

If no checkpoint exists, start fresh.

### Cleaning Up

After all tasks in a phase are complete, archive the checkpoint:
```bash
mv .plangate/orchestration-state.json .plangate/orchestration-state-phase-{N}.json
```

## The Pipeline

```text
For each task in the phase:

0. CHECK FOR CHECKPOINT (resume if exists)
   +-- Read .plangate/orchestration-state.json
   +-- Skip completed tasks/stages
   +-- Resume from first incomplete item

1. DISPATCH IMPLEMENTER (implementer agent, Sonnet)
   +-- Full task text + stack commands + project context in prompt
   +-- "Default-and-document" — proceeds with reasonable defaults, rarely blocks
   +-- Implement > write tests > self-validate > commit > report
   +-- Update .plangate/orchestration-state.json

2. RUN BUILD GATE (Bash, no subagent -- objective validation)
   +-- typecheck > lint > build
   +-- If fails: dispatch fix subagent > re-run gate (max 2 retries)
   +-- Update .plangate/orchestration-state.json

3. DISPATCH REVIEWER (reviewer agent, Sonnet)
   +-- Combined spec compliance + code quality with distrust
   +-- If issues found: dispatch fix subagent > re-review (max 2 retries)
   +-- Update .plangate/orchestration-state.json

4. SUPABASE MIGRATION HOOK (conditional)
   +-- If task touches DDL/migrations: invoke plangate:supabase-migrate
   +-- Re-run build gate after types regeneration
   +-- Update .plangate/orchestration-state.json

5. UPDATE PLAN.MD
   +-- Check off completed task
   +-- Update .plangate/orchestration-state.json

6. NEXT TASK
```

### After All Tasks Complete

1. Run full test suite
2. Invoke `plangate:gate` skill
3. Archive the checkpoint file
4. Offer to finish the phase using `/plangate:phase finish`

**Important:** Do NOT update PLAN.md status (e.g., "In Progress" → "Complete") or commit a phase-completion update. That is the responsibility of `plangate:phase finish`, which owns lifecycle transitions. Committing here would create duplicate commits.

---

## Stage 1: Dispatch Implementer

Launch the **implementer** agent via the Task tool. Include in the prompt:

- **Full task text** — paste the complete task description. Never tell the agent to read a file.
- **Stack commands** — the exact typecheck, lint, build, test commands from the table above
- **Scene-setting context** — what phase this is, what was done before, what comes after
- **Relevant file paths** — files the implementer will need to read or modify

The implementer agent will:
1. Review the task and proceed (defaulting on ambiguities and documenting assumptions)
2. Implement the task following existing patterns
3. Write tests for acceptance criteria (testing the actual function, not just helpers)
4. Self-validate (typecheck, lint, build)
5. Commit and report

When the implementer returns:
- Read their report carefully
- Check the **Concerns** section for documented assumptions (validate they're reasonable)
- If genuinely blocked with questions (rare), answer and re-dispatch
- Update the checkpoint file with implementer stage status
- Proceed to build gate

---

## Stage 2: Build Gate

Run validation directly via Bash (no subagent — this is objective pass/fail):

```bash
{TYPECHECK_CMD} && {LINT_CMD} && {BUILD_CMD}
```

Use the stack-appropriate commands from the table above or from `.plangate.json` if present.

**Note on optional linters:** For stacks where the linter is optional (detekt, golangci-lint, clippy, swiftlint), check if the command exists before running. Skip with a warning if not installed.

**If the build gate fails:**
1. Read the error output carefully
2. Dispatch a fix subagent with:
   - The exact error output
   - The files that need fixing
   - Instruction: "Fix ONLY these errors. Do not refactor or change anything else."
3. Re-run the build gate
4. If it fails again after 2 retries, STOP and report to the user

**The build gate is non-negotiable.** Do not skip it. Do not proceed to review if it fails.

After the build gate passes, update the checkpoint file with gate stage status.

---

## Stage 3: Dispatch Reviewer

Launch the **reviewer** agent via the Task tool. Include in the prompt:

- **Full task spec** — the original task text (same as what the implementer received)
- **Git diff** — run `git diff` to capture what was implemented
- **Implementer's report** — include it, but tell the reviewer NOT to trust it

The reviewer agent will independently:
- Read every line of the diff
- Compare implementation against spec requirements
- Check code quality, security, and conventions
- Return verdict: **APPROVED** or **ISSUES_FOUND** with file:line references

**If the reviewer finds issues:**
1. Dispatch a fix subagent with the reviewer's specific issues
2. Re-run the build gate
3. Re-dispatch the reviewer
4. If still failing after 2 retry cycles, STOP and report to the user

**Orchestrator discretion on trivial fixes:** For simple fixes (1-3 line changes addressing a single, clear issue like a missing `clearTimeout` or an off-by-one), the orchestrator may skip the re-review and proceed directly if the build gate passes. Use this only when the fix is obviously correct and the original review had no other concerns. When in doubt, re-review.

After the reviewer approves, update the checkpoint file with review stage status.

---

## Stage 4: Supabase Migration Hook (Conditional)

After review approval and before updating `PLAN.md`, determine whether the task touched Supabase DDL.

Treat it as DDL/migration work if ANY of these are true:
- Task text references migrations, DDL, policies, or schema changes
- Changed files include `supabase/migrations/*.sql`
- Changed files include `supabase/schema.sql` or `supabase/seed.sql`
- Reviewer/implementer reports mention `CREATE TABLE`, `ALTER TABLE`, or RLS policy changes

If DDL/migrations were touched:
1. Invoke `plangate:supabase-migrate`
2. Ensure regenerated types are staged
3. Re-run Stage 2 build gate before proceeding
4. Update the checkpoint file

If no DDL/migration changes were made, skip this step.

---

## Stage 5: Update PLAN.md

After a task passes all gates:
1. Read PLAN.md
2. Find the task's checkbox line
3. Change `- [ ]` to `- [x]`
4. Write the updated file
5. Update the checkpoint file to mark task as complete

---

## Key Principles

### Fresh Subagent Per Stage
Each subagent starts with clean context. The orchestrator (you) maintains continuity between stages. This prevents implementer bias from leaking into review.

### Full Context in Prompts
Never make a subagent read files to understand their task. Paste the full task description, relevant code snippets, and stack commands directly into the prompt.

### Sequential, Not Parallel
Execute tasks one at a time. Parallel execution causes quality issues — tasks often have implicit dependencies, and parallel commits create merge conflicts.

### Orchestrator Stays Active
You (the orchestrator) read every subagent report, run every build gate, and make every dispatch decision. You are the quality gatekeeper.

---

## Red Flags — STOP If You Catch Yourself

- Starting a task without creating TaskCreate entries first
- Dispatching implementer without full task text in the prompt
- Skipping the build gate ("it probably passes")
- Proceeding to reviewer while build gate has failures
- Letting the implementer's report substitute for reviewer verification
- Running tasks in parallel
- Dispatching reviewer without the git diff
- Accepting "close enough" from the reviewer
- Moving to next task with open issues
- Not updating the checkpoint file after each stage

---

## Integration

- Composes with `plangate:gate` for final validation
- Composes with `plangate:phase finish` for PR creation
- Invokes `plangate:supabase-migrate` automatically for Supabase DDL tasks
- Updates PLAN.md checkboxes for progress tracking
- Maintains `.plangate/orchestration-state.json` for checkpoint/resume capability

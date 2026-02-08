# plangate

A [Claude Code](https://claude.com/claude-code) plugin for PLAN.md-driven development with quality gates.

Each task flows through a sequential pipeline: **implement** (subagent) > **build gate** (objective pass/fail) > **review** (independent subagent). Fresh context per stage prevents implementer bias from leaking into review.

## Philosophy

Building features requires more than just writing code. Code that compiles isn't necessarily correct, and code that the implementer says works isn't necessarily reviewed. plangate enforces a three-stage pipeline where:

- **Implementation and review are independent** — the reviewer gets the spec and the diff, never the implementer's self-assessment
- **Build gates are objective** — typecheck, lint, and build are pass/fail with no AI interpretation
- **The orchestrator maintains continuity** — a human-level coordinator reads every report and makes every dispatch decision

This catches the failure mode where AI agents mark their own homework: implementing a feature, then reviewing it with the same context and biases.

## Commands

| Command | What it does |
|---------|-------------|
| `/plangate:orchestrate [N]` | Execute phase N tasks through the gate pipeline |
| `/plangate:gate` | Typecheck + lint + build + tests validation |
| `/plangate:status` | Show current phase, task progress, orchestration state |
| `/plangate:phase start N` / `finish` | Branch creation, PLAN.md updates, PR creation |
| `/plangate:investigate {name}` | Structured investigation doc for complex bugs |
| `/plangate:supabase-migrate` | Regen types, check RLS policies after DDL changes |

## Agents

| Agent | Role | When dispatched |
|-------|------|----------------|
| `implementer` | Implement task, write tests, validate, commit | Stage 1 of orchestrate |
| `reviewer` | Independent spec + quality review with distrust | Stage 3 of orchestrate |

## Installation

```bash
git clone https://github.com/bishnubista/plangate.git ~/plugins/plangate
```

From your project directory:

```bash
claude /install-plugin file://$HOME/plugins/plangate
```

Or add the marketplace and install:

```bash
/plugin marketplace add bishnubista/plangate
/plugin install plangate@plangate
```

### Verify

Start a new Claude Code session. You should see the manifest in context:

```text
<plangate-manifest>
Stack: nextjs | Package manager: bun | Supabase: false

Auto-invocable skills (Claude can use directly):
  plangate:gate              — Typecheck + lint + build validation.
  plangate:status            — Show current phase, task progress, and orchestration state.
  plangate:supabase-migrate  — After DDL changes: regen types, check RLS/indexes.

User-invoked workflows (run via / commands):
  /plangate:orchestrate [N]        — Multi-task orchestration with sequential gates.
  /plangate:phase start N | finish — Phase lifecycle.
  /plangate:investigate [name]     — Structured investigation doc.
  /plangate:status                 — Quick project progress overview.
</plangate-manifest>
```

## The Orchestration Pipeline

When you run `/plangate:orchestrate 1`, here's what happens for each task in Phase 1:

### Stage 1: Implementer

The orchestrator launches the **implementer agent** with the full task text, stack commands, and project context. The implementer:

1. Asks clarifying questions (if any)
2. Implements the task following existing patterns
3. Writes tests for acceptance criteria
4. Runs typecheck + lint + build
5. Commits and reports

**Example orchestrator dispatch:**
```text
Dispatching implementer for Task 1.1: "Create project structure with src/ directory"

Context: Phase 1 (Foundation), bun + Next.js project
Stack commands: bunx tsc --noEmit, bunx eslint . --max-warnings=0, bun run build

[implementer agent starts...]
```

### Stage 2: Build Gate

The orchestrator runs validation directly — no AI, just pass/fail:

```bash
bunx tsc --noEmit && bunx eslint . --max-warnings=0 && bun run build
```

If it fails, a fix subagent is dispatched with the exact errors. Max 2 retries.

**The build gate is non-negotiable.** No proceeding to review if it fails.

### Stage 3: Reviewer

The orchestrator launches the **reviewer agent** with:
- The original task spec
- The git diff of what was implemented
- The implementer's report (with explicit instruction: "Do NOT trust this")

**Example reviewer output:**
```text
Verdict: ISSUES_FOUND

1. src/lib/api.ts:45 — Critical
   Missing error handling for network failures.
   The fetch call has no try/catch. If the API is unreachable,
   this throws an unhandled exception.
   Fix: Wrap in try/catch, return typed error response.

2. src/components/Layout.tsx:12 — Important
   Hardcoded breakpoint value (768px) should use theme constant.
   Fix: Import from theme config.
```

If issues are found: fix subagent > re-gate > re-review. Max 2 cycles.

### Stage 4: PLAN.md Update

After all gates pass, the task checkbox is marked complete:

```diff
- - [ ] Task 1.1: Create project structure
+ - [x] Task 1.1: Create project structure
```

## Gate Skill

`/plangate:gate` runs the full validation pipeline and reports results:

```text
## Pre-PR Gate Results

| Check      | Status | Details              |
|------------|--------|----------------------|
| Typecheck  | PASS   | clean                |
| Lint       | PASS   | clean                |
| Build      | PASS   | clean                |
| Tests      | PASS   | 24 passing, 0 failing|

Verdict: GATE PASSED
```

If any check fails:

```text
## Pre-PR Gate Results

| Check      | Status | Details              |
|------------|--------|----------------------|
| Typecheck  | FAIL   | 3 errors             |
| Lint       | —      | skipped (typecheck failed) |
| Build      | —      | skipped              |
| Tests      | —      | skipped              |

Verdict: GATE FAILED — fix issues before creating PR

Errors:
  src/lib/api.ts(12,5): error TS2322: Type 'string' is not assignable to type 'number'.
  src/lib/api.ts(15,3): error TS2345: Argument of type '...' is not assignable to...
  src/components/Card.tsx(8,1): error TS7006: Parameter 'props' implicitly has an 'any' type.

Suggested fix: Add proper type annotations to the 3 files listed above.
```

The gate stops on first failure — build won't run if typecheck fails.

## Phase Lifecycle

### Starting a phase

```text
> /plangate:phase start 2 core-api

Phase 2 started.
Branch: feat/phase-2-core-api
Tasks: 3 tasks to complete

Ready to implement. Use /plangate:orchestrate 2 to begin.
```

### Finishing a phase

```text
> /plangate:phase finish

Running pre-PR gate... PASSED
Pushing to origin...

Phase 2 complete!
PR: https://github.com/you/project/pull/7
Branch: feat/phase-2-core-api

Summary:
- 3 tasks completed
- All gates passed (typecheck, lint, build, tests)
- PR created and ready for review
```

## Investigation Docs

For bugs that need more than a quick fix:

```text
> /plangate:investigate auth-token-expiry

Created: docs/investigations/2026-02-07-auth-token-expiry.md
```

The doc tracks hypotheses, trials, root cause, and lessons learned. Updated incrementally as you debug. Follows the 3-fix rule: if 3 fixes fail, stop and question the architecture.

## Stack Detection

The session-start hook auto-detects your project stack:

| File | Detected Stack | Package Manager |
|------|---------------|-----------------|
| `bun.lock` / `bun.lockb` | node/nextjs | bun |
| `pnpm-lock.yaml` | node/nextjs | pnpm |
| `yarn.lock` | node/nextjs | yarn |
| `package-lock.json` | node/nextjs | npm |
| `next.config.ts` / `.js` / `.mjs` | nextjs | (from above) |
| `pyproject.toml` | python | uv |
| `supabase/` directory | — | (adds Supabase flag) |

All skills use the detected stack for validation commands. No manual configuration needed.

## When to Use plangate

**Use for:**
- Multi-task feature phases with a PLAN.md
- Projects where you want independent review of AI-generated code
- Teams that want a repeatable gate before every PR
- Supabase projects that need post-migration checks

**Don't use for:**
- Single-file bug fixes (just fix it directly)
- Exploratory prototyping (gates slow you down)
- Projects without a PLAN.md (orchestrate needs one)
- Non-JavaScript/Python stacks (gate commands won't match)

## Best Practices

1. **Write a good PLAN.md** — the orchestrator is only as good as the tasks it receives. Clear, specific tasks with acceptance criteria produce better results.
2. **Let the orchestrator work** — don't interrupt mid-pipeline. It manages the full loop.
3. **Answer implementer questions** — if the implementer asks, answer. Skipping questions leads to assumptions.
4. **Trust the reviewer** — the reviewer's distrust is by design. If it flags an issue, it's worth looking at.
5. **Run `/plangate:gate` before every PR** — even outside of orchestration. It's fast and catches drift.

## Troubleshooting

### "Gate fails but I don't have TypeScript"

The gate assumes TypeScript. If your project is plain JavaScript, the `tsc --noEmit` step will fail.

**Fix:** Add a `tsconfig.json` or modify the gate to skip typecheck for non-TS projects. File an issue if you'd like first-class JS-only support.

### "Orchestrate does nothing"

The orchestrate skill reads `PLAN.md` to find tasks. If there's no `PLAN.md` or no tasks with `- [ ]` checkboxes, it has nothing to do.

**Fix:** Create a `PLAN.md` with phases and task checkboxes.

### "Supabase-migrate errors out"

The skill needs either a linked Supabase project (`supabase link`) or the Supabase MCP plugin connected.

**Fix:** Run `supabase link --project-ref <ref>` or ensure the Supabase MCP is authenticated with the correct account.

### "Stack detected as 'unknown'"

The hook checks for lockfiles and `package.json`. If none exist, stack is unknown and gate commands won't work.

**Fix:** Initialize your project with a package manager (`bun init`, `npm init`, etc.) before using plangate.

### "Reviewer keeps finding issues in a loop"

The retry limit is 2 cycles. If the reviewer still finds issues after 2 fix-review cycles, the orchestrator stops and reports to you.

**Fix:** Look at the specific issues. They may indicate a deeper design problem that automated fixes can't solve.

## Plugin Structure

```text
plangate/
  .claude-plugin/
    plugin.json              # Plugin metadata
    marketplace.json         # Marketplace catalog
  agents/
    implementer.md           # Implementation agent (Sonnet)
    reviewer.md              # Independent review agent (Sonnet)
  commands/
    orchestrate.md           # /plangate:orchestrate
    gate.md                  # /plangate:gate
    status.md                # /plangate:status
    phase.md                 # /plangate:phase
    investigate.md           # /plangate:investigate
    supabase-migrate.md      # /plangate:supabase-migrate
  skills/
    orchestrate/SKILL.md     # Orchestration pipeline logic
    gate/SKILL.md            # Validation pipeline logic
    status/SKILL.md          # Progress overview logic
    phase/SKILL.md           # Phase lifecycle logic
    investigate/SKILL.md     # Investigation doc logic
    supabase-migrate/SKILL.md # Post-migration checks
  hooks/
    hooks.json               # Hook registration
    session-start.sh         # Stack detection
  try-plangate.sh            # Plugin verification (55 checks)
```

## Verification

Run the self-test to validate the plugin structure:

```bash
./try-plangate.sh              # 26 structure checks
./try-plangate.sh --scaffold   # Also create a sample project
```

## Author

Bishnu Bista (collab@bishnu.dev)

## License

MIT

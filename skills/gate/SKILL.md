---
name: gate
description: "Bun + Next.js + Supabase-first pre-PR gate. Auto-detects stack, validates typecheck + lint + build + tests, and never auto-fixes."
---

# Pre-PR Gate: Stack-Aware Validation Pipeline

## Overview

Validates the project is in a clean, passing state before PR creation. The primary profile is Bun + Next.js + Supabase; for other stacks, use the fallback command paths below. This skill is **read-only** — it reports pass/fail with actionable suggestions but never modifies code.

## The Process

### Step 1: Detect Stack

Check the `<plangate-manifest>` from session context. If not available, detect manually:

| Marker File | Stack | Package Manager |
|-------------|-------|-----------------|
| `bun.lock` / `bun.lockb` | node/nextjs | bun |
| `pnpm-lock.yaml` | node/nextjs | pnpm |
| `yarn.lock` | node/nextjs | yarn |
| `package-lock.json` | node/nextjs | npm |
| `pyproject.toml` | python | uv |

Check for `next.config.js`/`next.config.ts`/`next.config.mjs` to distinguish Next.js from plain Node.

### Step 2: Run Validation Pipeline

Run each command sequentially. Stop on first failure.

**bun / Next.js:**
```bash
bunx tsc --noEmit
```
```bash
bunx eslint . --max-warnings=0
```
```bash
bun run build
```

**pnpm / Next.js:**
```bash
pnpm tsc --noEmit
```
```bash
pnpm eslint . --max-warnings=0
```
```bash
pnpm build
```

**yarn / Next.js:**
```bash
yarn tsc --noEmit
```
```bash
yarn eslint . --max-warnings=0
```
```bash
yarn build
```

**npm / Next.js:**
```bash
npx tsc --noEmit
```
```bash
npx eslint . --max-warnings=0
```
```bash
npm run build
```

**uv / Python:**
```bash
uv run pyright
```
```bash
uv run ruff check .
```
```bash
uv run pytest
```

### Step 3: Run Tests (if not already run)

For JavaScript/TypeScript projects, also run the test suite:
```bash
bun test
```
or
```bash
pnpm test
```
or
```bash
yarn test
```
or
```bash
npm test
```

For Python, `uv run pytest` was already included in step 2.

### Step 4: Report Results

Report in this exact format:

```
## Pre-PR Gate Results

| Check      | Status | Details |
|------------|--------|---------|
| Typecheck  | PASS/FAIL | {error count or "clean"} |
| Lint       | PASS/FAIL | {warning/error count or "clean"} |
| Build      | PASS/FAIL | {error summary or "clean"} |
| Tests      | PASS/FAIL | {N passing, N failing} |

**Verdict: GATE PASSED** or **Verdict: GATE FAILED — fix issues before creating PR**
```

If any check fails, include:
- The exact error output (first 50 lines if verbose)
- Suggested fix approach for each failure
- Which files are affected

## Key Principles

### Never Auto-Fix
This skill only validates. If it finds issues, report them clearly and let the user (or orchestrator) decide how to fix them. This prevents the gate from introducing new bugs.

### Stop on First Failure
Don't run build if typecheck fails. Don't run tests if build fails. Each stage depends on the previous one passing.

### Block PR Creation
If the gate fails, explicitly state: **"Do not create a PR until these issues are resolved."**

The gate is the last line of defense. It catches things that slipped through implementation and review.

## Integration

- Called automatically by `plangate:orchestrate` after all tasks complete
- Called automatically by `plangate:phase finish` before PR creation
- Can be invoked directly via `/plangate:gate`

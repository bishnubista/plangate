---
name: gate
description: "Stack-aware pre-PR validation gate. Auto-detects stack, validates typecheck + lint + build + tests. Use when the user says 'run gate', 'validate', 'check before PR', or 'run checks'."
---

# Pre-PR Gate: Stack-Aware Validation Pipeline

## Overview

Validates the project is in a clean, passing state before PR creation. Auto-detects the stack from the session manifest and selects the appropriate validation commands. Supports 6 language stacks (Node.js, Python, Kotlin, Go, Rust, Swift) with 9 toolchain configurations. This skill is **read-only** — it reports pass/fail with actionable suggestions but never modifies code.

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
| `build.gradle.kts` / `build.gradle` | kotlin | gradle |
| `go.mod` | go | go |
| `Cargo.toml` | rust | cargo |
| `Package.swift` | swift | spm |

Check for `next.config.js`/`next.config.ts`/`next.config.mjs` to distinguish Next.js from plain Node.

### Step 2: Custom Validation Commands

If a `.plangate.json` file exists in the project root, use its commands instead of the stack-detected defaults:

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

Any command set to `null` or omitted is skipped. Custom commands always take priority over auto-detected stack commands.

### Step 2.5: Read Manifest Commands (Preferred)

If `<plangate-manifest>` is available in session context, read the `Commands:` line. It contains pre-resolved commands for each stage. If a command is `SKIP`, skip that stage. This avoids re-deriving commands from the stack table.

### Step 3: Run 4-Stage Validation Pipeline

Run each stage sequentially. Stop on first **failure**.

**SKIP vs FAIL semantics:**
- **SKIP** means the stage is not configured for this project. SKIP does **NOT** count as failure and does **NOT** stop the pipeline.
- **FAIL** means the stage ran and produced errors. FAIL stops the pipeline immediately.
- **Conditions for SKIP:**
  - **Typecheck**: no TypeScript/type checker configured (rare — almost always runs)
  - **Lint**: no eslint config file (`.eslintrc.*`, `eslint.config.*`) AND no `lint` script in package.json. For non-JS stacks: linter binary not installed (`detekt`, `golangci-lint`, `clippy`, `swiftlint`)
  - **Build**: no `build` script in package.json (common for TypeScript-only projects using Bun/ts-node). For non-JS stacks: skip if stack has no build step (e.g., Python)
  - **Test**: no test files found AND no `test` script in package.json

| Stack | Typecheck | Lint | Build | Test |
|-------|-----------|------|-------|------|
| **bun** | `bunx tsc --noEmit` | `bunx eslint . --max-warnings=0` | `bun run build` | `bun test` |
| **pnpm** | `pnpm tsc --noEmit` | `pnpm eslint . --max-warnings=0` | `pnpm build` | `pnpm test` |
| **yarn** | `yarn tsc --noEmit` | `yarn eslint . --max-warnings=0` | `yarn build` | `yarn test` |
| **npm** | `npx tsc --noEmit` | `npx eslint . --max-warnings=0` | `npm run build` | `npm test` |
| **uv/Python** | `uv run pyright` | `uv run ruff check .` | — | `uv run pytest` |
| **gradle/Kotlin** | `./gradlew compileKotlin` | `./gradlew detekt` (if available, else skip) | `./gradlew build` | `./gradlew test` |
| **go** | `go vet ./...` | `golangci-lint run` (if available, else skip) | `go build ./...` | `go test ./...` |
| **cargo/Rust** | `cargo check` | `cargo clippy -- -D warnings` (if available, else skip) | `cargo build` | `cargo test` |
| **spm/Swift** | `swift build` | `swiftlint` (if available, else skip) | `swift build -c release` | `swift test` |

**Note on optional linters**: For stacks where the linter is optional (`detekt`, `golangci-lint`, `clippy`, `swiftlint`), check if the command exists before running. If not available, report as "SKIP (linter not installed)" rather than FAIL.

To check command availability, use:

```bash
command -v detekt >/dev/null 2>&1 || echo "not found"
```

### Step 4: Report Results

Report in this exact format:

```text
## Pre-PR Gate Results

| Check      | Status | Details |
|------------|--------|---------|
| Typecheck  | PASS/FAIL/SKIP | {error count or "clean"} |
| Lint       | PASS/FAIL/SKIP | {warning/error count or "clean"} |
| Build      | PASS/FAIL/SKIP | {error summary or "clean"} |
| Tests      | PASS/FAIL/SKIP | {N passing, N failing} |

**Verdict: GATE PASSED** or **Verdict: GATE FAILED — fix issues before creating PR**
```

If any check fails, include:
- The exact error output (first 50 lines if verbose)
- Suggested fix approach for each failure
- Which files are affected

## Key Principles

### Never Auto-Fix
This skill only validates. If it finds issues, report them clearly and let the user (or orchestrator) decide how to fix them. This prevents the gate from introducing new bugs.

### Stop on First Failure (but not on SKIP)
Don't run lint if typecheck fails. Don't run build if lint fails. Don't run tests if build fails. Each stage depends on the previous one passing. However, SKIP does not stop the pipeline — if lint is SKIPped, proceed to build normally.

### Block PR Creation
If the gate fails, explicitly state: **"Do not create a PR until these issues are resolved."**

The gate is the last line of defense. It catches things that slipped through implementation and review.

## Integration

- Called automatically by `plangate:orchestrate` after all tasks complete
- Called automatically by `plangate:phase finish` before PR creation
- Can be invoked directly via `/plangate:gate`

# plangate

PLAN.md-driven development with quality gates for [Claude Code](https://claude.com/claude-code).

Each task flows through: **implement** (subagent) > **build gate** (pass/fail) > **review** (independent subagent). Fresh context per stage prevents the failure mode where AI agents mark their own homework.

## Installation

```bash
/plugin marketplace add bishnubista/plangate
/plugin install plangate@plangate
```

Or run `/plugin` and install from the **Discover** tab.

## Prerequisites

- Claude Code installed (`claude --version`)
- Git repository initialized in your project
- GitHub CLI (`gh`) authenticated if you use `/plangate:phase finish` to create PRs
- Stack toolchain available for your project (or provide custom commands via `.plangate.json`)

## Marketplace Submission

Use `MARKETPLACE_SUBMISSION.md` as a copy-paste pack for Claude Plugin Directory submission fields.

Included assets:
- Listing copy and 3 example prompts: `MARKETPLACE_SUBMISSION.md`
- 1200x630 listing image: `assets/plangate-marketplace-card.svg`

## Commands

All commands are provided by plugin skills (no legacy `commands/*.md` wrappers).

| Command | What it does |
|---------|-------------|
| `/plangate:orchestrate [N]` | Execute phase N tasks through the full pipeline |
| `/plangate:gate` | Typecheck + lint + build + tests validation |
| `/plangate:status` | Show current phase, task progress, orchestration state |
| `/plangate:phase start N` / `finish` | Branch creation, PLAN.md updates, PR creation |
| `/plangate:investigate {name}` | Structured investigation doc for complex bugs |

## How It Works

### The Pipeline

For each task in a phase, the orchestrator runs:

```text
1. IMPLEMENTER (Sonnet subagent)
   Implement > write tests > self-validate > commit

2. BUILD GATE (Bash, no AI)
   typecheck > lint > build — objective pass/fail

3. REVIEWER (Sonnet subagent, independent)
   Spec compliance + code quality + distrust of implementer

4. UPDATE PLAN.MD
   Check off completed task
```

If any stage fails, a fix subagent is dispatched and the gate re-runs. Max 2 retries per stage.

### Why Independent Review Matters

The reviewer receives the original task spec and the git diff — never the implementer's self-assessment. It's explicitly told: **"Do NOT trust the implementer."** This catches skipped features, fake tests, missed edge cases, and bugs from blindly following patterns.

### Build Gate

`/plangate:gate` runs validation and reports results:

```text
| Check      | Status | Details              |
|------------|--------|----------------------|
| Typecheck  | PASS   | clean                |
| Lint       | PASS   | clean                |
| Build      | PASS   | clean                |
| Tests      | PASS   | 24 passing, 0 failing|

Verdict: GATE PASSED
```

The gate stops on first failure — build won't run if typecheck fails. Non-negotiable before every PR.

### Phase Lifecycle

```bash
/plangate:phase start 2 core-api    # Create branch feat/phase-2-core-api
/plangate:orchestrate 2              # Run all Phase 2 tasks through pipeline
/plangate:phase finish               # Gate + push + create PR
```

### Investigation Docs

For bugs that need more than a quick fix:

```bash
/plangate:investigate auth-token-expiry
# Creates docs/investigations/2026-02-07-auth-token-expiry.md
```

Tracks hypotheses, trials, root cause, and lessons learned. Follows the 3-fix rule: if 3 fixes fail, stop and question the architecture.

## Stack Detection

The session hook auto-detects your project stack. No manual configuration needed.

| Marker | Stack | Package Manager |
|--------|-------|-----------------|
| `bun.lock` | node/nextjs | bun |
| `pnpm-lock.yaml` | node/nextjs | pnpm |
| `yarn.lock` | node/nextjs | yarn |
| `package-lock.json` or `package.json` (fallback) | node/nextjs | npm |
| `pyproject.toml` | python | uv |
| `build.gradle.kts` | kotlin | gradle |
| `go.mod` | go | go |
| `Cargo.toml` | rust | cargo |
| `Package.swift` | swift | spm |

Override with `.plangate.json`:

```json
{
  "commands": {
    "typecheck": "your-custom-typecheck",
    "lint": "your-custom-lint",
    "build": "your-custom-build",
    "test": "your-custom-test"
  }
}
```

## When to Use

- Multi-task feature phases with a PLAN.md
- Projects where you want independent review of AI-generated code
- Teams that want a repeatable quality gate before every PR
- Any stack — Node.js, Python, Kotlin, Go, Rust, Swift

## Troubleshooting

### "Unknown skill: install-plugin"

There is no `/install-plugin` command. Use `/plugin install plangate@plangate` after adding the marketplace.

### "Orchestrate does nothing"

The skill reads `PLAN.md` for tasks. Create one with `- [ ]` checkboxes.

### "Stack detected as 'unknown'"

The hook needs lockfiles or `package.json`. Run `bun init`, `npm init`, etc., or create `.plangate.json` with custom commands.

### "Reviewer keeps finding issues in a loop"

Retry limit is 2 cycles. After that, the orchestrator stops and reports. The issues may indicate a deeper design problem.

## Privacy and Data Handling

- plangate is a local workflow plugin. It does not run its own hosted API.
- The plugin does not collect or transmit personal data to a plangate backend.
- Optional tools you invoke (`git`, `gh`) operate under your own local credentials and account settings.

## Support

- Issues: `https://github.com/bishnubista/plangate/issues`
- Contact: `collab@bishnu.dev`
- Troubleshooting guide: this README (see the Troubleshooting section above)

## Plugin Structure

```text
plangate/
  .claude-plugin/
    plugin.json              # Plugin metadata
    marketplace.json         # Marketplace catalog
  agents/
    implementer.md           # Implementation agent (Sonnet)
    reviewer.md              # Independent review agent (Sonnet)
  skills/
    orchestrate/SKILL.md     # /plangate:orchestrate
    gate/SKILL.md            # /plangate:gate
    status/SKILL.md          # /plangate:status
    phase/SKILL.md           # /plangate:phase
    investigate/SKILL.md     # /plangate:investigate
  hooks/
    hooks.json               # Hook registration
    session-start.sh         # Stack detection (9 languages)
  assets/
    plangate-marketplace-card.svg  # 1200x630 directory image
  MARKETPLACE_SUBMISSION.md  # Submission copy + prompt examples
  try-plangate.sh            # Plugin verification
```

## Verification

```bash
./try-plangate.sh              # Structure + hook output validation
./try-plangate.sh --scaffold   # Also create a sample project to test with
claude plugin validate .       # Official marketplace manifest check
```

## Author

Bishnu Bista (collab@bishnu.dev)

## License

MIT

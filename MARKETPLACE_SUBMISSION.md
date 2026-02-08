# Claude Plugin Directory Submission Pack

Last updated: 2026-02-08

## Plugin Name

`plangate`

## Repository URL

`https://github.com/bishnubista/plangate`

## Description (50-100 words)

plangate is a Claude Code plugin for PLAN.md-driven delivery. For each task, it enforces a deterministic pipeline: implementation subagent, objective quality gate (typecheck, lint, build, tests), and independent reviewer subagent before progress is recorded. It auto-detects stack commands across Node, Python, Kotlin, Go, Rust, and Swift, supports custom command overrides, and includes phase lifecycle workflows for branch management, orchestration checkpoints, and pre-PR validation.

## How The Software Works

The plugin installs skills, agents, and a session-start hook. The hook detects stack tooling and emits a `<plangate-manifest>` with resolved validation commands. Workflow skills use that manifest to run build gates, orchestrate tasks in sequence, track checkpoint state, and manage phase start/finish operations for branch and PR flow.

## Intended Purpose And Use Cases

- Teams running phase-based development from a `PLAN.md` checklist.
- Projects that want independent review of AI-generated code before marking tasks done.
- Repositories that need repeatable pre-PR validation without writing custom orchestration prompts each session.

## Troubleshooting Resources

- Main docs: `README.md`
- Common issues: `README.md` Troubleshooting section
- Local verification: `./try-plangate.sh`

## Example Prompts (3)

1. `/plangate:phase start 2 auth-and-permissions`
2. `/plangate:orchestrate 2`
3. `/plangate:investigate flaky-auth-refresh-tests`

## Contact Information

- Author: Bishnu Bista
- Email: `collab@bishnu.dev`
- Support issues: `https://github.com/bishnubista/plangate/issues`

## Test Account Requirements

No external account is required for plugin functionality. Optional `gh` authentication is only needed if the user chooses to create PRs with `/plangate:phase finish`.

## Listing Image

- Asset file: `assets/plangate-marketplace-card.svg`
- Suggested raw URL after push:
  `https://raw.githubusercontent.com/bishnubista/plangate/main/assets/plangate-marketplace-card.svg`

## Data Handling Statement

plangate has no hosted backend and does not collect user data. It runs local shell commands in the user repository and uses user-configured tooling (`git`, `gh`, project build tools).

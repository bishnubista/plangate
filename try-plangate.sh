#!/usr/bin/env bash
# try-plangate.sh — Verify plangate plugin structure and test in a sample project
#
# Usage:
#   ./try-plangate.sh              # Verify plugin structure only
#   ./try-plangate.sh --scaffold   # Also create a sample project to test with
#
# This script does NOT require Claude Code. It validates the plugin files
# and optionally scaffolds a sample project where you can test plangate skills.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
WARN=0

pass() { ((PASS++)); printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
fail() { ((FAIL++)); printf "  ${RED}✗${RESET} %s\n" "$1"; }
warn() { ((WARN++)); printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
header() { printf "\n${BOLD}${CYAN}▸ %s${RESET}\n" "$1"; }

# ─── Plugin Structure Check ───────────────────────────────────────────

header "Plugin Structure"

[[ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]] \
  && pass "plugin.json exists" \
  || fail "plugin.json missing — not a valid Claude Code plugin"

[[ -f "$PLUGIN_DIR/.claude-plugin/marketplace.json" ]] \
  && pass "marketplace.json exists" \
  || fail "marketplace.json missing — required for marketplace publishing"

[[ -f "$PLUGIN_DIR/LICENSE" ]] \
  && pass "LICENSE exists" \
  || warn "LICENSE missing"

[[ -f "$PLUGIN_DIR/README.md" ]] \
  && pass "README.md exists" \
  || warn "README.md missing"

# ─── Skills Check ─────────────────────────────────────────────────────

header "Skills"

expected_skills=(orchestrate gate phase investigate status)
for skill in "${expected_skills[@]}"; do
  if [[ -f "$PLUGIN_DIR/skills/$skill/SKILL.md" ]]; then
    # Check frontmatter has name field
    if head -5 "$PLUGIN_DIR/skills/$skill/SKILL.md" | grep -q "^name:"; then
      pass "skills/$skill/SKILL.md — valid"
    else
      warn "skills/$skill/SKILL.md — missing 'name:' in frontmatter"
    fi
  else
    fail "skills/$skill/SKILL.md — missing"
  fi
done

# ─── Legacy Commands Check ────────────────────────────────────────────

header "Legacy Commands"

if [[ -d "$PLUGIN_DIR/commands" ]]; then
  warn "commands/ directory present — legacy command wrappers are deprecated; prefer skills/"
else
  pass "No commands/ directory (skills-only plugin layout)"
fi

# ─── Hooks Check ──────────────────────────────────────────────────────

header "Hooks"

if [[ -f "$PLUGIN_DIR/hooks/hooks.json" ]]; then
  pass "hooks/hooks.json — exists"
else
  fail "hooks/hooks.json — missing"
fi

if [[ -f "$PLUGIN_DIR/hooks/session-start.sh" ]]; then
  if [[ -x "$PLUGIN_DIR/hooks/session-start.sh" ]]; then
    pass "hooks/session-start.sh — exists and executable"
  else
    warn "hooks/session-start.sh — exists but NOT executable (run: chmod +x hooks/session-start.sh)"
  fi
else
  fail "hooks/session-start.sh — missing"
fi

# ─── Hook Output Test ─────────────────────────────────────────────────

header "Session Hook Output (simulated)"

# Helper: run hook, print output, and assert expected strings
TEMP_DIR=$(mktemp -d)

run_hook() {
  CLAUDE_PROJECT_DIR="$TEMP_DIR" bash "$PLUGIN_DIR/hooks/session-start.sh" 2>/dev/null
}

print_output() {
  local output="$1"
  while IFS= read -r line; do
    printf "  ${DIM}│${RESET} %s\n" "$line"
  done <<< "$output"
}

assert_contains() {
  local output="$1" expected="$2" label="$3"
  if echo "$output" | grep -qF "$expected"; then
    pass "$label"
  else
    fail "$label (expected '$expected' in output)"
  fi
}

# --- Empty project (unknown stack) ---
printf "  ${DIM}Testing hook with no project markers...${RESET}\n"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: unknown" "Empty project → Stack: unknown"
assert_contains "$hook_out" "Package manager: none" "Empty project → Package manager: none"

# --- bun + Next.js ---
printf "\n  ${DIM}Testing hook with bun + Next.js markers...${RESET}\n"
touch "$TEMP_DIR/package.json" "$TEMP_DIR/bun.lock" "$TEMP_DIR/next.config.ts"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: nextjs" "bun+Next.js → Stack: nextjs"
assert_contains "$hook_out" "Package manager: bun" "bun+Next.js → Package manager: bun"
assert_contains "$hook_out" "typecheck=bunx tsc --noEmit" "bun+Next.js → typecheck command"
assert_contains "$hook_out" "build=bun run build" "bun+Next.js → build command"
assert_contains "$hook_out" "plangate:status" "bun+Next.js → status skill in manifest"

# --- pnpm ---
printf "\n  ${DIM}Testing hook with pnpm markers...${RESET}\n"
rm -f "$TEMP_DIR/bun.lock" "$TEMP_DIR/next.config.ts"
touch "$TEMP_DIR/pnpm-lock.yaml"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Package manager: pnpm" "pnpm → Package manager: pnpm"
assert_contains "$hook_out" "typecheck=pnpm tsc --noEmit" "pnpm → typecheck command"

# --- Python/uv ---
printf "\n  ${DIM}Testing hook with Python/uv markers...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/pyproject.toml"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: python" "Python → Stack: python"
assert_contains "$hook_out" "Package manager: uv" "Python → Package manager: uv"
assert_contains "$hook_out" "typecheck=uv run pyright" "Python → typecheck command"
assert_contains "$hook_out" "build=SKIP" "Python → build=SKIP"

# --- Kotlin/Gradle ---
printf "\n  ${DIM}Testing hook with Kotlin/Gradle markers...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/build.gradle.kts"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: kotlin" "Kotlin → Stack: kotlin"
assert_contains "$hook_out" "Package manager: gradle" "Kotlin → Package manager: gradle"
assert_contains "$hook_out" "typecheck=./gradlew compileKotlin" "Kotlin → typecheck command"

# --- Go ---
printf "\n  ${DIM}Testing hook with Go markers...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/go.mod"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: go" "Go → Stack: go"
assert_contains "$hook_out" "Package manager: go" "Go → Package manager: go"
assert_contains "$hook_out" "typecheck=go vet ./..." "Go → typecheck command"

# --- Rust/Cargo ---
printf "\n  ${DIM}Testing hook with Rust/Cargo markers...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/Cargo.toml"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: rust" "Rust → Stack: rust"
assert_contains "$hook_out" "Package manager: cargo" "Rust → Package manager: cargo"
assert_contains "$hook_out" "typecheck=cargo check" "Rust → typecheck command"

# --- Swift/SPM ---
printf "\n  ${DIM}Testing hook with Swift/SPM markers...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/Package.swift"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Stack: swift" "Swift → Stack: swift"
assert_contains "$hook_out" "Package manager: spm" "Swift → Package manager: spm"
assert_contains "$hook_out" "typecheck=swift build" "Swift → typecheck command"

# --- Custom config ---
printf "\n  ${DIM}Testing hook with .plangate.json custom config...${RESET}\n"
rm -rf "${TEMP_DIR:?}"/*
touch "$TEMP_DIR/package.json" "$TEMP_DIR/bun.lock"
echo '{"commands":{"build":"custom-build"}}' > "$TEMP_DIR/.plangate.json"
hook_out=$(run_hook)
print_output "$hook_out"
assert_contains "$hook_out" "Custom config: true" "Custom config → Custom config: true"
assert_contains "$hook_out" "build=custom-build" "Custom config → build=custom-build"

rm -rf "$TEMP_DIR"

# ─── Agents Check ─────────────────────────────────────────────────────

header "Agents"

expected_agents=(implementer reviewer)
for agent in "${expected_agents[@]}"; do
  if [[ -f "$PLUGIN_DIR/agents/$agent.md" ]]; then
    if head -10 "$PLUGIN_DIR/agents/$agent.md" | grep -q "^name:"; then
      pass "agents/$agent.md — valid"
    else
      warn "agents/$agent.md — missing 'name:' in frontmatter"
    fi
  else
    fail "agents/$agent.md — missing (orchestrate needs this)"
  fi
done

# Check agents have model specified
for agent in "${expected_agents[@]}"; do
  if [[ -f "$PLUGIN_DIR/agents/$agent.md" ]]; then
    if head -10 "$PLUGIN_DIR/agents/$agent.md" | grep -q "^model:"; then
      pass "agents/$agent.md — model specified"
    else
      warn "agents/$agent.md — no model in frontmatter"
    fi
  fi
done

# ─── disable-model-invocation Audit ───────────────────────────────────

header "Model Invocation Control"

# Side-effect skills MUST have disable-model-invocation: true
for skill in orchestrate phase investigate; do
  if head -10 "$PLUGIN_DIR/skills/$skill/SKILL.md" | grep -q "disable-model-invocation: true"; then
    pass "skills/$skill — correctly blocks auto-invocation"
  else
    fail "skills/$skill — MISSING disable-model-invocation (side-effect skill!)"
  fi
done

# Auto-invocable skills must NOT have it
for skill in gate status; do
  if head -10 "$PLUGIN_DIR/skills/$skill/SKILL.md" | grep -q "disable-model-invocation: true"; then
    fail "skills/$skill — should NOT block auto-invocation (read-only/auto-trigger skill)"
  else
    pass "skills/$skill — correctly allows auto-invocation"
  fi
done

# ─── Marketplace Readiness Assets ──────────────────────────────────────

header "Marketplace Readiness Assets"

if [[ -f "$PLUGIN_DIR/MARKETPLACE_SUBMISSION.md" ]]; then
  pass "MARKETPLACE_SUBMISSION.md — exists"
else
  warn "MARKETPLACE_SUBMISSION.md — missing (add submission copy and prompts)"
fi

if [[ -f "$PLUGIN_DIR/assets/plangate-marketplace-card.svg" ]]; then
  pass "assets/plangate-marketplace-card.svg — exists (1200x630 listing image)"
else
  warn "assets/plangate-marketplace-card.svg — missing listing image asset"
fi

if command -v claude >/dev/null 2>&1; then
  if claude plugin validate "$PLUGIN_DIR" >/dev/null 2>&1; then
    pass "claude plugin validate — passed"
  else
    fail "claude plugin validate — failed"
  fi
else
  warn "claude CLI not found — skipped 'claude plugin validate'"
fi

# ─── Summary ──────────────────────────────────────────────────────────

printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "  ${GREEN}${PASS} passed${RESET}  ${RED}${FAIL} failed${RESET}  ${YELLOW}${WARN} warnings${RESET}\n"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

if [[ $FAIL -gt 0 ]]; then
  printf "\n${RED}Plugin has structural issues. Fix failures above before publishing.${RESET}\n"
  exit 1
fi

if [[ $WARN -gt 0 ]]; then
  printf "\n${YELLOW}Plugin is functional but has minor issues.${RESET}\n"
fi

# ─── Scaffold Sample Project ──────────────────────────────────────────

if [[ "${1:-}" == "--scaffold" ]]; then
  SAMPLE_DIR="$PLUGIN_DIR/sample-project"
  header "Scaffolding Sample Project at $SAMPLE_DIR"

  mkdir -p "$SAMPLE_DIR"
  cd "$SAMPLE_DIR"

  # Create minimal package.json
  cat > package.json <<'PACKAGE'
{
  "name": "plangate-sample",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "build": "echo 'Build OK'",
    "test": "echo 'Tests OK'",
    "lint": "echo 'Lint OK'"
  }
}
PACKAGE
  pass "Created package.json"

  # Create bun.lock to trigger bun detection
  touch bun.lock
  pass "Created bun.lock (triggers bun stack detection)"

  # Create next.config.ts to trigger Next.js detection
  cat > next.config.ts <<'NEXT'
import type { NextConfig } from "next";
const nextConfig: NextConfig = {};
export default nextConfig;
NEXT
  pass "Created next.config.ts (triggers Next.js detection)"

  # Create PLAN.md with sample tasks
  cat > PLAN.md <<'PLAN'
# Sample Project Plan

## Phase 1 — Foundation Setup
**Status: Not Started**

- [ ] Task 1.1: Create project structure with src/ directory and basic layout
- [ ] Task 1.2: Add a health-check API endpoint at /api/health
- [ ] Task 1.3: Set up basic error handling middleware

## Phase 2 — Core Features
**Status: Not Started**

- [ ] Task 2.1: Implement user model and database schema
- [ ] Task 2.2: Add authentication endpoints (login, signup, logout)
- [ ] Task 2.3: Create protected route middleware
PLAN
  pass "Created PLAN.md with sample phases"

  # Initialize git
  if [[ ! -d .git ]]; then
    git init -q
    git add -A
    git commit -q -m "chore: scaffold sample project for plangate testing"
    pass "Initialized git repo with initial commit"
  else
    pass "Git repo already exists"
  fi

  printf "\n${BOLD}${GREEN}Sample project ready!${RESET}\n"
  printf "\n${BOLD}To test plangate:${RESET}\n"
  printf "  ${CYAN}cd %s${RESET}\n" "$SAMPLE_DIR"
  printf "  ${CYAN}claude${RESET}          ${DIM}# Start Claude Code${RESET}\n"
  printf "\n${BOLD}Then try these commands in Claude Code:${RESET}\n"
  printf "  ${CYAN}/plangate:gate${RESET}                        ${DIM}# Run validation gate${RESET}\n"
  printf "  ${CYAN}/plangate:status${RESET}                      ${DIM}# Show progress overview${RESET}\n"
  printf "  ${CYAN}/plangate:phase start 1 foundation${RESET}    ${DIM}# Start phase 1${RESET}\n"
  printf "  ${CYAN}/plangate:orchestrate 1${RESET}               ${DIM}# Execute phase 1 tasks${RESET}\n"
  printf "  ${CYAN}/plangate:investigate slow-query${RESET}       ${DIM}# Create investigation doc${RESET}\n"
  printf "  ${CYAN}/plangate:phase finish${RESET}                 ${DIM}# Finish and create PR${RESET}\n"
else
  printf "\n${BOLD}Tip:${RESET} Run with ${CYAN}--scaffold${RESET} to create a sample project:\n"
  printf "  ${CYAN}./try-plangate.sh --scaffold${RESET}\n"
fi

printf "\n${BOLD}Installation:${RESET}\n"
printf "  ${DIM}# Add as marketplace, then install:${RESET}\n"
printf "  ${CYAN}/plugin marketplace add %s${RESET}\n" "$PLUGIN_DIR"
printf "  ${CYAN}/plugin install plangate@plangate${RESET}\n"
printf "\n"

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

[[ -f "$PLUGIN_DIR/LICENSE" ]] \
  && pass "LICENSE exists" \
  || warn "LICENSE missing"

[[ -f "$PLUGIN_DIR/README.md" ]] \
  && pass "README.md exists" \
  || warn "README.md missing"

# ─── Skills Check ─────────────────────────────────────────────────────

header "Skills"

expected_skills=(orchestrate gate phase investigate supabase-migrate)
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

# ─── Commands Check ───────────────────────────────────────────────────

header "Commands"

expected_commands=(orchestrate gate phase investigate supabase-migrate)
for cmd in "${expected_commands[@]}"; do
  if [[ -f "$PLUGIN_DIR/commands/$cmd.md" ]]; then
    pass "commands/$cmd.md — exists"
  else
    fail "commands/$cmd.md — missing"
  fi
done

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

# Test the hook with a fake project dir
printf "  ${DIM}Testing hook with no project markers...${RESET}\n"
TEMP_DIR=$(mktemp -d)
CLAUDE_PROJECT_DIR="$TEMP_DIR" bash "$PLUGIN_DIR/hooks/session-start.sh" 2>/dev/null | while IFS= read -r line; do
  printf "  ${DIM}│${RESET} %s\n" "$line"
done
pass "Hook runs with empty project (unknown stack)"

# Test with bun + next.js markers
printf "\n  ${DIM}Testing hook with bun + Next.js markers...${RESET}\n"
touch "$TEMP_DIR/package.json" "$TEMP_DIR/bun.lock" "$TEMP_DIR/next.config.ts"
CLAUDE_PROJECT_DIR="$TEMP_DIR" bash "$PLUGIN_DIR/hooks/session-start.sh" 2>/dev/null | while IFS= read -r line; do
  printf "  ${DIM}│${RESET} %s\n" "$line"
done
pass "Hook detects bun + Next.js stack"

# Test with pnpm + supabase
printf "\n  ${DIM}Testing hook with pnpm + Supabase markers...${RESET}\n"
rm -f "$TEMP_DIR/bun.lock" "$TEMP_DIR/next.config.ts"
touch "$TEMP_DIR/pnpm-lock.yaml"
mkdir -p "$TEMP_DIR/supabase"
CLAUDE_PROJECT_DIR="$TEMP_DIR" bash "$PLUGIN_DIR/hooks/session-start.sh" 2>/dev/null | while IFS= read -r line; do
  printf "  ${DIM}│${RESET} %s\n" "$line"
done
pass "Hook detects pnpm + Supabase stack"

# Test with python/uv
printf "\n  ${DIM}Testing hook with Python/uv markers...${RESET}\n"
rm -rf "$TEMP_DIR"/*
touch "$TEMP_DIR/pyproject.toml"
CLAUDE_PROJECT_DIR="$TEMP_DIR" bash "$PLUGIN_DIR/hooks/session-start.sh" 2>/dev/null | while IFS= read -r line; do
  printf "  ${DIM}│${RESET} %s\n" "$line"
done
pass "Hook detects Python/uv stack"

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
for skill in gate supabase-migrate; do
  if head -10 "$PLUGIN_DIR/skills/$skill/SKILL.md" | grep -q "disable-model-invocation: true"; then
    fail "skills/$skill — should NOT block auto-invocation (read-only/auto-trigger skill)"
  else
    pass "skills/$skill — correctly allows auto-invocation"
  fi
done

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
  printf "  ${CYAN}/plangate:phase start 1 foundation${RESET}    ${DIM}# Start phase 1${RESET}\n"
  printf "  ${CYAN}/plangate:orchestrate 1${RESET}               ${DIM}# Execute phase 1 tasks${RESET}\n"
  printf "  ${CYAN}/plangate:investigate slow-query${RESET}       ${DIM}# Create investigation doc${RESET}\n"
  printf "  ${CYAN}/plangate:phase finish${RESET}                 ${DIM}# Finish and create PR${RESET}\n"
else
  printf "\n${BOLD}Tip:${RESET} Run with ${CYAN}--scaffold${RESET} to create a sample project:\n"
  printf "  ${CYAN}./try-plangate.sh --scaffold${RESET}\n"
fi

printf "\n${BOLD}Installation:${RESET}\n"
printf "  ${DIM}# From the target project directory:${RESET}\n"
printf "  ${CYAN}claude /install-plugin file://%s${RESET}\n" "$PLUGIN_DIR"
printf "\n"

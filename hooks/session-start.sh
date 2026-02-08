#!/usr/bin/env bash
# plangate session-start hook
# Detects project stack and injects a lightweight skill manifest (~15 lines)

set -euo pipefail

# Use CLAUDE_PROJECT_DIR for robust project-root resolution
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# --- Stack detection ---
stack=""
pkg_manager=""
has_supabase=false

if [[ -f "$project_dir/pyproject.toml" ]]; then
  stack="python"
  pkg_manager="uv"
fi

if [[ -f "$project_dir/package.json" ]]; then
  if [[ -f "$project_dir/bun.lock" || -f "$project_dir/bun.lockb" ]]; then
    pkg_manager="bun"
  elif [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
    pkg_manager="pnpm"
  elif [[ -f "$project_dir/yarn.lock" ]]; then
    pkg_manager="yarn"
  else
    pkg_manager="npm"
  fi

  if [[ -f "$project_dir/next.config.js" || -f "$project_dir/next.config.ts" || -f "$project_dir/next.config.mjs" ]]; then
    stack="nextjs"
  else
    stack="node"
  fi
fi

if [[ -d "$project_dir/supabase" || -f "$project_dir/supabase/config.toml" ]]; then
  has_supabase=true
fi

# --- Emit manifest ---
cat <<EOF
<plangate-manifest>
Stack: ${stack:-unknown} | Package manager: ${pkg_manager:-none} | Supabase: ${has_supabase}

Auto-invocable skills (Claude can use directly):
  plangate:gate              — Typecheck + lint + build validation. ALWAYS run before creating PRs.
  plangate:supabase-migrate  — After DDL changes: regen types, check RLS/indexes.

User-invoked workflows (run via / commands):
  /plangate:orchestrate [N]        — Multi-task orchestration with sequential gates.
  /plangate:phase start N | finish — Phase lifecycle: branch creation, PLAN.md updates, PR creation.
  /plangate:investigate [name]     — Create structured investigation doc for complex bugs.

Rules:
  - If stack is Next.js + bun + Supabase, prefer Bun-first validation/build commands.
  - Always run plangate:gate before creating any PR.
  - After Supabase migrations, run plangate:supabase-migrate.
  - Do NOT invoke orchestrate, phase, or investigate via the Skill tool. These are user-triggered only.
</plangate-manifest>
EOF

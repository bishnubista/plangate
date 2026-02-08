#!/usr/bin/env bash
# plangate session-start hook
# Detects project stack and injects a lightweight skill manifest (~15 lines)

set -euo pipefail

# Use CLAUDE_PROJECT_DIR for robust project-root resolution
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# --- Stack detection ---
stack=""
pkg_manager=""
has_custom_config=false

if [[ -f "$project_dir/pyproject.toml" ]]; then
  stack="python"
  pkg_manager="uv"
fi

# Kotlin/Gradle
if [[ -f "$project_dir/build.gradle.kts" || -f "$project_dir/build.gradle" ]]; then
  stack="kotlin"
  pkg_manager="gradle"
fi

# Go
if [[ -f "$project_dir/go.mod" ]]; then
  stack="go"
  pkg_manager="go"
fi

# Rust
if [[ -f "$project_dir/Cargo.toml" ]]; then
  stack="rust"
  pkg_manager="cargo"
fi

# Swift (SPM)
if [[ -f "$project_dir/Package.swift" ]]; then
  stack="swift"
  pkg_manager="spm"
fi

if [[ -f "$project_dir/package.json" ]]; then
  if [[ -z "$pkg_manager" ]]; then
    if [[ -f "$project_dir/bun.lock" || -f "$project_dir/bun.lockb" ]]; then
      pkg_manager="bun"
    elif [[ -f "$project_dir/pnpm-lock.yaml" ]]; then
      pkg_manager="pnpm"
    elif [[ -f "$project_dir/yarn.lock" ]]; then
      pkg_manager="yarn"
    else
      pkg_manager="npm"
    fi
  fi

  if [[ -z "$stack" ]]; then
    if [[ -f "$project_dir/next.config.js" || -f "$project_dir/next.config.ts" || -f "$project_dir/next.config.mjs" ]]; then
      stack="nextjs"
    else
      stack="node"
    fi
  fi
fi

if [[ -f "$project_dir/.plangate.json" ]]; then
  has_custom_config=true
fi

read_custom_cmd() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.commands[$key] | select(type=="string")' "$project_dir/.plangate.json" 2>/dev/null || true
  else
    grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$project_dir/.plangate.json" 2>/dev/null | sed 's/.*:.*"\(.*\)"/\1/' || true
  fi
}

# --- Resolve validation commands ---
# Custom config overrides stack-detected defaults
cmd_typecheck=""
cmd_lint=""
cmd_build=""
cmd_test=""

if [[ "$has_custom_config" == "true" ]]; then
  # Read commands from .plangate.json (jq when available, grep fallback)
  cmd_typecheck=$(read_custom_cmd "typecheck")
  cmd_lint=$(read_custom_cmd "lint")
  cmd_build=$(read_custom_cmd "build")
  cmd_test=$(read_custom_cmd "test")
else
  case "${pkg_manager:-none}" in
    bun)
      cmd_typecheck="bunx tsc --noEmit"
      cmd_lint="bunx eslint . --max-warnings=0"
      cmd_build="bun run build"
      cmd_test="bun test"
      ;;
    pnpm)
      cmd_typecheck="pnpm tsc --noEmit"
      cmd_lint="pnpm eslint . --max-warnings=0"
      cmd_build="pnpm build"
      cmd_test="pnpm test"
      ;;
    yarn)
      cmd_typecheck="yarn tsc --noEmit"
      cmd_lint="yarn eslint . --max-warnings=0"
      cmd_build="yarn build"
      cmd_test="yarn test"
      ;;
    npm)
      cmd_typecheck="npx tsc --noEmit"
      cmd_lint="npx eslint . --max-warnings=0"
      cmd_build="npm run build"
      cmd_test="npm test"
      ;;
    uv)
      cmd_typecheck="uv run pyright"
      cmd_lint="uv run ruff check ."
      cmd_build=""
      cmd_test="uv run pytest"
      ;;
    gradle)
      cmd_typecheck="./gradlew compileKotlin"
      cmd_lint="./gradlew detekt"
      cmd_build="./gradlew build"
      cmd_test="./gradlew test"
      ;;
    go)
      cmd_typecheck="go vet ./..."
      cmd_lint="golangci-lint run"
      cmd_build="go build ./..."
      cmd_test="go test ./..."
      ;;
    cargo)
      cmd_typecheck="cargo check"
      cmd_lint="cargo clippy -- -D warnings"
      cmd_build="cargo build"
      cmd_test="cargo test"
      ;;
    spm)
      cmd_typecheck="swift build"
      cmd_lint="swiftlint"
      cmd_build="swift build -c release"
      cmd_test="swift test"
      ;;
  esac
fi

# --- Emit manifest ---
cat <<EOF
<plangate-manifest>
Stack: ${stack:-unknown} | Package manager: ${pkg_manager:-none} | Custom config: ${has_custom_config}
Commands: typecheck=${cmd_typecheck:-SKIP} | lint=${cmd_lint:-SKIP} | build=${cmd_build:-SKIP} | test=${cmd_test:-SKIP}

Auto-invocable skills (Claude can use directly):
  plangate:gate              — Typecheck + lint + build validation. ALWAYS run before creating PRs.
  plangate:status            — Show current phase, task progress, and orchestration state.

User-invoked workflows (run via / commands):
  /plangate:orchestrate [N]        — Multi-task orchestration with sequential gates.
  /plangate:phase start N | finish — Phase lifecycle: branch creation, PLAN.md updates, PR creation.
  /plangate:investigate [name]     — Create structured investigation doc for complex bugs.
  /plangate:status                 — Quick project progress overview.

Rules:
  - Always run plangate:gate before creating any PR.
  - Use the Commands line above for validation. SKIP means that stage should be skipped.
  - Do NOT invoke orchestrate, phase, or investigate via the Skill tool. These are user-triggered only.
</plangate-manifest>
EOF

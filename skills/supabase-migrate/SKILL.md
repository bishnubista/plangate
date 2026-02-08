---
name: supabase-migrate
description: "Run after any Supabase DDL change or migration. Regenerates TypeScript types, checks security advisors (RLS), checks performance advisors (indexes), and auto-stages the generated type file."
---

# Supabase Post-Migration: Type Generation and Advisory Checks

## Overview

After any DDL change (creating tables, altering columns, adding policies), this skill ensures TypeScript types stay in sync and catches common security/performance issues. Run this every time you apply a migration.

## The Process

### Step 1: Detect Supabase Configuration

Check for Supabase project configuration:

1. Look for `supabase/config.toml` (local development)
2. Check `<plangate-manifest>` for Supabase flag
3. Check `.env` or `.env.local` for `SUPABASE_PROJECT_REF` or `NEXT_PUBLIC_SUPABASE_URL` (extract project ref from URL)
4. Check if Supabase MCP is available (for remote operations)

### Step 2: Regenerate TypeScript Types

**Option A — Local CLI (preferred if `supabase` CLI is linked):**
```bash
supabase gen types typescript --local > src/lib/database.types.ts
```

Or if the project uses a different types path (check existing imports):
```bash
supabase gen types typescript --local > {TYPES_PATH}
```

**Option B — MCP (if using remote project):**
Use `generate_typescript_types` MCP tool with the project ID.

Then write the output to the appropriate types file.

**Option C — Linked remote project:**
```bash
supabase gen types typescript --project-id {PROJECT_REF} > {TYPES_PATH}
```

### Step 3: Check Security Advisors

**Via MCP:**
Use `get_advisors` tool with `type: "security"` and the project ID.

**Via CLI (local):**
```bash
supabase inspect db lint
```

Focus on:
- **Missing RLS policies** — Tables without row-level security enabled
- **Permissive policies** — Policies that grant too-broad access
- **Missing auth checks** — Public access to sensitive tables

Report each finding with:
- Table name
- Issue description
- Remediation URL (if provided by advisor)
- Suggested fix (e.g., "Enable RLS: `ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;`")

### Step 4: Check Performance Advisors

**Via MCP:**
Use `get_advisors` tool with `type: "performance"` and the project ID.

Focus on:
- **Missing indexes** — Columns used in WHERE clauses without indexes
- **Unused indexes** — Indexes that waste space
- **Bloated tables** — Tables needing VACUUM

Report each finding with severity and suggested action.

### Step 5: Auto-Stage Type File

```bash
git add {TYPES_PATH}
```

This ensures the regenerated types are included in the next commit.

### Step 6: Report

```
## Supabase Post-Migration Report

**Types:** Regenerated at {TYPES_PATH}

**Security Advisors:**
| Table | Issue | Severity | Action |
|-------|-------|----------|--------|
| {table} | {issue} | {severity} | {action} |

**Performance Advisors:**
| Issue | Severity | Action |
|-------|----------|--------|
| {issue} | {severity} | {action} |

**Staged files:** {TYPES_PATH}

{If security issues found:}
⚠️ Security issues found. Address RLS policies before proceeding.

{If no issues:}
✓ No security or performance issues detected.
```

## Key Principles

### Types Must Stay in Sync
Stale TypeScript types are a common source of runtime errors that the type checker can't catch. Regenerating after every DDL change prevents this.

### RLS Is Non-Negotiable
Every table that holds user data must have RLS enabled. The security advisor check catches tables where this was forgotten.

### Don't Auto-Fix Security Issues
Report security findings but don't automatically add RLS policies. The user needs to design policies based on their access patterns. Bad auto-generated policies are worse than no policies.

## Integration

- Triggered automatically by `plangate:orchestrate` when a task involves Supabase migrations
- Can be invoked directly after running `apply_migration` MCP tool
- Can be invoked directly via `/plangate:supabase-migrate`

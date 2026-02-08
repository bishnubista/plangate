---
name: investigate
description: "Create a structured investigation document for complex bugs. Use when a bug requires more than a quick fix — tracks hypotheses, trials, root cause, and lessons learned."
disable-model-invocation: true
---

# Investigate: Structured Bug Investigation

## Overview

When a bug requires more than a quick fix, create a structured investigation document that tracks your debugging process. This prevents repeating failed approaches, documents root causes for future reference, and builds a knowledge base of project-specific issues.

## Arguments

`/plangate:investigate {problem-name}` — Creates or resumes an investigation doc

## The Process

### Step 1: Create Investigation Document

Create the file at:
```
docs/investigations/{YYYY-MM-DD}-{problem-name}.md
```

Ensure the directory exists:
```bash
mkdir -p docs/investigations
```

Use this template:

```markdown
# Investigation: {Problem Name}

**Date:** {YYYY-MM-DD}
**Status:** Open
**Severity:** {Critical/High/Medium/Low}

## Problem Statement

{Clear description of the bug: what happens, what should happen, when it was first observed}

## Reproduction Steps

1. {Step 1}
2. {Step 2}
3. {Expected: ...}
4. {Actual: ...}

## Environment

- Stack: {from plangate-manifest}
- Branch: {current git branch}
- Last known working commit: {SHA if known}

## Hypothesis Log

| # | Hypothesis | Evidence For | Evidence Against | Status |
|---|-----------|-------------|-----------------|--------|
| 1 | {hypothesis} | {evidence} | {evidence} | Testing/Confirmed/Rejected |

## Trial Log

| # | Action | Expected | Actual | Result | Duration |
|---|--------|----------|--------|--------|----------|
| 1 | {what you tried} | {expected outcome} | {actual outcome} | ✅/❌ | {time} |

## Root Cause

{Filled in when root cause is identified}

## Fix Applied

{Description of the fix, with commit SHA}

## Lessons Learned

- {What would have helped find this faster?}
- {What pattern should be avoided?}
- {What should be added to testing?}
```

### Step 2: Update Incrementally

As you debug, update the document in real-time:

1. **Before each attempt:** Add a hypothesis to the Hypothesis Log
2. **After each attempt:** Add a row to the Trial Log with results
3. **When evidence changes:** Update hypothesis statuses

### Step 3: Apply the 3-Fix Rule

From Superpowers' systematic debugging:

- If < 3 fixes attempted: continue investigating
- **If >= 3 fixes failed:** STOP and question the architecture
  - Is this a symptom of a deeper design issue?
  - Are fixes revealing new problems in different places?
  - Should you refactor rather than patch?
  - Discuss with the user before attempting more fixes

### Step 4: Close the Investigation

When the fix is applied and verified:

1. Update the **Status** to `Resolved`
2. Fill in **Root Cause** section
3. Fill in **Fix Applied** with commit SHA
4. Fill in **Lessons Learned**
5. Commit the investigation doc: `git commit -m "docs: close investigation — {problem-name}"`

## Key Principles

### Always Write It Down
The investigation doc is not optional overhead. It prevents you from:
- Retrying failed approaches
- Losing context when the conversation gets long
- Forgetting why you rejected a hypothesis

### Update Before and After Every Trial
Don't batch updates. Record each hypothesis and trial as you go. If the investigation gets interrupted (context limit, session end), the document preserves all progress.

### Lessons Learned Are the Most Valuable Section
After closing an investigation, the Lessons Learned section is what prevents the same bug class from recurring. Be specific — "add integration tests for X" is better than "test more."

## Integration

- Standalone skill — does not depend on other plangate skills
- Investigation docs are committed to the repo for team reference
- Can be resumed across sessions by reading the existing doc

# Changelog

## [1.1.2] - 2026-02-08

### Added
- Added `MARKETPLACE_SUBMISSION.md` with submission-ready listing copy, required form answers, and 3 example prompts
- Added `assets/plangate-marketplace-card.svg` (1200x630) for Claude Plugin Directory listing image

### Changed
- Improved plugin and marketplace descriptions for directory listing quality
- Updated verification script to check marketplace manifest presence, submission assets, and `claude plugin validate`
- Added privacy/data-handling and support sections to README
- Bumped marketplace and plugin manifest versions to `1.1.2`

## [1.1.1] - 2026-02-08

### Changed
- Migrated to skills-only command delivery (removed legacy `commands/*.md` wrappers)
- Updated verification script and docs for the skills-only plugin layout
- Removed stale Supabase marker from session manifest output
- Added explicit runtime prerequisites in README
- Bumped marketplace and plugin manifest versions to `1.1.1`

## [1.1.0] - 2026-02-08

### Changed
- Fixed installation docs — replaced invalid `/install-plugin` with correct `/plugin install` syntax
- Improved skill descriptions with trigger-aware patterns for better auto-invocation
- Fixed gate description from "Bun + Next.js" to stack-agnostic
- Updated keywords for broader discoverability
- Rewrote README for marketplace submission quality
- Simplified orchestration pipeline from 6 stages to 5

### Removed
- Removed `supabase-migrate` skill and command — database workflows don't belong in a planning/quality plugin. Use the Supabase MCP plugin directly.

## [1.0.0] - 2026-02-08

### Added
- Orchestration pipeline: implement > build gate > independent review
- Stack detection for 9 languages (Node.js, Python, Kotlin, Go, Rust, Swift + package managers)
- Checkpoint/resume for long-running orchestrations
- Phase lifecycle management (branch, orchestrate, PR)
- Investigation docs for structured debugging
- 2 specialized agents: implementer (Sonnet) and reviewer (Sonnet)
- Session-start hook with auto-manifest injection
- Plugin verification script (try-plangate.sh)
- Custom validation via `.plangate.json`

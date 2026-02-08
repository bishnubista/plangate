# Contributing

plangate is a Claude Code plugin — Markdown skills and a Bash hook. No build step, no dependencies.

## Structure

```text
.claude-plugin/plugin.json       # Plugin metadata
.claude-plugin/marketplace.json  # Marketplace catalog
agents/*.md                      # Specialized agent definitions
skills/*/SKILL.md                # Skill definitions (workflow logic)
hooks/session-start.sh           # Stack detection hook
MARKETPLACE_SUBMISSION.md        # Submission copy/prompt pack
assets/*.svg                     # Marketplace listing assets
try-plangate.sh                  # Plugin verification script
```

## Setup

```bash
git clone https://github.com/bishnubista/plangate.git
cd plangate
./try-plangate.sh                # Structure + hook output checks
./try-plangate.sh --scaffold     # Create a test project
claude plugin validate .         # Marketplace manifest validation
```

## Adding a Skill

1. Create `skills/{name}/SKILL.md` with frontmatter (`name`, `description`)
2. Set `disable-model-invocation: true` on side-effect skills (creates branches/commits/PRs)
3. Update `hooks/session-start.sh` manifest
4. Update README skills table
5. Run `./try-plangate.sh`

## Pull Requests

1. Fork, branch, make changes
2. `./try-plangate.sh` must pass
3. Test the skill in a real Claude Code session
4. Open PR with a clear description

# Contributing

plangate is a Claude Code plugin — Markdown skills, Markdown commands, and a Bash hook. No build step, no dependencies.

## Structure

```text
.claude-plugin/plugin.json       # Plugin metadata
agents/*.md                      # Specialized agent definitions
commands/*.md                    # Slash command wrappers (/plangate:*)
skills/*/SKILL.md                # Skill definitions (workflow logic)
hooks/session-start.sh           # Stack detection hook
try-plangate.sh                  # Plugin verification script
```

## Setup

```bash
git clone https://github.com/bishnubista/plangate.git
cd plangate
./try-plangate.sh                # 55 structure checks
./try-plangate.sh --scaffold     # Create a test project
```

## Adding a Skill

1. Create `skills/{name}/SKILL.md` with frontmatter (`name`, `description`)
2. Create `commands/{name}.md` as a thin wrapper
3. Set `disable-model-invocation: true` on side-effect skills (creates branches/commits/PRs)
4. Update `hooks/session-start.sh` manifest
5. Update README skills table
6. Run `./try-plangate.sh`

## Pull Requests

1. Fork, branch, make changes
2. `./try-plangate.sh` must pass
3. Test the skill in a real Claude Code session
4. Open PR with a clear description

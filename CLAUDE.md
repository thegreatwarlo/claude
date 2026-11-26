# CLAUDE.md (this repo)

This repo is a Claude Code plugin marketplace with one plugin, `workbench`, at the root:
`.claude-plugin/`, `agents/`, `skills/`, `hooks/`, plus copy-only `templates/`.

- **Stay project-neutral.** No company, product, machine, customer or person names. A rule
  that only makes sense for one project goes in that project's `CLAUDE.md`. Run
  `scripts/check-neutral.sh` before every push.
- Skills and the agent read project specifics (default branch, worktree dir, test command,
  review risk areas) from the target repo's `CLAUDE.md` and fall back to defaults. Keep
  that contract in sync with `templates/project-CLAUDE.md`.
- Hook scripts must stay bash + jq only, and exit 0 on anything unexpected: a crashing hook
  blocks every session that installs the plugin.
- Before pushing: `claude plugin validate .`, `bash -n hooks/scripts/*.sh`, and bump
  `version` in `.claude-plugin/plugin.json` so installs pick up the change.

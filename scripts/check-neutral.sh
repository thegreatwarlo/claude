#!/usr/bin/env bash
# This repo must stay project-neutral: nothing company-, machine- or person-specific.
# Add a term to NEUTRAL_DENY (one per line, case-insensitive) in .neutral-deny, which is
# gitignored so the deny-list itself doesn't leak what it guards against.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
[[ -f .neutral-deny ]] || { echo "no .neutral-deny file; nothing to check"; exit 0; }
pattern=$(grep -v '^\s*$' .neutral-deny | paste -sd'|')
if git ls-files -z | xargs -0 grep -niE "$pattern" -- 2>/dev/null; then
  echo "FAIL: project-specific terms above. Move them to the project's own repo." >&2
  exit 1
fi
echo "ok: no project-specific terms"

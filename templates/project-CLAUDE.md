# CLAUDE.md

<!--
Skeleton for a project's root CLAUDE.md. The workbench skills and agent read the
sections marked (workbench) to adapt to this repo, so fill those in even if you
delete the rest.
-->

[One paragraph: what this project is, and a link to the architecture doc.]

## Conventions (workbench)

- **Default branch:** `main`
- **Worktrees go in:** `.worktrees/` (gitignored)
- **Install:** `pnpm install`
- **Tests:** `pnpm test`; scoped: `npx vitest run <path>`
- **Commits:** Conventional Commits. [AI attribution trailers allowed / not allowed.]

## Review risk areas (workbench)

The `adversarial-reviewer` reads these closest, and `open-pr` treats a PR touching them as
risky (draft + review):

- [e.g. billing and payouts: `src/billing/`]
- [e.g. outbound messages and templates]
- [e.g. consent, opt-out, personal data]
- [e.g. crons and queue workers]

Legal and consent questions are decided by: [name / role]. Product calls: [name / role].

## Outcome watches (workbench)

[If this repo has its own watch runner or `docs/watches/` convention, say where; otherwise
`outcome-watch` uses its portable defaults.]

## Environment

[Only what would cause a wrong action: which database is prod, which machine runs what,
what never to run locally. Detail goes in docs/.]

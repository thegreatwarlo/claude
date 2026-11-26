# workbench

Project-neutral Claude Code practices, packaged as a plugin: an adversarial PR reviewer,
worktree-per-task and PR hand-off skills, outcome watches for changes that fail silently,
and hooks that keep secrets out of transcripts. Plus templates for the parts a plugin can't
carry (`CLAUDE.md` rules).

Everything here was extracted from day-to-day work with several concurrent Claude sessions
on a shared dev VM; each rule exists because its absence cost something real.

## Install

The repo is private, so you need read access and a working git login for GitHub.

```
/plugin marketplace add thegreatwarlo/claude
/plugin install workbench@thegreatwarlo
```

Update later with `/plugin marketplace update thegreatwarlo`. Hooks need `jq` and `bash`.

If you already have copies of these hooks or the agent in `~/.claude/`, remove them after
installing, or they run twice.

## Two layers

This repo is the **generic layer**: nothing in it names a company, machine or person
(`scripts/check-neutral.sh` enforces that against a local deny-list).

The **project layer** lives in each project's own repo, in its `CLAUDE.md`: default branch,
where worktrees go, test commands, **review risk areas**, who decides legal questions, and
any project-specific watch runner. The skills and agent read those sections and fall back
to sensible defaults. `templates/project-CLAUDE.md` is a skeleton with the sections they
look for. The dependency runs one way: projects configure the kit, never copy its files.

## What's in it

### Agent: `adversarial-reviewer`

Reviews an open PR assuming the author was confident and wrong somewhere. Correctness
first (a guard some other path skips, two writers disagreeing about state, a consent check
missing on a new send path, test fixtures that encode the bug), simplicity second. Works in
its own detached worktree, never comments or pushes, and labels each finding CONFIRMED or
PLAUSIBLE. Ends with two plain paragraphs: how bad, and whether it should block.

*Why:* the costliest bugs (a profile-data leak, a consent leak) sat in PRs under 1k lines
that a normal review passed. Size is a poor signal; risk area is a good one.

### Skill: `start-task`

Fresh worktree from `origin/<default>`, after pruning finished ones by PR state.

*Why:* several sessions sharing one checkout silently clobber each other on a branch
switch, and branching from whatever is checked out drags unrelated commits into the PR.

### Skill: `open-pr`

Checks the diff, commits, pushes, opens the PR. A **risky** PR opens as a **draft**, gets
the adversarial review, has its confirmed bugs fixed test-first, and is marked ready only
after that.

*Why draft:* people merge PRs not knowing a review is still running. GitHub can't merge a
draft, and "ready" becomes the signal that the review is done.

### Skill: `outcome-watch`

For a change with a numeric goal and a silent failure mode: agree the goal and the kill
criterion, capture the baseline **before** the deploy, write the spec into the shipping PR,
schedule a verdict at +7d/+30d. Measures the outcome people acted on, not just the proxy,
against an all-population control.

*Why:* the baseline only exists before the deploy, and what to do with each result is only
known at ship time. Watches written after the fact trailed their changes as extra PRs and
mismeasured; one fired "not working" on a proxy when the whole population had dropped by
the same amount.

### Hooks

| Hook | Event | What it does |
|---|---|---|
| `block-secret-dump.sh` | PreToolUse (Bash, Read) | Refuses commands whose known failure mode is printing a whole credential-bearing object (`pm2 jlist`, bare `env`, `cat .env`, `gcloud secrets versions access`, unformatted `docker inspect`, …) and names the narrow alternative. |
| `secret-tripwire.sh` | PostToolUse | When a tool result carries something shaped like a live key, tells the user and Claude in the same turn and logs an incident line (never the value), so a silent leak becomes a known one. |
| `disk-space-alert.sh` | SessionStart, PostToolUse (Bash) | Silent until the disk is low, then warns with a safe cleanup order. Thresholds via `DISK_ALERT_WARN_GB` / `DISK_ALERT_CRIT_GB`; optional `DISK_ALERT_CLEANER`. |

*Why:* no hook can redact a tool result after it's produced, so refusing the call is the
only real control, and the tripwire is the backstop.

## Templates (copy, don't install)

| File | Goes to | Holds |
|---|---|---|
| `templates/CLAUDE.user.md` | `~/.claude/CLAUDE.md` | Worktrees, TDD, fixes as PRs, the risky-PR rule, verify-before-claiming, no flags by default, the papercuts log |
| `templates/project-CLAUDE.md` | a project's `CLAUDE.md` | The sections the kit reads |
| `templates/project-rules/instruction-tiers.md` | `.claude/rules/` | Which tier an instruction belongs in, and why it decides what survives a compaction |
| `templates/project-rules/simulations.md` | `.claude/rules/` | The bar a persona simulation meets before its numbers inform a decision |
| `templates/papercuts.md` | `~/papercuts.md` | The machine-wide log of tooling time-sinks |

## Contributing

Keep it neutral: run `scripts/check-neutral.sh` before pushing. A fix that only makes sense
for one project belongs in that project's `CLAUDE.md`, not here. Validate with
`claude plugin validate .`.

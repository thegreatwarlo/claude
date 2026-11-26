---
name: open-pr
description: Use when a task is FINISHED and its tests pass. Sanity-checks the diff, commits, pushes the branch, opens a GitHub PR with a structured body, and for a risky PR opens it as a draft and launches the adversarial-reviewer agent before marking it ready. Invoke when the user says they're done, want to open/submit a PR, or "ship this". Never merges, never deploys.
---

# Open a pull request

Turn finished work into a clean PR, handling all the git and GitHub. This skill **stops at
the PR**: merging and deploying each need the user's explicit go-ahead, every time.

## 1. Preconditions

- On a feature branch, not the default branch. If on the default branch, stop and run
  `/start-task` first.
- The tests pass. Run the repo's test command (its `CLAUDE.md` says which, and how to scope
  it). **Never open a PR with failing tests**, and never wave one off as "pre-existing":
  find the cause, or explain why it cannot be fixed now and get the user's confirmation.
- `git fetch origin <default>` and `git log --oneline origin/<default>..HEAD` shows only
  this task's commits.

## 2. Read the diff before anyone else does

`git diff origin/<default>...HEAD` plus `git status --short`. Check, and tell the user in
plain bullets:
- **Coherence**: does it do what was asked, and nothing unrelated?
- **Secrets**: keys, tokens, `.env` contents.
- **Leftovers**: debug prints, commented-out blocks, TODO/WIP markers, scratch files,
  editor backups, large binaries.
Ask before continuing if anything looks wrong.

## 3. Commit and push

Stage the intended files only (not a blind `git add -A`). Follow the repo's commit
convention (Conventional Commits unless its `CLAUDE.md` says otherwise, including whether
AI attribution trailers are allowed). `git push -u origin <branch>`. Never push to the
default branch; never force-push a shared branch.

## 4. Is it risky?

A PR is **risky** when it changes production code (tests, docs, simulations, evals and
generated files don't count) and either adds 300+ such lines or touches a risk area. Use
the repo's **review risk areas** if its `CLAUDE.md` names them; otherwise: money, consent
and opt-out, outbound messages and templates, crons and queue workers, personal data,
access and eligibility gates, admin actions that write production data.

Size alone is a poor signal: the worst bugs tend to sit in small PRs that touch one of
those areas.

## 5. Open it

```
gh pr create --base <default> [--draft]
```

Body:

```
## Summary
<1–2 sentences: what changes for whom, and why>

## Changes
- <bullet per meaningful change>

## How to verify
- <steps a reviewer can follow>
```

**Risky PR**: open with `--draft`, and make the body's first line say it stays a draft until
the adversarial review lands. A draft cannot be merged, which is the point: people do merge
PRs without knowing a review is still running.

## 6. Adversarial review (risky PRs only)

Launch the `adversarial-reviewer` agent **in the background, without isolation**, briefed
with the PR number, the branch, one paragraph of intent, and any worry the user named. Do
not hand it your own conclusions.

When it reports:
- Fix its **CONFIRMED** correctness bugs on the branch, test first, and push.
- Bring **PLAUSIBLE** findings, simplifications, and product or legal calls to the user in
  two plain paragraphs next to the PR link.
- **Only then** `gh pr ready`. "Ready" is the signal that the review is done; never before.

If a review already ran on the current head, skip it and open the PR as ready.

## 7. Hand off

Print the PR URL and say plainly what happens next: review, then merge and deploy only on
an explicit go-ahead.

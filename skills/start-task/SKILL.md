---
name: start-task
description: Use at the very START of any code change, before editing anything. Sets up a clean, isolated git worktree off the latest origin default branch so work never builds on a dirty tree, a stale branch, or a checkout another session is using. Invoke when the user wants to start work, add a feature, fix a bug, change copy, or asks "how do I start".
---

# Start a task (clean worktree off the latest default branch)

Get into a **fresh, isolated copy of the latest code** before changing anything, so the
common git mistakes are impossible by construction: editing a dirty tree, building on a
stale branch, or switching branches in a checkout that another Claude session (or a deploy
script) is using at the same time. A branch switch in a shared checkout silently clobbers
the other session's work.

The user may not be technical. Do all the git yourself and keep what you say short and
plain.

## 0. Read the repo's conventions

From the repo's `CLAUDE.md` (and `.claude/rules/`), take:
- **default branch**: otherwise `git remote show origin | sed -n 's/.*HEAD branch: //p'`;
- **worktree directory**: otherwise `.worktrees/` at the repo root (make sure it is
  gitignored; add it to `.gitignore` in your first commit if not);
- **install command** for dependencies.

If Claude Code's `EnterWorktree` tool is available and the repo's `CLAUDE.md` asks for it,
use it instead of steps 4–5, branching from `origin/<default>`.

## 1. Figure out where we are

- `git rev-parse --show-toplevel` for the root, and check the current path. If you are
  **already inside a task worktree**, say which branch it is and stop. Do not nest worktrees.
- `git worktree list`: a worktree for this exact task may already exist. Reuse it.
- Run the remaining git commands from the main checkout.

## 2. Clean up finished worktrees (disk hygiene)

Each worktree is a full copy; prune before creating a new one.
- `git worktree prune`, then for each worktree under the worktree directory check whether
  its PR is done: `gh pr view <branch> --json state --jq .state` → `MERGED` or `CLOSED`.
  **Prefer PR state**: a squash-merged branch is not an ancestor of the default branch, so
  `git merge-base --is-ancestor` misses it. Use that only when `gh` is unavailable.
- Remove finished ones with `git worktree remove <dir>` and `git branch -d <branch>`.
  **Never** `--force` a worktree with uncommitted, untracked or unpushed work without asking;
  it may belong to another session.

## 3. Name the branch

Use the skill arguments as the task, or ask in one sentence. Derive `feat/<kebab>`,
`fix/`, `chore/` or `docs/` (2–4 word slug), unless the repo's `CLAUDE.md` sets another
convention. Show the name and let the user correct it.

## 4. Fetch

`git fetch origin <default>`

## 5. Create the worktree off origin, never off what is checked out

- Folder name: the branch with `/` replaced by `-`.
- Handle collisions first: if the folder or branch already exists, reuse it or add a
  numeric suffix. Do not surface a raw git error.
- `git worktree add -b <branch> <worktree-dir>/<folder> origin/<default>`
- Install dependencies there.

## 6. Move in and hand off

- `cd` into the worktree for shell commands, **and use the worktree's absolute path for
  every file operation** for the rest of the task. Read/Edit/Write take absolute paths and
  ignore `cd`; editing via the main-checkout path out of habit silently loses the isolation.
- Tell the user which branch they are on and that they can describe the change now, then
  use `/open-pr` when done.

## Before pushing, later

`git log --oneline origin/<default>..HEAD` must show only this task's commits. Anything
else means the branch was cut from the wrong base: rebase onto `origin/<default>` first.

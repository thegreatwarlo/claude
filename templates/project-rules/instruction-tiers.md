# Where an instruction belongs

<!-- Drop into a project's .claude/rules/ (no `paths:` frontmatter, so it loads at launch). -->

Before adding anything to `CLAUDE.md`, pick the tier by what happens after a context
compaction, which is the usual reason a long session forgets what it knew:

| Tier | Loads | After a compaction |
|---|---|---|
| Root `CLAUDE.md`, `.claude/rules/*.md` without `paths:` | at launch | re-read, still there |
| Nested `CLAUDE.md`, a rule with `paths:` | when a file it covers is read | gone until such a file is read again |
| `docs/*.md` | only when a link is followed | gone |

- Would a session take a **wrong action** without it, in **any** task? Launch-loaded. It
  costs every session, so keep it short (a test that caps the launch-loaded size works well).
- Wrong action only while touching one subsystem? A nested `CLAUDE.md` next to that code, or
  a rule with `paths:`. Losing it at compaction is fine: working there again reloads it.
- Merely informs, or is reasoning, history or a measurement? `docs/`, linked from the tier
  above.
- Never use `@path` imports in `CLAUDE.md`: they expand at launch and undo the split.
- `CLAUDE.md` is instructions, not reference.

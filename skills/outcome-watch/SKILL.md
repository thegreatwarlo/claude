---
name: outcome-watch
description: Set up a post-rollout check for a change whose failure mode is silent. Captures the baseline while it still exists, writes the spec into the PR that ships the change, and schedules an unattended verdict for a few days or weeks after the deploy. Use while building such a change, before its PR opens. If the repo has its own rollout-watch skill or runner, use that instead.
---

# Outcome watch

Some changes can fail without anyone noticing: a gate, a re-rank, a new step in a flow, a
copy change meant to lift a response rate. Nothing errors; the number just doesn't move, or
moves the wrong way. This skill makes sure someone finds out.

**Two facts drive the whole design:**
1. **The baseline only exists before the deploy.** After it, every "before" number is
   contaminated by the new behaviour. Capture it now or never.
2. **What to measure, and what you'd do with each result, is only known at ship time**, in
   the session that built the change. In four weeks nobody remembers. So it gets written
   down in the shipping PR, not a follow-up PR.

A skill cannot fire three weeks from now when no session is open, so this skill writes the
spec and something else (a cron, a scheduled cloud task) runs it.

If the repo has its own rollout-watch skill, runner or `docs/watches/` convention, use that;
this is the portable version.

## When to offer one

While building, **before the PR opens**. Offer only when both hold:
1. the change has an intended outcome you can state as a number, and
2. its failure mode is silent, so nothing else would surface it.

A typo fix gets none. Never create one unasked, never offer twice for the same change, and
if the user says no, drop it. A yes covers every setup step, scheduling included; don't ask
again.

**Same-day "is the fix working?"** is a different, lighter thing: a session loop (e.g.
`/loop 1h <read-only probe>`) for the rest of the day, not a spec and a scheduled email.

## Step 1: agree what "it worked" means

Ask, don't guess:
- **Context**, two to four plain sentences: what used to happen, what changed, for whom.
  No field names or file paths; the reader in four weeks won't have the diff in their head.
- **Goal**, one sentence: what this should change for a real person.
- **How we'd know**: which numbers move, which direction. Push until a wrong answer is
  possible. "Engagement improves" is not a check; "the share of X carrying Y goes from ~0
  to most of them" is.
- **Kill criterion**: what result means turn it off. **If no result would change the
  decision, say so and stop.** A watch nobody would act on is just a scheduled email.
- **What to do with the result**: the follow-up for each way it lands (worked, didn't,
  too early), plus anything deferred until then. This is ship-time knowledge like the
  baseline; without it the report can only say "wait or revert".
- **When to look**: days for something immediate, weeks for anything needing volume. Two
  checkpoints (+7d, +30d) is the common shape.
- **Flag**: if the change shipped behind a kill switch, this watch is what retires it.

## Step 2: measure past the proxy

A watch on an intermediate step can't tell you whether anything was lost. For each metric:
- also count the **outcome people acted on** (the click, the confirmed match, the paid
  invoice), not only the step before it;
- print the **same rate for the whole population** in both windows as a **control**, so a
  market-wide drop isn't read as the change's fault (or a market-wide lift as its success);
- add a **"what it cost"** line in absolute numbers, not only percentages.

## Step 3: capture the baseline now

Run the probes today and record the numbers with today's date. Where a number genuinely has
no before-value (a brand-new field), **write that down**; never estimate one. An invented
baseline produces a confident comparison that is simply false.

Probes are **read-only, always**: they run unattended against production with nobody
watching.

## Step 4: write the spec, in the shipping PR

`docs/watches/<slug>.md` (or wherever the repo keeps them), with front matter
(`slug`, `deployed: pending`, `checks: [+7d, +30d]`, `flag:` if any) and these sections:
`## Context`, `## Goal`, `## How we'd know`, `## Baseline`, `## Kill criterion`,
`## What to do with the result`, `## Probes` (one runnable block).

Don't make the commit wait for the deploy moment: it doesn't exist yet. Probes that split
before/after read it from the environment with a placeholder fallback
(`${WATCH_SINCE:-<merge day>}`), or better, find the split in the data itself (the first
record only the new code writes).

## Step 5: rehearse once

Run the probes the way the scheduled job will, and read the output. A check that has never
run once is hoped for, not scheduled. Don't send the rehearsal anywhere: at ship time the
verdict is always "too early".

## Step 6: at the deploy, schedule it

Not a PR. Take the real deploy moment and schedule each checkpoint with whatever this
environment has, in order of preference:
1. the repo's own watch runner, if its `CLAUDE.md` names one;
2. a one-shot cron on a machine with read access to the data, whose wrapper **removes its
   own line from an EXIT trap**, so a failed check still cleans up (a cleanup at the end of
   the script never runs when the script dies first, and leaves a line that fires again
   next year);
3. a one-time scheduled cloud task (the `schedule` skill), if the probes need no private
   network or credentials;
4. at minimum, a calendar reminder linking the spec.

A check that can't reach the data should retry, and only report failure if the whole window
passes.

Tell the user in one message: which numbers, which dates, where the verdict will arrive,
and exactly what was scheduled.

## Closing it

The final verdict isn't the end; recording it is. Add `verdict: working | not-working`,
`closed: <date>` and the real `deployed:` date to the spec in a small PR. If a flag is
named, delete it in the same PR: working keeps the behaviour and drops the switch,
not-working reverts it and drops the switch. Remove any leftover scheduled jobs.

If the change is reverted before the check, delete the spec and the scheduled jobs.

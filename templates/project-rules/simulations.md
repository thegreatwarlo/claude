# Simulations that inform a decision

<!-- Drop into a project's .claude/rules/ if the project runs persona or load simulations. -->

A simulation whose numbers feed a product call (simulated users, a matching or marketplace
sim, synthetic load) meets this bar before anyone trusts it:

- The strongest current model writes the people, never a small/cheap model.
- A written spec comes first: population mix with counts, answer styles, languages, timing
  and dropoff guesses, and what is deliberately NOT engineered in (e.g. no forced overlap
  between what people want and what's on offer).
- Personas go through the real product path (the live prompt and tools), never outputs
  written directly.
- Controls: a random baseline and a best-possible upper bound.
- The judge is a different model family from the system under test, and scores the people
  in their own words, not the system's output.
- A subagent reviews the setup adversarially before the numbers are trusted.
- Publish how the personas were made alongside the results.
- State the expected API spend before running a large one.

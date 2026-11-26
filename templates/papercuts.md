# Papercuts

<!--
Machine-wide, append-only log of tooling that cost a Claude session time. Put it at
~/papercuts.md. Shared by every session in every repo on this machine.
Format: - date · symptom · fix · where
Append with >>, never rewrite: other sessions append concurrently.
-->

- 2026-01-01 · example: `gh repo clone` says "Repository not found" for a private repo you can see · the SSH key belongs to a different GitHub account than `gh auth`; clone over HTTPS with `git -c credential.helper='!gh auth git-credential' clone https://...` · any machine with two GitHub identities

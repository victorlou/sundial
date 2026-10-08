# Sundial

A mobile app for one household's routines and chores, with a Supabase + PowerSync backend. The plan is in `docs/`. Development starts at P0.

## Start here

- Read [docs/README.md](docs/README.md) first. It says which doc to read for each kind of task, and its conventions apply to all work in this repo. Read only the docs your task needs.
- The scope of any task is the current phase in [docs/05-roadmap.md](docs/05-roadmap.md). Don't build ahead of it.

## Rules the docs index doesn't cover

- If the docs are wrong, are missing something, or contradict each other, stop and ask. Don't work around it in code.
- When a change makes something in a current-truth file (`docs/01`, `03`, `04`, `05`, `06`) untrue, update that file in the same change.
- When a new ADR changes an accepted one, the accepted ADR gets only a status line that points to the new ADR.
- IDs (FR, NFR, DM, HH, AM, L, E, C, spikes, ADR numbers) are never renumbered or reused. New ones go at the end of their sequence.
- Examples and seed data use Alice, Bob, Carol, and Dave. No real people's names in committed files.
- `.local/` holds local working files and is git-ignored. Never cite it from committed files.

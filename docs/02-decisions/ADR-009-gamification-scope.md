# ADR-009 — Gamification scope

**Status:** Accepted (2026-09-25).

## Context
- F1: celebrations early, points and rewards later.
- It's cooperative, and adults take part.

## Options

| | A. Celebrations only | **B. A + points ledger + household rewards + cooperative goals** | C. B + a persistent game layer (pets, avatars, levels) |
|---|---|---|---|
| Data impact | None | An append-only `PointEntry` ledger, `Reward` definitions, and redemption events | Game state per member, plus art and asset pipelines |
| Effort | Small | Medium | Large, and mostly content and art work |
| Risk | — | Balances conflicting across devices. Avoided by the ledger (ADR-007). | Scope creep |

## Decision
- **A in P4**, because board mode needs the "list complete!" moment.
- **B in P5.**
- **C isn't planned.** Revisit it after the family has used B for a while.

## Consequences
- Nothing in P1–P3 needs to change except that events always carry `actorMemberId`, which ADR-003 already requires.
- A task's point value is a field on the task definition. It's added in P5 with a default of 0.
- There are no leaderboards, per F1.

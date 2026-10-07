# ADR-007 — Completion records and conflict resolution

**Status:** Accepted (2026-09-25).

## Context
- Every device works offline, so two devices can tick the same thing, one can undo while another ticks, and so on.
- We need history for streaks and averages (E1), and a points ledger later (F1).
- Sync conflicts are resolved in our upload handler and in Postgres (ADR-001 B).

## Options

| | A. Mutable state, last writer wins | **B. Append-only events + last writer wins for definitions** | C. Full event sourcing / CRDTs |
|---|---|---|---|
| Idea | The task holds `lastDoneAt` and `doneToday`, and the last write wins | Completions, skips, snoozes, and point entries are **immutable event rows**. Task and member *definitions* are ordinary rows where the last write wins, field by field. | Every change is an event, and state is rebuilt by replaying them |
| Two devices tick the same occurrence | One write is silently lost | Both events exist. The occurrence is done, and it's clear who did it. | ✅ |
| Undo | Overwrite the state. History is lost. | Set `revokedAt` on the event (a soft revoke, which syncs cleanly) | A compensating event |
| History and stats | ❌ | ✅ | ✅ |
| Complexity | Lowest | Moderate | High |

## Decision: **B**

## Consequences
- Every event has an **occurrence key**: `(taskId, memberId?, logicalDate, slotId)`. The engine groups events by this key, so duplicates are harmless.
- **"Up for grabs":** the first completion that the server accepts (by server receipt time) takes the credit. Later ones are kept as "also done by". Whether this is decided on the server or the client is settled in the domain model.
- Events are never hard-deleted. This matches the rule against permanently deleting data.
- The points ledger (P5) follows the same pattern, so a balance is always the sum of its entries and never a counter that devices overwrite.

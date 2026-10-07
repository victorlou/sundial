# ADR-005 — Recurrence engine

**Status:** Accepted (2026-09-25).

## Context
- We need fixed and floating schedules; weekday, monthly, and one-off patterns; per-task miss policies; several slots per day; and skip and snooze (D1–D4, R5).
- Schedule changes must not rewrite history (FR-18).
- This engine is the heart of the app and must be exhaustively testable (NFR-05).

## Options

| | A. Materialize occurrences | **B. Compute on read** | C. Hybrid |
|---|---|---|---|
| Idea | Generate occurrence rows ahead of time, like a calendar | A pure function takes the schedule, the event history, and the logical day, and returns the occurrences. Only **facts** are stored: completions, skips, snoozes. | B, plus a cached `nextDue` per task for sorting and widgets |
| Floating schedules | ❌ Can't generate ahead. The next date depends on when it's done. | ✅ | ✅ |
| Editing a schedule | Regenerate rows and resolve conflicts with ticks already made | Nothing to regenerate. Changes apply from their effective date. | Same as B, plus invalidating the cache |
| Sync traffic | High: generated rows sync too | Only events | Events, plus cache churn if the cache is synced |
| Testability | Stateful | **Pure function with table-driven tests** | Pure core |

## Decision: **B**. Add C's cache later only if measurements show it's needed. At our data sizes they won't.

## Consequences
- The engine is a **dependency-free Swift package**. Its inputs are the schedule, the events, `today: LogicalDate`, and member settings. It never reads the clock or the time zone (see ADR-006).
- A schedule is made of these parts. Exact types are in `03-domain-model.md`.

| Part | Values |
|---|---|
| Anchor | `fixed` or `floating` |
| Pattern | `once`, `everyNDays`, `everyNWeeks`, `weekdays`, `monthlyDay`, `monthlyNthWeekday` (`yearly` later) |
| Slots | One or more |
| Miss policy | `vanish`, `markMissed`, or `carryOver` |
| Active window | Optional, later |

- **"Strict habit" and "postponable" aren't types.** They're presets:
  - A strict habit is a fixed anchor with `markMissed`.
  - A postponable is a floating anchor with `carryOver`.

  Miss policies are per task (D1), so presets are the honest model.
- **Schedule versioning:** an edit creates a new version that takes effect on a date. Past days are evaluated against the version that applied then. The exact rules are in `03-domain-model.md`.

# ADR-006 — Day boundary and time zones

**Status:** Accepted (2026-09-25).

## Context

- Each member has their own day-start hour (default 05:00). "Today" follows wherever the device is, using the simplest workable approach (D5).
- Household members may be in different time zones at the same time.

## Options


|                      | **A. Logical day on the device, stored on each event**                                                                                            | B. A fixed home time zone per member                       | C. Store instants only, derive days when reading                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- | --------------------------------------------------------------- |
| Rule                 | `logicalDate = civilDate(now − dayStart)` in the device's **current** time zone. Each event stores `logicalDate`, `occurredAt` (UTC), and `tzId`. | The same calculation, but always in the member's home zone | The day is recomputed from the UTC instant whenever it's needed |
| While travelling     | "Today" matches the local wall clock ✅                                                                                                            | The Evening slot might start at noon ❌                     | ✅                                                               |
| History stays stable | ✅ The day is frozen when the event is recorded                                                                                                    | ✅                                                          | ❌ Changing time zone moves past completions to different days   |
| Complexity           | Low                                                                                                                                               | Low                                                        | Hidden and bug-prone                                            |




## Decision: **A**

It's the simplest option that keeps history stable.

## Consequences

- **The recurrence engine only ever works with civil dates** (`2026-09-23`), never instants or time zones. Only the app shell converts the current time into a logical date. This one line of code removes most time-zone bugs.
- Flying east can give a short logical day, and flying west a long one. We accept that. An occurrence can't be completed twice, because events are keyed by occurrence (see ADR-007).
- Household tasks and members in different time zones: each completion carries **the completer's** logical date. Whether the board shows "done today" uses the viewer's logical date. Worked examples come in the domain model.


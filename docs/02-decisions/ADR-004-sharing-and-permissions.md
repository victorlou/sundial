# ADR-004 — Sharing scope and permissions

**Status:** Accepted (2026-09-25). Partly superseded by [ADR-010](ADR-010-household-membership-lifecycle.md): capabilities now live on Membership. Partly superseded by [ADR-013](ADR-013-board-review-amendments.md): sync rules are now Sync Streams (AM-02), and moving a task to the household is an online-only server function (AM-11).

## Context
- Tasks are private by default and shared with the household by opt-in, with one merged Today view (C1).
- One household per person, for now (C4).
- The server enforces capabilities (R4, C2).

## Options

| | **A. Two scopes: personal + household** | B. Per-list sharing (like Reminders) | C. Household only |
|---|---|---|---|
| Model | Each task has a `scope`: either `personal(ownerMemberId)` or `household(householdId)`. | Lists shared with arbitrary people, each with its own permissions | Everything is visible to every member |
| Private tasks | ✅ | ✅ | ❌ Violates C1 |
| Household board | ✅ Natural | Awkward. Which lists count? | ✅ |
| Permission complexity | Low: two predicates | High: an access graph per list | Lowest |
| Sync rules | One bucket per member's personal data, one per household | One bucket per list, per user | One per household |

## Decision: **A**

It's the smallest model that satisfies C1 and gives the board a clear source of data.

**Starting capabilities** (stored as a set per member, with no adult/kid enum):

| Capability | Allows |
|---|---|
| `manageHouseholdTasks` | Creating, editing, and deleting household tasks |
| `manageMembers` | Inviting and removing members, adding profiles, and granting capabilities |
| `actForOthers` | Recording events for other members. The shared iPad needs this. |
| `manageRewards` | P5 |

The household creator gets every capability. Anyone can always manage their own personal tasks.

## Consequences
- **Enforcement:** RLS policies check scope and capabilities. Rules that span several rows run in Postgres functions called over RPC, e.g. "up for grabs: the first completion wins".
- **Edge case for the domain model:** a *profile-only* member has no devices of their own, so their "personal" scope would be invisible to everyone. Proposal: profile-only members own **household-scoped** tasks only.
- Moving a task between personal and household scope moves it between sync buckets. The sync spike verifies this.

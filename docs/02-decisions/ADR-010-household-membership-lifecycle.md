# ADR-010 — Household membership lifecycle

**Status:** Accepted (2026-09-25). Partly supersedes ADR-003 (Member becomes Profile + Membership) and ADR-004 (capabilities move to Membership). Partly superseded by [ADR-013](ADR-013-board-review-amendments.md): several households per person also couple personal tasks to one household's slots (AM-09), lifecycle functions use the caller's logical date (AM-10), and two more operations are online-only (AM-13).

## Context
- The domain model needs clear answers to these questions: what creates a household, how people join or leave one, and whether we need an owner or admin role.
- Under ADR-003, one `Member` record held both **who someone is** (name, avatar, day start, personal tasks) and **their place in a household** (`householdId`, capabilities). Joining or leaving a household breaks that:
  - Capabilities belong to the household, not the person.
  - The household's history must survive someone leaving.
  - Personal data must follow the person.

## Options

| | A. Keep Member, add `createdBy` and an owner role | **B. Split into Profile + Membership, use capabilities plus invariants** | C. Make the household optional (a solo user has none) |
|---|---|---|---|
| Admin | A fixed owner, which needs a transfer flow | `manageMembers` capability. Several people can hold it, and granting it transfers it. | Same as B |
| Leaving | Moves the member row. The old household loses the name behind its history. | Closes a membership row. History keeps its name. | Same as B |
| Personal data on a move | Rewrite `householdId` on every personal task and event | Nothing to rewrite except remapping slots | Same as B |
| Several households later (C4) | Needs a redesign | Drop one unique index | Same as B |
| Slots for a solo user | Household slots | Household slots | ❌ Would need a second set of slots, per profile |

## Decision: **B**
Together with HH-01 to HH-07:

| # | Decision |
|---|---|
| HH-01 | Split the old `Member` into **Profile** (the identity) and **Membership** (profile × household, which holds the capabilities). |
| HH-02 | Name the identity entity **Profile**. A profile with no account is **unlinked**. "Player" can be a UI label in kid mode. |
| HH-03 | Keep the household of one from first launch (DM-01). **Hide the personal/household choice until the household has 2 or more memberships.** |
| HH-04 | The last linked profile can't leave while unlinked profiles remain: invite someone first, or delete the profiles. Merging households goes on the later list. |
| HH-05 | Lifecycle actions only work **online**. They're Postgres functions that check the rules atomically. This is the one exception to NFR-01. |
| HH-06 | When an account is deleted and it was the profile's only account, the profile is anonymized ("Former member"), and the household's events are kept. |
| HH-07 | Linking another account to a profile only works through **pairing**. The code comes from one of the profile's own accounts, or, for an unlinked profile, from someone with `manageMembers`. Signing in never claims an existing profile. |

**Invariants**, enforced on the server:
1. At most one open membership per profile (a unique index on memberships where `leftAt` is null).
2. A household that has any linked profile always has at least one linked profile holding `manageMembers`.
3. An account links to at most one profile.
4. `Household.createdByProfileId` is kept as a record only. It **never grants permissions**.

## Consequences
- Personal-scope tasks and events drop `householdId`. They're keyed by `ownerProfileId`, which matches the per-profile sync bucket in ADR-004.
- Joining a household creates new rule versions for the joiner's personal tasks, effective today, with slots matched **by name** and falling back to Anytime.
- The full lifecycle and its edge cases are in `03-domain-model.md` §3.

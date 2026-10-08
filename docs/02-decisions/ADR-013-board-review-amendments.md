# ADR-013 — Board review amendments

**Status:** Accepted (2026-10-07). Partly supersedes ADR-001, ADR-002, ADR-003, ADR-004, ADR-007, ADR-008, ADR-010, ADR-011, and ADR-012, as listed below. Amendments from the same review are added here as its remaining items are applied.

## Context
- A board review of the planning docs (2026-10-01) checked every finding against the docs, and every external claim against its source. Those sources are linked next to each fact, here and in the current-truth files.
- Most of its changes are edited straight into the current-truth files (01, 03–06). Some of them change what accepted ADRs say.
- Accepted ADRs are never rewritten, and the [docs index](../README.md) settles disagreements on detail. A change to what an ADR *decided* still needs a record.

## Options

| | **A. One ADR for all of the review's amendments** | B. One new ADR per amended ADR | C. Edit the accepted ADRs |
|---|---|---|---|
| Accepted ADRs stay as accepted | ✅ | ✅ | ❌ |
| Finding a change | One table, one ID per change | Spread across several new ADRs | In place, with no record of what changed or why |
| New files | 1 | One per amended ADR | None |

## Decision: **A**

| # | Amends | Change | Why |
|---|---|---|---|
| AM-01 | ADR-001: Consequences ("Before Phase 2 there's a sync spike") and sub-decision 1b ("if the Phase 2 spike fails") | The sync spike (S2) runs in **P0**, next to S1, against the local Docker stack, so it's done before P1 starts. Its fallback is no longer option A (CloudKit). It's a tool that meets R4, such as another Postgres-based sync tool, and the spike's write-up names the candidates. | P1's data layer shouldn't be built on a sync path nobody has exercised. The spike is throwaway and needs no P1 code. By ADR-001's own table, CloudKit fails R4 and shares only with iCloud users. |
| AM-02 | ADR-001 (option B: "*Sync rules* decide what each user downloads"), and every other mention of "sync rules" in ADR-001, ADR-002, ADR-004, ADR-008, and ADR-011 | Downloads are defined with PowerSync **Sync Streams**, not Sync Rules. Read "sync rules" as "sync streams" in those ADRs. | Sync Rules [don't support joins](https://docs.powersync.com/sync/rules/many-to-many-join-tables) and are [deprecated](https://docs.powersync.com/sync/rules/overview) in favor of Sync Streams, which support joins, CTEs, and subqueries. The bucket parameter chain (account → profile → open membership → household) needs them. |
| AM-03 | ADR-003: Consequences ("Device pairing and anonymous auth are P4+ spikes") | Pairing a kid's own device (FR-53), anonymous auth, and spike S5 are **Later**, outside the implementation plan. HH-07 still holds: until pairing ships, a second account can't be linked to an existing profile, so a teen who gets their own Apple Account joins as a new profile. | The owner decided that compliance for children's data comes first. [TestFlight doesn't allow users under 13](https://www.apple.com/legal/internet-services/itunes/testflight/), so pairing will need App Store distribution when it comes back. |
| AM-04 | ADR-011: Consequences ("RLS and PowerSync sync rules exclude deleted rows") | RLS read policies **don't** filter `deletedAt`. Sync streams and repositories exclude deleted rows, so they still disappear from devices at once. If a policy ever has to filter it, soft deletes for that table go through a SECURITY DEFINER function. | A PostgREST update reads its updated row back through the SELECT policies ([Postgres](https://www.postgresql.org/docs/current/sql-createpolicy.html), [Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security)), so an RLS filter on `deletedAt` would reject every soft delete with `42501`. |
| AM-05 | ADR-011: Decision ("30 days, disclosed in the UI") and Consequences ("it isn't built before P3") | The account-deletion part of the purge job is built in **P2**; the rest of it stays in P3. Retention is still 30 days, but the app tells the user deletion takes **up to 60 days, including backups**. | FR-33 is a P2 requirement and the P2 exit says account deletion works end to end, so its purge can't wait for P3. Backups expire up to 30 days after the purge, so 60 days is the accurate figure. |
| AM-06 | ADR-012: Consequences ("A scheduled Xcode Cloud build keeps the Prod build fresh") | A scheduled **GitHub Action** keeps the Prod build fresh. It starts the Xcode Cloud Prod workflow on the latest Prod tag through the App Store Connect API. | Xcode Cloud's [schedules can only build a branch](https://developer.apple.com/documentation/xcode/configuring-start-conditions), not the latest tag. |
| AM-07 | ADR-007: option B ("definitions are ordinary rows where the last write wins, field by field") | When two devices create the same row (a deterministic rule-version ID), the **whole row** from whichever device uploads last wins, because the connector uploads a `PUT` as a full-row upsert with explicit nulls. Later updates still merge field by field. | PowerSync's `PUT` [carries only the non-null columns](https://docs.powersync.com/handling-writes/handling-update-conflicts), so without explicit nulls a create would mix fields from both devices. |
| AM-08 | ADR-001: Consequences ("The server never generates IDs") | Server functions and triggers generate UUIDs for the rows they create, such as a fresh household of one when someone is removed, or a P5 `PointEntry`. Every row the client writes still gets a client-generated UUID. | A remove creates a household on the server, and P5's ledger is written by a trigger. Neither has a client to generate the ID. |
| AM-09 | ADR-010: Options ("Several households later … Drop one unique index") | Several households per person also means deciding which household's slots a personal task uses, because its rule versions point at one household's slots. | Dropping the index alone would leave personal tasks pointing at slots in only one of the households. |
| AM-10 | ADR-010: Consequences (joining creates rule versions "effective today") | The versions are effective the **caller's `logicalDate`**. Every lifecycle RPC takes it. | Only the device knows the logical date (ADR-006); a server function can't work out "today". |
| AM-11 | ADR-004: Consequences ("Moving a task between personal and household scope moves it between sync buckets. The sync spike verifies this.") | Moving a task is *Change task scope*, an online-only server function, and only personal → household for now; household → personal is Later. In one transaction it rewrites the scope columns of the task, its rule versions, and its actions, and writes a new rule version with a household assignment. Copy + delete (DM-17) is only the fallback, if spike S2 shows rows don't move between buckets cleanly. | Actions copy the task's scope, so without the rewrite a moved task's history would stay in the owner's personal bucket and fail the household RLS checks. Converting tasks is the first thing a family does after someone joins. The direction and who may call it were settled by the owner on 2026-10-08. |
| AM-12 | ADR-007: option B ("immutable event rows") | *Change task scope* may rewrite an action's scope columns: a named exception to immutability, like `deletedAt`. | Needed for AM-11. |
| AM-13 | ADR-010: HH-05 ("This is the one exception to NFR-01") | Two more operations are online-only server functions: changing a task's scope, and redeeming points (P5). | The scope change rewrites rows across buckets in one transaction, and an offline redemption could overdraw a balance. |
| AM-14 | ADR-011: Context ("a household whose last linked profile leaves") | A household is deleted only when its last linked profile deletes their account. Leaving is blocked while unlinked profiles remain (HH-04, unchanged). | HH-04 and this context line contradicted each other. The owner chose blocking, because it's the rule that can't silently delete children's history. Account deletion is the one exit that can't be blocked. |
| AM-15 | ADR-011: Decision ("deleted unlinked profiles", 180 days, then purged; "its name is overwritten at purge") | At purge, a deleted unlinked profile is **anonymized**, not hard-deleted, the same as a deleted account's profile: its name and avatar are overwritten. The name-and-avatar snapshots on its closed memberships are treated the same way. The exception is a household deleted along with its last linked profile's account: it follows the account's 30 days instead of 180, and at purge it's hard-deleted as a whole, its unlinked profiles included, because nothing points at them any more. | Household actions still point at the profile, so hard-deleting it would break them or take other people's history with it. The snapshots would otherwise keep a deleted person's name. The owner decided this on 2026-10-08. |
| AM-16 | ADR-011: Decision ("Archived tasks, revoked actions: Not deletions. Kept as history.") | Kept indefinitely **in family use** only. The purge job has a time-based retention hook, which the children's privacy ADR (NFR-10) sets before any public release. | The [amended COPPA Rule](https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect) requires a written retention policy with a set time period, not indefinite retention. The owner decided that a public version keeps under-13 profiles and takes on that work (NFR-10). |

## Consequences
- The status line of each amended ADR points here.
- The current-truth files already reflect each amendment:
  - AM-01: [05-roadmap](../05-roadmap.md) (spikes, P0).
  - AM-02: [04-architecture](../04-architecture.md) §2 and §5.1, and [06](../06-environments-and-release.md) §4–§5.
  - AM-03: [03-domain-model](../03-domain-model.md) §2.2 and §3, 04 §1 and §5.3, 05 (P4, Later), and 06 §8.
  - AM-04: 04 §5.2 and §6.
  - AM-05: [01-requirements](../01-requirements.md) FR-33, 03 §2.10 and §3.1, 04 §1 and §6, and 05 (P2, P3).
  - AM-06: 06 §4.
  - AM-07: 03 §8 (C5) and 04 §4.2.
  - AM-08: 03 §2.9 and §3.1, 04 §4.3 and §6.
  - AM-09: 05 (Later).
  - AM-10: 03 §2.7 and §3.1, 04 §4.3.
  - AM-11 and AM-12: 03 §2.6–§2.8 and §3.1, 04 §5.1 and §5.2, 05 (P3, Later).
  - AM-13: 01 NFR-01, 03 §2.9 and §3.1, 05 (P5).
  - AM-14: 01 FR-41d, 03 §3.1 (*Delete household*) and L7.
  - AM-15: 03 §2.3, §2.10, §3.1, and L16.
  - AM-16: 03 §2.10, 05 (P3).
- Later amendments from the same review take the next AM number. Existing rows aren't rewritten.

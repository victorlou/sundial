# ADR-014 — P0 spike outcomes (S1, S2)

**Status:** Proposed. S1 was decided on 2026-10-15; S2 is pending. The S2 session adds its outcome and the fallback candidates, then accepts this ADR.

## Context

- P0's exit needs spikes S1 and S2 decided, with their outcomes in a new ADR ([05](../05-roadmap.md#p0--foundations-s)). A failed spike would change ADR-001's decision, and accepted ADRs aren't rewritten.
- S1 checks ADR-001 sub-decision 1b (i): the PowerSync Swift SDK in local-only mode as P1's store, with sync starting at `connect()`. Its pass criteria and open question are in [05's spike table](../05-roadmap.md#riskiest-unknowns-spike-first).
- **How S1 ran:**
  - On 2026-10-15, against the local stack ([06 §3](../06-environments-and-release.md#3-local-stack)), on two iOS 27 simulators.
  - Versions: PowerSync Swift 1.16.4, supabase-swift 2.55.4, and the PowerSync service 1.26.1.
  - A throwaway app with the five tables the criteria name.
  - Server side: the RLS from [architecture §5.2](../04-architecture.md#52-permissions-rls), a claim-or-create function, and the P2 parts of the §5.1 streams.
  - Sign-in used an email and password account on the local Supabase Auth, standing in for Sign in with Apple (spike S3). Everything after sign-in is the same either way: the session, the JWT, claim-or-create, and `connect()`.
  - The code and the full results log are on the branch `spike/s1-powersync-local-only`, which is never merged.

## S1 results

| Pass criterion | Result |
|---|---|
| A small app with 2 tables survives a schema change and an app relaunch | ✅ Every row ID survived a relaunch, and a v2 build installed over v1 that added a column and an index and dropped a column. SwiftUI lists fed by `watch()` updated on every write, and again after each relaunch. |
| Are writes made before sign-in uploaded after `connect()`? | ✅ **Yes.** Every write to a synced table is queued, connected or not. All 12 of a P1 device's queued entries were handled at its first `connect()`. The SDK's own documentation says the same. So nothing has to be copied from local-only tables. |
| A P1 device with a profile, household, membership, slots, and tasks signs in and uploads cleanly under the planned RLS | ✅ Claim-or-create returned `created`. The profile, slots, and tasks uploaded with no `42501` and no rejected writes, and the server held exactly the device's IDs. The device kept every row after its first checkpoint. |
| A second device's pre-sign-in rows don't upload (domain model C8) | ✅ With the same account, claim-or-create returned `claimed`. After Discard, and again after Import, none of the device's 10 pre-sign-in IDs reached the server. Import's copies, with new IDs, uploaded and reached the first device. |
| **Open:** local-only `households` and `memberships`, or the connector clears their queued entries? | **The connector clears them** (X, below). |

What else S1 found:

1. **A device ends up with exactly the server's checkpoint.** Once its uploads are done, a row that no stream covers is removed from the device, even when its upload was rejected. In a control run, the second device connected without clearing:
   - RLS rejected all 8 of its uploadable rows with `42501`, and the skip rule took the other 2.
   - Its own 10 rows then disappeared from the device. Only `rejected_writes` kept their data.
2. **A schema change needs no client migration.** The client schema is a set of views over JSON rows, rebuilt when the app opens the database.
   - A new column reads null on existing rows.
   - A dropped column leaves the view, but its values stay in the stored JSON.
   - Indexes are built over the JSON.
   - Queued entries keep the shape they were written in. v1 entries still carrying the dropped column uploaded after v2 shipped, which is the case the rewrite step in [06 §5](../06-environments-and-release.md#5-backward-compatibility-rules) covers.
3. **`updateSchema` doesn't re-run live watches.** A watch opened before the switch kept reading the old view and missed a row written after switching back (prototype Y).
4. **PowerSync accepts the local stack's JWT.** It's signed with ES256 and verified through the JWKS in `backend/powersync/service.yaml`.

## Options for the open question (architecture §5.3)

| | **X. Synced tables; the connector skips their entries** | Y. Local-only tables until sign-in |
|---|---|---|
| How | P1 writes `households` and `memberships` like any other table. The connector completes any `memberships` operation, and a `households` `PUT`, without uploading it. Those rows reach the server only through claim-or-create. | P1 keeps them in local-only tables behind the same view names. At sign-in, `updateSchema` swaps the views to synced tables, which fill from the download. |
| Second device (C8) | Clear the queue before `connect()` | **The same:** profiles, slots, and tasks are queued under Y too |
| Schemas | One | Two, swapped at every sign-in and sign-out, only while disconnected |
| UI around sign-in | No gap | The household view is empty from the swap until the first download, and live watches must be restarted |
| Leftovers | None | Pre-sign-in copies stay in local tables until deleted |
| If the rule is wrong | RLS rejects direct membership writes (`42501`, no write policy) | — |
| Prototyped | Yes, in every S1 run | Yes, sign-in and sign-out once |

## Decision: S1 passes; ADR-001 1b (i) stands, with **X**

- P1 stores everything in synced PowerSync tables, apart from local-only tables like `rejected_writes`. Calling `connect()` uploads whatever P1 queued.
- The connector never uploads a `memberships` operation or a `households` `PUT`. A household rename (`PATCH`) uploads as usual.
- **Import or Discard runs before `connect()`:**
  1. Import reads the rows it will copy.
  2. `disconnectAndClear()` wipes the device's rows and its queue.
  3. Import writes the copies with new IDs.
  4. Only then does the device connect.
- Y removes two entries from the queue but not the clear. It adds schema swaps, a gap in the UI, and stale watches.

## S2 results

*Added by the S2 session.*

## Consequences

- [Architecture §5.3](../04-architecture.md#53-identity-flow) and §6, and [domain model §3.1](../03-domain-model.md#31-operations) (*Import or Discard*), say what's decided here.
- P2's streams must cover every synced table before any device connects. Otherwise rows vanish from devices after their first upload (finding 1).
- On a `claimed` result, the app must not call `connect()` until the user has chosen Import or Discard, or the device's own rows are lost (finding 1).
- The queue holds every P1 write until the first sign-in, which then uploads them one operation at a time. That took about 5 ms per operation against the local stack, and it hasn't been measured against a remote backend. P2's connector may batch them.
- The PowerSync GRDB integration and sub-decision 1b (ii) aren't needed.

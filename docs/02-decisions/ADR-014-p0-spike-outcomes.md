# ADR-014 — P0 spike outcomes (S1, S2)

**Status:** Accepted (2026-10-19). S1 was decided on 2026-10-15, and S2 on 2026-10-19.

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
- S2 checks ADR-001's decision B end to end, and AM-01 asks its write-up to name the fallback candidates ([ADR-013](ADR-013-board-review-amendments.md)). Its pass criteria and open questions are in the same table.
- **How S2 ran:**
  - On 2026-10-19, against the same local stack and versions as S1, on three iOS 27 simulators: Bob on an iPhone and an iPad, and Alice on an iPhone.
  - A headless script played a third household, Carol's. It signed in, wrote through PostgREST under RLS, and read the account's whole download from the PowerSync service.
  - S1's app, schema, and sign-in, plus `rule_versions` and `occurrence_actions` with their §5.2 RLS, and every stream in [architecture §5.1](../04-architecture.md#51-buckets-what-each-device-downloads), P3 parts included.
  - Join, Leave, and Change task scope ran as minimal SQL stand-ins for the P3 lifecycle functions. Each makes the same row changes, without invites, checks, or remap versions.
  - "Offline" meant the app called `disconnect()` and kept writing, which queues writes the same way a lost network does.
  - After every step, a check compared each device and each account's download with §5.1 restated in SQL and with the server's rows, and looked for rows shared between households.
  - The code and the full results log are on the branch `spike/s2-end-to-end-sync`, which is never merged.

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

| Pass criterion | Result |
|---|---|
| First sign-in from a device with P1 data (S1's checks) | ✅ As in S1, now with rule versions and an action: the first device's 10 rows uploaded, and the household and membership `PUT`s were skipped. The iPad got `claimed`, then Discard, and held only Bob's server rows. |
| Domain model C5 | ✅ Both of Bob's devices, offline, wrote the same rule-version ID. The device's UUIDv5 matched Postgres's `uuid_generate_v5`. **On create**, each device queued a `PUT`, and the whole row from the second to reconnect won. **On a later update**, each `PATCH` carried only its own column, and the two merged. Both devices ended up with the server's row each time. |
| Domain model C11 | ✅ Alice queued household actions offline, then left the household. On reconnect, both were rejected with `42501` into `rejected_writes`, one of them in the same transaction as a personal action that uploaded. The queue drained. Finding 6 is the gap. |
| A soft-deleted row disappears from both devices | ✅ The server keeps the row with `deletedAt` set. It left the writing device at its next checkpoint, and a device that was offline lost it when it reconnected. |
| After a bucket change, the old and new buckets' devices converge, with nothing left behind or duplicated | ✅ **Join:** within a second Alice's device held Bob's household, with its slots, tasks, rule versions, and actions. Her old household's rows were gone, and her personal tasks stayed. **Change task scope:** two personal tasks, with 3 rule versions and 2 actions, became household rows exactly once on every device. Alice gained them. **Leave:** Alice's device dropped the household, and Bob's devices showed her membership closed with its snapshot. A device that was offline caught up each time. Finding 7 is the gap. |
| Neither household downloads any of the other's rows | ✅ Three households side by side, checked after every step on every device and on each account's whole download: no shared row. Each held exactly what §5.1 says it should. |
| **Open:** does the stream lookup account → profile → open membership → household work? | **Yes**, so the JWT needs no custom claims (A, below). |
| **Open:** which sync tools qualify as the fallback? | None as a drop-in. Candidates below. |

What S2 found (numbered after S1's findings):

5. **A row sent by two streams with different columns loses columns.** §5.1's `household_people` sent every open member's profile as `profiles`, names and avatars only. That included my own row, which `profile` also sends with every column. The client keeps the copy with the highest `op_id` ([PowerSync](https://docs.powersync.com/architecture/client-architecture)). On every device, the household copy won, and the device's own profile read `dayStartMinutes` as null. Streams can't leave out my own row, because they don't support `NOT IN (SELECT …)` ([PowerSync](https://docs.powersync.com/sync/supported-sql)). **Fix:** a source alias (`FROM profiles AS household_profiles`) sends other members' profiles to a client table of their own. With the alias, every check passed, including builds that predated the client table. Those builds kept the rows aside until a newer build added the table.
6. **An update that RLS blocks comes back as a success.** RLS filters an `UPDATE`'s target rows instead of raising `42501`. After Alice left, her queued rename of a household task came back 2xx with 0 rows, and nothing reached `rejected_writes`. **Fix:** a `PATCH` that returns no row is a permanent error. PostgREST returns the updated rows by default. In a second run, the rename landed in `rejected_writes`.
7. **Writes queued in a task's old scope keep it.** The iPad was offline while a task moved to the household, and still held it as personal. Its tick and its next rule version uploaded with Bob as owner. RLS accepted them, so they stayed in Bob's `profile` bucket, and Alice never got them. **Fix:** a server trigger copies the scope from the task on every insert and update of rule versions and actions. RLS then applies the household rules. In a second run, both rows landed in the household, and all three devices converged.

## Options for S2's open check (architecture §5.1)

| | **A. The streams look up the chain** | B. `profileId` and `householdId` as JWT claims |
|---|---|---|
| How | Streams key on `auth.user_id()`, and CTEs and subqueries look up `profile_accounts` and `memberships` | A Supabase access-token hook adds the claims, and streams key on them |
| After a join or leave | Devices follow within a second, because PowerSync re-evaluates the lookups when rows change | Nothing moves until the session's token is refreshed. The app would refresh it after every lifecycle call, and other devices would wait for their own refresh. |
| Leaving out my own profile (finding 5) | Not possible | Possible, with `id != ` the claim |
| Extra pieces | None | The hook, and refreshing the session |
| Prototyped | Yes, in every S2 run | No |

## Fallback candidates (AM-01)

Checked on 2026-10-19. A fallback needs offline writes (S1), server-enforced permissions (R4), an iOS client, and an existing sync tool (R3). R1 prefers Postgres.

| Tool | Offline writes | Permissions on the server | iOS client | Backend | Qualifies? |
|---|---|---|---|---|---|
| [ElectricSQL](https://electric.ax/docs/guides/writes) | ❌ It syncs reads only. Writes go through our own API. | Writes through PostgREST keep RLS. Reads need our own auth proxy. | ❌ HTTP API only | Postgres | **Partly.** It could replace PowerSync's download path, but the local store, the write queue, and a Swift client would be ours to build, against R3. |
| [SQLite-Sync](https://github.com/sqliteai/sqlite-sync) | ✅ CRDT merges | Server-side RLS is claimed, not verified | ✅ Swift package | Postgres, through its own extension and sync service, [beta](https://github.com/sqliteai/sqlite-sync/blob/main/docs/postgresql/README.md) | **Not yet.** It's beta, and its Supabase support is a self-hosted image, which ADR-002's managed Supabase can't run. |
| [Couchbase Lite + Sync Gateway](https://docs.couchbase.com/sync-gateway/3.2/access-control-concepts.html) | ✅ | ✅ A sync function on the server assigns channels and can reject any write | ✅ | Couchbase, not Postgres | **Yes, at the cost of the whole backend** (R1). The free hosted tier deletes a cluster idle for 30 days ([Couchbase](https://docs.couchbase.com/cloud/get-started/configuring-app-services.html)), so R2 means self-hosting it. |
| [Ditto](https://docs.ditto.live/auth-and-authorization/cloud-authentication) | ✅ Also peer-to-peer | ✅ An auth webhook we write grants permissions | ✅ | Proprietary | **Yes, technically**, but closed and not Postgres (A1, R1), with the most lock-in of these |
| [Zero](https://zero.rocicorp.dev/docs/connection) | ❌ "Zero does not support offline writes" | ✅ | ❌ TypeScript | Postgres | No |
| [Atlas Device Sync](https://mongodb.com/docs/realm) | — | — | — | MongoDB | No: end of life on 2025-09-30 |

So no Postgres-based tool replaces PowerSync as it stands. If PowerSync ever had to go: Electric for downloads with our own client side, or Couchbase Mobile with a new backend. The ADR-001 review would choose between them.

## Decision: S2 passes; ADR-001 stands, with A and the fixes for findings 5–7

- ADR-001's decision B and sub-decision 1b (i) stand. No fallback is needed. Change task scope moves rows between buckets as it is, so the copy + delete fallback isn't needed either.
- The streams key only on `auth.user_id()` and look up the chain (A). The JWT carries no custom claims.
- **Finding 5:** `household_people` sends other members' profiles into a client table of their own, `household_profiles`, and never as `profiles`.
- **Finding 6:** the upload handler treats a `PATCH` that returns no row as a permanent error.
- **Finding 7:** the server copies a rule version's or action's scope from its task on every insert and update.

## Consequences

- [Architecture §5.3](../04-architecture.md#53-identity-flow) and §6, and [domain model §3.1](../03-domain-model.md#31-operations) (*Import or Discard*), say what's decided here.
- P2's streams must cover every synced table before any device connects. Otherwise rows vanish from devices after their first upload (finding 1).
- On a `claimed` result, the app must not call `connect()` until the user has chosen Import or Discard, or the device's own rows are lost (finding 1).
- The queue holds every P1 write until the first sign-in, which then uploads them one operation at a time. That took about 5 ms per operation against the local stack, and it hasn't been measured against a remote backend. P2's connector may batch them.
- The PowerSync GRDB integration and sub-decision 1b (ii) aren't needed.
- [Architecture §4.2](../04-architecture.md#42-write-path-tasks-and-actions-works-offline) (finding 6), §5.1 (A, finding 5), and §5.2 (finding 7), and [domain model §2.7–§2.8](../03-domain-model.md#27-ruleversion-what-makes-occurrences-exist) and §3.1 (*Change task scope*), say what's decided here.
- No two streams may send the same client table with different columns (finding 5).
- S2's check script (on its spike branch) is a starting point for the download isolation test and the two-simulator script ([architecture §7](../04-architecture.md#7-testing-strategy)).

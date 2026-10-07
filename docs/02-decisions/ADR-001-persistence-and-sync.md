# ADR-001 — Persistence and sync engine

**Status:** Accepted (2026-09-25).

## Context
- Every device must work fully offline (NFR-01).
- Control over sync is preferred to managed magic (A1). An owned backend is acceptable (A3). Sync itself should come from an existing tool, not be hand-built (R3).
- Budget: about $10/mo (R2). Everything is Apple-only for now (A4).
- The server should enforce permissions (R4).
- This decision drives almost every other one.

## Options

| | **A. SQLiteData + CloudKit** | **B. PowerSync + Supabase** | **C. Firebase Firestore** |
|---|---|---|---|
| How it works | Local SQLite through GRDB. Point-Free's [SQLiteData](https://github.com/pointfreeco/sqlite-data) mirrors it to the user's iCloud private database. Sharing uses `CKShare`. | Local SQLite managed by the [PowerSync Swift SDK](https://docs.powersync.com/client-sdks/reference/swift). The server is Supabase Postgres. *Sync rules* decide what each user downloads. Local writes go into an upload queue, and **app code** uploads them to Supabase, where row-level security (RLS) enforces permissions. | Google's SDK caches documents offline and syncs them automatically. |
| Running cost | $0 | $0 on the free tiers (see ADR-002). About $25 with Supabase Pro. | $0 on Spark (1 GiB storage, 50k reads and 20k writes per day) |
| Server-enforced permissions | ❌ Only read-only or read-write per share | ✅ Postgres RLS | ✅ Security rules |
| Who can be shared with | iCloud users only | Anyone with an account, including paired devices | Anyone with an account |
| Control and transparency | Medium. The SQL is ours. Apple owns the transport and conflict handling. | **High.** The schema, sync rules, upload handler, and conflict rules are all ours. Everything can be inspected with SQL. | Low. Sync is a black box, and the data is NoSQL. |
| Fit with existing skills (R1) | Low (CloudKit is all new) | **High** (Postgres, SQL, infra) | Medium (similar to DynamoDB) |
| Lock-in | Apple | Low. It's plain Postgres, and PowerSync has a free self-hostable [Open Edition](https://powersync.com/blog/powersync-open-edition-release). | Google |
| Main risks | Tables with two foreign keys **can't be shared** ([docs](https://github.com/pointfreeco/sqlite-data)), and a completion points to both a task and a member. There are [reports of CKShare acceptance bugs on iOS 26](https://developer.apple.com/forums/thread/788427) (to verify). | Two vendors. Both free tiers pause after 7 days of inactivity. The Swift API is raw SQL (the [GRDB integration is alpha](https://docs.powersync.com/client-sdks/orms/swift/grdb)). PowerSync is a smaller vendor. | Goes against A1. A heavy SDK. Offline queries only see cached data. |

**Rejected without a full column:**
- **SwiftData**: the least control, and it still [doesn't support CloudKit's shared database](https://developer.apple.com/forums/thread/756721).
- **Hand-rolled sync** (e.g. Lambda + DynamoDB): R3 says it isn't needed, and it would roughly double the work of Phases 2–3.
- **AWS Amplify DataStore**: [not supported in Amplify Gen 2](https://github.com/aws-amplify/amplify-swift/issues/3764).

## Decision: **B (PowerSync + Supabase)**

- It's the only option that meets **R3 (don't build sync) and R4 (server-enforced permissions)** together, while keeping everything inspectable with SQL.
- It builds on existing skills (Postgres, SQL, infra as code), and what's new (RLS, logical replication, sync rules) is reusable backend knowledge.
- Its lock-in is the lowest of the three. If PowerSync Cloud ever goes away, we can self-host the Open Edition against the same Postgres.
- Option A is a close second **on cost alone**: $0 forever with no pausing. It loses on R4, on the two-foreign-key sharing limit, and on sharing only with iCloud users.

## Sub-decision 1b (accepted: (i)) — the local store in Phase 1 (solo, no backend)

| | (i) **PowerSync SDK in local-only mode from day 1** | (ii) GRDB or SQLiteData now, migrate to PowerSync in P2 |
|---|---|---|
| P2 migration | None. Calling `connect()` starts sync. | A one-time data migration and a rewritten data layer |
| Developer experience in P1 | Raw SQL and `watch()` queries, mapped to structs by hand | Nicer SwiftUI observation and typed queries |
| Risk | Committed to PowerSync before sync is tried | Double work |

**Recommendation: (i)**, behind a repository protocol so that (ii) is still possible if the Phase 2 spike fails. PowerSync [supports local-only use without `connect()`](https://docs.powersync.com/client-sdks/reference/swift).

## Consequences
- Every row gets a **client-generated UUID** `id`. The server never generates IDs.
- Conflict rules live in the **upload handler and Postgres functions** (see ADR-007), not in the SDK.
- Before Phase 2 there's a **sync spike**: one table, two devices, offline edits, and an RLS check.
- *To verify:* how a paused PowerSync free instance is reactivated, and how long Supabase keeps paused projects restorable.

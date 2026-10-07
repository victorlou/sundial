# Decisions — index

**Status:** All accepted. ADR-001 to 010 on 2026-09-25, ADR-011 on 2026-09-29, ADR-012 on 2026-09-30. To change a decision, write a new ADR that supersedes it. Accepted ADRs only get editorial fixes.

| ADR | Decision | Options | Accepted | Hinges on |
|---|---|---|---|---|
| [001](ADR-001-persistence-and-sync.md) | Persistence and sync | A. SQLiteData + CloudKit<br>**B. PowerSync + Supabase**<br>C. Firestore | **B**, and 1b = (i): PowerSync in local-only mode from P1 | R3 + R4: an existing sync tool *and* server-enforced permissions |
| [002](ADR-002-hosting-and-cost.md) | Hosting and cost | **A. Free tiers**<br>B. Supabase Pro<br>C. VPS | **A now, B later**, plus a nightly `pg_dump` to S3 | R2: $10 now, easy to pause |
| [003](ADR-003-identity-model.md) | Identity | **A. Member-centric**<br>B. Account-centric<br>C. Device-centric | **A** | B3, and Sign in with Apple being unavailable under 13 |
| [004](ADR-004-sharing-and-permissions.md) | Sharing and permissions | **A. Personal + household scopes**<br>B. Per-list sharing<br>C. Household only | **A**, with capabilities instead of roles | C1, C2 |
| [005](ADR-005-recurrence-engine.md) | Recurrence engine | A. Materialize<br>**B. Compute on read**<br>C. Hybrid | **B** | Floating schedules, editing history safely |
| [006](ADR-006-day-boundary-and-time-zones.md) | Day boundary and time zones | **A. Logical day stored on each event**<br>B. Home time zone<br>C. Instants only | **A** | D5: the simplest option that keeps history stable |
| [007](ADR-007-events-and-conflicts.md) | Completions and conflicts | A. Mutable, last writer wins<br>**B. Append-only events**<br>C. Event sourcing | **B** | Offline ticks, undo, stats, and the ledger |
| [008](ADR-008-app-structure.md) | App structure | A. Single target<br>**B. SPM packages + `@Observable`**<br>C. B + TCA | **B** | A1: learnable, with enforced boundaries |
| [009](ADR-009-gamification-scope.md) | Gamification | A. Celebrations<br>**B. + points ledger and rewards**<br>C. + game layer | **A in P4, B in P5, C not planned** | F1 |
| [010](ADR-010-household-membership-lifecycle.md) | Household membership lifecycle | A. Owner role + `createdBy`<br>**B. Profile + Membership + capabilities**<br>C. Optional household | **B**, plus HH-01 to HH-07 | Joining and leaving must keep history and personal data intact |
| [011](ADR-011-data-deletion-and-retention.md) | Data deletion and retention | A. Hard-delete now<br>**B. Soft-delete + purge**<br>C. Soft-delete forever | **B**, 30 days for account deletion, 180 days otherwise | Recover from mistakes without breaking privacy law |
| [012](ADR-012-environments-and-release.md) | Environments and release | A. Local + Prod<br>**B. Local + Dev + Prod**<br>C. + staging | **B**, separate app variants, Xcode Cloud from P2, TestFlight for the family | Real devices for testing, without risking family data |

## How they fit together

```mermaid
flowchart LR
  subgraph Device["iPhone / iPad"]
    UI["Features<br/>(SwiftUI + @Observable)"] --> Dom["Domain<br/>(pure models + recurrence engine)"]
    Data["Data<br/>(repositories)"] --> Dom
    UI --> Data
    Data --> PS[("PowerSync SQLite<br/>+ upload queue")]
  end
  PS <-- "sync rules<br/>(download)" --> PSS["PowerSync Service"]
  PS -- "upload handler<br/>(REST/RPC)" --> SB[("Supabase Postgres<br/>RLS + functions")]
  SB -- "logical replication" --> PSS
  SB -. "nightly pg_dump" .-> S3[("S3 backup")]
```

The full architecture is in [04-architecture.md](../04-architecture.md).

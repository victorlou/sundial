# ADR-011 — Data deletion and retention

**Status:** Accepted (2026-09-29).

## Context
- Several flows "delete" things:
  - account deletion (FR-33, which the App Store requires)
  - an empty household after a join
  - a household whose last linked profile leaves
  - data discarded on import
- Nothing should be deleted the moment someone acts. Old inactive data should be purged by a routine.
- Privacy law (GDPR, Brazil's LGPD) expects **user-requested** erasure "without undue delay", usually read as about a month. App Store rules require account deletion to really happen, and any delay must be disclosed to the user.

## Options

| | A. Hard-delete immediately | **B. Soft-delete, then purge after a retention period** | C. Soft-delete forever |
|---|---|---|---|
| Recover from mistakes | ❌ | ✅ Within the retention period | ✅ |
| Legal for account deletion | ✅ | ✅ If the period is short and disclosed | ❌ |
| Complexity | Low | A `deletedAt` column, RLS filters, and a scheduled job | Low, but the data grows forever |

## Decision: **B**

| What | Retention |
|---|---|
| Data from an account the user deleted | **30 days**, disclosed in the UI. Signing back in within the period cancels the deletion. The profile is shown as "Former member" at once, and its name is overwritten at purge. |
| Everything else deleted by the system (empty households, deleted unlinked profiles, data discarded on import) | **180 days** |
| Archived tasks, revoked actions | Not deletions. Kept as history. |

**Why 30 days rather than 180 for accounts:** it's the one case where the user explicitly requests erasure, and six months would be hard to defend as "without undue delay".

## Consequences
- Every synced table gets `deletedAt?`.
- RLS and PowerSync sync rules exclude deleted rows, so they disappear from devices at once.
- The **purge job** is a scheduled Postgres function (`pg_cron`, or a scheduled Edge Function). It isn't needed before real family data exists, so it isn't built before P3.
- **Backups:** an S3 lifecycle rule expires `pg_dump` files after 30 days. Otherwise purged data would live on in old backups.

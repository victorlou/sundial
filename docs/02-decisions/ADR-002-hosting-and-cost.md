# ADR-002 — Hosting, cost, and backups

**Status:** Accepted (2026-09-25).

## Context
- Budget is about $10/mo now and about $25/mo later. The backend should be easy to "turn off" (R2).
- US region (R6).
- The data is tiny. A family of 5 with about 60 tasks produces roughly 10–20k event rows a year.

## Facts checked (Sep 2026)

| Service | Free tier | Paid |
|---|---|---|
| [Supabase](https://supabase.com/pricing) | 500 MB database, 2 active projects. **Pauses after 1 week of no database or API activity.** **No backups.** | Pro is $25/mo. It includes $10 of compute credit (one Micro instance), daily backups kept 7 days, no pausing, and a spend cap on by default. |
| [PowerSync Cloud](https://www.powersync.com/pricing) | 2 GB synced per month, 500 MB hosted, 50 peak concurrent clients. **Deactivated after 1 week of inactivity.** | Pro is $49/mo, which is outside the budget. |
| Self-hosted VPS | — | Hetzner [raised prices in June 2026](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/). Expect roughly €6–12/mo. |

## Options

| | **A. Both free tiers** | **B. Supabase Pro + PowerSync Free** | **C. Self-host everything on a VPS** |
|---|---|---|---|
| Cost | **$0** | $25 | About €6–12, plus maintenance time |
| Pausing | Both pause after 7 idle days. Daily family use keeps them active, and pausing doubles as the "off switch". | The database never pauses. PowerSync can still deactivate. | None |
| Backups | Built by us: a nightly `pg_dump` to S3 from a scheduled GitHub Action (cents a month) | 7 days of daily backups included | Built by us |
| Ops | None | None | Updates, TLS, auth server, monitoring, all yours |
| Reliability | Good while it's used | Good | Depends on our ops |

## Decision: **A now, B once the family depends on it**
- A costs $0 during development, and the pause doubles as the required "turn it off for a while" switch (R2).
- The two free Supabase projects map neatly to **dev** and **prod**.
- The off-platform `pg_dump` backup is worth keeping even after moving to B.
- C is the best way to learn ops, but it's the worst match for "reliable, with no sync plumbing to build".

## Consequences
- Everything is in the repo as code:
  - Supabase CLI SQL migrations
  - RLS policies
  - PowerSync sync rules (YAML)
  - Edge Functions
  - the backup workflow
- If both services pause, the app keeps working locally (NFR-01). Sync resumes once they're reactivated.

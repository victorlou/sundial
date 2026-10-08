# Docs — index

Start here. Read only the files your task needs.

## Kinds of document

| Kind | Files | Holds | Changes how |
|---|---|---|---|
| **Current truth** | `01`, `03`, `04`, `05`, `06` | What the system *is* and *how to work on it* | Edited in place and kept current |
| **Decisions** | `02-decisions/ADR-*` | *Why* each choice was made, and what was rejected | Never rewritten. A change means a new ADR that supersedes the old one. |

Short constraint IDs cited in the docs (A1, R3, S6′, …) are defined in [01-requirements § Constraint IDs](01-requirements.md#constraint-ids). Spikes (S1–S5, in [05](05-roadmap.md)) and the domain model's worked cases (C1–C11, E1–E6, L1–L16, in [03](03-domain-model.md)) reuse some of the same letters, so other files cite them with their source: "spike S2", "domain model C8".

**One fact, one place.** Other files link to that place instead of repeating the fact.

Where an ADR and a current-truth file disagree on detail, the current-truth file wins.

## Read this when…

| Task | Read |
|---|---|
| Understanding the product and its scope | [01-requirements](01-requirements.md) (glossary, FR/NFR, non-goals) |
| Working on the recurrence engine, Today, history, or streaks | [03-domain-model](03-domain-model.md) §4–§7 |
| Working on households, profiles, invites, or pairing | [03-domain-model](03-domain-model.md) §2–§3, [ADR-010](02-decisions/ADR-010-household-membership-lifecycle.md) |
| Working on sync, conflicts, or the upload handler | [03-domain-model](03-domain-model.md) §8, [04-architecture](04-architecture.md) §4–§5 |
| Adding or changing a table, RLS policy, or sync stream | [04-architecture](04-architecture.md) §5, **[06](06-environments-and-release.md) §5 (compatibility rules)** |
| Choosing where code goes (Domain / Data / Features / App) | [04-architecture](04-architecture.md) §3 |
| Writing tests | [04-architecture](04-architecture.md) §7 |
| Build settings, environments, the local stack, secrets | [06-environments-and-release](06-environments-and-release.md) §1–§3 |
| Releasing, CI/CD, versions, feature flags, test data, turning the backend off | [06-environments-and-release](06-environments-and-release.md) §4–§8, §10 |
| Deleting data or anything to do with retention | [ADR-011](02-decisions/ADR-011-data-deletion-and-retention.md), [03-domain-model](03-domain-model.md) §2.10 |
| Knowing what's in scope for the current phase | [05-roadmap](05-roadmap.md) |
| Knowing why something is the way it is | [02-decisions/README](02-decisions/README.md) |

## Files

| File | Status |
|---|---|
| [01-requirements.md](01-requirements.md) | Approved |
| [02-decisions/](02-decisions/README.md) | ADR-001 to ADR-013 accepted |
| [03-domain-model.md](03-domain-model.md) | Accepted |
| [04-architecture.md](04-architecture.md) | Draft |
| [05-roadmap.md](05-roadmap.md) | Draft |
| [06-environments-and-release.md](06-environments-and-release.md) | Current |

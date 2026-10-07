# ADR-012 — Environments and release process

**Status:** Accepted (2026-09-30).
**How-to:** [06-environments-and-release.md](../06-environments-and-release.md). This ADR records only *why*.

## Context

- Changes must be tried on real devices without putting the family's data at risk.
- Budget: $0 beyond the Apple Developer Program (ADR-002). The free tiers allow 2 Supabase projects and 2 PowerSync instances.
- **On iOS, the backend and the app don't deploy together.** Older app versions keep running, and offline devices hold writes queued in the old shape. Backend changes must stay compatible with older app versions.



## Decisions


| #   | Question                                | Options                                                                                                                                                                                       | Decision                                                                                                              |
| --- | --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| E-1 | Environments                            | A. Local + Prod · **B. Local + Dev + Prod** · C. B + a separate staging                                                                                                                       | **B.** It covers coding, testing on real devices, and real use, and it fits the free tiers exactly.                   |
| E-2 | Keeping Dev apart from Prod on a device | A. One app with a hidden backend switch · **B. A separate bundle ID, icon, name, and App Group per variant**                                                                                  | **B.** A switch would put dev and real data in the same local database. Separate variants install side by side.       |
| E-3 | iOS builds                              | A. Archive by hand in Xcode · B. Xcode Cloud (25 compute hours a month included with the developer program) · C. GitHub Actions on macOS (macOS minutes count 10× against the free allowance) | **A in P1, B from P2.** Backend CI runs on GitHub Actions Linux runners.                                              |
| E-4 | How the Prod app gets to the family     | **A. TestFlight, internal testers** · B. Unlisted App Store · C. Public App Store                                                                                                             | **A through P3.** Reconsider B once the app is stable, since Apple declines unlisted requests for apps still in beta. |




## Consequences

- **Backward compatibility is a standing rule:**
  - schema changes follow expand, then contract
  - the client schema only ever grows
  - a server-side `min_supported_build` gate stops sync for app builds that are too old
- **Prod data is never copied into Dev or Local**, because it includes children's data. Backup-restore rehearsals use a throwaway local database.
- TestFlight builds expire after 90 days. A scheduled Xcode Cloud build keeps the Prod build fresh.
- **Prod releases deploy the backend first, then the app.** Expand/contract makes that order safe.


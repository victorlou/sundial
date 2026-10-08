# ADR-008 — App structure and modularity

**Status:** Accepted (2026-09-25). Partly superseded by [ADR-013](ADR-013-board-review-amendments.md): sync rules are now Sync Streams (AM-02).

## Context
- The architecture must be learnable, and every layer must be understandable (A1, NFR-09).
- Widgets and a Mac app are planned for later (B1).
- The domain must be testable on its own (NFR-05).

## Options

| | A. One app target, folders by feature | **B. Local SPM packages by layer, with plain SwiftUI + `@Observable`** | C. B + TCA |
|---|---|---|---|
| Structure | Everything in one target | `Domain` (pure: models and recurrence engine), `Data` (PowerSync, repositories, sync connector), `Features` (SwiftUI views and `@Observable` models), and a thin `App` target | The same packages, with features written as TCA reducers |
| Boundaries enforced | Only by discipline | **By the compiler** | By the compiler and the framework |
| Domain tests | Need the app or a simulator | Run with `swift test` in milliseconds | Same as B |
| Reuse for widgets or Mac later | Needs extracting first | Import the packages | Same as B |
| New concepts to learn | Fewest | A few (SPM, dependency injection through initializers) | Many (reducers, effects, dependencies, TCA's navigation) |

## Decision: **B**
- Compiler-enforced boundaries help most for someone learning where code belongs.
- Rejecting TCA isn't a judgment on TCA. It's about stacking too many new concepts at once (SwiftUI, PowerSync, and Supabase are all being learned at the same time). It could be adopted per feature later.

## Consequences
- **Monorepo layout:**

  ```
  /ios        Xcode app + local packages
  /backend    Supabase migrations, RLS, functions, sync rules
  /docs       these documents
  ```

- **Dependency rule:** `Features → Domain`, and `Data → Domain`. `Domain` depends on nothing.
- Screens depend on repository **protocols** defined in `Domain`. This is what makes ADR-001's sub-decision (i) reversible.

# 01 — Requirements

**Status:** Approved (2026-09-25). Amended by ADR-010 (household membership lifecycle), ADR-011 (deletion), and the board review of 2026-10-01 (glossary, FR-33, FR-41, FR-41d, FR-50, FR-51, NFR-01, NFR-02, NFR-05, NFR-10, non-goals).
**Constraint IDs** such as A1, R3, or S6′ are cited across the docs. They're defined in [Constraint IDs](#constraint-ids) at the end of this file.
**Phase tags** (P1–P5) refer to the roadmap in [05-roadmap.md](05-roadmap.md):


| Tag       | Phase             |
| --------- | ----------------- |
| **P1**    | Solo MVP          |
| **P2**    | Multi-device sync |
| **P3**    | Family sharing    |
| **P4**    | Kid/iPad board    |
| **P5**    | Gamification      |
| **Later** | No phase yet      |


## Glossary


| Term                  | Meaning                                                                                                                               |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Logical day**       | The calendar date a moment belongs to after applying the profile's *day-start hour*. With a 5 AM start, 4:30 AM on Tue belongs to Mon. |
| **Slot**              | A named part of the day (Morning, Afternoon, Evening, or user-defined), plus *Anytime*. No clock times.                               |
| **Occurrence**        | One instance of a task on one logical day, in one slot, for one profile (or shared by the household). This is the thing you tick.            |
| **Fixed schedule**    | The next due date comes from the calendar, whether or not the last one was done (Skylight style).                                     |
| **Floating schedule** | The next due date is the last completion + N days (Tody style).                                                                       |
| **Miss policy**       | What happens to a missed occurrence: *vanish*, *mark missed*, or *carry over* (collapsed into one item).                              |
| **Profile**           | Someone who uses the app: a name, an avatar, and their tasks and history. It may or may not have an account.                          |
| **Membership**        | A profile's place in one household, including their capabilities there. One open membership per profile for now (C4).                |
| **Account**           | A sign-in identity (Sign in with Apple, or later a paired device, FR-53). It links to at most one profile. A profile can have several accounts.   |
| **Linked / unlinked** | A profile with at least one account / with none (e.g. a kid who only uses the shared iPad).                                           |
| **Capability**        | A named permission held through a membership (e.g. manage tasks). It doesn't depend on "adult" or "kid".                             |




## Functional requirements



### Today view


| ID    | Requirement                                                                                                                                  | Phase |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| FR-01 | Today lists the occurrences due on the current logical day, grouped by slot. The default slots are Morning, Afternoon, Evening, and Anytime. | P1    |
| FR-02 | Users can rename, reorder, add, and remove slots.                                                                                            | P1    |
| FR-03 | Tick and untick an occurrence. Unticking is an undo and keeps the history consistent.                                                        | P1    |
| FR-04 | **Skip** an occurrence ("not today, on purpose"). Skips are distinct from misses.                                                            | P1    |
| FR-05 | Carried-over items show a **warning level that grows** the more overdue they are.                                                            | P1    |
| FR-06 | **Snooze N days** hides an item. The overdue count keeps running (R5).                                                                       | P1    |
| FR-07 | Nothing appears before its due date.                                                                                                         | P1    |




### Tasks and recurrence


| ID    | Requirement                                                                                                           | Phase |
| ----- | --------------------------------------------------------------------------------------------------------------------- | ----- |
| FR-10 | One-off tasks with no repeat. They can be undated, which means Anytime from today until done.                         | P1    |
| FR-11 | Fixed interval: every N days or weeks from an anchor date.                                                            | P1    |
| FR-12 | Floating interval: N days after the last completion.                                                                  | P1    |
| FR-13 | Specific weekdays (e.g. Mon/Thu).                                                                                     | P1    |
| FR-14 | Monthly: on a day of the month, or on the Nth weekday ("first Saturday").                                             | P1    |
| FR-15 | Yearly, and seasonal active windows (e.g. May–Sep).                                                                   | Later |
| FR-16 | Each task has its own miss policy (vanish / mark missed / carry over), with a sensible default for its schedule type. | P1    |
| FR-17 | A task can occupy several slots on the same day, and each slot is ticked separately.                                  | P1    |
| FR-18 | Editing a task's schedule never rewrites past history. Changes take effect from a date.                               | P1    |
| FR-19 | Each profile has a day-start hour (default 05:00).                                                                     | P1    |




### History


| ID    | Requirement                                                                         | Phase |
| ----- | ----------------------------------------------------------------------------------- | ----- |
| FR-20 | Keep the full history of completions, skips, and snoozes (occurrence actions). Nothing is hard-deleted when a user acts (ADR-011).                           | P1    |
| FR-21 | Show a streak for fixed habits, and the average actual interval for floating tasks. | P1    |




### Accounts and sync


| ID    | Requirement                                                                            | Phase |
| ----- | -------------------------------------------------------------------------------------- | ----- |
| FR-30 | The app is fully usable with **no account**. Data stays on the device.                 | P1    |
| FR-31 | Sign in with Apple turns on sync. Existing local data is kept and uploaded.            | P2    |
| FR-32 | Changes made offline on any device sync when it reconnects. No user action is needed.  | P2    |
| FR-33 | Users can delete their account and all its server data. (The App Store requires this.) It's soft-deleted at once and purged after 30 days; signing back in within that time cancels it (ADR-011). The app tells the user that deletion takes up to 60 days, including backups. | P2    |




### Household


| ID    | Requirement                                                                                                                                         | Phase |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| FR-40 | Every profile is always in a household: a solo user gets a hidden household of one at first launch (P1). The personal/household choice only appears once the household has 2 or more memberships. | P1    |
| FR-41 | Invite people to the household with a one-time code, shared as text or a QR code. Whoever redeems the code joins, with their own consent, and the inviter is shown who joined; nobody's account is added without consent. The invite sets the joiner's capabilities, which they see before accepting. This doesn't depend on Apple Family Sharing. | P3    |
| FR-41a | Joining a household means leaving the current one. Your personal tasks come with you; household tasks stay behind. | P3    |
| FR-41b | Add an **unlinked profile** (e.g. a kid) to the household. It can be linked to an account later. | P3    |
| FR-41c | Leave a household, or remove someone from it. You can't leave the household without a linked profile holding `manageMembers`. | P3    |
| FR-41d | The last linked profile can't leave while unlinked profiles remain (HH-04). A household is deleted only when its last linked profile deletes their account (FR-33), after a clear warning that unlinked profiles and their history go with it. | P3    |
| FR-42 | A task is **personal** (the default, visible only to its owner) or **household**.                                                                   | P3    |
| FR-43 | Household tasks can be **assigned** (to one profile), **everyone** (each chosen profile does it), or **up for grabs** (the first person to do it closes it). | P3    |
| FR-44 | Rotation between profiles.                                                                                                                           | Later |
| FR-45 | Capabilities are granted per membership. The server enforces them for accounts (R4).                                                                    | P3    |
| FR-46 | My Today view merges my personal tasks with my household occurrences.                                                                               | P3    |
| FR-47 | A household board shows today's occurrences as one column per profile.                                                                               | P3    |




### Kid/iPad board


| ID    | Requirement                                                                                   | Phase |
| ----- | --------------------------------------------------------------------------------------------- | ----- |
| FR-50 | **Kid mode**, turned on for a device by a parent: pick a profile, then tick that profile's items. Only household tasks are shown and can be ticked; the signed-in parent's personal tasks are hidden. Kids lose nothing, because unlinked profiles own only household tasks (DM-12). | P4    |
| FR-51 | In kid mode, management actions, settings, and sign-out aren't available. Leaving kid mode needs an app-specific **parent PIN**, not the device passcode, which the kids may know. **Threat model:** this stops casual access by children, not a child who can delete and reinstall apps; iOS Screen Time ("Deleting Apps: Don't Allow") closes that gap. | P4    |
| FR-52 | A celebration plays when a profile finishes their slot or their day.                           | P4    |
| FR-53 | A kid's own device is **paired** to their profile, without Sign in with Apple.                 | Later |




### Gamification


| ID    | Requirement                                                                           | Phase |
| ----- | ------------------------------------------------------------------------------------- | ----- |
| FR-60 | Tasks earn points. Points go into an append-only ledger per profile. Adults take part. | P5    |
| FR-61 | Rewards are defined within the household and redeemed from points.                    | P5    |
| FR-62 | Cooperative household goals ("200 points this week → pizza night").                   | P5    |




### Later, with no phase yet

- Widgets, including ticking items from a widget.
- Mac app.
- Siri and Shortcuts.
- Notifications (slot-start summaries).
- Several households per person.



## Non-functional requirements


| ID                           | Requirement                                                                                                                                                                       |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| NFR-01 **Offline-first**     | Every read and write of tasks and events works without a network. Today never waits on the network. **Exception:** household lifecycle actions (invite, join, leave, remove, change capabilities, delete an unlinked profile, link an account), changing a task's scope, and redeeming points (P5) need a connection (ADR-010, ADR-013).                                                                                                   |
| NFR-02 **Cost**              | ≤ $10/mo while building, ≤ $25/mo once the family relies on it (excluding the Apple Developer Program). The backend can be paused without losing data.                            |
| NFR-03 **Privacy**           | Data lives only on devices and on our own backend (US region). No third-party analytics or ads. Personal data is kept minimal: nicknames and avatars.                             |
| NFR-04 **Portability**       | The server data model is plain Postgres. The sync layer can be replaced without rewriting the domain.                                                                             |
| NFR-05 **Correctness**       | The recurrence engine is deterministic and pure: it's given the logical date rather than reading the clock. Every edge case in `03-domain-model.md` is a unit test.               |
| NFR-06 **Platforms**         | iPhone and iPad, on the current iOS/iPadOS major version or the one before (S2).                                                                                                  |
| NFR-07 **Accessibility**     | Supports Dynamic Type and VoiceOver. The board has large tap targets for kids.                                                                                                    |
| NFR-08 **Localization**      | English only, but every string is localizable.                                                                                                                                    |
| NFR-09 **Understandability** | Every layer can be explained end to end. No framework is adopted "because it's standard" if it hides behavior that would need debugging.                                                            |
| NFR-10 **Children's privacy** | Kids using the app is a core reason it exists, so a public version keeps under-13 profiles. **Before any public release**, an ADR covers children's privacy law: the [amended COPPA Rule](https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect) (enforced since 2026-04-22: verifiable parental consent, and a written retention policy with a set time period instead of indefinite retention); [GDPR Art. 8](https://rgpd.com/gdpr/chapter-2-principles/article-8-conditions-applicable-to-childs-consent-in-relation-to-information-society-services) (parental consent under 16, or a member state's lower age, which can't go below 13); and [LGPD Art. 14](https://lgpd-brazil.info/chapter_02/article_14) (specific, prominent consent from a parent). A lawyer checks the ADR's legal reading. |




## Non-goals

These are explicit. A change here needs a new decision.


| Non-goal                         | Why                                                                        |
| -------------------------------- | -------------------------------------------------------------------------- |
| Calendar, clock times, hour grid | This is the product's core premise.                                        |
| Frequency goals ("3× a week")    | Not needed (D3). They would require a second engine.                       |
| Android or web clients           | A4. Postgres keeps this door open, but we won't build for it.              |
| Apple Watch, Live Activities     | B1: never.                                                                 |
| Competitive leaderboards         | F1: cooperative only.                                                      |
| Real money, in-app purchases     | The app is free.                                                           |
| Apple Family Sharing integration | B2. The household is our own concept.                                      |
| App Store Kids Category          | Not planned. Children's privacy law applies with or without it (NFR-10).   |
| Hand-built sync engine           | R3. Use an existing tool.                                                  |

## Constraint IDs

These are the constraints gathered before design began. The IDs are cited across the requirements and the ADRs.

| ID | Constraint |
|---|---|
| A1 | Prefer explicit, inspectable behavior to framework-managed "magic", and keep new concepts few (see NFR-09) |
| A2 | Built for one household first. The App Store is possible later. Always free. |
| A3 | An owned backend (managed BaaS) is acceptable at a small cost |
| A4 | Apple-only users for now |
| A5 | No deadline: phases have exit criteria, not dates |
| B1 | iPhone and iPad now. Mac, widgets, and Siri/Shortcuts later. Apple Watch and Live Activities never. |
| B2 | Adults have their own Apple Accounts. Apple Family Sharing must not be required. |
| B3 | Profiles without accounts and profiles with accounts are both valid. Linking a profile to an account later is a feature. |
| B4 | The shared iPad is signed in with a parent's Apple Account. Kid mode is locked inside the app. |
| C1 | Tasks are private by default. Sharing with the household is opt-in. One merged Today view. |
| C2 | Permissions are capabilities, not adult/kid roles |
| C3 | Household task kinds: assigned, everyone, up for grabs. Rotation later. |
| C4 | One household per person, for now |
| D1 | What happens to a missed item is chosen per task (vanish / mark missed / carry over, collapsed into one item) |
| D2 | Overdue postponable tasks stay in Today, with a warning that grows the more overdue they are |
| D3 | Patterns: fixed interval, floating, weekdays, monthly, one-off. Yearly and seasonal later. No frequency goals. |
| D4 | A task can occupy several slots. Slots are user-definable, plus Anytime. |
| D5 | The day start is per person (default 05:00). "Today" follows the device's time zone. |
| D6 | Notifications are a low priority, for later |
| E1 | Keep all history. Streaks and averages first. |
| F1 | Celebrations early, points and rewards later. Cooperative. Adults take part. |
| R1 | Prefer backend technology the maintainers already know: Postgres, SQL, and cloud infrastructure as code |
| R2 | Budget about $10/mo at first, up to about $25/mo later. The backend must be easy to pause. |
| R3 | Use an existing sync tool rather than building one |
| R4 | Capabilities are enforced on the server for accounts, with a UI lock for profiles on shared devices |
| R5 | Snooze only hides an item. The overdue count keeps running. |
| R6 | Server region: US (`us-east-1`) |
| S1 | Offline-first on every device |
| S2 | Minimum OS: the current iOS/iPadOS major version or the one before it |
| S3′ | Data lives only on devices and our own backend. No third-party analytics. |
| S4 | Kids appear by nickname and avatar, never by photo |
| S5 | English first, with strings kept localizable |
| S6′ | Solo use needs no account. Sign in with Apple is only needed for sync or a household. |
| S7 | The miss policy is set per task, with sensible defaults |
| S8 | "Seasonal" means a date window within the year. Deferred. |



# ADR-003 — Identity: Account vs. Member vs. Device

**Status:** Accepted (2026-09-25). Partly superseded by [ADR-010](ADR-010-household-membership-lifecycle.md): Member is now Profile + Membership. Partly superseded by [ADR-013](ADR-013-board-review-amendments.md): pairing a kid's own device is Later (AM-03).

## Context
- Both profiles and accounts must be valid, and linking a profile to an account later is a feature (B3).
- Permissions are capabilities, not adult/kid roles (C2).
- The shared iPad is signed in with a parent's Apple ID (B4).
- **Sign in with Apple is [not available to children under 13](https://support.apple.com/en-us/102609)**, so a kid's own device needs another way to sign in.
- Solo use needs no account at all (S6′).

## Options

| | **A. Member-centric** | B. Account-centric | C. Device-centric |
|---|---|---|---|
| Core idea | A **Member** is a person in a household. An **Account** is a sign-in identity. An optional link connects them. A device authenticates as an account and *acts for* one or more members. | Every person must have an account. Profiles are only a UI concept. | Each device is the identity. Members are labels. |
| Kid on the shared iPad | A profile-only member. The parent's account acts for them. | Needs an account → blocked by the Sign in with Apple age limit | Natural |
| Kid with their own device later | A **pairing code** binds the device to the kid's member (anonymous auth plus a server check) | Email/password for kids | Natural |
| Personal cross-device sync | ✅ | ✅ | ❌ Devices aren't people |
| Server permissions | Per account, plus "which members may this account act for" | Per account | Per device. Coarse. |

## Decision: **A (member-centric)**
- It's the only option that covers solo use, the shared iPad, and future kid devices without contradicting B3.
- **Solo (P1):** the first launch creates a local "me" member with no account.
- **P2:** signing in binds "me" to the user's account.
- **P3:** members from other households join through invites.

## Consequences
- Every event records `actorMemberId` (who it's credited to). The server also knows `auth.uid()` (which account or device submitted it). These can differ, and that's by design: the shared iPad ticks for Dave.
- The server rule is: an account may write events for **itself**, or for **members it has the `actForOthers` capability on**.
- The limit (R4): the server can't tell Carol and Dave apart on the same iPad. That separation is enforced only in the app.
- Device pairing and anonymous auth are **P4+ spikes**. Supabase supports anonymous sign-in, but linking identities natively [currently has limitations](https://github.com/supabase/supabase-swift/issues/588), so pairing will probably go through an Edge Function that redeems the code.

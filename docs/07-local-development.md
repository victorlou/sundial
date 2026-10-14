# 07 — Local development

**Status:** Current (2026-10-14).
**Read this when:** you're setting up a Mac to work on Sundial, signing a device build, or something in the local setup breaks.

Daily commands for the local stack and tests are in [06 §3](06-environments-and-release.md#3-local-stack). Build configurations and schemes are in [06 §2](06-environments-and-release.md#2-build-configuration).

---

## 1. Prerequisites

The minimum versions are the ones P0 was set up and verified with. `scripts/doctor` checks all of them.

| Tool | Minimum | Install |
|---|---|---|
| Xcode | 27.0 | Mac App Store, then `sudo xcode-select -s <path to Xcode.app>` |
| Swift | 6.2 (the packages' `swift-tools-version`) | Comes with Xcode |
| iOS simulator runtime | 26.0, the deployment target ([NFR-06](01-requirements.md)) | Xcode → Settings → Components |
| XcodeGen | 2.46.0 | `brew install xcodegen` |
| Supabase CLI | 2.120.0 | `brew install supabase/tap/supabase` |
| A Docker runtime with Compose | Compose 5.6.0 | Any one works. Colima: `brew install colima docker docker-compose`. OrbStack or Docker Desktop also work. |

## 2. First-time setup

1. Run `scripts/doctor` from the repo root and fix anything it marks ✗.
2. Run `xcodegen generate` in `ios/`, then open `ios/Sundial.xcodeproj`.
3. Run the **Sundial (Local)** scheme on a simulator. It needs the local stack only once the app talks to a backend ([06 §3](06-environments-and-release.md#3-local-stack)).

### Signing a device build

Signing is per developer and never committed.

1. Sign into Xcode with your Apple Account (Xcode → Settings → Accounts).
2. Copy `ios/Config/Signing.local.xcconfig.example` to `ios/Config/Signing.local.xcconfig`, which is git-ignored, and set `DEVELOPMENT_TEAM` to your team ID.
3. If your team isn't the project's, also set your own `BUNDLE_PREFIX` there. Bundle IDs and App Groups belong to one team.
4. Run `xcodegen generate` again, choose your device, and run **Sundial (Dev)** or **Sundial (Prod)**. The two variants install side by side ([06 §1](06-environments-and-release.md#1-environments)).
5. The first time, turn on Developer Mode on the device, and after the first install trust your developer certificate (Settings → General → VPN & Device Management).

A free Personal Team works for this, with limits: installed apps expire after 7 days, and a device can hold 3 of your apps at a time.

## 3. Conventions

- **The Xcode project is generated.** Change `ios/project.yml`, never the `.xcodeproj`, which is git-ignored. Run `xcodegen generate` after pulling and after editing the spec.
- **Nothing machine-specific is committed:** no team IDs, no absolute paths, no Docker runtime assumptions. Machine-specific settings go in the git-ignored local files.
- **PowerSync joins Supabase's Docker network.** The network is named after `project_id` in `backend/supabase/config.toml` (`supabase_network_sundial`). So run `supabase start` before `docker compose up`, and if `project_id` ever changes, update `backend/powersync/` to match.
- **Values in the committed settings files are public.** That includes the local stack's fixed publishable key. Secrets follow [06 §2](06-environments-and-release.md#2-build-configuration).

## 4. Troubleshooting

Only problems that have actually happened are listed here.

| Symptom | Fix |
|---|---|
| `scripts/doctor` or `supabase start` says it can't connect to the Docker daemon | The Docker runtime isn't running. With Colima, run `colima start`, which also switches Docker to its `colima` context. |
| After `supabase db reset`, PowerSync logs `Replication slot … is missing` | Expected. The reset drops PowerSync's replication slot. Within about 30 seconds PowerSync creates a new one and replicates from scratch. Nothing to do. |

# Domain — platform

Prefix: `PLATFORM`. Ground truth: `PROJECT-BRIEF-v2.md` + amendments; invariants I1–I15 in `CLAUDE.md`.

## Purpose

The native app shell every other domain runs inside: content-bundle loading and versioning (static
hosting plus a bundled offline snapshot, D36), student-state persistence as JSON and its iCloud sync
(D32, D36), capability facts for **runtime-tiers**, offline behaviour. It owns the **platform↔all**
seam — no other domain touches the network, the file system or iCloud directly; the sole write path off
the device belongs to **telemetry**. There is no application server (D36) and no environment gate page:
the App Store enforces the iOS 18+ floor (D34). Milestones **Demo** (bundled data only, no network),
**M3** (hosted bundles, sync, telemetry endpoint).

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Launch, work offline, see installed content versions, trigger a content refresh, see whether iCloud sync is active | Choose bundle versions; bypass an integrity failure |
| Owner | Publish a bundle set to the static host; ship the offline snapshot in a build; verify on a physical device at the wrap-gate (D29) | Push an update to a running client (no server logic) |
| System | Fetch and verify bundles; swap atomically; read/write `StudentState`; sync; migrate; report capability facts | Send anything off-device (only **telemetry** may); compute state (I14) |
| Local model (Tier 1), Generation model | No role here | Anything |

## Core entities

**ContentBundle** — the set of versioned JSON files a build requires, one **AssetVersion** each: Spine
(**curriculum-spine**), Graph with precomputed coordinates (**concept-graph**, D33), Regions / Trails /
Landmarks (**map**, **learning-objects**), LearningObjects (**learning-objects**). A **manifest** names
them; a partial manifest is never activated. The app ships an **offline snapshot** of one complete set
(D36) so first launch needs no network; hosted bundles replace it per W2.

**AssetVersion** — an immutable version id plus a content hash, checked on fetch so a truncated or
substituted file fails closed. Versions travel into telemetry events: they describe the build, not the
device (I5).

**StatePersistence** — `StudentState` (**expedition**, a `Codable` struct in `Core`) written as one JSON
document in Application Support, with a `schema_version`; this domain owns reading, writing, migration and
sync, never the shape (I14). Sync via iCloud — an iCloud Drive document container or a CloudKit asset,
chosen at M3 (Q1) — **only when the device is signed in to iCloud; otherwise silent local storage**
(v2.5 §5). Apple-managed identity; no account of ours (D36).

**CapabilityFacts** — OS version, whether the Foundation Models system model reports *available* (Apple
Intelligence enabled on eligible hardware — D34), and nothing else; handed to **runtime-tiers**, kept on
the device (I5).

**Connectivity** — online/offline, observed for W2 and for telemetry buffering; never blocks anything.

## Workflows

### W1 — Launch
**Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline
snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`). If the
snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered.
2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to
**map** W1. Tier 0. **Post:** `platform.launched` emitted.

### W2 — Content refresh
**Pre:** online; the hosted manifest differs from the installed one. **Steps:** 1. Fetch each changed
bundle in the background; verify its hash; on mismatch discard and keep the installed set. 2. Write the
new set alongside the old; swap atomically at next launch (Q2); delete the superseded set. Tier 0.
**Post:** exactly one set active; `platform.content_updated` emitted at the launch that activates it.

### W3 — Read, write and migrate student state
**Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if
`schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one
is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used,
nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:**
`platform.state_migrated` on a migration; `platform.state_written` otherwise.

### W4 — Sync student state
**Pre:** signed in to iCloud; a local write happened or a remote change arrived. **Steps:** 1. Upload the
document / download the remote one per the mechanism chosen in Q1. 2. On conflict merge per Q3 in `Core`
(a pure function over two `StudentState`s), write the merged result, sync again. 3. Signed out, or iCloud
unavailable → do nothing, silently (v2.5 §5). **Post:** `platform.sync_completed` or
`platform.sync_conflict_merged`; a failure is logged locally and retried, never surfaced as an error.

### W5 — Offline operation
**Pre:** no connectivity. **Steps:** run everything from the installed bundle and local state — Doors B, C
and A need no network; telemetry buffers (its W3). **Post:** `platform.connectivity_changed` on transition.

## UI surfaces

Native: **Settings › Storage** — installed content versions, refresh action, iCloud sync status (W2, W4).
No unsupported page: the OS floor is enforced at install (D34).

## Notifications produced

- `platform.launched` — `{ app_version, bundle_versions }`. Consumers: **map**, **telemetry** (session start).
- `platform.content_updated` — new manifest versions. Consumers: **curriculum-spine**, **concept-graph**,
  **learning-objects**, **map**, **expedition** (id revalidation, its W7).
- `platform.state_migrated` — `{ from, to }`; `platform.state_written`. Consumer: **expedition**.
- `platform.sync_completed` / `platform.sync_conflict_merged`. Consumer: **expedition**.
- `platform.capability_facts` — `{ os_version, foundation_models_available }`. Consumer: **runtime-tiers**.
- `platform.connectivity_changed`. Consumer: **telemetry**.

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `PLATFORM_BUNDLE_FETCH_FAILED` | A hosted bundle could not be fetched | "Could not refresh content; still using the installed version" | Yes |
| `PLATFORM_BUNDLE_INTEGRITY_FAILED` | Hash mismatch or a bundle failing load-time validation (`MAP_LAYOUT_MISSING`, I8) | Same message; the snapshot or installed set stays | Yes, never tolerated |
| `PLATFORM_SNAPSHOT_REFUSED` | The offline snapshot shipped in the build fails a load-time check (manifest completeness, format major, L0) and no other set is installed | "The map could not be loaded from this copy of the app; reinstall the app to fix it." No map is rendered | No — needs a new build |
| `PLATFORM_STATE_WRITE_FAILED` | The JSON write failed | Banner from the calling domain | Yes — retried |
| `PLATFORM_STATE_UNREADABLE` | Migration failed | "Earlier progress could not be read; it has been kept" | Yes — file retained |
| `PLATFORM_SYNC_UNAVAILABLE` | Not signed in, or iCloud errored | Nothing (silent); status in Settings | Yes |

## Invariants enforced here

- **I2** — nothing here needs a model or the network; a test runs the three doors with connectivity and
  iCloud both absent.
- **I5** — `CapabilityFacts` and file paths are typed device-local with no path into a telemetry batch;
  only `AssetVersion` and app version cross that boundary, asserted on the serialised batch. Sync carries
  the `StudentState` document only — which has no identifying field — under Apple's identity, not ours.
- **I14** — this domain reads and writes `StudentState` as an opaque `Codable` value from `Core` and merges
  via a `Core` function; it defines no state shape and no transition.
- **D36** — the only outbound requests are GETs to the static host, iCloud, and telemetry's single POST; a
  network test asserts no other host.

Seams: platform ↔ all (bundles, persistence); platform → runtime-tiers (capability facts); platform →
telemetry (connectivity, versions).

## Open questions

**Q1 — iCloud Drive container or CloudKit asset for the state document?** **Default:** decided at M3 per
v2.4 §1; the Demo persists locally only. **Trade-off:** a document container is one file with
OS-managed conflicts and no schema; CloudKit gives explicit records and conflict hooks at more code.
**Ratified 2026-09-09:** default accepted.

**Q2 — Content update policy.** **Default:** background fetch, atomic swap at next launch, never mid-run.
**Trade-off:** the graph never changes under a running expedition; a student who never relaunches sits on
a stale bundle indefinitely (rare on a phone).
**Ratified 2026-09-09:** default accepted.

**Q3 — State merge on sync conflict.** **Default:** per-node merge in `Core`: the higher mastery wins
(`cleared` > `blocked` > `fog`), `correct_count` takes the max, `last_probe`/`next_due` take the latest;
logs are unioned by entry id; the marker takes the latest write. **Trade-off:** never loses earned
progress; can resurrect a `blocked` mark the other device already cleared, corrected by the next probe.
**Ratified 2026-09-09:** default accepted.

**Q4 — What happens to state if the student deletes the app?** **Default:** the local file goes with it;
the iCloud copy, if any, restores on reinstall; no export feature in MVP. **Trade-off:** matches platform
convention; an unsynced student loses progress, which is the A5 trade the owner accepted with D36.
**Ratified 2026-09-09:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b, PWA). Open questions ratified (see docs/plans/phase3b-open-questions.md). |
| 2026-09-09 | Rewritten for native iOS (D31–D36): no service worker, no IndexedDB, no environment gate, no Pyodide; JSON state + iCloud sync; offline snapshot. v1 Q1–Q4 retired with the PWA; new Q1–Q4 pending owner ratification. |

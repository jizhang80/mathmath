# Domain — platform

## Purpose

The PWA shell every other domain runs inside: environment detection and the unsupported page, asset
loading and versioning, IndexedDB persistence, service-worker caching, offline behaviour. It owns the
**platform↔all** seam — no other domain touches the network, the cache or IndexedDB directly. Milestone:
**M3** (decomposition row 10). Static hosting, no server-side application logic (brief §4.3); the sole
write path belongs to **telemetry**.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Student, Parent | Load the app, see the environment result, retry an update, work offline | Choose bundle versions; bypass an integrity failure |
| Owner | Publish a bundle set, read the M4′ load measurement, test the unsupported page | Push an update to a running client (no server logic) |
| System | Run `EnvironmentCheck`, fetch and cache assets, migrate the `Store`, swap versions atomically | Send anything off-device (only **telemetry** may, under consent) |

**runtime-tiers** owns the model adapters; this domain only reports WebGPU and free-space facts to it. The
**Local model** and **Generation model** have no role of their own here.

## Core entities

**AssetManifest** — the bundles a build requires and the `AssetVersion` of each: Spine
(**curriculum-spine**), Graph (**concept-graph**), LearningObject (**learning-objects**), and the
Pyodide + SymPy runtime payload. It defines what "installed" means; a partial manifest is never activated.

**AssetVersion** — an immutable version id plus a content hash, checked on fetch so a truncated or
substituted bundle fails closed. Versions travel into `TelemetryEvent` (**telemetry**): they describe the
build, not the device, which is why they are permitted there.

**EnvironmentCheck** — the D8 baseline evaluated on first load, recording per criterion *pass*, *fail* or
*undetectable*. The third state is the honest part. Browser brand and major version (UA Client Hints) and
desktop-vs-mobile (UA-CH `mobile`) are reliable, and §9 excludes mobile anyway; WebGPU is reliable via a
`navigator.gpu` adapter request and is the only hard Tier 1 gate. The other three are not:
`navigator.deviceMemory` is quantised and capped at 8, so **≥ 16 GB RAM cannot be confirmed**;
`navigator.storage.estimate()` gives an approximate origin quota, not disk free space, so **≥ 20 GB free is
approximate**; **Chromebook is undetectable** in-browser. Instrument and exclusions per C3: RAM and
Chromebook are excluded from the verdict, and a report naming no undetectable criterion is wrong, not
clean. The storage figure only warns near Chrome's 10 GB free-space threshold, below which the on-device
model is evicted [SOURCED: brief §4.3, developer.chrome.com/docs/ai/prompt-api]. Results stay on the
device: they are the fingerprint material I5 forbids sending.

**Store** — the IndexedDB layout: *assets* (payloads keyed by `AssetVersion`), *session records*
(`SessionRecord`, **tutoring-session**, read by **parent-view**), *consent* (`ConsentState`,
**telemetry**), *tier capability cache* (`TierCapability`, **runtime-tiers**). Each carries a schema
version; this domain owns migration, not the entity shapes. Footprint: app assets < 100 MB [ESTIMATE:
brief §4.3] within ≈ 6–7 GB once model payloads count [SOURCED: brief §4.3].

**ServiceWorker state** — installed / waiting / active, plus the cache strategy: shell and bundles are
cache-first, being immutable and keyed by `AssetVersion`; nothing is network-first, and a new worker never
takes over a running session.

## Workflows

### W1 — First load
**Pre:** no `EnvironmentCheck` result for this app version. **Steps:** 1. Run every criterion. 2. If WebGPU
fails or storage is unavailable, render the unsupported page listing the §9 queued items and stop.
3. Otherwise proceed, warning on any *fail* that does not break Tier 0 (Q1). 4. Persist the result locally.
Tier 0; no model is consulted about the environment. **Post:** `platform.env_checked` emitted.

### W2 — Asset install or update
**Pre:** an `AssetManifest` differs from the installed one. **Steps:** 1. Fetch each missing bundle and
verify its hash; on mismatch abort the update, keeping the previous manifest active. 2. Write new bundles
alongside the old, swap atomically at next launch (Q2), delete the superseded ones. Tier 0. **Post:**
exactly one manifest active; `platform.assets_updated` emitted.

### W3 — Pyodide + SymPy load
**Pre:** the app proceeded past W1. **Steps:** 1. Fetch the runtime payload per the manifest, or read it
from cache. 2. Hand it to **verification**, which owns readiness and declares when CAS checking is
available; this domain owns fetching and caching only. 3. Record the load measurement for the M4′
first-load experience (brief §8 M4′, §11) — payload size unquantified [ESTIMATE: measured at M4′]. Tier 0.
**Post:** payload cached; `platform.runtime_ready` emitted.

### W4 — Store migration across bundle versions
**Pre:** a store's schema version is older than the build expects. **Steps:** 1. Open at the new version.
2. Run migrations in order, one transaction per store. 3. On failure roll back, leaving old data readable;
unmigratable records are kept, not deleted, and surface as `PARENT_RECORD_UNREADABLE` (**parent-view**).
Tier 0. **Post:** `platform.store_migrated` emitted.

### W5 — Offline operation
**Pre:** the app is installed and the network is unavailable. **Steps:** 1. Serve shell and bundles from
cache. 2. Run the whole Tier 0 flow — nothing in the §7 contract needs the network. 3. Buffer telemetry
locally. **Post:** the session completes offline; `platform.offline_changed` emitted on transition.

## UI surfaces

- `/unsupported` — the D8 failure page listing the §9 queued items (W1).
- `/settings/storage` — installed versions, storage use, update state (W2). Confirmed in Phase 4.

## Notifications produced

- `platform.env_checked` — per-criterion verdict including *undetectable*. Consumers: **runtime-tiers**,
  **tutoring-session**.
- `platform.assets_updated` — new manifest versions. Consumers: **curriculum-spine**, **concept-graph**,
  **learning-objects**.
- `platform.runtime_ready` — the Pyodide payload is cached. Consumer: **verification**.
- `platform.store_migrated` — store and new schema version. Consumers: all store users.
- `platform.offline_changed` / `platform.quota_low` — connectivity; storage near eviction. Consumers:
  **telemetry**, **tutoring-session**, **runtime-tiers**.

## Errors produced

- `PLATFORM_ENV_UNSUPPORTED` — a criterion breaking Tier 1 or the store failed. User sees `/unsupported`
  with the §9 list. Not recoverable in-app.
- `PLATFORM_ASSET_FETCH_FAILED` — a bundle could not be fetched. User sees "could not update; still using
  the installed version". Recoverable; the previous manifest stays active.
- `PLATFORM_ASSET_INTEGRITY_FAILED` — a content hash mismatched; the partial download is discarded, same
  user-visible outcome. Recoverable, never tolerated.
- `PLATFORM_QUOTA_EXCEEDED` — a write failed for space. User sees a message naming what to free.
  Recoverable.
- `PLATFORM_RUNTIME_LOAD_FAILED` — the Pyodide payload failed to load. User sees that step checking is
  unavailable; **verification** decides what the session may still do. Recoverable by retry.

## Invariants enforced here

- **I2** — W1 blocks only on conditions that break Tier 0 or the store; a WebGPU failure degrades the app
  to Tier 0 rather than ending it, and a test asserts the §7 flow completes with WebGPU and the network
  both absent.
- **I5** — `EnvironmentCheck` output is typed device-local with no path to `AggregateBatch`
  (**telemetry**); only `AssetVersion` and app version cross that boundary, enforced by a test on the
  serialised batch.
- **I11** — the environment report states instrument per criterion, lists RAM and Chromebook as excluded
  (C3), and asserts no untagged number.

## Open questions

**Q1 — Hard-block or warn on a failed check?** Default: warn and proceed, except where WebGPU or storage
would break Tier 1 or the store — Tier 0 still works (I2).
Trade-off: warning maximises reach, but a machine quietly missing D8 gives slow first impressions the owner
cannot tell from defects.
**Ratified 2026-09-08:** default accepted.

**Q2 — Asset update policy.** Default: background download, atomic swap at next launch.
Trade-off: the graph never changes under a running session, but a student can sit on a stale bundle
indefinitely if the tab is never closed.
**Ratified 2026-09-08:** default accepted.

**Q3 — Storage quota handling.** Default: request persistent storage on first successful load; on
`PLATFORM_QUOTA_EXCEEDED` keep session records and consent, dropping cached bundles first.
Trade-off: this preserves the parent view and L3 evidence, but a dropped bundle needs a re-download an
offline user cannot perform.
**Ratified 2026-09-08:** default accepted.

**Q4 — Self-host Pyodide or fetch from a CDN?** Default: self-host, for offline.
Trade-off: self-hosting keeps the offline promise and removes a third party from the load path, at the cost
of bundle size on the static host and of shared CDN cache hits.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |

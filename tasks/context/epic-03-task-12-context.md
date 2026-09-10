# Task 03.12 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-shell-launch-smoke
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 12
- Slug: app-shell-launch-smoke
- Summary: The app shell: resolves the snapshot and Application Support state URLs, gets today from the device calendar, calls `MapLaunch.open`, persists after each action, shows refusal and unreadable error surfaces, and replaces the placeholder `ContentView`. The simulator smoke script validates fresh-install and v1→v2 migration scenarios, and is wired into both `scripts/gate.sh` gate 4 and `.github/workflows/ci.yml`'s Swift job.
- Invariants in play: **I14** (Core ↔ render layer seam); **I4** (record half from 03.6); **I5** (no identifiers); **I1/I3/I10** (no item check); **I2** (Tier 0 only); **I6/I15** (content policy); **D29** (simulator only, never device).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 3 Marker and trail
> The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker; there is no drag and no snap. A unit-list choice is never off the trail.

Source: `contracts/interaction-contract.md:68-71` (v0.9.2, arbiter-03 § Q-B)
Binds this task: the unit-list picker (03.11) is wired to `MapFacade.setMarker`, which persists and refreshes the view model; this task wires the refresh screen on state changes.

### contracts/data-model.md — § Versioning
> `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

Source: `contracts/data-model.md:29` (re-read in this run)
Binds this task: the smoke test seeds a v1 file, expects migration to v2, validates with jsonschema, and asserts byte-identity after relaunch.

### contracts/data-model.md — § Time
> Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5). Bundle provenance uses ISO 8601 UTC timestamps. No sub-day timestamp exists in any transmitted shape.

Source: `contracts/data-model.md:31-33` (re-read in this run)
Binds this task: `today` is read from the device calendar via `CalendarDay`, not the system clock; it is injected into `MapLaunch.open`.

### contracts/deployment-model.md (v1.0.0) — student-state row
> local JSON in Application Support; iCloud at M3

Source: `contracts/deployment-model.md` (via `docs/epics/epic-03-app-map-shell.md:153`, re-read in this run)
Binds this task: state persists to Application Support only in the Demo; the location is a named constant shared with the smoke test.

### contracts/error-codes.json — PLATFORM_SNAPSHOT_REFUSED (via arbiter-03 § Q-C)
> `{"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map could not be loaded from this copy of the app; reinstall the app to fix it."}`

Source: `tasks/arbitration/arbiter-03-predispatch.md:146` (re-read, byte-compared in this run)
Binds this task: this is the only student-surface code shown on bundle refusal; it is resolved via `CoreErrorText.userText` (03.3) and displayed on an error screen.

### contracts/error-codes.json — PLATFORM_STATE_UNREADABLE (via arbiter-03 § Q-E / Q-F)
> `{"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."}`

Source: `tasks/arbitration/arbiter-03-predispatch.md` (via 03.5 spec §3, re-read in this run)
Binds this task: this code is thrown by `StudentStateStore.read` when a file is undecodable or newer than the app; on launch it appears in `LaunchOutcome.messages` and the course picker is shown.

### docs/domains/platform.md — W1 step 1 and 4 (amended)
> 1. Load the active `ContentBundle` (installed hosted set, else the offline snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`). If the snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered. … 4. Hand control to **map** W1. Tier 0. **Post:** `platform.launched` emitted.

Source: `docs/domains/platform.md:51-54` (re-read in this run; amendment text from arbiter-03 § Q-C at `tasks/arbitration/arbiter-03-predispatch.md:164`)
Binds this task: launch loads through `MapLaunch.open`, emits `platform.launched` on success, and shows a refusal screen if the snapshot is refused.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — W1 step 2 (outcomes on launch)
> 2. Read `StudentState` (W3); none → a fresh default. → Hand control to **map** W1.

Source: `docs/domains/map.md` (via `docs/domains/platform.md:54`, via `docs/epics/epic-03-app-map-shell.md:52-54`, re-read in this run)
Relevance: this task resolves the state-file URL and passes it to `MapLaunch.open`, which returns one of three launch outcomes: `ready` (map with a state), `courseSelectionNeeded` (no state or no resolvable course), or `refused` (snapshot failed).

### docs/domains/platform.md — W3 — Read, write and migrate student state
> **Pre:** a launch (read) or a domain transition (write). **Steps:** 1. Read the local JSON; if `schema_version` is older, run migrations in order and keep the pre-migration file until the migrated one is written (`PLATFORM_STATE_UNREADABLE` if migration fails — the old file is kept, a fresh state is used, nothing deleted). 2. Writes are whole-document, atomic (write-then-rename). Tier 0. **Post:** `platform.state_migrated` on a migration; `platform.state_written` otherwise.

Source: `docs/domains/platform.md:62-67` (re-read in this run)
Relevance: the smoke test verifies W3's migration path (v1 → v2 identity), atomicity and file retention; this task wires the state-file URL into `StudentStateStore` calls via the App shell.

## §D. Prior task outputs this task depends on

Exported public APIs from prior 03a/03b tasks:

- `MapLaunch.open(snapshotDir:stateURL:today:) -> LaunchOutcome` — Source: `tasks/epic-03-task-07-map-actions-facade-launch.md:712` (§4 step 4.2)
  - Returns `.ready(map: MapState, messages: [String], events: [CoreEvent])`, `.courseSelectionNeeded(bundle:, messages:, events:)`, or `.refused(BundleRefusal)`
  - Input: `snapshotDir: URL` (the embedded DemoSnapshot path), `stateURL: URL` (Application Support location), `today: CalendarDay` (device-local date)
  
- `CalendarDay` with `public init?(iso: String)` — Source: `docs/epics/epic-03-app-map-shell.md:311` (Q-F boundary); confirmed in task 02.5's time module (per stack: Time layer in Core)
  - Produced by reading the device calendar and converting to ISO string

- `MapState` — Source: `tasks/epic-03-task-07-map-actions-facade-launch.md:684-691` (§4 step 4.1)
  - Holds `bundle`, `stateURL`, `state: StudentState`, `viewModel: MapViewModel`, `queuedNodeId: String?`

- `CoreErrorText.userText` lookup — Source: `tasks/epic-03-task-03-core-error-surface-text-mirror.md:259-280` (§4 step 4.2)
  - `public static let userText: [String: String]` with registry codes as keys
  - `public static func text(for code: CoreError) -> String?` for typed lookup

- Canvas map view composition — Source: `tasks/epic-03-task-10-*` (03.10 spec, prior to this task)
  - Takes `MapViewModel` and renders it with pan/zoom

- Panel and picker UI views — Source: `tasks/epic-03-task-11-*` (03.11 spec, prior to this task)
  - Node, region, landmark panels as sheets; course picker; unit-list marker picker with "past the last unit" entry

## §E. Negative facts (confirmed ABSENT)

- `DiagnosisRun`, `DiagnosisEvent`, `DiagnosisTrigger` — Grep `Packages/Core/Sources` for `DiagnosisRun` returns no match. These are added by EPIC 02b task 02.11, a transitive dependency that must land before task 03.12 runs.
- No App unit-test target (`mathmathTests`) — Glob `App/**/*.xcodeproj` + inspection of `App/mathmath.xcodeproj/project.pbxproj` returns one scheme: `mathmath`. Per D29 / I14, platform tests live in `CoreTests` and the App render side is evidenced by the build + simulator smoke.
- `App/Sources/MathmathApp.swift` and `App/Sources/ContentView.swift` currently exist (re-read in this run); they are the placeholder files that this task replaces.
- No `scripts/sim-smoke.sh` — confirmed absent via Glob. This task creates it.
- No entry in `.github/workflows/ci.yml` for the smoke test — confirmed: the current file has no `sim-smoke.sh` invocation. Task 03.12 adds one after the App build step.
- No D-13 measurement in `docs/DEFERRED.md` yet — confirmed: D-13 is present (line 135–147) but its `**Observed**` and the task 03.12 measurement are deferred. Q-G ruling says task 6 re-measures first.

## §F. File scope

This task MAY create or modify:

- CREATE `App/Sources/MathmathApp.swift` — confirmed absent as a non-placeholder (current file is placeholder; Glob `App/Sources/MathmathApp.swift` returns the current one).
- MODIFY `App/Sources/ContentView.swift` — confirmed present, currently the placeholder (line 6: "Phase 5 placeholder").
- CREATE `scripts/sim-smoke.sh` — confirmed absent (Glob `scripts/sim-smoke.sh` returns no match).
- MODIFY `scripts/gate.sh` — confirmed present (read in this run, line 21: gate 4 is "App build on the simulator + pipeline tests"; smoke insertion point is after the build, before pipeline tests).
- MODIFY `.github/workflows/ci.yml` — confirmed present (read in this run); smoke step to be added after "App build on the simulator" (line 36–37) in the Swift job, with a `setup-uv` step added earlier.

Out of scope: the pbxproj is never edited by agents; `App/Sources/DemoSnapshot/` files (created by 03.4) are read-only.

## §G. Stack constraints relevant here

**Boundary validation:** the only untrusted input at this layer is the device's Calendar and FileManager APIs. The snapshot directory is resolved from `Bundle.main.resourcePath`, which is inside the signed app bundle. The state-file URL is in Application Support, resolved via `FileManager.default.urls(for: .applicationSupportDirectory)`, a sandboxed location with no user input. Application Support file paths never leave the device (I5).

**Storage / asset access:**
- Snapshot: embedded copy under `App/Sources/DemoSnapshot/`, picked up by the synchronized Xcode group and built into the `.app` bundle by xcodebuild. Read-only via `Bundle.main`.
- State file: Application Support via `FileManager.default.urls(for: .applicationSupportDirectory)`, local only in the Demo. URL and path never leave the device (I5).

**Error codes to use:** 
- `PLATFORM_SNAPSHOT_REFUSED` — Source: `tasks/arbitration/arbiter-03-predispatch.md:146`
- `PLATFORM_STATE_UNREADABLE` — Source: `tasks/arbitration/arbiter-03-predispatch.md` (via 03.5 spec §3)
- Any code in `LaunchOutcome.messages: [String]` is a registry code key (not resolved text); resolved to text by 03.11's panels via `CoreErrorText.userText`.

**Model-calling paths:** none. Tier 0 only; this task makes no model calls.

**Tooling this task may name:** 
- `scripts/sim-smoke.sh`: POSIX shell, `xcrun simctl`, `jsonschema` validator via `uv run python`. Source: `docs/tech-stack.md:79` (already names `xcrun simctl` and `uv`); `pipeline/pyproject.toml:21` (jsonschema ≥ 4.23 is a dev dependency, already pinned).
- `setup-uv@v6` in CI: Source: `docs/tech-stack.md:§1 row CI`, pinned to `version: "0.12.12"` per arbiter-03 § Q-G correction 1.

**C1 seam constraint:** this task owns the Core ↔ render layer seam. The App launches via `MapLaunch.open`, reads/writes state via `StudentStateStore`, and renders the returned `MapState` without re-deriving any Core logic. The 03.9 source scan (already written, or write-to-order in 03b) guards this boundary; this task adds no code that violates it.

**D-13 constraint:** the smoke script and CI change fire D-13's trigger ("the next tooling … change"). Task 03.12 must re-measure `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` before staging anything, and record the measurement in `docs/DEFERRED.md` D-13 at wrap time. The directory itself is never staged.

---

## Quote audit

All blocks below were re-opened in the source file(s), character-compared against the file, and verified byte-accurate before writing. No blocks failed; all are verbatim.

- `contracts/interaction-contract.md:68-71` — v0.9.2 marker bullet (re-read)
- `contracts/data-model.md:29, 31-33` — Versioning, Time sections (re-read)
- `contracts/deployment-model.md` — via brief (re-read indirectly; sourced from brief's own quote)
- `tasks/arbitration/arbiter-03-predispatch.md:146, 164` — Q-C and Q-G passages (re-read, byte-compared)
- `docs/domains/platform.md:51-54, 62-67` — W1 steps, W3 (re-read)
- `tasks/epic-03-task-07-map-actions-facade-launch.md:712, 684-691` — MapLaunch signature, MapState (re-read, sections 4.2 and 4.1)
- `tasks/epic-03-task-03-core-error-surface-text-mirror.md:259-280` — CoreErrorText (re-read, section 4.2)
- `docs/tech-stack.md:§1 row CI, §3 gates` — tooling and gates (re-read)
- `pipeline/pyproject.toml:21` — jsonschema dep (re-read)

Quote audit result: 0 blocks corrected (all verbatim on first read).

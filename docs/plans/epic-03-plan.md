# EPIC 03 plan (planner output)

Brief: `docs/epics/epic-03-app-map-shell.md` (amended for `tasks/arbitration/arbiter-03-predispatch.md`). The
planner found the EPIC over the 8-task cap (11 work tasks + 2 wraps) and split it at the brief's own §8 seam
without changing scope. The two tasks beyond the brief's eight are the ones its own acceptance items require:
the Q-C registry registration, and the Core mirror of registered user text (§4 item 10).

- **03a — Map core:** 03.1–03.8 (wrap 03.8), branch `epic-03a-map-core`.
- **03b — Map app:** 03.9–03.13 (wrap 03.13), branch `epic-03b-map-app`.
- **Seam between them:** the map-actions façade and launch entry point (03.7). 03b calls only 03.7's entry
  points, and 03.9's source scan enforces that.

EPIC 03 starts only after EPIC 02b is merged: it consumes `DiagnosisRun.open` (02.11, step-wise API per
`tasks/arbitration/arbiter-02-11-stepwise-api.md`) and data-model v1.4.0 (02.9).

| Id | Sub | Slug | Kind | Depends | Risk | C1 seam |
|---|---|---|---|---|---|---|
| 03.1 | a | contract-interaction-marker-unit-list | contract | — | seam | — |
| 03.2 | a | contract-error-codes-snapshot-refused | contract | — | seam | — |
| 03.3 | a | core-error-surface-text-mirror | impl | 03.2 | seam | — |
| 03.4 | a | bundle-loader-snapshot-seam | impl | 03.3 | seam | bundle loader ↔ Core validation |
| 03.5 | a | student-state-store | impl | 03.3 | seam | — |
| 03.6 | a | map-view-model | impl | — | seam | — |
| 03.7 | a | map-actions-facade-launch | impl | 03.1, 03.4, 03.5, 03.6 | seam | — |
| 03.8 | a | epic-03a-wrap | wrap | 03.1–03.7 | mechanical | — |
| 03.9 | b | app-sources-i14-scan | impl | 03.8 | seam | — (guard for 03.12) |
| 03.10 | b | app-map-canvas | impl | 03.9 | mechanical | — |
| 03.11 | b | app-panels-pickers-handoff | impl | 03.9 | seam | — |
| 03.12 | b | app-shell-launch-smoke | impl | 03.10, 03.11 | seam | Core ↔ render layer (I14) |
| 03.13 | b | epic-03b-wrap | wrap | all | mechanical | — |

## Task scopes

**03.1:** interaction-contract v0.9.1 → v0.9.2. Replace the marker-drag item in § Finalization owed with the
Q-B ruling: in the Demo the marker is set only from the unit list (D45), and "past the last unit" is an
explicit last entry. The other two finalization items stay for EPIC 04. It also lands the map.md W5 edit and
its error row, and a DEFERRED entry for drag. Files: `contracts/interaction-contract.md`, `docs/DEFERRED.md`,
and `docs/domains/map.md` (W5 and the error row, per the ruling).

**03.2:** registry entry `PLATFORM_SNAPSHOT_REFUSED` (Q-C: `recoverable: false`, surface `student`, text as
ruled) plus its `docs/domains/platform.md` row and the W1 sentence. The registration is additive (no version
bump). Files: `contracts/error-codes.json`, `docs/domains/platform.md`.

**03.3:** `CoreError` gains `PLATFORM_STATE_UNREADABLE`, `PLATFORM_STATE_WRITE_FAILED` and
`PLATFORM_SNAPSHOT_REFUSED`. A Core `userText` table mirrors every student-surface code's registered text
(nil for internal and owner codes). It gets a parity test against `contracts/error-codes.json` and a planted
mismatch as negative control. This is the only task in the EPIC that writes `CoreError.swift`. Files:
`Packages/Core/Sources/Core/CoreError.swift`, `Packages/Core/Sources/Core/CoreErrorText.swift`,
`Packages/Core/Tests/CoreTests/ErrorUserTextParityTests.swift`.

**03.4:** `BundleLoader.load(from:)` in Core does BundleIO.read, then the format-major check, then L0, and
returns the bundle plus its report or a typed refusal. It reuses L0Checker's format-major check through a
minimal helper extraction, so there is exactly one implementation. Decode failures map to
`PLATFORM_BUNDLE_INTEGRITY_FAILED`. The snapshot is embedded as a copy under `App/Sources/DemoSnapshot/`
(the synchronized folder, so the pbxproj is not edited), with a mandatory byte-identity test against
`data/demo` (empty set = FAIL). This task owns the C1 seam loader ↔ validation, running the same entry point
over the real `data/demo` and over the embedded copy.

**03.5:** `StudentStateStore` in Core over a URL the caller supplies:
- `read` returns absent, loaded (with `migratedFrom` if migrated), or unreadable (the file is kept);
- the 1→2 migration is an identity and keeps the pre-migration file until the migrated write succeeds;
- writes are atomic, whole-document, through `CoreCoding`;
- `PLATFORM_STATE_UNREADABLE` covers an undecodable file or a newer schema, with the file kept byte for byte;
- `PLATFORM_STATE_WRITE_FAILED` covers a failed write.

When no file exists, the result is `absent` (arbiter Q-E): the store writes nothing and course selection
builds the first state.

**03.6:** `MapViewModel` in Core is a pure derivation from (bundle, StudentState, today). It carries:
- region tints and pure-fog horizon regions;
- one river per edge;
- a NodeView per node, with fog level, due ring, upstream flag and the single offered action;
- solid course segments and a dashed extension;
- the position indicator and the landmark;
- the zoom-dependent label set and the trail-first focus frame (D44).

It does no layout, no I/O and no clock read. Tests cover I4's record half and a W6 re-derivation over real
transitions, including a real confirmed diagnosis through 02.11's step-wise API.

**03.7:** the map-actions façade plus `MapLaunch.open(snapshotDir:stateURL:today:)`. Launch runs load (03.4),
then read (03.5), then W7 reconciliation, then derive (03.6). The façade covers:
- panel content, with codes paired with `official_url` and landmarks with `source_url`, never Ministry prose;
- `selectCourse`, which builds and saves the first state (Q-E);
- `setMarker`, from a unit or past the last unit, which persists the state;
- `include`, an in-memory one-node queue (Q-D);
- `unitExpedition`, which calls `Expedition.compose(unitExpeditionUnitId:)`;
- `checkHere`, which calls `DiagnosisRun.open(... .mapCheckHere, levelBudget: 1)`.

It never calls later diagnosis steps or `ExpeditionRun`. Core decides the message list (Q-A): the load-path
marker reset is silent.

**03.8:** 03a wrap. Record the Q-H DEFERRED entry (embedded-snapshot hash check; trigger EPIC 10). Never
stage the D-13 directory.

**03.9:** a Core test scanning `App/Sources` for violations of I14, I5, I1/I10 and D24:
- no `StudentState(`;
- no direct Core transitions outside 03.7's allow-list;
- no reads of `data/` paths;
- no `URLSession` or `URLRequest`;
- no FoundationModels or third-party engines;
- no free-text answer, OCR or item-check path.

It has a planted-violation negative control per class. An empty scan fails.

**03.10:** SwiftUI `Canvas` map rendering a `MapViewModel`. The only view state is the pan/zoom transform,
and the initial camera comes from the model's focus frame. No SpriteKit.

**03.11:** node, region and landmark panels; the course picker; the unit-list marker picker with its "past
the last unit" entry; the three buttons, whose typed hand-off hooks lead to a placeholder destination that
EPIC 04 replaces. Error copy comes only from 03.3's `userText`.

**03.12:** the app shell:
- resolves the snapshot and Application Support URLs, and gets today from the device calendar;
- calls `MapLaunch`, persists after each action, and shows the refusal and unreadable surfaces;
- replaces the placeholder `ContentView`.

`scripts/sim-smoke.sh` (`xcrun simctl`) runs two scenarios, as the arbiter ruled for Q-G:
1. a fresh install writes no state file;
2. a seeded v1 file migrates to v2, validates with `jsonschema`, and survives a relaunch byte-identical.

It also `cmp`s the built `.app`'s snapshot against `data/demo`. The script is wired into both
`scripts/gate.sh` and `.github/workflows/ci.yml` (adding a `setup-uv` step to the Swift job). The D-13
directory is re-measured first. This task owns the C1 seam Core ↔ render.

**03.13:** 03b wrap. Close D-12 with the Q-A ruling. interaction-contract stays at v0.9.2; EPIC 04 bumps it
to v1.0.0.

## Planner notes kept for spec writers

- File ownership: only 03.3 writes `CoreError.swift`, and only 03.4 writes `L0Checker.swift`, as a minimal
  extraction. `DEFERRED.md` is written in order by 03.1, then 03.8, then 03.13. Only 03.12 writes
  `ContentView.swift` and `MathmathApp.swift`.
- Brief claims the planner found wrong:
  - removing a node's `position` key throws a decode error, because `Node.position` is non-optional; the
    `MAP_LAYOUT_MISSING` route is L0-7, position in polygon;
  - a landmark missing `source_url` is refused at decode, not at L0-10;
  - `ci.yml` does not call `gate.sh`.
- With no App test target, the render side of the C1 seam is evidenced only by the App build, the 03.9 scan
  and the simulator smoke. The 03.12 spec must name that exclusion (C3).
- `jsonschema` (Draft202012Validator) is already a pipeline dev dependency, used by `test_contracts.py`. The
  arbiter's Q-G ruling confirms it is allowed.
- Glossary: never use "session", "start marker", "cursor", "profile" or "save" in new identifiers or copy.
  `docs/domains/map.md` still says "start marker"/"StartMarker" and Q2's "five unpopulated" regions; both are
  out of scope and reported only.

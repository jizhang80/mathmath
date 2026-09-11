# EPIC 03: App — Map (Door C) + shell

> Status: brief authored 2026-09-10 by epic-scoper; amended 2026-09-10 by brief-amender with the pre-dispatch
> arbiter rulings (Amendment 03.00.1). Owner decides dispatch; planner decomposes.

## 1. EPIC id, title, category
EPIC 03 — App: Map (Door C) + shell. Category: Feature.

## 2. Goal & scope
Today the App is a placeholder: `App/Sources/ContentView.swift` shows a title, the data-format version and one
SwiftMath label. `Core` can decode, validate and lay out a bundle and run the Door B machines (02a). After this
EPIC the App launches on the simulator from the bundled demo snapshot. It validates that snapshot with L0 at
load and persists `StudentState` as one atomic JSON document in Application Support. It opens on the student's
trail, drawn over the continent with fog, and lets the student pan, zoom, open the panels, set the
course-progress marker from the unit list, and request "Check me here", "Include" and "Unit expedition". Each
of those actions is a `Core` call.

**Dominant domain: map** (W1–W6, `MapViewModel`, the node, region and landmark panels). **Secondary domain:
platform**, the Demo slice of W1 (launch) and W3 (read, write, migrate), plus the load half of expedition W7.
In scope, cut at the domain docs' own seams:

- **Launch: load and validate the snapshot** (platform W1 steps 1, 2 and 4; Demo = bundled data only, no
  network). The snapshot is read through the existing `BundleIO.read`, which checks manifest completeness. It
  is then checked for a `format_version` major equal to `CoreInfo.dataFormatVersion` (`contracts/data-model.md` §
  Versioning: "the app refuses a bundle whose major differs from its own") and validated by the existing L0
  `validate` (I8). A refused bundle is never rendered (map § Invariants: "a violation refuses the bundle rather
  than rendering a broken map"). The snapshot is the `data/demo` bundle, embedded in the App build **as a copy
  under `App/Sources`** that the synchronized group picks up as resources. A regenerating script, not a hand
  edit, keeps the copy in sync, and a byte-identity test guards it (arbiter-03 § Q-F, "Embedding the
  snapshot"). The `Core` launch entry returns one of three outcomes (arbiter-03 § Q-E): `ready(bundle, state,
  viewModel, messages)`, `courseSelectionNeeded(bundle, messages)`, or `refused(code)`. A refused snapshot
  yields `PLATFORM_SNAPSHOT_REFUSED`, with the underlying code kept as internal detail (arbiter-03 § Q-C).
- **StudentState persistence** (platform W3, Demo slice). Read at launch. No file → launch returns
  `courseSelectionNeeded` and **writes nothing**. Choosing a course creates the first state and persists it
  (arbiter-03 § Q-E: no valid `StudentState` exists before a course is chosen, because `marker` is required).
  An older `schema_version` → forward migration, with the pre-migration file kept until the migrated one is
  written (1 → 2 is the identity, data-model § StudentState). A failed migration or unreadable file →
  `PLATFORM_STATE_UNREADABLE`: the old file is kept, launch returns `courseSelectionNeeded`, the fresh state is
  created when a course is chosen, and nothing is deleted. Writes are whole-document and atomic
  (write-then-rename) after every state-changing action. That sequencing lives in a `Core` session type that
  writes to an injected URL (arbiter-03 § Q-F). Location: Application Support, local only. iCloud is EPIC 10.
- **Load-time reconciliation** (expedition W7, App half). The persisted state goes through the existing
  `MarkerTrail.reconcileMarker` / `reconcileNodeIds` (02a, task 02.5) before the map opens. Ruled in
  arbiter-03 § Q-A (option (a)):
  - no student text on this path;
  - `Core`, not the App, computes the student-message list, which is empty for `MAP_MARKER_OFF_TRAIL` here,
    and carries the code as internal diagnostics;
  - when no course in `syllabi[]` resolves in the bundle, `reconcileMarker` returns the unchanged stored marker,
    so launch returns `courseSelectionNeeded`;
  - reconciliation changes the in-memory state only; **load never writes the state file**.
- **`MapViewModel` in `Core`** (map § Core entities; `docs/tech-stack.md` §2 places "map (layout,
  `MapViewModel`)" in `Packages/Core`). This is a pure derivation from the bundle, `StudentState` and an
  injected `today`:
  - regions with a tint from the cleared fraction over trail nodes; empty regions are pure fog (map Q2);
  - rivers, following edge direction;
  - one `NodeView` per node, with a fog level (`fog` / `blocked` / `cleared`), a due ring (map Q1: fog never
    returns) and an upstream-of-marker flag;
  - trail segments, course segments solid and `extension` segments dashed (D47);
  - the position indicator (the glossary's "first uncleared trail node at or after the marker");
  - horizon labels, greyed and not tappable (map Q3), and the landmark;
  - the label set for a zoom level (map Q4);
  - the trail-first focus frame (D44, map W1 step 2: "the marker's unit and the next").
  `MapViewModel` does not exist today; this EPIC creates it.
- **Map actions façade in `Core`** (map W2–W5), every one a pure `Core` function returning a new value and the
  `CoreEvent`s it emits (`interaction-contract.md` §5 names):
  - node, region and landmark panel content;
  - the one action a node offers, chosen by its state (map W2 step 2);
  - **set marker** from the unit list → `MarkerTrail.setMarker` → trail regenerated → state persisted
    (`map.marker_moved`);
  - **course selection** into `syllabi[]`. It is needed because no state exists before the first course is
    chosen (arbiter-03 § Q-E). It builds and persists the first state, or replaces `syllabi` and the marker
    together on a later change (mastery kept);
  - **Include** → a queued node for the next `Expedition.compose(queuedNodeId:)` (map Q5). The queue is held in
    memory by the `Core` façade and not persisted (arbiter-03 § Q-D);
  - **Unit expedition** → `Expedition.compose(unitExpeditionUnitId:)` (D46);
  - **Check me here** → `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` with trigger `map_check_here`
    and the Demo budget of 1 (02b, task 02.11). The step-wise ruling keeps `open` unchanged as pure
    construction (`tasks/arbitration/arbiter-02-11-stepwise-api.md` § Ruling, finding 3).
  - W6: re-deriving the map from any new `StudentState`.
- **Render layer in `App/Sources`**: the SwiftUI `Canvas` map drawing the `MapViewModel`; pan and zoom; the
  trail-first initial camera; the node, region and landmark panels as sheets (map § UI surfaces); the unit-list
  marker picker; the three action buttons. The layer computes nothing (I14).
- **Hand-offs to EPIC 04 (the seam).** For "Check me here", "Include" and "Unit expedition", EPIC 03 ships the
  map action, its `Core` call and the typed value that call returns: a `DiagnosisEvent`, a `ComposeResult`, or
  the queued node. EPIC 03 also ships the navigation hook that hands that value on. **EPIC 04 owns every screen
  these values open**: the expedition item view, the hypothesis card, probe, remediation and summary. Between
  the two EPICs, the hook may land on a placeholder destination that EPIC 04 replaces. EPIC 03 never calls
  `DiagnosisRun.run` or `ExpeditionRun.*` from the App, nor the step functions `DiagnosisRun.start` /
  `decideProbe` / `answerProbeItem` / `decideFurtherLevel` (arbiter-02-11-stepwise-api § Ruling 1).

**This EPIC builds on EPICs 01 and 02 and re-creates nothing.** These exist in `Packages/Core/Sources/Core/`:
- `BundleIO`, `L0Checker` / `GraphIndex` and `LayoutEngine` (positions arrive precomputed in `nodes.json`;
  nothing is laid out at runtime — glossary: "force simulation" at runtime is banned);
- `StudentState` and its types, `CalendarDay`, `MarkerTrail` (`generateTrail`, `setMarker`, `defaultMarker`,
  `reconcileMarker`, `reconcileNodeIds`);
- `Expedition.compose` / `selectItem`, `ExpeditionRun`, `MasteryTransitions`, `ItemChecker`;
- `CoreEvent` (every §5 name) and `CoreError`.

Not yet landed, and **named here as dependencies, not as existing code**: the 02b specs
`tasks/epic-02-task-09-contract-state-merge-rule.md` (data-model v1.4.0),
`tasks/epic-02-task-10-prerequisite-query-classify.md`, `tasks/epic-02-task-11-diagnosis-machine-seam.md`
(`DiagnosisTrigger.mapCheckHere`, `DiagnosisRun.open`, and the step-wise API ruled in
`tasks/arbitration/arbiter-02-11-stepwise-api.md`) and `tasks/epic-02-task-12-state-merge.md`.

**MANDATORY placement line:** milestone **Demo** (D26, hand-written `data/demo` as the snapshot). M3 behaviour
is the same with only the data replaced (EPIC 12). Layer **④ interaction**, Door C and the shell. Layers ①
(courses, units, `official_url`), ② (nodes, edges, regions, positions, trail) and ③ (landmarks) are read-only
inputs.

## 3. Contracts it must conform to
- `contracts/interaction-contract.md` (v0.9.1, discovery zone; **v0.9.2 after task 1**):
  - § 3 Marker and trail: `READ-ONLY`, apart from the v0.9.2 bullet below. `set_marker` regenerates the trail.
    The default marker is the first unit of the selected course. An off-trail marker returns
    `MAP_MARKER_OFF_TRAIL` with the default marker.
  - § 2 `compose` (queued node first, unit expedition): `READ-ONLY`; the parameters are called, not changed.
  - § 4 `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`, "budget 2 (Demo: 1)": `READ-ONLY`.
  - § 5 Notifications: `READ-ONLY`. The exact names for `map.opened`, `map.node_opened`, `map.region_opened`,
    `map.landmark_opened`, `map.marker_moved`, `map.check_here_requested`, `map.include_requested`,
    `map.unit_expedition_requested`, `platform.launched`, `platform.state_migrated` and
    `platform.state_written` are already `CoreEvent` cases.
  - § *Finalization owed by the Demo EPIC*, first item, "The unit-boundary snap for dragging the marker":
    **BUMP** (v0.9.2, patch). Task 1 applies the exact normative text of arbiter-03 § Q-B in a
    `contract(interaction-contract)` commit: the header line, a new § 3 bullet ("The marker is set only by
    choosing an entry from the selected course's unit list … there is no drag and no snap. A unit-list choice is
    never off the trail."), and the replacement Finalization paragraph. Cascade in the same task: the
    `docs/domains/map.md` § W5 step 1 sentence and the `MAP_MARKER_OFF_TRAIL` error row, both per arbiter-03 §
    Q-B, and a `docs/DEFERRED.md` entry "Marker drag with unit-boundary snap" (C6 template; trigger: Demo
    observations, `DEMO-BRIEF.md` § 7). The two other items (answer-card timing, summary tint deltas) and the
    v1.0.0 bump belong to EPIC 04.
- `contracts/data-model.md` (v1.3.0 today; **v1.4.0 once 02b's task 02.9 lands**):
  - § StudentState, including `past_last_unit` and `remediated`, the closed key set and `schema_version` 2 with
    the identity 1 → 2 migration: `READ-ONLY`.
  - § Versioning (format-major refusal; "`StudentState.schema_version` (integer) is migrated forward only
    (platform W3); older files are kept"): `READ-ONLY`.
  - § Time (calendar days, device-local): `READ-ONLY`. `today` is read from the device calendar in the App and
    injected into `Core`.
  - § Text: `READ-ONLY`. "LaTeX appears only in fields named `latex` or `prompt_latex`", so no map panel field
    carries LaTeX (see §7 item 3).
  - § StudentState merge (v1.4.0): `READ-ONLY`, not called in this EPIC (sync is EPIC 10).
  - Schemas `regions`, `nodes`, `edges`, `courses` (units, `expectations[].official_url`), `landmarks`
    (`source_url`, `position`) and `student-state`: `READ-ONLY`. No field is added.
- `contracts/graph-constraints.md` (v1.1.0): L0-1 … L0-10 run at app load through the one `Core` `validate`
  ("runtime contract test: `core-cli validate` (L0) on every bundle, in the pipeline build step and at app
  load", `contracts/README.md`): `READ-ONLY`. L0-T runs inside `setMarker` / `generateTrail`: `READ-ONLY`.
- `contracts/error-codes.md` + `error-codes.json` (v1.0.0): § Rules, including "Internal codes never reach a
  student surface; a `student` code always has a next action in its text." `READ-ONLY`, apart from **one additive
  registration** ruled in arbiter-03 § Q-C: `PLATFORM_SNAPSHOT_REFUSED` (`recoverable: false`, `surface:
  student`, `user_text`: "The map could not be loaded from this copy of the app; reinstall the app to fix it."),
  placed after `PLATFORM_BUNDLE_INTEGRITY_FAILED`. Task 1 lands it in a `contract(error-codes)` commit, together
  with its `docs/domains/platform.md` § Errors produced row and the platform § W1 step 1 sentence ("If the
  snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered."). This comes **before** task 2 adds
  the `CoreError` case. Additive registration needs no version bump but does need its domain-doc row.
- `contracts/deployment-model.md` (v1.0.0): the student-state row (local JSON in Application Support; iCloud at
  M3). **No network code of any kind in this EPIC** (Demo: bundled data only). The "Network allowlist for the
  app (asserted by a test, App EPIC)" is scheduled with hosting in EPIC 10 and is not moved forward here.
  Opening a landmark `source_url` or an `official_url` hands the URL to the system and makes no App-side
  request. `READ-ONLY`.
- `contracts/domain-glossary.md` (v1.0.0): Map, Region, Horizon, Node, Edge/river, Fog, Due, Trail / course
  segment / extension, Course-progress marker (never "start marker", "position" or "cursor"), Position
  indicator, Landmark, Layout / coordinates, Student state (never "profile", "progress file" or "save").
  `READ-ONLY`. The wrap-epic (f) banned-synonym grep applies to new identifiers **and to student-facing copy**
  in `App/Sources`.
- `contracts/content-policy.md`: panels show `paraphrase`, expectation codes and outbound links, never Ministry
  text (I6). A landmark is shown only with its `source_url` (I15). `READ-ONLY`.
- `contracts/telemetry.md`, `contracts/runtime-tiers.md`, `contracts/ai-usage.md`: no telemetry client and no
  model or adapter in this EPIC. Events are emitted in-process only; their telemetry consumer is EPIC 11.
  `READ-ONLY`.

**MANDATORY (R-6) brief-checklist line — startup-failure guard set.** The config- and registry-bearing inputs in
scope, each checked against `contracts/error-codes.json` v1.0.0:
- **Snapshot bundle at launch** (the bundle loader). A missing manifest file, or a format-major mismatch →
  `PLATFORM_BUNDLE_INTEGRITY_FAILED`. L0 failure → `GRAPH_L0_FAILED`, with the L0 report's rule ids. A node
  without coordinates → `MAP_LAYOUT_MISSING`. An unknown region → `MAP_REGION_UNKNOWN`. A landmark without a
  source → `MAP_LANDMARK_UNSOURCED`. **All registered**, and all already `CoreError` cases → `READ-ONLY`.
  **Caveat:** the registered `user_text` of `PLATFORM_BUNDLE_INTEGRITY_FAILED` is "Could not refresh content;
  still using the installed version." That sentence is false when the *snapshot itself* is refused, because the
  Demo has no other installed set. **Resolved** (arbiter-03 § Q-C): when the snapshot is the only set and is
  refused, the launch entry raises the new `student` code `PLATFORM_SNAPSHOT_REFUSED` and carries the codes
  above as internal detail, which is never shown. Task 2 adds `case platformSnapshotRefused =
  "PLATFORM_SNAPSHOT_REFUSED"` to `CoreError`.
- **Persisted `StudentState`** (the persistence store):
  - an unreadable file, a failed migration, or a `schema_version` newer than the App → `PLATFORM_STATE_UNREADABLE`;
  - a failed write → `PLATFORM_STATE_WRITE_FAILED` (internal), surfaced by the calling domain as
    `EXP_STATE_WRITE_FAILED` or `DIAG_STATE_WRITE_FAILED`;
  - unknown node ids → `EXP_NODE_NOT_IN_GRAPH`;
  - an off-trail marker → `MAP_MARKER_OFF_TRAIL`.
  **All registered** → `READ-ONLY`. `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` are **not yet
  `CoreError` cases**. The store lives in `Core` (arbiter-03 § Q-F), so both join `CoreError` additively, and the
  existing `ErrorRegistryTests` covers them. The EPIC 01 precedent is `PLATFORM_BUNDLE_INTEGRITY_FAILED`
  (`docs/plans/epic-01-task-plan.md` note 5).
- **Error registry:** `CoreError` ⊆ registry stays green, with its negative control. `READ-ONLY`.
- **Map constants** (map Q4 label threshold [ESTIMATE: ~44 pt, map Q4], the Demo diagnosis budget 1, the
  trail-first framing rule): these are code constants from ratified defaults, not runtime-loaded configuration.
  No config file → no config-invalid code to register.

**`error-codes.json` gains exactly one additive entry, `PLATFORM_SNAPSHOT_REFUSED` (arbiter-03 § Q-C), with no
version bump.**

**MANDATORY invariant line:**
- **I14 (primary risk).** `MapViewModel`, the panel content, action-by-state, tint, the position indicator,
  label visibility for a zoom level and the trail-first focus frame are all derived in `Core`. Every map action
  is a `Core` call that returns a new value. The App keeps only the ephemeral pan/zoom transform and the
  presentation state of its sheets. Two guards:
  - The existing recursive import-boundary test stays green (`Core` imports Foundation only).
  - A **new source scan** over `App/Sources` fails if the render layer constructs a `StudentState`, calls a
    `Core` transition or derivation other than the façade's entry points, or reads `data/` files directly. A
    planted violation proves it bites (C3 negative control).
  - The exact `Core` / App boundary is the one ruled in arbiter-03 § Q-F ("The boundary, precisely").
    `MapViewModel` is plain structs in bundle coordinate space, with no `CGFloat`, `Color`, `@Observable` or
    screen-pixel quantity. The App holds one `@Observable` holder that replaces the `Core` session value with
    each façade result and never derives from it. The App never branches on a `CoreError` to decide visibility.
- **I4 (the record half).** The test the map domain names: "a test asserts every `blocked` id in `StudentState`
  appears in `MapViewModel` with the "Check me here" action and nothing else". It runs over real `data/demo`
  plus constructed states. No page, list or panel anywhere records deeper gaps; the map is the record (v2.5 §3).
- **I7 / I8.** A bundle that fails L0 (or the format-major check, or manifest completeness) is refused, and no
  map is rendered from it. A test proves this on corrupted copies of `data/demo`. The trail on screen is always
  a `MarkerTrail` output, never authored in the App.
- **I5.** The persisted file is exactly the schema's closed key set: no identifier, and the file path never
  leaves the device. There is no network code in `App/Sources` or `Core`; a grep for `URLSession` and
  `URLRequest` must return 0 hits. The existing `IdentifierBlocklistParityTests` stays green.
- **I6 / I15.** The node panel shows `name`, `paraphrase` and expectation codes, each linked to its
  `official_url` from `courses.json`, never Ministry prose. The landmark panel shows `what_it_is` and the
  `source_url` link. A landmark missing `source_url` cannot reach the view model, because L0-10 refuses the
  bundle first.
- **I2.** Tier 0 only; nothing in this EPIC imports a model framework.
- **I1 / I3 / I10.** No item is checked, shown or answered on the map; the only student input is taps, gestures
  and the course and unit pickers. These are asserted as absences in the source scan.
- **D24.** SwiftUI `Canvas`, with no third-party engine. SpriteKit only if `Canvas` performance demands it,
  which ~20 nodes does not [ESTIMATE].
- **D29.** Agents verify on the iOS simulator only; physical-device verification is the owner's.

**MANDATORY artifact line (P4/C4):**
- The **App build** (`xcodebuild build -scheme mathmath`, gate 4), now a real map shell.
- A **simulator launch-and-relaunch smoke**, a script under `scripts/` built on `xcrun simctl`, which
  `scripts/pick-simulator.sh` already uses. It validates with `jsonschema` through `uv run --project pipeline
  python …`. The smoke is added to **both** `scripts/gate.sh` gate 4 (after the App build) **and**
  `.github/workflows/ci.yml` (the `swift` job, after "App build on the simulator"), because CI inlines its steps
  and never calls `gate.sh`. The `swift` job gains an `astral-sh/setup-uv@v6` step pinned to `version:
  "0.12.12"`, the `python` job's pin (arbiter-03 § Q-G, correction 1). It runs two scenarios (arbiter-03 § Q-G,
  correction 2):
  1. **Fresh install:** install and launch; the process is alive after a settle interval; **no** state file
     exists in the container's Application Support.
  2. **Seeded relaunch:** terminate, then seed a version-1 state file (`contracts/examples/student-state.json`
     with `schema_version` 1 and every `remediated` key removed) at the App's named state-file location. Launch:
     the process is alive, the file has `schema_version` 2 and validates against `student-state.schema.json`,
     and no pre-migration file remains. Terminate and relaunch: the process is alive and the file is
     byte-identical to the one before relaunch.

  Every assertion names its instrument, and a missing container or file is FAIL. No launch-argument test hook
  exists in shipping code. The state-file location is a named constant shared by the App and the smoke.
- The **`Core` library** with `MapViewModel`, the map-actions façade and session, the launch load-and-validate
  entry point, and the persistence store, all in `Core` (arbiter-03 § Q-F), exercised by `xcodebuild test
  -scheme Core-Package` (gate 3).
- The **embedded snapshot**: `data/demo` bytes inside the App bundle, as a copy under `App/Sources` kept in sync
  by a regenerating script. A **mandatory** byte-identity `CoreTests` test against `data/demo` guards it (single
  source; empty set = FAIL; arbiter-03 § Q-F).
- **`core-cli`** gains no subcommand but must still build (gate 3; the EPIC 01 pipeline seam test).
- **Contract artefacts** (task 1): `interaction-contract.md` v0.9.2 (arbiter-03 § Q-B) under a
  `contract(interaction-contract)` commit, and the `error-codes.json` additive entry `PLATFORM_SNAPSHOT_REFUSED`
  with its `platform.md` row and W1 sentence (arbiter-03 § Q-C) under a `contract(error-codes)` commit.

## 4. Acceptance criteria
1. **Launch on the real snapshot.** On the simulator, a fresh install launches, loads the embedded `data/demo`
   through `BundleIO.read` → format-major check → L0 `validate` (L0 `passed: true`) and presents the course
   picker (`courseSelectionNeeded`, §9 Q-E). Choosing a course opens the map. The `platform.launched` and
   `map.opened` events are emitted.
2. **Refusal.** `Core` tests run the same load path over corrupted copies of `data/demo` and assert that no map
   view model is produced in each case. Each case asserts **both** the student-surface code
   `PLATFORM_SNAPSHOT_REFUSED` and the underlying internal code listed below (arbiter-03 § Q-C):
   - a manifest-named file removed → `PLATFORM_BUNDLE_INTEGRITY_FAILED`;
   - a format major changed → `PLATFORM_BUNDLE_INTEGRITY_FAILED`;
   - an edge making a cycle → `GRAPH_L0_FAILED` with the rule id in the details;
   - a node's position removed → `MAP_LAYOUT_MISSING`, or `GRAPH_L0_FAILED` carrying it, whichever the L0 report
     shape already produces.
3. **Persistence** (platform W3, Demo slice):
   - No file → `courseSelectionNeeded`; no file is written. Choosing a course yields a state with
     `schema_version` 2, `install_day` = the injected today, `syllabi` = [course], the default marker, every
     node absent (`fog`), and it is persisted (arbiter-03 § Q-E).
   - Write → read round-trips byte-equal through `CoreCoding`. The write is atomic: an interrupted write never
     leaves a truncated document where the previous one was.
   - Every state-changing action of the `Core` session writes the whole document to the injected URL
     (arbiter-03 § Q-F).
   - A version-1 file migrates to version 2 by identity. The pre-migration file is kept until the migrated
     one is written.
   - An undecodable file, or one with a `schema_version` newer than the App → `PLATFORM_STATE_UNREADABLE`. The
     original file is kept byte-for-byte, and launch returns `courseSelectionNeeded` with
     `PLATFORM_STATE_UNREADABLE` in its messages. The fresh state is created when a course is chosen
     (arbiter-03 § Q-E).
   - Every one of these passes in `Core` tests against a temporary directory. The simulator smoke (§3 artifact
     line) shows that a fresh install writes no file, and that a seeded version-1 file migrates, validates and
     is byte-identical after relaunch.
4. **Load reconciliation (W7).** A persisted marker naming a unit absent from the bundle opens the map at the
   default marker, with mastery untouched. A persisted node id absent from the bundle is kept in the file and
   ignored on the map. Both run through the existing 02a functions. Per arbiter-03 § Q-A (task 3 test
   obligation), over a state whose marker names `MCR3U.u9`:
   - the outcome's marker equals `defaultMarker`, and mastery is byte-equal to the input;
   - the student-message list computed by `Core` is **empty**, and the internal diagnostics contain
     `MAP_MARKER_OFF_TRAIL`;
   - load writes nothing: the file keeps its stored marker until the next state-changing action;
   - negative control: the same state with a valid unit produces no code;
   - with syllabi `["MHF4U"]`, a course absent from `data/demo`, the outcome is `courseSelectionNeeded`, with no
     student text.
5. **`MapViewModel` over real `data/demo`** (`Core` tests):
   - 10 regions + 4 horizon labels. Horizon regions are not tappable and carry no fraction. The 7 regions with
     no nodes are pure fog (map Q2, Q3).
   - One river per edge, from → to.
   - Region tint = cleared fraction over the region's trail nodes.
   - `NodeView` fog levels follow `StudentState`: `fog`, `blocked` with a marker, `cleared` lifted. A cleared
     node with `next_due ≤ today` gets a due ring and stays cleared (map Q1).
   - Course segments are solid. With `past_last_unit == true` on an in-memory bundle that has a downstream
     course, an `extension` segment appears and is marked dashed. This follows the 02a test-data rule, because
     `data/demo` has no `next_courses` target present.
   - The position indicator is the first uncleared trail node at or after the marker.
   - The landmark appears with its node links.
   - Node names are in the label set only above the zoom threshold (map Q4).
   - The initial focus frame contains every node of the marker's unit and the next unit (D44).
   - The derivation is deterministic: equal inputs give an equal view model.
6. **Actions by state** (map W2, I4 record half, `Core` tests):
   - A `blocked` node, or one upstream of the marker, offers exactly "Check me here".
   - A fogged node on the fringe offers exactly "Include".
   - A `cleared` node offers nothing.
   - A fogged node that is neither on the fringe nor upstream of the marker offers nothing; its panel still
     shows "under fog" (arbiter-03 § Q-D).
   - Every `blocked` id in a state appears in the view model with "Check me here" and nothing else.
7. **Marker from the unit list** (map W5, D45):
   - Picking a unit calls `MarkerTrail.setMarker`. The trail is regenerated, nodes upstream of the new marker
     keep their mastery and are flagged upstream, and the view model is re-derived.
   - The state is persisted, `map.marker_moved` is emitted, and after relaunch the marker and trail are
     unchanged.
   - Picking "past the last unit" sets `past_last_unit` (interaction-contract v0.9.2 § 3, arbiter-03 § Q-B).
   - With no state, the student first selects a course; the first state is then created and persisted with
     `syllabi[]` and the default marker. A later course change replaces `syllabi` and the marker together and
     keeps mastery (arbiter-03 § Q-E).
8. **C1 seam — `Core` ↔ render layer (I14).** The App's map screen is driven only by the `Core` view model and
   façade. The `App/Sources` source scan of §3 is green, and its planted negative control fails it. The App
   build is green. A W6 test takes a state produced by a **real** `MasteryTransitions.itemCorrect` sequence
   (clear) and a **real** `DiagnosisRun.run` `confirmed` outcome (block), both on `data/demo`. `run` is kept
   as the thin driver over the step API (arbiter-02-11-stepwise-api § Ruling 3). The test re-derives the view
   model and asserts the fog lifted, the blocked marker placed and the region re-tinted. No hand-built view
   model is used.
9. **C1 seam — bundle loader ↔ `Core` validation at load.** The App's launch path and the `Core` test call the
   same `Core` entry point. The test runs over the **real** `data/demo` and over the **embedded snapshot bytes**
   the App build ships, which are byte-identical to `data/demo`. That copy lives under `App/Sources`, and the
   byte-identity test is mandatory, with empty set = FAIL (arbiter-03 § Q-F). Neither side is stubbed, and no
   second L0 or loader implementation exists in `App/Sources` (I14: "L0 and layout exist once, in `Core`").
10. **Hand-off values for EPIC 04.**
    - "Check me here" on a blocked node of real `data/demo` returns a `DiagnosisEvent` with trigger
      `map_check_here`, the node as origin and budget 1, and emits `map.check_here_requested`.
    - "Unit expedition" on a unit returns a `ComposeResult` drawn only from that unit plus `blocked` nodes, and
      emits `map.unit_expedition_requested`. On empty data it raises `EXP_NO_FRINGE`, surfaced with its
      registered text.
    - "Include" on a fringe node makes that node slot 1 of the next real `compose`, and emits
      `map.include_requested`. Per arbiter-03 § Q-D: the queue is in memory and not persisted; a later Include
      replaces the queued id; the next `compose` consumes the id; and an Include on a node upstream of the marker
      returns a typed "ignored, upstream of the marker" outcome with no student text and no new code.
    - All three are `Core` tests on real data. `scripts/gate.sh` is green.

## 5. Conformance tests it must ship (B.1)
- **map** (§ Invariants enforced here):
  - I14 co-owner: `MapViewModel` in `Core`, and the render layer computes nothing. Covered by the import
    boundary test (existing) plus the new `App/Sources` scan.
  - I4 record half: every `blocked` id gets "Check me here" and nothing else.
  - I7 / I8: a violation refuses the bundle rather than rendering a broken map.
  - I15: no unsourced landmark reaches the model.
  - I2 / I6: Tier 0; panels show `paraphrase`, codes and outbound links.
  - D24: no third-party engine, and the renderer is replaceable without touching `Core` (the `Core` suite
    passes with no App code).
- **platform** (§ Invariants enforced here, Demo slice):
  - I14: `StudentState` is read and written as an opaque `Codable` value, and no state shape or transition is
    defined outside `Core`.
  - I5: the file carries the closed key set only; no path or capability fact enters any shape that could leave
    the device. There is no network code (grep). The platform domain's network-host test is EPIC 10's.
  - I2: launch, map and persistence run with no connectivity. The simulator smoke runs with no network
    dependency.
- **expedition** W7 (App half): unknown ids are kept and ignored; the off-trail marker falls back to the default.
- **Contract rungs marked EPIC-time** (`contracts/README.md`):
  - graph-constraints "at app load" (the load half EPIC 01 left to EPIC 03);
  - error-codes "`Core` error enum mirrors the registry", extended to any new platform cases;
  - interaction-contract: map-action property tests for the §3 marker behaviour through the façade.

## 6. Dependencies on prior EPICs
- **EPIC 01** (merged; `docs/audits/epic-01-acceptance.md`): `Core` types, `BundleIO`, L0, layout positions,
  and `data/demo` (20 nodes, 40 items, 19 edges, 14 regions, 2 courses, 1 landmark) [SOURCED:
  docs/audits/epic-01-acceptance.md §2]. It explicitly left "the bundle-loader ↔ `Core` validation seam" to
  EPIC 03 (§5 there).
- **EPIC 02a** (wrapped; `docs/audits/epic-02a-acceptance.md`): `MarkerTrail`, `Expedition.compose`,
  `ExpeditionRun`, `MasteryTransitions`, `CoreEvent`, `CalendarDay`, `CoreError`, and data-model v1.3.0.
- **EPIC 02b** (in progress on `epic-02b-door-a-core-merge`; **must be wrapped first**, i.e.
  `docs/audits/epic-02-acceptance.md` exists): task 02.11 (`DiagnosisRun.open`, `DiagnosisTrigger.mapCheckHere`,
  and the `DiagnosisRun.run` used by the §4 item 8 W6 test, kept as a thin driver over the step API per
  `tasks/arbitration/arbiter-02-11-stepwise-api.md`); task 02.10 (the query behind it); task 02.9
  (data-model v1.4.0, which this EPIC reads). Task 02.12 (`merge`) is not called here.
- Domain order: bundle loading (platform) before map W1. The map is the record (v2.5 §3), so EPIC 03 renders
  the state EPIC 02 produces. EPIC 04 depends on this EPIC's hand-off values (§4 item 10).
- No dependency on EPICs 05–13.

## 7. Out of scope
1. **Expedition, answer-card, hypothesis-card, probe, remediation and summary screens; the "Start expedition"
   entry; the unit-expedition entry screen; the Demo acceptance record** — EPIC 04 (its epic-plan row). EPIC 03
   stops at the typed hand-off value (§2).
2. **The remaining interaction-contract finalization items** (answer-card timing, summary tint deltas) and the
   **v1.0.0 bump** — EPIC 04 at Demo wrap.
3. **`MathView`.** The EPIC 01 brief (§7 item 2) says "`MathView` is EPIC 03's", but no map surface carries
   LaTeX: data-model § Text puts LaTeX only in `latex` and `prompt_latex` fields, which are item and choice
   fields. `MathView` therefore moves to EPIC 04, its first consumer (RULE 2: no speculative code). This is
   stated here so the move is traceable.
4. **Hosted bundles, content refresh, hash verification on fetch, and the network-allowlist test** — EPIC 10
   (platform W2; `contracts/deployment-model.md`). See §9 Q-H for the snapshot-hash item EPIC 01 routed here.
5. **iCloud sync and calling `merge`** (platform W4, platform Q1) — EPIC 10.
6. **Telemetry client, consent switch, and Settings › Storage** — EPICs 10–11. Events are emitted in-process
   only (DEMO-BRIEF §2: no telemetry in the Demo).
7. **CapabilityFacts** (platform W1 step 3) — they have no consumer until runtime-tiers, EPIC 06/13. Tier 1 is
   untouched, and DEFERRED D-2 (Tier 2) is not fired.
8. **Shore region** (D-10, trigger M5), **ideas layer** (D-9, trigger: Demo observations), **additional
   syllabi** (D-11, trigger: undergraduate nodes exist). None has fired.
9. **Streaks, badges, Game Center** (D-7) and **animation beyond a basic transition** (D24; map W6).
10. **UI localisation** (D-1, English only) and **accessibility polish** (DEMO-BRIEF §4).
11. **Physical-device verification** (D29) — the owner's check at the Demo wrap. No agent claims it.
12. **Nodes outside Number, Algebra and Functions.** The other regions are drawn empty (DEMO-BRIEF §3.1 as
    amended by v2.6 §D).

## 8. Size estimate
**8 tasks** [ESTIMATE: at the cap; the planner may re-cut], plus the wrap:
1. Contract task, two commits (arbiter-03 § Consequences for the planner, item 1):
   - `interaction-contract.md` v0.9.2 with the `map.md` W5 and error-row edits and the drag DEFERRED entry
     (§9 Q-B);
   - the `error-codes.json` `PLATFORM_SNAPSHOT_REFUSED` entry with its `platform.md` row and W1 sentence
     (§9 Q-C).
2. Launch load-and-validate entry point (`BundleIO` → format major → L0 → the Q-E launch outcome, or
   `refused(PLATFORM_SNAPSHOT_REFUSED)` with the underlying code), the `CoreError` case
   `platformSnapshotRefused`, the snapshot copy under `App/Sources` with its regenerating script and mandatory
   byte-identity guard, and the **C1 loader↔validation seam** (§4 items 1, 2 and 9).
3. The `StudentState` persistence store in `Core`: first-state creation on course choice, identity migration,
   atomic write, unreadable/newer handling, error mirror + registry test, the save-after-every-action session,
   and W7 reconciliation wiring with the Q-A test obligation (§4 items 3 and 4).
4. `MapViewModel` derivation + I4 record-half test + W6 re-derivation over real transitions (§4 items 5 and
   6, and the `Core` half of item 8).
5. Map-actions façade: panel content, action by state (including the no-action case), the course-selection
   façade, set marker, the in-memory Include queue, Unit expedition, Check me here, and the events (§4 items 7
   and 10).
6. App shell: launch wiring, Application Support location (a named state-file constant), injected `today`,
   error-surface policy (show only `Core`'s message list; §9 Q-A, Q-C), the course picker as the first screen
   for `courseSelectionNeeded`, and the simulator smoke. The smoke is wired into both `scripts/gate.sh` and
   `.github/workflows/ci.yml`. File scope adds `.github/workflows/ci.yml` ("CI mirror of gate 4's smoke step").
   The D-13 directory is re-measured first and never staged (§9 Q-G).
7. App `Canvas` map: regions, rivers, fog, due ring, blocked marker, solid/dashed trail, horizon, landmark,
   pan/zoom, and the trail-first camera.
8. App panels as sheets, the course and unit-list picker, the three action buttons with their hand-off hooks,
   and the `App/Sources` I14 source scan with its negative control (§4 item 8).

**Seams (C1) added:** `Core` ↔ render layer, and bundle loader ↔ `Core` validation at load. The hand-off values
to EPIC 04 are tested at the `Core` level here (§4 item 10). EPIC 04 owns the screen-level seam, "App↔`Core`
state transitions".

**If the plan exceeds the cap**, split at the natural seam. (Q-C adds no task: its registration lands in task
1, arbiter-03 § Q-C "Ordering constraint".)
- **03a — Map core**: tasks 1–5, all `Core` plus the contract bump. Gate: `Core-Package`.
- **03b — Map App**: tasks 6–8, all `App/Sources` plus the smoke. It depends on 03a's façade.

Each half is wrapped and merged on its own, as EPIC 02 was.

## 9. Open questions
All of Q-A … Q-H are **resolved** (2026-09-10). The pre-dispatch arbiter rulings are in
`tasks/arbitration/arbiter-03-predispatch.md` (no ESCALATE-Q5, and no locked decision or invariant changed). The
entries below keep their original analysis.
- **Q-A — D-12: the `MAP_MARKER_OFF_TRAIL` user text vs the load-time fallback** (DEFERRED D-12; revisit
  trigger "EPIC 03, when the App first surfaces this code to the student", **fired by this EPIC**).
  - **RESOLVED — option (a), CONFIRMED with precisions** (arbiter-03 § Q-A):
    - no student text on the load path;
    - `Core` computes the message list (empty here), and the App never branches on a code;
    - the missed second `reconcileMarker` branch (no course in `syllabi[]` resolves, so the stored marker is
      returned unchanged) → `courseSelectionNeeded`, with no text;
    - load never writes the state file.

    The registered text's drag path is unreachable in the Demo, and there is no registry change. The test
    obligation is in §4 item 4. **Wrap action:** close D-12 in `docs/DEFERRED.md` citing the ruling, with the
    revisit trigger moved to "EPIC 10: a content refresh can change unit ids".
  - **The conflict.** The registry text is "The marker stays where it was; pick a unit from the list." On the W7
    load path the marker *moves* to the default (arbiter-02-predispatch § Q-D caveat, owed to EPIC 03).
  - **Default: option (a).** On the load path the App shows **no** student text. The map opens at the default
    marker and the code is handled as internal. The registered text is reserved for a set-marker path where the
    marker really stays. Under the Q-B default no such path is reachable in the Demo, because the unit-list
    picker cannot produce an off-trail marker. No registry change.
  - **Alternative: option (b).** Register a dedicated additive code for "your class marker was reset", with its
    domain-doc row and no version bump.
  - This is a UI-text decision with a registry rule on each side, so it is **routed to the spec-arbiter
    pre-dispatch (Q4)**, not decided in code. The wrap closes D-12 in `docs/DEFERRED.md` with the ruling.
  - **Revisit trigger:** EPIC 10, when a content refresh can change unit ids and the load path becomes
    reachable in practice.
- **Q-B — Marker drag** (interaction-contract finalization item 1; map W5 step 1 describes dragging with
  unit-boundary snap).
  - **RESOLVED — CONFIRMED** (arbiter-03 § Q-B). The marker is set from the unit list only, and there is no
    drag. A contract change is needed because the finalization item is contract text: `interaction-contract.md`
    v0.9.2, a patch bump, with the exact normative text in the ruling. It goes with the `docs/domains/map.md` W5
    step 1 sentence and `MAP_MARKER_OFF_TRAIL` error row, and a `docs/DEFERRED.md` entry "Marker drag with
    unit-boundary snap" (trigger: Demo observations). All of it lands in task 1.
  - **Default:** the Demo sets the marker **only from the unit list**. That is the D45 mechanism ("The student
    marks "we are here" from the course's unit list") and the epic-plan row's "unit-list marker picker". No drag
    gesture is built, and "past the last unit" is an explicit entry at the end of the list (v2.7 §4).
  - The contract-bump task records this as the resolution of the finalization item, and a DEFERRED entry is
    added for drag (trigger: Demo observations, DEMO-BRIEF §7 item 7).
  - No D-number changes: drag is in the domain doc, not in D45. **Not a Q5.** If the arbiter reads map W5 as
    binding, the alternative is drag with a snap to the nearest unit boundary. That adds scope inside task 7
    and does not add a task.
- **Q-C — Refused snapshot vs the registered text** (Q4 → spec-arbiter, BUMP candidate).
  - **RESOLVED — new code, CONFIRMED** (arbiter-03 § Q-C). `PLATFORM_SNAPSHOT_REFUSED` is added, with the exact
    registry entry, `platform.md` row and W1 sentence given in the ruling. Reuse and a non-registry screen are
    both rejected. The registry entry and the domain row land in task 1, before task 2 adds the `CoreError`
    case. §4 item 2 asserts both codes.
  - **The situation.** `PLATFORM_BUNDLE_INTEGRITY_FAILED` is a `student` code whose text reads "Could not
    refresh content; still using the installed version." When the Demo's only bundle, the snapshot, is refused,
    no installed version remains. Showing an internal code instead would break "Internal codes never reach a
    student surface".
  - **Default:** additive registration of one platform code for "the app's own content could not be loaded",
    with a next action (reinstall), plus its row in `docs/domains/platform.md` (the `test_contracts.py`
    round-trip requires the row). No version bump (`error-codes.md`: "Additive registration … is allowed without
    a version bump").
  - The path is unreachable in a gated build, because §4 item 9 validates the embedded bytes. It exists so the
    fail-closed screen has honest text.
  - **Alternative:** the arbiter may allow a fixed non-registry screen for a build defect.
  - **Revisit trigger:** the arbiter's pre-dispatch ruling.
- **Q-D — Where the "Include" queue lives** (technical default, not Q5). `StudentState` has no queue field, and
  its closed key set admits none without a BUMP.
  - **RESOLVED — CONFIRMED** (arbiter-03 § Q-D). The queue is held in memory by the `Core` façade:
    - a later Include replaces it;
    - the next `compose` consumes it;
    - an upstream Include returns a typed "ignored" outcome with no text.

    The ruling closes a gap: a fogged node that is neither on the fringe nor upstream of the marker offers no
    action (§4 item 6).
  - **Default:** the one queued node is an **in-memory `Core` value** held by the map façade, passed to the next
    `compose(queuedNodeId:)`, and not persisted. A relaunch clears it.
  - map Q5's "ignored with a plain message if it is upstream of the marker" cannot occur from the panel, because
    such a node offers "Check me here", not "Include" (map W2). The message exists only as a façade result.
  - **Revisit trigger:** Demo observations showing that testers expect the queue to survive a relaunch; that
    would be a data-model BUMP.
- **Q-E — Course selection on a fresh state** (technical default). A fresh state has no `syllabi[]`, so
  `defaultMarker` has nothing to resolve. v2.6 §D: "initial camera on the tester's selected course trail (MTH1W
  or MCR3U)".
  - **RESOLVED — CORRECTED** (arbiter-03 § Q-E). No `StudentState` can exist before a course is chosen, because
    `marker` is required by the schema and non-optional in Swift. So:
    - launch with no file (or an unreadable file, or no resolvable course) returns `courseSelectionNeeded` and
      writes nothing;
    - choosing a course calls a `Core` façade that builds the first state and persists it (`schema_version` 2,
      `format_version_seen` from the bundle, `syllabi = [course]`, the default marker, `trail` from
      `generateTrail`, empty `nodes` and logs, `install_day` = today, `consent_on = true` per I5);
    - the same façade replaces `syllabi` and the marker on a later change.

    §2 and §4 items 1, 3 and 7 are re-worded accordingly.
  - **Default:** the first launch presents the bundle's courses. Selecting one sets `syllabi = [course]` and the
    default marker through a `Core` façade call. The same picker can later change course.
  - Selecting several syllabi at once is not built for the Demo. The state shape already allows it (D47), so
    adding it later changes no schema.
  - **Revisit trigger:** a tester taking two courses (D-11 territory).
- **Q-F — Test home for the platform code.** This is the brief's main structural risk, flagged for the
  planner. **The App has no unit-test target**: `App/mathmath.xcodeproj` has one native target, `mathmath`. An
  agent cannot add one, because "Agents add files under `App/Sources` and `Packages/Core` **without editing the
  pbxproj**" (`docs/tech-stack.md` §1).
  - **RESOLVED — option 1, CONFIRMED** (arbiter-03 § Q-F). This is consistent with I14 and D33, needs no owner
    action and raises no Q5. The exact boundary is in the ruling ("The boundary, precisely"):
    - the launch entry, the persistence store, the plain-struct `MapViewModel`, and the façade are in `Core`;
    - the save-after-every-action session and the student-message list are also in `Core`;
    - `App/Sources` holds views, `Canvas`, gestures, one replacing `@Observable` holder, URL and calendar
      resolution, and URL hand-off.

    The embedded `data/demo` copy lives under `App/Sources`, and its byte-identity test is mandatory.
  - **Default:** everything testable is a Foundation-only `Core` function over caller-supplied URLs and values:
    the load-and-validate path, the persistence store's encode/decode/migrate/atomic write, the view model and
    the façade. `BundleIO` already reads files in `Core`. `App/Sources` keeps only what needs UIKit/SwiftUI or
    the OS: views, `Canvas`, resolving the Application Support and app-bundle URLs, and reading the device
    calendar. Everything else is verified by `Core-Package` tests, the App build and the simulator smoke.
  - `docs/tech-stack.md` §2 lists "persistence/sync/bundle loading (platform)" under `App/Sources`, but the same
    section says "a spec's §2 file scope is authoritative". If a reviewer reads the ownership line as binding,
    that is a **Q4 → spec-arbiter**.
  - **Q5 candidate (only if the arbiter rejects the default):** the owner adds an App unit-test target
    (`mathmathTests`) to the pbxproj. That is an owner-only edit.
    - Option 1: `Core` placement (recommended; no owner action).
    - Option 2: the owner-added test target.
    - Option 3: a new local package for platform adapters. Linking it into the App also needs an owner pbxproj
      edit.
- **Q-G — The simulator smoke in the gate** (technical default). **Default:** a script under `scripts/` built on
  `xcrun simctl` (already used by `scripts/pick-simulator.sh`) and invoked from gate 4 after the App build, so
  CI runs it. It asserts: the App launches; it stays up; the state file appears in the App container and
  validates against `student-state.schema.json`; the state survives terminate → relaunch.
  - **RESOLVED — CORRECTED** (arbiter-03 § Q-G). `xcrun simctl` and `jsonschema` (via `uv run --project
    pipeline`) are allowed. Two corrections:
    1. CI never calls `gate.sh`. So the smoke goes into **both** `scripts/gate.sh` gate 4 and the `swift` job of
       `.github/workflows/ci.yml`, which gains a `setup-uv` step (`0.12.12`).
    2. The App writes nothing before a course is chosen, and `simctl` cannot tap. So the smoke runs two
       scenarios: a fresh install writes no file; and a seeded v1 file migrates to v2, validates, and is
       byte-identical after relaunch.

    No launch-argument test hook is allowed. Task 6 first **re-measures** the D-13 directory, never stages it,
    and the wrap records the measurement in D-13. See the §3 artifact line.
  - Under D29 this is a simulator check, not a device check.
  - **Revisit trigger:** CI flakes in simulator boot. Fallback: run it as the wrap's runbook command, recorded
    in the acceptance report, rather than weakening the assertion.
- **Q-H — Snapshot `sha256` verification** (outstanding from EPIC 01). `docs/plans/epic-01-task-plan.md` note 2
  says hash "*verification at load* defers to EPIC 03's App-side loader. Record the deferral in
  `docs/DEFERRED.md` at wrap". **No such DEFERRED entry exists** (D-1 … D-13), and every `sha256` in
  `data/demo/manifest.json` is the all-zero placeholder [SOURCED: data/demo/manifest.json].
  - **RESOLVED — CONFIRMED** (arbiter-03 § Q-H). EPIC 03 has no embedded-snapshot hash check. **Wrap action:**
    add the missing EPIC 01 deferral as the next `docs/DEFERRED.md` entry, in the C6 template, with trigger
    EPIC 10 hosted bundles (platform W2) and no hypothesis.
  - **Default:** EPIC 03 does **not** verify hashes on the snapshot. The snapshot ships inside the code-signed
    App, and platform § AssetVersion describes the hash as "checked on fetch", which is EPIC 10's path. EPIC 03
    enforces completeness, format major and L0 at load. The wrap records the missing DEFERRED entry (trigger:
    EPIC 10 hosted bundles). Verifying at load in the App would need CryptoKit, which `Core` may not import
    (D33), together with real hashes in `data/demo`.
  - **Alternative:** the arbiter may require launch-time hash verification now. That would add a pipeline step
    that writes real hashes into `data/demo/manifest.json` (re-validated by L0), plus an App-side check.
  - **Revisit trigger:** EPIC 10.
- **D-13 (carried forward).** The untracked `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`
  is **never staged** by any EPIC 03 task. If the Q-G script counts as "the next tooling … change" (D-13's
  trigger), the task that adds it first **re-measures** the directory (DEFERRED's rule: "Consuming work
  re-measures before planning against an entry") before proposing an ignore rule. The `Package.resolved` tracking
  question stays open. This is outside the 8-task count.
  - **RESOLVED** (arbiter-03 § Q-G, "D-13"). The smoke and the `ci.yml` change **do** fire the trigger. Task 6
    re-measures first, and the wrap records the measurement in D-13. Any ignore rule is a separate
    owner-visible change and is not part of task 6.
- **Note for EPIC 04, not in scope here.** The 02.11 spec gives `DiagnosisRun.run` a batch signature that
  takes every level's decisions up front (`decisions: [DiagnosisLevelDecision]`). A touch UI decides one step at
  a time. EPIC 04's planner should check the step-wise entry points in the same spec (`hypothesise`, `probe`,
  `offered`, `remediate`, `returned`) before designing its screens.
  - **Superseded** by `tasks/arbitration/arbiter-02-11-stepwise-api.md` (§ Ruling, § Downstream doc note). Those
    helpers are now `internal`. EPIC 04 drives Door A through `DiagnosisRun.start` → `decideProbe` →
    `answerProbeItem` → `decideFurtherLevel`, one call per screen action, threading `DiagnosisAdvance.state`.
    `open` and the thin-driver `run` keep the names this brief uses. EPIC 03 is unaffected: it only calls
    `DiagnosisRun.open` for `map_check_here`.
- **Q5 candidates:** none at authoring. Q-A, Q-B and Q-C are contract realisations routed to the spec-arbiter.
  Q-D, Q-E, Q-G and Q-H are technical defaults. Q-F becomes an owner decision only if the arbiter rejects the
  `Core`-placement default, because the alternatives need an owner-only pbxproj edit. No locked decision D1–D49
  is changed. *Post-arbitration:* the arbiter raised no ESCALATE-Q5 and confirmed the Q-F default, so no Q5
  candidate remains.

## 10. Change log
| Date | Author | Change |
|------|--------|--------|
| 2026-09-10 | epic-scoper | Initial brief synthesized. |
| 2026-09-10 | brief-amender (arbiter pre-dispatch rulings `tasks/arbitration/arbiter-03-predispatch.md`; step-wise diagnosis API `tasks/arbitration/arbiter-02-11-stepwise-api.md`) | Status line; §2 (launch, persistence, reconciliation, façade, hand-offs, 02b dependency); §3 (interaction-contract, error-codes, R-6 guard set, I14 line, artifact line); §4 criteria 1, 2, 3, 4, 6, 7, 8, 9, 10; §6 EPIC 02b entry; §8 task contents and split note; §9 Q-A…Q-H and D-13 marked resolved, EPIC 04 note superseded. Scope unchanged. See Amendment 03.00.1. |

## Amendment log

### Amendment 03.00.1 — 2026-09-10

**Trigger**: tier-6 brief-amender, invoked by the orchestrating session with the spec-arbiter's pre-dispatch rulings on Q-A … Q-H, before any EPIC 03 task is dispatched. The sequence number `00` marks the pre-dispatch amendment, which is tied to no task.
**Architect escalation**: none on disk. The brief itself routed Q-A, Q-B, Q-C and Q-F to the spec-arbiter (Q4) and submitted Q-D, Q-E, Q-G and Q-H for confirmation. The rulings are in `tasks/arbitration/arbiter-03-predispatch.md`. The `DiagnosisRun` alignment follows `tasks/arbitration/arbiter-02-11-stepwise-api.md`.

**Passage 1 — §4 acceptance criterion 3, first bullet (arbiter-03 § Q-E, verbatim re-wording).**

**Original brief text**:
> No file → a fresh default state, with `schema_version` 2, `install_day` = the injected today, and every
> node absent (`fog`).

**Amended brief text**:
> No file → `courseSelectionNeeded`; no file is written. Choosing a course yields a state with
> `schema_version` 2, `install_day` = the injected today, `syllabi` = [course], the default marker, every
> node absent (`fog`), and it is persisted (arbiter-03 § Q-E).

**Passage 2 — §2 StudentState persistence bullet (arbiter-03 § Q-E, § Q-F).**

**Original brief text**:
> Read at launch. No file → a fresh default.

**Amended brief text**:
> Read at launch. No file → launch returns `courseSelectionNeeded` and **writes nothing**. Choosing a course
> creates the first state and persists it.

**Passage 3 — §4 acceptance criterion 2 (arbiter-03 § Q-C, "Code shape").**

**Original brief text**:
> `Core` tests run the same load path over corrupted copies of `data/demo` and assert that no map view model is
> produced in each case:

**Amended brief text**:
> `Core` tests run the same load path over corrupted copies of `data/demo` and assert that no map view model is
> produced in each case. Each case asserts **both** the student-surface code `PLATFORM_SNAPSHOT_REFUSED` and the
> underlying internal code listed below (arbiter-03 § Q-C):

**Passage 4 — §3 artifact line, smoke (arbiter-03 § Q-G, corrections 1 and 2).**

**Original brief text**:
> It asserts the state file appears in the App container's Application Support and validates against
> `student-state.schema.json`. It then terminates and relaunches the App and asserts that state survived. Whether
> this script is wired into `scripts/gate.sh` or run as the wrap's runbook command is the planner's call (§9
> Q-G); either way a gate runs it (C4).

**Amended brief text** (summarised; see §3 for the full wording):
> The smoke is added to both `scripts/gate.sh` gate 4 and the `swift` job of `.github/workflows/ci.yml`, which
> gains a `setup-uv` step (`0.12.12`). It runs two scenarios: a fresh install writes no state file; and a seeded
> version-1 file migrates to version 2, validates, and is byte-identical after relaunch. There is no
> launch-argument hook, and the state-file location is a named constant.

**Passage 5 — specificity from the rulings, with no criterion added or removed.**
- §2:
  - launch: three outcomes (Q-E), refusal code (Q-C), and the embedded copy under `App/Sources` with its regenerating script (Q-F);
  - persistence: unreadable → `courseSelectionNeeded`, and the save-after-every-action session in `Core` (Q-E, Q-F);
  - reconciliation: the Q-A precisions, including the missed `reconcileMarker` branch and "load never writes";
  - façade: course selection (Q-E) and the in-memory Include queue (Q-D);
  - Check me here: points to the step-wise ruling (`open` unchanged);
  - hand-offs: the App calls none of the step functions;
  - 02b dependency line: names the step-wise ruling.
- §3:
  - interaction-contract: v0.9.2 with the Q-B cascade (map.md W5 + error row, drag DEFERRED entry);
  - error-codes: the ruled `PLATFORM_SNAPSHOT_REFUSED` entry, landing in task 1 before the `CoreError` case in task 2;
  - R-6 caveat resolved, and the store's errors join `CoreError`;
  - the "No BUMP … unless" line replaced by the ruled single entry;
  - the I14 line gains the Q-F boundary;
  - the artifact line: `Core` placement, the mandatory byte-identity test, and both contract commits.
- §4 criteria:
  - 1: fresh install presents the course picker, then the map (Q-E).
  - 3: the unreadable bullet goes through `courseSelectionNeeded`; a save-after-every-action bullet (Q-F); the smoke clause per Q-G.
  - 4: the Q-A test obligation, covering the empty message list, internal diagnostics, no write on load, negative control and the unresolvable-course variant.
  - 6: the fogged, off-fringe, not-upstream → no action case (Q-D).
  - 7: "past the last unit" cites v0.9.2 § 3; the no-state first course selection and later course change (Q-E).
  - 8: `run` is the thin driver over the step API (arbiter-02-11-stepwise-api § Ruling 3).
  - 9: the copy's location and the mandatory test (Q-F).
  - 10: the Include queue precisions (Q-D).
- §6: EPIC 02b entry names the step-wise ruling.
- §8:
  - task 1 carries both contract commits;
  - task 2 carries the `CoreError` case and the embedded copy;
  - task 3 carries the session and the Q-A obligation;
  - task 5 carries the no-action case and the selection façade;
  - task 6 carries `ci.yml`, the named state-file constant and the D-13 re-measure;
  - the split note records that Q-C adds no task. The count stays at 8.
- §9: Q-A … Q-H and D-13 are marked resolved with pointers, and the original analysis is kept. The wrap actions are D-12 close (revisit EPIC 10), the Q-H DEFERRED entry (trigger EPIC 10), and the D-13 measurement. The EPIC 04 note is marked superseded by the step-wise ruling. The Q5-candidates line gains a post-arbitration note.

**Source**:
- `tasks/arbitration/arbiter-03-predispatch.md` § Summary table, § Q-A … § Q-H (including their exact normative text, test obligations and wrap actions), and § Consequences for the planner.
- `tasks/arbitration/arbiter-02-11-stepwise-api.md` § Ruling (1, 2, 3), findings 3, and § Downstream doc note.
- Contracts cited by the rulings are not edited by this amendment. `interaction-contract.md` v0.9.2 and the `PLATFORM_SNAPSHOT_REFUSED` registration are owed by task 1.

**Effect on deliverables**: NONE (specificity added).
- Every item of §2 and §7 is unchanged, and no deliverable is added, dropped or deferred.
- Two items were already in the brief as default-or-candidate artefacts: the v0.9.2 bump (§3, §8 task 1) and the additive registration (§3, §9 Q-C). The rulings fix their text.
- The `ci.yml` mirror and the D-13 re-measure make the brief's own "a gate runs it (C4)" true. The count stays at 8 tasks.

**Effect on owner-facing acceptance**: NONE.
- Criteria 1 and 3 now describe the only schema-valid first-run path (a course is chosen before any state exists). They still assert launch on the real snapshot, `platform.launched` / `map.opened`, and every persistence behaviour.
- Criteria 2, 4, 6, 7, 8, 9 and 10 gain assertions from the rulings. None is weakened, removed or renumbered, and §5 is unchanged.
- No locked decision D1–D49 and no invariant I1–I15 changes meaning (arbiter-03 header: "no ESCALATE-Q5").

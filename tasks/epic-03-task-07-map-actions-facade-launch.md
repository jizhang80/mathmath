# Epic 03 · Task 07: Map-actions façade + `MapLaunch.open` (the `Core` ↔ App seam)

---
epic: 03
task: 07
slug: map-actions-facade-launch
kind: feat
risk: seam
depends_on: [02.5b, 03.1, 03.4, 03.5, 03.6]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`, no `epic-03a-map-core` branch yet). The
> implementer runs this task on `epic-03a-map-core`, created after EPIC 02b merges into `main`
> (`docs/plans/epic-03-plan.md`: "EPIC 03 starts only after EPIC 02b is merged"). `DiagnosisRun.open`
> (`Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift`) is confirmed **absent** from
> `Packages/Core/Sources/Core/` in this session (context bundle §E; `Glob **/DiagnosisEvent.swift` returned no
> match) — it lands with EPIC 02b's task 02.11, which must be merged before this task's implementer starts. If
> `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` (exact signature, `tasks/arbitration/arbiter-02-11
> -stepwise-api.md` § Ruling 1, re-read and byte-compared in this run) is absent when implementation starts,
> that is the EPIC-order precondition failing to hold — BLOCK and report it; do not stub or reimplement the
> diagnosis machine here. Task 03.3's `CoreError` cases `platformStateUnreadable`, `platformStateWriteFailed`
> and `platformSnapshotRefused`, and tasks 03.4/03.5/03.6's public entry points, are all direct dependencies
> (`depends_on`) and are assumed landed and byte-verified against their own already-written specs
> (`tasks/epic-03-task-0{3,4,5,6}-*.md`), quoted verbatim in §3 below.
>
> **Past-last-unit precondition (task 02.5b, arbitration `tasks/arbitration/arbiter-03-07-past-last-unit.md`).**
> The contract rule "setting it writes the course's last unit as `unit_id`" (interaction-contract § 3, quoted
> §3) is enforced **once, in `Core`**, by `MarkerTrail.setMarker` as corrected by EPIC 02b's task 02.5b
> (`tasks/epic-02-task-05b-fix-set-marker-past-last-unit.md`). The code as landed by 02.5 does NOT do this:
> `MarkerTrailGeneration.swift:94` builds the `Marker` straight from the caller's `unitId`. Before writing any
> code, the implementer confirms that `MarkerTrail.setMarker`'s body substitutes the course's `units.last`
> when `pastLastUnit` is `true` (02.5b §4). If it does not, the EPIC-order precondition has failed: BLOCK and
> report it. Do not compute the last unit in `MapLaunch.swift`. A second copy of the rule would violate the
> single-source rule.

## §1 Goal & acceptance criteria

Goal: `Core` gains `MapLaunch.open(snapshotDir:stateURL:today:)`, the App-launch entry point. It composes
`BundleLoader.load` (03.4), `StudentStateStore.read` (03.5), expedition W7 reconciliation (`MarkerTrail
.reconcileMarker` / `.reconcileNodeIds`, existing 02a code), and `MapViewModel.derive` (03.6) into one of three
`LaunchOutcome`s: `.ready`, `.courseSelectionNeeded`, or `.refused`. It also gains the map-actions façade
covering panel content (node/region/landmark), `selectCourse`, `setMarker`, `include` (an in-memory one-node
queue), `unitExpedition` and `checkHere`. The façade's state-changing actions (`selectCourse`, `setMarker`)
persist through `StudentStateStore.write` after every call; `include` never persists (Q-D). The App's only
handle onto this surface is one Foundation-only value type, `MapState`, that a single `@Observable` holder
(built in a later App task) replaces wholesale after each façade call. The App never constructs a
`StudentState`, `MarkerTrail`, `Expedition` or `DiagnosisRun` directly (arbiter-03 § Q-F). `Core`, not the
App, computes the student-message list (`[String]` of registry codes, resolved to text only by 03.11's later
call to `CoreErrorText`); the load-path marker reset (`MAP_MARKER_OFF_TRAIL`) never appears in it
(arbiter-03 § Q-A).

Invariants in play:

- **I1** — not applicable: this task checks no item and decides no correctness; `checkHere` returns a
  `DiagnosisEvent` unchanged (pure construction, arbiter-02-11 Ruling 1), never itself judging a probe.
- **I2** — Tier 0 only: no model import, no adapter parameter anywhere in `MapLaunch.swift`.
- **I3** — not engaged: no answer is shown or withheld by this task (no item-check path exists here).
- **I4** — the record half: `include` never offers a node whose `MapViewModel.NodeView.action != .include`
  (§4.5); `checkHere` is the only route onto a `blocked` node, matching 03.6's own action-priority rule, which
  this task consumes rather than re-derives (no duplicate action logic).
- **I5** — `MapState` and every façade return value carry only bundle/graph ids, `StudentState` (already I5-
  clean per 03.5), enums and plain strings — no identifier is added; `LaunchOutcome.messages` holds registry
  code strings only, never a student, device or session identifier.
- **I6** — node panel content shows `paraphrase`, expectation codes paired with `courses.json`'s `official_url`,
  never Ministry text; the `verbatim` key is never read (§4.2).
- **I15** — landmark panel content shows only `what_it_is` and `source_url`; a landmark reaching this façade
  already passed L0-10 / decode-time `sourceUrl` non-optionality (03.4), so no further sourcing check is needed
  here.
- **I14** — `MapLaunch.swift` imports Foundation only; the render layer (App/Sources, out of this task's scope)
  calls only this file's public entry points and never re-derives `MapViewModel`, `StudentState` transitions or
  the fringe formula itself — enforced later by 03.9's source scan, which this task's public surface must be
  narrow enough to make possible. No new type in this file has a `public init` other than the implicit
  memberwise ones Swift restricts to module-internal callers for types with only `public let` fields. The
  past-last-unit rule is not re-implemented here; `MarkerTrail.setMarker` (02.5b) owns it.

Acceptance criteria (each independently verifiable; brief §4 item numbers noted where they map to
`docs/epics/epic-03-app-map-shell.md` after Amendment 03.00.1):

- AC1 (brief item 1, fresh install): `MapLaunch.open(snapshotDir: <data/demo>, stateURL: <no file>, today:)`
  returns `.courseSelectionNeeded(bundle:, messages: [])`; no file is created at `stateURL`; the returned
  `events` contain `.platformLaunched` and do not contain `.mapOpened`.
- AC2 (refusal, delegated): `MapLaunch.open` over a `snapshotDir` `BundleLoader.load` refuses (a manifest-named
  file removed) returns `.refused(refusal)` with `refusal.studentCode == .platformSnapshotRefused` and
  `refusal.internalCode == .platformBundleIntegrityFailed`; `stateURL` is never read or written; `.platform
  Launched` is **not** in the (empty, for this case) events.
- AC3 (brief item 3, Q-E persistence): `selectCourse(courseCode: "MTH1W", bundle:, stateURL:, previousState:
  nil, today:)` returns a `MapState` whose `.state` has `schemaVersion == 2`, `installDay == today.iso`,
  `syllabi == ["MTH1W"]`, `marker == MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle:)`, and `nodes.is
  Empty`; a subsequent `StudentStateStore.read(at: stateURL)` returns `.loaded` with that exact state
  (`Equatable`-equal); `events == [.platformStateWritten]`.
- AC4 (brief item 4, W7 reconciliation — MCR3U.u9 + negative control + MHF4U variant, arbiter-03 § Q-A test
  obligation): over a seeded `StudentState` whose `marker == Marker(courseCode: "MCR3U", unitId: "MCR3U.u9",
  pastLastUnit: nil)` (`MCR3U.u9` confirmed absent from `data/demo/courses.json`'s `MCR3U.units` — only
  `MCR3U.u1`, `.u2`, `.u3` exist, re-read in this run) persisted at `stateURL`:
  - `MapLaunch.open(snapshotDir: <data/demo>, stateURL:, today:)` returns `.ready(map:, messages: [], events:)`
    where `map.state.marker == MarkerTrail.defaultMarker(syllabi: ["MCR3U"], bundle:)`;
  - `map.state.nodes` is byte-equal (`Equatable`) to the seeded state's `nodes`;
  - `messages == []`;
  - `stateURL`'s file bytes are unchanged after the call (load never writes, arbiter-03 § Q-A precision 3);
  - **negative control**: the identical seed with `marker.unitId` replaced by `"MCR3U.u1"` (a real unit)
    produces `.ready` with `map.state.marker == Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit:
    nil)` unchanged — no reconciliation branch fires;
  - **MHF4U variant**: the same seed shape with `syllabi == ["MHF4U"]` (confirmed absent from
    `data/demo/courses.json`'s `courses[]` — only `MTH1W`, `MCR3U` exist, re-read in this run) produces
    `.courseSelectionNeeded(bundle:, messages: [])`.
- AC5 (node panel content, map W2, I6): `nodePanelContent(nodeId:, mapState:)` for a node with ≥ 1
  `expectationCodes` entry returns `paraphrase == bundle node's paraphrase`, each `expectationCodeLinks` entry's
  `officialUrl` equal to the matching `courses.json` `Expectation.officialUrl`, `masteryLabel` one of exactly
  `"under fog"` / `"cleared"` / `"blocked — something upstream is in the way"` per the node's mastery, and no
  field anywhere equal to any `Node`/`Course` field not in `{name, paraphrase, expectationCodes, officialUrl}`
  (no Ministry `verbatim` text, none exists in the model to begin with — 03.4's decode already excludes it).
- AC6 (region panel content, map W3): `regionPanelContent(regionId:, mapState:)` for a `horizon` region returns
  `nil` (not tappable); for a content region returns `about`, `clearedFraction` equal to `mapState.viewModel
  .regions[region].clearedFraction`, and `courseCodesCrossingHere` derived only from `mapState.state.trail`'s
  `course`-kind segments.
- AC7 (landmark panel content, map W4, I15): `landmarkPanelContent(landmarkId:, mapState:)` over `data/demo`'s
  one landmark (`canadian-mortgage-compounding`) returns `whatItIs`, `sourceUrl` non-empty, and `nodeIds ==
  ["exponent-laws", "exponential-functions"]` (byte-verified against `data/demo/landmarks.json` in this run).
- AC8 (brief item 7, marker from the unit list, D45; interaction-contract § 3). All cases run over real
  `data/demo`, on a `MapState` built by `selectCourse(courseCode: "MTH1W", …)`. MTH1W's `units[]` are
  `MTH1W.u1…u4` in order (`data/demo/courses.json:99,108,116,125`, re-read in this run).
  - **In-course move:** `setMarker(unitId: "MTH1W.u2", pastLastUnit: false, mapState:, today:)` calls
    `MarkerTrail.setMarker`. It returns a `MapState` whose `.state.marker == Marker(courseCode: "MTH1W",
    unitId: "MTH1W.u2", pastLastUnit: false)`, whose `.state.trail` is the regenerated trail, and whose
    `.viewModel` is re-derived over it. Nodes upstream of the new marker keep their stored mastery
    (`MapViewModel`'s own rule, consumed not re-derived). `events` contains `.expeditionMarkerChanged`,
    `.expeditionTrailGenerated`, `.platformStateWritten` and `.mapMarkerMoved`, in that order. A subsequent
    `MapLaunch.open` over the same `stateURL` (simulating relaunch) returns `.ready` with `map.state.marker`
    and `map.state.trail` unchanged (`Equatable`-equal) from what `setMarker` returned.
  - **Past the last unit, from a non-last unit:** `setMarker(unitId: "MTH1W.u2", pastLastUnit: true, …)`
    returns `.state.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)`. The
    `unitId` argument is replaced by the course's last unit, per the contract: "setting it writes the course's
    last unit as `unit_id`". The test computes the expected id from the bundle
    (`bundle.courses.courses.first { $0.courseCode == "MTH1W" }?.units.last?.unitId`). It first asserts that
    this id is non-nil and `!= "MTH1W.u2"` (empty=FAIL: a nil lookup fails the test). A subsequent
    `StudentStateStore.read(at: stateURL)` returns `.loaded` with `marker.unitId == "MTH1W.u4"` and
    `marker.pastLastUnit == true`, which is the persisted form. A subsequent `MapLaunch.open` returns `.ready`
    with `map.state.marker` unchanged, so the persisted marker is on the trail and no reconciliation fires.
  - **Negative control:** the in-course move above is the control. With `pastLastUnit: false`, the same
    `unitId: "MTH1W.u2"` persists unchanged. So the substitution is gated on the flag and not applied to
    every call.
  - **Instrument:** Swift Testing `#expect` in `MapFacadeTests.swift`, run on the simulator. It runs over
    the real `MarkerTrail.setMarker` (02.5b-corrected), not a stub. It excludes the App's unit-list screen
    (03.11).
- AC9 (brief item 7, later course change, Q-E): `selectCourse(courseCode: "MCR3U", bundle:, stateURL:,
  previousState: <a state with syllabi ["MTH1W"] and ≥ 1 cleared node>, today:)` returns a `MapState` whose
  `.state.syllabi == ["MCR3U"]`, `.state.marker == MarkerTrail.defaultMarker(syllabi: ["MCR3U"], bundle:)`, and
  `.state.nodes` **unchanged** (`Equatable`-equal to `previousState.nodes` — mastery kept, arbiter-03 § Q-E).
- AC10 (brief item 10, hand-off — Check me here): `checkHere(nodeId:, mapState:)` on a `blocked` node of real
  `data/demo` returns `(event: DiagnosisEvent(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1),
  events: [.mapCheckHereRequested])`; no `StudentState` mutation; no throw.
- AC11 (brief item 10, hand-off — Unit expedition): `unitExpedition(unitId:, mapState:, today:)` on a unit with
  ≥ 1 fringe node returns a `ComposeResult` whose `.newLearning`-kind slots are drawn only from that unit's
  resident nodes plus unconditionally-eligible `blocked` nodes (delegated verbatim to `Expedition.compose
  (unitExpeditionUnitId:)`, not re-derived), and `events == [.mapUnitExpeditionRequested]`; on a unit/state
  combination with an empty fringe and no due node, throws `CoreError.expNoFringe`.
- AC12 (brief item 10, hand-off — Include, Q-D): `include(nodeId:, mapState:)` on a `fog` node whose
  `MapViewModel.NodeView.action == .include` returns `(mapState': mapState with queuedNodeId == nodeId,
  outcome: .queued, events: [.mapIncludeRequested])`; a **second** `include` call with a different eligible
  node id **replaces** the queue (the first id is gone from `mapState''.queuedNodeId`); a real
  `Expedition.compose(..., queuedNodeId: mapState.queuedNodeId, ...)` afterward places the queued id as slot 0
  of `.newLearning` kind when it is still on the fringe; `include` on a node whose `NodeView.action != .include`
  (upstream, or neither fringe nor upstream, or already `cleared`) returns `outcome: .ignored`, `mapState'
  .queuedNodeId` unchanged from the input, `events == []`, and throws nothing; the queue is never present in any
  `StudentState` field (`Equatable`-checked: two `MapState`s with the same `.state` but different `.queuedNodeId`
  still round-trip to the identical written JSON via `StudentStateStore.write`).
- AC13 (save-after-every-action + missed-write negative control, arbiter-03 § Q-F): a table-driven test calls
  `selectCourse` then `setMarker` against a temp-directory `stateURL`, asserting a `StudentStateStore.write` (or
  its observable effect — the file's bytes) follows each call; a negative control makes `stateURL`'s containing
  directory read-only before calling `setMarker`, asserting the call throws `CoreError.platformStateWriteFailed`
  and the caller's previously-held `MapState` is never replaced (the function does not return — Swift's throw
  semantics make "the old `MapState` stays in place" the App's own natural behavior, verified here by asserting
  the file at `stateURL` is byte-unchanged from before the failed call).
- AC14 (event-name conformance, §5 in-scope names): a single test enumerates every façade action this task
  ships and asserts its returned `events` is a subset of, and where the domain doc requires an event, contains
  exactly, `{map.opened, map.node_opened, map.region_opened, map.landmark_opened, map.marker_moved, map.check
  _here_requested, map.include_requested, map.unit_expedition_requested, platform.launched, platform.state
  _written}` plus the pre-existing `expedition.marker_changed` / `expedition.trail_generated` cases `Marker
  Trail.setMarker` itself already emits (03.7 does not invent a new `CoreEvent` case; `Events/CoreEvent.swift`
  is unmodified, per §2).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — CREATE. `MapLaunch.open`, `LaunchOutcome`, `MapState`,
  `MapFacade` (panel content, `selectCourse`, `setMarker`, `include`, `unitExpedition`, `checkHere`), and every
  panel-content / outcome value type (§4). Confirmed absent (context bundle §E: `Glob **/MapLaunch.swift`
  returned no match).
- `Packages/Core/Tests/CoreTests/MapLaunchTests.swift` — CREATE. AC1–AC4 (launch outcomes, W7 reconciliation
  incl. the MCR3U.u9 case, its negative control and the MHF4U variant).
- `Packages/Core/Tests/CoreTests/MapFacadeTests.swift` — CREATE. AC5–AC14 (panel content, `selectCourse`,
  `setMarker`, `include`, `unitExpedition`, `checkHere`, save-after-every-action, event-name conformance).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/CoreError.swift` — task 03.3's file, a `depends_on` precondition; `platform
  StateUnreadable`, `platformStateWriteFailed` and `platformSnapshotRefused` are already landed cases by the
  time this task runs (03.3 is a transitive dependency of 03.4 and 03.5, both direct `depends_on` entries).
  **Correction to the context bundle §F**, which listed `CoreError.swift` as a MODIFY target for this task: task
  03.3's own spec states "This is the only task in EPIC 03 that writes `CoreError.swift`"
  (`tasks/epic-03-task-03-core-error-surface-text-mirror.md` §1, re-read in this run), and tasks 03.4 §2 / 03.5
  §2 both independently mark the file out-of-scope for the same reason. This task reads the three cases,
  defines none of them.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — read-only; every event name this task emits is already
  a case (re-read and byte-compared in this run, §3).
- `Packages/Core/Sources/Core/Platform/BundleLoader.swift`, `Packages/Core/Sources/Core/Platform/StudentState
  Store.swift`, `Packages/Core/Sources/Core/Map/MapViewModel.swift` — 03.4's, 03.5's and 03.6's files
  respectively; call their public entry points only.
- `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`, `Packages/Core/Sources/Core/State/Expedition
  .swift` — read-only; call `MarkerTrail.setMarker` / `.reconcileMarker` / `.reconcileNodeIds` /
  `.defaultMarker` and `Expedition.compose` (all public) only. Neither file's `private` helpers are touched,
  widened or reimplemented. `MarkerTrailGeneration.swift`'s past-last-unit substitution is task 02.5b's
  change, landed on EPIC 02b before this task runs. It is not this task's.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — not this task's; call `DiagnosisRun.open` (the
  02.11 precondition, public, pure construction) only. This task never calls `.start` / `.decideProbe` /
  `.answerProbeItem` / `.decideFurtherLevel` / `.run` (arbiter-02-11 Ruling 1, 3).
  `Packages/Core/Sources/Core/Model/*.swift` — read-only; no field added, no type added.
- `App/Sources/**` — no App code; 03.9's source scan and 03.11/03.12's screens consume this task's public
  surface in EPIC 03b.
- `contracts/**`, `data/demo/**`, `docs/**` — read-only ground truth.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition`:
  > `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  > cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  > requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on
  > the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
  > `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

  Source: `contracts/interaction-contract.md:31-36` (re-read, byte-compared in this run). Binds `unitExpedition`
  (AC11, delegated to `Expedition.compose(unitExpeditionUnitId:)`, not re-derived) and `include` (AC12, the
  `queuedNodeId` parameter of the next real `compose`).

- `contracts/interaction-contract.md` — heading `## 3. Marker and trail (D45, D47)`:
  > `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
  > selected course. Nodes upstream of the marker keep their mastery.
  > The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
  > names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
  > `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
  > when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
  > not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
  > (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

  Source: `contracts/interaction-contract.md:64-71` (v0.9.1, re-read in the arbitration run). This is the
  full contiguous bullet. Binds `setMarker` (AC8) and `MapLaunch.open`'s W7 reconciliation branch (AC4). For
  `pastLastUnit: true`, the persisted `unit_id` is the course's last unit. `MarkerTrail.setMarker` enforces
  this **only as corrected by task 02.5b** (`tasks/epic-02-task-05b-fix-set-marker-past-last-unit.md` §4). The
  02.5-landed body (`MarkerTrailGeneration.swift:94`) does not, which is why 02.5b is in `depends_on`.
  `MapFacade.setMarker` passes the caller's `unitId` through and relies on that single source.

- `contracts/data-model.md` — heading `### StudentState (student-state.schema.json)`, `past_last_unit`
  paragraph:
  > `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the
  > course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must
  > still name a unit of the course.

  Source: `contracts/data-model.md:139-141` (re-read in the arbitration run). Binds AC8's persisted-form
  assertion (`StudentStateStore.read` shows `unitId == "MTH1W.u4"`).

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis`:
  > `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).

  Source: `contracts/interaction-contract.md:80` (re-read, byte-compared in this run). Binds `checkHere` (AC10):
  `DiagnosisRun.open(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1)`, pure construction (arbiter-
  02-11 Ruling 1, 3).

- `contracts/interaction-contract.md` — heading `## 5. Notifications`:
  > `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved · map.check
  > _here_requested · map.include_requested · map.unit_expedition_requested · expedition.started · expedition
  > .item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition
  > .marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened · diagnosis
  > .hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped · diagnosis
  > .remediation_shown · diagnosis.returned · platform.launched · platform.content_updated · platform.state
  > _migrated · platform.state_written · platform.sync_completed · platform.sync_conflict_merged · platform
  > .capability_facts · platform.connectivity_changed · tier.capability_detected · tier.classification_returned
  > · tier.fallback_decided · tier.wording_adapted · telemetry.consent_changed · telemetry.batch_sent ·
  > telemetry.batch_failed · learning_objects.bundle_loaded · learning_objects.hint_tier_served · graph
  > .prerequisite_returned

  Source: `contracts/interaction-contract.md:102-112` (re-read, byte-compared in this run). Binds AC14: the
  façade emits only names from this set, matched against `CoreEvent` cases (§3's `CoreEvent.swift` quote below).

- `contracts/content-policy.md` — Grade 9–12 tier policy (I6):
  > A node or expectation carries codes + the project's own `paraphrase` + an `official_url`. No field anywhere
  > holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate).

  Source: `contracts/content-policy.md:9-13` (re-read, byte-compared in this run). Binds AC5.

- `contracts/content-policy.md` — Landmarks rule (I15):
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required …
  > ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

  Source: `contracts/content-policy.md:40-45` (re-read, byte-compared in this run). Binds AC7.

Domain-doc excerpts (verbatim):

- `docs/domains/map.md` — heading `### W2 — Tap a node`:
  > **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the
  > official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream is
  > in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one
  > action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the
  > marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do.
  > **Post:** no state change; `map.node_opened` emitted.

  Source: `docs/domains/map.md:71-77` (re-read, byte-compared in this run). Binds AC5. Step 2's action-by-state
  is 03.6's `NodeView.action`, consumed here, never re-derived.

- `docs/domains/map.md` — heading `### W3 — Tap a region`:
  > **Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction
  > cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region
  > _opened`.

  Source: `docs/domains/map.md:79-81` (re-read, byte-compared in this run). Binds AC6.

- `docs/domains/map.md` — heading `### W4 — Tap a landmark`:
  > **Pre:** map open. **Steps:** open the **landmark panel**: name, `what_it_is`, the source link (I15), and
  > "which parts of the map this touches" as jump links, one per linked node, each landing on W2 for that node.
  > **Post:** `map.landmark_opened` emitted (a D40 event).

  Source: `docs/domains/map.md:83-86` (re-read, byte-compared in this run). Binds AC7.

- `docs/domains/map.md` — heading `### W5 — Set the course-progress marker` (edited per arbiter-03 § Q-B):
  > 1. Show the course's **unit list** (curriculum-spine `Unit`s, D45) with the current one highlighted; the
  > student picks "we are here in class". The marker is set from this list only; there is no drag
  > (interaction-contract v0.9.2 § 3). 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns
  > the change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes
  > the fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your
  > class" note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40
  > event).

  Source: `docs/domains/map.md:88-95` (re-read, byte-compared in this run). Binds AC8: "state is persisted,
  `map.marker_moved` is emitted" fixes this task's event order (§4.4, §6). Step 2 ("Hand the unit id to
  **expedition** … which owns the change") is why the last-unit substitution lives in `MarkerTrail.setMarker`
  (expedition W6), not in this map façade.

- `docs/domains/expedition.md` — heading `### W6 — Set the course-progress marker`:
  > **Pre:** `map.marker_moved` with a unit of the selected course. **Steps:** set the marker; regenerate the
  > Trail (W8); recompute the Fringe; nodes newly upstream keep whatever mastery they had (a cleared node stays
  > cleared). **Post:** persisted; `expedition.marker_changed` emitted → map, telemetry (D40).

  Source: `docs/domains/expedition.md:105-108` (re-read in the arbitration run). Binds AC8 (expedition sets
  the marker; the façade persists and notifies).

- `docs/domains/map.md` — `## Open questions`, the bold paragraph **"Q5 — Can the student add a fogged node to
  the next expedition from the panel?"** (there is no `### Q5` heading; orchestrator correction of a fabricated
  heading label; the quoted Default text is unchanged):
  > **Default:** yes, one node, queued ahead of the scheduler's pick if it is on the fringe; ignored with a
  > plain message if it is upstream of the marker (D45 — that way in is "Check me here"). **Trade-off:** gives
  > the map a reason to be tapped; a queue longer than one is scheduling policy the student should not have to
  > manage.

  Source: `docs/domains/map.md:170-174` (re-read, byte-compared in this run). Binds AC12.

- `docs/domains/expedition.md` — heading `### W7 — Resume after relaunch`:
  > **Pre:** app launch; a `StudentState` file exists (or an iCloud copy). **Steps:** platform reads and
  > migrates (its W4); this domain validates node ids against the installed bundle — ids no longer in the graph
  > are kept in the file but ignored (`EXP_NODE_NOT_IN_GRAPH`), never deleted. **Post:** state loaded; the map
  > opens (map W1).

  Source: `docs/domains/expedition.md:119-123` (re-read, byte-compared in this run). Binds AC1/AC4:
  `reconcileNodeIds`'s ignored ids stay in `StudentState.nodes` and are never surfaced as a message (same
  silent-load-path treatment as `MAP_MARKER_OFF_TRAIL`, per arbiter-03 § Q-A's "the App never branches on a
  code"; §6 decision default).

- `docs/domains/platform.md` — heading `### W1 — Launch`, step 4 (final sentence):
  > 4. Hand control to **map** W1. Tier 0. **Post:** `platform.launched` emitted.

  Source: `docs/domains/platform.md:54` (re-read, byte-compared in this run). Binds AC1/AC2's event-emission
  split (§6 decision default: `platform.launched` fires once `BundleLoader.load` succeeds, never on `.refused`).

Arbiter rulings (verbatim, all re-read and byte-compared in this run):

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-A, ruling paragraph 1–3:
  > 1. **No student text on the W7 load path.** … `Core`'s launch outcome carries the reconciliation code as
  >    internal diagnostics. The list of messages the App must display is computed **in `Core`** and is empty
  >    for this code on this path. The App shows what `Core` hands it and never branches on a code itself.
  > 2. **The second `reconcileMarker` branch.** When no course in `syllabi[]` resolves in the bundle,
  >    `reconcileMarker` returns the **unchanged** stored marker with `.mapMarkerOffTrail`. So there is no
  >    default marker to open the map on. The launch outcome is then "course selection needed" (Q-E), with no
  >    student text either.
  > 3. **No write on load.** Reconciliation changes the in-memory state only. The file keeps its stored marker
  >    until the next state-changing action writes the whole document.

  Binds AC4's whole structure (both the resolved-fallback and unresolvable-course branches, and the no-write
  assertion).

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-D, ruling paragraph:
  > CONFIRMED. The queue is one in-memory node id held by the `Core` façade value (Q-F), passed to the next
  > `Expedition.compose(queuedNodeId:)` and not persisted. … A later Include **replaces** the queued id … the id
  > is consumed by the next `compose` call whether or not it was still on the fringe … An Include on a node
  > upstream of the marker returns a typed "ignored, upstream of the marker" outcome with **no student text**
  > and no new code … **Gap in the brief, closed here:** … A fogged node that is neither on the fringe nor
  > upstream of the marker … offers no action.

  Binds AC12.

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-E, ruling bullets:
  > - **Launch outcome.** The `Core` launch entry returns one of three outcomes: `ready(bundle, state,
  >   viewModel, messages)`; `courseSelectionNeeded(bundle, messages)` …; `refused(code)`.
  > - **First state.** … Choosing a course calls a `Core` façade function that builds the first state and
  >   persists it, then derives the view model: `schema_version` 2 and `format_version_seen` = the bundle's
  >   `format_version`; `syllabi = [course]` and `marker = defaultMarker(syllabi:bundle:)`; `trail` from
  >   `generateTrail`, `nodes` empty (every node `fog`), both logs empty; `install_day` = injected today, and
  >   `consent_on = true`.
  > - **Changing course later.** The same picker calls the same façade, replacing `syllabi` and the marker
  >   together (never an off-trail result, Q-A). Mastery is kept.

  Binds AC1, AC3, AC9. The `LaunchOutcome` case shape (`ready`/`courseSelectionNeeded`/`refused`) is realised
  here as `LaunchOutcome.ready(map: MapState, messages: [String], events: [CoreEvent])` etc. (§4.1) — `bundle`
  and `viewModel` are folded into the single `MapState` value per the Q-F boundary quote below, so the App holds
  one type, not four loose values.

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "The boundary, precisely", item 4:
  > **The façade.** Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a
  > `CoreError`. — The persist-after-every-state-changing-action sequencing lives here too: a `Core` session
  > type whose actions write to the injected URL. … The list of student messages to display (Q-A, Q-C, Q-E) is
  > computed here, as registry codes.

  Binds the whole façade shape and `LaunchOutcome.messages: [String]`'s registry-code (not text) content.

- `tasks/arbitration/arbiter-03-07-past-last-unit.md` § Ruling: the past-last-unit substitution is enforced
  once, in `MarkerTrail.setMarker` (task 02.5b). `MapFacade.setMarker` passes `unitId` through unchanged and
  does not compute the last unit. Binds §4.4 and AC8.

- Planner note (`docs/plans/epic-03-plan.md` "Planner notes kept for spec writers"):
  > Glossary: never use "session", "start marker", "cursor", "profile" or "save" in new identifiers or copy.

  Binds the type name `MapState` (never "`MapSession`" or "`Session`") used throughout this task's product code,
  tests and this spec's own prose, per the dispatch instruction's own example name.

- `CLAUDE.md` — I14 (system rules table):
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Prior signatures this task builds on (verbatim, re-read against the current tree in this session):

```swift
// Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift:55-57, 91-99, 103-111, 118-128, 132-139
public static func generateTrail(
    syllabi: [String], marker: Marker, bundle: ContentBundle
) throws -> TrailGenerationReport
// Signature unchanged by 02.5b. After 02.5b, `pastLastUnit: true` ⇒ the returned marker's unitId is the
// course's `units.last` (whatever `unitId` is passed); `pastLastUnit: false` ⇒ `unitId` passes through.
public static func setMarker(
    courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
) throws -> SetMarkerResult
public static func defaultMarker(syllabi: [String], bundle: ContentBundle) -> Marker?
public static func reconcileMarker(
    _ marker: Marker, syllabi: [String], bundle: ContentBundle
) -> MarkerReconciliationResult
public static func reconcileNodeIds(
    nodes: [String: NodeState], bundle: ContentBundle
) -> NodeIdReconciliationResult

public struct SetMarkerResult: Equatable {
    public let marker: Marker
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let events: [CoreEvent]   // [.expeditionMarkerChanged, .expeditionTrailGenerated]
}
public struct MarkerReconciliationResult: Equatable {
    public let marker: Marker
    public let code: CoreError?      // .mapMarkerOffTrail when off-trail
}
public struct NodeIdReconciliationResult: Equatable {
    public let ignoredNodeIds: [String]
    public let code: CoreError?      // .expNodeNotInGraph when non-empty
}
```

```swift
// Packages/Core/Sources/Core/State/Expedition.swift:35-43, 21-24, 93-95
public static func compose(
    state: StudentState, bundle: ContentBundle, trail: Trail, marker: Marker, today: CalendarDay,
    queuedNodeId: String? = nil, unitExpeditionUnitId: String? = nil
) throws -> ComposeResult
public struct ComposeResult: Equatable {
    public let slots: [ComposeSlot]
    public let skippedNodeIds: [String]
}
public struct ComposeSlot: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind   // .newLearning or .review
}
```

```swift
// Packages/Core/Sources/Core/Events/CoreEvent.swift:8-49 (full file, re-read in this run — every case this
// task uses is already present, no edit to this file)
public enum CoreEvent: String, CaseIterable, Equatable {
    case mapOpened = "map.opened"
    case mapNodeOpened = "map.node_opened"
    case mapRegionOpened = "map.region_opened"
    case mapLandmarkOpened = "map.landmark_opened"
    case mapMarkerMoved = "map.marker_moved"
    case mapCheckHereRequested = "map.check_here_requested"
    case mapIncludeRequested = "map.include_requested"
    case mapUnitExpeditionRequested = "map.unit_expedition_requested"
    // … (expedition.*, diagnosis.*, tier.*, telemetry.*, learning_objects.*, graph.* cases unaffected)
    case expeditionMarkerChanged = "expedition.marker_changed"
    case expeditionTrailGenerated = "expedition.trail_generated"
    case platformLaunched = "platform.launched"
    case platformStateMigrated = "platform.state_migrated"
    case platformStateWritten = "platform.state_written"
}
```

```swift
// Packages/Core/Sources/Core/Platform/BundleLoader.swift (task 03.4's spec, §3 "Types")
public struct BundleRefusal: Error, Equatable {
    public let internalCode: CoreError
    public let report: L0Report?
    public var studentCode: CoreError { .platformSnapshotRefused }
}
public enum BundleLoader {
    public static func load(from directory: URL) throws -> (bundle: ContentBundle, report: L0Report)
}
```

```swift
// Packages/Core/Sources/Core/Platform/StudentStateStore.swift (task 03.5's spec, §4.1)
public enum StudentStateStore {
    public enum ReadResult: Equatable {
        case absent
        case loaded(StudentState, migratedFrom: Int?)
    }
    public static func read(at url: URL) throws -> (result: ReadResult, events: [CoreEvent])
    public static func write(_ state: StudentState, to url: URL) throws -> [CoreEvent]
}
```

```swift
// Packages/Core/Sources/Core/Map/MapViewModel.swift (task 03.6's spec, §4 step 2, 3, 6)
public struct MapViewModel: Equatable {
    public let regions: [RegionView]
    public let nodes: [NodeView]
    public let rivers: [River]
    public let trailSegments: [TrailSegmentView]
    public let positionIndicatorNodeId: String?
    public let landmarks: [LandmarkView]
    public let focusFrame: FocusFrame
}
public struct RegionView: Equatable { public let id: RegionId; public let horizon: Bool
    public let clearedFraction: Double? }
public enum NodeAction: Equatable { case checkHere, include }
public struct NodeView: Equatable {
    public let id: String
    public let regionId: RegionId
    public let position: Point
    public let fogLevel: Mastery
    public let due: Bool
    public let upstream: Bool
    public let action: NodeAction?
}
public struct LandmarkView: Equatable { public let id: String; public let position: Point
    public let nodeIds: [String] }
public static func derive(bundle: ContentBundle, state: StudentState, today: CalendarDay) -> MapViewModel
```

```swift
// Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift (task 02.11's landed spec, arbiter-02-11
// -stepwise-api.md § Ruling 1 — the EPIC 02b precondition this task's `checkHere` calls, unchanged by this task)
public enum DiagnosisTrigger: String, Equatable { case expeditionSecondMiss = "expedition_second_miss"
    case mapCheckHere = "map_check_here" }
public struct DiagnosisEvent: Equatable {
    public let originNodeId: String
    public let trigger: DiagnosisTrigger
    public let levelBudget: Int
}
public enum DiagnosisRun {
    public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent
}
```

```swift
// Packages/Core/Sources/Core/Model/StudentState.swift:10-27 (re-read, byte-compared in this run)
public struct StudentState: Codable, Equatable {
    public let schemaVersion: Int
    public let formatVersionSeen: String
    public let syllabi: [String]
    public let marker: Marker
    public let nodes: [String: NodeState]
    public let trail: Trail
    public let expeditionLog: [ExpeditionLogEntry]
    public let probeLog: [ProbeLogEntry]
    public let installDay: String
    public let consentOn: Bool
}
public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String
    public let pastLastUnit: Bool?
}
```

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift:9-25, Courses.swift:9-31, Landmarks.swift:11-20 (re-read in
// this run — the exact field names §4's panel content builders read)
public struct Node: Codable, Equatable {
    public let id: String
    public let name: String
    public let regionId: RegionId
    public let expectationCodes: [NodeExpectationCode]?
    public let paraphrase: String
    // …
}
public struct NodeExpectationCode: Codable, Equatable { public let courseCode: String; public let code: String }
public struct Course: Codable, Equatable {
    public let courseCode: String
    public let expectations: [Expectation]
    // …
}
public struct Expectation: Codable, Equatable {
    public let code: String
    public let officialUrl: String
    public let unitId: String
    // …
}
public struct Landmark: Codable, Equatable {
    public let id: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
    // …
}
```

```swift
// Packages/Core/Sources/Core/Model/Manifest.swift:4-12, BundleIO.swift:8-16 (re-read in this run)
public struct Manifest: Codable, Equatable { public let formatVersion: String; /* … */ }
public struct ContentBundle {
    public let manifest: Manifest
    public let regions: RegionsFile
    public let nodes: NodesFile
    public let edges: EdgesFile
    public let courses: CoursesFile
    public let landmarks: LandmarksFile
    public let sources: SourcesFile
}
```

Data re-read this session (`data/demo/courses.json`, verbatim structure, not citation text — verifies AC4's
and AC8's fixtures):

- `MCR3U.units` = `["MCR3U.u1", "MCR3U.u2", "MCR3U.u3"]` — `"MCR3U.u9"` is absent.
- `MTH1W.units` = `["MTH1W.u1", "MTH1W.u2", "MTH1W.u3", "MTH1W.u4"]` (`courses.json:99,108,116,125`) — the last
  unit is `"MTH1W.u4"`.
- `courses[].course_code` = `["MTH1W", "MCR3U"]` — `"MHF4U"` is absent (it is only named in `MCR3U.next
  _courses`, never itself a course entry).
- `data/demo/landmarks.json`'s one landmark: `id: "canadian-mortgage-compounding"`, `node_ids:
  ["exponent-laws", "exponential-functions"]`, `source_url` present (verified in 03.6's own already-written
  spec, re-confirmed here).

Gate commands (`scripts/gate.sh:16-18`, re-read in this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by every sibling task file re-read in this run): Swift Testing (`import Testing`,
`@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

Layer placement: layer ④ interaction (Door C, the map). `MapLaunch.swift` composes layer ① (`courses.json` via
`ContentBundle.courses`), layer ② (`GraphIndex`/`MarkerTrail`/L0 via `BundleLoader`), and layer ③ (landmarks)
strictly through the public entry points of 03.4/03.5/03.6/02a/02.5b/02.11 — it adds no new graph, layout, L0
or marker logic of its own.

### 4.1 `LaunchOutcome` and `MapState` — public shape

```swift
import Foundation

/// The App's one handle onto a live map: everything a façade action needs, and everything the render layer may
/// read. Never called "session" (glossary rule, `docs/plans/epic-03-plan.md` planner note). Replaced wholesale
/// by the App's `@Observable` holder after every façade call — never partially mutated by App code.
public struct MapState {
    public let bundle: ContentBundle
    public let stateURL: URL
    public let state: StudentState
    public let viewModel: MapViewModel
    /// Q-D: the one in-memory "Include" queue slot. Never written to `stateURL`; absent from every
    /// `StudentState` field (`StudentState`'s schema has no queue key — adding one would be a data-model BUMP).
    public let queuedNodeId: String?
}

/// `MapLaunch.open`'s result. `messages` are registry code strings (e.g. `"PLATFORM_STATE_UNREADABLE"`), never
/// resolved text — 03.11's later call to `CoreErrorText.userText` resolves them (arbiter-03 § Q-F: "computed
/// here, as registry codes").
public enum LaunchOutcome {
    case ready(map: MapState, messages: [String], events: [CoreEvent])
    case courseSelectionNeeded(bundle: ContentBundle, messages: [String], events: [CoreEvent])
    case refused(BundleRefusal)
}
```

`ContentBundle` is not `Equatable` (03.4 §3, confirmed by reading the type in this run), so neither `MapState`
nor `LaunchOutcome` conforms to `Equatable`; every test asserts on individual fields (`.state`, `.viewModel`,
`.marker`, …), all of which are themselves `Equatable`.

### 4.2 `MapLaunch.open(snapshotDir:stateURL:today:)`

```swift
public enum MapLaunch {
    public static func open(snapshotDir: URL, stateURL: URL, today: CalendarDay) -> LaunchOutcome {
        let bundle: ContentBundle
        do {
            (bundle, _) = try BundleLoader.load(from: snapshotDir)
        } catch let refusal as BundleRefusal {
            return .refused(refusal)
        } catch {
            // BundleLoader.load's only documented throw type is BundleRefusal (03.4 §3); this branch exists
            // only as a defensive, never-exercised fallback and is asserted unreachable by §5 T2.
            return .refused(BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil))
        }

        let readResult: StudentStateStore.ReadResult
        var events: [CoreEvent] = [.platformLaunched]
        do {
            let (result, readEvents) = try StudentStateStore.read(at: stateURL)
            readResult = result
            events += readEvents
        } catch {
            return .courseSelectionNeeded(
                bundle: bundle, messages: ["PLATFORM_STATE_UNREADABLE"], events: events)
        }

        guard case .loaded(let loadedState, _) = readResult else {
            return .courseSelectionNeeded(bundle: bundle, messages: [], events: events)
        }

        let markerRecon = MarkerTrail.reconcileMarker(
            loadedState.marker, syllabi: loadedState.syllabi, bundle: bundle)
        if markerRecon.code == .mapMarkerOffTrail && markerRecon.marker == loadedState.marker {
            // Q-A precision 2: no course in syllabi[] resolves — no default marker to fall back to.
            return .courseSelectionNeeded(bundle: bundle, messages: [], events: events)
        }

        var effectiveState = loadedState
        if markerRecon.marker != loadedState.marker {
            // Q-A precision 3: in-memory only — never written back to stateURL by this function.
            if let report = try? MarkerTrail.generateTrail(
                syllabi: loadedState.syllabi, marker: markerRecon.marker, bundle: bundle)
            {
                effectiveState = StudentState(
                    schemaVersion: loadedState.schemaVersion, formatVersionSeen: loadedState.formatVersionSeen,
                    syllabi: loadedState.syllabi, marker: markerRecon.marker, nodes: loadedState.nodes,
                    trail: report.trail, expeditionLog: loadedState.expeditionLog,
                    probeLog: loadedState.probeLog, installDay: loadedState.installDay,
                    consentOn: loadedState.consentOn)
            }
        }
        // reconcileNodeIds: ignored ids stay in effectiveState.nodes unchanged (W7: "kept … never deleted");
        // its .expNodeNotInGraph code, like .mapMarkerOffTrail, never enters `messages` on the load path
        // (§6 decision default — the same silent-load-path treatment, since W7 names no student-facing text
        // for it either).
        _ = MarkerTrail.reconcileNodeIds(nodes: effectiveState.nodes, bundle: bundle)

        let viewModel = MapViewModel.derive(bundle: bundle, state: effectiveState, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: effectiveState, viewModel: viewModel,
            queuedNodeId: nil)
        return .ready(map: map, messages: [], events: events + [.mapOpened])
    }
}
```

`.platformStateMigrated` (if `StudentStateStore.read` migrated a v1 file) rides through in `readEvents`, already
included in `events` before either return path — no separate handling needed.

### 4.3 `MapFacade` — panel content (map W2, W3, W4; no state mutation, no persistence)

```swift
public struct ExpectationCodeLink: Equatable {
    public let courseCode: String
    public let code: String
    public let officialUrl: String
}
public struct NodePanelContent: Equatable {
    public let nodeId: String
    public let name: String
    public let paraphrase: String
    public let expectationCodeLinks: [ExpectationCodeLink]
    public let masteryLabel: String
    public let courseCodesCrossingHere: [String]
    public let landmarkIds: [String]
}
public struct RegionPanelContent: Equatable {
    public let regionId: RegionId
    public let name: String
    public let about: String
    public let clearedFraction: Double?
    public let courseCodesCrossingHere: [String]
}
public struct LandmarkPanelContent: Equatable {
    public let landmarkId: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
}

public enum MapFacade {
    public static func nodePanelContent(
        nodeId: String, mapState: MapState
    ) -> (content: NodePanelContent, events: [CoreEvent])? {
        guard let node = mapState.bundle.nodes.nodes.first(where: { $0.id == nodeId }),
            let nodeView = mapState.viewModel.nodes.first(where: { $0.id == nodeId })
        else { return nil }

        let links = (node.expectationCodes ?? []).compactMap { entry -> ExpectationCodeLink? in
            guard let course = mapState.bundle.courses.courses.first(where: { $0.courseCode == entry.courseCode }),
                let expectation = course.expectations.first(where: { $0.code == entry.code })
            else { return nil }
            return ExpectationCodeLink(
                courseCode: entry.courseCode, code: entry.code, officialUrl: expectation.officialUrl)
        }
        let masteryLabel: String
        switch nodeView.fogLevel {
        case .fog: masteryLabel = "under fog"
        case .cleared: masteryLabel = "cleared"
        case .blocked: masteryLabel = "blocked — something upstream is in the way"
        }
        let courseCodes = mapState.state.trail.segments
            .filter { $0.kind == .course && $0.nodeIds.contains(nodeId) }
            .compactMap(\.courseCode)
        let landmarkIds = mapState.bundle.landmarks.landmarks
            .filter { $0.nodeIds.contains(nodeId) }.map(\.id)

        let content = NodePanelContent(
            nodeId: nodeId, name: node.name, paraphrase: node.paraphrase, expectationCodeLinks: links,
            masteryLabel: masteryLabel, courseCodesCrossingHere: courseCodes, landmarkIds: landmarkIds)
        return (content, [.mapNodeOpened])
    }

    public static func regionPanelContent(
        regionId: RegionId, mapState: MapState
    ) -> (content: RegionPanelContent, events: [CoreEvent])? {
        guard let region = mapState.bundle.regions.regions.first(where: { $0.id == regionId }),
            !region.horizon,
            let regionView = mapState.viewModel.regions.first(where: { $0.id == regionId })
        else { return nil }

        let regionNodeIds = Set(mapState.bundle.nodes.nodes.filter { $0.regionId == regionId }.map(\.id))
        let courseCodes = mapState.state.trail.segments
            .filter { $0.kind == .course && !Set($0.nodeIds).isDisjoint(with: regionNodeIds) }
            .compactMap(\.courseCode)

        let content = RegionPanelContent(
            regionId: regionId, name: region.name, about: region.about,
            clearedFraction: regionView.clearedFraction, courseCodesCrossingHere: courseCodes)
        return (content, [.mapRegionOpened])
    }

    public static func landmarkPanelContent(
        landmarkId: String, mapState: MapState
    ) -> (content: LandmarkPanelContent, events: [CoreEvent])? {
        guard let landmark = mapState.bundle.landmarks.landmarks.first(where: { $0.id == landmarkId }) else {
            return nil
        }
        let content = LandmarkPanelContent(
            landmarkId: landmark.id, name: landmark.name, whatItIs: landmark.whatItIs,
            sourceUrl: landmark.sourceUrl, nodeIds: landmark.nodeIds)
        return (content, [.mapLandmarkOpened])
    }
```

(`MapFacade`'s remaining functions continue below, same `enum`.)

### 4.4 `MapFacade.selectCourse` and `MapFacade.setMarker` (state-changing, persist every call)

```swift
    /// Q-E: `previousState == nil` builds the first `StudentState`; non-nil replaces `syllabi`/`marker`
    /// together and keeps `nodes` (mastery). Throws whatever `MarkerTrail.generateTrail` or
    /// `StudentStateStore.write` throws — on any throw, no `MapState` is returned (§6 decision default:
    /// atomic, all-or-nothing).
    public static func selectCourse(
        courseCode: String, bundle: ContentBundle, stateURL: URL, previousState: StudentState?,
        today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent]) {
        guard let marker = MarkerTrail.defaultMarker(syllabi: [courseCode], bundle: bundle) else {
            // Never reached in the Demo: the App's course picker only offers courses present in `bundle
            // .courses.courses` (§6 decision default — a programmer-error precondition, not a student path).
            throw CoreError.expTrailInvalid
        }
        let report = try MarkerTrail.generateTrail(syllabi: [courseCode], marker: marker, bundle: bundle)
        let newState = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: [courseCode],
            marker: marker, nodes: previousState?.nodes ?? [:], trail: report.trail,
            expeditionLog: previousState?.expeditionLog ?? [], probeLog: previousState?.probeLog ?? [],
            installDay: previousState?.installDay ?? today.iso, consentOn: previousState?.consentOn ?? true)
        let writeEvents = try StudentStateStore.write(newState, to: stateURL)
        let viewModel = MapViewModel.derive(bundle: bundle, state: newState, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: newState, viewModel: viewModel, queuedNodeId: nil)
        return (map, writeEvents)
    }

    /// D45, map W5 / expedition W6. `unitId` is passed to `MarkerTrail.setMarker` unchanged. When
    /// `pastLastUnit` is `true`, `MarkerTrail.setMarker` (as corrected by task 02.5b) writes the course's last
    /// unit as `unit_id` (interaction-contract § 3). This façade never computes the last unit itself: one
    /// source, in expedition's `Core` function. Throws whatever `MarkerTrail.setMarker` or
    /// `StudentStateStore.write` throws; no `MapState` returned on failure.
    public static func setMarker(
        unitId: String, pastLastUnit: Bool, mapState: MapState, today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent]) {
        let result = try MarkerTrail.setMarker(
            courseCode: mapState.state.marker.courseCode, unitId: unitId, pastLastUnit: pastLastUnit,
            syllabi: mapState.state.syllabi, bundle: mapState.bundle)
        let newState = StudentState(
            schemaVersion: mapState.state.schemaVersion, formatVersionSeen: mapState.state.formatVersionSeen,
            syllabi: mapState.state.syllabi, marker: result.marker, nodes: mapState.state.nodes,
            trail: result.trail, expeditionLog: mapState.state.expeditionLog,
            probeLog: mapState.state.probeLog, installDay: mapState.state.installDay,
            consentOn: mapState.state.consentOn)
        let writeEvents = try StudentStateStore.write(newState, to: mapState.stateURL)
        let viewModel = MapViewModel.derive(bundle: mapState.bundle, state: newState, today: today)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: newState, viewModel: viewModel,
            queuedNodeId: mapState.queuedNodeId)
        // Event order follows map W5's own sentence order: regenerate → persist → notify (§6 decision default).
        return (newMap, result.events + writeEvents + [.mapMarkerMoved])
    }
```

The persisted marker is `result.marker`, which is `MarkerTrail.setMarker`'s own output. It is never
`Marker(courseCode:unitId:pastLastUnit:)` built in this file. This is what makes AC8's past-last-unit case
hold by construction.

### 4.5 `MapFacade.include`, `.unitExpedition`, `.checkHere` (no persistence)

```swift
    public enum IncludeOutcome: Equatable { case queued, ignored }

    /// Q-D. Not persisted — `queuedNodeId` lives only on `MapState`, never in `StudentState`.
    public static func include(
        nodeId: String, mapState: MapState
    ) -> (map: MapState, outcome: IncludeOutcome, events: [CoreEvent]) {
        guard mapState.viewModel.nodes.first(where: { $0.id == nodeId })?.action == .include else {
            return (mapState, .ignored, [])
        }
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: mapState.state,
            viewModel: mapState.viewModel, queuedNodeId: nodeId)
        return (newMap, .queued, [.mapIncludeRequested])
    }

    /// D46. Delegates verbatim to `Expedition.compose(unitExpeditionUnitId:)` — no fringe/window logic of its
    /// own. Throws `CoreError.expNoFringe` when `compose` does.
    public static func unitExpedition(
        unitId: String, mapState: MapState, today: CalendarDay
    ) throws -> (result: ComposeResult, events: [CoreEvent]) {
        let result = try Expedition.compose(
            state: mapState.state, bundle: mapState.bundle, trail: mapState.state.trail,
            marker: mapState.state.marker, today: today, queuedNodeId: nil, unitExpeditionUnitId: unitId)
        return (result, [.mapUnitExpeditionRequested])
    }

    /// The Demo budget of 1 (interaction-contract § 4). `DiagnosisRun.open` is pure construction and never
    /// throws (arbiter-02-11 Ruling 1, 3) — this task calls no later step function.
    public static func checkHere(
        nodeId: String, mapState: MapState
    ) -> (event: DiagnosisEvent, events: [CoreEvent]) {
        let event = DiagnosisRun.open(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1)
        return (event, [.mapCheckHereRequested])
    }
}
```

### 4.6 Boundary validation

The only untrusted input any function in this file reads is `snapshotDir`/`stateURL` (already validated by
`BundleLoader`/`StudentStateStore`, 03.4/03.5) and caller-supplied ids (`nodeId`, `regionId`, `landmarkId`,
`unitId`, `courseCode`) — each is looked up against `mapState.bundle`/`mapState.viewModel` and produces `nil`
(panel content) or a typed outcome (`include`) rather than crashing when the id is unknown; no id is ever
force-unwrapped. `setMarker`'s `unitId` is handed to `MarkerTrail.setMarker` unchanged. The last-unit
substitution for `pastLastUnit: true` happens there (02.5b), not here.

### 4.7 Error codes thrown

- `CoreError.expTrailInvalid` — `selectCourse`/`setMarker` via `MarkerTrail.generateTrail`/`.setMarker` (an
  already-registered code, propagated, never newly thrown by logic this task writes beyond the never-reached
  precondition guard in `selectCourse`, §4.4).
- `CoreError.platformStateWriteFailed` — `selectCourse`/`setMarker` via `StudentStateStore.write` (AC13).
- `CoreError.expNoFringe` — `unitExpedition` via `Expedition.compose` (AC11).
- `CoreError.platformStateUnreadable` — caught internally by `MapLaunch.open` (never re-thrown; folded into
  `.courseSelectionNeeded`'s `messages`, AC1's sibling case).
- `BundleRefusal` — caught internally by `MapLaunch.open` (never re-thrown; folded into `.refused`, AC2).

### 4.8 Model-calling paths

None. Every function in this file is Tier 0, pure or file-I/O-via-delegation only (I2's confidence-threshold/
fallback requirement is not engaged).

### 4.9 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles `MapLaunch.swift`
even though `core-cli`'s `main.swift` calls none of it yet, matching every prior EPIC 03 task's own precedent).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path:**
  - AC1, AC3, AC5–AC9, AC10–AC12: every acceptance criterion above is itself a happy-path assertion; each runs
    over real `data/demo` (`MapLaunchTests.swift` for AC1–AC4, `MapFacadeTests.swift` for AC5–AC14).
- **T2 negative — invalid input rejected at the boundary:**
  - AC2 (a corrupted `data/demo` copy refuses at `BundleLoader.load`, `MapLaunch.open` returns `.refused`
    without reading `stateURL` at all — asserted by never creating a file there).
  - `nodePanelContent`/`regionPanelContent`/`landmarkPanelContent` on an id absent from the bundle return `nil`,
    never crash (a table-driven test over three made-up ids).
  - `MapLaunch.open`'s defensive `catch` branch (§4.2) is asserted unreachable in practice: a test confirms
    `BundleLoader.load`'s documented throw type is exhaustively `BundleRefusal` by catching with `as!
    BundleRefusal` over every AC2-style corruption this task's own fixtures construct — proving the untyped
    `catch` fallback is dead code covered defensively, not silently masking a real code path (mirrors 03.4's own
    "IF … THEN the untyped catch still maps it" decision default).
- **T3 error-taxonomy:**
  - AC11's `EXP_NO_FRINGE` and AC13's `PLATFORM_STATE_WRITE_FAILED` each assert the thrown error, cast `as?
    CoreError`, has the exact expected `rawValue`.
  - `ErrorRegistryTests` (unmodified, from task 03.3) stays green — this task throws no new `CoreError` case.
- **T4 conformance per requirements §B.1** (`contracts/interaction-contract.md` §§ 2–5, `contracts/data-model.md`
  § StudentState `past_last_unit` paragraph, `contracts/content-policy.md`, and I1/I2/I4/I5/I6/I14/I15 per §1):
  - AC14 (event-name conformance): the exhaustive per-action event assertion, checked against the raw `Core
    Event.allCases` set (never a hand-maintained literal list — a derived allowlist per the guard-test shape
    below).
  - AC8 (interaction-contract § 3, "setting it writes the course's last unit as `unit_id`"): the
    past-last-unit case asserts `unitId == <MTH1W units.last>` on the returned `MapState` **and** on the
    re-read file, for a `unitId` argument that is not the last unit.
  - AC5/AC7 (I6/I15): a dedicated assertion that no `NodePanelContent`/`LandmarkPanelContent` field's value is
    ever equal to any `Node`/`Course` field this task does not name in §4.3 (`explanation`, `workedExamples`,
    `hintTree`, `errorTypes`) — proving the panel never accidentally leaks a non-paraphrase field.
  - AC4/§4.2 (I14, "the App never branches on a code"): a table-driven test over every `LaunchOutcome` case this
    task can construct in `Core` tests asserts `messages` contains **only** `[]` or `["PLATFORM_STATE
    _UNREADABLE"]` — `"MAP_MARKER_OFF_TRAIL"` and `"EXP_NODE_NOT_IN_GRAPH"` never appear (the silent-load-path
    guard, §6).
- **Real composition (seam):** AC8 composes, with no stubs, the real `MapFacade.setMarker`, the real
  `MarkerTrail.setMarker` (02.5b-corrected), the real `StudentStateStore.write`/`read`, and the real
  `MapLaunch.open` → `reconcileMarker`. AC4 composes real `StudentStateStore.read` → `reconcileMarker` →
  `generateTrail` → `MapViewModel.derive`. AC12 composes real `include` → `Expedition.compose`.
- **T5 negative control for every regression guard:**
  - AC13's missed-write negative control (a read-only `stateURL` directory) proves `selectCourse`/`setMarker`'s
    "persist every state-changing action" claim is load-bearing, not accidentally satisfied — without the
    negative control, a `selectCourse` that silently dropped its `StudentStateStore.write` call would still pass
    every other test in this file.
  - AC8's past-last-unit guard has two controls. (1) The in-course move (`pastLastUnit: false`,
    `unitId: "MTH1W.u2"`) must persist `"MTH1W.u2"`, which fails an "always write the last unit"
    implementation. (2) The precondition `units.last != "MTH1W.u2"` keeps the past-last-unit assertion from
    passing vacuously. Without 02.5b's fix, the past-last-unit case fails (the persisted `unitId` would be
    `"MTH1W.u2"`), so the guard is load-bearing.
  - AC12's queue-replacement assertion is itself a negative control on a "the queue accumulates instead of
    replacing" bug: two sequential `include` calls with different node ids, the second call's returned
    `MapState.queuedNodeId` **is not** an array or a set containing both ids — it is the single, most-recent id.
  - AC14's derived allowlist (`CoreEvent.allCases`, never a literal string list) is itself the guard against "a
    new event name is added to the contract but this task's list goes stale" — per the guard-test shape §5
    requires; a planted call to an event name **not** in `CoreEvent.allCases` (impossible to construct in Swift,
    since `CoreEvent` is a closed enum) is replaced by the equivalent, constructible negative: a test asserts
    that removing one required event from a captured actual-events array (a local, test-only mutation, never
    touching `MapLaunch.swift`) makes the AC14 assertion fail — proving the assertion is not vacuously true over
    an unconstrained superset.
- **T6 idempotency / no-leak:**
  - `MapLaunch.open` called twice in succession over the same, unmodified `(snapshotDir, stateURL, today)`
    returns two `LaunchOutcome`s whose `.ready` `map.state`/`map.viewModel` are field-by-field `Equatable`-equal
    (AC4's negative-control case run twice is the concrete instance).
  - AC8's relaunch assertions (`setMarker` then a fresh `MapLaunch.open` over the same `stateURL`, for both the
    in-course and the past-last-unit case) are this task's own no-leak proof for the state-changing façade
    path: the persisted marker/trail survive an independent re-read with no drift.
  - `include`'s queue never reaches `StudentStateStore.write`'s argument: a test writes via `selectCourse`, then
    calls `include`, then re-reads `stateURL`'s raw bytes and asserts they are byte-identical to what
    `selectCourse` wrote (no queue key appears anywhere on disk, AC12).

## §6 Decision defaults

- IF a reviewer expects `CoreError.swift` to be modified by this task (per an earlier draft of the context
  bundle's §F) THEN it is not — see §2's "Correction to the context bundle" note; task 03.3 alone writes that
  file, and by the time this task's `depends_on` chain (03.4 → 03.3, 03.5 → 03.3) is satisfied, the three cases
  this task throws/matches (`platformStateUnreadable`, `platformStateWriteFailed`, `platformSnapshotRefused`)
  already exist (per `tasks/epic-03-task-03-core-error-surface-text-mirror.md` §1, quoted §2).
- IF `MapFacade.setMarker` should itself substitute the course's last unit when `pastLastUnit == true` THEN it
  does not. `MarkerTrail.setMarker` does, as corrected by task 02.5b (per
  `tasks/arbitration/arbiter-03-07-past-last-unit.md` § Ruling; `docs/domains/map.md` § W5 step 2: "Hand the
  unit id to **expedition** … which owns the change"; `CLAUDE.md`: "implemented once, in `Core`"). A second
  copy here would let the two diverge. If 02.5b has not landed when implementation starts, BLOCK (Branch
  note). Do not add a local workaround.
- IF `platform.launched`/`map.opened` should both fire on every `LaunchOutcome` (including `.refused`) THEN they
  do not — `docs/domains/platform.md` § W1's `platform.launched` is the *Post* of the four-step sequence
  culminating in "hand control to map W1" (§3, quoted); a `.refused` outcome never reaches step 4, so it carries
  `events == []`. `map.opened` fires only on `.ready`, because `docs/domains/map.md` § W1's own Pre is "bundles
  loaded (platform); `StudentState` read" — `.courseSelectionNeeded` has no resolved `StudentState`/marker to
  open a map on, so no `MapViewModel` is ever derived for it, and no `map.opened` is emitted.
- IF the load-path `messages` list should also surface `EXP_NODE_NOT_IN_GRAPH` (from `reconcileNodeIds`'s
  ignored ids) THEN it does not — `docs/domains/expedition.md` § W7 (quoted §3) describes the ids as "kept …
  ignored", with no student-facing text named anywhere for this code on the load path, and arbiter-03 § Q-A's
  governing principle ("the App never branches on a code … the list … is computed in `Core`") extends naturally
  to any load-path reconciliation code this task's `messages` list does not explicitly carry — this is a Q1
  (information), resolved from the same principle already ruled for `MAP_MARKER_OFF_TRAIL`, not a new Q4.
- IF `selectCourse`/`setMarker` should return a partially-updated `MapState` when `StudentStateStore.write`
  throws (so the App can show the attempted change optimistically) THEN they do not — both functions are plain
  `throws` functions with no `Result`-wrapping and no fallback return value; a Swift `throws` function either
  returns its declared type or does not return at all, so "the caller's previously-held `MapState` is never
  replaced" (AC13) is guaranteed by the language, not by extra logic this task must write — consistent with
  arbiter-03 § Q-F's "(new value, `[CoreEvent]`) or throws a `CoreError`" (never both).
- IF `selectCourse`'s later-course-change branch should carry the previous `MapState.queuedNodeId` forward THEN
  it resets to `nil` instead — no ruling or contract text addresses this directly; the conservative default
  (§4.4, `selectCourse` always constructs `queuedNodeId: nil`) avoids carrying a queued node id across a
  syllabus change that may have made that node ineligible, and no AC in this task's scope or the amended brief's
  §4 exercises the alternative, so this is a defensible Q1 default rather than a Q4 escalation.
- IF `include`'s outcome type should distinguish "upstream" from "neither fringe nor upstream" (two different
  reasons a node's `action != .include`) THEN it does not — Q-D's own ruling (§3, quoted) closes exactly this
  gap by observing both cases are "unreachable from the panel" and treats them identically ("no student text and
  no new code"); a single `IncludeOutcome.ignored` case covers both without inventing a distinction no ruling or
  contract draws.
- IF `setMarker`'s emitted-event order should place `.mapMarkerMoved` before the persistence event
  (`.platformStateWritten`) THEN it does not — `docs/domains/map.md` § W5's own sentence order (quoted §3, "The
  state is persisted, `map.marker_moved` is emitted") is read literally: persistence completes, then the
  map-specific notification fires.
- Standing defaults: identifiers and timestamps are untouched beyond what `StudentStateStore`/`MarkerTrail`
  already produce (`installDay`, log `day` fields pass through opaquely); model calls do not exist anywhere in
  this task's code (I2 vacuous); telemetry is unaffected (`consentOn` passes through opaquely); no node's
  Ministry text is read (the model has none to begin with — `paraphrase` is the only prose field this task
  reads, per I6).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`).
- typecheck clean (Swift's typecheck is the build).
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package`
  on the simulator), including every case in §5.
- `ErrorRegistryTests`, `IdentifierBlocklistParityTests`, `coreImportBoundary()` and every sibling task's own
  unmodified test suite (03.3–03.6, and 02.5b's `MarkerTrailSetMarkerPastLastUnitTests`) stay green with no
  edit to any of their files.
- tests green for every case in §5 (T1–T6).
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` §§ 2–5,
  `contracts/data-model.md` § StudentState's `past_last_unit` paragraph, `contracts/content-policy.md`'s I6/I15
  paragraphs) and to every invariant listed in §1 (I1, I2, I3, I4, I5, I6, I14, I15).
- `scripts/gate.sh` gate 3 green in full.

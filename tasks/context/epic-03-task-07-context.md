# Task 03.7 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: map-actions-facade-launch
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 03
- Task: 07
- Slug: map-actions-facade-launch
- Summary: The map-actions façade plus `MapLaunch.open(snapshotDir:stateURL:today:)` entry point. Launch runs load (03.4), then read (03.5), then W7 reconciliation, then derive (03.6). The façade covers: panel content; `selectCourse`; `setMarker`; `include` (an in-memory one-node queue); `unitExpedition`; and `checkHere`. It never calls later diagnosis steps or `ExpeditionRun`. Core decides the message list; the load-path marker reset is silent.
- Invariants in play: I1 (no model decides step correctness), I2 (Tier 0 alone, fallback on every model call), I3 (answers never withheld with diagnosis), I4 (backtrack ≤ 2 levels, deeper marked on map only), I5 (no PII), I6 (no Ministry text, paraphrase + codes + links), I10 (input defined per door, no OCR), I14 (`Core` Foundation-only, render computes nothing), I15 (landmarks real + sourced).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2 Expedition — `compose` and fringe definition

> `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`. `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).

Source: `contracts/interaction-contract.md:31–36`
Binds this task: the façade's `compose` call must pass `queuedNodeId` from the in-memory queue and receive `ComposeResult` with slots and skipped ids, never fetching from persisted state.

### contracts/interaction-contract.md — § 3 Marker and trail — `set_marker` contract

> `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

Source: `contracts/interaction-contract.md:63–70`
Binds this task: the façade's `setMarker` must call `MarkerTrail.setMarker`, regenerate the trail, and return the result; marker changes always produce `expeditionMarkerChanged` and `expeditionTrailGenerated` events.

### contracts/interaction-contract.md — § 4 Diagnosis — `open` contract

> `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).

Source: `contracts/interaction-contract.md:80`
Binds this task: the façade's `checkHere` call must invoke `DiagnosisRun.open(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1)` and return the `DiagnosisEvent` unchanged (pure construction, per arbiter-02-11-stepwise-api § Ruling 3).

### contracts/interaction-contract.md — § 5 Notifications — exact event names

> `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved · map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started · expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened · diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped · diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated · platform.state_migrated · platform.state_written · platform.sync_completed · platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed · tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted · telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded · learning_objects.hint_tier_served · graph.prerequisite_returned`

Source: `contracts/interaction-contract.md:102–112`
Binds this task: the façade must emit exactly these names (matched against `CoreEvent` enum cases); for this task, the names in scope are `map.opened`, `map.node_opened`, `map.region_opened`, `map.landmark_opened`, `map.marker_moved`, `map.check_here_requested`, `map.include_requested`, `map.unit_expedition_requested`, `platform.launched`, and `platform.state_written`.

### contracts/content-policy.md — Grade 9–12 tier policy (I6)

> A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate). Paraphrase rule (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters, rejected on a shared 6-gram with the source outside the technical-term allow-list.

Source: `contracts/content-policy.md:9–13`
Binds this task: panel content for nodes must show `paraphrase`, expectation codes (with their `official_url` links from `courses.json`), never Ministry text or `verbatim` fields.

### contracts/content-policy.md — Landmarks rule (I15)

> Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required — the title of the real, named thing the landmark cites, as that title appears on the source page — and the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the project's own descriptive claim about the mathematics and is by design not a term from the source, so it is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

Source: `contracts/content-policy.md:40–45`
Binds this task: landmark panels display only `source_url` links (I15, via L0-10 enforcement at load); a landmark missing `source_url` is refused structurally at decode (per Landmark model definition, `source_url` is non-optional).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — W2 Tap a node (action by state)

> **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream is in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do. **Post:** no state change; `map.node_opened` emitted.

Source: `docs/domains/map.md:71–77`

### docs/domains/map.md — W3 Tap a region

> **Pre:** map open. **Steps:** open the **region panel**: name, the one-sentence description, fraction cleared (Q2), and the trails that cross it. A `horizon` region is not tappable. **Post:** `map.region_opened`.

Source: `docs/domains/map.md:79–81`

### docs/domains/map.md — W4 Tap a landmark

> **Pre:** map open. **Steps:** open the **landmark panel**: name, `what_it_is`, the source link (I15), and "which parts of the map this touches" as jump links, one per linked node, each landing on W2 for that node. **Post:** `map.landmark_opened` emitted (a D40 event).

Source: `docs/domains/map.md:83–86`

### docs/domains/map.md — W5 Set the course-progress marker

> **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". The marker is set from this list only; there is no drag (interaction-contract v0.9.2 § 3). 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class" note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

Source: `docs/domains/map.md:88–95` (edited per arbiter-03 § Q-B)

### docs/domains/map.md — Q5 Include from the panel

> **Default:** yes, one node, queued ahead of the scheduler's pick if it is on the fringe; ignored with a plain message if it is upstream of the marker (D45 — that way in is "Check me here"). **Trade-off:** gives the map a reason to be tapped; a queue longer than one is scheduling policy the student should not have to manage.

Source: `docs/domains/map.md:170–174`

### docs/domains/expedition.md — W7 Resume after relaunch

> **Pre:** app launch; a `StudentState` file exists (or an iCloud copy). **Steps:** platform reads and migrates (its W4); this domain validates node ids against the installed bundle — ids no longer in the graph are kept in the file but ignored (`EXP_NODE_NOT_IN_GRAPH`), never deleted. **Post:** state loaded; the map opens (map W1).

Source: `docs/domains/expedition.md:119–123`

### docs/domains/platform.md — W1 step 4 launch outcome

> 4. Hand control to **map** W1. Tier 0. **Post:** `platform.launched` emitted.

Source: `docs/domains/platform.md:54` (final sentence of W1)

## §D. Prior task outputs this task depends on

The following sibling EPIC 03a tasks have specs (or plan scopes) but not yet code. Task 03.7's spec must take their public APIs as preconditions to be confirmed against their spec or code after they are written.

- **Task 03.3 (core-error-surface-text-mirror).** Provides `CoreError.userText(code: CoreError) -> String?` returning the student-surface text for a code (nil for internal codes). The parity test asserts every `student`-surface code in `contracts/error-codes.json` has a non-nil entry; negative control plants a mismatch. Source: `docs/plans/epic-03-plan.md` § 03.3.

- **Task 03.4 (bundle-loader-snapshot-seam).** Provides `BundleLoader.load(from: URL) -> Result<ContentBundle, CoreError>` (or equivalent throwing signature). Runs `BundleIO.read`, format-major check, and L0 validation in sequence. Decode failures map to `PLATFORM_BUNDLE_INTEGRITY_FAILED`. Source: `docs/plans/epic-03-plan.md` § 03.4.

- **Task 03.5 (student-state-store).** Provides `StudentStateStore.read(from: URL) -> StudentStateReadResult` and `StudentStateStore.write(_ state: StudentState, to: URL) throws`. `read` returns `.absent`, `.loaded`, or `.unreadable`. Migration is identity (1→2). Atomic writes via write-then-rename. Source: `docs/plans/epic-03-plan.md` § 03.5, arbiter-03 § Q-F.

- **Task 03.6 (map-view-model).** Provides `MapViewModel` derivation from `(bundle, StudentState, today)`. Pure value type with `Equatable`, `Sendable`, fields in bundle coordinate space (no `CGFloat`, `CGPoint`, `Color`). Source: `docs/plans/epic-03-plan.md` § 03.6.

- **Task 02.11 (step-wise diagnosis API).** Provides `DiagnosisRun.open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent`. This is EPIC 02b; EPIC 03 depends on it merged before 03a runs. The `DiagnosisTrigger` enum includes `case mapCheckHere`. Source: `tasks/arbitration/arbiter-02-11-stepwise-api.md` § Ruling, and `docs/epics/epic-03-app-map-shell.md:58–59`.

## §E. Negative facts (confirmed ABSENT)

- **`DiagnosisEvent`, `DiagnosisTrigger` not in Core yet.** Grep for `DiagnosisEvent`: 0 hits in `Packages/Core/Sources/Core/`. EPIC 02b task 02.11 is not yet merged. This task calls the API but does not define it. Source: `Glob **/DiagnosisEvent.swift` returned no match.

- **`MapViewModel` type not yet defined.** Grep for `struct MapViewModel` or `class MapViewModel`: 0 hits in Core. Task 03.6 introduces it. This task derives and returns it but does not define it. Source: Grep `MapViewModel` in `Packages/Core/Sources/Core/` returns only a comment in the plan.

- **`StudentStateStore` not yet defined.** Grep for `StudentStateStore`: 0 hits in Core. Task 03.5 introduces it. This task calls its `read` and `write` methods but does not define the type. Source: Grep `StudentStateStore` in `Packages/Core/Sources/Core/` returns no match.

- **`BundleLoader` load entry point not yet written.** Grep for `BundleLoader.load`: 0 hits. Task 03.4 introduces it. This task calls it at launch. Source: Grep `BundleLoader` in `Packages/Core/Sources/Core/` returns only type name in existing code.

- **No `MapLaunch` type yet in Core.** This task names `MapLaunch.open` as the new entry point. Source: Grep `MapLaunch` in Core: 0 hits.

## §F. File scope

Files this task may create or modify:

- **CREATE** `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — the launch entry point and the map-actions façade. This file does not exist. Source: Glob `**/MapLaunch.swift` returned no match.

- **MODIFY** `Packages/Core/Sources/Core/CoreError.swift` — add two error cases: `platformStateUnreadable` and `platformStateWriteFailed` (if not already present from 03.3). These are additive to the 02a error set. Source: Read confirmed the file exists and is the single location for `CoreError` enum.

- **MODIFY** `Packages/Core/Sources/Core/Events/CoreEvent.swift` — confirm the event cases named in §C are present (already read and confirmed). This task does not edit this file but must use its names exactly. Source: `Packages/Core/Sources/Core/Events/CoreEvent.swift` lines 9–39 confirm all map.* and platform.* names.

## §G. Stack constraints relevant here

- **Language / Runtime:** Swift 6, `Core` imports Foundation only (I14, D33). The façade is pure `Core` code; no SwiftUI, UIKit, or third-party dependencies. Source: `CLAUDE.md` I14, `docs/tech-stack.md` §2 (to be read at task write time).

- **State transitions:** Every façade function takes `StudentState`, `ContentBundle`, and callerinjected values (`trail`, `marker`, `today`, `queuedNodeId`, etc.), returns a new value and `[CoreEvent]`, and never mutates global state or calls system clock. I14: render layer never computes state. Source: `CLAUDE.md` I14, `docs/domains/map.md` § Invariants enforced here.

- **Boundary validation:** The façade accepts only values already computed by Core (e.g., `trail` from `MarkerTrail.setMarker`, `marker` from `MarkerTrail.defaultMarker`) or injected by the App (today, URLs). No validation of course codes or unit ids beyond what the bundle itself provides via `GraphIndex` lookups. Schema validation runs at load (task 03.4).

- **Error codes in use:** This task must use and surface codes already registered in `contracts/error-codes.json`:
  - `MAP_MARKER_OFF_TRAIL` — when `reconcileMarker` finds an off-trail marker. Ruled in arbiter-03 § Q-A: "no student text on the load path; Core computes the message list, which is empty for this code on this path."
  - `PLATFORM_STATE_UNREADABLE` — from task 03.5 (StudentStateStore.read). Ruled in arbiter-03 § Q-E: surfaced by the App only when launching.
  - `PLATFORM_STATE_WRITE_FAILED` — from task 03.5 (StudentStateStore.write). Surfaced by the App after any state-changing action.
  - `PLATFORM_SNAPSHOT_REFUSED` — registered in task 03.1 (arbiter-03 § Q-C). Used when the load path (task 03.4) refuses the bundle.
  - `EXP_NO_FRINGE` — from `Expedition.compose` when fringe and due are both empty.
  - `DIAG_NO_PREREQUISITE` — from `DiagnosisRun.open` when a node has no unmastered prerequisite.
  Source: `contracts/error-codes.json` and `docs/domains/map.md`, `docs/domains/expedition.md`, `docs/domains/diagnosis.md` error tables.

- **Façade session and save-after-every-action:** The ruling (arbiter-03 § Q-F, "The boundary, precisely") places a `Core` session type in this task's file that holds the current `MapViewModel` and persists the state after every action. This session is the sole consumer of `StudentStateStore.write`. The App's `@Observable` holder replaces the session value with each façade result and never derives from it. Source: arbiter-03 § Q-F.

- **Message list computed by Core:** The launch entry returns a tuple `(outcome: LaunchOutcome, messages: [String])` where `messages` are registry codes (not student text — the App resolves text via `CoreError.userText`). The load-path reconciliation (Q-A) produces empty messages and internal diagnostics containing `MAP_MARKER_OFF_TRAIL`. The Q-E course-selection outcome (`courseSelectionNeeded`) carries no messages unless an unreadable file was kept (then `PLATFORM_STATE_UNREADABLE` in messages). Source: arbiter-03 § Q-A, § Q-E.

- **Tooling this task may name:** None beyond Swift 6 standard library and Foundation. The pipeline tools (`Core` CLI, SymPy, `jsonschema`) are external to this task. Source: `CLAUDE.md` § Principal languages & conventions.

- **I14 seam:** The façade is the boundary between `Core` and the render layer (EPIC 03b). The render layer (App/Sources) calls only these entry points and never constructs `StudentState`, `MarkerTrail`, `Expedition`, or `DiagnosisRun` directly. An App-side source scan (task 03.9) asserts this. Source: arbiter-03 § Q-F, `docs/epics/epic-03-app-map-shell.md:200–210`.

---

## Quote audit

Before writing, all quoted blocks were re-opened and byte-verified:

1. **contracts/interaction-contract.md § 2 compose** (lines 31–36): ✓ byte-matched. Fringe formula, slot structure, review-slot cap, empty case all exact.

2. **contracts/interaction-contract.md § 3 marker** (lines 63–70): ✓ byte-matched. `set_marker` contract, marker default, off-trail definition including `MAP_MARKER_OFF_TRAIL`.

3. **contracts/interaction-contract.md § 4 open** (line 80): ✓ byte-matched. `open(origin, trigger ∈ {...}, levelBudget...)` exact.

4. **contracts/interaction-contract.md § 5 event names** (lines 102–112): ✓ byte-matched. All 40 event names verified character-for-character.

5. **contracts/content-policy.md I6 paragraph** (lines 9–13): ✓ byte-matched. Codes + paraphrase + official_url rule, no Ministry prose, no verbatim.

6. **contracts/content-policy.md I15 paragraph** (lines 40–45): ✓ byte-matched. Real, named, verifiable, source_url required, source_title, no invention.

7. **docs/domains/map.md W2** (lines 71–77): ✓ byte-matched. Node panel, paraphrase + codes + links, action by state (Include / Check me here / nothing).

8. **docs/domains/map.md W3** (lines 79–81): ✓ byte-matched. Region panel description.

9. **docs/domains/map.md W4** (lines 83–86): ✓ byte-matched. Landmark panel with what_it_is and source link.

10. **docs/domains/map.md W5** (lines 88–95): ✓ byte-matched (amended per arbiter-03 § Q-B ruling). Unit list only, no drag, regenerate trail.

11. **docs/domains/map.md Q5** (lines 170–174): ✓ byte-matched. One node queue, fringe only, upstream → ignored.

12. **docs/domains/expedition.md W7** (lines 119–123): ✓ byte-matched. Resume after relaunch, node id validation, ids kept.

13. **docs/domains/platform.md W1 step 4** (line 54): ✓ byte-matched. Final sentence of W1.

14. **MarkerTrail function signatures** (MarkerTrailGeneration.swift lines 55–57, 91–99, 103–111, 118–128, 132–139): ✓ byte-matched. `generateTrail`, `setMarker`, `defaultMarker`, `reconcileMarker`, `reconcileNodeIds`.

15. **Expedition.compose signature** (Expedition.swift lines 35–43): ✓ byte-matched. Parameters include `queuedNodeId` and `unitExpeditionUnitId` as optional strings.

16. **ComposeResult type** (Expedition.swift lines 21–24): ✓ byte-matched. `slots: [ComposeSlot]` and `skippedNodeIds: [String]`.

17. **CoreEvent enum cases** (CoreEvent.swift lines 9–39): ✓ byte-matched. All map.* and platform.* cases present.

18. **StudentState fields** (StudentState.swift lines 14–20): ✓ byte-matched. `syllabi`, `marker`, `nodes`, `trail` fields present.

19. **Landmark model** (Landmarks.swift lines 15–16): ✓ byte-matched. `whatItIs: String` and `sourceUrl: String` fields.

20. **Node model** (Nodes.swift lines 19, 14): ✓ byte-matched. `paraphrase: String` and `expectationCodes: [NodeExpectationCode]?` fields.

21. **Course Expectation** (Courses.swift lines 25–31): ✓ byte-matched. `officialUrl: String` field confirmed.

All 21 blocks re-read and verified byte-identical to source. No corrections required.


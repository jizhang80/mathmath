# Epic 03 · Task 06: `MapViewModel` — the pure map derivation

---
epic: 03
task: 06
slug: map-view-model
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: Implement `MapViewModel` in `Core` (`Packages/Core/Sources/Core/Map/MapViewModel.swift`) as a pure,
deterministic derivation from `(ContentBundle, StudentState, CalendarDay today)` — no I/O, no clock read, no
rendering. It carries region tints (with horizon and empty regions as pure fog), one river per edge, a
`NodeView` per node (fog level, due ring, upstream-of-marker flag, the single offered action), trail segments
(course segments solid, `extension` dashed), the position indicator, the landmark set, the trail-first D44
focus frame, and a zoom-scale label-set function (map Q4). The trail it renders is always the caller's own
`StudentState.trail` (a `MarkerTrail` output) — this task never regenerates a trail. Fringe membership for the
"Include" action is computed by calling `Expedition.swift`'s own D48 fringe formula directly —
`Expedition.scopeWindow` and `Expedition.fringeNodeIds`, widened from `private` to `internal` by this task's
minimal, surgical visibility edit to that file (§2 — no other line of `Expedition.swift` changes, and the
landed `MarkerTrailFringeSeamTests.swift` (02.6) tests stay green unmodified), together with
`Expedition.residentNodeIds`/`Expedition.unitIndex` (also widened to `internal`) reused directly by this
task's own `upstreamNodeIds` helper. This is I14's single-source requirement satisfied by construction: the
D48 fringe formula and the unit-index rule each exist exactly once in `Core`, in `Expedition.swift`, and
`MapViewModel.swift` never re-implements either — cross-checked against a real `Expedition.compose` call in a
C1-style seam test (§5 T4, AC12) and guarded structurally against regression (§5 T9, with its negative control
§5 T9b, AC14).

Invariants in play:
- **I1** — not applicable to this task (no item is checked here); no code path in `MapViewModel` decides
  correctness of anything.
- **I2** — Tier 0 only: `derive` is a pure function with no adapter parameter and no model import.
- **I4 (record half)** — every `blocked` id in the input `StudentState` gets `NodeAction.checkHere` on its
  `NodeView` and no other action, regardless of window/fringe membership, satisfied by the action-priority rule
  in §4 step 6 and tested in §5 T1/T4.
- **I6** — `MapViewModel` carries no Ministry text; `NodeView`/`LandmarkView` carry only ids, coordinates and
  enums — panel content (`paraphrase`, expectation codes, `official_url`) is `Core`'s map-actions façade's job
  (task 03.7), not this task's.
- **I14** — `MapViewModel.swift` imports Foundation only, has zero `public init`s on its own state that could
  let `App/Sources` forge a value other than through `derive`/`labelSet`, and carries only `Double`, `String`,
  `Bool`, ids and enums (no `CGFloat`, `Color`, `Path`, `@Observable`, or screen-pixel quantity) — asserted by
  the existing recursive import-boundary test extended over this new file, unchanged by this task. **Single-
  source clause**: the D48 fringe/window formula and the unit-index rule exist exactly once in `Core`
  (`Expedition.swift`, widened to `internal`, §2); `MapViewModel.swift` calls them directly and contains no
  second definition of any of the four functions — asserted structurally by §5 T9 over the real file, whose
  scan logic is itself proven to fail red on a planted violation by the negative control §5 T9b (AC14).

Acceptance criteria (every AC is asserted over real `data/demo` unless stated otherwise):

- AC1: `MapViewModel.derive(bundle:state:today:)` over real `data/demo` and the Demo's two courses returns
  exactly 14 `RegionView`s (10 content + 4 horizon, matching `data/demo/regions.json`'s 14 entries
  byte-verified in §3). The 7 content regions with no bundle nodes (`number-operations`, `algebra`,
  `functions` are the 3 populated ones; the other 7 content regions plus the 4 horizon regions carry
  `clearedFraction == nil`, i.e. 11 of the 14 are pure fog with no fraction) and the 4 horizon regions all
  carry `clearedFraction == nil`. `RegionView.horizon` matches `Region.horizon` from the bundle 1:1.
- AC2: One `River` per `Edge` in `bundle.edges.edges`, `from`/`to` unchanged, same count and order.
- AC3: For every node, `NodeView.fogLevel == (state.nodes[id]?.mastery ?? .fog)` unconditionally — no
  upstream/marker override (§6 decision default). A `cleared` node with `nextDue <= today.iso` has `due ==
  true` and stays `fogLevel == .cleared`; no other fog level ever carries `due == true`.
- AC4: Course trail segments (`SegmentKind.course`) produce `TrailSegmentView.dashed == false`; the
  `extension` segment produces `dashed == true`. On real `data/demo`, `past_last_unit == true` produces no
  extension segment (`data/demo`'s two courses' `next_courses` — `MPM2D`, `MHF4U` — both name courses absent
  from the bundle, verified in §3). On the `Fixtures/trail/extension-positive` fixture bundle (existing,
  read-only, `Packages/Core/Tests/CoreTests/Fixtures/trail/extension-positive/`) with `pastLastUnit: true`, the
  generated trail's extension segment renders `dashed == true`.
- AC5: `positionIndicatorNodeId` equals the first node in trail-flattened order (`state.trail.segments.flatMap
  { $0.nodeIds }`) that is not upstream of the marker and whose mastery is not `.cleared`; `nil` when every
  such node is cleared.
- AC6: One `LandmarkView` per `bundle.landmarks.landmarks` entry, `id`/`position`/`nodeIds` unchanged.
- AC7: `labelSet(atZoom:)` returns `landmarkNames == true` at every zoom scale; `nodeNames == true` iff `zoom >=
  MapViewModel.nodeNameZoomThreshold`; `regionNames == !nodeNames` (§6 decision default; the threshold is
  `[ESTIMATE]`-tagged).
- AC8: `focusFrame` is the bounding box (`minX`/`minY`/`maxX`/`maxY`) of every node's `position` in the
  marker's-unit-∪-next-unit window (or, `pastLastUnit == true`, the extension segment's nodes); it defaults to
  `(0, 0)`–`(1, 1)` when that window is empty.
- AC9 (I4 record half): over a constructed `StudentState` with `blocked` nodes both inside and outside the
  marker's window, every `blocked` id's `NodeView.action == .checkHere` and no `blocked` id ever gets
  `.include`.
- AC10 (map W2 step 2 + Q-D): a `fog` node in the fringe (per §4 step 5's formula) and not upstream gets
  `.include`; a `fog` node upstream of the marker gets `.checkHere`; a `cleared` node gets `action == nil`; a
  `fog` node neither on the fringe nor upstream gets `action == nil` (its `fogLevel` still reports `.fog`).
- AC11 (determinism): two `derive` calls with `Equatable`-equal arguments produce `Equatable`-equal
  `MapViewModel`s.
- AC12 (C1-style fringe seam, §5 T4): every node id in a real `Expedition.compose(...)`'s
  `ComposeResult.slots` of `kind == .newLearning`, over real `data/demo`, is a `fog` node whose
  `MapViewModel.NodeView.action == .include` in the `MapViewModel` derived over the same `(state, bundle,
  today)`.
- AC13 (W6 re-derivation): a `StudentState` produced by a real `MasteryTransitions.itemCorrect` sequence
  (clearing a node) composed with a real `DiagnosisRun.run(...)` `.confirmed` outcome (blocking a different
  node), both over real `data/demo`, re-derives to a `MapViewModel` where the cleared node's `fogLevel ==
  .cleared` and the blocked node's `fogLevel == .blocked` with `action == .checkHere`. No hand-built
  `MapViewModel` or hand-built `StudentState.nodes` entry is used for either transition.
- AC14 (I14 single-source, no restatement): the set of `NodeView.id`s with `action == .include` in a
  `MapViewModel` derived over real `data/demo` (and, separately, over the constructed `blocked`+`remediated`
  fixture of AC12) equals `Expedition.fringeNodeIds(...)` (called directly, now `internal`, over the same
  `(state, bundle, index, edgesByTo, marker, trail)`) intersected with the `fog`, non-upstream nodes; and
  `Packages/Core/Sources/Core/Map/MapViewModel.swift` contains no `func scopeWindow`, `func fringeNodeIds`,
  `func residentNodeIds` or `func unitIndex` declaration of its own — i.e. no second fringe/window formula
  exists anywhere in `Map/`. Instrument: the structural half is produced by the single test helper
  `restatedDeclarations(in:)` (§5 T9) run over the real file's text — empty scan = FAIL (the file must resolve,
  read non-empty, and contain `static func derive(`); it excludes call sites (`Expedition.<name>(`) and lines
  whose trimmed form begins with `//`. That same helper is proven non-vacuous by §5 T9b: it detects all four
  names planted in a synthetic source text and reports nothing on a clean synthetic text containing only call
  sites and comments.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Map/MapViewModel.swift` — CREATE. Confirmed absent: `Glob
  Packages/Core/Sources/Core/Map/**` returned no matches (context bundle §F). Public `MapViewModel` and its
  value types (`RegionView`, `NodeView`, `NodeAction`, `River`, `TrailSegmentView`, `LandmarkView`,
  `FocusFrame`, `LabelSet`), `MapViewModel.derive(bundle:state:today:)`, `MapViewModel.labelSet(atZoom:)`, and
  one private helper (`upstreamNodeIds`) — the window and fringe sets are computed by calling
  `Expedition.scopeWindow`/`Expedition.fringeNodeIds` directly (§4 steps 4–5), never restated.
- `Packages/Core/Sources/Core/State/Expedition.swift` — MODIFY, visibility only. Drop the `private` keyword on
  exactly four `static func` declarations — `residentNodeIds` (`:125`), `unitIndex` (`:137`), `scopeWindow`
  (`:152`) and `fringeNodeIds` (`:202`), each verified at those line numbers in this session — making each
  `internal` (module-visible; no other access-level keyword, no wrapper function). No other line of this file
  changes: not the body of any function, not `compose`, not a doc comment, not whitespace. The landed
  `MarkerTrailFringeSeamTests.swift` (02.6) does not reference any of these four functions by name and stays
  green unmodified.
- `Packages/Core/Tests/CoreTests/MapViewModelTests.swift` — CREATE. Confirmed absent (context bundle §F). Holds
  T1–T9b, including the single private scan helper `restatedDeclarations(in:)` shared by T9 and T9b.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/Expedition.swift` beyond the four visibility keywords named in the
  in-scope entry above — everything else in this file (every function body, `compose`, `ComposeResult`, every
  doc comment) is read-only. Production code calls `Expedition.scopeWindow`, `Expedition.fringeNodeIds`,
  `Expedition.residentNodeIds` and `Expedition.unitIndex` (module-visible after the edit) from
  `MapViewModel.swift`; `Expedition.compose` (public) is additionally called, unchanged, only from the test
  file's seam test (§5 T4).
- `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift` — read-only. Call `MarkerTrail.generateTrail` /
  `MarkerTrail.setMarker` (public) only, from tests.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — read-only. Call `DiagnosisRun.run` (public,
  the thin driver) only, from the W6 test (AC13).
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift` — read-only. Call `MasteryTransitions.itemCorrect`
  (public) only, from the W6 test.
- `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift` — read-only; the shape precedent
  for T9b (§3), not modified or imported from.
- `Packages/Core/Sources/Core/Core.swift` — read-only. **Correction to the context bundle**: Swift has no
  per-type "export line" mechanism; every `public` declaration in any file of the `Core` target is automatically
  part of the module's public API once compiled. No other landed feature (`DiagnosisEvent.swift`,
  `PrerequisiteQuery.swift`, `StateMerge.swift`, …) added a line to `Core.swift` to become visible, and
  `Core.swift` today (`Packages/Core/Sources/Core/Core.swift:1-10`) holds only `CoreInfo`, no export registry of
  any kind. This task does not modify it.
- `Packages/Core/Sources/Core/Model/*.swift`, `Packages/Core/Sources/Core/Validation/GraphIndex.swift`,
  `Packages/Core/Sources/Core/Time/CalendarDay.swift`, `App/**`, `contracts/**`, `data/demo/**`, `docs/**` —
  read-only. **Correction to the context bundle**: `GraphIndex` is declared at
  `Packages/Core/Sources/Core/Validation/GraphIndex.swift:5` (`struct GraphIndex`, internal, no `public`
  keyword — module-visible, not `Graph/GraphIndex.swift` as the bundle's §D cited). `ContentBundle` is declared
  at `Packages/Core/Sources/Core/BundleIO.swift:8`, not at a `Model/ContentBundle.swift` file (the bundle's §D
  citation for `ContentBundle`/`Node`/`Region`/`Edge`/`Landmark` names a file that does not exist; the actual
  model types are split across `Packages/Core/Sources/Core/Model/{Nodes,Regions,Edges,Courses,Landmarks,Ids}.swift`
  and `ContentBundle` itself lives in `BundleIO.swift`).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition` (`compose` rule, v0.9.2):
  > - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  >   cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  >   requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if
  >   on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
  >   `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

  Source: `contracts/interaction-contract.md:32-36`. This is the D48 formula `MapViewModel` calls directly
  through `Expedition.fringeNodeIds` for fringe membership (§1, §4 step 5) — the fringe *set* itself (not the
  ≤ 5-slot draw) is what determines whether a `fog` node offers "Include"; `Expedition.compose`'s own
  `ComposeResult` only exposes up to 5 drawn slots, which is why this task cannot use `ComposeResult` as the
  fringe source of truth and instead calls the underlying set-formula function directly, cross-checked against
  a real `compose` call (§5 T4, AC12).

- `contracts/interaction-contract.md` — heading `## 3. Marker and trail` (v0.9.2):
  > - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
  >   selected course. Nodes upstream of the marker keep their mastery. The marker is past the course's
  >   last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the
  >   course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪ next(marker.unit)` window
  >   of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course
  >   are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id`
  >   is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker)
  >   regardless of `past_last_unit`.

  Source: `contracts/interaction-contract.md:62-71`. Binds `upstreamNodeIds` (§4 step 4): "keep their mastery"
  is why `NodeView.fogLevel` never overrides a node's real mastery for an upstream node (AC3, §6 decision
  default resolving the apparent conflict with `docs/domains/map.md` § W5 step 3 below).

- `contracts/interaction-contract.md` — heading `## 1. Mastery (per node, in \`StudentState\`)` (fog/cleared/
  blocked states):
  > States `fog → cleared`, `fog → blocked`, `blocked → cleared`, `cleared` stays `cleared` (map Q1: fog never
  > returns).

  Source: `contracts/interaction-contract.md:15-16` (excerpt of the states line; the full transition table is
  not reproduced here as this task does not perform transitions, only reads `Mastery` values already computed
  by `MasteryTransitions`). Binds AC3's due-ring rule (map Q1: a cleared node stays cleared and never re-fogs).

- `contracts/domain-glossary.md` — heading "Map and graph (Door C)":
  > - **Region** — one of the ten D21 territories (`region_id` fixed enum, `data-model.md`). *Banned:* "area",
  >   "zone", "strand".
  > - **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked**
  >   (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
  > - **Due** — a cleared node whose `next_due` has passed; drawn with a *due ring*. Not a mastery state.
  > - **Trail** — the student's one generated path over the graph (D47): **segments** that are either a
  >   **course segment** (`course_code`) or an **extension** (dashed). *Banned:* "path", "route", "track",
  >   "course trail" (a course is not a trail).
  > - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form
  >   in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".
  > - **Position indicator** — the first uncleared trail node at or after the marker (display only).
  > - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example",
  >   "story".

  Source: `contracts/domain-glossary.md:9-26`. Every identifier in `MapViewModel.swift` and every doc comment
  uses these terms; "start marker"/"cursor"/"position" (as a synonym for the marker) are banned even though
  `docs/domains/map.md` still uses "start marker" in places this task does not touch.

Domain-doc excerpts (verbatim, `docs/domains/map.md`):

- § Core entities — `MapViewModel` (`:54-57`):
  > **MapViewModel** — the pure derivation rendered each frame: regions with a tint from the fraction of their
  > nodes cleared (Q2), rivers, trails with marker and position indicator, landmarks, horizon labels, and the
  > label set for the current zoom (Q4). Derived in `Core` from bundles + `StudentState`; never persisted; the
  > renderer holds nothing the model does not (I14).

- § Core entities — `NodeView` (`:49-52`):
  > **NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from
  > `StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker),
  > `cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies
  > upstream of the current trail's marker.

- § W1 — Open the map (`:64-69`):
  > **Pre:** bundles loaded (platform); `StudentState` read. **Steps:** 1. Build `MapViewModel` (Tier 0, in
  > `Core`). 2. Render **trail first (D44)**: the camera frames the trail's current unit — the marker's unit
  > and the next — with the continent visible around it; zooming out reveals regions, horizon and the whole
  > trail; node names appear at the zoom threshold (Q4). 3. The position indicator is the first uncleared trail
  > node at or after the marker. **Post:** `map.opened` emitted.

- § W2 — Tap a node (`:71-77`):
  > **Pre:** map open. **Steps:** 1. Open the **node panel**: name, `paraphrase`, expectation codes with the
  > official link (I6), mastery state in plain words ("under fog", "cleared", "blocked — something upstream is
  > in the way"), "which courses walk through here" from trail data, linked landmarks. 2. Offer exactly one
  > action by state: fogged and reachable → "Include in my next expedition"; `blocked` or upstream of the
  > marker → "Check me here" (opens **diagnosis** W1 on this node, the D28 way in); `cleared` → nothing to do.
  > **Post:** no state change; `map.node_opened` emitted.

  This task's §4 step 6 resolves the case a plain reading of these two bullets leaves ambiguous — a `cleared`
  node that also happens to be upstream — as a decision default (§6): `cleared` always wins (`action == nil`),
  because "cleared → nothing to do" is unconditional in this same step, and W2's own list never combines the
  two.

- § W6 — Reflect state changes (`:97-100`):
  > **Pre:** expedition or diagnosis emitted a transition (`expedition.node_cleared`, `diagnosis.node_blocked`,
  > `expedition.node_due`). **Steps:** re-derive `MapViewModel`; lift fog, place a blocked marker or a due
  > ring, re-tint the region; a basic transition only — no animated mechanics (D24). **Post:** rendered.

- § Open questions Q1 (`:147-150`):
  > **Q1 — Does fog return when a cleared node falls due?** **Default:** no — a cleared node stays cleared on
  > the map and gains a *due* ring; only a failed re-probe (per D27 tolerance) can move it to `blocked`.
  > **Ratified 2026-09-09:** default accepted.

- § Open questions Q2 (`:152-157`):
  > **Q2 — Region tint for regions with no nodes.** **Default:** an empty region (the five unpopulated ones in
  > the Demo, any horizon region) is drawn as pure fog with no fraction; a populated region's tint is the
  > cleared fraction over its nodes on the student's selected trails, not all its nodes. **Ratified
  > 2026-09-09:** default accepted.

  **Correction**: `data/demo/nodes.json` carries only `region_id ∈ {number-operations, algebra, functions}`
  across its 20 nodes (grepped and verified, §3 "Data re-read" below), so 7 of the 10 content regions (not
  five) have no bundle nodes in the current `data/demo`; `docs/plans/epic-03-plan.md`'s planner notes already
  flag Q2's "five unpopulated" figure as stale and out of scope to fix here. AC1 uses the verified figure (7).

- § Open questions Q3 (`:160-163`):
  > **Q3 — What the horizon shows.** **Default:** the D21 (revised) labels only — Analysis, Topology, Number
  > Theory, Abstract Algebra — greyed, not tappable, no content. **Ratified 2026-09-09:** default accepted.

- § Open questions Q4 (`:165-168`):
  > **Q4 — Label zoom thresholds.** **Default:** region names at overview; node names when a node's drawn
  > diameter exceeds a fixed on-screen size [ESTIMATE: ~44 pt, Apple's minimum tap target]; landmark names
  > always. **Ratified 2026-09-09:** default accepted.

- § Invariants enforced here — I4 (`:133-134`):
  > - **I4 — the record half.** A `blocked` node beyond the cap is drawn and enterable; a test asserts every
  >   `blocked` id in `StudentState` appears in `MapViewModel` with the "Check me here" action and nothing
  >   else.

- § Invariants enforced here — I14 (`:131-132`):
  > - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and
  >   computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).

Prior task outputs this task calls (verbatim, re-verified against the current tree in this session):

- `Packages/Core/Sources/Core/Model/StudentState.swift:10-21, :23-27, :29-36, :38-42, :44-46, :48-52, :54-57`:
  ```swift
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
  public struct NodeState: Codable, Equatable {
      public let mastery: Mastery
      public let correctCount: Int
      public let lastProbe: String?
      public let nextDue: String?
      public let ladderRung: Int
      public let remediated: Bool?
  }
  public enum Mastery: String, Codable { case fog; case cleared; case blocked }
  public struct Trail: Codable, Equatable { public let segments: [TrailSegment] }
  public struct TrailSegment: Codable, Equatable {
      public let kind: SegmentKind
      public let courseCode: String?
      public let nodeIds: [String]
  }
  public enum SegmentKind: String, Codable { case course; case `extension` }
  ```

- `Packages/Core/Sources/Core/BundleIO.swift:8-16`:
  ```swift
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

- `Packages/Core/Sources/Core/Model/Nodes.swift:9-25`:
  ```swift
  public struct Node: Codable, Equatable {
      public let id: String
      public let name: String
      public let regionId: RegionId
      public let strand: String?
      public let expectationCodes: [NodeExpectationCode]?
      public let sourceRef: SourceRef?
      public let courses: [NodeCourse]
      public let position: Point
      public let layoutHint: Point?
      public let paraphrase: String
      public let explanation: String?
      public let workedExamples: [WorkedExample]?
      public let errorTypes: [ErrorType]
      public let hintTree: [String: [String]]
      public let probeItems: [ProbeItem]
  }
  public struct NodeExpectationCode: Codable, Equatable {
      public let courseCode: String
      public let code: String
  }
  ```

- `Packages/Core/Sources/Core/Model/Regions.swift:9-16`:
  ```swift
  public struct Region: Codable, Equatable {
      public let id: RegionId
      public let name: String
      public let about: String
      public let horizon: Bool
      public let polygon: [Point]
      public let neighbours: [RegionId]
  }
  ```

- `Packages/Core/Sources/Core/Model/Edges.swift:9-16`:
  ```swift
  public struct Edge: Codable, Equatable {
      public let from: String
      public let to: String
      public let sources: [EdgeSource]
      public let generationAgreement: Int
      public let confidence: Double
      public let probeStats: ProbeStats
  }
  ```

- `Packages/Core/Sources/Core/Model/Landmarks.swift:11-20`:
  ```swift
  public struct Landmark: Codable, Equatable {
      public let id: String
      public let name: String
      public let sourceTitle: String
      public let whatItIs: String
      public let sourceUrl: String
      public let nodeIds: [String]
      public let regionIds: [RegionId]
      public let position: Point
  }
  ```

- `Packages/Core/Sources/Core/Model/Courses.swift:9-18, :38-42`:
  ```swift
  public struct Course: Codable, Equatable {
      public let courseCode: String
      public let name: String
      public let vintage: String
      public let strands: [Strand]
      public let expectations: [Expectation]
      public let units: [Unit]
      public let unitSource: UnitSource?
      public let nextCourses: [String]
  }
  public struct Unit: Codable, Equatable {
      public let unitId: String
      public let name: String
      public let expectationCodes: [String]
  }
  ```

- `Packages/Core/Sources/Core/Model/Ids.swift:4-27`:
  ```swift
  public struct Point: Codable, Equatable { public let x: Double; public let y: Double }
  public enum RegionId: String, Codable, CaseIterable {
      case numberOperations = "number-operations"
      case algebra = "algebra"
      case functions = "functions"
      case geometryMeasurement = "geometry-measurement"
      case trigonometry = "trigonometry"
      case calculus = "calculus"
      case linearAlgebra = "linear-algebra"
      case differentialEquations = "differential-equations"
      case probabilityStatistics = "probability-statistics"
      case discrete = "discrete"
      case analysis = "analysis"
      case topology = "topology"
      case numberTheory = "number-theory"
      case abstractAlgebra = "abstract-algebra"
      case shore = "shore"
  }
  ```

- `Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21` (internal, module-visible, not `public`):
  ```swift
  struct GraphIndex {
      let nodesById: [String: Node]
      let edges: [Edge]
      let edgesByFrom: [String: [Edge]]
      let regionsById: [RegionId: Region]
      let coursesByCode: [String: Course]
      let sortedNodeIds: [String]
      init(bundle: ContentBundle) { /* … */ }
  }
  ```

- `Packages/Core/Sources/Core/Time/CalendarDay.swift:7-20`:
  ```swift
  public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
      public let iso: String
      public init?(iso: String) { /* … */ }
  }
  ```

- `Packages/Core/Sources/Core/State/Expedition.swift:120-214` (the D48 fringe/window formula and the three
  helper functions this task calls directly — `residentNodeIds` (`:125`), `unitIndex` (`:137`) and
  `scopeWindow` (`:152`), alongside `fringeNodeIds` (`:202`) itself — quoted verbatim as they exist on disk
  today, all four `private`, until this task's §2 visibility edit drops `private` from exactly these four
  declarations and changes no other character):
  ```swift
      // MARK: - Private fringe/window helpers

      /// A node is resident in course `X` iff its `expectationCodes` array (may be `nil`) contains ≥ 1
      /// entry whose `courseCode == X`. A second, independent implementation of the same rule 02.5's own
      /// (private, hence not importable) `MarkerTrailGeneration.swift` helper uses.
      private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> {
          Set(
              index.nodesById.values
                  .filter { node in
                      (node.expectationCodes ?? []).contains { $0.courseCode == course.courseCode }
                  }
                  .map(\.id))
      }

      /// A node's unit index within course `X` is the 0-based index into `course.units` of the unit named
      /// by the node's lowest-ordered expectation code for `X` (`contracts/graph-constraints.md` v1.1.0
      /// L0-T).
      private static func unitIndex(nodeId: String, course: Course, index: GraphIndex) -> Int? {
          guard let node = index.nodesById[nodeId] else { return nil }
          let entries = (node.expectationCodes ?? []).filter { $0.courseCode == course.courseCode }
          let ordinals: [Int] = entries.compactMap { entry in
              guard let unitId = course.expectations.first(where: { $0.code == entry.code })?.unitId else {
                  return nil
              }
              return course.units.firstIndex(where: { $0.unitId == unitId })
          }
          return ordinals.min()
      }

      /// The three readings of "`marker.unit ∪ next(marker.unit)`, or the requested unit only" (compose
      /// bullet), in priority order — unit expedition first, then past-last-unit (Q-F), then the ordinary
      /// current+next-unit window.
      private static func scopeWindow(
          marker: Marker, trail: Trail, index: GraphIndex, unitExpeditionUnitId: String?
      ) -> Set<String> {
          if let requestedUnit = unitExpeditionUnitId {
              guard let courseCode = requestedUnit.split(separator: ".").first.map(String.init),
                  let course = index.coursesByCode[courseCode]
              else { return [] }
              return residentNodeIds(course: course, index: index).filter { nodeId in
                  guard let idx = unitIndex(nodeId: nodeId, course: course, index: index),
                      idx < course.units.count
                  else { return false }
                  return course.units[idx].unitId == requestedUnit
              }
          }
          if marker.pastLastUnit == true {
              return Set(trail.segments.first(where: { $0.kind == .extension })?.nodeIds ?? [])
          }
          guard let course = index.coursesByCode[marker.courseCode],
              let markerUnitIdx = course.units.firstIndex(where: { $0.unitId == marker.unitId })
          else { return [] }
          return Set(
              residentNodeIds(course: course, index: index).filter { nodeId in
                  guard let idx = unitIndex(nodeId: nodeId, course: course, index: index) else { return false }
                  return idx == markerUnitIdx || idx == markerUnitIdx + 1
              })
      }

      private static func mastery(of nodeId: String, in state: StudentState) -> Mastery {
          state.nodes[nodeId]?.mastery ?? .fog
      }

      private static func isRemediated(_ nodeId: String, in state: StudentState) -> Bool {
          state.nodes[nodeId]?.remediated ?? false
      }

      private static func prerequisiteGuardSatisfied(
          _ nodeId: String, state: StudentState, edgesByTo: [String: [Edge]]
      ) -> Bool {
          (edgesByTo[nodeId] ?? []).allSatisfy { edge in
              let p = edge.from
              return mastery(of: p, in: state) == .cleared
                  || (mastery(of: p, in: state) == .blocked && isRemediated(p, in: state))
          }
      }

      /// The guard-eligible-and-in-window set unioned with the unconditional `blocked` set (the compose
      /// formula's `∪ {n : mastery(n) = blocked}`; the Q-A cascade note: "It is always fringe-eligible
      /// itself as `blocked`"). A `blocked` node outside every trail segment (no course, or a course not in
      /// `syllabi[]`) is still fringe-eligible — the union has no course/trail restriction on the `blocked`
      /// term.
      private static func fringeNodeIds(
          state: StudentState, bundle: ContentBundle, index: GraphIndex, edgesByTo: [String: [Edge]],
          marker: Marker, trail: Trail, unitExpeditionUnitId: String?
      ) -> Set<String> {
          let window = scopeWindow(
              marker: marker, trail: trail, index: index, unitExpeditionUnitId: unitExpeditionUnitId)
          let guardEligible = bundle.nodes.nodes.map(\.id).filter { nodeId in
              mastery(of: nodeId, in: state) != .cleared && window.contains(nodeId)
                  && prerequisiteGuardSatisfied(nodeId, state: state, edgesByTo: edgesByTo)
          }
          let blocked = bundle.nodes.nodes.map(\.id).filter { mastery(of: $0, in: state) == .blocked }
          return Set(guardEligible).union(blocked)
      }
  ```
  `residentNodeIds`, `unitIndex`, `scopeWindow` and `fringeNodeIds` are `private` (file-scoped) on disk today,
  at the line numbers above — not callable from `MapViewModel.swift` until this task's §2 edit widens exactly
  these four to `internal`. After that edit, `MapViewModel.swift` calls all four directly: `derive` (§4 step
  3) calls `Expedition.scopeWindow(marker:trail:index:unitExpeditionUnitId:)` with `unitExpeditionUnitId: nil`
  for its window (the requested-unit branch above is dead code from `MapViewModel`'s call site, since it never
  passes a non-`nil` value, but the branch itself is untouched) and `Expedition.fringeNodeIds(...)` for its
  fringe set; `MapViewModel`'s own private `upstreamNodeIds` helper (§4 step 4, a concept `Expedition.swift`
  does not itself compute, since `compose` never needs it) calls `Expedition.residentNodeIds`/
  `Expedition.unitIndex` directly. No function body in this excerpt is re-implemented anywhere in
  `MapViewModel.swift` (I14 single-source, AC14).

- `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift:29-119` (an existing, unrelated test file
  that independently restates the fringe formula for its own AC10 cross-check purpose — not a pattern this
  task's production code follows, since `MapViewModel.swift` calls `Expedition.fringeNodeIds` directly instead
  — but whose non-trivial `StudentState` fixture shape (a `blocked` + `remediated` node) this task's own T4
  test reuses):
  ```swift
  @Test("AC10: every new-learning slot is a member of an independently recomputed fringe set")
  func ac10NewLearningSlotsAreFringeMembers() throws { /* … */ }
  private static func independentFringe(
      bundle: ContentBundle, state: StudentState, marker: Marker
  ) throws -> Set<String> { /* … */ }
  ```

- `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:20-83` (the codebase's precedent for a
  structural source-scan guard with a negative control — T9/T9b follow its shape, not its file: one scan helper
  parameterised over its input, an empty-scan FAIL, a planted-violation case asserting detection, and a clean
  fixture asserting no detection):
  ```swift
      /// Mirrors `coreImportBoundary()`'s recursive-walk-plus-forbidden-import-scan logic, parameterised
      /// over a directory so it can run against a synthetic fixture as well as the real `Sources/Core`.
      private static func forbiddenImportViolations(in root: URL) throws -> [String] {
          // … enumerate *.swift …
          #expect(!files.isEmpty, "no source files found — empty scan is a FAIL")
          // … collect violations …
      }

      @Test("recursive scan catches a forbidden import planted inside a Model/ subdirectory")
      func recursiveScanCatchesPlantedViolation() throws { /* plant, scan, #expect detection */ }

      @Test("recursive scan reports no violations on a clean fixture tree")
      func recursiveScanIsCleanOnACleanTree() throws { /* clean, scan, #expect(violations.isEmpty) */ }
  ```

- `Packages/Core/Sources/Core/State/MasteryTransitions.swift:19-24`:
  ```swift
  public static func itemCorrect(
      current: NodeState, itemId: String, correctItemIds: Set<String>, today: CalendarDay
  ) -> MasteryTransitionResult
  ```

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` (per `tasks/epic-02-task-11-diagnosis-machine-seam.md`
  §4 step 3b and `tasks/arbitration/arbiter-02-11-stepwise-api.md` Ruling 1; **not yet landed — EPIC 02b must be
  wrapped before this task's AC13 test can run**, per `docs/epics/epic-03-app-map-shell.md:99-103, :388-392`):
  ```swift
  public static func run(
      trigger: DiagnosisTrigger, originNodeId: String, failedAttempts: [FailedProbeAttempt], levelBudget: Int,
      decisions: [DiagnosisLevelDecision], shownItemIdsInRun: Set<String>, state: StudentState,
      bundle: ContentBundle, today: CalendarDay
  ) -> DiagnosisOutcome
  public struct DiagnosisOutcome: Equatable {
      public let state: StudentState
      public let terminal: DiagnosisTerminal   // .refuted, .confirmed, .unconfirmed, .capped, .noPrerequisite
      // … depthReached, blockedNodeIds, hintNodeId, hintErrorTypeId, probeResults, events, code
  }
  public struct DiagnosisLevelDecision: Equatable {
      public let declineProbe: Bool
      public let submittedAnswers: [String]
      public let acceptFurtherLevel: Bool
      public init(declineProbe: Bool, submittedAnswers: [String], acceptFurtherLevel: Bool)
  }
  ```
  A `DiagnosisOutcome.terminal == .confirmed` sets `state.nodes[blockedNodeIds[0]].mastery == .blocked` and
  `remediated == true` (`tasks/epic-02-task-11-diagnosis-machine-seam.md` §4 step 3d, AC7/AC9). Budget 2 with
  `acceptFurtherLevel: false` on the first (and only) level yields `.confirmed`, not `.capped` — the "block, no
  cap" scenario this task's AC13 needs.

Data re-read this session (verbatim counts, not the bundle's citations, which named a non-existent
`Graph/GraphIndex.swift` path — corrected in §2):

- `data/demo/regions.json`: 14 region objects, 10 with `"horizon": false` (`number-operations`, `algebra`,
  `functions`, `geometry-measurement`, `trigonometry`, `calculus`, `linear-algebra`,
  `differential-equations`, `probability-statistics`, `discrete`), 4 with `"horizon": true` (`analysis`,
  `topology`, `number-theory`, `abstract-algebra`).
- `data/demo/nodes.json`: every node's `region_id` is one of `number-operations` (5 nodes), `algebra` (8
  nodes), `functions` (7 nodes) — 20 nodes total, 0 nodes in any other region. So 7 of the 10 content regions
  have no bundle nodes (not 5, as `docs/domains/map.md` Q2's stale prose says).
- `data/demo/courses.json`: `MTH1W.next_courses == ["MPM2D"]`, `MCR3U.next_courses == ["MHF4U"]`; neither
  `MPM2D` nor `MHF4U` is a course in `data/demo/courses.json`'s own `courses[]` array (only `MTH1W` and
  `MCR3U` are), so `MarkerTrail.generateTrail`'s `buildExtensionSegment` finds no match on real `data/demo` —
  the extension-dashed case (AC4) needs the existing `Fixtures/trail/extension-positive` fixture bundle.
- `data/demo/landmarks.json`: 1 landmark, `id: "canadian-mortgage-compounding"`, `node_ids: ["exponent-laws",
  "exponential-functions"]`, `source_url` present.
- `data/demo/manifest.json`: `starting_chain` begins `["linear-relations", "solving-linear-equations",
  "exponent-laws", "polynomials", "factoring", "solving-quadratics", …]` — the sequence this task's tests draw
  real node ids from.

## §4 Implementation outline

1. **Layer.** `Sources/Core/Map/MapViewModel.swift` is layer ④ interaction's map derivation (Door C), reading
   layer ① courses, layer ② nodes/edges/regions/trail and layer ③ landmarks as read-only inputs — it computes
   nothing that changes `StudentState` and performs no I/O, no clock read and no rendering.

2. **Public types** (all `Equatable`, no `Codable` — these values never cross the wire; every stored property
   `public let`; no `public init` other than the implicit memberwise ones Swift already restricts to this
   module for internal-initializer types — i.e. none of these types is constructible from `App/Sources` except
   via `MapViewModel.derive`):
   ```swift
   public struct MapViewModel: Equatable {
       public let regions: [RegionView]
       public let nodes: [NodeView]
       public let rivers: [River]
       public let trailSegments: [TrailSegmentView]
       public let positionIndicatorNodeId: String?
       public let landmarks: [LandmarkView]
       public let focusFrame: FocusFrame
   }
   public struct RegionView: Equatable {
       public let id: RegionId
       public let horizon: Bool
       public let clearedFraction: Double?   // nil = pure fog (map Q2/Q3)
   }
   public enum NodeAction: Equatable { case checkHere, include }
   public struct NodeView: Equatable {
       public let id: String
       public let regionId: RegionId
       public let position: Point
       public let fogLevel: Mastery          // fog / cleared / blocked, straight from StudentState
       public let due: Bool
       public let upstream: Bool
       public let action: NodeAction?        // nil = no action offered
   }
   public struct River: Equatable { public let from: String; public let to: String }
   public struct TrailSegmentView: Equatable {
       public let courseCode: String?
       public let nodeIds: [String]
       public let dashed: Bool
   }
   public struct LandmarkView: Equatable {
       public let id: String
       public let position: Point
       public let nodeIds: [String]
   }
   public struct FocusFrame: Equatable {
       public let minX: Double
       public let minY: Double
       public let maxX: Double
       public let maxY: Double
   }
   public struct LabelSet: Equatable {
       public let regionNames: Bool
       public let nodeNames: Bool
       public let landmarkNames: Bool
   }
   ```

3. **`MapViewModel.derive(bundle:state:today:)`** — the single public entry point.
   ```swift
   public static func derive(bundle: ContentBundle, state: StudentState, today: CalendarDay) -> MapViewModel
   ```
   Builds one `GraphIndex(bundle: bundle)` and one `edgesByTo = Dictionary(grouping: index.edges, by: \.to)`,
   then computes, in order: `window = Expedition.scopeWindow(marker: state.marker, trail: state.trail, index:
   index, unitExpeditionUnitId: nil)` (called directly — `internal` after §2's visibility edit), `upstream =
   upstreamNodeIds(marker: state.marker, bundle: bundle, index: index)` (step 4, `MapViewModel`'s own private
   helper), `fringe = Expedition.fringeNodeIds(state: state, bundle: bundle, index: index, edgesByTo:
   edgesByTo, marker: state.marker, trail: state.trail, unitExpeditionUnitId: nil)` (called directly, step 5),
   then builds `regions`, `nodes`, `rivers`, `trailSegments`, `positionIndicatorNodeId`, `landmarks` and
   `focusFrame` (step 6) from those three sets plus `bundle` and `state`. No thrown error anywhere in this
   function — an empty `window`/`fringe` produces an empty result set at each downstream step, never a
   `CoreError`.

4. **`upstreamNodeIds`** — `MapViewModel`'s one private helper (§2), implementing the contract's § 3
   "upstream of the marker" rule (quoted in §3) — a concept `Expedition.swift` does not itself compute, since
   `compose` never needs upstream membership. It calls `Expedition.residentNodeIds`/`Expedition.unitIndex`
   directly (both `internal` after §2's visibility edit) rather than restating either body:
   ```swift
   private static func upstreamNodeIds(marker: Marker, bundle: ContentBundle, index: GraphIndex) -> Set<String> {
       guard let course = index.coursesByCode[marker.courseCode] else { return [] }
       let resident = Expedition.residentNodeIds(course: course, index: index)
       if marker.pastLastUnit == true { return resident }
       guard let markerUnitIdx = course.units.firstIndex(where: { $0.unitId == marker.unitId }) else { return [] }
       return Set(
           resident.filter { id in
               guard let idx = Expedition.unitIndex(nodeId: id, course: course, index: index) else { return false }
               return idx < markerUnitIdx
           })
   }
   ```

5. **The window and the fringe.** Neither is computed by a function in `MapViewModel.swift`. `derive` (step 3)
   calls `Expedition.scopeWindow(marker:trail:index:unitExpeditionUnitId:)` directly for the window and
   `Expedition.fringeNodeIds(state:bundle:index:edgesByTo:marker:trail:unitExpeditionUnitId:)` directly for
   the fringe, both with `unitExpeditionUnitId: nil` (`MapViewModel` has no unit-expedition concept, so
   `scopeWindow`'s requested-unit branch is always skipped). This is the single I14 implementation of the D48
   fringe formula quoted in §3 (contract heading `## 2. Expedition`) — `MapViewModel.swift` contains no second
   definition of `scopeWindow` or `fringeNodeIds` (AC14, §5 T9/T9b).

6. **Building the output value.**
   - `regions`: for each `region` in `bundle.regions.regions` (14, real `data/demo`), `total` = the count of
     `bundle.nodes.nodes` with `regionId == region.id` **and** id present in `state.trail.segments.flatMap {
     $0.nodeIds }`; `clearedCount` = the subset of those with `mastery == .cleared`; `clearedFraction = total ==
     0 ? nil : Double(clearedCount) / Double(total)` (§6 decision default: this single rule covers both "empty
     region" and "horizon region", since both always have `total == 0`, and also covers a populated region with
     zero trail-resident nodes the same way).
   - `nodes`: for each `node` in `bundle.nodes.nodes`, `mastery = state.nodes[node.id]?.mastery ?? .fog`,
     `isUpstream = upstream.contains(node.id)`, `due = mastery == .cleared && (state.nodes[node.id]?.nextDue
     .map { $0 <= today.iso } ?? false)`. `action` per the priority order (§6 decision default, resolving the
     W2 ambiguity noted in §3):
     1. `mastery == .cleared` → `nil`;
     2. `mastery == .blocked` → `.checkHere`;
     3. `mastery == .fog && isUpstream` → `.checkHere`;
     4. `mastery == .fog && fringe.contains(node.id)` → `.include`;
     5. else → `nil`.
   - `rivers`: `bundle.edges.edges.map { River(from: $0.from, to: $0.to) }`, same order.
   - `trailSegments`: `state.trail.segments.map { TrailSegmentView(courseCode: $0.courseCode, nodeIds:
     $0.nodeIds, dashed: $0.kind == .extension) }`.
   - `positionIndicatorNodeId`: `state.trail.segments.flatMap { $0.nodeIds }.first { id in !upstream.contains(id)
     && (state.nodes[id]?.mastery ?? .fog) != .cleared }`.
   - `landmarks`: `bundle.landmarks.landmarks.map { LandmarkView(id: $0.id, position: $0.position, nodeIds:
     $0.nodeIds) }`.
   - `focusFrame`: `let positions = window.compactMap { index.nodesById[$0]?.position }`; if empty, `(0, 0)`–`(1,
     1)`; else the coordinate-wise min/max over `positions`.

7. **`MapViewModel.labelSet(atZoom:)`** and the `[ESTIMATE]` threshold constant:
   ```swift
   public func labelSet(atZoom zoomScale: Double) -> LabelSet {
       let nodeNames = zoomScale >= MapViewModel.nodeNameZoomThreshold
       return LabelSet(regionNames: !nodeNames, nodeNames: nodeNames, landmarkNames: true)
   }
   /// [ESTIMATE: the zoom multiple, relative to a whole-continent overview of 1.0, at which a node's drawn
   /// diameter is judged to exceed the ~44 pt minimum tap target (map Q4); no on-screen diameter model exists
   /// yet to derive this from first principles, so it is a placeholder the rendering task (03.10) may tune].
   public static let nodeNameZoomThreshold: Double = 3.0
   ```

8. **No error codes, no I/O, no model call.** `derive` and `labelSet` never throw and never read the clock —
   `today` is always the caller's injected `CalendarDay` (I14).

9. **Test-side scan helper (T9/T9b).** In `MapViewModelTests.swift`, one private static helper — the only scan
   logic T9 and T9b use, following the parameterised-over-its-input shape of
   `ImportBoundaryNegativeControlTests.forbiddenImportViolations(in:)` (§3):
   ```swift
   private static let singleSourceNames = ["scopeWindow", "fringeNodeIds", "residentNodeIds", "unitIndex"]

   /// Returns the subset of `singleSourceNames` declared (`func <name>`, any access modifier, `static` or
   /// not) in `source`. Lines whose trimmed form begins with `//` are skipped; call sites
   /// (`Expedition.<name>(`) never match because they carry no `func ` token.
   private static func restatedDeclarations(in source: String) -> Set<String> {
       var found: Set<String> = []
       for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
           let line = rawLine.trimmingCharacters(in: .whitespaces)
           if line.hasPrefix("//") { continue }
           for name in singleSourceNames where line.contains("func \(name)(") {
               found.insert(name)
           }
       }
       return found
   }
   ```

10. **Smoke check**: `swift test --package-path Packages/Core --filter MapViewModelTests` — must be green.

## §5 Test plan

- T1 (AC1, AC2, AC6, AC7, AC8, AC9, AC10, AC11 happy path, real `data/demo`): derive over a constructed
  `StudentState` with `syllabi: ["MTH1W"]`, the default marker, and a mix of `fog`/`cleared`/`blocked` nodes
  (including at least one `blocked` node inside the window and one outside it, and one `cleared` node with
  `nextDue` in the past). Assert the region count/horizon split, the cleared-fraction rule (including the pure-
  fog count of 11 = 7 empty content regions + 4 horizon), one river per edge, `labelSet` above/below/at the
  threshold, the focus frame's bounding box against the window nodes' real bundle positions, every `blocked`
  node's `action == .checkHere`, the `.include`/`.checkHere`/`nil` action split, and `derive` called twice with
  the same arguments produces `==` results.
- T2 (negative — invalid input rejected at the boundary): not applicable in the usual sense — `derive` has no
  throwing boundary (§4 step 8). Instead: over a `StudentState` whose `marker.courseCode` is absent from
  `bundle.courses.courses` (a state that should never reach this function post-reconciliation, but `derive`
  must not crash), assert `window`/`upstream`/`fringe` all resolve to empty sets, every node's `action` follows
  the priority rule with `isUpstream == false` for every node, and `focusFrame == (0,0)-(1,1)`.
- T3 (error taxonomy): not applicable — this task raises no `CoreError`. Documented here per the risk-tier
  template rather than omitted silently.
- T4 (conformance, §B.1, AC12, AC14, direct single-implementation check): over real `data/demo`, and
  separately over a constructed `StudentState` with at least one `blocked` + `remediated` node (matching
  `MarkerTrailFringeSeamTests.swift`'s fixture shape, not its file, per §3), build the same
  `GraphIndex(bundle:)` and `edgesByTo` `MapViewModel.derive` builds internally, call
  `Expedition.fringeNodeIds(state:bundle:index:edgesByTo:marker:trail:unitExpeditionUnitId:)` directly (now
  `internal`, §2) with `unitExpeditionUnitId: nil`, and separately call `MapViewModel.derive` over the same
  `(bundle, state, today)`. Assert the set of `NodeView.id`s with `action == .include` equals that
  directly-called `fringe` set intersected with the `fog`, non-upstream node ids
  (`(state.nodes[id]?.mastery ?? .fog) == .fog && !upstream.contains(id)`, where `upstream` is computed the
  same way `derive` computes it, step 4) — i.e. the derived `.include` flags are a pure re-expression of the
  one fringe implementation `Expedition.fringeNodeIds` returns, never a second computation of it. Also assert,
  per AC12, that a real `Expedition.compose(...)` call's `ComposeResult.slots` entries of `kind ==
  .newLearning` are each a subset of that same `.include` set (the ≤ 5-slot draw is a further narrowing of the
  fringe, never a wider one).
- T5 (non-vacuous-check guard for T4, AC14): before asserting the equality in T4, assert the directly-called
  `fringe` set (over the constructed `blocked` + `remediated` fixture) contains at least one `fog`,
  non-upstream node id — i.e. T4's `.include` set has at least one member — so a `derive` bug that always
  returns `action == nil` cannot pass T4's equality check by comparing two empty sets.
- T6 (AC4, extension dashed on the existing fixture): load `Fixtures/trail/extension-positive` via `BundleIO
  .read(from:)`, call `MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: Marker(courseCode: "MTH1W",
  unitId: <that fixture's own `course.units.last!.unitId`, resolved at test time, never hardcoded>,
  pastLastUnit: true), bundle:)`, build a matching empty-`nodes` `StudentState`, derive, and assert the
  `TrailSegmentView` whose `courseCode == "MPM2D"` has `dashed == true`, while the `MTH1W` course segment has
  `dashed == false`. Also assert real `data/demo` with `pastLastUnit: true` produces trail segments with no
  `dashed == true` entry (AC4's real-data negative half — `MPM2D`/`MHF4U` are absent from `data/demo`).
- T7 (AC3, upstream never overrides fog level): a constructed `StudentState` where an upstream node (per
  `upstreamNodeIds`) is `cleared` and another upstream node is still `fog`; assert both `NodeView.fogLevel`s
  equal their real `state.nodes[...].mastery` unchanged, and the `cleared` one's `action == nil` while the
  `fog` one's `action == .checkHere` (the §4 step 6 priority order, tested at both ends).
- T8 (AC13, W6 re-derivation; **depends on EPIC 02b being merged** — `DiagnosisRun` is confirmed absent from
  `Packages/Core/Sources` as of this session; this test cannot compile until then): starting from a `fog`-only
  `StudentState` over real `data/demo`, run `MasteryTransitions.itemCorrect` twice with two distinct item ids
  of the `starting_chain`'s first node (`linear-relations`) — its own two lowest-id `probeItems`, resolved at
  test time — to reach `mastery == .cleared`; separately run `DiagnosisRun.run(trigger: .mapCheckHere,
  originNodeId: "polynomials", failedAttempts: [], levelBudget: 2, decisions: [DiagnosisLevelDecision
  (declineProbe: false, submittedAnswers: [<two wrong values>], acceptFurtherLevel: false)],
  shownItemIdsInRun: [], state:, bundle:, today:)` and assert `terminal == .confirmed` (the query resolves
  `exponent-laws` as the candidate, per the worked example in `tasks/arbitration/arbiter-02-predispatch.md` §
  Q-G, cited by `tasks/epic-02-task-11-diagnosis-machine-seam.md` §3). Merge both resulting `nodes` dicts into
  one `StudentState` (union — the two transitions touch different node ids) and derive; assert
  `linear-relations`'s `NodeView.fogLevel == .cleared` and `exponent-laws`'s `NodeView.fogLevel == .blocked`
  with `action == .checkHere`.
- T9 (AC14, I14 single-source structural guard over the real file): resolve
  `Packages/Core/Sources/Core/Map/MapViewModel.swift` from `#filePath` (the test file's own path → up to
  `Packages/Core` → `Sources/Core/Map/MapViewModel.swift`), read it with `String(contentsOfFile:encoding:
  .utf8)`, and first assert the scan is not empty (**empty = FAIL**): the file exists at that path, its text is
  non-empty, and it contains `static func derive(` — so a wrong path, a renamed file, or an empty read cannot
  pass the guard vacuously. Then assert `restatedDeclarations(in: text).isEmpty` (§4 step 9's helper, the only
  scan logic used) — i.e. none of `scopeWindow`, `fringeNodeIds`, `residentNodeIds`, `unitIndex` is declared
  in the file; call sites `Expedition.<name>(` are permitted and do not match. It fails red the moment a
  future edit re-introduces a second implementation of any of the four functions in `Map/`.
- T9b (negative control for T9, following the planted-violation + clean-fixture shape of
  `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift`, §3): two `@Test` cases over
  synthetic in-memory source strings (no file I/O needed — the helper takes text), each calling the same
  `restatedDeclarations(in:)` helper T9 calls, never a copy of its logic.
  - Planted: a synthetic source containing one declaration of each of the four names with varied modifiers —
    `private static func scopeWindow(`, `static func fringeNodeIds(`, `internal static func residentNodeIds(`,
    `public static func unitIndex(` — plus a `static func derive(` line; assert the helper returns exactly
    `["scopeWindow", "fringeNodeIds", "residentNodeIds", "unitIndex"]` as a set (every planted name
    detected, `derive` not reported).
  - Clean: a synthetic source containing only the permitted forms — `static func derive(`, the four call
    sites `Expedition.scopeWindow(`, `Expedition.fringeNodeIds(`, `Expedition.residentNodeIds(`,
    `Expedition.unitIndex(`, and a comment line `// no func scopeWindow( here` — and assert the helper
    returns an empty set (no false positive on call sites or comments).

## §6 Decision defaults

- IF `docs/domains/map.md` § W5 step 3 ("nodes upstream of the marker are fog … never cleared") appears to
  conflict with `contracts/interaction-contract.md` § 3 ("Nodes upstream of the marker keep their mastery")
  THEN follow the contract: `NodeView.fogLevel` is always `state.nodes[id]?.mastery ?? .fog`, with no override
  for upstream nodes. RULE 5 and `CLAUDE.md`'s "contracts are the source of truth" resolve doc-vs-contract
  conflicts in the contract's favour; `docs/plans/epic-03-plan.md`'s planner notes already flag
  `docs/domains/map.md` as carrying known-stale prose ("start marker", Q2's "five unpopulated") this EPIC does
  not correct. This is a Q1 (information), resolved from `contracts/interaction-contract.md` § 3, not a Q4.
- IF a node is simultaneously `cleared` and upstream of the marker (a case W2's two bullets do not jointly
  disambiguate) THEN `action == nil` (the "cleared → nothing to do" bullet wins unconditionally) — per
  `contracts/domain-glossary.md`'s "Due" entry, a cleared node's only decoration is a possible due ring, never
  an action.
- IF the fringe/window formula cannot be reused without widening a `private` function's access
  (`Expedition.swift:125, :137, :152, :202`) THEN widen exactly those four declarations to `internal` (drop
  the `private` keyword, add no other qualifier, add no wrapper function) rather than restating the formula a
  second time in `MapViewModel.swift` — I14's single-source principle (one implementation of any given rule in
  `Core`) is exactly why a second file-scoped restatement of the same D48 formula would be the wrong call. No
  other line of `Expedition.swift` changes, and the landed `MarkerTrailFringeSeamTests.swift` (02.6) stays
  green unmodified since it does not reference these four functions by name.
- IF the T9 structural guard needs a negative control THEN it takes the shape of
  `ImportBoundaryNegativeControlTests.swift` (one parameterised scan helper; planted case asserts detection;
  clean case asserts none; empty scan = FAIL), but over in-memory text rather than a temp directory, because
  T9 scans one known file's text, not a directory walk (per `tasks/arbitration/arbiter-03-06-guard.md`).
- IF a region has bundle nodes but none on `state.trail` (zero trail-resident nodes, a case Q2's prose does not
  explicitly cover) THEN treat it the same as an empty/horizon region: `clearedFraction == nil` (§4 step 6's
  single `total == 0 → nil` rule covers this without a special case).
- IF the `window` (marker's-unit-∪-next-unit, or the extension segment) is empty THEN `focusFrame` defaults to
  `(0, 0)`–`(1, 1)` (the full normalised coordinate space every `Point` lives in, per `Ids.swift:3`'s "A
  normalised map coordinate in `[0, 1]` on each axis") rather than a degenerate zero-size frame.
- IF the map Q4 label-zoom threshold has no first-principles derivation available in `Core` (no on-screen
  diameter model exists at this layer) THEN pick a single `[ESTIMATE]`-tagged constant (`nodeNameZoomThreshold
  = 3.0`) and let the rendering task (03.10) tune it — consistent with the epic brief's own framing of this as
  "code constants from ratified defaults, not runtime-loaded configuration" (`docs/epics/epic-03-app-map-shell
  .md:192-194`).
- Standing defaults: identifiers and timestamps are untouched by this task (`MapViewModel` persists nothing);
  no model call anywhere (Tier 0 only, I2); no telemetry client in this task; no identifying field is
  introduced (`MapViewModel` carries only node/region/landmark ids already cleared by EPIC 01, plus `Double`/
  `Bool`/enum presentation data).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages/Core/Sources/Core/Map/MapViewModel.swift`,
  `Packages/Core/Sources/Core/State/Expedition.swift` and `Packages/Core/Tests/CoreTests/MapViewModelTests.swift`).
- typecheck clean (Swift's typecheck is the build: `swift build --package-path Packages/Core`).
- `Core` build + test green (`swift build --package-path Packages/Core`; `xcodebuild test -scheme Core-Package`
  on the simulator), including the existing import-boundary test extended over the new file (no SwiftUI/UIKit/
  SpriteKit import) and the landed `MarkerTrailFringeSeamTests.swift` (02.6) unmodified and still green.
- tests green for every case in §5 (T8 gated on EPIC 02b being merged first, per `docs/epics/epic-03-app-map-
  shell.md`'s own EPIC-order statement — if EPIC 02b is not yet merged when this task runs, T8 is written
  against `DiagnosisRun.run`'s signature as specified in `tasks/epic-02-task-11-diagnosis-machine-seam.md` and
  left failing-to-compile only until that merge, never stubbed or skipped). This explicitly includes T9 (the
  structural guard over the real `MapViewModel.swift`, empty scan = FAIL) and both T9b cases (planted
  declarations detected; clean fixture reports none), all three calling the single `restatedDeclarations(in:)`
  helper.
- conforms to every contract section cited in §3 and to every invariant listed in §1.

# Epic 02 · Task 06: D48 fringe + `compose`, shared item-draw function, C1 marker→trail→fringe seam

---
epic: 02
task: 06
slug: fringe-compose-seam
kind: feat
risk: seam
depends_on: [02.2, 02.4, 02.5]
model: sonnet
---

> **Bundle-defect note (report to the task-context-compiler).** The context bundle's §I sketches
> `compose`/`selectItem` signatures that reference `set_marker(course: String, unit: String) → Marker` and
> `generate_trail(syllabi:marker:state:bundle:today:) → (Trail, errors: [CoreError])`. Neither matches
> `tasks/epic-02-task-05-marker-trail-reconciliation.md`'s actual, already-written spec (re-read in this
> run): the real API is `MarkerTrail.setMarker(courseCode:unitId:pastLastUnit:syllabi:bundle:) throws ->
> SetMarkerResult` and `MarkerTrail.generateTrail(syllabi:marker:bundle:) throws -> TrailGenerationReport`
> — no `state`/`today` parameters, and `throws` rather than a returned `[CoreError]` array. This spec uses
> 02.5's real, committed-spec signatures (§3 below), not the bundle's guess. 02.5's own file
> (`Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`) has not landed at the time this spec is
> written (confirmed absent by `Glob` in this run) — it is "under review," so this task treats its spec
> as the authoritative future API, the same pattern 02.5 itself used for 02.4's not-yet-landed pieces.

## §1 Goal & acceptance criteria

Goal: give `Core` the D48 fringe computation and the `compose` function that fills an expedition's up-to-5
slots — the map-queued node first (if on the fringe), then fringe nodes in trail order, then up to 2 due
review slots — plus the deterministic item-draw function `selectItem` that this task defines once and that
tasks 02.7 (expedition run, retry exclusion) and 02.11 (diagnosis probe availability) both reuse by name.
This task owns the C1 seam test `MarkerTrailFringeSeamTests.swift`: real `MarkerTrail.setMarker` +
`MarkerTrail.generateTrail` (02.5) feeding a real `compose` call, on the real `data/demo` bundle, no
stubbed trail and no hand-built fringe.

Invariants in play:

- **I1 (I10)** — `compose` and `selectItem` never judge answer correctness; they select which `ProbeItem`s
  to show. No free-text path exists — `selectItem`'s only inputs are a `Node` (whose `probeItems` are
  already `numeric`/`mc`-typed per the data-model contract) and ids/strings, never a submitted answer.
  Satisfied structurally, not exercised by this task's own logic (I1's CAS-decision half is 02.7's
  `ItemChecker`).
- **I2** — every function in this task's scope is Tier-0 deterministic; `compose`/`selectItem` take no
  model or adapter argument and call none.
- **I3** — not directly exercised here (the answer/`why` display guarantee belongs to 02.7's `answer`
  result), but structurally true: every `ProbeItem` `compose` returns already carries `why` and either
  `answer` or `choices`/`correctChoiceId` per the data-model contract's closed `ProbeItem` shape — this
  task adds no path that could strip either field.
- **I4 (co-owner, brief §5)** — `compose`'s fringe guard is the load-bearing mechanism of "no new-learning
  item off the fringe or upstream of the marker unless the node is `blocked`": a node whose prerequisite is
  unmet is never in the guard-eligible set, and only `blocked` nodes bypass the guard/window entirely. This
  task does not implement backtracking (02.11's job) or the ≤2-level depth cap (I4's other half) — it
  satisfies its own half by construction, per the property test in §5.
- **I5** — no field is added to `StudentState`/`NodeState`/`Marker` (02.2's, already landed). The new
  public types this task ships (`ComposeSlot`, `ComposeResult`, `SlotKind`) carry only node/item ids, an
  enum case, and `ProbeItem` values (themselves already id/enum/LaTeX-only per the data-model contract) —
  no person, device, install or session identifier.
- **I14** — every function in `Expedition` is a pure value transformation over its arguments:
  `Foundation` only, no `Date()`, no file I/O, no global mutable state. `today` is always the caller's
  injected `CalendarDay`. `Core`'s existing `coreImportBoundary()` test (unmodified) covers the new file
  with no edit.
- **D27** — not engaged by this task (one retry / one diagnosis per run is 02.7's/02.11's state machine);
  recorded so the absence is a decision, not a gap. `compose` runs once, at expedition start, before any
  item is answered.
- **D45 / D46 / D48** — this task **is** the runtime realisation of D48 (fringe), scoped by D45 (the
  course-progress marker's current+next unit) and narrowed by D46 (a unit expedition restricts the window
  to one requested unit).

Acceptance criteria (each independently verifiable):

- AC1: `Expedition.compose(state:, bundle:, trail:, marker:, today:)` called with the real `data/demo`
  bundle, `trail` = `MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: <default MTH1W marker>,
  bundle:).trail` (02.5 AC1's trail), `marker` = that same default marker (`MTH1W.u1`, `pastLastUnit:
  false`), and a `StudentState` whose `nodes` dict is empty (every node implicitly `fog`), returns exactly
  two new-learning slots, in this order: `nodeId == "integer-operations"`, then `nodeId ==
  "rational-numbers"` — both have zero prerequisites in `data/demo/edges.json`, so their guard is
  vacuously satisfied, while `order-of-operations`'s sole prerequisite (`integer-operations`, `fog`) and
  `exponent-laws`'s sole prerequisite (`solving-linear-equations`, `fog`) are unmet. Zero review slots
  (no `cleared` node exists), `skippedNodeIds == []`, no error thrown.
- AC2: Same setup as AC1, but `state.nodes["exponent-laws"] = NodeState(mastery: .blocked, correctCount: 0,
  lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: true)`. The result's new-learning slots are, in
  trail order, `integer-operations`, `rational-numbers`, `exponent-laws`, `scientific-notation` —
  `exponent-laws` is fringe-eligible unconditionally because it is `blocked` (window membership does not
  matter for a `blocked` node); `scientific-notation`'s sole prerequisite is now `exponent-laws`, whose
  mastery is `blocked` **and** `remediated == true`, so its guard is satisfied and, being in the window
  (`MTH1W.u1 ∪ MTH1W.u2`), it joins the fringe. `order-of-operations` still fails its own guard
  (`integer-operations` is `fog`) and is absent.
- AC3: Same setup as AC1, but `state.nodes["linear-relations"] = NodeState(mastery: .cleared, correctCount:
  2, lastProbe: "2026-08-01", nextDue: "2026-09-01", ladderRung: 0, remediated: nil)` and `today =
  CalendarDay(iso: "2026-09-10")!`. The result carries the same two AC1 new-learning slots plus exactly one
  review slot: `nodeId == "linear-relations"`, `kind == .review` — `next_due ("2026-09-01") ≤ today
  ("2026-09-10")` and its mastery is `cleared`.
- AC4: A property test over `PropertyGen`-driven `NodeState` maps (§5 T4) asserts, for every generated
  `(StudentState, marker, trail)` triple: `reviewSlots.count == min(2, dueCandidateCount)` and
  `newLearningSlots.count == min(5 - reviewSlots.count, fringeCandidateCount)`, so the total never exceeds
  5 and review never exceeds 2, for every generated combination including one where both pools exceed their
  share (giving exactly 3 new-learning + 2 review) and one where the fringe pool is smaller than 3 (giving
  fewer than 3 new-learning and up to 5 - newLearningSlots.count review, still capped at 2).
- AC5: `queuedNodeId: "rational-numbers"` under the AC1 setup places `rational-numbers` in slot 1 and does
  not duplicate it later in the new-learning list — the result's new-learning order is
  `["rational-numbers", "integer-operations"]`. `queuedNodeId: "order-of-operations"` (not on the fringe:
  its own guard is unmet) under the same setup returns the AC1 result **unchanged** — `compose` does not
  throw and does not add a slot for the ignored node.
- AC6: `unitExpeditionUnitId: "MTH1W.u4"` under the AC1 setup (marker still at `MTH1W.u1`) returns exactly
  one new-learning slot, `nodeId == "simplifying-expressions"` (u4's only zero-prerequisite node in
  `data/demo`), even though `MTH1W.u4` is outside the default `marker.unit ∪ next(marker.unit)` window
  (`u1 ∪ u2`) — proving the unit-expedition parameter overrides the marker window rather than intersecting
  with it.
- AC7: A `StudentState` in which every node the window admits is already `cleared` with a `nextDue` strictly
  after `today`, no node is `blocked`, and no node is due, causes `compose` to `throw
  CoreError.expNoFringe`.
- AC8: On the existing `Packages/Core/Tests/CoreTests/Fixtures/l0/valid` bundle (unmodified, already
  committed) with `syllabi = ["MTH1W"]`, default marker, and `state.nodes["matrix-multiplication"] =
  NodeState(mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated:
  nil)`: `matrix-multiplication` (an undergraduate node with `"probe_items": []` in that fixture, confirmed
  by re-reading the file in this run) is fringe-eligible (unconditionally, as `blocked`) but yields no slot
  — `selectItem` returns `nil` for it (empty pool) — so it appears in `skippedNodeIds` and `slots` carries
  only the one item drawn from `exponent-laws` (that fixture's other, zero-prerequisite, item-bearing
  node). `compose` does not throw.
- AC9: `Expedition.selectItem(from:excluding:probeLog:)` on a two-item node: with an empty `probeLog`,
  returns the item whose id sorts first ascending (both unused, tie by id). With one `probeLog` entry for
  item A dated `"2026-01-01"` and one for item B dated `"2026-06-01"` (both items otherwise unused before
  those dates), returns item A (the earlier most-recent-use day — "least recently used"). Called twice with
  byte-identical arguments (fresh values each call) returns `Equatable`-equal results both times.
- AC10 (C1 seam): `MarkerTrailFringeSeamTests.swift` drives, on the real `data/demo` bundle: a real
  `MarkerTrail.setMarker` call, a real `compose` call over its result, and an independent (in-test,
  formula-level, not calling any `Expedition` private helper) recomputation of the D48 fringe set for that
  same trail/marker/state. Every new-learning slot's `nodeId` is asserted to be a member of that
  independently recomputed set.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/State/Expedition.swift` — CREATE. The `Expedition` enum namespace,
  `compose`, `selectItem`, the new public result/value types (`ComposeSlot`, `SlotKind`, `ComposeResult`),
  and every private helper (§4).
- `Packages/Core/Tests/CoreTests/ExpeditionComposeTests.swift` — CREATE. This task's own companion test
  suite (§5) covering AC1–AC9 and the negative controls — everything except the C1 seam, which lives in its
  own file per the plan.
- `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift` — CREATE. The C1 marker→trail→fringe
  seam test (AC10), real `data/demo`, real `MarkerTrail` (02.5) + real `compose` (this task), no stub.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift` — task 02.5's file. This task calls
  `MarkerTrail.setMarker`/`.generateTrail` (in the seam test only) and reads `Trail`/`TrailSegment`/
  `SegmentKind` unmodified; it does not implement or re-implement trail generation.
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift`, `Packages/Core/Sources/Core/Time/
  CalendarDay.swift`, `Packages/Core/Sources/Core/Events/CoreEvent.swift`, `Packages/Core/Sources/Core/
  CoreError.swift` — task 02.4's files, already landed as this task's precondition. This task reads
  `CalendarDay`, `CoreError.expNoFringe`/`.expItemPoolEmpty` unmodified; it does not add a case to either
  enum (both already registered by 02.4) and does not touch `MasteryTransitions` (mastery transitions are
  02.7's job — `compose` never calls `itemCorrect`/`itemMissReview`/`diagnosisBlocked`).
- `Packages/Core/Sources/Core/Model/StudentState.swift` — 02.2's file; this task reads `NodeState`,
  `Marker`, `Trail`, `TrailSegment`, `SegmentKind`, `ProbeLogEntry` unmodified.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — 02.4's file, already ships `calendarDay`,
  `mastery`, `element`, `bool`, `int`, `nodeState`, `nodesMap` (confirmed present by reading it in this
  run). This task's property test (§5 T4) uses these existing generators; it does not add a new one — no
  random-graph/random-bundle generator is needed because AC4's property test holds `bundle`/`trail`/`marker`
  fixed (the real `data/demo` MTH1W window) and only varies `state.nodes` via `PropertyGen.nodesMap`.
- `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/**` — read-only reuse (AC8); this fixture already exists
  and already contains a zero-item node (`matrix-multiplication`); this task changes none of its files.
- `data/demo/**` — read-only fixture data.
- `contracts/interaction-contract.md`, `contracts/graph-constraints.md`, `contracts/data-model.md`,
  `contracts/error-codes.json` — read-only ground truth; this task lands no contract bump (both error codes
  it uses, `EXP_NO_FRINGE` and `EXP_ITEM_POOL_EMPTY`, are already registered by 02.4).
- `Packages/Core/Sources/Core/State/{ItemChecker,Diagnosis}*.swift` — 02.7's and 02.11's files; this task
  ships no answer-checking, no expedition run state machine, no diagnosis flow. Those tasks import
  `Expedition.selectItem` by name; this task does not call forward into either.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition (Door B)`, `compose` bullet (re-read,
  byte-compared in this run):
  > `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  > cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  > requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if
  > on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
  > `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.
  > `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).
- `contracts/interaction-contract.md` — heading `## 2. Expedition (Door B)`, Properties bullet (re-read,
  byte-compared in this run):
  > **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker
  > unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review
  > slots; every item shown ends with its answer visible.
- `contracts/domain-glossary.md` — Fringe, Slot entries (re-read, byte-compared in this run):
  > **Fringe** — the trail's outer fringe (D48): nodes not cleared whose prerequisites are cleared.
  > *Banned:* "frontier" (v2 name), "next up", "available".
  >
  > **Slot** — one of the ≈ 5 places in an expedition: **new-learning slot** (from the fringe) or **review
  > slot** (due node).
- `docs/domains/expedition.md` — W1 Start an expedition (re-read, byte-compared in this run):
  > **Pre:** bundles loaded; `StudentState` read; a trail generated (W8); optionally a unit id for a unit
  > expedition (D46, `map.unit_expedition_requested`). **Steps:** 1. (Tier 0, `Core`) Compute the Fringe
  > within the current + next unit (or the requested unit only). 2. Fill up to ≈ 5 slots (Q3): first any
  > node queued from the map (map Q5), then fringe nodes in trail order, then — new-learning slots exhausted
  > or the review quota unused — `cleared` nodes whose `next_due` has passed, oldest `last_probe` first
  > (≤ 2, v2.7 §3). 3. Draw one `ProbeItem` per slot from **learning-objects** W3 (single-item variant),
  > preferring items unused in the last N runs. 4. If the fringe and due sets are both empty, raise
  > `EXP_NO_FRINGE` and stop.
- `docs/domains/expedition.md` — Q3 Slot mix per run (re-read, byte-compared in this run):
  > **Q3 — Slot mix per run.** **Default:** 5 slots — up to 3 frontier (map-queued first), up to 2 due; if
  > one pool is short the other fills. **Trade-off:** keeps every run moving forward; a due-heavy run feels
  > like revision, a frontier-only run lets cleared nodes rot silently.
  > **Ratified 2026-09-09:** default accepted.
- `docs/domains/expedition.md` — error codes table, `EXP_NO_FRINGE`/`EXP_ITEM_POOL_EMPTY` rows (re-read,
  byte-compared in this run):
  > | `EXP_NO_FRINGE` | Nothing on the fringe in the current + next unit and nothing due | "You've cleared
  > everything up to here. Move your class marker forward, or explore the map." | Yes |
  > | `EXP_ITEM_POOL_EMPTY` | A frontier node has no unused item | Node skipped this run; internal count |
  > Yes — pool grows at M5 |
- `tasks/arbitration/arbiter-02-predispatch.md` — Q-A cascade note for 02.6 (re-read, byte-compared in this
  run):
  > **Cascade note for 02.6.** A prerequisite that is `capped` or blocked on a spent Door A event keeps its
  > downstream nodes off the fringe until it is cleared. It is always fringe-eligible itself as `blocked`.
  > This is intended, per I4 ("deeper gaps are marked on the map only").
- `tasks/arbitration/arbiter-02-predispatch.md` — Q-G ruling and test-data rule (re-read, byte-compared in
  this run):
  > An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown
  > in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of
  > the candidate is available. Among available items the draw order of learning-objects W3 applies.
  >
  > **Test-data rule** (02.5, 02.6, 02.11):
  > - In-memory bundles derived from `data/demo` are allowed for property tests over generated graphs (brief
  >   AC5) and for the extension positive case (02.5, where `data/demo` has no `next_courses` target).
  > - The C1 seams (AC7, AC8) and the AC6 terminal suite run on the real `data/demo` bundle. Only the
  >   `StudentState` is constructed.
  > - A test that substitutes a bundle there fails review.
- `docs/epics/epic-02-core-behaviour.md` § 9 Open questions — "Technical defaults (not Q5; …)" bullet (lines
  472–475 at time of writing; citation corrected by the orchestrator — originally misattributed to the arbiter
  file, which does not contain this text):
  > - No unused item for a D27 retry → skip the retry, log `EXP_ITEM_POOL_EMPTY`, continue the run.
  > - Item draw prefers items with no `probe_log` entry, then the least recently used, deterministic by
  >   item id.

Prior signatures this task builds on (from the codebase and `tasks/epic-02-task-05-marker-trail-
reconciliation.md`, verbatim, re-read in this run):

```swift
// Packages/Core/Sources/Core/Model/StudentState.swift:23-36 (current, task 02.2 already landed)
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

public struct Trail: Codable, Equatable {
    public let segments: [TrailSegment]
}

public struct TrailSegment: Codable, Equatable {
    public let kind: SegmentKind
    public let courseCode: String?
    public let nodeIds: [String]
}

public enum SegmentKind: String, Codable {
    case course
    case `extension`
}

public struct ProbeLogEntry: Codable, Equatable {
    public let day: String
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let retry: Bool
}
```

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift:9-25, 54-65 (current, unmodified)
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

public struct ProbeItem: Codable, Equatable {
    public let id: String
    public let type: ProbeItemType
    public let promptLatex: String
    public let why: String
    public let renderFallback: RenderFallback?
    public let answer: ProbeAnswer?
    public let wrongAnswers: [WrongAnswer]?
    public let choices: [ProbeChoice]?
    public let correctChoiceId: String?
    public let check: ProbeCheck?
}
```

```swift
// Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21 (internal, same module, unmodified)
struct GraphIndex {
    let nodesById: [String: Node]
    let edges: [Edge]
    let edgesByFrom: [String: [Edge]]
    let regionsById: [RegionId: Region]
    let coursesByCode: [String: Course]
    let sortedNodeIds: [String]

    init(bundle: ContentBundle) { ... }
}
```

```swift
// Packages/Core/Sources/Core/CoreError.swift:18, 20 (current, task 02.4 already landed)
    case expNoFringe = "EXP_NO_FRINGE"
    case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
```

The future `MarkerTrail` API this task's seam test (AC10) calls (`tasks/epic-02-task-05-marker-trail-
reconciliation.md` §4, quoted verbatim, re-read in this run — not yet committed to the repo at the time of
this run; see the bundle-defect note atop this spec):

```swift
public enum MarkerTrail {
    public static func generateTrail(
        syllabi: [String], marker: Marker, bundle: ContentBundle
    ) throws -> TrailGenerationReport

    public static func setMarker(
        courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
    ) throws -> SetMarkerResult

    public static func defaultMarker(syllabi: [String], bundle: ContentBundle) -> Marker?
    // reconcileMarker, reconcileNodeIds omitted — not called by this task
}

public struct TrailGenerationReport: Equatable {
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let event: CoreEvent
}

public struct SetMarkerResult: Equatable {
    public let marker: Marker
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let events: [CoreEvent]
}
```

02.5's own AC1 fixture values this spec's AC1–AC8 build on (`tasks/epic-02-task-05-marker-trail-
reconciliation.md` §1 AC1, re-read in this run):

> `MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: <default MTH1W marker>, bundle: <real data/demo>)`
> returns a `Trail` with exactly one `course` segment, `courseCode == "MTH1W"`, `nodeIds ==
> ["integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
> "scientific-notation", "linear-relations", "solving-linear-equations", "solving-systems-of-equations",
> "simplifying-expressions", "polynomials", "factoring"]`.

`data/demo/edges.json` (re-read in this run): the only edge into `order-of-operations` is `integer-
operations --> order-of-operations`; the only edge into `exponent-laws` is `solving-linear-equations -->
exponent-laws`; the only edge into `scientific-notation` is `exponent-laws --> scientific-notation`;
`integer-operations`, `rational-numbers`, and `simplifying-expressions` have no incoming edge in the file.

`data/demo/courses.json` (re-read in this run): `MTH1W.u1 = {integer-operations, order-of-operations,
rational-numbers}` (via expectation codes B1.1–B1.3), `MTH1W.u2 = {exponent-laws, scientific-notation}`
(B2.1–B2.2), `MTH1W.u4 = {simplifying-expressions, polynomials, factoring}` (C2.1–C2.3).

`Packages/Core/Tests/CoreTests/Fixtures/l0/valid/nodes.json` (re-read in this run): the node
`matrix-multiplication` carries `"courses": []`, `"source_ref": {...}` (undergraduate), and `"probe_items":
[]` (zero items — schema-valid, no `minItems` constraint on `probe_items`, confirmed by reading
`contracts/schemas/nodes.schema.json` in this run). `Fixtures/l0/valid/edges.json` carries exactly one edge,
`exponent-laws --> exponential-functions`; `exponent-laws` itself has no incoming edge in that file.

Gate commands (verbatim, from `scripts/gate.sh`, re-read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by `Packages/Core/Tests/CoreTests/CoreTests.swift:1-2`, re-read in this run):
Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

Layer placement: layer ④ interaction, expedition W1 (compose) plus the single-item variant of learning-
objects W3 (`selectItem`). Reads layer ① (`Unit`, `Course.expectations`), layer ② (`edges[]`, `confidence`
— read but unused here, since the fringe guard is mastery-only, not confidence-weighted), and layer ③
(`Node.probeItems`) as read-only inputs; writes nothing.

**Precondition (hard dependency, not advisory, matching 02.4's and 02.5's own precondition pattern):**
tasks 02.2 (`NodeState.remediated`, `Marker.pastLastUnit`), 02.4 (`CoreError.expNoFringe`/
`.expItemPoolEmpty`, `CalendarDay`), and 02.5 (`MarkerTrail`, `TrailGenerationReport`, `SetMarkerResult`)
must be merged before this task's seam test (`MarkerTrailFringeSeamTests.swift`) compiles — it calls
`MarkerTrail.setMarker`/`.generateTrail` directly. `Expedition.swift` itself and
`ExpeditionComposeTests.swift` depend only on 02.2 and 02.4 (they take a caller-supplied `Trail` value and
never call `MarkerTrail`), so they can compile before 02.5 lands; only the seam test file has the harder
dependency. Do not add any 02.2/02.4/02.5 type or case yourself if the corresponding task has not landed —
those are out of scope here (§2).

### 1. New types (`Packages/Core/Sources/Core/State/Expedition.swift`, top of file)

```swift
import Foundation

/// One of the ≈ 5 places in an expedition (`contracts/domain-glossary.md` § Slot). Never call this
/// "frontier" — that name is explicitly banned by the same glossary entry.
public enum SlotKind: String, Equatable {
    case newLearning
    case review
}

/// One filled slot: the node it targets, the drawn `ProbeItem`, and whether it is new-learning (from the
/// fringe) or review (a due `cleared` node).
public struct ComposeSlot: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind
}

/// The result of `Expedition.compose`. `skippedNodeIds` are fringe/due candidates whose item pool was
/// empty (`selectItem` returned `nil`) — logged, not thrown (`EXP_ITEM_POOL_EMPTY` is "Node skipped this
/// run; internal count", `docs/domains/expedition.md` § error codes, quoted §3), in the order they were
/// skipped.
public struct ComposeResult: Equatable {
    public let slots: [ComposeSlot]
    public let skippedNodeIds: [String]
}
```

### 2. `Expedition` namespace and public API

```swift
public enum Expedition {
    /// D48 fringe + slot fill (`contracts/interaction-contract.md` § 2 `compose`, quoted § 3). `trail` is
    /// always the caller's own, already-generated `Trail` (e.g. `MarkerTrail.setMarker`'s result) — this
    /// function never regenerates a trail and never reads `state.trail` (§6 decision default). `today` is
    /// always the caller's injected `CalendarDay` (I14). Throws `CoreError.expNoFringe` iff both the
    /// fringe node set and the due node set are empty.
    public static func compose(
        state: StudentState,
        bundle: ContentBundle,
        trail: Trail,
        marker: Marker,
        today: CalendarDay,
        queuedNodeId: String? = nil,
        unitExpeditionUnitId: String? = nil
    ) throws -> ComposeResult

    /// The single-item draw (learning-objects W3, single-item variant), reused by 02.7 (excludes items
    /// already answered in the current run, for D27's retry) and 02.11 (excludes items already answered in
    /// the current run, for the Q-G "available" probe-item definition). `excludedItemIds` is always empty
    /// at `compose` time — nothing has been shown yet in a run that has not started. Among the remaining
    /// candidates, prefers an item with no `probeLog` entry, then the item whose most-recent `probeLog` day
    /// is earliest ("least recently used"), then the lower item id (brief §9 technical default, quoted §3).
    /// Returns `nil` iff every item of `node` is excluded or `node.probeItems` is empty.
    public static func selectItem(
        from node: Node,
        excluding excludedItemIds: Set<String>,
        probeLog: [ProbeLogEntry]
    ) -> ProbeItem?

    // MARK: - Private fringe/window helpers (step 3)

    private static func mastery(of nodeId: String, in state: StudentState) -> Mastery { ... }
    private static func isRemediated(_ nodeId: String, in state: StudentState) -> Bool { ... }
    private static func prerequisiteGuardSatisfied(
        _ nodeId: String, state: StudentState, edgesByTo: [String: [Edge]]
    ) -> Bool { ... }
    private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> { ... }
    private static func unitIndex(nodeId: String, course: Course, index: GraphIndex) -> Int? { ... }
    private static func scopeWindow(
        marker: Marker, trail: Trail, index: GraphIndex, unitExpeditionUnitId: String?
    ) -> Set<String> { ... }
    private static func fringeNodeIds(
        state: StudentState, bundle: ContentBundle, index: GraphIndex, edgesByTo: [String: [Edge]],
        marker: Marker, trail: Trail, unitExpeditionUnitId: String?
    ) -> Set<String> { ... }
    private static func dueNodeIds(state: StudentState, today: CalendarDay) -> [String] { ... }
    private static func trailOrder(_ trail: Trail) -> [String] { ... }
}
```

### 3. Fringe and window computation

`residentNodeIds` and `unitIndex` re-derive the same node-unit assignment rule 02.5's own (private, hence
not importable) `MarkerTrailGeneration.swift` helpers use — a node's unit is the unit of its lowest-ordered
`expectationCodes` entry for the given course (`contracts/graph-constraints.md` v1.1.0 L0-T, as 02.5's own
spec quotes it: "a node's unit is the unit of its lowest-ordered expectation code of that course"). This is
a **second, independent implementation of the same rule**, not a shared call — the invariant it must
satisfy on its own is: for every node resident in a course, `unitIndex` returns the 0-based index into
`course.units` matching that rule, agreeing with whatever 02.5's `generateTrail` used to place the node in
its segment (§5 T4 asserts this agreement empirically over `data/demo`, since the two files cannot share a
`private` helper across a module boundary that does not exist here — both live in `Core`, but 02.5's helper
is `private` to its own file per that task's own spec).

```swift
private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> {
    Set(
        index.nodesById.values
            .filter { node in (node.expectationCodes ?? []).contains { $0.courseCode == course.courseCode } }
            .map(\.id))
}

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
```

`scopeWindow` implements the three readings of "`marker.unit ∪ next(marker.unit)`, or the requested unit
only" (compose bullet, quoted §3), in priority order — unit expedition first, then past-last-unit (Q-F),
then the ordinary current+next-unit window:

```swift
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
```

`fringeNodeIds` combines the guard-eligible-and-in-window set with the unconditional `blocked` set (the
compose bullet's `∪ {n : mastery(n) = blocked}`, and the Q-A cascade note, quoted §3: "It is always
fringe-eligible itself as `blocked`"):

```swift
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

### 4. Due nodes and trail order

```swift
private static func dueNodeIds(state: StudentState, today: CalendarDay) -> [String] {
    let due = state.nodes.filter { _, ns in
        ns.mastery == .cleared && (ns.nextDue.map { $0 <= today.iso } ?? false)
    }
    return due.keys.sorted { lhs, rhs in
        let l = state.nodes[lhs]?.lastProbe
        let r = state.nodes[rhs]?.lastProbe
        switch (l, r) {
        case (nil, nil): return lhs < rhs
        case (nil, .some): return true
        case (.some, nil): return false
        case let (.some(ld), .some(rd)):
            if ld != rd { return ld < rd }
            return lhs < rhs
        }
    }
}

private static func trailOrder(_ trail: Trail) -> [String] {
    trail.segments.flatMap(\.nodeIds)
}
```

`CalendarDay.iso` string comparison is valid here for the same reason `CalendarDay.Comparable` uses it
(`Packages/Core/Sources/Core/Time/CalendarDay.swift:36-38`, re-read in this run): two zero-padded
`"YYYY-MM-DD"` strings of equal length sort lexicographically in chronological order.

### 5. `compose` body

```swift
public static func compose(
    state: StudentState, bundle: ContentBundle, trail: Trail, marker: Marker, today: CalendarDay,
    queuedNodeId: String? = nil, unitExpeditionUnitId: String? = nil
) throws -> ComposeResult {
    let index = GraphIndex(bundle: bundle)
    let edgesByTo = Dictionary(grouping: index.edges, by: \.to)
    let fringe = fringeNodeIds(
        state: state, bundle: bundle, index: index, edgesByTo: edgesByTo, marker: marker, trail: trail,
        unitExpeditionUnitId: unitExpeditionUnitId)
    let due = dueNodeIds(state: state, today: today)
    guard !(fringe.isEmpty && due.isEmpty) else { throw CoreError.expNoFringe }

    let reviewSlotsCount = min(2, due.count)
    let newLearningCap = 5 - reviewSlotsCount

    var newLearningOrder: [String] = []
    if let queued = queuedNodeId, fringe.contains(queued) { newLearningOrder.append(queued) }
    newLearningOrder += trailOrder(trail).filter { fringe.contains($0) && $0 != queuedNodeId }
    newLearningOrder += fringe.subtracting(Set(newLearningOrder)).sorted()

    var slots: [ComposeSlot] = []
    var skipped: [String] = []

    for nodeId in newLearningOrder {
        guard slots.filter({ $0.kind == .newLearning }).count < newLearningCap else { break }
        guard let node = index.nodesById[nodeId] else { continue }
        if let item = selectItem(from: node, excluding: [], probeLog: state.probeLog) {
            slots.append(ComposeSlot(nodeId: nodeId, item: item, kind: .newLearning))
        } else {
            skipped.append(nodeId)
        }
    }

    for nodeId in due {
        guard slots.filter({ $0.kind == .review }).count < reviewSlotsCount else { break }
        guard let node = index.nodesById[nodeId] else { continue }
        if let item = selectItem(from: node, excluding: [], probeLog: state.probeLog) {
            slots.append(ComposeSlot(nodeId: nodeId, item: item, kind: .review))
        } else {
            skipped.append(nodeId)
        }
    }

    return ComposeResult(slots: slots, skippedNodeIds: skipped)
}
```

`reviewSlotsCount = min(2, due.count)` computed first, then `newLearningCap = 5 - reviewSlotsCount`, is
this task's reconciliation of the compose bullet's literal fill order ("fringe nodes in trail order, then
... due cleared nodes ... ≤ 2 review slots") with Q3's "up to 3 frontier, up to 2 due; if one pool is
short the other fills" default — see §6 decision default 1 for the full justification; it is not spelled
out arithmetically by either source alone.

### 6. `selectItem`

```swift
public static func selectItem(
    from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]
) -> ProbeItem? {
    let candidates = node.probeItems.filter { !excludedItemIds.contains($0.id) }
    guard !candidates.isEmpty else { return nil }

    var lastUsed: [String: String] = [:]
    for entry in probeLog {
        if let existing = lastUsed[entry.itemId] {
            if entry.day > existing { lastUsed[entry.itemId] = entry.day }
        } else {
            lastUsed[entry.itemId] = entry.day
        }
    }

    return candidates.min { lhs, rhs in
        switch (lastUsed[lhs.id], lastUsed[rhs.id]) {
        case (nil, nil): return lhs.id < rhs.id
        case (nil, .some): return true
        case (.some, nil): return false
        case let (.some(lDay), .some(rDay)):
            if lDay != rDay { return lDay < rDay }
            return lhs.id < rhs.id
        }
    }
}
```

### 7. Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles the new
file even though `core-cli`'s `main.swift` calls none of it yet, matching 02.4's and 02.5's own smoke-check
pattern).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path** (`ExpeditionComposeTests.swift`, real `data/demo` loaded via `BundleIO.read` unless
  noted):
  - AC1, AC2, AC3: exact `compose` scenario assertions (slot order, `kind`, `skippedNodeIds == []`).
  - AC5: `queuedNodeId` on-fringe and off-fringe scenario assertions.
  - AC6: `unitExpeditionUnitId` scenario assertion.
  - AC9: `selectItem` unused-first / LRU / tie-break scenario assertions, on a hand-built two-item `Node`
    value (constructed directly in the test, per §6's decision default — no bundle needed for a pure
    function's own unit test).
- **T2 negative — invalid input rejected at the boundary:**
  - AC7: the all-`cleared`-not-yet-due, no-`blocked` scenario throws `CoreError.expNoFringe`.
  - AC8: on `Fixtures/l0/valid` (unmodified), `matrix-multiplication` set `.blocked` yields
    `skippedNodeIds == ["matrix-multiplication"]` and `slots` containing only the `exponent-laws` item;
    `compose` does not throw (an item-pool-empty node is not a fringe-emptiness condition).
  - `selectItem` on a `Node` whose `probeItems` is empty (`Fixtures/l0/valid`'s `matrix-multiplication`,
    read directly from the fixture bundle) returns `nil` regardless of `excludedItemIds`/`probeLog`.
  - `selectItem` with `excludedItemIds` covering every item of a two-item node returns `nil`.
- **T3 error-taxonomy:** a table-driven assertion that `CoreError.expNoFringe.rawValue == "EXP_NO_FRINGE"`
  and `CoreError.expItemPoolEmpty.rawValue == "EXP_ITEM_POOL_EMPTY"` — the exact registry strings this
  task's throw/skip paths use, cross-checked against `contracts/error-codes.json` (already covered
  end-to-end by 02.4's unmodified `ErrorRegistryTests`, re-run here as a gate, not re-implemented).
- **T4 conformance per requirements §B.1 / cited contract and invariants:**
  - AC4: the slot-count property test — `PropertyGen.nodesMap` (02.4's, unmodified) generates `state.nodes`
    over the fixed `data/demo` MTH1W `window (u1 ∪ u2)` node set, across seeded runs; for each generated
    `StudentState`, `reviewSlots.count == min(2, dueCandidateCount)` and `newLearningSlots.count == min(5 -
    reviewSlots.count, fringeCandidateCount)`, with `dueCandidateCount`/`fringeCandidateCount` independently
    recomputed in the test from the same contract formula (not by calling `Expedition`'s private helpers).
  - I4 co-owner: a property test asserts, over the same generated `StudentState`s, that every
    `newLearning`-kind slot's `nodeId` either (a) is `blocked` in the generated state, or (b) is in the
    window **and** every one of its `edgesByTo` prerequisites (independently recomputed from `data/demo/
    edges.json` in the test) is `cleared` or `blocked`-and-`remediated` — the literal Properties bullet's
    "never draws a new-learning item off the fringe or upstream of the marker unless the node is `blocked`"
    (quoted §3).
  - I14: `xcrun swift-format lint --strict` passes over the new file (mechanical); a dedicated grep
    assertion (mirroring 02.4's/02.5's `Date()` scan) confirms zero occurrences of `Date()` in
    `Expedition.swift`; `Core`'s existing `coreImportBoundary()` test is re-run unmodified and stays green.
  - `unitIndex`/`residentNodeIds` agreement check (§4 step 3's own stated obligation): for every node
    `MarkerTrail.generateTrail` places in `data/demo`'s MTH1W course segment (02.5 AC1's exact list, quoted
    §3), this task's own `unitIndex`/`residentNodeIds` (called directly in the test) assign it to the same
    unit 02.5's fixture table (§3) implies from the course's `units[]`.
- **T5 negative control for every regression guard:**
  - Guard "review slots computed before new-learning, capped independently at 2 regardless of fringe size":
    reconstruct (locally, in the test file — do not modify product code) a variant that fills new-learning
    up to 5 first and only then fills review with whatever room remains, and prove it produces `reviewSlots
    == 0` on AC4's "fringe ≥ 5, due = 2" case — differing from the real implementation's `reviewSlots == 2`
    — proving the real ordering is load-bearing, not accidentally satisfied by the simpler-looking
    fringe-first-no-reservation alternative.
  - Guard "`selectItem` prefers unused over LRU, not the reverse": reconstruct a variant that sorts purely
    by `lastUsed` day (treating `nil` as `"9999-12-31"`, i.e., "used furthest in the future" rather than
    "never used") and prove it wrongly prefers a once-used, long-ago item over a never-used one when the
    once-used item's day sorts earlier than a hand-picked sentinel — the negative control for AC9's "no
    `probeLog` entry beats any dated entry" property.
  - Guard "a `blocked` node is fringe-eligible unconditionally, not intersected with the window": reconstruct
    a variant that applies the window filter to the `blocked` set too, and prove it drops AC2's
    `exponent-laws` from the fringe when the window is narrowed to exclude it (e.g. via
    `unitExpeditionUnitId: "MTH1W.u4"`) — proving the real implementation's union-after-window (not
    intersect) is load-bearing.
  - Guard "a `queuedNodeId` off the fringe is dropped, not force-inserted": reconstruct a variant that
    always inserts `queuedNodeId` at slot 1 regardless of fringe membership, and prove it wrongly adds
    `order-of-operations` (AC5's off-fringe case) as a slot — the negative control for AC5's "ignored"
    clause.
- **T6 idempotency / no-leak:** `compose` and `selectItem`, called twice with byte-identical arguments
  (fresh `StudentState`/`ContentBundle`/`Trail`/`Marker`/`[ProbeLogEntry]` values each call, not a reused
  mutated variable), return `Equatable`-equal results both times (pure functions, no hidden state). No
  `StudentState`, `Trail`, or `ContentBundle` value passed in is mutated by either function — this task
  ships no writer of any kind (mirroring 02.4's and 02.5's own T6 disposition for non-persistence tasks).

**C1 seam test** (`MarkerTrailFringeSeamTests.swift`, real `data/demo`, real `MarkerTrail` + real
`compose`, per the Q-G test-data rule quoted §3 — "The C1 seams ... run on the real `data/demo` bundle.
Only the `StudentState` is constructed."):

- AC10: load `data/demo` via `BundleIO.read`. Call the real `MarkerTrail.setMarker(courseCode: "MTH1W",
  unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"], bundle: bundle)` (02.5). Construct a
  `StudentState` using that result's `.marker` and `.trail`, with a small hand-built `nodes` dict (e.g. the
  AC2 blocked-and-remediated scenario, reused here for a non-trivial fringe). Call the real
  `Expedition.compose(state:, bundle:, trail: result.trail, marker: result.marker, today:)`. Independently,
  in the test, recompute the D48 fringe set for that same `(state, trail, marker)` from the contract
  formula (quoted §3) — a fresh implementation written in the test file, not a call into any `Expedition`
  private helper — and assert every `newLearning`-kind slot's `nodeId` is a member of that independently
  recomputed set. Assert the test never substitutes a hand-built `Trail`/`ContentBundle`/fringe list for
  `MarkerTrail`'s or `compose`'s own real output — both calls are the real, imported functions.

## §6 Decision defaults

- IF the compose bullet's literal fill order ("fringe nodes in trail order, then ... due cleared nodes ...
  ≤ 2 review slots") is read as "fill new-learning up to 5 first, then top up review with whatever room is
  left" THEN it produces `reviewSlots == 0` whenever the fringe alone reaches 5, contradicting Q3's stated
  *default* shape of "up to 3 frontier ... up to 2 due" (`docs/domains/expedition.md` Q3, quoted §3) for the
  common case where both pools are plentiful. This task instead computes `reviewSlotsCount = min(2,
  dueCandidateCount)` **first**, then `newLearningCap = 5 - reviewSlotsCount`, then fills new-learning up to
  that cap — this is the only reading under which BOTH "never more than 2 review slots" (the Properties
  bullet, quoted §3, a hard cap regardless of fringe size) AND "up to 3 frontier, up to 2 due" (the Q3
  default, quoted §3) AND "if one pool is short the other fills" (Q3, quoted §3 — new-learning expanding
  past 3 when due is short) are simultaneously true. Neither source states this arithmetic explicitly; this
  is this task's own reconciliation, and T5's first negative control proves the alternative reading is
  observably different and wrong against Q3's stated default.
- IF a fringe or due candidate's item pool is empty (`selectItem` returns `nil`) THEN `compose` skips it
  (records it in `skippedNodeIds`) and continues to the next candidate in that same slot category — never
  throws, never aborts the whole call (`docs/domains/expedition.md` § error codes, quoted §3:
  `EXP_ITEM_POOL_EMPTY` is "Node skipped this run; internal count", "Recoverable: Yes").
- IF a `blocked` node lies outside every trail segment (no course, or a course not in `syllabi[]` — e.g. an
  undergraduate node, as in AC8) THEN it is still fringe-eligible (the compose formula's union has no
  course/trail restriction on the `blocked` term) and is appended to the new-learning candidate order after
  every trail-ordered candidate, sorted by node id ascending, for determinism — the contract's "trail
  order" only defines an order for nodes the trail actually lists; this task adds a deterministic secondary
  key for the (real-`data/demo`-unreachable, but real-on-other-bundles, per AC8) case where it does not.
- IF `queuedNodeId` names a node not on the fringe THEN it is silently dropped — the compose bullet's "if on
  the fringe" is already conditional, and the brief's AC3 states a queued node upstream of the marker "is
  ignored," with no error code associated with this case.
- IF the due-node sort ties on `lastProbe` (including both `nil`) THEN it breaks by node id ascending — the
  contract only specifies "oldest `last_probe` first" (compose bullet, quoted §3); this task adds a
  deterministic secondary key, consistent with every other explicit id tie-break in this EPIC (Kahn's-
  algorithm id order in 02.3/02.5, quoted in 02.5's own §3).
- IF `today` should be read from a live clock inside `compose`/`selectItem` THEN it must not be —
  `today: CalendarDay` is always the caller-injected value (I14), matching 02.4's and 02.5's own precedent;
  `selectItem` never reads a clock at all (its recency signal is entirely `probeLog[].day`, already-stored
  calendar-day strings).
- IF `selectItem`'s "least recently used" should be computed from the earliest-ever `probeLog` day for an
  item rather than the most-recent day THEN it uses the most recent (`max`) day per item — "least recently
  used" (brief §9 technical default, quoted §3) means the longest time since the item was **last** shown, not
  since it was first shown; using the earliest day would wrongly treat an item probed once long ago the same
  as one probed many times recently, up to yesterday.
- IF `compose` should read `state.trail` instead of the caller-supplied `trail` parameter THEN it does not —
  `trail` is always the caller's freshly generated value (matching the brief's AC8 language, "sets the
  marker on real `data/demo` state, generates the trail and composes an expedition from **that** trail"),
  avoiding staleness between a cached `state.trail` and a trail `set_marker` just regenerated in the same
  operation.

Standing defaults: identifiers and timestamps follow `contracts/data-model.md` (calendar days only, string
comparison of `nextDue`/`lastProbe`/`probeLog[].day`, no sub-day timestamp anywhere in this task's code); no
model call exists anywhere in this task's code (I2); no field is added to `StudentState`/`NodeState`/
`Marker` by this task (I5) — task 02.2 owns the two fields this task depends on (`remediated`,
`pastLastUnit`); every new type (`ComposeSlot`, `SlotKind`, `ComposeResult`) carries only node/item ids, an
enum case, and an unmodified `ProbeItem` value. No node's `paraphrase`/`explanation`/`workedExamples` is
read or touched by this task (I6) — `compose`/`selectItem` read only `Node.id`, `.expectationCodes`,
`.probeItems`.

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the new file and the two new test files.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6, plus the C1 seam AC10) pass.
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` (both unmodified, 02.4's files) stay green.
- No file under `Packages/Core/Sources/Core` contains the literal `Date()` (I14).
- Conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 2 `compose` and
  Properties; `contracts/domain-glossary.md` § Fringe, § Slot; `docs/domains/expedition.md` W1, Q3, § error
  codes; `tasks/arbitration/arbiter-02-predispatch.md` § Q-A cascade note, § Q-G; `docs/epics/epic-02-core-behaviour.md` § 9 Technical defaults) and
  to every invariant listed in §1 (I1/I10, I2, I3, I4, I5, I14).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and are unaffected by
  this task's file scope).

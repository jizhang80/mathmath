# Epic 02 · Task 05: Marker, trail generation (D47), and W7 load-time reconciliation

---
epic: 02
task: 05
slug: marker-trail-reconciliation
kind: feat
risk: seam
depends_on: [02.1, 02.3, 02.4]
model: sonnet
---

> **Bundle defects found and corrected in this run (report to the task-context-compiler).**
> 1. `tasks/context/epic-02-task-05-context.md` §H's MCR3U u1 segment order — `[solving-quadratics,
>    quadratic-functions, rational-expressions]` — is **wrong**. Applying the Q5-ruling's own tie-break
>    rule (Kahn's algorithm, ties broken by node id **among currently-available zero-indegree
>    candidates**, per `tasks/epic-02-task-03-l0t-trail-rule-contract.md` §6's own decision default,
>    which this spec also adopts) to `data/demo/courses.json` + `data/demo/edges.json` as they exist
>    today (re-read and re-derived in this run) gives `[rational-expressions, solving-quadratics,
>    quadratic-functions]` — `rational-expressions` is isolated (no in-course edges) and therefore has
>    indegree 0 from the start, and `"rational-expressions" < "solving-quadratics"` lexicographically, so
>    it is picked **first**, not last. This is not a difference of opinion: task 02.3's own §4 step 3
>    hand-computed fixture (already written, `tasks/epic-02-task-03-l0t-trail-rule-contract.md`) states
>    the *correct* order (`rational-expressions` first) and directly contradicts the context bundle's §H.
>    This spec uses **02.3's fixture**, per the dispatching instruction to treat 02.3 as authoritative for
>    orderings; §3 and §4 below reproduce 02.3's fixture, not the bundle's.
> 2. The context bundle's §I item 8 and §F assign the C1 marker→trail→fringe seam test
>    (`MarkerTrailFringeSeamTests.swift`) to **this** task. That is impossible to honour as scoped: the
>    seam test calls `compose`, which does not exist until task 02.6 (`docs/plans/epic-02-plan.md`'s own
>    task table assigns this file to **02.6**: "Owns C1 marker→trail→fringe
>    (`MarkerTrailFringeSeamTests.swift`...)"), and this task's `depends_on` is `[02.1, 02.3, 02.4]` — not
>    02.6. Writing that file here would create a dependency cycle the plan does not have. This spec follows
>    the **plan's** task table (§2 below) and leaves `MarkerTrailFringeSeamTests.swift` to 02.6; this
>    task ships its own companion test file instead (§2, §5).

## §1 Goal & acceptance criteria

Goal: give `Core` the pure, deterministic functions that own expedition W6 (set the course-progress
marker) and W8 (generate the trail, D47), plus the `Core` half of W7 (load-time reconciliation of a
persisted marker and persisted node ids against the installed bundle). All five functions are namespaced
under one new public type, `MarkerTrail`, in a new file. This task does not implement `compose` (fringe;
task 02.6) and does not edit `L0Checker.swift` — the L0-T check this task performs is its own
independent, re-derivable validation, living beside the construction code it double-checks, exactly as
`contracts/graph-constraints.md`'s L0-T row already says of the *rule* ("same `Core` function; runs at
generation, not on the bundle") without naming a file.

Invariants in play:

- **I2** — no model call, no adapter, anywhere in this task's code; every function is Tier-0 deterministic.
  Not otherwise engaged (recorded so the absence is a decision, not a gap).
- **I4** — this task does not implement backtracking or the fringe guard (02.6's job); it satisfies I4's
  co-owned half only by construction: `MarkerTrail.generateTrail` never reads or writes `mastery`, so it
  cannot itself violate "deeper gaps are marked on the map only" — there is no record it could create.
- **I5** — no field is added to `StudentState`/`Marker`/`NodeState` (02.2's job, already landed as a
  precondition). `TrailWarning`, `TrailGenerationReport`, `SetMarkerResult`,
  `MarkerReconciliationResult` and `NodeIdReconciliationResult` (§2) carry only node/course/unit ids,
  booleans and `CoreError`/`CoreEvent` enum cases — no person, device, install or session identifier.
- **I7** — `generateTrail` derives every segment from `syllabi[]` + `marker` + the bundle's own
  `courses[]`/`edges[]`; there is no per-course authored trail anywhere in this file, and no course is
  special-cased.
- **I8** — this task **is** the runtime implementation of L0-T as rewritten by the owner's Q5 ruling
  (`tasks/blocked/Q5-RULING-02-QE.md`, carried into the contract by task 02.3): every constructed course
  segment is unit-order-then-topological-within-unit with ties by node id; an against-unit-order edge is
  a **warning**, never a failure; every extension-segment node is reachable from the segment before it.
  A segment that fails this independent check raises `CoreError.expTrailInvalid`
  (`EXP_TRAIL_INVALID`) and — per §6's decision default — neither the trail nor the marker is mutated;
  the caller's previously-held values stand unchanged, matching the contract's "the previous trail
  stands."
- **I14** — every function in `MarkerTrail` is a pure value transformation over its arguments: no
  `Date()`, no file I/O, no global mutable state, `Foundation` only. `Core`'s existing
  `coreImportBoundary()` test (unmodified) continues to cover the new file with no edit.

Acceptance criteria (each independently verifiable; these narrow brief AC2, `docs/epics/epic-02-core-behaviour.md`
§4 item 2, to this task's exact scope):

- AC1: `MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: <default MTH1W marker>, bundle: <real
  data/demo>)` returns a `Trail` with exactly one `course` segment, `courseCode == "MTH1W"`, `nodeIds ==
  ["integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
  "scientific-notation", "linear-relations", "solving-linear-equations", "solving-systems-of-equations",
  "simplifying-expressions", "polynomials", "factoring"]`, and exactly one warning:
  `TrailWarning(courseCode: "MTH1W", from: "solving-linear-equations", to: "exponent-laws")`.
- AC2: `MarkerTrail.generateTrail(syllabi: ["MTH1W", "MCR3U"], marker: <default MTH1W marker>, bundle:
  <real data/demo>)` returns a `Trail` with the AC1 MTH1W segment followed by a `course` segment
  `courseCode == "MCR3U"`, `nodeIds == ["rational-expressions", "solving-quadratics",
  "quadratic-functions", "function-concept", "domain-and-range", "function-notation",
  "function-transformations", "exponential-functions", "logarithms"]` (§3's corrected fixture — note
  `rational-expressions` **first**), and zero additional warnings (the MCR3U segment carries none).
- AC3: `MarkerTrail.setMarker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi:
  ["MTH1W"], bundle: <real data/demo>)` returns a `SetMarkerResult` whose `.marker == Marker(courseCode:
  "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false)`, `.trail` equal to AC1's trail (marker position does
  not change the trail's node order — only `compose`, 02.6, reads marker position to window the fringe),
  and `.events == [.expeditionMarkerChanged, .expeditionTrailGenerated]`.
- AC4: on an in-memory bundle derived from `data/demo` (§4 step 6) that adds a synthetic `MPM2D` course
  with ≥ 1 node reachable by a forward edge from `factoring` (MTH1W's sole segment terminal — no
  outgoing edge within the MTH1W segment), `generateTrail` with `marker.pastLastUnit == true` and
  `marker.courseCode == "MTH1W"` returns a trail whose last segment has `kind == .extension`, whose
  `courseCode == "MPM2D"`, and whose every node is reachable (BFS, forward edges) from the MTH1W course
  segment — this is the positive extension case, run only on the synthetic bundle because `data/demo`'s
  `next_courses` targets (`MPM2D`, `MHF4U`) are absent from `data/demo` itself (confirmed:
  `data/demo/courses.json` lists only `MTH1W` and `MCR3U`).
- AC5: `generateTrail` with the same real-`data/demo` inputs as AC1 but `marker.pastLastUnit == true`
  returns a trail with **no** `.extension` segment (no downstream-course node is present in `data/demo`).
- AC6: a course segment or extension segment that independently fails this task's own re-derivation of
  L0-T (§4 steps 3–4) causes `generateTrail`/`setMarker` to `throw CoreError.expTrailInvalid`, and no
  `Trail` or `Marker` value is returned (§6 decision default: the previous trail/marker, held by the
  caller, is left untouched by construction — this function simply does not produce a replacement).
- AC7: `MarkerTrail.defaultMarker(syllabi: ["MTH1W", "MCR3U"], bundle: <real data/demo>) ==
  Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)` (first unit of the first course in
  `syllabi[]` present in the bundle); `defaultMarker(syllabi: ["ZZZ9Z"], bundle: <real data/demo>) ==
  nil` (no resolvable course).
- AC8: `MarkerTrail.reconcileMarker` implements the Q-D off-trail definition exactly
  (`tasks/arbitration/arbiter-02-predispatch.md` § Q-D, quoted §3): a marker whose `courseCode ∉
  syllabi[]`, or whose course is absent from the bundle, or whose `unitId` is not one of that course's
  `units[]`, is off-trail and the result carries `.code == .mapMarkerOffTrail` and `.marker ==
  defaultMarker(syllabi:bundle:)` when that resolves, else `.marker` is the **unchanged input marker**
  (still `.code == .mapMarkerOffTrail`) when no course in `syllabi[]` resolves in the bundle. An on-trail
  marker returns `.code == nil` and `.marker` unchanged.
- AC9: `MarkerTrail.reconcileNodeIds(nodes: <a dict with one key absent from data/demo's node set>,
  bundle: <real data/demo>)` returns `.ignoredNodeIds == [<that one key>]` and `.code ==
  .expNodeNotInGraph`; called with a `nodes` dict whose every key is a real `data/demo` node id returns
  `.ignoredNodeIds == []` and `.code == nil`. The function never mutates or drops entries itself — it
  only reports which ids the caller should keep-but-ignore (I14: pure, no persistence side effect).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift` — CREATE. The `MarkerTrail` enum
  namespace, its five public functions, the five new public result/value types (§4), and every private
  helper (unit lookup, topological sort, reachability, warning/violation detection).
- `Packages/Core/Tests/CoreTests/MarkerTrailGenerationTests.swift` — CREATE. This task's own companion
  test suite (§5) — the marker→trail seam is real-`data/demo` scenario tests plus the synthetic-fixture
  extension/negative cases; it does **not** call `compose` (02.6, not yet shipped).
- `Packages/Core/Tests/CoreTests/Fixtures/trail/extension-positive/{manifest,regions,nodes,edges,courses,landmarks,sources}.json`
  — CREATE. A small synthetic bundle: `data/demo`'s MTH1W course plus a synthetic `MPM2D` course with a
  forward edge from `factoring` (§4 step 6) — the AC4 positive extension fixture, following the shape of
  the existing `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/` fixture set (same `regions.json` may be
  reused byte-for-byte; it is schema-generic and already covers every region id this fixture needs).
- `Packages/Core/Tests/CoreTests/Fixtures/trail/unit-cycle/{manifest,regions,nodes,edges,courses,landmarks,sources}.json`
  — CREATE. A small synthetic bundle whose single course has two nodes in one unit joined by edges in
  **both** directions (an intra-unit cycle) — the AC6 negative-control fixture that exercises this task's
  own defensive L0-T re-check (§4 step 3), independent of whether such a bundle could ever pass the
  pipeline's own L0-1 acyclicity check (it is a hand-built unit-test input for this function alone, never
  loaded through `L0Checker`).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Validation/L0Checker.swift` — never edited by this task (plan: "Does not
  edit `L0Checker.swift`"). L0-T has no implementation there today (its own doc comment: "L0-T is EPIC
  02's") and none is added there by this task either — the runtime check lives beside the construction
  code it double-checks, in the new file above.
- `Packages/Core/Sources/Core/Validation/GraphIndex.swift` — read-only reuse. This task constructs
  `GraphIndex(bundle:)` (its `init` is internal, visible within the `Core` module) to get `nodesById`,
  `edges`, `edgesByFrom` and `coursesByCode` without re-deriving them; it is never modified.
- `Packages/Core/Sources/Core/Model/StudentState.swift`, `Packages/Core/Sources/Core/CoreError.swift`,
  `Packages/Core/Sources/Core/Events/CoreEvent.swift` — tasks 02.2 and 02.4's files, already landed as
  this task's precondition (§6). This task reads `Marker.pastLastUnit`, `NodeState`, `CoreError.expTrailInvalid`
  / `.expNodeNotInGraph` / `.mapMarkerOffTrail`, and `CoreEvent.expeditionMarkerChanged` /
  `.expeditionTrailGenerated` unmodified.
- `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift` — **not created here** (see the
  bundle-defect note above). This is `docs/plans/epic-02-plan.md`'s task 02.6 file; it needs `compose`,
  which does not exist yet.
- `Packages/Core/State/{Fringe,Compose,ItemChecker,Diagnosis}*.swift` — 02.6/02.7/02.10/02.11's files;
  this task ships no scheduling, no item checking, no diagnosis.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — 02.4's file. This task does not add a
  random-graph generator to it; every scenario in §5 uses either real `data/demo` or a small,
  hand-built, named fixture (§2 above), per the Q-G test-data rule
  (`tasks/arbitration/arbiter-02-predispatch.md` § Q-G: "In-memory bundles derived from `data/demo` are
  allowed... for the extension positive case (02.5...)").
- `contracts/interaction-contract.md`, `contracts/graph-constraints.md`, `contracts/error-codes.json` —
  read-only ground truth (tasks 02.1, 02.3's files respectively; error codes already registered by 02.4).
  This task lands no contract bump.
- `data/demo/**` — read-only fixture data; the Q5 ruling is explicit that `data/demo` is not changed.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rule this task implements (the **future** v0.9.1 text task 02.1 lands — quoted from
`tasks/epic-02-task-01-contract-interaction-numeric-normalisation.md` §4 step 5, since the committed
`contracts/interaction-contract.md` is still v0.9.0 at the time of this run, re-read and byte-compared):

> The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
> names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
> `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
> when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
> not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
> (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

The still-current, unedited `contracts/interaction-contract.md` §3 (v0.9.0, re-read in this run — this
task's `set_marker`/`generate_trail` structural contract, which 02.1's bump does not alter):

> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
>   selected course. Nodes upstream of the marker keep their mastery.
> - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an
>   `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every
>   segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

The L0-T rewrite task 02.5 implements (the **future** v1.1.0 row — quoted from
`tasks/epic-02-task-03-l0t-trail-rule-contract.md` §4 step 1, since the committed
`contracts/graph-constraints.md` is still v1.0.0 at the time of this run, re-read and byte-compared):

> | L0-T | **Trail segments** (generated at runtime, expedition W8, never over the bundle): a course
> segment is exactly that course's nodes resident in the bundle — a node's unit is the unit of its
> lowest-ordered expectation code of that course — ordered by unit order, then topologically by the edge
> set within each unit, ties broken by node id (ascending); an edge between two nodes of the same course
> segment that runs against unit order is listed as a warning in the trail generation's own report, never
> a failure; every node of an extension segment is reachable along directed edges from some node of the
> segment placed before it. | `EXP_TRAIL_INVALID` | same `Core` function family as L0-1…L0-10
> conceptually, but runs at trail generation (expedition W8), never via `core-cli validate`; the warning
> list's concrete shape is fixed by the implementing task (02.5), not by this contract |

02.3's own tie-break decision default this task adopts verbatim (`tasks/epic-02-task-03-l0t-trail-rule-contract.md`
§6, re-read in this run):

> IF "ties by node id" is ambiguous between "sort the whole unit's node list by id" and "break Kahn's-
> algorithm ties by id at each step" THEN it is the latter: a full-list sort by id would not respect the
> edges inside the unit... Kahn's algorithm with id-ordered tie-break among zero-indegree candidates is
> the only reading that satisfies both "topological" and "ties by id" simultaneously, and it is the
> reading used to compute §4 step 3's fixture values.

02.3's own hand-computed fixture for MCR3U (`tasks/epic-02-task-03-l0t-trail-rule-contract.md` §4 step 3,
re-read in this run — this is the **authoritative** ordering this spec's AC2 uses; the context bundle's
§H disagrees and is a bundle defect, see the note atop this spec):

> **`MCR3U` course segment** (9 nodes, units `MCR3U.u1`…`MCR3U.u3`):
> ```
> rational-expressions (u1), solving-quadratics (u1), quadratic-functions (u1),
> function-concept (u2), domain-and-range (u2), function-notation (u2), function-transformations (u2),
> exponential-functions (u3), logarithms (u3)
> ```
> **`MCR3U` against-unit-order warnings**: none.

02.3's MTH1W fixture (same source, re-read in this run — matches the context bundle's §H for MTH1W; used
here for AC1):

> **`MTH1W` course segment** (11 nodes, units `MTH1W.u1`…`MTH1W.u4`):
> ```
> integer-operations (u1), order-of-operations (u1), rational-numbers (u1),
> exponent-laws (u2), scientific-notation (u2),
> linear-relations (u3), solving-linear-equations (u3), solving-systems-of-equations (u3),
> simplifying-expressions (u4), polynomials (u4), factoring (u4)
> ```
> **`MTH1W` against-unit-order warning** (exactly one, the case the ruling names by example):
> ```
> solving-linear-equations (u3) --> exponent-laws (u2)
> ```

Q-D ruling, verbatim (`tasks/arbitration/arbiter-02-predispatch.md`, re-read and byte-compared in this run):

> **Ruling.** CONFIRMED for `Core`. The W7 reconciliation in 02.5 returns `MAP_MARKER_OFF_TRAIL` as data
> in its result, together with the default marker. `Core` surfaces no text (I14), and mastery is untouched.
> - **Default marker.** Use the first unit of the first course in `syllabi[]` that exists in the bundle.
> - **No resolvable course.** If no course in `syllabi[]` exists in the bundle, keep the stored marker,
>   generate a trail with no segments, and let `compose` raise `EXP_NO_FRINGE` unless `blocked` or due
>   nodes exist.
> - **Off-trail definition.** A marker is off the trail when `course_code ∉ syllabi[]`, or when the course
>   is absent from the bundle, or when `unit_id` is not one of that course's `units[]`.

`docs/domains/expedition.md` W7 (re-read and byte-compared in this run — the `Core` half this task owns):

> **Pre:** app launch; a `StudentState` file exists (or an iCloud copy). **Steps:** platform reads and
> migrates (its W4); this domain validates node ids against the installed bundle — ids no longer in the
> graph are kept in the file but ignored (`EXP_NODE_NOT_IN_GRAPH`), never deleted. **Post:** state loaded;
> the map opens (map W1).

`docs/plans/epic-02-plan.md`'s task table row for 02.5 and 02.6 (re-read in this run — the source of the
bundle-defect correction #2 above):

> | 02.5 | a | marker-trail-reconciliation | impl | 02.1, 02.3, 02.4 | seam | — |
> | 02.6 | a | fringe-compose-seam | impl | 02.2, 02.4, 02.5 | seam | marker → trail → fringe |
>
> **02.6** — D48 fringe + `compose`... Owns C1 marker→trail→fringe (`MarkerTrailFringeSeamTests.swift`,
> all real on `data/demo`).

Prior signatures this task builds on (from the codebase, verbatim, re-read in this run):

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
```

```swift
// Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21 (internal — visible within the Core
// module; not modified by this task)
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
// Packages/Core/Sources/Core/Model/Courses.swift:9-42 (unmodified)
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

public struct Expectation: Codable, Equatable {
    public let code: String
    public let kind: ExpectationKind
    public let paraphrase: String
    public let officialUrl: String
    public let unitId: String
}

public struct Unit: Codable, Equatable {
    public let unitId: String
    public let name: String
    public let expectationCodes: [String]
}
```

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift:9-30 (unmodified)
public struct Node: Codable, Equatable {
    public let id: String
    // ...
    public let expectationCodes: [NodeExpectationCode]?
    // ...
    public let courses: [NodeCourse]
    // ...
}

public struct NodeExpectationCode: Codable, Equatable {
    public let courseCode: String
    public let code: String
}
```

```swift
// Packages/Core/Sources/Core/Model/Edges.swift:9-16 (unmodified)
public struct Edge: Codable, Equatable {
    public let from: String
    public let to: String
    public let sources: [EdgeSource]
    public let generationAgreement: Int
    public let confidence: Double
    public let probeStats: ProbeStats
}
```

`data/demo/courses.json` (re-read in this run): `MTH1W.next_courses == ["MPM2D"]`,
`MCR3U.next_courses == ["MHF4U"]`; neither `MPM2D` nor `MHF4U` is a course in `data/demo/courses.json`
(only `MTH1W` and `MCR3U` are present) — confirming the AC4/AC5 split (real `data/demo` exercises "no
extension"; a synthetic fixture exercises "extension present").

`data/demo/nodes.json` (re-read in this run): every one of the 20 nodes carries exactly one
`expectation_codes` entry, for exactly one of `MTH1W`/`MCR3U` — no node is undergraduate (no
`source_ref`-only node exists in `data/demo`), so the "undergraduate nodes" branch of extension-building
(§4 step 6) is exercised nowhere on real `data/demo`; it is implemented for correctness (per the D47
amendment text quoted below) but has no `data/demo` assertion.

AMENDMENT-v2.7.md §4 (re-read in this run — the extension rule's source, D47):

> When the course-progress marker is moved past the course's last unit, the trail extends from the
> course's terminal nodes along downstream prerequisite edges, preferring the next course in the same
> stream per the Ministry's course-prerequisite chart... then into undergraduate trails when those nodes
> exist. The extension is opt-in by marker position, never automatic... Course succession is data in the
> spine (`next_courses[]` per course), not logic.

`Packages/Core/Sources/Core/CoreError.swift` (as this task's precondition, task 02.4, lands it — quoted
from `tasks/epic-02-task-04-core-error-calendar-day-mastery.md` §4.1, since the committed
`CoreError.swift` still has only the original seven cases at the time of this run):

```swift
    case expNoFringe = "EXP_NO_FRINGE"
    case expTrailInvalid = "EXP_TRAIL_INVALID"
    case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
    case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
    case expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"
    case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
    case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
    case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
    case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
    case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"
```

`Packages/Core/Sources/Core/Events/CoreEvent.swift` (same precondition, quoted from
`tasks/epic-02-task-04-core-error-calendar-day-mastery.md` §4.4, relevant cases only):

```swift
    case expeditionMarkerChanged = "expedition.marker_changed"
    case expeditionTrailGenerated = "expedition.trail_generated"
```

Precondition test-loading pattern this task follows (`Packages/Core/Tests/CoreTests/L0CheckerTests.swift:11-28`,
re-read in this run):

```swift
private static var l0FixturesDir: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CoreTests
        .appendingPathComponent("Fixtures/l0")
}

private static func loadBundle(_ name: String) throws -> ContentBundle {
    try BundleIO.read(from: l0FixturesDir.appendingPathComponent(name))
}
```

## §4 Implementation outline

Layer placement: layer ④ interaction, expedition W6/W8 (marker, trail) and the `Core` half of W7 (load-time
reconciliation). Reads layer ① (`Unit`, `next_courses[]`) and layer ② (`edges[]`, `confidence` — read but
never used for ordering, only for warning/reachability detection) as read-only inputs; writes nothing.

**Precondition (hard dependency, not advisory, mirroring 02.4's own precondition pattern):** tasks 02.1
(§3 contract text — informational only, this task does not read the `.md` file at runtime), 02.3
(L0-T contract text — informational only, same), and 02.4 (`CoreError` R-6 cases, `CoreEvent`) must be
merged before this task's code compiles: it references `CoreError.expTrailInvalid`,
`.expNodeNotInGraph`, `.mapMarkerOffTrail` and `CoreEvent.expeditionMarkerChanged`,
`.expeditionTrailGenerated`, none of which exist in the committed `CoreError.swift` / (not-yet-existing)
`CoreEvent.swift` at the time of this run. Do not add these cases yourself if 02.4 has not landed — that
is 02.4's file scope (out of scope here, §2).

### 1. New types (`Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`, top of file)

```swift
import Foundation

/// An edge inside one course segment that runs against that course's unit order — reported, never a
/// failure (L0-T, `contracts/graph-constraints.md` v1.1.0).
public struct TrailWarning: Equatable {
    public let courseCode: String
    public let from: String
    public let to: String
}

/// The result of `MarkerTrail.generateTrail`. `event` is always `.expeditionTrailGenerated` — callers
/// that also changed the marker in the same operation (`setMarker`) get `.expeditionMarkerChanged` too,
/// via `SetMarkerResult.events`, rather than this type growing a second event slot.
public struct TrailGenerationReport: Equatable {
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let event: CoreEvent
}

/// The result of `MarkerTrail.setMarker`.
public struct SetMarkerResult: Equatable {
    public let marker: Marker
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let events: [CoreEvent]
}

/// The result of `MarkerTrail.reconcileMarker` (W7). `code` is `.mapMarkerOffTrail` when the persisted
/// marker did not resolve; `Core` returns this as data only and surfaces no text (I14, Q-D ruling).
public struct MarkerReconciliationResult: Equatable {
    public let marker: Marker
    public let code: CoreError?
}

/// The result of `MarkerTrail.reconcileNodeIds` (W7). `ignoredNodeIds` are node ids present in the
/// caller's `nodes` dict but absent from the installed bundle — the caller keeps them in `StudentState`
/// unchanged (never deletes) and simply excludes them from any bundle-dependent computation.
public struct NodeIdReconciliationResult: Equatable {
    public let ignoredNodeIds: [String]
    public let code: CoreError?
}
```

### 2. `MarkerTrail` namespace and public API

```swift
public enum MarkerTrail {
    /// W8 (D47), pure. Constructs one `course` segment per entry of `syllabi[]` that resolves to a
    /// course with ≥ 1 resident node in `bundle`, in `syllabi[]`'s own order, each ordered by unit order
    /// then topologically within each unit (ties by node id — step 3). If `marker.pastLastUnit == true`
    /// and the marker's own course produced a segment, appends one `extension` segment (step 6) when a
    /// downstream node exists. Throws `CoreError.expTrailInvalid` if any constructed segment fails this
    /// task's own re-derivation of L0-T (steps 3–4) — a defensive check, since construction is designed
    /// to always satisfy L0-T on an already-L0-passed bundle (§6 default).
    public static func generateTrail(
        syllabi: [String], marker: Marker, bundle: ContentBundle
    ) throws -> TrailGenerationReport

    /// W6. Builds the new `Marker` from the given course/unit/`pastLastUnit`, then calls
    /// `generateTrail(syllabi:marker:bundle:)` with it. Throws (and returns nothing) if trail generation
    /// throws — per §6's decision default, the caller's previously-held marker AND trail both stay
    /// untouched on failure (this function does not partially apply the marker change).
    public static func setMarker(
        courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
    ) throws -> SetMarkerResult

    /// Q-D default: the first unit of the first course in `syllabi[]` present in `bundle`, with
    /// `pastLastUnit: false`. `nil` if no course in `syllabi[]` resolves.
    public static func defaultMarker(syllabi: [String], bundle: ContentBundle) -> Marker?

    /// W7 (Q-D). Off-trail iff `marker.courseCode ∉ syllabi`, or the course is absent from `bundle`, or
    /// `marker.unitId` is not one of that course's `units[]`. On-trail: returns `marker` unchanged,
    /// `code: nil`. Off-trail: returns `defaultMarker(syllabi:bundle:)` with `code: .mapMarkerOffTrail`
    /// when that resolves, else the **unchanged input marker** with `code: .mapMarkerOffTrail` (no
    /// resolvable course — Q-D's "keep the stored marker" branch).
    public static func reconcileMarker(
        _ marker: Marker, syllabi: [String], bundle: ContentBundle
    ) -> MarkerReconciliationResult

    /// W7. `ignoredNodeIds` = the keys of `nodes` absent from `bundle`'s node set, sorted ascending for
    /// determinism. `code: .expNodeNotInGraph` iff non-empty.
    public static func reconcileNodeIds(
        nodes: [String: NodeState], bundle: ContentBundle
    ) -> NodeIdReconciliationResult

    // MARK: - Private construction helpers (step 3)

    private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> { ... }
    private static func unitIndex(nodeId: String, course: Course, index: GraphIndex) -> Int? { ... }
    private static func orderedNodes(_ nodeIds: Set<String>, course: Course, index: GraphIndex) -> [String] { ... }
    private static func topoOrder(_ nodeIds: Set<String>, edges: [Edge]) -> [String] { ... }
    private static func buildCourseSegment(
        courseCode: String, index: GraphIndex
    ) -> (segment: TrailSegment, warnings: [TrailWarning])? { ... }

    // MARK: - Private validation helpers (step 4)

    private static func courseSegmentViolations(_ segment: TrailSegment, index: GraphIndex) -> [String] { ... }
    private static func extensionSegmentViolations(
        _ segment: TrailSegment, precedingNodeIds: [String], index: GraphIndex
    ) -> [String] { ... }

    // MARK: - Private extension-building helpers (step 6)

    private static func buildExtensionSegment(
        afterCourseCode: String, precedingNodeIds: [String], index: GraphIndex
    ) -> TrailSegment? { ... }

    // MARK: - Private reconciliation helpers (step 7)

    private static func isMarkerOffTrail(_ marker: Marker, syllabi: [String], bundle: ContentBundle) -> Bool { ... }
}
```

### 3. Course-segment construction (`residentNodeIds`, `unitIndex`, `orderedNodes`, `topoOrder`, `buildCourseSegment`)

A node is **resident** in course `X` iff its `expectationCodes` array (may be `nil`) contains ≥ 1 entry
whose `courseCode == X`:

```swift
private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> {
    Set(
        index.nodesById.values
            .filter { node in (node.expectationCodes ?? []).contains { $0.courseCode == course.courseCode } }
            .map(\.id))
}
```

A node's **unit index** within course `X` is the 0-based index into `course.units` of the unit named by
the node's **lowest-ordered** expectation code for `X` (02.3's own decision default — this branch is
never exercised on `data/demo`, where every node carries exactly one expectation code per course, but must
be implemented for correctness on future, non-demo bundles):

```swift
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

**Kahn's algorithm with id-ordered tie-break among zero-indegree candidates** (02.3 §6, quoted §3 —
NOT a whole-list sort by id):

```swift
private static func topoOrder(_ nodeIds: Set<String>, edges: [Edge]) -> [String] {
    var indegree: [String: Int] = Dictionary(uniqueKeysWithValues: nodeIds.map { ($0, 0) })
    var adjacency: [String: [String]] = [:]
    for edge in edges where nodeIds.contains(edge.from) && nodeIds.contains(edge.to) {
        adjacency[edge.from, default: []].append(edge.to)
        indegree[edge.to, default: 0] += 1
    }
    var result: [String] = []
    var available = Set(nodeIds.filter { indegree[$0] == 0 })
    while let next = available.sorted().first {
        available.remove(next)
        result.append(next)
        for successor in adjacency[next] ?? [] {
            indegree[successor, default: 0] -= 1
            if indegree[successor] == 0 { available.insert(successor) }
        }
    }
    // result.count < nodeIds.count only if a cycle exists in this induced subgraph — impossible on an
    // already-L0-passed bundle (L0-1 is global acyclicity, and a subgraph of an acyclic graph is
    // acyclic), but the caller (buildCourseSegment / buildExtensionSegment) does not assume this: it
    // simply returns whatever partial order results, and courseSegmentViolations / extensionSegmentViolations
    // (step 4) independently catch the inconsistency and raise EXP_TRAIL_INVALID.
    return result
}
```

Group `nodeIds` by unit index, emit each unit's nodes (topologically ordered) in unit-index order:

```swift
private static func orderedNodes(_ nodeIds: Set<String>, course: Course, index: GraphIndex) -> [String] {
    var byUnit: [Int: [String]] = [:]
    for nodeId in nodeIds {
        guard let idx = unitIndex(nodeId: nodeId, course: course, index: index) else { continue }
        byUnit[idx, default: []].append(nodeId)
    }
    var ordered: [String] = []
    for unitIdx in course.units.indices {
        guard let inUnit = byUnit[unitIdx] else { continue }
        ordered += topoOrder(Set(inUnit), edges: index.edges)
    }
    return ordered
}
```

Build one course segment plus its against-unit-order warnings — a warning fires for any edge **inside**
the resident set (any two units, not just adjacent) whose target's unit index is strictly less than its
source's:

```swift
private static func buildCourseSegment(
    courseCode: String, index: GraphIndex
) -> (segment: TrailSegment, warnings: [TrailWarning])? {
    guard let course = index.coursesByCode[courseCode] else { return nil }
    let resident = residentNodeIds(course: course, index: index)
    guard !resident.isEmpty else { return nil }
    let ordered = orderedNodes(resident, course: course, index: index)
    var warnings: [TrailWarning] = []
    for edge in index.edges where resident.contains(edge.from) && resident.contains(edge.to) {
        guard let fromIdx = unitIndex(nodeId: edge.from, course: course, index: index),
            let toIdx = unitIndex(nodeId: edge.to, course: course, index: index)
        else { continue }
        if toIdx < fromIdx {
            warnings.append(TrailWarning(courseCode: courseCode, from: edge.from, to: edge.to))
        }
    }
    return (TrailSegment(kind: .course, courseCode: courseCode, nodeIds: ordered), warnings)
}
```

### 4. Independent validation (`courseSegmentViolations`, `extensionSegmentViolations`)

Re-derives L0-T from the constructed segment alone, without reusing any intermediate value from step 3
(defense in depth, matching `L0Checker`'s own style of computing each rule fresh from `GraphIndex`):

```swift
private static func courseSegmentViolations(_ segment: TrailSegment, index: GraphIndex) -> [String] {
    guard let courseCode = segment.courseCode, let course = index.coursesByCode[courseCode] else {
        return ["segment names an unknown course"]
    }
    var position: [String: Int] = [:]
    for (i, id) in segment.nodeIds.enumerated() { position[id] = i }
    var violations: [String] = []
    for edge in index.edges where position[edge.from] != nil && position[edge.to] != nil {
        guard let fromIdx = unitIndex(nodeId: edge.from, course: course, index: index),
            let toIdx = unitIndex(nodeId: edge.to, course: course, index: index),
            fromIdx == toIdx
        else { continue }  // cross-unit edges are never a within-unit-topological-order violation
        if position[edge.from]! > position[edge.to]! {
            violations.append("\(edge.from)-->-\(edge.to) violates within-unit topological order")
        }
    }
    return violations
}

private static func extensionSegmentViolations(
    _ segment: TrailSegment, precedingNodeIds: [String], index: GraphIndex
) -> [String] {
    var reachable = Set(precedingNodeIds)
    var queue = precedingNodeIds
    while let current = queue.popLast() {
        for edge in index.edgesByFrom[current] ?? [] where !reachable.contains(edge.to) {
            reachable.insert(edge.to)
            queue.append(edge.to)
        }
    }
    return segment.nodeIds.filter { !reachable.contains($0) }
        .map { "\($0) not reachable from the preceding segment" }
}
```

### 5. `generateTrail` and `setMarker`

```swift
public static func generateTrail(
    syllabi: [String], marker: Marker, bundle: ContentBundle
) throws -> TrailGenerationReport {
    let index = GraphIndex(bundle: bundle)
    var segments: [TrailSegment] = []
    var warnings: [TrailWarning] = []
    for courseCode in syllabi {
        guard let built = buildCourseSegment(courseCode: courseCode, index: index) else { continue }
        guard courseSegmentViolations(built.segment, index: index).isEmpty else {
            throw CoreError.expTrailInvalid
        }
        segments.append(built.segment)
        warnings += built.warnings
    }
    if marker.pastLastUnit == true,
        let markerSegment = segments.first(where: { $0.kind == .course && $0.courseCode == marker.courseCode }),
        let extensionSegment = buildExtensionSegment(
            afterCourseCode: marker.courseCode, precedingNodeIds: markerSegment.nodeIds, index: index)
    {
        guard
            extensionSegmentViolations(
                extensionSegment, precedingNodeIds: markerSegment.nodeIds, index: index
            ).isEmpty
        else { throw CoreError.expTrailInvalid }
        segments.append(extensionSegment)
    }
    return TrailGenerationReport(
        trail: Trail(segments: segments), warnings: warnings, event: .expeditionTrailGenerated)
}

public static func setMarker(
    courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
) throws -> SetMarkerResult {
    let marker = Marker(courseCode: courseCode, unitId: unitId, pastLastUnit: pastLastUnit)
    let report = try generateTrail(syllabi: syllabi, marker: marker, bundle: bundle)
    return SetMarkerResult(
        marker: marker, trail: report.trail, warnings: report.warnings,
        events: [.expeditionMarkerChanged, .expeditionTrailGenerated])
}
```

`generateTrail` and `setMarker` never read or write `nodes: [String: NodeState]` — "nodes upstream of
the marker keep their mastery" (contract §3, quoted §3) is true by construction: this task's functions
have no mastery input to mutate.

### 6. Extension-segment construction (D47)

Terminal nodes of the preceding segment = its own nodes with no outgoing edge to another node **of that
same segment** (not "of the same course" broadly — a node's out-edges within its own course-segment unit
do not disqualify it if none of those edges lands inside the segment itself; in practice, for a course
segment, "terminal" and "sink of the induced whole-course subgraph" coincide, but this task states the
narrower, segment-scoped definition because it is what the extension actually needs and it generalises
correctly to a segment that is itself an `extension` — not exercised here, since D47 chains at most one
extension per trail per the amendment text, but stated for clarity):

```swift
private static func buildExtensionSegment(
    afterCourseCode: String, precedingNodeIds: [String], index: GraphIndex
) -> TrailSegment? {
    guard let course = index.coursesByCode[afterCourseCode] else { return nil }
    let precedingSet = Set(precedingNodeIds)
    let terminals = precedingNodeIds.filter { nodeId in
        !(index.edgesByFrom[nodeId] ?? []).contains { precedingSet.contains($0.to) }
    }

    var reachable: Set<String> = []
    var visited = Set(terminals)
    var queue = terminals
    while let current = queue.popLast() {
        for edge in index.edgesByFrom[current] ?? [] where !visited.contains(edge.to) {
            visited.insert(edge.to)
            if !precedingSet.contains(edge.to) { reachable.insert(edge.to) }
            queue.append(edge.to)
        }
    }

    for nextCode in course.nextCourses {
        guard let nextCourse = index.coursesByCode[nextCode] else { continue }
        let resident = residentNodeIds(course: nextCourse, index: index)
        let hit = reachable.intersection(resident)
        guard !hit.isEmpty else { continue }
        return TrailSegment(
            kind: .extension, courseCode: nextCode, nodeIds: orderedNodes(hit, course: nextCourse, index: index))
    }

    let undergraduate = reachable.filter { nodeId in (index.nodesById[nodeId]?.expectationCodes ?? []).isEmpty }
    guard !undergraduate.isEmpty else { return nil }
    return TrailSegment(kind: .extension, courseCode: nil, nodeIds: topoOrder(undergraduate, edges: index.edges))
}
```

The "next" preference walks `course.nextCourses` **in the order the bundle lists them** (interaction-contract
§3: "preferring `next_courses[]`", plural array order = preference order) and stops at the first entry
whose reachable-and-resident intersection is non-empty; if none of `nextCourses` yields a hit, the
undergraduate branch (nodes with no `expectationCodes` at all) is tried; if that too is empty, no
extension segment is appended (AC5's "no downstream-course node present" case).

### 7. W7 reconciliation

```swift
private static func isMarkerOffTrail(_ marker: Marker, syllabi: [String], bundle: ContentBundle) -> Bool {
    guard syllabi.contains(marker.courseCode) else { return true }
    guard let course = bundle.courses.courses.first(where: { $0.courseCode == marker.courseCode }) else {
        return true
    }
    return !course.units.contains { $0.unitId == marker.unitId }
}

public static func defaultMarker(syllabi: [String], bundle: ContentBundle) -> Marker? {
    for courseCode in syllabi {
        guard let course = bundle.courses.courses.first(where: { $0.courseCode == courseCode }),
            let firstUnit = course.units.first
        else { continue }
        return Marker(courseCode: courseCode, unitId: firstUnit.unitId, pastLastUnit: false)
    }
    return nil
}

public static func reconcileMarker(
    _ marker: Marker, syllabi: [String], bundle: ContentBundle
) -> MarkerReconciliationResult {
    guard isMarkerOffTrail(marker, syllabi: syllabi, bundle: bundle) else {
        return MarkerReconciliationResult(marker: marker, code: nil)
    }
    if let fallback = defaultMarker(syllabi: syllabi, bundle: bundle) {
        return MarkerReconciliationResult(marker: fallback, code: .mapMarkerOffTrail)
    }
    return MarkerReconciliationResult(marker: marker, code: .mapMarkerOffTrail)
}

public static func reconcileNodeIds(
    nodes: [String: NodeState], bundle: ContentBundle
) -> NodeIdReconciliationResult {
    let known = Set(bundle.nodes.nodes.map(\.id))
    let ignored = nodes.keys.filter { !known.contains($0) }.sorted()
    return NodeIdReconciliationResult(
        ignoredNodeIds: ignored, code: ignored.isEmpty ? nil : .expNodeNotInGraph)
}
```

### 8. Fixture files (§2's two new `Fixtures/trail/` directories)

Both follow the shape of `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/` (all seven files present;
`manifest.json`'s `files[].sha256` may reuse the same placeholder-zero string — `BundleIO.read` never
verifies it) and may reuse that fixture's `regions.json` byte-for-byte (it is schema-generic: the region
ids `number-operations`, `algebra`, `linear-algebra` etc. this task's fixtures need are already present).

- **`extension-positive/`**: `courses.json` = `MTH1W` (with `next_courses: ["MPM2D"]`, all four units,
  matching `data/demo/courses.json`'s MTH1W exactly) plus a synthetic `MPM2D` with one unit and ≥ 1
  expectation. `nodes.json` = `data/demo`'s eleven MTH1W nodes (may be trimmed to the minimum needed to
  exercise the segment + at least the `factoring` terminal, since Kahn's-algorithm ordering is already
  covered by AC1 against real `data/demo`) plus ≥ 1 synthetic `MPM2D`-resident node, e.g. `id:
  "quadratic-relations"`, `expectation_codes: [{course_code: "MPM2D", code: "<its one code>"}]`.
  `edges.json` = the MTH1W edges needed to reach `factoring` plus one new edge `factoring -->
  quadratic-relations`. `landmarks.json: {"format_version": "0.0.0", "landmarks": []}`, `sources.json:
  {"format_version": "0.0.0", "sources": []}`.
- **`unit-cycle/`**: one course `TST1X` with one unit `TST1X.u1` containing two resident nodes `a`, `b`;
  `edges.json` contains both `a --> b` and `b --> a` (an intra-unit cycle). This fixture is loaded only
  by this task's own `courseSegmentViolations`-exercising test (§5 T2/T5), never through `L0Checker` —
  the AC6 negative control needs a hand-built `TrailSegment` (e.g. `nodeIds: ["a", "b"]`, constructed
  directly in the test, not via `buildCourseSegment`) so that `courseSegmentViolations` has a genuine,
  independently-detectable inconsistency to catch, proving the check does not just rubber-stamp whatever
  `buildCourseSegment` itself produced.

### 9. Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles the new
file even though `core-cli`'s `main.swift` calls none of it yet, matching 02.4's own smoke-check pattern).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path** (`Packages/Core/Tests/CoreTests/MarkerTrailGenerationTests.swift`, real `data/demo`
  loaded via `BundleIO.read` unless noted):
  - AC1, AC2: `generateTrail` scenario assertions, exact `nodeIds` and warning lists.
  - AC3: `setMarker` returns the expected `SetMarkerResult`.
  - AC4: `generateTrail` on the `extension-positive` fixture (§4 step 8) with `pastLastUnit == true`
    produces the expected `.extension` segment; every node in it passes a direct BFS-reachability
    assertion from the MTH1W segment (re-derived in the test, independently of
    `extensionSegmentViolations`, so the test is not merely re-running the production code against
    itself).
  - AC5: `generateTrail` on real `data/demo` with `pastLastUnit == true` has `trail.segments.count ==
    1` (only the MTH1W course segment; no extension).
  - AC7, AC8, AC9: `defaultMarker` / `reconcileMarker` / `reconcileNodeIds` scenario assertions.
- **T2 negative — invalid input rejected at the boundary:**
  - AC6: loading the `unit-cycle` fixture (§4 step 8) and manually constructing `TrailSegment(kind:
    .course, courseCode: "TST1X", nodeIds: ["a", "b"])`, then calling `courseSegmentViolations` directly,
    returns a non-empty violation list (the `b --> a` edge is inside the same unit and violates
    `position["b"] < position["a"]`... i.e. `position[edge.from] > position[edge.to]` for the reverse
    edge). Then `generateTrail(syllabi: ["TST1X"], marker: <any>, bundle: <unit-cycle fixture>)` is
    asserted to `throw CoreError.expTrailInvalid` — this exercises the full call path, not just the
    helper, because `buildCourseSegment` itself, run against this fixture, may produce a truncated
    (`result.count < nodeIds.count`) `topoOrder` output that `courseSegmentViolations` must still catch
    from the *produced* segment, not from a hand-built one.
  - `defaultMarker(syllabi: [], bundle: <real data/demo>) == nil` (no syllabi at all).
  - `reconcileMarker` on a marker naming a real course (`MTH1W`) but a non-existent unit id
    (`"MTH1W.u99"`) is off-trail (`.code == .mapMarkerOffTrail`).
  - `reconcileMarker` with `syllabi = ["ZZZ9Z"]` (no course in syllabi resolves in the bundle) returns
    `.marker` **unchanged** from the input (not `defaultMarker`'s result, which is `nil` here) and
    `.code == .mapMarkerOffTrail` — the Q-D "no resolvable course: keep the stored marker" branch.
- **T3 error-taxonomy:** a table-driven assertion that `CoreError.expTrailInvalid.rawValue ==
  "EXP_TRAIL_INVALID"`, `.expNodeNotInGraph.rawValue == "EXP_NODE_NOT_IN_GRAPH"`,
  `.mapMarkerOffTrail.rawValue == "MAP_MARKER_OFF_TRAIL"` — the exact registry strings this task's
  results/throws use, cross-checked against `contracts/error-codes.json` (already covered end-to-end by
  02.4's unmodified `ErrorRegistryTests`, re-run here as a gate, not re-implemented).
- **T4 conformance per §B.1 / cited contract and invariants:**
  - I7: `generateTrail`'s only inputs are `syllabi`, `marker`, `bundle` — a signature-level fact, asserted
    by the test file's own call sites never passing a hand-authored segment.
  - I8: for every segment `generateTrail` produces on real `data/demo` (both AC1 and AC2's calls),
    `courseSegmentViolations` (called directly in the test, on the *returned* segment) is empty — proving
    the independent re-check agrees with construction on the real bundle, not just on hand-picked cases.
  - I14: `xcrun swift-format lint --strict` passes over the new file (mechanical); a dedicated grep
    assertion (mirroring 02.4's `Date()` scan) confirms zero occurrences of `Date()` in
    `MarkerTrailGeneration.swift`; `Core`'s existing `coreImportBoundary()` test is re-run unmodified and
    stays green.
  - Against-unit-order-is-a-warning-not-a-failure: AC1's single MTH1W warning is asserted to coexist with
    a successful (non-throwing) `generateTrail` call — the warning never causes `expTrailInvalid`.
- **T5 negative control for every regression guard:**
  - Guard "ties broken by Kahn's-algorithm id order, not a whole-list sort": reconstruct (locally, in the
    test file — do not modify product code) a whole-list-sort variant of `orderedNodes` for MCR3U's u1
    unit and prove it produces `[quadratic-functions, rational-expressions, solving-quadratics]` (sorted
    by id ignoring topology) or some other order that differs from AC2's `[rational-expressions,
    solving-quadratics, quadratic-functions]` — proving the real implementation's tie-break is
    load-bearing, not accidentally satisfied by the simpler-looking alternative. This is also the
    negative control that catches the bundle-defect corrected atop this spec: a reviewer who reintroduces
    the bundle's wrong ordering would fail this test.
  - Guard "against-unit-order detection compares unit **index**, not unit **id** string order": construct
    a two-node, two-unit fragment where the unit ids sort in the *opposite* order from their intended
    unit-order index (e.g., a course whose `units[]` lists `"X.u1"` then `"X.u2"` but the pipeline could
    hypothetically list them out of file order — not possible in `data/demo`, so this is a small
    synthetic `Course`/`Unit` value constructed directly in the test, not a bundle fixture) and confirm
    the warning check keys off `course.units.firstIndex(...)`, not `unitId < unitId` string comparison.
  - Guard "extension reachability is BFS/DFS from the **preceding segment's node set**, not from the
    whole bundle": on the `extension-positive` fixture, confirm that a node resident in the synthetic
    `MPM2D` course but with **no** incoming edge from any MTH1W node is correctly **excluded** from the
    extension segment (add a second, unreachable `MPM2D`-resident node to the fixture for this purpose).
- **T6 idempotency / no-leak:** `generateTrail` and `setMarker`, called twice with byte-identical
  arguments (fresh `ContentBundle`/`Marker`/`[String]` values each call, not a reused mutated variable),
  return `Equatable`-equal results both times (pure function, no hidden state). `reconcileMarker` and
  `reconcileNodeIds` are likewise pure and side-effect-free — no file is written, no `StudentState` is
  mutated (this task ships no writer of any kind, mirroring 02.2's own T6 disposition for a
  non-persistence task).

## §6 Decision defaults

- IF `generateTrail`/`setMarker` throws `CoreError.expTrailInvalid` THEN neither function returns a
  `Trail` or `Marker` value at all — the caller's own previously-held trail (and, for `setMarker`, marker)
  stay whatever they were before the call. This is the only reading of the contract's "the previous trail
  stands" (`contracts/interaction-contract.md` §3, quoted §3) that keeps `setMarker` atomic: the
  alternative (moving the marker even when regeneration fails) would leave the marker pointing somewhere
  the cached trail does not cover, an inconsistency the contract text does not license and this task
  declines to introduce. Not contract-quoted verbatim because the contract is silent on the marker's own
  fate on failure — this is this task's own conservative reading, stated explicitly per the "write it
  conditionally" rule.
- IF `generateTrail` needs `mastery: [String: NodeState]` as an input (per `docs/domains/expedition.md`
  W8's "Pre" line listing "mastery state") THEN it does not take one: `contracts/interaction-contract.md`
  §3's own formal definition of `generate_trail` (quoted §3) lists no mastery input, and this task's
  construction algorithm (unit order, topology, downstream reachability) never reads mastery anywhere.
  W8's "Pre" line lists mastery because trail regeneration and fringe recompute happen back-to-back in
  the same W6/W8 workflow step, not because `generate_trail` itself consumes it — `compose` (02.6) is the
  sole mastery consumer.
- IF a node's unit is ambiguous because it carries more than one `expectation_codes` entry for the same
  course THEN `unitIndex` takes the **minimum** unit index across those entries (02.3's own decision
  default, quoted §3: "a node's unit is the unit of its lowest-ordered expectation code of that course").
  This branch does not fire on `data/demo` (confirmed §3: every node carries exactly one entry per
  course) and is untested by any AC; it is implemented per 02.3's contract text for correctness on
  future, non-demo bundles, and its presence-but-untested status is recorded here rather than silently
  assumed.
- IF the extension's "terminal nodes" should be computed against the **whole course** (any edge to any
  node resident in that course, even one not in this particular constructed segment) rather than against
  the constructed segment's own node set THEN it should not: `docs/domains/expedition.md` W8 says "extend
  from the course's terminal nodes" and the course segment IS exactly that course's resident nodes
  (`buildCourseSegment`'s own `resident` set becomes the segment's `nodeIds` in full — no filtering
  happens between residency and segment membership), so "terminal in the segment" and "terminal in the
  course" are the same set by construction; the segment-scoped definition (§4 step 6) is stated for
  clarity, not because the two readings diverge here.
- IF `reconcileNodeIds` should also delete or mutate the caller's `nodes` dict THEN it must not — I14
  requires purity, and `docs/domains/expedition.md` W7 (quoted §3) is explicit: "ids no longer in the
  graph are kept in the file but ignored... never deleted." This function only reports which ids to
  treat as ignored; the caller (a later App-side or 02.6-side consumer) is responsible for excluding them
  from bundle-dependent computation without removing them from persisted state.
- IF the C1 marker→trail→fringe seam test (`MarkerTrailFringeSeamTests.swift`, brief AC8) should be
  written by this task, per the context bundle's §F/§I THEN it should not — see the bundle-defect note
  atop this spec: the plan (`docs/plans/epic-02-plan.md`, quoted §3) assigns that file to task 02.6, and
  it requires `compose`, which task 02.6 ships. This task's own companion test file
  (`MarkerTrailGenerationTests.swift`) fully covers this task's own AC1–AC9 without needing `compose`.

Standing defaults: identifiers and timestamps are untouched by this task (no new `StudentState` field; no
timestamp anywhere in `MarkerTrail`'s types). No model call exists anywhere in this task's code (I2); no
confidence threshold or Tier-0 fallback applies. Telemetry is untouched. No field anywhere identifies a
person, device, install or session (I5) — every new type carries only node/course/unit ids, booleans, and
`CoreError`/`CoreEvent` enum cases. No node's `paraphrase` or Ministry text is read or touched by this
task (I6) — this task never reads `Node.paraphrase`/`explanation`/`workedExamples`.

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` —
  clean over the new file and the new test file.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )`.
- All cases in §5 (T1–T6) pass, including both new fixture-backed scenarios.
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` (both unmodified, 02.4's files) stay green.
- No file under `Packages/Core/Sources/Core` contains the literal `Date()` (I14).
- Conforms to every contract section cited in §3 (`contracts/interaction-contract.md` §3, as it will read
  after 02.1's bump; `contracts/graph-constraints.md` L0-T, as it will read after 02.3's bump;
  `tasks/arbitration/arbiter-02-predispatch.md` § Q-D; `docs/domains/expedition.md` W6/W7/W8) and to every
  invariant listed in §1 (I2, I4, I5, I7, I8, I14).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and unaffected by
  this task's file scope).

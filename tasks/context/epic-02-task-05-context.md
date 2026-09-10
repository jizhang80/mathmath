# Task 02.5 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: marker-trail-reconciliation
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 02
- **Task:** 02.5
- **Slug:** marker-trail-reconciliation
- **Summary:** Implement `set_marker`, default marker, `generate_trail` with D47 extension, runtime L0-T segment validation, W7 load-time state reconciliation (`EXP_NODE_NOT_IN_GRAPH`, `MAP_MARKER_OFF_TRAIL` + default marker fallback). Does not edit `L0Checker.swift`. Extension positive case on an in-memory bundle. Core pure functions; no model calls.

**Invariants in play:**
- **I2** — Tier 0 alone is usable; every model call has fallback (none here). Source: `CLAUDE.md` §Hard invariants
- **I4** — Backtrack ≤ 2 levels per session; deeper gaps marked on map only. Source: `CLAUDE.md` I4
- **I5** — No PII, no identifiers. Source: `CLAUDE.md` I5
- **I7** — One cross-grade graph; trail generated, never authored. Source: `CLAUDE.md` I7
- **I8** — Trail segments pass L0 checks; every segment a path; acyclic, nodes covered. Source: `CLAUDE.md` I8

---

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 3. Marker and trail

> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery.
> - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

Source: `contracts/interaction-contract.md:45-51`

Binds this task: defines the behaviour of `set_marker`, default marker, `generate_trail`, and what happens when L0-T validation fails.

### contracts/graph-constraints.md — § L0-T (Trail segments)

> **L0-T** | **Trail segments** (generated at runtime, expedition W8): every segment's `node_ids[]` is a directed path in the graph; a course segment contains only that course's nodes. | `EXP_TRAIL_INVALID` | same `Core` function; runs at generation, not on the bundle

Source: `contracts/graph-constraints.md:23`

Binds this task: runtime validation rule on every generated trail segment.

### tasks/blocked/Q5-RULING-02-QE.md — Owner ruling on L0-T interpretation

> **Ruled: option A.**
> 
> - A trail's **course segment** is exactly that course's nodes resident in the bundle, ordered by **unit order**, then **topologically by the graph within each unit** (ties by node id).
> - An edge that runs **against unit order** (e.g. `solving-linear-equations` u3 → `exponent-laws` u2) is **reported** (a warning in the L0 report), **not a failure**.
> - Every **extension segment** node must be **reachable in the graph** from the segment before it.
> - The L0-T row of `contracts/graph-constraints.md` and the I8 wording in `CLAUDE.md` are rewritten to match. The contract change is a versioned bump carried by task 02.3 (route a); **`data/demo` is not changed**.

Source: `tasks/blocked/Q5-RULING-02-QE.md:6-14`

Binds this task: the exact rule for ordering nodes in a course segment (unit order, then topological within unit, ties by id); against-unit-order edges are not failures; extension reachability rule.

### tasks/arbitration/arbiter-02-predispatch.md — Q-D: unknown persisted marker

> **Ruling.** CONFIRMED for `Core`. The W7 reconciliation in 02.5 returns `MAP_MARKER_OFF_TRAIL` as data in its result, together with the default marker. `Core` surfaces no text (I14), and mastery is untouched.
> - **Default marker.** Use the first unit of the first course in `syllabi[]` that exists in the bundle.
> - **No resolvable course.** If no course in `syllabi[]` exists in the bundle, keep the stored marker, generate a trail with no segments, and let `compose` raise `EXP_NO_FRINGE` unless `blocked` or due nodes exist.
> - **Off-trail definition.** A marker is off the trail when `course_code ∉ syllabi[]`, or when the course is absent from the bundle, or when `unit_id` is not one of that course's `units[]`.

Source: `tasks/arbitration/arbiter-02-predispatch.md:140-143`

Binds this task: W7 load-time reconciliation for persisted marker; `MAP_MARKER_OFF_TRAIL` return value and default marker fallback; off-trail definition.

### tasks/arbitration/arbiter-02-predispatch.md — Q-F: representing marker past last unit

> **Ruling.** Add an optional boolean `past_last_unit` on `marker`. It lands with Q-A in **02.2** (data-model v1.3.0, schema, example, `Marker` type) and in **02.1** (interaction-contract text).
> 
> **Normative text for 02.2: `contracts/data-model.md` § StudentState.** Replace the `marker` clause with `marker {course_code, unit_id, past_last_unit?}`, then add:
> > `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must still name a unit of the course.
> 
> **Normative text for 02.1: `contracts/interaction-contract.md` § 3**, appended to the `set_marker` bullet:
> > The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the course's last unit as `unit_id`. While past the last unit, the `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

Source: `tasks/arbitration/arbiter-02-predispatch.md:181-196`

Binds this task: the implementation must await Q-A/Q-F landing in 02.2 (schema v1.3.0, `Marker` type with optional `past_last_unit`); when interpreting extension segments, the `past_last_unit` flag determines when the extension rule applies.

---

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W6. Set the course-progress marker

> **Pre:** `map.marker_moved` with a unit of the selected course. **Steps:** set the marker; regenerate the Trail (W8); recompute the Fringe; nodes newly upstream keep whatever mastery they had (a cleared node stays cleared). **Post:** persisted; `expedition.marker_changed` emitted → map, telemetry (D40).

Source: `docs/domains/expedition.md:105-108`

### docs/domains/expedition.md — W8. Generate the trail (D47)

> **Pre:** `syllabi[]`, the marker, mastery state, the graph bundle and the spine's `Unit`s and `next_courses[]`. **Steps (pure, `Core`):** 1. For each selected course, order its nodes by unit (curriculum-spine W3) into a solid segment. 2. If the marker is past the last unit of its course, extend from the course's terminal nodes along downstream edges into the first `next_courses[]` entry whose nodes exist, then the next, then undergraduate nodes; mark the segment `extension`. 3. Validate every segment as a path (I8); a broken segment raises `EXP_TRAIL_INVALID` and the previous trail stands. **Post:** the Trail cached in `StudentState`; `expedition.trail_generated` → map.

Source: `docs/domains/expedition.md:110-117`

### docs/domains/expedition.md — W7. Resume after relaunch

> **Pre:** app launch; a `StudentState` file exists (or an iCloud copy). **Steps:** platform reads and migrates (its W4); this domain validates node ids against the installed bundle — ids no longer in the graph are kept in the file but ignored (`EXP_NODE_NOT_IN_GRAPH`), never deleted. **Post:** state loaded; the map opens (map W1).

Source: `docs/domains/expedition.md:119-123`

---

## §D. Prior task outputs (signatures this task depends on)

Tasks 02.1, 02.3, 02.4 must be completed first per the plan. This task consumes:

- **From 02.1** (contract-interaction-numeric-normalisation): the binding text in `contracts/interaction-contract.md` §1–§5 is finalized and includes Q-F text on `past_last_unit`.

- **From 02.2** (Q-A/Q-F; LANDED in prior EPIC 01): `StudentState.swift` carries `Marker` type with `courseCode`, `unitId` **and will add** `past_last_unit: Bool?` in 02.2 (not yet implemented). `NodeState` will add `remediated: Bool?` in 02.2. The schema version will be 2.

- **From 02.3** (L0-T demo-trail resolution): the Q-E ruling is verified to pass on `data/demo` with MTH1W and MCR3U; the contract text in `contracts/graph-constraints.md` L0-T is updated to reflect the ruling.

- **From 02.4** (core-error-calendar-day-mastery): `CoreError` enum includes error codes `EXP_TRAIL_INVALID`, `EXP_NODE_NOT_IN_GRAPH`, `MAP_MARKER_OFF_TRAIL` (already registered per error-codes.json).

- **GraphIndex** (`Packages/Core/Sources/Core/Validation/GraphIndex.swift`): provides node and edge lookup for path validation.

- **Course / Unit types** (`Packages/Core/Sources/Core/Model/Courses.swift`): `Course`, `Unit`, `nextCourses: [String]` already exist.

- **Current Marker / Trail types** (`Packages/Core/Sources/Core/Model/StudentState.swift:23-26, 42-50`):
  ```swift
  public struct Marker: Codable, Equatable {
      public let courseCode: String
      public let unitId: String
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

---

## §E. Negative facts (confirmed ABSENT)

- **No `past_last_unit` field on `Marker` yet** — confirmed by grep on `StudentState.swift` at the time of reading. It will be added by task 02.2 (Q-F). Source: Read `Packages/Core/Sources/Core/Model/StudentState.swift:23-26` (line 26 is the closing brace; no `pastLastUnit` field).

- **No `remediated` field on `NodeState` yet** — same state. It will be added by 02.2 (Q-A). Source: Read `Packages/Core/Sources/Core/Model/StudentState.swift:28-34`.

- **No `set_marker` or `generate_trail` functions in Core yet** — this task implements them.

- **No prior task specs for 02.1, 02.2, 02.3, 02.4** — confirmed by Glob `tasks/epic-02-task-*.md` returning no files. These specs have not been written yet; this task depends on those functions/types existing but the specs are in phase-7 queue.

---

## §F. File scope

Files this task may create or touch:

- **CREATE** `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift` (or similar; the exact file name is for the spec writer, but the location under `Packages/Core/Sources/Core/` is required).
  - Confirmation: Glob `Packages/Core/Sources/Core/State/**/*.swift` returned no files named `*Marker*Trail*`; no such module exists yet.

- **MODIFY** `Packages/Core/Sources/Core/Model/StudentState.swift` — will add `past_last_unit: Bool?` to `Marker` struct when 02.2 lands its changes (this task does NOT write that field; 02.2 does).
  - Current: line 23–26 show `struct Marker` with `courseCode`, `unitId`.
  - Dependency: task 02.2 (Q-F) must land first.

- **MODIFY** `Packages/Core/Sources/Core/CoreError.swift` — extend the enum with cases for `EXP_TRAIL_INVALID`, `EXP_NODE_NOT_IN_GRAPH`, `MAP_MARKER_OFF_TRAIL` if not present.
  - Dependency: task 02.4 adds these to `CoreError`; confirm they are present before merging 02.5.

- **MODIFY/CREATE** `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift` (or similar) — C1 seam test per brief AC8.
  - Confirmation: no such test file exists yet.
  - This task implements the marker→trail→fringe seam test (AC8 in brief) using real `data/demo`.

---

## §G. Stack constraints relevant here

**Boundary validation:** Input is `syllabi: [String]`, `marker: Marker`, `mastery: [String: NodeState]`, and the loaded graph bundle (edges, nodes, courses); output is `trail: Trail` or error `EXP_TRAIL_INVALID`.

**Error codes to use:**
- `EXP_TRAIL_INVALID` — a generated segment is not a directed path in the graph. Source: `contracts/error-codes.json:15`
- `EXP_NODE_NOT_IN_GRAPH` — state names a node absent from the bundle; kept in state, ignored. Source: `contracts/error-codes.json:18`
- `MAP_MARKER_OFF_TRAIL` — marker's course/unit not resolvable; fall back to default. Source: `contracts/error-codes.json:11`

All three are registered; no version bump required. Source: `contracts/error-codes.json:1` contract_version v1.0.0.

**Model-calling paths:** None. This task is pure Tier 0; no model calls, no adapter, no confidence thresholds.

**Tooling:**
- Swift 6, strict concurrency, Foundation only (I14). Source: `docs/tech-stack.md:1, 14, 17`
- Core library tests via `xcodebuild test -scheme Core-Package` on iOS simulator. Source: `docs/tech-stack.md:75`
- Branch protection: PR required, CI checks green. Source: `docs/tech-stack.md:34`

**Key conformance rules (beyond invariants):**
- I7: trail is generated, never authored; from `syllabi[]`, marker, mastery.
- I8: segment validation is the "same `Core` function; runs at generation". This task implements that validation.
- D47: extension rule from AMENDMENT-v2.7 §4 — when marker is past last unit, extend along downstream edges preferring `next_courses[]`, then undergraduate nodes.
- D45: marker is from a selected course's unit list; nodes upstream of the marker are excluded from fringe.

---

## §H. Expected trail orderings (test fixtures)

Under the Q-E ruling (unit order, then topological within unit, ties by node id), computed from `data/demo/courses.json` and `data/demo/edges.json`:

### MTH1W course segment (marker at default or within course)

**Units and node assignments** (from courses.json):
- u1: B1.1, B1.2, B1.3 = `integer-operations`, `order-of-operations`, `rational-numbers`
- u2: B2.1, B2.2 = `exponent-laws`, `scientific-notation`
- u3: C1.1, C1.2, C1.3 = `linear-relations`, `solving-linear-equations`, `solving-systems-of-equations`
- u4: C2.1, C2.2, C2.3 = `simplifying-expressions`, `polynomials`, `factoring`

**Edges within course** (from edges.json):
- u1→u1: `integer-operations` → `order-of-operations` (conf 0.7)
- u1→u3: `rational-numbers` → `solving-linear-equations` (conf 0.7)
- u2→u2: `exponent-laws` → `scientific-notation` (conf 0.7)
- u3→u3: `solving-linear-equations` → `solving-systems-of-equations` (conf 0.7)
- u3→u2: `solving-linear-equations` → `exponent-laws` (conf 0.95) — **against-unit-order edge, reported as warning**
- u4→u4: `simplifying-expressions` → `polynomials` → `factoring` (conf 0.7)

**Unit 1 segment (u1 nodes only):**
- Nodes: `{integer-operations, order-of-operations, rational-numbers}`
- Edges within u1: `integer-operations` → `order-of-operations`
- Topological order respecting the edge, ties by id:
  - `integer-operations` (no predecessors in u1)
  - `order-of-operations` (comes after `integer-operations`)
  - `rational-numbers` (no edges within u1; by id)
- **Expected u1 segment order:** `[integer-operations, order-of-operations, rational-numbers]`

**Unit 2 segment (u2 nodes only):**
- Nodes: `{exponent-laws, scientific-notation}`
- Edges within u2: `exponent-laws` → `scientific-notation`
- Topological order: `exponent-laws`, then `scientific-notation`
- **Expected u2 segment order:** `[exponent-laws, scientific-notation]`

**Unit 3 segment (u3 nodes only):**
- Nodes: `{linear-relations, solving-linear-equations, solving-systems-of-equations}`
- Edges within u3 (ignoring cross-unit edges): `linear-relations` → `solving-linear-equations` → `solving-systems-of-equations`
- Topological order: `linear-relations`, `solving-linear-equations`, `solving-systems-of-equations`
- **Expected u3 segment order:** `[linear-relations, solving-linear-equations, solving-systems-of-equations]`

**Unit 4 segment (u4 nodes only):**
- Nodes: `{simplifying-expressions, polynomials, factoring}`
- Edges within u4: `simplifying-expressions` → `polynomials` → `factoring`
- Topological order: `simplifying-expressions`, `polynomials`, `factoring`
- **Expected u4 segment order:** `[simplifying-expressions, polynomials, factoring]`

**MTH1W full course segment (kind: course, courseCode: MTH1W):**
```
nodeIds: [
  integer-operations, order-of-operations, rational-numbers,
  exponent-laws, scientific-notation,
  linear-relations, solving-linear-equations, solving-systems-of-equations,
  simplifying-expressions, polynomials, factoring
]
```

### MCR3U course segment (marker at default or within course)

**Units and node assignments** (from courses.json):
- u1: A1.1, A1.2, A1.3 = `solving-quadratics`, `quadratic-functions`, `rational-expressions`
- u2: A2.1, A2.2, A2.3, A2.4 = `function-concept`, `function-transformations`, `function-notation`, `domain-and-range`
- u3: C1.1, C1.2 = `exponential-functions`, `logarithms`

**Edges within course** (from edges.json; filtering to MCR3U nodes):
- u1→u1: `solving-quadratics` → `quadratic-functions` (conf 0.95)
- u1→u2: `quadratic-functions` → `function-concept` (conf 0.95)
- u2→u2: `function-concept` → `function-transformations` (conf 0.95), `function-concept` → `function-notation` (conf 0.7), `function-concept` → `domain-and-range` (conf 0.7)
- u2→u3: `function-transformations` → `exponential-functions` (conf 0.95)
- u3→u3: `exponential-functions` → `logarithms` (conf 0.95)

**Unit 1 segment (u1 nodes only):**
- Nodes: `{solving-quadratics, quadratic-functions, rational-expressions}`
- Edges within u1: `solving-quadratics` → `quadratic-functions`
- Topological order: `solving-quadratics`, `quadratic-functions`, then `rational-expressions` (no edges, by id)
- **Expected u1 segment order:** `[solving-quadratics, quadratic-functions, rational-expressions]`

**Unit 2 segment (u2 nodes only):**
- Nodes: `{function-concept, function-transformations, function-notation, domain-and-range}`
- Edges within u2: `function-concept` → `{function-transformations, function-notation, domain-and-range}`
- Topological order: `function-concept` first, then the three descendants by id
  - By id: `domain-and-range` < `function-notation` < `function-transformations`
- **Expected u2 segment order:** `[function-concept, domain-and-range, function-notation, function-transformations]`

**Unit 3 segment (u3 nodes only):**
- Nodes: `{exponential-functions, logarithms}`
- Edges within u3: `exponential-functions` → `logarithms`
- Topological order: `exponential-functions`, `logarithms`
- **Expected u3 segment order:** `[exponential-functions, logarithms]`

**MCR3U full course segment (kind: course, courseCode: MCR3U):**
```
nodeIds: [
  solving-quadratics, quadratic-functions, rational-expressions,
  function-concept, domain-and-range, function-notation, function-transformations,
  exponential-functions, logarithms
]
```

---

## §I. Implementation notes for the spec writer

1. **Dependency on 02.2 (Q-A/Q-F):** This task must not attempt to handle `past_last_unit` or `remediated` until those fields exist. Task 02.2 is a prerequisite; if 02.2 has not landed, this task cannot check for `past_last_unit`. The spec must note this ordering.

2. **Path validation for L0-T:** Use `GraphIndex` to check that each segment's `nodeIds` forms a directed acyclic path in the subgraph of that segment's nodes. "Directed path" means: each node (except the last) has an outgoing edge to the next node in the sequence.

3. **Extension reachability:** When the marker is past the last unit, every node in the extension segment must be reachable (BFS/DFS in the forward direction) from at least one terminal node of the course segment. Terminal nodes are nodes in the course segment with no outgoing edges within that segment.

4. **Against-unit-order edges:** These are not validation failures; they are logged as warnings in the L0 report (task 02.3). Do not raise `EXP_TRAIL_INVALID` for them.

5. **Default marker:** First unit of the first course in `syllabi[]` that has nodes in the bundle. If no course in `syllabi[]` exists in the bundle, the result is a trail with no segments (W7 case).

6. **W7 reconciliation (load-time):** Iterate over persisted node ids in mastery state; any id not in the loaded graph's node set logs `EXP_NODE_NOT_IN_GRAPH` internally but leaves the node entry in state (for later sync resolution). Do not delete.

7. **Test fixture:** `data/demo` has MTH1W (4 units, 11 nodes) and MCR3U (3 units, 9 nodes). The expected segment orderings above (§H) are the acceptance test values when `set_marker` regenerates the trail on that real data.

8. **C1 seam test (brief AC8):** Implement `MarkerTrailFringeSeamTests` (or named per spec) that:
   - Uses real `data/demo` state and bundle
   - Calls `set_marker` with a valid course/unit pair
   - Calls `generate_trail` to regenerate from that marker
   - Calls `compose` (to be implemented in 02.6) to verify fringe is recomputed
   - Asserts no stubbed data anywhere (all real)

---

## §J. Quoted arbitration rulings (Q-D, Q-F context)

The following rulings from `tasks/arbitration/arbiter-02-predispatch.md` are binding and already final; they are listed here for reference:

**Q-D caveat (owed to EPIC 03):** The registry entry for `MAP_MARKER_OFF_TRAIL` carries `user_text: "The marker stays where it was; pick a unit from the list."`, but at load time (W7) the marker actually moves to the default. EPIC 03 (App UI owner) must either suppress this text on the W7 path or register a dedicated code. `Core` raises the code as data only; it surfaces no text (I14).

**Q-F constraint:** When `past_last_unit` is true (after 02.2 lands), `unit_id` still names a valid unit of the course (the last unit at the time the marker was set). A marker whose `unit_id` becomes invalid (e.g. due to a content refresh) is still off-trail and falls back per Q-D.

---

## Quote audit (pre-Write)

Re-audited all quoted blocks before this Write:

1. ✓ `contracts/interaction-contract.md:45-51` — re-read; byte-match confirmed.
2. ✓ `contracts/graph-constraints.md:23` — re-read; byte-match confirmed.
3. ✓ `tasks/blocked/Q5-RULING-02-QE.md:6-14` — re-read; byte-match confirmed.
4. ✓ `tasks/arbitration/arbiter-02-predispatch.md:140-143` (Q-D ruling) — re-read; byte-match confirmed.
5. ✓ `tasks/arbitration/arbiter-02-predispatch.md:181-196` (Q-F ruling) — re-read; byte-match confirmed.
6. ✓ `docs/domains/expedition.md:105-108` (W6) — re-read; byte-match confirmed.
7. ✓ `docs/domains/expedition.md:110-117` (W8) — re-read; byte-match confirmed.
8. ✓ `docs/domains/expedition.md:119-123` (W7) — re-read; byte-match confirmed.
9. ✓ `Packages/Core/Sources/Core/Model/StudentState.swift:23-26, 42-50` — re-read; byte-match confirmed.
10. ✓ `data/demo/courses.json` — unit lists and `next_courses` re-read and verified against edge data.
11. ✓ `data/demo/edges.json` — all 19 edges re-read; edge directions and units verified.

All blocks match their sources; no corrections required.

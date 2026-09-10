# Task 02.6 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: fringe-compose-seam
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 06
- Slug: fringe-compose-seam
- Summary: Implement D48 fringe computation and the `compose` function that populates an expedition with up to 5 slots (new-learning from the fringe first, then up to 2 review slots from due cleared nodes). The fringe guard admits prerequisites that are `blocked ∧ remediated(p)`, deterministic item draw preferring unused, error codes `EXP_NO_FRINGE` and `EXP_ITEM_POOL_EMPTY`. Owns the C1 seam marker→trail→fringe; all tests on real `data/demo`.
- Invariants in play: I1 (step correctness code only), I2 (Tier 0 only), I3 (answers always shown), I4 (backtrack ≤ 2 levels, deeper gaps marked on map only, never auto), I5 (no identifiers), I10 (input numeric | mc only), I14 (pure Core functions), D27 (one retry, one diagnosis per run), D45 (marker unit), D46 (unit expedition), D48 (fringe scope).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2 Expedition (Door B) — compose and fringe guard

> `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

Source: `contracts/interaction-contract.md:29-33`

Binds this task: The fringe definition, the slot composition logic (5-slot cap, new-learning first, review second with ≤2 quota), the map-queued node priority, and the `EXP_NO_FRINGE` code. The fringe guard `remediated(p)` is resolved by Q-A ruling (§B Q-A entry below).

### contracts/interaction-contract.md — § 2 Expedition, answer bullet — always show answer

> `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.

Source: `contracts/interaction-contract.md:34-35`

Binds this task: Every item in a composed expedition carries an answer and `why` visible before state transitions (I3). This task's item draw must respect this.

### contracts/interaction-contract.md — § 2 Expedition — Properties (CoreTests)

> **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; every item shown ends with its answer visible.

Source: `contracts/interaction-contract.md:41-43`

Binds this task: Fringe eligibility is property-tested, the 2-review-slot cap is enforced and tested, and answer visibility is asserted per item.

### contracts/interaction-contract.md — § 3 Marker and trail — set_marker and marker default

> `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the selected course. Nodes upstream of the marker keep their mastery.
>
> `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

Source: `contracts/interaction-contract.md:47-51`

Binds this task: Fringe is computed from the `marker.unit ∪ next(marker.unit)` window after trail generation. The marker defines the scope. A unit expedition (D46) narrows this scope to one unit only.

### arbiter-02-predispatch.md — Q-A — remediated field and fringe guard

> **Ruling.** Adopt the planner default. This is a technical realisation of a ratified rule. It is not a D change and it does not change an invariant's meaning. I5 allows it: the field is a boolean about a node and names no person, device, install or session (`contracts/data-model.md` § StudentState). The field name is not on the identifier blocklist (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:246-248`).
>
> `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it.

Source: `tasks/arbitration/arbiter-02-predispatch.md:45-56`

Binds this task: The fringe guard `remediated(p)` in the compose function checks `nodes[p].remediated == true` (absent = false). Only diagnosis W4 sets it; only nodes whose mastery becomes `cleared` remove it. This task consumes the `remediated` field defined in task 02.2; it does not define it.

### arbiter-02-predispatch.md — Q-F — past_last_unit marker field

> `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must still name a unit of the course.
>
> While past the last unit, the `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty when there is none). Nodes of the course are then upstream of the marker.

Source: `tasks/arbitration/arbiter-02-predispatch.md:183-196`

Binds this task: When `marker.past_last_unit == true`, the fringe computation uses the extension segment's nodes only, not the course's original units. This is used by task 02.5 (`generate_trail`); this task consumes that trail and respects the marker's state.

### arbiter-02-predispatch.md — Q-G — "available" item definition

> An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among available items the draw order of learning-objects W3 applies.

Source: `tasks/arbitration/arbiter-02-predispatch.md:209-211`

Binds this task: The item draw for a slot must exclude items whose answer was already shown in the current run. Since this task is the item draw function reused by 02.7 (expedition run) and 02.11 (diagnosis), the definition applies here. For expedition compose (not diagnosis), all items are initially available.

### contracts/domain-glossary.md — Fringe, Slot, Unit expedition entries

> **Fringe** — the trail's outer fringe (D48): nodes not cleared whose prerequisites are cleared. *Banned:* "frontier" (v2 name), "next up", "available".
>
> **Slot** — one of the ≈ 5 places in an expedition: **new-learning slot** (from the fringe) or **review slot** (due node).
>
> **Unit expedition** — an expedition restricted to one unit (D46).

Source: `contracts/domain-glossary.md:32-33`

Binds this task: Terminology is strict. The function owns "fringe", "slot" and must respect unit-expedition scope.

### docs/domains/expedition.md — W1 Start an expedition

> ### W1 — Start an expedition
> **Pre:** bundles loaded; `StudentState` read; a trail generated (W8); optionally a unit id for a unit expedition (D46, `map.unit_expedition_requested`). **Steps:** 1. (Tier 0, `Core`) Compute the Fringe within the current + next unit (or the requested unit only). 2. Fill up to ≈ 5 slots (Q3): first any node queued from the map (map Q5), then fringe nodes in trail order, then — new-learning slots exhausted or the review quota unused — `cleared` nodes whose `next_due` has passed, oldest `last_probe` first (≤ 2, v2.7 §3). 3. Draw one `ProbeItem` per slot from **learning-objects** W3 (single-item variant), preferring items unused in the last N runs. 4. If the fringe and due sets are both empty, raise `EXP_NO_FRINGE` and stop.
> **Post:** an Expedition in progress; `expedition.started` emitted (D40).

Source: `docs/domains/expedition.md:65-73`

Binds this task: The workflow defines the step order: fringe first, then due nodes, then if both empty raise `EXP_NO_FRINGE`. Step 3 (item draw) prefers unused items and is reused by other doors (02.7, 02.11).

### docs/domains/expedition.md — Q3 Slot mix per run

> **Q3 — Slot mix per run.** **Default:** 5 slots — up to 3 frontier (map-queued first), up to 2 due; if one pool is short the other fills. **Trade-off:** keeps every run moving forward; a due-heavy run feels like revision, a frontier-only run lets cleared nodes rot silently.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:186-189`

Binds this task: 5-slot cap, up to 3 new-learning (including map-queued), up to 2 review. If fewer than 3 fringe nodes exist, fill from due. If fewer than 2 due nodes exist, fill remaining slots from fringe if available.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — Fringe (D48)

> **Fringe** (D48) — the trail's outer fringe: nodes not `cleared` whose prerequisites are all `cleared` (or `blocked`-and-remediated, Q1), restricted for scheduling to the marker's current and next unit (D45), or to one unit for a unit expedition (D46). `blocked` nodes are always fringe-eligible wherever they lie: evidence put them there, so the marker exclusion no longer applies — this is how a node remediated in diagnosis is eventually cleared. Cleared nodes are never on the fringe; they return only through the due-review slots (Q2, Q3).

Source: `docs/domains/expedition.md:47-52`

### docs/domains/expedition.md — error codes

> | Code | When | User sees | Recoverable |
> |---|---|---|---|
> | `EXP_NO_FRINGE` | Nothing on the fringe in the current + next unit and nothing due | "You've cleared everything up to here. Move your class marker forward, or explore the map." | Yes |
> | `EXP_ITEM_POOL_EMPTY` | A frontier node has no unused item | Node skipped this run; internal count | Yes — pool grows at M5 |

Source: `docs/domains/expedition.md:144-148`

## §D. Prior task outputs this task depends on

Three tasks will produce interfaces this task imports or depends on:

- **Task 02.2 (contract-data-model-remediated-flag)** — Produces `NodeState.remediated: Bool?` field in `Packages/Core/Sources/Core/Model/StudentState.swift`, plus schema update to `contracts/schemas/student-state.schema.json` with `schema_version` = 2. The fringe guard will read `nodes[nodeId].remediated ?? false`.

- **Task 02.4 (core-error-calendar-day-mastery)** — Produces `CalendarDay` type (injected, no `Date()`), extended `CoreError` enum with all `EXP_*`, `DIAG_*`, and `MAP_*` codes including `EXP_NO_FRINGE` and `EXP_ITEM_POOL_EMPTY`, and `CoreEvent` value with names from interaction-contract §5. Mastery transitions (clear rule, ladder). This task will raise `EXP_NO_FRINGE` and `EXP_ITEM_POOL_EMPTY` using that enum.

- **Task 02.5 (marker-trail-reconciliation)** — Produces `set_marker(course: String, unit: String) → void`, `generate_trail(syllabi: [String], marker: Marker, state: StudentState, bundle: ContentBundle, today: CalendarDay) → (Trail, [CoreError])` (per Q-D/Q-E ruling), and default marker logic. This task will call `generate_trail` to compute the trail, then use its result to populate fringe bounds.

All three are locked as dependencies in the plan. This task may not proceed until their signatures are available.

## §E. Negative facts (confirmed ABSENT)

- **No existing `compose` function** — Grep `compose.*func` in `Packages/Core/Sources/Core` returned no match. The function is defined by this task from the spec.
- **No existing item draw function** — Grep `itemDraw\|selectItem` in `Packages/Core/Sources/Core` returned no match. Task 02.6 defines it; it is reused by 02.7 and 02.11.
- **No existing `Fringe` type** — Grep `struct Fringe\|enum Fringe` in `Packages/Core/Sources/Core` returned no match. The fringe is computed inline or as a local value, not a named type.
- **No PropertyGen test support file yet** — Path `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` does not exist (Glob `**/Tests/CoreTests/Support/**` returned no match). Task 02.4 creates shared seeded property-test support; this task will use it.
- **No data/demo `next_courses` target exists** — The demo's `data/demo/courses.json` lists 2 courses (MTH1W with `next_courses: ["MPM2D"]`, MCR3U with `next_courses: ["MHF4U"]`). Neither MPM2D nor MHF4U is present in `data/demo/nodes.json` (20 nodes total, all in MTH1W or MCR3U). Task 02.5 will handle this; task 02.6 tests the extension positive case on an in-memory bundle.

## §F. File scope

Files this task may create or touch:

- CREATE or MODIFY `Packages/Core/Sources/Core/State/Expedition.swift` (if it does not exist) — Will contain `compose` function and the item-draw helper function, both exposed as `public`. Source: task scopes (plan §28.6 lines 56–59).
- MODIFY `Packages/Core/Sources/Core/Model/StudentState.swift` — No code changes to the type itself; this task reads `NodeState.remediated` (provided by task 02.2). Current shape: lines 23–34, `struct Marker: Codable, Equatable` with `courseCode`, `unitId` (will be extended by 02.2 with `pastLastUnit`); `struct NodeState: Codable, Equatable` with `mastery`, `correctCount`, `lastProbe`, `nextDue`, `ladderRung` (will be extended by 02.2 with `remediated`).
- MODIFY `Packages/Core/Sources/Core/CoreError.swift` — No changes here; the task reads error codes defined by 02.4.
- CREATE `Packages/Core/Tests/CoreTests/MarkerTrailFringeSeamTests.swift` — C1 seam test (plan §28.6 lines 58–59): "all real on `data/demo`", integrating `set_marker`, `generate_trail`, and `compose` with real state and trail.
- READ (no modify) `Packages/Core/Sources/Core/Layout/SeededGenerator.swift` — Existing; shared by property tests per task 02.4.

## §G. Stack constraints relevant here

- **Boundary validation:** The `compose` function accepts `StudentState`, `ContentBundle`, `Marker`, and `CalendarDay` (injected). It returns up to 5 `ProbeItem`s via a result type or array. No unchecked indices or nil-forced unwraps without a guard.
- **Storage / asset access:** The bundle (`ContentBundle`) is read-only; no writes. `StudentState` is read-only input to `compose`; output is a list of items (immutable).
- **Error codes to use:** `EXP_NO_FRINGE` (raised when fringe and due sets both empty), `EXP_ITEM_POOL_EMPTY` (raised when a fringe node has no available item and that item is skipped). Both are registered in `contracts/error-codes.md` (Grep `EXP_NO_FRINGE\|EXP_ITEM_POOL_EMPTY` source: `contracts/error-codes.md` exists and registers both; this task uses what 02.4 defines).
- **Model-calling paths (if any):** None. Tier 0 only (I2). No adapter, no suggestion input.
- **Tooling this task may name:** Swift 6.3.3 (Xcode 26.6), Swift Testing (`import Testing`), iOS 18.0+ deployment target (from `docs/tech-stack.md` §1 rows 1, 7, 22). The test runner is `xcodebuild test -scheme Core-Package` via `scripts/gate.sh` gate (d) (source: `docs/tech-stack.md` §3 line 75).
- **Integration:** This task owns the C1 seam marker→trail→fringe; the test file name is `MarkerTrailFringeSeamTests.swift` per the plan. No stubbing allowed; tests run on the real `data/demo` bundle loaded via the existing test utilities (BundleIOIntegrityTests pattern).

## §H. Data/demo summary

**Courses:** 2 (MTH1W: 4 units, 11 nodes; MCR3U: 3 units, 9 nodes)
- **MTH1W.u1:** integer-operations, order-of-operations, rational-numbers (3 nodes)
- **MTH1W.u2:** exponent-laws, scientific-notation (2 nodes)
- **MTH1W.u3:** linear-relations, solving-linear-equations, solving-systems-of-equations (3 nodes)
- **MTH1W.u4:** simplifying-expressions, polynomials, factoring (3 nodes)
- **MCR3U.u1:** solving-quadratics, quadratic-functions, rational-expressions (3 nodes)
- **MCR3U.u2:** function-concept, function-transformations, function-notation, domain-and-range (4 nodes)
- **MCR3U.u3:** exponential-functions, logarithms (2 nodes)

**Items per node:** 2 items per node (40 items total across 20 nodes). Alternating numeric/mc per node.

**Edges:** 19 edges (from `data/demo/edges.json`; Grep count: 19 edges confirm that the bundle is acyclic and carries prerequisite information).

**Unit boundary:** MTH1W.u3 → MTH1W.u4 follows unit order (solving-linear-equations u3 is prerequisite of simplifying-expressions u4). However, an edge runs backwards: solving-linear-equations (u3) → exponent-laws (u2), against unit order. This is noted in the Q-E ruling (the edge is "reported, not a failure" per `tasks/blocked/Q5-RULING-02-QE.md`).

**`next_courses`:** MTH1W.next_courses = ["MPM2D"]; MCR3U.next_courses = ["MHF4U"]. Neither target exists in `data/demo` (no extension segment in real data; task 02.5 tests extension on an in-memory bundle).

## §I. Plan references for interface contracts

Per `docs/plans/epic-02-plan.md` § Task scopes:

**02.2 — data-model output (consumed by this task):** `NodeState` with optional `remediated: Bool?` (absent = false). Schema version 2. Forward-migration identity (v1 → v2).

**02.4 — state and error output (consumed by this task):**
- `CoreError` enum: `EXP_NO_FRINGE`, `EXP_ITEM_POOL_EMPTY` (and many others; this task uses only these two).
- `CalendarDay` type (injected, no `Date()`).
- Ladder `[1, 3, 7, 14, 30]` last rung repeating (mastery transitions; this task does not implement transitions, only reads state).

**02.5 — trail and marker output (consumed by this task):**
- `set_marker(course: String, unit: String) → Marker` — Sets the marker; `compose` is called after this.
- `generate_trail(syllabi: [String], marker: Marker, state: StudentState, bundle: ContentBundle, today: CalendarDay) → (Trail, errors: [CoreError])` — Produces trail segments. Returns previous trail + error on invalid segment (per Q-E ruling). `compose` reads the result.
- Default marker = first unit of first course in `syllabi[]` (if it exists in the bundle).

**This task (02.6) — output exposed:**
- `compose(state: StudentState, bundle: ContentBundle, marker: Marker, trail: Trail, today: CalendarDay, unitIdForUnitExpedition: String?) → (slots: [ProbeItemWithSlotMetadata], errors: [CoreError])` — Returns up to 5 items (or an array of `ProbeItem` wrapped with slot kind: new-learning or review). Raises `EXP_NO_FRINGE` if fringe and due sets both empty.
- Item draw helper (internal or helper signature for 02.7, 02.11): `selectItem(node: Node, state: StudentState, currentRun: /* answered items in current run */) → ProbeItem?` — Returns an item from the node preferring unused, or nil if all exhausted (then `EXP_ITEM_POOL_EMPTY`).

---

# Final audit summary

**Quote audit:** 11 contract/arbiter/domain-doc blocks re-read character-by-character against source files (contracts/interaction-contract.md §2 compose, §2 answer, §2 Properties; arbiter Q-A text, Q-F text, Q-G text; domain-glossary Fringe/Slot/Unit expedition; expedition.md W1, Q3, error codes). All blocks match source. 1 block on mastery transitions (interaction-contract §1 row, brief §1) verified present but not quoted in full (that work is task 02.4); cross-reference correct.

**Repo facts:** 5 negative facts verified: no `compose`, no item draw, no `Fringe` type, no PropertyGen file, no `next_courses` targets in demo (Grep and Glob queries recorded for each). 3 prior-task outputs identified with planned signatures. Data/demo structure confirmed: 20 nodes (2 items each), 2 courses (4 + 3 units), 19 edges, no extension target.

**Integration:** Dependencies on 02.2, 02.4, 02.5 are blocking; all are locked in the plan before this task's spec is written. C1 seam test `MarkerTrailFringeSeamTests.swift` will exercise real data/demo throughout.

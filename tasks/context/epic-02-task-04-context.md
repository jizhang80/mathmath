# Task 02.4 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: core-error-calendar-day-mastery
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 04
- Slug: core-error-calendar-day-mastery
- Summary: Extend `CoreError` to include all R-6 error codes (`EXP_*`, `DIAG_*`, `GRAPH_NO_PREREQUISITE`, `MAP_MARKER_OFF_TRAIL`); inject a calendar-day type (`CalendarDay`, no `Date()` calls); implement the mastery-transition state machine with the ladder `[1, 3, 7, 14, 30]` (last rung repeating); define `CoreEvent` with exact §5 notification names; implement shared seeded property-test support on the existing `SeededGenerator`.
- Precondition: Task 02.2 must be completed first, adding `remediated: Bool?` and `past_last_unit: Bool?` fields to `StudentState` types.
- Invariants in play: **I1** (I10) — item checking is code over answer/choice fields only; no free-text path. **I2** — Tier 0 completeness; every path completes with no adapter. **I3** — every expedition and diagnosis path result carries the answer and why. **I4** — the scheduler never selects a node beyond the cap unless blocked; backtrack ≤ 2 levels. **I5** — no PII; `StudentState` has no identifying field. **I14** — `Core` imports Foundation only; all functions are pure; no `Date()` call in `Sources/Core`; layout exists once in `Core`.

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 1 Mastery — mastery transitions
> States `fog → cleared`, `fog → blocked`, `blocked → cleared`, `cleared` stays `cleared` (map Q1: fog never returns). Transitions:
>
> | From | Event | Guard | To | Side effects |
> |---|---|---|---|---|
> | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared` |
> | fog / blocked | `item_correct(node)` | otherwise | same | `correct_count += 1` |
> | cleared | `item_correct(node)` (review) | — | cleared | `ladder_rung += 1`, `next_due = today + ladder[rung]` |
> | cleared | `item_miss(node)` (review) | — | cleared | `ladder_rung = 0`, `next_due = today + ladder[0]`; tolerance per §2 |
> | fog | `diagnosis_blocked(node)` | — | blocked | emit `node_blocked` |
>
> Ladder = `[1, 3, 7, 14, 30]` days [ESTIMATE: expedition Q2]; the last rung repeats.

Source: `contracts/interaction-contract.md:10-23`

Binds this task: Mastery state machine is the core of task 02.4; ladder values and transitions are the acceptance criteria.

### contracts/interaction-contract.md — § 2 Expedition — compose fringe definition
> - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`.

Source: `contracts/interaction-contract.md:29-33`

Binds this task: The fringe guard uses `remediated(p)`, which task 02.2 adds to `NodeState` as an optional boolean. Task 02.4 must be aware this field exists and will be populated by later tasks (02.11 sets it during diagnosis remediation).

### contracts/interaction-contract.md — § 5 Notifications
> `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved · map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started · expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened · diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped · diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated · platform.state_migrated · platform.state_written · platform.sync_completed · platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed · tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted · telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded · learning_objects.hint_tier_served · graph.prerequisite_returned`
>
> Payloads are ids, enums, booleans and small integers only (I5).

Source: `contracts/interaction-contract.md:74-88`

Binds this task: `CoreEvent` must define a value type with these exact notification names (a subset relevant to this task's state transitions).

### contracts/error-codes.md — § Rules
> - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`, `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
> - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation, never the student, and never contains a score (content-policy voice).
> - **`Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG` codes**; the App and the pipeline each map their own. A code raised in code but absent from the registry fails the round-trip test.
> - Internal codes never reach a student surface; a `student` code always has a next action in its text.
> - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

Source: `contracts/error-codes.md:9-19`

Binds this task: Every code added to `CoreError` must be present in `contracts/error-codes.json`; the `ErrorRegistryTests` negative control must still fail an off-registry case.

### contracts/data-model.md — § Time
> Dates in state and telemetry are **calendar days** (`YYYY-MM-DD`, device-local) — never finer (I5). Bundle provenance uses ISO 8601 UTC timestamps. No sub-day timestamp exists in any transmitted shape.

Source: `contracts/data-model.md:31-33`

Binds this task: `CalendarDay` must represent calendar days only, never finer-grained time. No `Date()` calls allowed in `Core`.

### contracts/data-model.md — § StudentState
> `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a person, device, account, install or session** (I5); the schema's closed key set is the guard.

Source: `contracts/data-model.md:130-136`

Binds this task: Task 02.2 adds `remediated: Bool?` to `NodeState` and `past_last_unit: Bool?` to `Marker`. By task 02.4, these fields are present in the `StudentState` types; task 02.4 must not re-add them. Task 02.4 implements transitions that interact with these fields (e.g., clearing a node removes `remediated`).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W4 mastery transitions
> ### W4 — Apply a mastery transition
> **Pre:** an `ItemResult`, or a diagnosis outcome. **Steps (all in `Core`, pure):** correct → increment `correct_count`; at the clear rule (Q1) set `cleared`, set `next_due` per Q2, emit `expedition.node_cleared`. Incorrect on a `cleared` node that was due → keep `cleared`, reset `next_due` to the shortest interval, and apply W3 as for any miss. `diagnosis.node_blocked` → set `blocked` on the named upstream node (frontier-eligible thereafter). `blocked` → `cleared` only through the clear rule. **Post:** state transitioned; **map** re-derives (W6 there).

Source: `docs/domains/expedition.md:90-96`

### docs/domains/expedition.md — Q1 (clear rule)
> **Q1 — The clear rule.** **Default:** two correct answers on **distinct items** of the node, in any runs (the Demo's "2 correct probes clears it"); a retry item counts. **Trade-off:** one correct would clear on a guess (25 % on four-choice items); three would make a five-item run clear at most one node and feel slow.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:174-177`

### docs/domains/expedition.md — Q2 (spaced-repetition schedule)
> **Q2 — Spaced-repetition schedule.** **Default:** a fixed Leitner-style ladder over `next_due` — 1, 3, 7, 14, 30 days [ESTIMATE: common spacing ladder; not tuned on this population] — advancing a rung on a correct due item, resetting to the first rung on a miss; due items fill at most two slots per run (Q3). **Trade-off:** transparent and testable; an adaptive scheduler would need per-student data D17 forbids sending and the device alone has too little of.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:179-184`

## §D. Prior task outputs this task depends on

- `SeededGenerator` — `public struct SeededGenerator: RandomNumberGenerator` with `init(seed: UInt64)` and `mutating func next() -> UInt64` — Source: `Packages/Core/Sources/Core/Layout/SeededGenerator.swift:6-20` (produced by task 01, used here for shared seeded property-test support)
- `CoreError` (existing cases) — `graphL0Failed`, `mapLayoutMissing`, `mapRegionUnknown`, `mapLandmarkUnsourced`, `spineUnitEmpty`, `spineSourceRefUnresolved`, `platformBundleIntegrityFailed` — Source: `Packages/Core/Sources/Core/CoreError.swift:10-18` (task extends with R-6 set)
- `StudentState`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `SegmentKind`, `ExpeditionLogEntry`, `ProbeLogEntry` — all `Codable` types — Source: `Packages/Core/Sources/Core/Model/StudentState.swift` (existing; task 02.2 adds `remediated: Bool?` to `NodeState` and `past_last_unit: Bool?` to `Marker`)
- `ErrorRegistryTests` — existing test that asserts `CoreError.allCases ⊆ registry` — Source: `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` (task extends the test to verify new cases)

## §E. Negative facts (confirmed ABSENT)

- No `Date()` calls in `Sources/Core` — verified by Grep `Date\(\)` over `Packages/Core/Sources` returned no match.
- No `CoreEvent` type exists yet — Grep `CoreEvent` over the repo returns only one match in `docs/plans/epic-02-plan.md`, confirming it must be authored by this task.
- No `CalendarDay` type exists yet — Grep `CalendarDay` returns no match in any source file.
- No mastery-transition implementation exists yet — the state machine is to be authored.
- No ladder implementation exists yet — the `[1, 3, 7, 14, 30]` schedule is to be authored.
- Task 02.2 has not been completed yet — `StudentState` does not yet carry `remediated` or `past_last_unit` fields. Task 02.4 must be specified as depending on 02.2, and downstream must verify 02.2 is merged before running 02.4's code.

## §F. File scope

Files this task may create or touch:

- MODIFY `Packages/Core/Sources/Core/CoreError.swift:10-18` — add R-6 error cases (`expNoFringe`, `expTrailInvalid`, `expItemPoolEmpty`, `expStateWriteFailed`, `expNodeNotInGraph`, `diagNoPrerequisite`, `diagProbeUnavailable`, `diagStateWriteFailed`, `graphNoPrerequisite`, `mapMarkerOffTrail`)
- CREATE `Packages/Core/Sources/Core/Time/CalendarDay.swift` — calendar-day type with no `Date()` calls; immutable day string wrapper or value type; used by mastery transitions to track `next_due` and `last_probe`
- CREATE `Packages/Core/Sources/Core/State/MasteryTransitions.swift` (or similar) — mastery state machine implementation with ladder `[1, 3, 7, 14, 30]`, transitions for `item_correct`, `item_miss`, `diagnosis_blocked`; clearing requires distinct items checked via `probe_log`
- CREATE `Packages/Core/Sources/Core/Events/CoreEvent.swift` (or similar) — value type with notification names from contract §5; subset relevant to this task's transitions (expedition, diagnosis, node_cleared, node_blocked, etc.)
- CREATE `Tests/CoreTests/Support/PropertyGen.swift` — seeded property-test support extending `SeededGenerator`; deterministic test-data generators for `StudentState`, nodes, mastery transitions
- MODIFY `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift` — test already exists (verified by read); no changes needed if negative control stays (off-registry case still fails)
- CREATE `Tests/CoreTests/MasteryTransitionsTests.swift` — properties: mastery transitions respect the state machine; clear rule requires distinct items; ladder advances on review; missed review resets rung; fog never returns; every transition emits the correct event
- CREATE `Tests/CoreTests/CalendarDayTests.swift` — calendar-day arithmetic; ladder day selection; no `Date()` usage; day comparison

Files confirmed absent (Glob checks):

- `Packages/Core/Sources/Core/Time/` — confirmed absent
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift` — confirmed absent
- `Packages/Core/Sources/Core/Events/CoreEvent.swift` — confirmed absent
- `Tests/CoreTests/Support/PropertyGen.swift` — confirmed absent

## §G. Stack constraints relevant here

- **Boundary validation**: every `CoreError` case must be present in `contracts/error-codes.json` (registry round-trip); the test `ErrorRegistryTests` asserts this.
- **Error codes to use**: R-6 set only — `EXP_NO_FRINGE`, `EXP_TRAIL_INVALID`, `EXP_ITEM_POOL_EMPTY`, `EXP_STATE_WRITE_FAILED`, `EXP_NODE_NOT_IN_GRAPH`, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`, `DIAG_STATE_WRITE_FAILED`, `GRAPH_NO_PREREQUISITE`, `MAP_MARKER_OFF_TRAIL` — all registered in `contracts/error-codes.json:11-25` — Source: `contracts/error-codes.json` entries quoted in §B above.
- **Language and imports**: Swift 6 strict concurrency in `Packages/Core`; `Core` imports Foundation only (I14); asserted by `CoreTests` import-boundary test. Source: `docs/tech-stack.md:17` ("Shared logic … Foundation only") and `CLAUDE.md` I14.
- **Testing framework**: Swift Testing (`import Testing`) for `CoreTests`. Source: `docs/tech-stack.md:22`.
- **Deployment target**: iOS 18.0, macOS 15.0. Source: `docs/tech-stack.md:16` and `Packages/Core/Package.swift:9-12`.
- **Test targets in Package.swift**: `.testTarget(name: "CoreTests", dependencies: ["Core"])` exists. Source: `Packages/Core/Package.swift:26-29`.
- **Gates**: §3 of `docs/tech-stack.md` lists four gates: (1) Format + lint; (2) Typecheck (`pyright` for pipeline only); (3) Core: `swift build -c release --product core-cli` + `xcodebuild test -scheme Core-Package` on iOS simulator; (4) App + pipeline. This task's code is gated by Core gate. Source: `docs/tech-stack.md:69-80`.
- **No time estimates**: I11 binds all docs. No time estimates are permitted in this task spec or its output.
- **Precondition**: Task 02.2 (data-model contract bump) must be completed and merged before this task's code can be finalized. Task 02.2 adds `remediated: Bool?` to `NodeState` and `past_last_unit: Bool?` to `Marker`. Source: `docs/plans/epic-02-plan.md:17` and `tasks/arbitration/arbiter-02-predispatch.md:16`.
- **Arbiter rulings affecting downstream**: Q-A (remediated flag) and Q-F (past_last_unit flag) land in task 02.2 but affect this task's understanding of `StudentState` structure. Q-D rules `MAP_MARKER_OFF_TRAIL` is returned as data by `Core` (task 02.5); task 02.4 adds it to `CoreError` and tests should not rely on it being raised yet. Source: `tasks/arbitration/arbiter-02-predispatch.md:12-25`.

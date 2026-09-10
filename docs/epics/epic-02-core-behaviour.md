# EPIC 02: Core behaviour

> Status: brief authored 2026-09-10 by epic-scoper. Owner decides dispatch; planner decomposes.

## 1. EPIC id, title, category
EPIC 02 — Core behaviour. Category: Feature.

## 2. Goal & scope
Give `Core` the product's behaviour. Today it can only decode, validate and lay out a bundle. After this
EPIC it can also run all three doors' state machines as pure functions over `StudentState` and a loaded
bundle, so EPICs 03/04 only render and call. **Dominant domain: expedition.** Diagnosis (Door A machine)
and platform (Q3 merge only) are the secondary domains. In scope, sliced at the domain docs' own seams:

- **Mastery transitions** — `contracts/interaction-contract.md` §1. This covers the clear rule on distinct
  items (expedition Q1) and the ladder `[1, 3, 7, 14, 30]` days, where the last rung repeats
  [ESTIMATE: expedition Q2]. It is expedition W4.
- **Marker and trail** — §3, expedition W6 + W8. `set_marker(course, unit)`, the default marker, and
  `generate_trail` with the D47 extension segment. The extension prefers `next_courses[]`, then
  undergraduate nodes when they exist. The runtime **L0-T** segment check comes from
  `contracts/graph-constraints.md`, as rewritten per the owner's Q-E ruling (§9 Q-E; the contract bump is
  task 02.3).
- **Fringe and compose** — §2 `compose`, expedition W1. This is the D48 fringe within `marker.unit ∪
  next(marker.unit)`. A unit expedition (D46) narrows it to one unit. The map-queued node goes first (map
  Q5). Next come fringe nodes in trail order, then **≤ 2 review slots** from due cleared nodes, up to 5
  slots (expedition Q3). The per-slot `ProbeItem` draw prefers unused items. `EXP_NO_FRINGE` and
  `EXP_ITEM_POOL_EMPTY` are raised here.
- **Expedition run machine** — §2 `answer`, tolerance, `end`; expedition W2, W3, W5. Checking is
  deterministic: numeric by normalised exact match within a per-item tolerance (expedition Q4), `mc` by
  choice id. The answer and `why` are always part of the result (I3). The D27 tolerance rule applies (one
  retry, at most one diagnosis per run; later second misses → `blocked`, expedition Q5). The machine also
  covers the summary, the `expedition_log` / `probe_log` entries, and `abandoned` (expedition Q6).
- **Diagnosis machine** — §4, diagnosis W1–W6. The distractor-tag `classify` lookup (diagnosis Q1, Tier 0
  only) comes first. Next is the **deepest-unmastered-prerequisite query** (concept-graph W3 under
  `graph-constraints.md` § Query rules: breadth-first, ≤ 2 levels, `fog` is a candidate, ties broken per
  concept-graph Q3), biased by `implies_prerequisite`. The probe is declinable (diagnosis Q2), and
  `refuted` / `confirmed` / `unconfirmed` / `capped` each have a remediation or hint outcome. A second
  level is offered, never automatic (diagnosis Q3). The budget is a parameter (2; Demo 1). `returned`
  hands back to the suspended expedition or the map node panel. The two triggers are
  `expedition_second_miss` and `map_check_here` (diagnosis Q4).
- **State merge** — platform Q3 / W4 step 2 only. A pure `Core` function over two `StudentState`s. The
  iCloud mechanism is EPIC 10.
- **Load-time state reconciliation** — expedition W7 (the `Core` half only). State ids absent from the
  bundle are kept but ignored (`EXP_NODE_NOT_IN_GRAPH`).
- **`CoreError`** — extend the EPIC 01 enum so it mirrors every `EXP_*`, `DIAG_*`, `GRAPH_*` code and the
  `MAP_*` codes `Core` raises (`contracts/error-codes.md` § Rules). The enum stays ⊆ the registry.

This EPIC **builds on EPIC 01 and does not re-create anything**. The following already exist in
`Packages/Core/Sources/Core/`: the `StudentState` family of `Codable` types (`Model/StudentState.swift`:
`Marker`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `SegmentKind`, `ExpeditionLogEntry`,
`ProbeLogEntry`), the bundle types (`Model/*.swift`: `ProbeItem`, `ErrorType`, `WrongAnswer`,
`ProbeChoice`, courses/units/`next_courses`, edges with `confidence`), `CoreError` (`CoreError.swift`), the
single wire coder (`CoreCoding.swift`), `GraphIndex` / `L0Checker`, and `ErrorRegistryTests`. This EPIC
adds behaviour over those types and extends them only where §3 records a `BUMP`.

**MANDATORY placement line:** milestone **Demo**, run under D26 on the hand-written `data/demo` bundle,
with the M3 behaviour identical and only the data replaced. Layer **④ interaction** (all three doors'
state machines). It reads layers ① (units, `next_courses`), ② (edges, confidence, regions) and ③ (probe
items, distractor tags, hints, explanations) as read-only inputs.

## 3. Contracts it must conform to
- `contracts/interaction-contract.md` (v0.9.0, discovery zone). §1 Mastery, §2 Expedition (Door B, including
  **Properties (CoreTests)**), §3 Marker and trail, §4 Diagnosis (Door A, including **Properties
  (CoreTests)**), and §5 Notifications (exact in-process names for every event these transitions emit).
  - **READ-ONLY** for §1–§5 behaviour.
  - **BUMP** for § *Finalization owed by the Demo EPIC*, first item, "exact item-normalisation rules for
    numeric answers". This EPIC implements the checker, so it must fix those rules. The planner emits a
    contract-bump task that writes them into §2 (v0.9.x). The remaining finalization items (marker
    unit-boundary snap, answer-card timing, summary tint deltas) are UI and belong to EPICs 03/04. The
    v1.0.0 bump happens at Demo wrap (EPIC 04), not here.
  - The same bump task (02.1) also lands the arbiter's normative §1/§2/§3/§4 text for Q-A (`remediated`),
    Q-F (`past_last_unit`) and Q-G (probe item availability) verbatim from
    `tasks/arbitration/arbiter-02-predispatch.md`. That text realises existing rules and does not change
    §1–§5 behaviour.
- `contracts/graph-constraints.md` (v1.0.0), § L0-T (trail segments) and § *Query rules (also `Core`)*.
  - § *Query rules*: `READ-ONLY`. The query walks ≤ 2 levels breadth-first, treats `fog` as a candidate and
    uses the confidence → depth → id tie-break.
  - § L0-T: **BUMP**, per the owner's Q5 ruling on Q-E (`tasks/blocked/Q5-RULING-02-QE.md`, option A). The
    bump is a versioned contract task, 02.3, route a. The rewritten row says three things:
    - A **course segment** is exactly that course's nodes resident in the bundle, ordered by unit order,
      then topologically by the graph within each unit, with ties broken by node id.
    - An edge running against unit order is **reported (warning)**, not a failure.
    - Every **extension-segment** node is reachable in the graph from the segment before it.

    L0-T stays "the same `Core` function; runs at generation". **`data/demo` is not changed.** The matching
    rewrite of `CLAUDE.md` I8 is not a deliverable of this EPIC's brief.
- `contracts/data-model.md` (v1.2.0).
  - § StudentState, § Time (calendar days only, device-local), § Nulls, enums, unknowns (optional =
    absent), § ProbeItem (`answer.value` / `tolerance`, `wrong_answers[].error_type_id`,
    `choices[].error_type_id`, `correct_choice_id`), and `contracts/schemas/student-state.schema.json`:
    **READ-ONLY** by default.
  - **BUMPs, ruled by the spec-arbiter (`tasks/arbitration/arbiter-02-predispatch.md`; see §9 Q-A, Q-B and
    Q-F).** (a) The §2 fringe guard uses `remediated(p)`, but `NodeState` has no field that records it.
    (b) Platform Q3 says "logs are unioned by entry id; the marker takes the latest write", but
    `expedition_log[]` / `probe_log[]` entries have no id and the state has no write time. (c) Nothing
    represents "the marker is past the course's last unit". The rulings land as:
    - **v1.3.0 (task 02.2):** optional boolean `remediated` on the node entry (Q-A) and optional boolean
      `past_last_unit` on `marker` (Q-F). `schema_version` becomes 2, with an identity migration from 1.
      The schema, the example and the `Core` types change with it.
    - **v1.4.0 (task 02.9):** a new § StudentState merge subsection (Q-B).

    A contract change to a LOCK-FIRST schema is versioned (`contracts/README.md` § Lock-first rule) and gets
    its own contract-bump task. It is never silently reconciled in code.
- `contracts/error-codes.md` + `error-codes.json` (v1.0.0), § Rules: "`Core` defines `enum CoreError:
  String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG` codes". `READ-ONLY`. Additive
  registration needs no bump, but none is needed (see the R-6 line).
- `contracts/domain-glossary.md`: Fringe (never "frontier"), Slot / new-learning slot / review slot, Unit
  expedition, Course-progress marker (`marker`; never "start marker"), Trail / course segment / extension,
  Diagnosis event (never "session"/"attempt"), Blocked, Due. `READ-ONLY`. The wrap-epic (f) banned-synonym
  grep applies to new type and function names.
- `contracts/runtime-tiers.md` / `contracts/ai-usage.md`: no model and no adapter in `Core`. The Tier 1
  "suggest" input of §4 `classify` is **not** built here (EPIC 13). `READ-ONLY`.
- `contracts/telemetry.md`: no telemetry code here. `probe_log` / `expedition_log` stay within
  the schema's closed key set. `READ-ONLY`.

**MANDATORY (R-6) brief-checklist line — startup-failure guard set.** These are the config- and
registry-bearing inputs in scope, each checked against `contracts/error-codes.json`:
- **Error registry.** `CoreError` ⊆ registry, via the existing `ErrorRegistryTests` + negative control.
  After this EPIC the enum must carry `EXP_NO_FRINGE`, `EXP_TRAIL_INVALID`, `EXP_ITEM_POOL_EMPTY`,
  `EXP_STATE_WRITE_FAILED`, `EXP_NODE_NOT_IN_GRAPH`, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`,
  `DIAG_STATE_WRITE_FAILED`, `GRAPH_NO_PREREQUISITE` and `MAP_MARKER_OFF_TRAIL`. **All are registered** →
  `READ-ONLY`. The EPIC 01 cases `GRAPH_L0_FAILED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`,
  `MAP_LANDMARK_UNSOURCED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED` and
  `PLATFORM_BUNDLE_INTEGRITY_FAILED` stay (registered, `READ-ONLY`).
- **Bundle input** to every transition. `GRAPH_L0_FAILED` / `PLATFORM_BUNDLE_INTEGRITY_FAILED`, both
  registered, `READ-ONLY`. The behaviour functions accept only a bundle that has passed L0 (EPIC 01's
  `validate`). They do not re-validate it.
- **Persisted `StudentState` vs the installed bundle** (expedition W7). Unknown node ids →
  `EXP_NODE_NOT_IN_GRAPH`, registered, `READ-ONLY`. A marker naming a course or unit absent from the
  bundle or from `syllabi[]` → `MAP_MARKER_OFF_TRAIL` with the marker falling back to its default. That
  code is registered, so this is `READ-ONLY` (see §9 Q-D).
- **Generated trail.** `EXP_TRAIL_INVALID`, registered, `READ-ONLY`.
- **Scheduler / ladder / backtrack-budget constants.** These are contract constants
  (interaction-contract §1, §2, §4), not runtime-loaded configuration. This EPIC has no config file and
  therefore no config-invalid code to register.

**No BUMP to `error-codes.json` is needed.**

**MANDATORY invariant line:**
- **I1 / I10.** Item checking is code over `answer` / `correct_choice_id` only. The checker's inputs are a
  `ProbeItem` and a numeric string or a choice id, and no free-text path exists. A property test covers
  every `data/demo` item: its own `answer.value` (or `correct_choice_id`) checks correct, and each tagged
  wrong answer / distractor checks incorrect. `Core` imports no model framework (the import-boundary test
  guards this).
- **I2.** Every expedition and diagnosis path completes with no adapter and no suggestion input.
  `classify` is a pure distractor-tag lookup that returns `none_of_these` when nothing matches, and the
  hypothesis comes only from the graph query. A test drives every diagnosis terminal (`refuted`,
  `confirmed`, `unconfirmed` both by decline and by `DIAG_PROBE_UNAVAILABLE`, `capped`,
  `DIAG_NO_PREREQUISITE`) Tier 0 only.
- **I3.** Every `answer` transition's result carries the correct answer and `why` before any next-item
  state is reachable. A property test asserts this for every item shown, including retry, probe and review
  items.
- **I4.** The query's level cap is a parameter of the query, not of the caller (concept-graph I4). The
  budget is checked before any probe or remediation exists. A property test asserts depth ≤ 2 from the
  origin (≤ 1 in the Demo configuration) and that every capped or failed candidate is `blocked` in the
  resulting state. There is no other record: the map is the record (v2.5 §3).
- **I5.** No field is added to `StudentState` except by a §3 `BUMP`. Any added field is a boolean or a
  day, never an id of a person, device, install or session. The merge introduces no identifier. The
  existing `IdentifierBlocklistParityTests` and the schema's closed key set stay green.
- **I7 / I8.** The trail is generated from `syllabi[]` + marker + mastery, never authored. Every segment
  passes L0-T (as rewritten per §9 Q-E) or `EXP_TRAIL_INVALID` is raised and the previous trail stands (a
  test covers this).
- **I14.** All functions are pure `Core` functions over values. "Today" is an injected calendar-day input;
  there is no clock read in `Core`, and a grep for `Date()` over `Sources/Core` stays at zero hits. No
  `import` beyond Foundation (the recursive boundary test).
- **D27** is a property: at most one diagnosis event per run and at most one retry per node per run.

**MANDATORY artifact line (P4/C4):**
- The **`Core` library**, exercised by `xcodebuild test -scheme Core-Package` (gate (d)). This covers the
  new property tests for every §1–§4 property, the `CoreError` ⊆ registry test extended to the new cases,
  the two C1 seam tests (§4 items 7–8), the state-merge laws, and the demo-bundle scenario tests run
  against the real `data/demo`.
- The **App build** (`xcodebuild build -scheme mathmath`) stays green but gains no code.
- **`core-cli`** gains no subcommand. It must still build, because the pipeline seam test from EPIC 01
  exercises it.
- **Contract artefacts**, each landed by its contract-bump task under a `contract(<name>)` commit scope:
  - the interaction-contract §2 numeric-normalisation text, plus the arbiter-ruled §1–§4 text (task 02.1);
  - the data-model v1.3.0 bump for Q-A + Q-F (task 02.2) and the v1.4.0 bump for Q-B (task 02.9);
  - the graph-constraints L0-T rewrite for Q-E (task 02.3).

## 4. Acceptance criteria
1. **§1 transitions.** Two correct answers on **distinct** items clear a `fog` or `blocked` node, set
   `ladder_rung = 0` and `next_due = today + 1`, remove `remediated` (§9 Q-A), and emit
   `expedition.node_cleared`. The same item answered correctly twice does not clear the node. For a
   cleared node, a correct review advances the rung, and the rung caps at 4 with the last interval
   repeating. A missed review resets to rung 0 / `today + 1` and the node stays `cleared`, so fog never
   returns. `diagnosis_blocked` moves `fog → blocked`.
2. **§3 marker → trail.**
   - With `syllabi = [MTH1W]` and the default marker, `generate_trail` over `data/demo` produces a course
     segment holding **exactly** MTH1W's nodes resident in the bundle. They are ordered by unit order, then
     topologically by the graph within each unit, with ties broken by node id. The segment passes L0-T as
     rewritten per §9 Q-E.
   - The MTH1W edge `solving-linear-equations` (u3) → `exponent-laws` (u2) runs against unit order. It is
     reported as a warning and does not fail the segment.
   - After `set_marker` moves the marker, the trail is regenerated and the fringe recomputed, and nodes now
     upstream keep their mastery.
   - With the marker past the course's last unit (`marker.past_last_unit == true`, §9 Q-F), the result
     carries a `kind: extension` segment. Every node in it is reachable in the graph from the segment
     before it. The positive case runs on an in-memory bundle derived from `data/demo`, because `data/demo`
     has no `next_courses` target present (§9 Q-G, test-data rule).
   - With no downstream-course node present, the result carries no extension segment.
   - A segment that fails L0-T raises `EXP_TRAIL_INVALID` and the previous trail is returned unchanged.
3. **§2 compose.** Across generated states and markers (property tests):
   - no new-learning slot is ever drawn from a node off the fringe or upstream of the marker unless that
     node is `blocked`;
   - a prerequisite satisfies the fringe guard only if it is `cleared`, or `blocked` with `remediated ==
     true` (§9 Q-A);
   - there are never more than 5 slots and never more than 2 review slots;
   - review slots are due cleared nodes, oldest `last_probe` first;
   - a map-queued node on the fringe takes slot 1, and a queued node upstream of the marker is ignored;
   - a unit expedition draws only from its unit (plus `blocked` nodes);
   - an empty fringe with an empty due set raises `EXP_NO_FRINGE`;
   - a fringe node with no available item is skipped with `EXP_ITEM_POOL_EMPTY`.
4. **§2 run and D27.**
   - Every `data/demo` item checks correct on its own answer and incorrect on each tagged wrong answer or
     distractor, under the normalisation rules landed in interaction-contract §2 (for example `3/4` =
     `0.75`, whitespace, leading zeros, per-item tolerance).
   - A first miss on a node yields a retry on a different item of that node. A second miss with the Door
     A event unused yields `expedition.diagnosis_requested`. A second miss after the event was used marks
     the node `blocked` and continues.
   - Property: at most one diagnosis event per run.
   - A run ended mid-way appends an `expedition_log` entry with `abandoned: true`.
   - Every answered item appends a `probe_log` entry with day granularity.
5. **§4 diagnosis.** Property tests over generated graphs and states cover the following:
   - depth ≤ budget ≤ 2 from the origin;
   - no path reaches remediation without a `fail` probe outcome;
   - every `capped` or `confirmed` candidate is `blocked` in the output state. A `confirmed` candidate
     carries `remediated = true` once its remediation piece is shown; a `capped` candidate does not (§9 Q-A);
   - a second level is entered only on an explicit accept;
   - fewer than 2 **available** items on the candidate → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item
     is available unless its answer was already shown in the current run (§9 Q-G);
   - no candidate → `DIAG_NO_PREREQUISITE` → hint → `returned`;
   - declining → `unconfirmed` → hint → `returned`;
   - the query tie-break (highest confidence, then lowest depth, then node id) holds on constructed ties;
   - every path terminates in `returned`.
6. **Tier 0 completeness (I2).** Each diagnosis terminal is reached with no adapter and no suggestion
   input, over `data/demo` with the Demo budget of 1. The `DIAG_PROBE_UNAVAILABLE` terminal is reached on the
   real `data/demo` with the constructed `StudentState` of §9 Q-G. Only the state is constructed; the bundle
   is not substituted.
7. **C1 seam: expedition ↔ diagnosis.** A test drives a real expedition run on `data/demo` to a second
   miss. It opens a **real** diagnosis event from the emitted `diagnosis_requested`, drives it to
   `returned`, and resumes the **same** run at its next item. It asserts: the run's diagnosis count = 1; the
   blocked candidate is visible to the resumed run's state; the answered items' answers remain present;
   neither side is stubbed.
8. **C1 seam: marker → trail → fringe.** A test sets the marker on real `data/demo` state, generates the
   trail and composes an expedition from that trail. It asserts that the composed new-learning slots ⊆
   the fringe computed from that trail and marker, with no stubbed trail and no hand-built fringe.
9. **Merge (platform Q3).** `merge` is commutative, idempotent, and never lowers mastery (`cleared` >
   `blocked` > `fog`). `correct_count` is the max, and `last_probe` / `next_due` are the latest. Logs and
   the marker merge per the rule landed under §9 Q-B (`contracts/data-model.md` v1.4.0 § StudentState
   merge, task 02.9). The law tests compare logs in canonical order. Property tests cover all of these over
   generated pairs.
10. **`CoreError` ⊆ registry** is green with every code named in the §3 R-6 line, and the existing
    negative control still fails an off-registry case. `scripts/gate.sh` is green.

## 5. Conformance tests it must ship (B.1)
- **expedition** (§ Invariants enforced here):
  - I1/I2: checking is code over `answer` / `choice` fields; no free-text answer path.
  - I3: every item result carries the answer and `why`.
  - I4 co-owner: no new-learning item off the fringe or upstream of the marker unless `blocked`.
  - I5: `StudentState` closed field set; the existing parity test is extended if a BUMP adds a field.
  - I10: `numeric | mc` only.
  - I14: pure functions; import boundary.
  - I7/I8: generated trail; L0-T on every segment.
  - D27: one retry, one Door A event per run, as properties of W3.
- **diagnosis** (§ Invariants enforced here):
  - I2: every workflow runs with the adapter absent.
  - I4 primary: budget checked before any probe or remediation; none beyond depth 2; every capped
    candidate reaches `StudentState` as `blocked`.
  - I3: no terminal path gates an already-given answer.
  - I1/I10: probe items checked in code.
  - I5: outcome data is ids, enums and booleans only.
- **concept-graph** (§ Invariants enforced here, W3 half): I4, the 2-level cap is a parameter of the query;
  I2, no model in the query path; deterministic tie-break (Q3).
- **platform** (§ Invariants enforced here, merge half): I14, the merge is a `Core` function over opaque
  `StudentState` values; I5, the merge adds no identifier.
- **Contract rungs marked EPIC-time** (`contracts/README.md`):
  - interaction-contract: "state-machine property tests in `CoreTests`" — every **Properties
    (CoreTests)** bullet of §2 and §4, plus the §1 clear and ladder rules and §3 L0-T.
  - error-codes: "`Core` error enum mirrors the registry" — `CoreError` ⊆ registry, extended.

## 6. Dependencies on prior EPICs
- **EPIC 01** (merged, `docs/audits/epic-01-acceptance.md`). It supplies the `Core` `Codable` types
  including `StudentState`, `CoreError` + `ErrorRegistryTests`, `GraphIndex` / L0 (the input-validity
  precondition), and the `data/demo` bundle with 20 nodes, 40 items, 19 edges, MTH1W + MCR3U with units and
  `next_courses` [SOURCED: docs/audits/epic-01-acceptance.md §2].
- The domain order holds: node/edge schema and L0 before the graph query; the graph query before
  backtracking; the Tier-0 flow before any Tier-1 adapter (EPIC 13). The map is the record (v2.5 §3), so
  this EPIC ships the state it reads and EPIC 03 renders it.
- No dependency on EPICs 05–09 (pipeline) or 10–11 (hosting, sync, telemetry).

## 7. Out of scope
1. **Any App / SwiftUI / `Canvas` code, JSON persistence to Application Support, launch-time load** —
   EPIC 03 (map, platform launch/persistence). The `*_STATE_WRITE_FAILED` codes are mirrored in
   `CoreError` but raised by the App's persistence layer there.
2. **Expedition, answer-card, hypothesis-card, probe and remediation screens** — EPIC 04. So are the
   remaining interaction-contract finalization items (marker snap, answer-card timing, summary tint
   deltas) and the v1.0.0 bump.
3. **iCloud sync mechanism** (platform W4 steps 1 and 3, platform Q1) — EPIC 10. Only the pure merge
   function is here.
4. **Tier 1 `classify` suggestion and the optional "what did you do?" line** (diagnosis Q1, Tier 1 half;
   runtime-tiers) — EPIC 13, M4, gated on M4′. DEFERRED D-2 (Tier 2) is untouched.
5. **Local `ProbeStats` / edge-confidence update from probe runs** (concept-graph W4) and all telemetry
   event derivation — EPIC 11 (D17, D40). Edges stay immutable bundle data here.
6. **Homework-mode diagnosis variant** (`homework_first_failure` trigger, CAS step verdicts) — DEFERRED
   D-4, revisit trigger "M5 scope", which has not fired. No CAS on the device (D34).
7. **Hand-specified `upstream_hint` diagnosis for the Demo** (DEMO-BRIEF §3.6, diagnosis W2 step 2) — no
   such field exists in the locked `nodes.schema.json`. The Demo candidate comes from the contract's graph
   query with budget 1 (§9 Q-C).
8. **Additional syllabi as trails** (DEFERRED D-11, trigger: undergraduate nodes exist), the **shore
   region** (D-10, trigger M5) and the **ideas layer** (D-9, trigger: Demo observations). None has fired.
   The extension's "then undergraduate nodes" branch is implemented but has no demo data to walk.
9. **Game Center, streak UI, leaderboards** — DEFERRED D-7. Streaks emerge from the state, and no feature
   is built for them.
10. **Live-landmark-test transport-retry fix** recommended in `docs/audits/epic-01-acceptance.md` §7 —
    pipeline-side and not `Core` behaviour. It enters only if CI flakes during this EPIC, as a separate
    `fix(pipeline)` task outside the 8-task count.

## 8. Size estimate
The feature scope is **8 tasks** [ESTIMATE: planner may re-cut], at the cap:
1. `CoreError` extension + registry test, and the injected calendar-day type with ladder arithmetic.
2. §1 mastery transitions + properties.
3. §3 marker, default marker, `generate_trail` with extension, L0-T + properties.
4. Fringe + `compose` (slots, review quota, unit expedition, map-queued node, item draw) + properties +
   **C1 marker→trail→fringe seam**.
5. Expedition run machine: numeric/mc checking, D27 tolerance, end/summary/log/abandoned, W7 load
   reconciliation + properties.
6. The deepest-unmastered-prerequisite query (graph-constraints § Query rules) + distractor-tag
   `classify`.
7. Diagnosis machine §4 (open → hypothesis → probe/hint → remediation/hint → returned, capped, budget,
   offered second level) + properties + the Tier-0 completeness suite + **C1 expedition↔diagnosis seam**.
8. `merge` + algebraic-law properties.

There are **up to three contract-bump tasks** on top: interaction-contract numeric normalisation (certain),
and the data-model Q-A and Q-B bumps if the arbiter rules for them. **If they push the plan over the cap,
split at the brief's seam.**
- **02a — "Door B core"**: tasks 1–5 + the normalisation bump. This is expedition W1–W8 and seam 8.
- **02b — "Door A core + merge"**: tasks 6–8 + the Q-A/Q-B bumps. This is diagnosis W1–W6, platform Q3
  and seam 7. It depends on 02a for the suspended-run hand-off. Q-A's `remediated` guard touches task 4,
  so if Q-A lands in 02b, task 4's fringe guard is re-verified there.

**Split taken** (planner, 2026-09-10; `docs/plans/epic-02-plan.md`, `docs/epic-plan.md` § EPIC 02 split).
The planner cut 11 tasks + 2 wraps, with one id space. Scope is unchanged. The contract-bump tasks number
four, because the Q-E ruling adds the L0-T rewrite.
- **02a — Door B core**, tasks 02.1–02.8, branch `epic-02-core-behaviour`:
  - contract bumps 02.1 (interaction-contract), 02.2 (data-model v1.3.0, Q-A + Q-F) and 02.3
    (graph-constraints L0-T, Q-E);
  - implementation 02.4–02.7 (brief tasks 1–5);
  - wrap 02.8 (`docs/audits/epic-02a-acceptance.md`).
- **02b — Door A core + merge**, tasks 02.9–02.13, branch `epic-02b-door-a-core-merge`:
  - contract bump 02.9 (data-model v1.4.0, Q-B);
  - implementation 02.10–02.12 (brief tasks 6–8);
  - wrap 02.13 (`docs/audits/epic-02-acceptance.md`, tracing §4 items 1–10).

Q-A lands in 02a (02.2), before the fringe task 02.6. The "re-verified in 02b" clause above therefore
does not fire.

Seams (C1) added: expedition↔diagnosis and marker→trail→fringe. No other cross-module seam is crossed.

## 9. Open questions
All of Q-A … Q-G are **resolved** (2026-09-10). The pre-dispatch arbiter rulings are in
`tasks/arbitration/arbiter-02-predispatch.md`. The owner's Q5 ruling on Q-E is in
`tasks/blocked/Q5-RULING-02-QE.md`. The entries below keep their original analysis.
- **Q-A (Q4 → spec-arbiter; BUMP candidate on `contracts/data-model.md` + `student-state.schema.json`).**
  - **RESOLVED.** The arbiter adopted the default (arbiter-02-predispatch § Q-A).
    - Optional boolean `remediated` on the node entry, absent = false, in data-model v1.3.0 with
      `schema_version` 2 and an identity migration (task 02.2).
    - It is set `true` only by diagnosis W4's remediation step, on a `blocked` node, and removed on
      `cleared`. The merge is OR, then removed unless merged `mastery` is `blocked`.
    - The interaction-contract §1/§2/§4 text lands in task 02.1: `remediated(p)` ≡ `nodes[p].remediated ==
      true`.
  - **The conflict.** Interaction-contract §2's fringe guard admits a prerequisite that is `blocked ∧
    remediated(p)`, but `NodeState` records no remediation. Blocked arises three ways: confirmed and
    remediated (diagnosis W4); capped with no remediation (W6); spent-Door-A second miss with no
    remediation (expedition Q5). These are indistinguishable in the current schema.
  - **Default:** add one optional boolean on the node entry (absent = false). It is set only by diagnosis
    W4's remediation step, cleared on `cleared`, and merged by logical OR. This is a versioned
    data-model / schema change with `schema_version` migration handled forward (platform W3). It adds no
    identifier (I5).
  - **Alternative the arbiter may choose instead:** read §2 so that no blocked prerequisite satisfies the
    guard. This changes contract semantics and is itself a contract edit.
  - **Revisit trigger:** the arbiter's ruling, before task 4 is specified.
- **Q-B (Q4 → spec-arbiter; BUMP candidate or merge-rule clarification).**
  - **RESOLVED.** The arbiter adopted the default and completed it (arbiter-02-predispatch § Q-B). It lands
    as a new `contracts/data-model.md` § StudentState merge (v1.4.0, task 02.9):
    - Logs merge as a multiset union by full value (max multiplicity) in canonical order.
    - `marker`, `syllabi` and `trail` come from the winning side: latest log day, then marker further
      along (`past_last_unit` ranks above any unit), then greater `course_code`, then canonical-JSON
      byte order.
    - `install_day` takes the earlier value, `format_version_seen` the higher, and `consent_on` is the
      AND of both sides.
    - The law tests compare through canonicalisation, with a sum-multiplicity negative control (task
      02.12).
    - No identifier is added (I5).
  - **The conflict.** Platform Q3 (ratified) says "logs are unioned by entry id; the marker takes the
    latest write". The schema gives log entries no id and the state no write time. Adding a per-run id
    risks reading as a session id (I5).
  - **Default, with no schema change:** logs merge as a **multiset union by full-value equality** (for
    each distinct entry, keep the max multiplicity seen on either side). The marker is taken from the side
    whose latest `expedition_log.day` / `probe_log.day` is later. Ties go to the marker further along the
    course's unit order, then course code. The rule is recorded in the merge's contract home by a
    contract-bump task.
  - **Revisit trigger:** EPIC 10 (sync), if real conflicts show lost runs.
- **Q-C (Q1, answered from the ground-truth order: contracts > domain docs).**
  - **RESOLVED — CONFIRMED** (arbiter-02-predispatch § Q-C). There is no `upstream_hint`. The Demo
    candidate is the graph query with budget 1 (tasks 02.10, 02.11).
  - **The conflict.** Diagnosis W2 step 2 and DEMO-BRIEF §3.6 name a hand-specified `upstream_hint` for
    the Demo. The locked `nodes.schema.json` has no such field (EPIC 01 shipped without it), and
    interaction-contract §4 + graph-constraints § Query rules define the candidate as the graph query.
  - **Default:** the Demo uses the contract query with budget 1. `data/demo`'s hand-written edges make it
    deterministic, which serves the same purpose. No field is added.
  - **Revisit trigger:** EPIC 04 acceptance, if a Demo scenario needs a candidate the edges do not yield
    (then it is a data fix in `data/demo`, D26).
- **Q-D (Q1).**
  - **RESOLVED — CONFIRMED with a caveat** (arbiter-02-predispatch § Q-D). Task 02.5's W7 reconciliation
    returns `MAP_MARKER_OFF_TRAIL` as data, together with the default marker; `Core` surfaces no text.
    - **Default marker:** the first unit of the first course in `syllabi[]` that exists in the bundle.
    - **No resolvable course:** keep the stored marker and produce an empty trail.
    - **Off the trail** means `course_code ∉ syllabi[]`, or the course is absent from the bundle, or
      `unit_id` is not one of that course's units.
    - **Caveat:** the registry `user_text` does not fit this load path. That is owed to EPIC 03, not this
      EPIC, and no code is added here.
  - **The situation.** A persisted marker names a unit absent from the bundle or from `syllabi[]`.
  - **Default:** raise `MAP_MARKER_OFF_TRAIL` (registered) and fall back to the default marker (first unit
    of the first selected course, D45). Mastery is untouched.
  - **Revisit trigger:** EPIC 10 content refresh changing unit ids. If the arbiter prefers a dedicated
    `EXP_*` code, that is additive registration with no version bump.
- **Q-E (Q4 risk to verify in task 3, not a known conflict).**
  - **RESOLVED by owner Q5 ruling, option A** (`tasks/blocked/Q5-RULING-02-QE.md`). The arbiter confirmed a
    structural conflict and escalated it (arbiter-02-predispatch § Q-E, `tasks/blocked/blocked-arbiter-02-03.md`,
    `docs/blocked/run-stop-02-qe-trail-path.md`). The ruling:
    - A course segment is exactly that course's nodes resident in the bundle, ordered by unit order, then
      topologically by the graph within each unit, with ties broken by node id.
    - An edge against unit order is reported as a warning, not a failure.
    - Every extension-segment node is reachable in the graph from the segment before it.
    - L0-T in `contracts/graph-constraints.md` is rewritten by the versioned bump in task 02.3 (route a),
      and `CLAUDE.md` I8 wording is rewritten to match.
    - `data/demo` is not changed.
    - §3, §4 criterion 2 and the I7/I8 line above are amended accordingly.
  - **The risk.** L0-T requires "every segment's `node_ids[]` is a directed path in the graph", and
    `data/demo`'s MTH1W / MCR3U node sets in unit order may not be Hamiltonian paths over the 19 demo
    edges.
  - **Default:** the contract reading stands. If a demo course fails, the task records the failing course
    and escalates to the spec-arbiter. The candidate remedies are a `data/demo` edge fix (hand-written Demo
    data, D26, re-validated by L0) or an L0-T clarification (contract bump). Code does not silently accept
    a non-path.
  - **Revisit trigger:** the first `generate_trail` run over `data/demo` in task 3.
- **Q-F (raised by the arbiter pre-dispatch).**
  - **The situation.** Nothing in `StudentState` represents "marker past the course's last unit"
    (interaction-contract §3, v2.7 §4).
  - **RESOLVED** (arbiter-02-predispatch § Q-F). An optional boolean `past_last_unit` on `marker`, absent =
    false, lands in data-model v1.3.0 (task 02.2). There is no sentinel `unit_id`. While it is `true`:
    - `unit_id` names the course's last unit;
    - the §2 `compose` window is the extension segment's nodes;
    - the course's nodes are upstream of the marker.

    The interaction-contract §3 text lands in task 02.1.
- **Q-G (raised by the arbiter pre-dispatch).**
  - **The situation.** Every `data/demo` node has exactly 2 items. Under a pool-size reading,
    `DIAG_PROBE_UNAVAILABLE` would therefore be unreachable, contradicting §4 criterion 6.
  - **RESOLVED** (arbiter-02-predispatch § Q-G). An item is *available* for the probe unless its answer was
    already shown in the current run. Under `map_check_here`, every item of the candidate is available. The
    interaction-contract §4 text lands in task 02.1.
  - **Reachability.** The terminal is reachable on the real `data/demo` with a constructed state (task
    02.11):
    - `syllabi = [MTH1W]`;
    - `exponent-laws` and `polynomials` are `blocked`, `simplifying-expressions` is `cleared`;
    - `exponent-laws` is missed and then retried, so both of its answers are shown;
    - `polynomials` is missed twice, which opens a diagnosis with budget 1.
  - **Test-data rule:** in-memory bundles derived from `data/demo` are allowed only for property tests over
    generated graphs and for the extension positive case. The C1 seams and the AC6 terminal suite run on
    the real `data/demo`.
- **Technical defaults (not Q5; decided per owner calibration that technical detail is never a Q5):**
  - No unused item for a D27 retry → skip the retry, log `EXP_ITEM_POOL_EMPTY`, continue the run.
  - Item draw prefers items with no `probe_log` entry, then the least recently used, deterministic by
    item id.
  - A hint whose error type has no `hint_tree` entry falls back to the node's `none-of-these` hint.
  - A `map_check_here` diagnosis outside a run logs no `expedition_log` entry (its effects are the
    `blocked` marks and `probe_log` rows). `diagnosis_events` stays ≤ 1 per entry per the schema.
- **Q5 candidates:** none at authoring. Every decision above is taken from D1–D49, the ratified domain
  defaults and the contracts. Q-A and Q-B are contract realisations of ratified defaults, routed to the
  spec-arbiter; they are not owner decisions unless the arbiter finds that a ratified default itself must
  change. *Post-authoring:* the arbiter escalated Q-E to Q5, because every passing rule changes I8's
  meaning. The owner ruled it on 2026-09-10 (option A). No locked decision D1–D49 was changed, and none
  remains open.

## 10. Change log
| Date | Author | Change |
|------|--------|--------|
| 2026-09-10 | epic-scoper | Initial brief synthesized. |
| 2026-09-10 | brief-amender (owner Q5 ruling `tasks/blocked/Q5-RULING-02-QE.md` + arbiter pre-dispatch rulings `tasks/arbitration/arbiter-02-predispatch.md`) | §2 marker/trail bullet, §3 (interaction-contract, graph-constraints, data-model entries; I7/I8 line; artifact line), §4 criteria 1, 2, 3, 5, 6, 9, §8 split record, and §9 Q-A…Q-G marked resolved (Q-F and Q-G added). Scope unchanged. See Amendment 02.03.1. |

## Amendment log

### Amendment 02.03.1 — 2026-09-10

**Trigger**: tier-6 brief-amender, invoked by the orchestrating session with the owner's Q5 ruling on Q-E and the spec-arbiter's pre-dispatch rulings on Q-A, Q-B, Q-C, Q-D, Q-F and Q-G, ahead of task 02.3 dispatch.
**Architect escalation**: none on disk under `tasks/blocked/architect-escalation-02-03.md`. The Q-E block was raised by the spec-arbiter (`tasks/blocked/blocked-arbiter-02-03.md`), stopped at `docs/blocked/run-stop-02-qe-trail-path.md` and ruled in `tasks/blocked/Q5-RULING-02-QE.md`. The other rulings are in `tasks/arbitration/arbiter-02-predispatch.md`.

**Passage 1 — §3, graph-constraints entry.**

**Original brief text**:
> `contracts/graph-constraints.md` (v1.0.0), § L0-T (trail segments) and § *Query rules (also `Core`)*.
> `READ-ONLY`. L0-T is "the same `Core` function; runs at generation". The query walks ≤ 2 levels
> breadth-first, treats `fog` as a candidate and uses the confidence → depth → id tie-break.

**Amended brief text**:
> § *Query rules*: `READ-ONLY`, with the same query rules. § L0-T: **BUMP**, per the owner's Q5 ruling on
> Q-E (option A; task 02.3, route a). A course segment is exactly the course's resident nodes, ordered by
> unit order, then topologically within each unit, with ties broken by node id. An edge against unit order
> is a warning, not a failure. Every extension node is reachable from the preceding segment. `data/demo` is
> not changed. (See the full text in §3.)

**Passage 2 — §4 acceptance criterion 2.**

**Original brief text**:
> With `syllabi = [MTH1W]` and the default marker, `generate_trail` over `data/demo` produces course
> segments in unit order that pass L0-T. [...] With the marker past the course's last unit, the result
> carries a `kind: extension` segment. With no downstream-course node present, it carries none. A segment
> that fails L0-T raises `EXP_TRAIL_INVALID` and the previous trail is returned unchanged.

**Amended brief text** (summarised; see §4 item 2 for the full wording):
> The course segment holds exactly MTH1W's resident nodes, ordered by unit order, then topologically within
> each unit, with ties broken by node id. It passes the rewritten L0-T. The against-unit-order edge
> `solving-linear-equations` (u3) → `exponent-laws` (u2) is a warning, not a failure. Past the last unit
> (`marker.past_last_unit == true`), the extension segment's nodes are each reachable from the segment
> before it; the positive case runs on an in-memory bundle derived from `data/demo`. The "none" and
> `EXP_TRAIL_INVALID` clauses are unchanged.

**Passage 3 — specificity from the arbiter rulings, with no criterion added or removed.**
- §2 marker/trail bullet: L0-T is read "as rewritten per the owner's Q-E ruling".
- §3 interaction-contract entry: task 02.1 also lands the arbiter's Q-A, Q-F and Q-G text.
- §3 data-model entry: "BUMP candidates" becomes the ruled v1.3.0 (Q-A + Q-F, task 02.2) and v1.4.0 (Q-B, task 02.9).
- §3 I7/I8 line: "passes L0-T (as rewritten per §9 Q-E)".
- §3 artifact line: the four contract-bump tasks are enumerated.
- §4 criteria:
  - 1: a clear removes `remediated` (Q-A).
  - 3: a new bullet for the fringe-guard reading of `remediated` (Q-A).
  - 5: `confirmed` sets `remediated` and `capped` does not (Q-A); "available" items are defined (Q-G).
  - 6: `DIAG_PROBE_UNAVAILABLE` is reached on the real `data/demo` with a constructed state (Q-G).
  - 9: the merge rule is in data-model v1.4.0 and the law tests compare in canonical order (Q-B).
- §8: the planner's 02a/02b split is recorded.
- §9: Q-A…Q-E are marked resolved with pointers, and Q-F and Q-G are added as resolved. The Q5-candidates line gains a post-authoring note.

**Source**:
- `tasks/blocked/Q5-RULING-02-QE.md`: owner ruling, option A, the four bullets.
- `tasks/arbitration/arbiter-02-predispatch.md` § Summary, § Q-A, § Q-B, § Q-C, § Q-D, § Q-F, § Q-G, including their normative text and the test-data rule.
- `docs/plans/epic-02-plan.md` (header and task table) and `docs/epic-plan.md` § EPIC 02 split, for the 02a/02b split.
- `contracts/graph-constraints.md` v1.0.0 § L0-T is the current row. The rewrite is owed by task 02.3; this amendment does not edit it.

**Effect on deliverables**: NONE (specificity added).
- Every item of §2 and §7 is unchanged, and no deliverable is added, dropped or deferred.
- The contract bumps were already anticipated in brief §3 and §8 (normalisation, Q-A, Q-B). The L0-T rewrite is the owner's own ruling, carried by task 02.3.
- The split is the one the brief's §8 already specified, and it is taken at the brief's seam.
- I8 is not weakened by this brief. Every segment is still checked at generation, and `EXP_TRAIL_INVALID` still leaves the previous trail standing. What a valid segment means follows the owner's ruling.

**Effect on owner-facing acceptance**: NONE beyond the owner's own ruling.
- Criterion 2 now states the trail rule the owner ratified in the Q5 ruling, instead of the "directed path" reading the ruling replaced. It still asserts the same four behaviours: pass on the course segment, regeneration on `set_marker`, an extension present or absent, and `EXP_TRAIL_INVALID` with the previous trail standing.
- Criteria 1, 3, 5, 6 and 9 gain assertions from the arbiter rulings. None is weakened, removed or renumbered, and criteria 4, 7, 8 and 10 and §5 are unchanged.

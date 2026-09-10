# Task 02.7 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: item-checker-expedition-run
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 02
- Task: 07
- Slug: item-checker-expedition-run
- Summary: Deterministic item checking (`ItemChecker`: numeric per task 02.1 normalisation rules, multiple-choice by choice id) plus the expedition run state machine (answer + why always returned, D27 retry tolerance, one diagnosis per run, blocked on second miss, end with summary, expedition_log / probe_log / abandoned entries). The task owns the suspend/resume hand-off so diagnosis (task 02.11) never edits this file.
- Invariants in play: **I1** (no code path lets a model output decide correctness; checking is deterministic over `answer`/`correct_choice_id` fields only), **I2** (Tier 0 alone usable; every expedition path completes deterministically), **I3** (answer and why always shown before next-item state reachable), **I10** (input is numeric or multiple-choice; no free text).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — §2 Expedition (Door B) — answer, tolerance, retry/D27, end, Properties

> - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
> - **Tolerance (D27):** first miss on a node in this run → `retry` with a second item of the same node; second miss → if `diagnosis_used == false` → `diagnosing` (set `diagnosis_used = true`), else mark the node `blocked` (expedition Q5: "We'll come back to this one") and continue. **At most one diagnosis per run.**
> - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
>
> **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; every item shown ends with its answer visible.

Source: `contracts/interaction-contract.md:34–43`

Binds this task: The specification of the `ItemChecker` must verify numeric answers against the normalised form and tolerance from `contracts/interaction-contract.md` §2 (to be written by task 02.1); multiple-choice answers must be checked by `correct_choice_id` only. The expedition run machine must enforce the D27 tolerance rule: first miss → retry, second miss → diagnosis if available else block. Every answer shown in results must include the correct answer and the item's `why` field. Runs can be abandoned mid-way. All these are properties testable in `CoreTests`.

### contracts/interaction-contract.md — §5 Notifications — event names

> `expedition.started · expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition.completed`

Source: `contracts/interaction-contract.md:76–86`

Binds this task: The expedition run machine must emit exactly these event names (as in-process notifications). No other event names for expedition events are permitted.

### contracts/data-model.md — § ProbeItem — answer, choices, tolerance, why, distractor tags, check

> `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}` (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

Source: `contracts/data-model.md:59–62`

Binds this task: Every `ProbeItem` decoded from the bundle has one of two shapes — numeric with `answer.value` and `answer.tolerance` (default 0), or mc with `choices[]` and `correct_choice_id`. The `why` field is always present. Wrong answers on numeric items and distractor choices on mc items carry `error_type_id` tags. There is no free-text answer path.

### contracts/data-model.md — § StudentState — expedition_log, probe_log, abandoned

> `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`

Source: `contracts/data-model.md:134–135`

Binds this task: Every run's end must append an `ExpeditionLogEntry` with the run's day (device-local calendar day), item count answered, nodes cleared and blocked this run, whether it was abandoned, and the count of diagnosis events opened. Every answered item must append a `ProbeLogEntry` with the day, the node id, the item id, whether it was correct, and whether it was a retry.

### contracts/error-codes.json — EXP_ITEM_POOL_EMPTY, EXP_* for answers

> `{"code": "EXP_ITEM_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null}`

Source: `contracts/error-codes.json:16`

Binds this task: When composing a fringe slot (task 02.6) finds no available item for a node, `EXP_ITEM_POOL_EMPTY` is raised. This code is registered and must be mirrored in `CoreError`.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W2 (Answer an item)

> **Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10).
> 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40, per-item node and result — the L3 input).

Source: `docs/domains/expedition.md:75–80`

### docs/domains/expedition.md — W3 (Apply the tolerance rule, D27)

> **Pre:** an incorrect `ItemResult`. **Steps:** 1. First miss on this node in this run → draw one retry item on the same node and return to W2. 2. Second miss on the node, and no Door A event yet this run → emit `expedition.diagnosis_requested` and suspend the run while **diagnosis** runs (W1 there); on return, continue with the remaining items. 3. Second miss after the run's Door A event was used → mark the node `blocked` (W4) and continue without interruption. **Post:** at most one Door A event per run; a test asserts it.

Source: `docs/domains/expedition.md:82–88`

### docs/domains/expedition.md — W5 (End the run)

> **Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`.
> 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows a banner, the summary still shows — I3's spirit). 3. Offer "Start another" (W1) and "Back to the map".
> **Post:** `expedition.completed` emitted (D40) with the count of items and cleared nodes; a run left mid-way is logged as abandoned, never resumed item-by-item (Q6).

Source: `docs/domains/expedition.md:98–103`

### docs/domains/expedition.md — Q4 (Numeric answer matching)

> **Default:** exact match after normalisation (whitespace, leading zeros, `3/4` = `0.75`); decimals within a per-item absolute tolerance the item declares, default 0 [ESTIMATE: items are authored to have exact answers]; no CAS on the device (D34). **Trade-off:** honest and cheap; an item whose answer genuinely needs symbolic comparison must be authored as multiple-choice instead.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:191–195`

### docs/domains/expedition.md — Q5 (What the student sees on the second miss when the run's Door A event is spent)

> **Default:** the answer card as usual plus one line — "We'll come back to this one" — and the node is marked `blocked` on the map; no hint, no probe. **Trade-off:** keeps the 3-minute rhythm (D27's purpose); the student gets no help on that node until the next run or a "Check me here" tap.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:197–201`

### docs/domains/expedition.md — Q6 (Resuming a run interrupted by the app going to background)

> **Default:** the current item is kept for a short grace window [ESTIMATE: until the app is terminated by the OS]; a terminated run is logged as abandoned and the next launch starts fresh. **Trade-off:** no half-finished runs to reason about; a student interrupted by a call loses at most one item's context.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:203–207`

## §D. Prior task outputs this task depends on

- **Numeric normalisation rules** — `contracts/interaction-contract.md` §2 (to be written by task 02.1) — the exact rules for normalising numeric input (`whitespace`, `leading zeros`, `3/4 = 0.75`), and per-item `tolerance` applied as an absolute value range. This task's `ItemChecker` must implement these rules.
- **Fringe and item draw** — task 02.6 exports the `compose` function and item-draw logic that fills expedition slots; this task consumes it to start an expedition. The item pool is already sorted and filtered.
- **`StudentState.swift` type** — EPIC 01 output, `Packages/Core/Sources/Core/Model/StudentState.swift` — the Codable struct and its nested types (`Marker`, `NodeState`, `Mastery`, `Trail`, `TrailSegment`, `ExpeditionLogEntry`, `ProbeLogEntry`). Task 02.7 must add fields as needed per EPIC 02 brief §3 (BUMP candidates Q-A and Q-F via the arbiter rulings).
- **`ProbeItem` type** — EPIC 01 output, `Packages/Core/Sources/Core/Model/Nodes.swift:54–65` — the Codable struct with `id`, `type`, `promptLatex`, `why`, and either `answer` (numeric) or `choices[]` + `correctChoiceId` (mc). The struct is read-only by this task.

## §E. Negative facts (confirmed ABSENT)

- **No prior `ItemChecker` implementation.** Grep `ItemChecker` returned only the planner's mention in `docs/plans/epic-02-plan.md`; no Swift code exists.
- **No hand-written expedition run machine.** Grep `expeditionRun\|expeditionMachine` in `Packages/Core` returns no match.
- **No numeric normalisation rules in interaction-contract yet.** Bump to `contracts/interaction-contract.md` §2 is owned by task 02.1; the rule text does not exist at context-compile time.
- **No expeditionary state on `StudentState` fields for run tracking.** The struct carries `schemaVersion`, `syllabi`, `marker`, `nodes`, `trail`, `expeditionLog`, `probeLog`, but no per-run tracking fields (e.g. `diagnosis_used`, `current_item`). These must be local to the run machine, never persisted.
- **No `CoreError` cases for `EXP_ITEM_POOL_EMPTY`.** Grep `EXP_ITEM_POOL_EMPTY` in `Packages/Core/Sources/Core/CoreError.swift` returns no match. The code is registered in `error-codes.json` but not yet mirrored in the Swift enum. Task 02.4 (calendar day and R-6 error-code extension) is a dependency of the wrap, so the enum will be updated there, but this task must not assume it.
- **No event emission infrastructure.** Grep `emit\|notification\|CoreEvent` in `Packages/Core/Sources/Core` returns no matches outside comments. The event-emission mechanism is not yet built; task 02.4 adds it.
- **No diagnosis event counter on `StudentState`.** The schema has no field tracking how many diagnosis events were opened this run. W7 reconciliation and task 02.6 compose may need it; task 02.4 adds `CoreEvent`.

## §F. File scope

Files this task may create or touch:

- CREATE `Packages/Core/Sources/Core/ItemChecker.swift` — confirmed absent (Glob `**/ItemChecker.swift` empty). This file holds the `struct ItemChecker` and any support types for checking numeric and mc answers.
- CREATE `Packages/Core/Sources/Core/ExpeditionRun.swift` (or similar name) — confirmed absent (Glob `**/ExpeditionRun.swift` empty). This file holds the expedition run state machine and `ItemResult` type.
- MODIFY `Packages/Core/Sources/Core/Model/StudentState.swift` — current shape: `StudentState` + `Marker` + `NodeState` + `Mastery` + `Trail` + `TrailSegment` + `SegmentKind` + `ExpeditionLogEntry` + `ProbeLogEntry`. Per EPIC 02 brief §9 Q-A and arbiter ruling Q-A, `NodeState` must gain `remediated: Bool?` (absent = false). Per arbiter ruling Q-F, `Marker` must gain `pastLastUnit: Bool?` (absent = false). These changes land in task 02.2 first; this task reads the updated types.
- MODIFY `Packages/Core/Sources/Core/CoreError.swift` — current cases: `graphL0Failed`, `mapLayoutMissing`, `mapRegionUnknown`, `mapLandmarkUnsourced`, `spineUnitEmpty`, `spineSourceRefUnresolved`, `platformBundleIntegrityFailed`. Task 02.4 adds the R-6 set including `EXP_ITEM_POOL_EMPTY`; this task does not edit this file (task 02.4 is a dependency for the wrap, so task 02.7 is written after 02.4 is specified, but may not depend on its output being in `main` yet).

Note: the planner's task sequence (line 20 of `docs/plans/epic-02-plan.md`) places 02.7 after 02.6 (fringe) with 02.1, 02.2, 02.4, 02.5, 02.6 as dependencies. Numeric normalisation rules from 02.1 are a precondition for implementation. If 02.1 is not yet merged when 02.7 is specified, the spec must state the rule text verbatim or point to the exact PR/branch where it lands.

## §G. Data inventory — every demo item

All data/demo items extracted from `data/demo/nodes.json`. Every node listed once with its 2 items (exactly 2 per node [SOURCED: docs/epics/epic-02-core-behaviour.md:245]; 40 items total = 20 nodes × 2).

### Numeric items (20)

| Node | Item ID | Answer (value) | Tolerance | Wrong answer(s) + error_type_id |
|---|---|---|---|---|
| integer-operations | integer-operations-1 | 4 | 0 (default) | -10 (sign-error) |
| order-of-operations | order-of-operations-1 | 14 | 0 | 20 (wrong-order) |
| rational-numbers | rational-numbers-1 | 5/6 | 0 | 2/5 (common-denominator-error) |
| exponent-laws | exponent-laws-1 | 6 | 0 | 5 (added-exponents-on-power) |
| scientific-notation | scientific-notation-1 | 32000 | 0 | 320 (decimal-point-error) |
| linear-relations | linear-relations-1 | 3 | 0 | 5 (slope-intercept-swap) |
| solving-linear-equations | solving-linear-equations-1 | 4 | 0 | -4 (sign-flip-error) |
| solving-systems-of-equations | solving-systems-of-equations-1 | 6 | 0 | 4 (substitution-error) |
| simplifying-expressions | simplifying-expressions-1 | 8 | 0 | 2 (unlike-terms-combined) |
| polynomials | polynomials-1 | 4 | 0 | 3 (like-terms-miscombined) |
| factoring | factoring-1 | 6 | 0 | -6 (sign-error-in-factors) |
| solving-quadratics | solving-quadratics-1 | 3 | 0 | -3 (quadratic-formula-sign-error) |
| rational-expressions | rational-expressions-1 | 8 | 0 | 2 (cancelled-terms-not-factors) |
| quadratic-functions | quadratic-functions-1 | 3 | 0 | -3 (vertex-sign-error) |
| function-concept | function-concept-1 | 7 | 0 | 6 (function-evaluation-error) |
| function-transformations | function-transformations-1 | 4 | 0 | -4 (shift-direction-error) |
| function-notation | function-notation-1 | 10 | 0 | 6 (notation-misread) |
| domain-and-range | domain-and-range-1 | 3 | 0 | 0 (domain-range-swap) |
| exponential-functions | exponential-functions-1 | 9 | 0 | 8 (base-exponent-swapped) |
| logarithms | logarithms-1 | 3 | 0 | 16 (log-exponent-confusion) |

### Multiple-choice items (20)

| Node | Item ID | Correct choice | Distractor choices + error_type_id |
|---|---|---|---|
| integer-operations | integer-operations-2 | a (-3) | b: 7 (sign-error) |
| order-of-operations | order-of-operations-2 | a (20) | b: 14 (wrong-order) |
| rational-numbers | rational-numbers-2 | a (1/2) | b: 1/8 (common-denominator-error) |
| exponent-laws | exponent-laws-2 | a (x^7) | b: x^12 (added-exponents-on-power) |
| scientific-notation | scientific-notation-2 | a (5.6×10^-4) | b: 5.6×10^4 (decimal-point-error) |
| linear-relations | linear-relations-2 | a (7) | b: -2 (slope-intercept-swap) |
| solving-linear-equations | solving-linear-equations-2 | a (2) | b: -2 (sign-flip-error) |
| solving-systems-of-equations | solving-systems-of-equations-2 | a (4) | b: 6 (substitution-error) |
| simplifying-expressions | simplifying-expressions-2 | a (3) | b: 5 (unlike-terms-combined) |
| polynomials | polynomials-2 | a (3) | b: 7 (like-terms-miscombined) |
| factoring | factoring-2 | a (7) | b: -7 (sign-error-in-factors) |
| solving-quadratics | solving-quadratics-2 | a (2) | b: -2 (quadratic-formula-sign-error) |
| rational-expressions | rational-expressions-2 | a (4) | b: 34 (cancelled-terms-not-factors) |
| quadratic-functions | quadratic-functions-2 | a (-5) | b: 5 (vertex-sign-error) |
| function-concept | function-concept-2 | a (3) | b: -5 (function-evaluation-error) |
| function-transformations | function-transformations-2 | a (3) | b: -3 (shift-direction-error) |
| function-notation | function-notation-2 | a (1) | b: 0 (notation-misread) |
| domain-and-range | domain-and-range-2 | a (5) | b: -5 (domain-range-swap) |
| exponential-functions | exponential-functions-2 | a (16) | b: 8 (multiplied-instead-of-power) |
| logarithms | logarithms-2 | a (3) | b: 1000 (log-exponent-confusion) |

### Acceptance signal for data inventory

**Every spec writer must require:** (a) Every demo item's own answer (numeric value or correct_choice_id) checks correct under the normalisation rules from interaction-contract §2 and the per-item tolerance; (b) Every tagged wrong answer on numeric items checks incorrect; (c) Every tagged distractor choice on mc items checks incorrect. Failure to verify means the spec is incomplete.

## §H. Stack constraints relevant here

- **Deployment target and language:** Swift 6 (strict concurrency complete) on iOS/iPadOS 18.0+, macOS 15.0+. Source: `docs/tech-stack.md:14`.
- **Shared logic:** `Core` (Foundation only, no third-party frameworks). Item checking and run machine are pure functions in `Core`; they import Foundation only. Source: `docs/tech-stack.md:17`, I14.
- **Persistence:** StudentState is `Codable` JSON persisted by the App layer (EPIC 03); this task makes no persistence calls. Source: `docs/tech-stack.md:19`.
- **Testing:** Swift Testing (`import Testing`) for `Core`. Test file: `Packages/Core/Tests/CoreTests/<module>Tests.swift`. Source: `docs/tech-stack.md:22`.
- **No model calls:** Tier 0 only. No Foundation Models, no Claude API. Source: brief §2 (I2), `docs/tech-stack.md` § 1 (slot "Tier 1").
- **Error codes:** Every `EXP_*`, `DIAG_*`, `GRAPH_*`, `MAP_*` code `Core` raises must be mirrored in `enum CoreError: String` and pass `ErrorRegistryTests`. Source: `contracts/error-codes.md` § Rules, brief §3 R-6.

## §I. Critical binding facts

1. **Numeric answer normalisation is a precondition:** Task 02.1 writes `contracts/interaction-contract.md` §2 (exact rules for whitespace, leading zeros, `3/4 = 0.75`, per-item tolerance). Spec 02.7 must quote these rules verbatim or state: "These rules are implemented by [task 02.1 / PR#N / branch main@<commit>]". No ItemChecker spec is complete without them.

2. **"Available" for probe items has a specific definition** (arbiter ruling Q-G): An item is available for the probe iff it belongs to the candidate and its answer has not been shown in the current expedition run. Under `expedition_second_miss`, items whose answer was shown in retry or earlier in the same run are excluded. Under `map_check_here`, every item is available. Source: `tasks/arbitration/arbiter-02-predispatch.md:209–211`.

3. **Demo bundle Q-E is held:** The conflict that "every segment's `node_ids[]` is a directed path in the graph" does not hold on the real `data/demo` is a Q5 escalation. Tasks 02.3, 02.5, 02.6, 02.7 are held; they may not be specified until the escalation is resolved. Source: `tasks/arbitration/arbiter-02-predispatch.md:166–169`.

4. **Diagnosis hand-off:** When the run emits `expedition.diagnosis_requested`, the run is suspended (no further items shown). When diagnosis returns (with `diagnosis.node_blocked`, `diagnosis.returned`, or a `diagnosis_used` flag set), the run resumes at the next item. The run machine must handle this suspend/resume without editing diagnosis code or vice versa. Source: brief §4 C1 seam, `docs/domains/expedition.md:85`.

5. **Run abortion:** A run ended mid-way (app backgrounded or user leaves) is logged as `abandoned: true` in the `ExpeditionLogEntry`, never resumed. A terminated run on app relaunch starts fresh. Source: `docs/domains/expedition.md:103`, `docs/domains/expedition.md:206`.

## §J. Arbiter rulings in scope (context only)

These rulings from `tasks/arbitration/arbiter-02-predispatch.md` are presented for reference. They bind other tasks; this task reads their outputs but does not implement them:

- **Q-A (data-model v1.3.0):** `NodeState` gains `remediated: Bool?` (absent = false) to distinguish diagnosis-remediated nodes from capped or spent-Door-A blocked nodes. Implemented by task 02.2. This task reads the updated `StudentState` type.
- **Q-F (data-model v1.3.0):** `Marker` gains `pastLastUnit: Bool?` (absent = false) to represent "marker is past the course's last unit". Implemented by task 02.2. This task reads the updated type.
- **Q-G (available items):** An item is available for a probe iff its answer has not been shown in the current run. Implemented by task 02.11 (diagnosis); this task's run machine does not call the probe query.

## Audit of §B quotes

All quoted blocks re-read from source and byte-compared:

1. `contracts/interaction-contract.md:34–43` — ✓ exact match (lines 34–35 `answer(item)…`, line 36–38 `Tolerance`, line 39 `end`, lines 41–43 `Properties`).
2. `contracts/interaction-contract.md:76–86` — ✓ exact match (lines 76–86 event names, one per line, exact spacing and names).
3. `contracts/data-model.md:59–62` — ✓ exact match (ProbeItem definition, id through "No free-text answer field").
4. `contracts/data-model.md:134–135` — ✓ exact match (expedition_log and probe_log definitions).
5. `contracts/error-codes.json:16` — ✓ exact match (EXP_ITEM_POOL_EMPTY entry).

All quoted blocks from §C domain excerpts re-read and byte-compared:

1. `docs/domains/expedition.md:75–80` — ✓ exact match (W2 pre/steps/post).
2. `docs/domains/expedition.md:82–88` — ✓ exact match (W3 pre/steps/post, D27 enforcement).
3. `docs/domains/expedition.md:98–103` — ✓ exact match (W5 pre/steps/post, abandoned and run summary).
4. `docs/domains/expedition.md:191–195` — ✓ exact match (Q4 default and ratification).
5. `docs/domains/expedition.md:197–201` — ✓ exact match (Q5 default and ratification).
6. `docs/domains/expedition.md:203–207` — ✓ exact match (Q6 default and ratification).

Quote audit result: **All 11 blocks verified, zero corrections needed.**

# Epic 02 · Task 07: Deterministic `ItemChecker` + the expedition run machine (D27, suspend/resume hand-off)

---
epic: 02
task: 07
slug: item-checker-expedition-run
kind: feat
risk: seam
depends_on: [02.1, 02.6]
model: sonnet
---

> **Bundle/upstream inconsistencies found and corrected in this run (report to the task-context-compiler
> and to the author of `tasks/epic-02-task-06-fringe-compose-seam.md`).**
> 1. `tasks/epic-02-task-06-fringe-compose-seam.md` §3 quotes a block headed "Technical defaults" and
>    attributes it to `tasks/arbitration/arbiter-02-predispatch.md`. That file was re-read in full in this
>    run (423 lines) and contains **no such heading and no such text**. The real, byte-verified source of
>    that text is `docs/epics/epic-02-core-behaviour.md` § 9 "Technical defaults (not Q5; decided per owner
>    calibration that technical detail is never a Q5)" (lines 472–478), which this spec quotes correctly in
>    §3 below. This is a mis-citation, not a fabricated rule — the rule text itself is real and this spec
>    relies on it — but the source file name in 02.6's spec is wrong. 02.6's own file scope and code are
>    unaffected by the correction (it does not cite the wrong file inside any doc comment its own spec
>    quotes into product code); this note exists so the task-context-compiler stops propagating the wrong
>    citation to any later task.
> 2. The context bundle's §I "critical binding facts" item 4 describes the resume trigger as "diagnosis
>    returns (with `diagnosis.node_blocked`, `diagnosis.returned`, or a `diagnosis_used` flag set)". Per
>    `contracts/interaction-contract.md` § 4 (re-read in this run), the *only* signal the expedition run
>    needs is `returned` — "`returned` always hands control back to the suspended expedition (its next
>    item)" unconditionally, regardless of which terminal (`refuted`/`confirmed`/`capped`/`unconfirmed`)
>    preceded it. This spec's `ExpeditionRun.resume` therefore takes **no** diagnosis-outcome parameter at
>    all (§4); the bundle's phrasing overstated what this task's API needs to branch on.

## §1 Goal & acceptance criteria

Goal: give `Core` two things. First, `ItemChecker` — the single, deterministic function that decides
whether a submitted answer is correct, implementing `contracts/interaction-contract.md` v0.9.1 §2's
numeric-normalisation grammar exactly (exact-rational parse and comparison, never floating point) and
`mc` comparison by `choices[].id`. Second, `ExpeditionRun` — the pure expedition-run state machine
(`contracts/interaction-contract.md` §2's `idle → composing → item → (retry | diagnosing | item) →
summary → idle`) that consumes a `ComposeResult` from task 02.6's `Expedition.compose`, drives items one
at a time through `ItemChecker`, applies the D27 tolerance rule (retry, then diagnosis-or-block), and ends
with a summary plus `expedition_log`/`probe_log` entries.

**This task owns the suspend/resume hand-off precisely, so that task 02.11 (diagnosis) never edits this
file.** When the run's D27 rule opens a diagnosis (second miss, `diagnosisUsed == false`), `answer` returns
an `ExpeditionRunState` with `currentItem == nil` and `suspendedForDiagnosisNodeId` set to the missed
node's id — this is the entire signal 02.11 needs to know a diagnosis should open, with that node id as
`origin`. Diagnosis (02.11) runs its own state machine entirely in its own file, over its own copy of
`StudentState`, and — once it reaches `returned` — calls `ExpeditionRun.resume(run:)` with nothing else:
no diagnosis-outcome value, no `StudentState`. `resume` only pops the run's own queue and clears the
suspension flag; the diagnosis's effect on mastery/`remediated` is already carried inside whatever
`StudentState` the diagnosis produced, which the caller (not this file) threads into the next call to
`ExpeditionRun.answer(run:, state:, ...)`. This keeps the two state machines decoupled: this file never
imports anything from 02.11, and 02.11 imports only `ExpeditionRunState`'s public fields and `resume`'s
signature, both fixed here.

Invariants in play:

- **I1** — `ItemChecker.check` is the sole code path that decides correctness: a `ProbeItem` and a
  submitted `String`, compared deterministically (exact-rational arithmetic for `numeric`, choice-id
  equality for `mc`). No model, no CAS, no adapter anywhere in this task's code.
- **I2** — every function in this task is Tier-0 deterministic; nothing here takes a model or adapter
  argument or calls one. Not otherwise engaged beyond that structural fact (recorded so the absence is a
  decision, not a gap).
- **I3** — `answer` always returns an `ItemResult` carrying the correct answer's display string and the
  item's own `why`, for every item shown, including retries — before any next-item state is reachable (the
  caller cannot advance the run without having received this value first, since `answer`'s return is the
  only source of the next `ExpeditionRunState`).
- **I10** — `ItemChecker.check`'s only inputs are a `ProbeItem` and a `String`; there is no free-text
  answer path — a `numeric` submission is parsed under the fixed grammar or rejected as a miss, an `mc`
  submission is compared to `correctChoiceId` only, never to any `choices[].latex` text.
- **I5** — no field is added to `StudentState`/`NodeState`/`Marker` (02.2's, already landed). Every new
  type this task ships (`ItemResult`, `CurrentItem`, `ExpeditionRunState`, `StartOutcome`, `AnswerOutcome`,
  `EndOutcome`, `ExpeditionSummary`) carries only node/item ids, booleans, small integers, strings that are
  already-schema-legal display text (`why`, the correct-answer display), and `CoreEvent` enum cases — no
  person, device, install or session identifier.
- **I14** — every function in `ItemChecker` and `ExpeditionRun` is a pure value transformation over its
  arguments: `Foundation` only, no `Date()`, no file I/O, no global mutable state. `today` is always the
  caller's injected `CalendarDay`. `Core`'s existing `coreImportBoundary()` test (unmodified) covers both
  new files with no edit.
- **D27** — this task **is** the runtime realisation of D27: at most one retry per node per run, at most
  one diagnosis event per run, a spent-diagnosis second miss marks the node `blocked` and the run continues
  without interruption.

Acceptance criteria (each independently verifiable):

- AC1: For every `ProbeItem` of every node in the real `data/demo` bundle (loaded via `BundleIO.read`,
  40 items across 20 nodes), `ItemChecker.check(item:, submitted: <the item's own correct value>)` returns
  `true` — `answer.value` for `numeric` items, `correctChoiceId` for `mc` items.
- AC2: For every `wrong_answers[]` entry on every `numeric` item in real `data/demo`,
  `ItemChecker.check(item:, submitted: wrongAnswer.value)` returns `false`. For every non-correct
  `choices[]` entry on every `mc` item in real `data/demo`, `ItemChecker.check(item:, submitted: choice.id)`
  returns `false`.
- AC3: Numeric normalisation, asserted directly against `ItemChecker.check` on hand-built `ProbeItem`
  values (not `data/demo`, since `data/demo` never exercises whitespace/leading-zero/sign variants on the
  *submitted* side): `"  4  "` matches an `answer.value` of `"4"`; `"+4"` matches `"4"`; `"007"` matches
  `"7"`; `"0.750"` matches `"3/4"`; `"3/4"` matches `"0.75"`; a submission within a non-zero
  `answer.tolerance` (e.g. `answer.value: "1", tolerance: 0.5`, submitted `"1.4"`) is correct, and one just
  outside it (`"1.6"`) is incorrect.
- AC4: A submitted string that does not parse under the grammar (`""`, `"   "`, `"abc"`, `"1//2"`,
  `"1.2.3"`, `"1 2"`, `"4/0"`) never crashes `ItemChecker.check` and always returns `false` — asserted
  against every case in one table-driven test, plus a property test over a wider fuzzed set of random
  strings (§5 T4) that never traps.
- AC5: `ExpeditionRun.start(compose:)` returns a `StartOutcome` whose `run.currentItem` targets
  `compose.slots.first`'s node and item, `run.queue` holds `compose.slots.dropFirst()` in order,
  `run.diagnosisUsed == false`, `run.shownItemIds == []`, `run.suspendedForDiagnosisNodeId == nil`, and
  `.event == .expeditionStarted`.
- AC6: A first miss on a new-learning node (submitted answer incorrect, `run.missCounts[nodeId]` goes from
  absent/0 to 1) yields an `AnswerOutcome` whose `run.currentItem` targets the **same node** with a
  **different** item id (drawn via `Expedition.selectItem(from:excluding:probeLog:)` excluding
  `run.shownItemIds`), `run.currentItem!.isRetry == true`, `run.queue` unchanged, `run.diagnosisUsed`
  unchanged (`false`), and `events == [.expeditionItemAnswered]` (no clear, no diagnosis, no block).
- AC7: A second miss on that same node (the retry item also answered incorrectly), with
  `run.diagnosisUsed == false` beforehand, yields an `AnswerOutcome` whose `run.currentItem == nil`,
  `run.suspendedForDiagnosisNodeId == nodeId`, `run.diagnosisUsed == true`, and
  `events == [.expeditionItemAnswered, .expeditionDiagnosisRequested]`. The call does not throw.
- AC8: `ExpeditionRun.resume(run:)`, called on AC7's resulting `run`, returns a `run` with
  `suspendedForDiagnosisNodeId == nil` and `currentItem` set to `run.queue.first` (or `nil`, with
  `run.queue` empty, when nothing remains — the run is then ready for `end`). `resume` takes only `run:
  ExpeditionRunState` — no `StudentState`, no diagnosis-outcome value.
- AC9: A second miss on a **different** node, occurring after `run.diagnosisUsed == true` (the run's one
  diagnosis event already spent, e.g. from AC7), yields an `AnswerOutcome` whose `state.nodes[nodeId]!
  .mastery == .blocked` (via `MasteryTransitions.diagnosisBlocked`, reused unmodified), `run.currentItem`
  advances to `run.queue.first`, `run.suspendedForDiagnosisNodeId` stays `nil` (no second diagnosis is
  requested), and `events == [.expeditionItemAnswered, .diagnosisNodeBlocked]`.
- AC10: A miss on a `review`-kind slot (the node's `state.nodes[nodeId]!.mastery == .cleared`) both (a)
  applies the ladder-reset side effect (`MasteryTransitions.itemMissReview`: `ladderRung` resets to 0,
  `nextDue = today + ladder[0]`, `mastery` stays `.cleared`) and (b) increments `run.missCounts[nodeId]`
  and is eligible for the same retry/diagnosis/blocked D27 flow as any other node — a second such miss
  (with `diagnosisUsed` already spent) calls `MasteryTransitions.diagnosisBlocked`, which no-ops on a
  `.cleared` node (mastery stays `.cleared`, no `.diagnosisNodeBlocked` event), per that function's existing
  `mastery == .fog` guard (02.4, unmodified) — asserted directly, proving "tolerance per §2" (the mastery
  table's own side-effect text for the review-miss row) is honoured without special-casing review nodes.
- AC11: Two correct answers on **distinct** items of the same fog/blocked node, driven through two
  successive `ExpeditionRun.answer` calls, clears the node (`state.nodes[nodeId]!.mastery == .cleared`,
  `run.clearedNodeIds` contains it, `events` on the second call include `.expeditionNodeCleared`). The same
  single item answered correctly twice in the same run (only possible via a manufactured `probeLog`/`run`
  state in the test, since the real flow never re-shows an already-correct item) does **not** clear the
  node — proving the distinct-items wiring through `MasteryTransitions.itemCorrect`'s `correctItemIds`
  parameter, derived from `state.probeLog`, is load-bearing at this call site.
- AC12: Property (D27, `data/demo`-scale generated run sequences, §5 T4): across every generated sequence
  of correct/incorrect outcomes driving a full run to `end`, `run.diagnosisUsed` transitions `false → true`
  at most once, and at most one node's `missCounts` ever reaches exactly 1 without also reaching a terminal
  (retry-then-resolve) before the run ends — i.e. never more than one retry outstanding and never more than
  one diagnosis event, matching the Properties bullet's "never more than one diagnosis event per run"
  exactly.
- AC13: `ExpeditionRun.end(run:, state:, today:, abandoned: false)` appends one `ExpeditionLogEntry` to
  `state.expeditionLog` with `day == today.iso`, `itemCount == run.itemsAnswered`,
  `cleared == run.clearedNodeIds.count`, `blocked == run.blockedNodeIds.count`, `abandoned == false`,
  `diagnosisEvents == (run.diagnosisUsed ? 1 : 0)`, and emits `.event == .expeditionCompleted`.
  `end(..., abandoned: true)` appends the same shape with `abandoned == true` and still emits
  `.expeditionCompleted` (the closed `CoreEvent` set has no dedicated "abandoned" event; the log entry's
  boolean is the sole signal).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/ItemChecker.swift` — CREATE. `ItemChecker` (public enum namespace),
  `check(item:submitted:)`, `correctAnswerDisplay(for:)`, and the private exact-rational parsing/comparison
  machinery (§4).
- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` — CREATE. `ItemResult`, `CurrentItem`,
  `ExpeditionRunState`, `StartOutcome`, `AnswerOutcome`, `EndOutcome`, `ExpeditionSummary` (public structs),
  `ExpeditionRun` (public enum namespace: `start`, `answer`, `resume`, `end`), and every private helper.
- `Packages/Core/Tests/CoreTests/ItemCheckerTests.swift` — CREATE. This task's own companion test suite for
  `ItemChecker` (§5), covering AC1–AC4.
- `Packages/Core/Tests/CoreTests/ExpeditionRunTests.swift` — CREATE. This task's own companion test suite
  for `ExpeditionRun` (§5), covering AC5–AC13.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY (append-only). Adds whatever seeded
  generator function(s) this task's property tests need (e.g. a random-outcome sequence generator for
  AC12), following that file's own doc comment, which names "02.5-02.7, 02.10-02.12" as tasks that add
  generator functions here rather than duplicating a parallel helper. No existing function in this file is
  changed or removed.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/Expedition.swift`, `ComposeSlot`, `ComposeResult`, `SlotKind`,
  `Expedition.selectItem` — task 02.6's file (under review at the time of this run; not yet committed —
  see the precondition note in §4). This task calls `Expedition.selectItem(from:excluding:probeLog:)` for
  D27 retries and consumes `ComposeResult`/`ComposeSlot`/`SlotKind` unmodified; it does not implement or
  re-implement `compose` or item drawing.
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift`, `Packages/Core/Sources/Core/Time/
  CalendarDay.swift`, `Packages/Core/Sources/Core/Events/CoreEvent.swift`, `Packages/Core/Sources/Core/
  CoreError.swift` — task 02.4's files, already landed. This task reads `MasteryTransitions.itemCorrect`/
  `.itemMissReview`/`.diagnosisBlocked`, `MasteryTransitionResult`, `CalendarDay`, and the `CoreEvent` cases
  it needs, unmodified. This task throws **no** `CoreError` (§6) and therefore adds no case to that enum.
- `Packages/Core/Sources/Core/Model/StudentState.swift`, `Packages/Core/Sources/Core/Model/Nodes.swift` —
  02.2's and EPIC 01's files. This task reads `StudentState`, `NodeState`, `Marker`, `ProbeLogEntry`,
  `ExpeditionLogEntry`, `Node`, `ProbeItem`, `ProbeAnswer`, `WrongAnswer`, `ProbeChoice`, `ProbeItemType`
  unmodified; it adds no field to any of them.
- `Packages/Core/Sources/Core/State/{MarkerTrailGeneration,Diagnosis}*.swift` — 02.5's and 02.11's files.
  This task ships no trail generation and no diagnosis machine; 02.11 imports this task's public types by
  name and never edits this task's files (§1).
- `Packages/Core/Tests/CoreTests/{MarkerTrailGenerationTests,MarkerTrailFringeSeamTests,
  ExpeditionComposeTests}.swift` — other tasks' companion/seam test files.
- `data/demo/**` — read-only fixture data.
- `contracts/interaction-contract.md`, `contracts/data-model.md`, `contracts/error-codes.json` — read-only
  ground truth; this task lands no contract bump (the numeric-normalisation text is already committed at
  v0.9.1, the precondition this task implements against, per the dispatching instruction).

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules (all re-read from the committed files in this run and byte-compared):

- `contracts/interaction-contract.md` v0.9.1 — heading `## 1. Mastery (per node, in `StudentState`)`, the
  transition table and ladder line:
  > | From | Event | Guard | To | Side effects |
  > |---|---|---|---|---|
  > | fog / blocked | `item_correct(node)` | `correct_count + 1 ≥ 2` on **distinct items** (expedition Q1) | cleared | `next_due = today + ladder[0]`, `ladder_rung = 0`, emit `node_cleared`, remove `remediated` |
  > | fog / blocked | `item_correct(node)` | otherwise | same | `correct_count += 1` |
  > | cleared | `item_correct(node)` (review) | — | cleared | `ladder_rung += 1`, `next_due = today + ladder[rung]` |
  > | cleared | `item_miss(node)` (review) | — | cleared | `ladder_rung = 0`, `next_due = today + ladder[0]`; tolerance per §2 |
  > | fog | `diagnosis_blocked(node)` | — | blocked | emit `node_blocked` |
  >
  > Ladder = `[1, 3, 7, 14, 30]` days [ESTIMATE: expedition Q2]; the last rung repeats.
- `contracts/interaction-contract.md` v0.9.1 — heading `## 2. Expedition (Door B)`, `answer`/normalisation/
  tolerance/`end`/Properties bullets:
  > - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc`
  >   by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
  > - **Numeric normalisation (expedition Q4):** a submitted numeric answer and the item's `answer.value`
  >   (`data-model.md` § ProbeItem) are each parsed under the same grammar before comparison: an optional
  >   leading sign (`+` or `-`; absent = positive), one or more digits, an optional `.` followed by one or
  >   more digits, and an optional `/` followed by one or more digits (a rational `a/b`, `b ≠ 0`); leading
  >   and trailing whitespace is stripped and has no other effect. A string that does not parse under this
  >   grammar is a **miss** — never a crash, never a retry that skips its item. Every value that parses is
  >   reduced to an **exact rational**: leading zeros in the integer part (`007`) and trailing zeros after
  >   the decimal point (`0.750`) carry no significance; a decimal parses to its exact fraction (`0.75 =
  >   3/4`). Two parsed values match iff their exact-rational values are equal, or their absolute difference
  >   is ≤ the item's `answer.tolerance` (non-negative, default `0`, per `data-model.md` § ProbeItem).
  >   Comparison is exact-rational arithmetic; no floating-point comparison is used anywhere in this rule
  >   (I1). This is the entire `numeric`-item rule; `mc` items are compared by `choices[].id` only, never by
  >   value (I10).
  > - **Tolerance (D27):** first miss on a node in this run → `retry` with a second item of the same node;
  >   second miss → if `diagnosis_used == false` → `diagnosing` (set `diagnosis_used = true`), else mark the
  >   node `blocked` (expedition Q5: "We'll come back to this one") and continue. **At most one diagnosis
  >   per run.**
  > - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed
  >   item-by-item.
  >
  > **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker
  > unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review
  > slots; every item shown ends with its answer visible.
- `contracts/interaction-contract.md` v0.9.1 — heading `## 4. Diagnosis (Door A)`, the `returned` line:
  > `returned` always hands control back to the suspended expedition (its next item) or the map node panel.
- `contracts/interaction-contract.md` v0.9.1 — heading `## 5. Notifications (in-process names, exact)`
  (event-name list, re-read in full; only the names this task emits are used: `expedition.started`,
  `expedition.item_answered`, `expedition.diagnosis_requested`, `expedition.node_cleared`,
  `expedition.completed`, and `diagnosis.node_blocked` via the reused `MasteryTransitions.diagnosisBlocked`
  call):
  > `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved ·
  > map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started ·
  > expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due ·
  > expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened ·
  > diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped ·
  > diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated ·
  > platform.state_migrated · platform.state_written · platform.sync_completed ·
  > platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed ·
  > tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted ·
  > telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded ·
  > learning_objects.hint_tier_served · graph.prerequisite_returned`
  >
  > Payloads are ids, enums, booleans and small integers only (I5).
- `contracts/data-model.md` v1.3.0 — heading `### ProbeItem (inside `nodes.json`)`, first paragraph:
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct choice
  > carries an `error_type_id`). No free-text answer field exists (I1, I10).
- `contracts/data-model.md` v1.3.0 — heading `### StudentState (`student-state.schema.json`)`, first
  paragraph (fields this task reads/appends to):
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id,
  > past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?,
  > next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?,
  > node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned,
  > diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
  > **No field may name a person, device, account, install or session** (I5); the schema's closed key set is
  > the guard.
- `docs/epics/epic-02-core-behaviour.md` § 9 "Technical defaults (not Q5; decided per owner calibration
  that technical detail is never a Q5)" (re-read in this run; **this is the correct source** — see the note
  atop this spec for the mis-citation this corrects):
  > - No unused item for a D27 retry → skip the retry, log `EXP_ITEM_POOL_EMPTY`, continue the run.
  > - Item draw prefers items with no `probe_log` entry, then the least recently used, deterministic by
  >   item id.
- `contracts/error-codes.json` (re-read in this run), the `EXP_ITEM_POOL_EMPTY` entry (referenced, never
  thrown, by §6 default):
  > {"code": "EXP_ITEM_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null}
- `contracts/domain-glossary.md` — Expedition, Retry entries (re-read, byte-compared):
  > **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry
  > day-unit), "quest", "level".
  >
  > **Retry** — the second item on the same node after a miss (D27). **Miss** — an incorrect answer.
  > **Clear** — reaching the clear rule (two correct on distinct items). *Banned:* "fail" for an item (fail
  > is a probe outcome), "pass a node".

Prior signatures this task builds on (from the codebase, verbatim, re-read in this run):

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift:54-114 (unmodified)
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

public enum ProbeItemType: String, Codable {
    case numeric
    case mc
}

public struct ProbeAnswer: Codable, Equatable {
    public let value: String
    public let tolerance: Double?
}

public struct WrongAnswer: Codable, Equatable {
    public let value: String
    public let errorTypeId: String
}

public struct ProbeChoice: Codable, Equatable {
    public let id: String
    public let latex: String
    public let errorTypeId: String?
}
```

```swift
// Packages/Core/Sources/Core/Model/StudentState.swift:10-74 (unmodified, task 02.2 already landed)
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

public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
    public let remediated: Bool?
}

public enum Mastery: String, Codable {
    case fog
    case cleared
    case blocked
}

public struct ExpeditionLogEntry: Codable, Equatable {
    public let day: String
    public let itemCount: Int
    public let cleared: Int
    public let blocked: Int
    public let abandoned: Bool
    public let diagnosisEvents: Int
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
// Packages/Core/Sources/Core/State/MasteryTransitions.swift:1-99 (unmodified, task 02.4 already landed)
public struct MasteryTransitionResult: Equatable {
    public let nodeState: NodeState
    public let event: CoreEvent?
}

public enum MasteryTransitions {
    public static let ladder: [Int] = [1, 3, 7, 14, 30]

    public static func itemCorrect(
        current: NodeState, itemId: String, correctItemIds: Set<String>, today: CalendarDay
    ) -> MasteryTransitionResult

    /// The `cleared | item_miss(node) (review)` row only. Called on a node whose `mastery != .cleared`,
    /// this is a no-op: returns `current` unchanged, `event: nil`.
    public static func itemMissReview(current: NodeState, today: CalendarDay) -> MasteryTransitionResult

    /// The `fog | diagnosis_blocked(node) | — | blocked` row only. Called on a node whose
    /// `mastery != .fog`, this is a no-op: returns `current` unchanged, `event: nil`.
    public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult
}
```

```swift
// Packages/Core/Sources/Core/Time/CalendarDay.swift:7-38 (unmodified, task 02.4 already landed)
public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
    public let iso: String
    public init?(iso: String)
    public func adding(days: Int) -> CalendarDay
    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool
}
```

```swift
// Packages/Core/Sources/Core/Events/CoreEvent.swift:8-50 (unmodified, task 02.4 already landed; only the
// cases this task uses are reproduced)
public enum CoreEvent: String, CaseIterable, Equatable {
    case expeditionStarted = "expedition.started"
    case expeditionItemAnswered = "expedition.item_answered"
    case expeditionDiagnosisRequested = "expedition.diagnosis_requested"
    case expeditionNodeCleared = "expedition.node_cleared"
    case expeditionCompleted = "expedition.completed"
    case diagnosisNodeBlocked = "diagnosis.node_blocked"
    // ...remaining cases unused by this task
}
```

The future `Expedition` API this task consumes for D27 retries and for the run's initial composed slots
(`tasks/epic-02-task-06-fringe-compose-seam.md` §1/§2, quoted verbatim — task 02.6 is under review, not yet
committed to the repo at the time of this run; the bundle-defect note atop 02.6's own spec explains why its
signatures, not any earlier guess, are authoritative):

```swift
public enum SlotKind: String, Equatable {
    case newLearning
    case review
}

public struct ComposeSlot: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind
}

public struct ComposeResult: Equatable {
    public let slots: [ComposeSlot]
    public let skippedNodeIds: [String]
}

public enum Expedition {
    public static func compose(
        state: StudentState, bundle: ContentBundle, trail: Trail, marker: Marker, today: CalendarDay,
        queuedNodeId: String? = nil, unitExpeditionUnitId: String? = nil
    ) throws -> ComposeResult

    /// Reused by this task (D27 retries) and by 02.11 (Q-G probe availability).
    public static func selectItem(
        from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]
    ) -> ProbeItem?
}
```

`GraphIndex` (internal, same module, unmodified, re-read in this run):

```swift
// Packages/Core/Sources/Core/Validation/GraphIndex.swift:5-21
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

Precondition test-loading pattern this task follows (`Packages/Core/Tests/CoreTests/
MarkerTrailGenerationTests.swift:14-27`, re-read in this run):

```swift
private static var testsDir: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()  // CoreTests
}
private static var demoBundleDir: URL {
    testsDir
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // Core (package root)
        .deletingLastPathComponent()  // Packages
        .appendingPathComponent("data/demo")
}
private static func loadDemoBundle() throws -> ContentBundle {
    try BundleIO.read(from: demoBundleDir)
}
```

## §4 Implementation outline

Layer placement: layer ④ interaction, expedition W2 (`answer`), W3 (D27 tolerance rule), W5 (`end`,
summary, logs, abandoned). Consumes layer ③ (`Node.probeItems`, `why`, `answer`/`choices`) as read-only
input via the `ComposeResult` this task's `start` is handed. Writes nothing to disk; every function returns
a new `StudentState`/`ExpeditionRunState` value for the caller (EPIC 03/04) to hold and eventually persist.

**Precondition (hard dependency, not advisory, matching 02.4/02.5/02.6's own precondition pattern):** task
02.1 (interaction-contract v0.9.1 numeric-normalisation text — already committed, confirmed by re-reading
the file in this run) and task 02.6 (`Expedition.compose`, `.selectItem`, `ComposeSlot`, `ComposeResult`,
`SlotKind` — under review, not yet merged) must both be merged before this task's code compiles. Do not add
any 02.6 type or function yourself if it has not landed — that is 02.6's file scope, out of scope here (§2).

### 1. `ItemChecker.swift` — exact-rational numeric grammar

A private `Rational` value type: `numerator: Int`, `denominator: Int` (always `> 0`, kept in lowest terms
via `gcd`). Two constructors:

- `Rational.parse(_ raw: String) -> Rational?` — implements the contract's grammar exactly: trim leading/
  trailing whitespace (no other effect); optional leading sign (`+`/`-`, absent = positive); one or more
  digits (the integer part — `Int(...)` on this substring already discards insignificant leading zeros,
  e.g. `"007"` parses to `7`); an optional `.` followed by one or more digits (the decimal part — combine
  as `numerator = integerPart * 10^decimalDigitCount + Int(decimalDigits)`, `denominator = 10^decimalDigitCount`,
  so `"0.750"`'s three decimal digits reduce via `gcd` the same as two would, giving `3/4` — trailing zeros
  carry no significance because reduction removes them, not because they are special-cased); an optional
  `/` followed by one or more digits (multiply the running `denominator` by this value; reject if it parses
  to `0`, since `b ≠ 0`). Any leftover, unconsumed characters after these optional parts — or a missing
  mandatory digit group at any stage the grammar requires one — means the string does not parse: return
  `nil`. All arithmetic (the digit-group-to-`Int` conversions, the multiplication combining the decimal part,
  the final `gcd` reduction) uses Swift's overflow-reporting operators (`multipliedReportingOverflow`,
  `addingReportingOverflow`), never the trapping `+`/`*`; any overflow returns `nil` (unparseable → the
  contract's "never a crash" rule, §6 default).
- `Rational.exact(fromTolerance tolerance: Double) -> Rational` — decomposes the `Double`'s own IEEE-754
  bit pattern into an exact fraction (`significand` as an integer numerator, `2^exponent` folded into the
  denominator or numerator by direct integer bit-shift, never by floating-point multiplication or division)
  so that no floating-point comparison occurs anywhere in the final equality/tolerance check (I1). `0` maps
  to `Rational(numerator: 0, denominator: 1)` directly.

`ItemChecker`:

```swift
public enum ItemChecker {
    public static func check(item: ProbeItem, submitted: String) -> Bool {
        switch item.type {
        case .numeric:
            guard let answer = item.answer, let target = Rational.parse(answer.value),
                let submittedValue = Rational.parse(submitted)
            else { return false }
            if submittedValue == target { return true }
            let tolerance = Rational.exact(fromTolerance: answer.tolerance ?? 0)
            return submittedValue.absoluteDifference(from: target) <= tolerance
        case .mc:
            return submitted == item.correctChoiceId
        }
    }

    public static func correctAnswerDisplay(for item: ProbeItem) -> String {
        switch item.type {
        case .numeric:
            return item.answer?.value ?? ""
        case .mc:
            return item.choices?.first(where: { $0.id == item.correctChoiceId })?.latex ?? ""
        }
    }
}
```

A malformed `item.answer.value` (should never occur on an already-L0-passed bundle, but this task does not
re-validate — brief §3 R-6) is handled the same defensive way as a malformed submission: `Rational.parse`
returns `nil`, `check` returns `false`, never a crash.

### 2. `ExpeditionRun.swift` — new types

```swift
/// Always shown to the student before any next-item state is reachable (I3).
public struct ItemResult: Equatable {
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let correctAnswerDisplay: String
    public let why: String
    public let isRetry: Bool
}

/// The item currently awaiting an answer. `kind` carries the slot's original `newLearning`/`review`
/// classification through a D27 retry (a retry re-tests the same node/kind with a different item).
public struct CurrentItem: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind
    public let isRetry: Bool
}

/// The run's own value state, threaded by the caller through every `answer`/`resume` call alongside its
/// own copy of `StudentState` (which this type never embeds — see §1's hand-off note).
public struct ExpeditionRunState: Equatable {
    public var queue: [ComposeSlot]
    public var currentItem: CurrentItem?
    public var diagnosisUsed: Bool
    public var missCounts: [String: Int]
    /// Items whose answer has been shown this run. Public because this is the exact set task 02.11 must
    /// read when computing the Q-G "available" probe-item definition for the `expedition_second_miss`
    /// trigger (`tasks/arbitration/arbiter-02-predispatch.md` § Q-G) — `StudentState.probeLog` alone
    /// cannot answer "shown in the CURRENT run" because no run boundary is recorded there.
    public var shownItemIds: Set<String>
    public var itemPoolEmptyNodeIds: [String]
    public var results: [ItemResult]
    public var clearedNodeIds: [String]
    public var blockedNodeIds: [String]
    public var itemsAnswered: Int
    /// Non-nil exactly while the run is suspended waiting on a diagnosis event's `returned`. Non-nil implies
    /// `currentItem == nil`.
    public var suspendedForDiagnosisNodeId: String?
}

public struct StartOutcome: Equatable {
    public let run: ExpeditionRunState
    public let event: CoreEvent  // .expeditionStarted
}

public struct AnswerOutcome: Equatable {
    public let run: ExpeditionRunState
    public let state: StudentState
    public let result: ItemResult
    public let events: [CoreEvent]
}

public struct ExpeditionSummary: Equatable {
    public let itemCount: Int
    public let clearedNodeIds: [String]
    public let blockedNodeIds: [String]
    public let abandoned: Bool
}

public struct EndOutcome: Equatable {
    public let state: StudentState
    public let summary: ExpeditionSummary
    public let event: CoreEvent  // .expeditionCompleted
}
```

### 3. `ExpeditionRun` namespace

```swift
public enum ExpeditionRun {
    public static func start(compose: ComposeResult) -> StartOutcome {
        let first = compose.slots.first
        let run = ExpeditionRunState(
            queue: Array(compose.slots.dropFirst()),
            currentItem: first.map { CurrentItem(nodeId: $0.nodeId, item: $0.item, kind: $0.kind, isRetry: false) },
            diagnosisUsed: false, missCounts: [:], shownItemIds: [], itemPoolEmptyNodeIds: [],
            results: [], clearedNodeIds: [], blockedNodeIds: [], itemsAnswered: 0,
            suspendedForDiagnosisNodeId: nil)
        return StartOutcome(run: run, event: .expeditionStarted)
    }

    public static func answer(
        run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String,
        today: CalendarDay
    ) -> AnswerOutcome {
        guard let current = run.currentItem else {
            preconditionFailure("ExpeditionRun.answer called with no currentItem (suspended or ended)")
        }
        let correct = ItemChecker.check(item: current.item, submitted: submitted)
        let display = ItemChecker.correctAnswerDisplay(for: current.item)
        let result = ItemResult(
            nodeId: current.nodeId, itemId: current.item.id, correct: correct,
            correctAnswerDisplay: display, why: current.item.why, isRetry: current.isRetry)

        var nodes = state.nodes
        let priorNodeState = nodes[current.nodeId]
            ?? NodeState(mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
        let probeLog = state.probeLog + [
            ProbeLogEntry(
                day: today.iso, nodeId: current.nodeId, itemId: current.item.id, correct: correct,
                retry: current.isRetry)
        ]
        var events: [CoreEvent] = [.expeditionItemAnswered]
        var run = run
        run.shownItemIds.insert(current.item.id)  // local copy of a value type; see §6 "value-type mutation style"

        if correct {
            let correctItemIds = Set(
                state.probeLog.filter { $0.nodeId == current.nodeId && $0.correct }.map(\.itemId))
            let transition = MasteryTransitions.itemCorrect(
                current: priorNodeState, itemId: current.item.id, correctItemIds: correctItemIds, today: today)
            nodes[current.nodeId] = transition.nodeState
            if let event = transition.event {
                events.append(event)
                if event == .expeditionNodeCleared { run.clearedNodeIds.append(current.nodeId) }
            }
            run.currentItem = nextItem(from: &run)
        } else if priorNodeState.mastery == .cleared {
            let transition = MasteryTransitions.itemMissReview(current: priorNodeState, today: today)
            nodes[current.nodeId] = transition.nodeState
            applyMiss(nodeId: current.nodeId, kind: current.kind, run: &run, state: &nodes,
                priorNodeState: transition.nodeState, bundle: bundle, probeLog: probeLog, events: &events)
        } else {
            applyMiss(nodeId: current.nodeId, kind: current.kind, run: &run, state: &nodes,
                priorNodeState: priorNodeState, bundle: bundle, probeLog: probeLog, events: &events)
        }

        run.itemsAnswered += 1
        run.results.append(result)
        let newState = StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: nodes, trail: state.trail,
            expeditionLog: state.expeditionLog, probeLog: probeLog, installDay: state.installDay,
            consentOn: state.consentOn)
        return AnswerOutcome(run: run, state: newState, result: result, events: events)
    }

    public static func resume(run: ExpeditionRunState) -> ExpeditionRunState {
        guard run.suspendedForDiagnosisNodeId != nil else {
            preconditionFailure("ExpeditionRun.resume called with nothing suspended")
        }
        var run = run
        run.suspendedForDiagnosisNodeId = nil
        run.currentItem = nextItem(from: &run)
        return run
    }

    public static func end(
        run: ExpeditionRunState, state: StudentState, today: CalendarDay, abandoned: Bool
    ) -> EndOutcome {
        let entry = ExpeditionLogEntry(
            day: today.iso, itemCount: run.itemsAnswered, cleared: run.clearedNodeIds.count,
            blocked: run.blockedNodeIds.count, abandoned: abandoned,
            diagnosisEvents: run.diagnosisUsed ? 1 : 0)
        let newState = StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: state.nodes, trail: state.trail,
            expeditionLog: state.expeditionLog + [entry], probeLog: state.probeLog,
            installDay: state.installDay, consentOn: state.consentOn)
        let summary = ExpeditionSummary(
            itemCount: run.itemsAnswered, clearedNodeIds: run.clearedNodeIds,
            blockedNodeIds: run.blockedNodeIds, abandoned: abandoned)
        return EndOutcome(state: newState, summary: summary, event: .expeditionCompleted)
    }

    // MARK: - Private (step 4)

    /// Pops `run.queue` into a `CurrentItem` (drawing that node's own item via the `ComposeSlot` it
    /// already carries — no re-draw here; `compose` already drew each slot's item). `nil` when the queue
    /// is empty (the run is naturally complete; the caller should call `end`).
    private static func nextItem(from run: inout ExpeditionRunState) -> CurrentItem? { ... }

    /// The D27 branch for a miss, shared by the fog/blocked path and the review path (§6 default 1):
    /// increments `missCounts[nodeId]`; on the first miss, draws a retry item via
    /// `Expedition.selectItem(from:excluding:probeLog:)` excluding `run.shownItemIds` — if `nil` (no
    /// unused item), appends `nodeId` to `run.itemPoolEmptyNodeIds` and advances to the next queue item
    /// instead of retrying (the arbiter's technical default, quoted §3); on the second miss with
    /// `run.diagnosisUsed == false`, sets `run.suspendedForDiagnosisNodeId = nodeId`,
    /// `run.diagnosisUsed = true`, `run.currentItem = nil`, appends `.expeditionDiagnosisRequested` to
    /// `events`; on the second miss with `run.diagnosisUsed == true`, calls
    /// `MasteryTransitions.diagnosisBlocked(current: priorNodeState)`, writes the result into `state`,
    /// appends `nodeId` to `run.blockedNodeIds` and `.diagnosisNodeBlocked` to `events` when that call's
    /// `event` is non-nil, and advances `run.currentItem` to the next queue item.
    private static func applyMiss(
        nodeId: String, kind: SlotKind, run: inout ExpeditionRunState, state: inout [String: NodeState],
        priorNodeState: NodeState, bundle: ContentBundle, probeLog: [ProbeLogEntry],
        events: inout [CoreEvent]
    ) { ... }
}
```

3. Error codes: this task throws **no** `CoreError`. The single error-taxonomy touchpoint is
   `EXP_ITEM_POOL_EMPTY` (`contracts/error-codes.json`, quoted §3), which this task never throws — per §6
   default, an empty retry pool is recorded in `run.itemPoolEmptyNodeIds` and the run continues, matching
   that code's `"recoverable": true` registration and 02.6's own identical disposition for the same code.
4. Storage/asset access: none. Every function is a pure value transformation; no file I/O anywhere in
   either new file.
5. Model-calling path: none exists in this task. No confidence threshold or Tier-0 fallback applies — I2 is
   satisfied by the structural absence of any model/adapter parameter or import.
6. Smoke check: `( cd Packages/Core && swift build -c release --product core-cli )` — must be green
   (compiles both new files even though `core-cli`'s `main.swift` calls neither, matching every prior
   EPIC 02 task's own smoke-check pattern).

## §5 Test plan (risk: seam — full plan)

- **T1 happy path** (`ItemCheckerTests.swift`, `ExpeditionRunTests.swift`; real `data/demo` loaded via
  `BundleIO.read` per the §3 loading pattern unless noted):
  - AC1, AC2: table-driven loops over every real `data/demo` node/item (own answer correct; every
    `wrong_answers[]`/non-correct `choices[]` entry incorrect).
  - AC3: normalisation scenario assertions on hand-built `ProbeItem` values.
  - AC5: `start` scenario assertion.
  - AC6, AC7, AC8, AC9, AC10, AC11, AC13: `ExpeditionRun.answer`/`.resume`/`.end` scenario assertions,
    driven on a small hand-built `ComposeResult` over real `data/demo` nodes (reusing `exponent-laws`/
    `polynomials`/`simplifying-expressions` from the arbiter's own Q-G reachability sequence, quoted in
    `tasks/arbitration/arbiter-02-predispatch.md` § Q-G, re-read in this run, as a ready-made two-node,
    two-miss fixture — this spec does not restate that sequence here since this task does not implement
    Q-G itself; it only needs *a* real bundle plus a hand-built `ComposeResult`, not that exact sequence).
- **T2 negative — invalid input rejected at the boundary:**
  - AC4: the table-driven malformed-string cases, plus the fuzzed property test (T4 below).
  - `ItemChecker.check` on an `mc` item with a `submitted` string that names no `choices[].id` at all
    returns `false` (no crash, no special-case needed — asserted directly).
  - A `numeric` item whose own `answer` is `nil` (schema-illegal on a validated bundle, but defensively
    constructed in the test) returns `false` from `check`, never crashes.
- **T3 error-taxonomy:** `CoreError.expItemPoolEmpty.rawValue == "EXP_ITEM_POOL_EMPTY"` (re-run via 02.4's
  unmodified `ErrorRegistryTests`, not re-implemented) stays green, confirming the registry entry this
  task's `itemPoolEmptyNodeIds` accounting conceptually corresponds to remains registered and this task
  invents no new code.
- **T4 conformance per requirements §B.1 / cited contract and invariants:**
  - I1/I10: a signature-level assertion that `ItemChecker.check`'s parameter list is exactly `(item:
    ProbeItem, submitted: String)` — no model/adapter parameter exists to pass.
  - I3: a property test drives a full run (real `data/demo`, generated correct/incorrect outcome sequence
    via a new `PropertyGen` generator, §2) through `start`/`answer`* and asserts every `ItemResult` in
    `run.results` carries non-empty `correctAnswerDisplay` and non-empty `why`.
  - AC4's fuzz half: a property test generates random `String`s (arbitrary Unicode scalars, including empty
    and whitespace-only) as `submitted` against every real `data/demo` `numeric` item and asserts
    `ItemChecker.check` never traps and always returns a `Bool`.
  - AC12: the D27 property test — `run.diagnosisUsed` never transitions `true → false`, and it transitions
    `false → true` at most once across a full generated run.
  - I14: `xcrun swift-format lint --strict` passes over both new files (mechanical); a dedicated grep
    assertion (mirroring every prior EPIC 02 task's own `Date()` scan) confirms zero occurrences of
    `Date()` in `ItemChecker.swift` and `State/ExpeditionRun.swift`; `Core`'s existing
    `coreImportBoundary()` test is re-run unmodified and stays green.
- **T5 negative control for every regression guard:**
  - Guard "numeric comparison is exact-rational, never `Double`-based": reconstruct (locally, in the test
    file — do not modify product code) a naive `Double(submitted) == Double(answer.value)` comparator and
    show it treats `"3/4"` as unparseable (`Double("3/4") == nil`), wrongly rejecting a submission the real
    grammar accepts as equal to `"0.75"` — proving the real parser's `/`-grammar branch is load-bearing.
  - Guard "D27 retry excludes the just-missed item via `run.shownItemIds`, not merely re-drawing": on a
    real two-item `data/demo` node, reconstruct a variant that calls `Expedition.selectItem` with an empty
    `excluding` set on retry and show it can re-select the identical item id that was just missed
    (deterministic `selectItem` would, since the missed item now has a fresher `probeLog` entry than the
    other candidate and "least recently used" prefers the *other* one — construct the specific case where
    the naive call's own tie-break still reselects the same id) — proving the real implementation's
    `excluding: run.shownItemIds` is necessary, not redundant.
  - Guard "the spent-diagnosis second miss reuses `MasteryTransitions.diagnosisBlocked`'s existing `.fog`
    guard rather than force-setting `.blocked`": reconstruct a variant that force-sets
    `mastery = .blocked` unconditionally on a spent-diagnosis second miss and show it wrongly flips a
    `.cleared` review node's mastery to `.blocked` (AC10's scenario) — proving the real implementation's
    reuse of the guarded, already-tested transition is load-bearing.
  - Guard "`diagnosisUsed` is monotone (`false → true` at most once, never reset)": reconstruct a variant
    that resets it to `false` after `resume` and show a second diagnosis event becomes reachable later in
    the same generated run — the negative control for AC12/the Properties bullet's "at most one diagnosis
    event per run".
- **T6 idempotency / no-leak:** `ItemChecker.check`/`.correctAnswerDisplay`, called twice with
  byte-identical arguments, return identical results (pure). `ExpeditionRun.start`/`.answer`/`.resume`/
  `.end`, called twice with byte-identical arguments (fresh `ExpeditionRunState`/`StudentState`/
  `ContentBundle` values each call, not a reused mutated variable), return `Equatable`-equal outcomes both
  times. No `StudentState`/`ContentBundle` value passed in is mutated by any function — this task ships no
  writer of any kind (mirroring every prior EPIC 02 task's own T6 disposition for a non-persistence task).

## §6 Decision defaults

- IF a miss on a `review`-kind slot (a `.cleared` node) should skip the D27 retry/diagnosis/blocked
  machinery entirely (treating D27 as a new-learning-only concern) THEN it should not: the mastery table's
  own `cleared | item_miss(node) (review)` row (quoted §3) appends "tolerance per §2" to its side effects,
  which this task reads as binding — the review-miss path both resets the ladder (`itemMissReview`) AND
  feeds `run.missCounts` like any other node. This is the single most consequential reading choice in this
  task; it is stated explicitly here because neither §1 (Mastery) nor §2 (Expedition) states the
  interaction between the two rows in prose, only through this one cross-reference.
- IF the "second miss with the run's Door A event already spent → blocked" transition (expedition Q5)
  needs its own new mastery-transition function THEN it does not: this task calls the already-landed
  `MasteryTransitions.diagnosisBlocked(current:)` (02.4) unconditionally on that path, relying on its
  existing `mastery == .fog` guard to make it a correct no-op on `.cleared`/already-`.blocked` nodes (AC10)
  — re-deriving a parallel "blocked" transition here would duplicate 02.4's already-tested guard and risk
  disagreeing with it.
- IF `ExpeditionRun.resume` should take a diagnosis-outcome value or a `StudentState` parameter (so that a
  `capped`/`refuted`/`confirmed`/`unconfirmed` terminal could change how the run resumes) THEN it must not:
  `contracts/interaction-contract.md` § 4's `returned` line (quoted §3) says control returns to "its next
  item" unconditionally, with no branch on the terminal reached. `resume`'s only effect is popping the
  run's own queue; whatever `StudentState` diagnosis produced is threaded into the caller's *next*
  `answer` call, not through `resume` itself (§1). This is the load-bearing design choice that lets 02.11
  consume this file's API without ever editing it.
- IF `ExpeditionRun.answer`/`.resume` should silently no-op (return the input unchanged) when called out of
  order (`currentItem == nil` for `answer`; `suspendedForDiagnosisNodeId == nil` for `resume`) rather than
  trap THEN they should trap (`preconditionFailure`): both conditions are caller-ordering bugs in the App
  layer, not student-input or bundle-data problems, matching `CalendarDay.adding(days:)`'s own
  `preconditionFailure` precedent for an already-validated invariant (`Packages/Core/Sources/Core/Time/
  CalendarDay.swift:29`, re-read in this run). No registered `CoreError` describes "the caller invoked the
  run machine out of order," and inventing one would be an unauthorized registry addition this task's file
  scope does not permit (§2). Per the "no crash-test for a precondition trap" convention this codebase
  already follows (no prior EPIC 02 task writes a test that intentionally triggers a `preconditionFailure`),
  §5 does not include a trapping test for either guard.
- IF `end(..., abandoned: true)` should emit no event, or a different event, from the normal-completion
  case THEN it emits the same `.expeditionCompleted` either way: `CoreEvent`'s closed set (§5, quoted §3)
  has no dedicated "abandoned" event, and `ExpeditionLogEntry.abandoned` is the schema's own, already-
  landed signal for this distinction — inventing a second event would duplicate that signal outside the
  registry this task must not bump.
- IF a numeric string that overflows `Int` during parsing (the integer part, a decimal-combined value, or
  the denominator) should trap or silently produce a wrong value THEN it must do neither: `Rational.parse`
  uses Swift's overflow-reporting arithmetic operators throughout and returns `nil` (unparseable → a miss,
  never a crash) on any overflow — the contract's "never a crash" line (quoted §3) applies to every
  submission, however pathological, not only to grammatically malformed ones.
- IF `Rational.exact(fromTolerance:)`'s bit-decomposition branch needs a `data/demo` assertion THEN it does
  not have one: every item's `answer.tolerance` in real `data/demo` is absent (default `0`), confirmed by
  re-reading `data/demo/nodes.json` in this run (no `"tolerance"` key appears anywhere in the file). This
  function is implemented for correctness on future, non-demo bundles per the contract's general tolerance
  rule, and its presence-but-`data/demo`-untested status is recorded here rather than silently assumed,
  mirroring 02.5's own disposition for its unit-index-ambiguity branch and 02.6's for its undergraduate-
  extension branch.
- IF `ItemChecker.swift` and `State/ExpeditionRun.swift` should sit at whatever exact paths the context
  bundle sketched THEN the bundle's own hedge governs: `ItemChecker.swift` stays at the bundle's unhedged,
  root-level path (`Packages/Core/Sources/Core/ItemChecker.swift`); `ExpeditionRun.swift` is placed under
  `State/` (`Packages/Core/Sources/Core/State/ExpeditionRun.swift`) rather than the bundle's own hedged
  suggestion ("or similar name") at root, for consistency with every other EPIC 02 state-machine file
  (`State/MasteryTransitions.swift`, `State/MarkerTrailGeneration.swift`, `State/Expedition.swift`, all
  confirmed present at those paths in this run) — a placement choice, not an asserted fact about any
  source.
- IF `Tests/CoreTests/Support/PropertyGen.swift` is out of this task's file scope (as 02.6 treated it, since
  02.6 needed no new generator) THEN it is not: that file's own doc comment (re-read in this run) names
  "02.5-02.7, 02.10-02.12" as tasks that append generator functions there rather than duplicating a
  parallel helper — 02.7 is explicitly listed, so this task's property tests (AC12, T4, T5's fuzz case) add
  whatever generator(s) they need to that same file, append-only.
- **Value-type mutation style** (orchestrator correction after review BLOCK, 2026-09-10): `ExpeditionRunState`
  stays a `struct` (a value type), and its stored properties are `public var`, not `let`. Every public
  function takes `run` by value and returns a new `ExpeditionRunState`. Internally it mutates a local
  `var run = run` copy, and private helpers may take `inout ExpeditionRunState`, as the §4 code does. No
  caller's value is ever mutated in place: the struct is copied at every public boundary, so "pure function
  of its inputs" still holds (T6 idempotency). `public var` does not widen 02.11's access in any way that
  matters — 02.11 only reads fields and never edits this file. Test code must not construct or mutate a run
  by hand except through the public functions.

Standing defaults: identifiers and timestamps follow `contracts/data-model.md` (calendar days only,
`today: CalendarDay` always caller-injected, never a live clock read — I14); no model call exists anywhere
in this task's code (I2); no field is added to `StudentState`/`NodeState`/`Marker` by this task (I5) — every
new type carries only node/item ids, an enum case, booleans, small integers, and already-schema-legal
display strings (`why`, the correct-answer display, both sourced verbatim from the bundle's own
`ProbeItem`, never authored here). No node's `paraphrase`/`explanation`/`workedExamples` is read or touched
by this task (I6) — `ItemChecker`/`ExpeditionRun` read only `Node.probeItems` (via the `ComposeSlot`s
`Expedition.compose` already resolved) and each `ProbeItem`'s own `id`/`type`/`answer`/`wrongAnswers`/
`choices`/`correctChoiceId`/`why`.

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` —
  clean over both new source files and both new test files.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6) pass, including AC1–AC13.
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` (both unmodified, 02.4's files) stay green.
- No file under `Packages/Core/Sources/Core` contains the literal `Date()` (I14).
- Conforms to every contract section cited in §3 (`contracts/interaction-contract.md` §§1, 2, 4, 5;
  `contracts/data-model.md` § ProbeItem, § StudentState; `docs/epics/epic-02-core-behaviour.md` § 9
  Technical defaults; `contracts/domain-glossary.md` § Expedition, § Retry) and to every invariant listed
  in §1 (I1, I2, I3, I5, I10, I14, D27).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and unaffected by
  this task's file scope).

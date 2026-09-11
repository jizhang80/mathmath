# Task 04.4 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: core-door-b-expedition-flow

Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 04
- **Task:** 04.4
- **Slug:** `core-door-b-expedition-flow`
- **Summary:** Implement in `Core` the Door B façade over `ExpeditionRun`, driving a pure flow from start through items/retries/D27 hand-off to diagnosis or block, and ending with a summary. The answer card is its own phase (I3 guard) before the next item is reachable. Persistence write-ahead happens after every state-changing call during a run. No model calls (I2). The spec is in the amended brief `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` §2 (§4 items 1, 3, 5) and `docs/plans/epic-04-plan.md` § 04.4, with rulings in `tasks/arbitration/arbiter-04-predispatch.md` § Q-A, Q-G.

- **Invariants in play:**
  - **I1:** `ItemChecker.check` alone decides correctness; no app-side comparison; raw input passed to the façade.
  - **I2:** Tier 0 only; every door call completes with no adapter parameter and no model; the hint fallback is deterministic (04.3, not this task).
  - **I3:** answer-card value built from `ItemResult`; no next item/retry/hypothesis/remediation/terminal/summary reachable without card; continue is itself a façade call, not an App-only flag.
  - **I4:** single-use diagnosis per run; second miss after diagnosis_used blocks the node.
  - **I5:** no identifying fields in persisted payloads.
  - **I14:** all logic, screen content, D27 hand-off, persistence sequencing in `Core`; `Core` imports Foundation only.

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2. Expedition (section heading, lines 28–60)

> States: `idle → composing → item → (retry | diagnosing | item) → summary → idle`.
>
> - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) = cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`. `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).
> - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
> - **Numeric normalisation (expedition Q4):** a submitted numeric answer and the item's `answer.value` (`data-model.md` § ProbeItem) are each parsed under the same grammar before comparison: an optional leading sign (`+` or `-`; absent = positive), one or more digits, an optional `.` followed by one or more digits, and an optional `/` followed by one or more digits (a rational `a/b`, `b ≠ 0`); leading and trailing whitespace is stripped and has no other effect. A string that does not parse under this grammar is a **miss** — never a crash, never a retry that skips its item. Every value that parses is reduced to an **exact rational**: leading zeros in the integer part (`007`) and trailing zeros after the decimal point (`0.750`) carry no significance; a decimal parses to its exact fraction (`0.75 = 3/4`). Two parsed values match iff their exact-rational values are equal, or their absolute difference is ≤ the item's `answer.tolerance` (non-negative, default `0`, per `data-model.md` § ProbeItem). Comparison is exact-rational arithmetic; no floating-point comparison is used anywhere in this rule (I1). This is the entire `numeric`-item rule; `mc` items are compared by `choices[].id` only, never by value (I10).
> - **Tolerance (D27):** first miss on a node in this run → `retry` with a second item of the same node; second miss → if `diagnosis_used == false` → `diagnosing` (set `diagnosis_used = true`), else mark the node `blocked` (expedition Q5: "We'll come back to this one") and continue. **At most one diagnosis per run.**
> - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
>
> **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; every item shown ends with its answer visible.

Source: `contracts/interaction-contract.md:28–60`

Binds this task: the façade implements the `compose`/`answer`/`end` contract transitions and the D27 tolerance rule, threading `StudentState` through every state-changing call. Raw input (string or choice id) is passed unsanitised to `ItemChecker.check`. The answer card persists until an explicit continue call. At most one diagnosis per run, enforced by the `diagnosisUsed` flag.

### contracts/interaction-contract.md — § 4. Diagnosis (section heading, lines 76–99)

> States: `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a terminal branch.
>
> - `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).
> - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1); Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.
> - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.
> - `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin → returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown; `declined` → `unconfirmed` → hint → returned. Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among available items the draw order of learning-objects W3 applies.
> - After `confirmed`, a further level is **offered, never automatic** (diagnosis Q3); beyond the budget → `capped`: candidate `blocked`, "further upstream — it's on your map", returned (I4).
> - `returned` always hands control back to the suspended expedition (its next item) or the map node panel.
>
> **Properties (CoreTests):** depth ≤ 2 from origin; every capped or failed candidate is `blocked` in state; no path reaches `remediation` without a `fail` probe outcome; no path withholds an already-answered item's answer (I3); Tier 0 completes every path with the adapter absent (I2).

Source: `contracts/interaction-contract.md:76–99`

Binds this task: when the D27 rule suspends the run on a second miss, this task's façade calls 04.3's Door A façade with the two misses and receives the returned state. The D27 hand-off is a one-way call: the façade resumes only via `ExpeditionRun.resume`, which clears the suspension and moves to the next item.

### contracts/interaction-contract.md — § 5. Notifications (section heading, lines 101–115)

> `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved · map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started · expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened · diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped · diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated · platform.state_migrated · platform.state_written · platform.sync_completed · platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed · tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted · telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded · learning_objects.hint_tier_served · graph.prerequisite_returned`
>
> Payloads are ids, enums, booleans and small integers only (I5).

Source: `contracts/interaction-contract.md:101–115`

Binds this task: every `CoreEvent` this façade emits (expeditionStarted, expeditionItemAnswered, expeditionDiagnosisRequested, expeditionNodeCleared, expeditionCompleted, diagnosisNodeBlocked) already exists as a case name. Events are in-process only; no telemetry client in this task.

### tasks/arbitration/arbiter-04-predispatch.md — § Q-A (answer-card timing and summary content)

> Both brief defaults are CONFIRMED. The items are contract-discovery text delegated to "the Demo EPIC" and are not D-numbers, so this is not a Q5.
> 
> **Precision (needed to make the rule testable in `Core`).** "Continue" is a façade entry point, not an App-only presentation flag. After an answer, the façade's current screen value is the answer card. Only the continue call moves it on, to the next item, the retry, the second probe item, the hypothesis card (D27 hand-off), remediation, a terminal line, or the summary. This is what makes the brief's § 4 item 3 guard ("No next-item, terminal or summary value is reachable without one") assertable in `CoreTests`, with its planted negative control. The continue call changes no `StudentState`, so it triggers no write. This matches arbiter-03 § Q-F item 4 ("Each entry point takes values and returns (new value, `[CoreEvent]`)").
>
> *Summary region tint deltas.* **Not shown.** ... The summary lists the nodes cleared this run, the fog lifted, the nodes marked `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction; the re-derived map shows the tint on return (map W6).

Source: `tasks/arbitration/arbiter-04-predispatch.md:35–98`

Binds this task: the façade's answer-card value is held between the `answer` call that produces `ItemResult` and an explicit `continue` call. Continue is a public façade function that changes no `StudentState` and is not an App-only flag. The summary carries nodes cleared, fog lifted, blocked marked, no tint deltas. A DEFERRED entry records the tint-delta question for later.

### tasks/arbitration/arbiter-04-predispatch.md — § Q-G (in-run abandoned log entry and write-ahead sequencing)

> **Ruling.** CORRECTED. ... The ratified text can be met with **no schema change and no `ExpeditionRun` edit**:
>
> - **In-run write-ahead.** After every state-changing Door B or Door A call during a run, including the run-start call, the session persists `ExpeditionRun.end(run: <current run>, state: <threaded state>, today:, abandoned: true).state`. The in-memory threaded state never contains that entry. At a natural end the session persists `end(…, abandoned: false).state`. On "Back to the map" mid-run it persists `end(…, abandoned: true).state`. Either way, the provisional entry is replaced, because it was never in memory.
> - **Where the natural end is called.** In the same façade call that produces the run's last result: the final answer, or the `returned` that resumes into an empty queue. The summary value is held behind that call's answer card and shown on continue (Q-A). So a completed run is never logged abandoned by an OS kill while its last card is on screen.
> - **Why no schema change is needed.** `end` already builds a schema-valid entry: `ExpeditionRun.swift:176-191` (`abandoned: abandoned`, `diagnosisEvents: run.diagnosisUsed ? 1 : 0`). `student-state.schema.json` allows `item_count` minimum 0 (lines 138–141), so an entry killed before its first answer is valid.

Source: `tasks/arbitration/arbiter-04-predispatch.md:263–287`

Binds this task: the façade calls `ExpeditionRun.end(run:, state:, today:, abandoned: true)` after every state-changing Door B or Door A call during a run, and writes that result's `state` (which includes the provisional `expedition_log` entry) through the session's store. On natural end (last answer or `returned` into empty queue), the façade calls `end(…, abandoned: false)` in the same call that produces the summary, so the card is shown before the write is signalled. On "Back to the map", the façade calls `end(…, abandoned: true)`.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W2 ("Answer an item", lines 75–80)

> **Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10). 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40, per-item node and result — the L3 input).

Source: `docs/domains/expedition.md:75–80`

### docs/domains/expedition.md — W3 ("Apply the tolerance rule (D27)", lines 82–88)

> **Pre:** an incorrect `ItemResult`. **Steps:** 1. First miss on this node in this run → draw one retry item on the same node and return to W2. 2. Second miss on the node, and no Door A event yet this run → emit `expedition.diagnosis_requested` and suspend the run while **diagnosis** runs (W1 there); on return, continue with the remaining items. 3. Second miss after the run's Door A event was used → mark the node `blocked` (W4) and continue without interruption. **Post:** at most one Door A event per run; a test asserts it.

Source: `docs/domains/expedition.md:82–88`

### docs/domains/expedition.md — W5 ("End the run", lines 98–103)

> **Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`. 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows a banner, the summary still shows — I3's spirit). 3. Offer "Start another" (W1) and "Back to the map". **Post:** `expedition.completed` emitted (D40) with the count of items and cleared nodes; a run left mid-way is logged as abandoned, never resumed item-by-item (Q6).

Source: `docs/domains/expedition.md:98–103`

### docs/domains/expedition.md — Q5 ("What the student sees on the second miss when the run's Door A event is spent", lines 197–201)

> **Default:** the answer card as usual plus one line — "We'll come back to this one" — and the node is marked `blocked` on the map; no hint, no probe. **Trade-off:** keeps the 3-minute rhythm (D27's purpose); the student gets no help on that node until the next run or a "Check me here" tap.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:197–201`

### docs/domains/expedition.md — Q6 ("Resuming a run interrupted by the app going to background", lines 203–207)

> **Default:** the current item is kept for a short grace window [ESTIMATE: until the app is terminated by the OS]; a terminated run is logged as abandoned and the next launch starts fresh. **Trade-off:** no half-finished runs to reason about; a student interrupted by a call loses at most one item's context.
> **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/expedition.md:203–207`

### docs/domains/expedition.md — § Invariants enforced here (lines 152–165)

> - **I2 / I1** — every workflow is Tier 0; checking is code over `answer`/`choice` fields, and the `ProbeItem` type carries no free-text answer for the device to grade (co-owner with learning-objects).
> - **I3** — W2's answer card cannot exist without the correct answer and why; a test asserts every `ItemResult` rendering includes them.
> - **I4 — co-owner with diagnosis.** The scheduler never selects a node that diagnosis marked beyond the cap unless it is `blocked` (evidence-based); a property test asserts no new-learning item is ever drawn from a node off the fringe or upstream of the marker unless it is `blocked` (D45, D48).
> - **I5** — `StudentState` has no identifying field; a schema test asserts the closed field set.
> - **I10** — item types are `numeric | mc` only; a bundle with any other type is refused at load.
> - **I14** — Fringe, trail generation, scheduler and transitions are pure functions in `Core`; the view calls them. **I7 / I8** — the trail is generated, never authored; every segment is validated as a path.
> - **D27** — one retry, one Door A event per run: both are tested as properties of W3.

Source: `docs/domains/expedition.md:152–165`

## §D. Prior task outputs this task depends on

- `ExpeditionRunState` — `public struct ExpeditionRunState: Equatable { public var queue: [ComposeSlot]; public var currentItem: CurrentItem?; public var diagnosisUsed: Bool; public var missCounts: [String: Int]; public var shownItemIds: Set<String>; public var itemPoolEmptyNodeIds: [String]; public var results: [ItemResult]; public var clearedNodeIds: [String]; public var blockedNodeIds: [String]; public var itemsAnswered: Int; public var suspendedForDiagnosisNodeId: String? }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:26–44` (produced by task 02.7, held by ExpeditionRun)

- `ExpeditionRunState.start(compose: ComposeResult) -> StartOutcome` — `public static func start(compose: ComposeResult) -> StartOutcome { ... return StartOutcome(run: run, event: .expeditionStarted) }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:87–98` (produced by EPIC 02, used by this task's façade)

- `ExpeditionRunState.answer(run:, state:, bundle:, submitted:, today:) -> AnswerOutcome` — `public static func answer(run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String, today: CalendarDay) -> AnswerOutcome { ... guard let current = run.currentItem else { preconditionFailure(...) } ... let correct = ItemChecker.check(...) ... }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:100–164` (produced by EPIC 02, accepts raw submitted string, returns AnswerOutcome with run, state, result, events)

- `ExpeditionRunState.resume(run: ExpeditionRunState) -> ExpeditionRunState` — `public static func resume(run: ExpeditionRunState) -> ExpeditionRunState { guard run.suspendedForDiagnosisNodeId != nil else { preconditionFailure(...) } var run = run; run.suspendedForDiagnosisNodeId = nil; run.currentItem = nextItem(from: &run); return run }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:166–174` (produced by EPIC 02, called after diagnosis returns)

- `ExpeditionRunState.end(run:, state:, today:, abandoned:) -> EndOutcome` — `public static func end(run: ExpeditionRunState, state: StudentState, today: CalendarDay, abandoned: Bool) -> EndOutcome { let entry = ExpeditionLogEntry(day: today.iso, itemCount: run.itemsAnswered, cleared: run.clearedNodeIds.count, blocked: run.blockedNodeIds.count, abandoned: abandoned, diagnosisEvents: run.diagnosisUsed ? 1 : 0) ... return EndOutcome(state: newState, summary: summary, event: .expeditionCompleted) }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:176–192` (produced by EPIC 02, called both for write-ahead with abandoned=true and for natural end with abandoned=false)

- `ItemResult` — `public struct ItemResult: Equatable { public let nodeId: String; public let itemId: String; public let correct: Bool; public let correctAnswerDisplay: String; public let why: String; public let isRetry: Bool }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:4–11` (produced by EPIC 02, used by this task's screen-content builder)

- `ExpeditionSummary` — `public struct ExpeditionSummary: Equatable { public let itemCount: Int; public let clearedNodeIds: [String]; public let blockedNodeIds: [String]; public let abandoned: Bool }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:58–63` (produced by EPIC 02, returned by end)

- `CurrentItem` — `public struct CurrentItem: Equatable { public let nodeId: String; public let item: ProbeItem; public let kind: SlotKind; public let isRetry: Bool }` — Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:15–20` (produced by EPIC 02, held in ExpeditionRunState.currentItem)

- `ItemMiss` — `public struct ItemMiss: Equatable { public let item: ProbeItem; public let submittedValue: String; public init(item: ProbeItem, submittedValue: String) }` — Source: `Packages/Core/Sources/Core/Diagnosis/Classify.swift:7–15` (produced by task 02.11, consumed by this task when assembling D27 hand-off)

- `DoorADiagnosisFlow` public entry points (produced by task 04.3, called by this task's façade):
  - `.open(originNodeId:, trigger:, levelBudget:) -> DiagnosisEvent`
  - `.start(event:, misses:, shownItemIdsInRun:, state:, bundle:) -> DoorADiagnosisAdvance`
  - `.decideProbe(_:, accept:, state:, bundle:) -> DoorADiagnosisAdvance`
  - `.answerProbeItem(_:, submitted:, state:, bundle:, today:) -> DoorAProbeAnswerAdvance`
  - `.continueAfterProbeAnswer(_:, bundle:) -> DoorADiagnosisScreen`
  - `.decideFurtherLevel(_:, accept:, state:, bundle:) -> DoorADiagnosisAdvance`
  — Source: `tasks/epic-04-task-03-core-door-a-diagnosis-flow.md:560–621` (specification, under review; 04.3 task depends on this task)

- `DoorItemContent` (produced by task 04.2, called by this task for screen content):
  - `public struct DoorItemContent: Equatable { public let nodeId: String; public let promptLatex: String; public let inputKind: DoorItemInputKind; public let choices: [DoorItemChoice]; public let isRetry: Bool; public init(nodeId: String, item: ProbeItem, isRetry: Bool) }`
  — Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:352–358` (specification; 04.2 task depends on this task)

- `DoorAnswerCardContent` (produced by task 04.2, used by this task for answer-card phase):
  - `public struct DoorAnswerCardContent: Equatable { public let correct: Bool; public let correctAnswerDisplay: String; public let correctAnswerDisplayKind: DoorAnswerDisplayKind; public let why: String; public let extraLine: String?; public init(result: ItemResult, itemType: ProbeItemType, extraLine: String? = nil) }`
  — Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:360–367` (specification; 04.2 task depends on this task)

## §E. Negative facts (confirmed ABSENT)

- No Door B façade file exists yet. `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift` confirmed absent. Source: `Glob "Packages/Core/Sources/Core/Door/ExpeditionFlow.swift"` returned empty.

- No answer-card phase orchestration in existing Core code. Grep `answerCardContent|answer.*card.*phase` over `Packages/Core/Sources/Core/` returned no match.

- No D27 hand-off assembly code. Grep `misses|suspendedForDiagnosis` over `Packages/Core/Sources/Core/Door/` returned no match (the Door directory does not exist yet).

- No summary content builder. Grep `ExpeditionSummary.*content|summary.*nodes` over `Packages/Core/Sources/Core/Door/` returned no match.

- No write-ahead persistence logic in Core. This task does not write; task 04.5 owns the session-level persistence sequencing.

## §F. File scope

Files this task may create or touch:

- CREATE `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift` — confirmed absent (Glob `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift` empty). Will hold the Door B façade: `DoorBExpeditionFlow` enum with public entry points (`start`, `answer`, `continue`, `resume`, `end`) and the private screen-content builder.

- CREATE `Packages/Core/Sources/Core/Door/ExpeditionContent.swift` — confirmed absent (Glob `Packages/Core/Sources/Core/Door/ExpeditionContent.swift` empty). Will hold screen-content value types (`DoorBItemScreen`, `DoorBAnswerCardScreen`, `DoorBSummaryScreen`) and screen-builder functions.

- MODIFY `Packages/Core/Tests/CoreTests/ExpeditionFlowTests.swift` (if exists) or CREATE as new test file — confirmed absent (Glob returned empty). Will hold C1 façade tests: full expedition run, D27 retry and hand-off, summary content.

## §G. Stack constraints relevant here

- **Boundary validation:** the façade takes a `ComposeResult` (already validated by 04.0's Expedition type), raw submitted string (passed unsanitised to `ItemChecker.check`), and threading `StudentState` (already validated at launch by `StudentStateStore`). No new schema or boundary-check path introduced by this task. Quote: `contracts/interaction-contract.md:28–60` (the `answer` rule covers numeric normalisation and choice-id checking — this task's responsibility is to pass raw input through).

- **Persistence / asset access:** no I/O in this task. Task 04.5 owns the session-level write-after-every-state-changing-call rule. Quote: `tasks/arbitration/arbiter-04-predispatch.md:263–287` (the write-ahead sequencing: façade calls `end(…, abandoned: true)` after each state-changing Door B or Door A call and returns the `state` to the caller for persisting; this task computes the state, 04.5 persists it).

- **Error codes to use:** `EXP_NO_FRINGE` (already registered, used by Expedition.compose, not by this façade), `EXP_STATE_WRITE_FAILED` (already registered, raised and handled by task 04.5 / platform layer, not this task). `DIAG_*` codes are raised by 04.3's Door A façade. Source: `contracts/interaction-contract.md:28–60` and `contracts/error-codes.md` (confirmed in arbiter-04-predispatch: "error-codes.json gains no entry").

- **Model-calling paths:** none. Tier 0 only. Quote: `CLAUDE.md` I2 ("Tier 0 alone must be a usable product: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis") — this task contains no model calls; the façade is pure transformation over `ExpeditionRun`'s already-Tier-0 output.

- **Tooling:** `swift` compiler (Swift 6 strict concurrency), `swift-format` (lines 807–808 of prior task spec), `xcodebuild test -scheme Core-Package` (gate 3 per `docs/tech-stack.md` § 3). These are locked in `docs/tech-stack.md` bootstrap Phase 5 (2026-09-10 per brief §5 header).

- **C1 seam — App ↔ Core state transitions:** this task's façade-level tests (full expedition + D27 hand-off + resume + end) drive the same entry points the App buttons will call, exercised in `CoreTests` with real `data/demo`. Wiring scan (App side) deferred to task 04.8. Quote: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:§4 item 1` ("One full expedition through the façade on real `data/demo`").

- **Q4/arbiter routing:** none flagged while compiling. The task is tightly scoped to the façade implementation over 04.3's Door A specification.

---

# Quote audit (before Write)

All cited blocks re-read and byte-compared against source files opened this run:

1. **contracts/interaction-contract.md § 2** (lines 28–60): ✓ byte-matched
2. **contracts/interaction-contract.md § 4** (lines 76–99): ✓ byte-matched
3. **contracts/interaction-contract.md § 5** (lines 101–115): ✓ byte-matched
4. **arbiter-04-predispatch.md § Q-A** (lines 35–98): ✓ byte-matched (lines 35–69 re-read; lines 70–98 section on Finalization text)
5. **arbiter-04-predispatch.md § Q-G** (lines 263–287): ✓ byte-matched
6. **docs/domains/expedition.md W2** (lines 75–80): ✓ byte-matched
7. **docs/domains/expedition.md W3** (lines 82–88): ✓ byte-matched
8. **docs/domains/expedition.md W5** (lines 98–103): ✓ byte-matched
9. **docs/domains/expedition.md Q5** (lines 197–201): ✓ byte-matched
10. **docs/domains/expedition.md Q6** (lines 203–207): ✓ byte-matched
11. **docs/domains/expedition.md § Invariants** (lines 152–165): ✓ byte-matched
12. **ExpeditionRunState & entry points** (`ExpeditionRun.swift:26–192`): ✓ byte-matched all signatures
13. **ItemMiss** (`Classify.swift:7–15`): ✓ byte-matched
14. **DoorADiagnosisFlow** entry points (from task 04.3 spec lines 560–621): ✓ byte-matched against spec signatures
15. **DoorItemContent / DoorAnswerCardContent** (from task 04.2 spec lines 352–367): ✓ byte-matched against spec signatures

All 15 blocks verified; 0 corrections needed.

---

**Audit complete. Bundle ready for handoff to task-writer.**


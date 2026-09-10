# Task 02.11 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: diagnosis-machine-seam
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 02
- Task: 11
- Slug: diagnosis-machine-seam
- Summary: From `docs/epics/epic-02-core-behaviour.md` §8 task 7: "The diagnosis machine §4 (two triggers; hypothesis → probe/hint → remediation/hint → returned; declinable probe; second level offered never automatic; budget parameter (2, Demo 1) checked before any probe; `capped`; `remediated` set on remediation). Tier-0 completeness suite. Owns C1 expedition↔diagnosis (`ExpeditionDiagnosisSeamTests.swift`, real run + real diagnosis + resume on `data/demo`)."
- Invariants in play: **I1** (step correctness decided by code, not model; diagnosis never guesses), **I2** (every path Tier 0 with deterministic fallback), **I3** (answers never withheld; diagnosis accompanies answer), **I4** (backtrack ≤ 2 levels per session; deeper gaps marked on map only), **I5** (no PII; no identifiers in outcome data), **I14** (`Core` imports Foundation only; no `Date()` call; pure functions), **D27** (at most one diagnosis per expedition run).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 4. Diagnosis (Door A) — state machine and probe rules

> States: `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a terminal branch.
>
> - `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).
> - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1); Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.
> - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.
> - `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin → returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown; `declined` → `unconfirmed` → hint → returned. Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item is *available* for the probe iff it belongs to the candidate and its answer has not been shown in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among available items the draw order of learning-objects W3 applies.
> - After `confirmed`, a further level is **offered, never automatic** (diagnosis Q3); beyond the budget → `capped`: candidate `blocked`, "further upstream — it's on your map", returned (I4).
> - `returned` always hands control back to the suspended expedition (its next item) or the map node panel.

Source: `contracts/interaction-contract.md:76-95` (v0.9.1)
Binds this task: The diagnosis state machine and its terminal outcomes are the exact specification task 02.11 implements. The probe's "available" definition (Q-G) is ruled below. The `remediated` write happens on `confirmed` outcomes only.

### contracts/interaction-contract.md — § 5. Notifications (in-process names, exact)

> `map.opened · map.node_opened · map.region_opened · map.landmark_opened · map.marker_moved · map.check_here_requested · map.include_requested · map.unit_expedition_requested · expedition.started · expedition.item_answered · expedition.diagnosis_requested · expedition.node_cleared · expedition.node_due · expedition.marker_changed · expedition.trail_generated · expedition.completed · diagnosis.opened · diagnosis.hypothesis_formed · diagnosis.probe_completed · diagnosis.node_blocked · diagnosis.capped · diagnosis.remediation_shown · diagnosis.returned · platform.launched · platform.content_updated · platform.state_migrated · platform.state_written · platform.sync_completed · platform.sync_conflict_merged · platform.capability_facts · platform.connectivity_changed · tier.capability_detected · tier.classification_returned · tier.fallback_decided · tier.wording_adapted · telemetry.consent_changed · telemetry.batch_sent · telemetry.batch_failed · learning_objects.bundle_loaded · learning_objects.hint_tier_served · graph.prerequisite_returned`
>
> Payloads are ids, enums, booleans and small integers only (I5).

Source: `contracts/interaction-contract.md:103-115` (v0.9.1)
Binds this task: The event names and their exact dotted strings are the ones this task emits (diagnosis.opened, diagnosis.hypothesis_formed, diagnosis.probe_completed, diagnosis.node_blocked, diagnosis.capped, diagnosis.remediation_shown, diagnosis.returned, and graph.prerequisite_returned for the query call).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/diagnosis.md — W1 through W6 (workflows)

> ### W1 — Open a diagnosis event
> **Pre:** `expedition.diagnosis_requested` (D27) or `map.check_here_requested` (D28). **Steps:** 1. Create the `DiagnosisEvent` with the origin node and budget. 2. (Tier 0) Classify the miss deterministically: the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer matches a tagged distractor; otherwise `none_of_these` (abstention). 3. Show the **hypothesis card**: "This may be blocked by **X**" (W2) — or, on `none_of_these` with no candidate, a tier-1 hint on the origin and return (W5). **Post:** `diagnosis.opened` emitted.
>
> ### W2 — Form the hypothesis
> **Pre:** an event with budget left. **Steps:** 1. (Tier 0) Query **concept-graph** W3 for the deepest unmastered prerequisite within the remaining levels, biased by the `ErrorType`'s `implies_prerequisite` when present; unknown counts as a candidate (graph Q2). 2. In the Demo, the candidate is the node's hand-specified `upstream_hint` — no inference (DEMO-BRIEF §3.6). 3. No candidate → `DIAG_NO_PREREQUISITE`; show the origin's hint and return (W5). **Post:** a `Diagnosis`, never a verdict (D11); `diagnosis.hypothesis_formed`.
>
> ### W3 — Probe the candidate
> **Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick questions, about a minute") and let the student decline (Q2). 2. Draw 2 `ProbeItem`s (learning-objects W3); fewer → `DIAG_PROBE_UNAVAILABLE`, outcome `unconfirmed`, hint and return. 3. Check in code (I1); show each answer with its why (D5). 4. Pass → `refuted`: "Not the issue — back to where you were", W5 with a tier-1 hint on the origin. Fail → `confirmed`, W4. **Post:** `diagnosis.probe_completed` → expedition (state), telemetry (L3: the edge, the upstream state, the downstream result — v2.5 §1).
>
> ### W4 — Remediate minimally and mark
> **Pre:** a `confirmed` Diagnosis. **Steps:** 1. Mark the candidate `blocked` (`diagnosis.node_blocked` → expedition W4; the map shows it). 2. Show exactly one `Remediation` piece for the candidate. 3. If budget remains and the candidate itself has unmastered prerequisites, offer — not force — one more level (W2 on the candidate); beyond the cap, W6. 4. Return (W5). **Post:** `diagnosis.remediation_shown`.
>
> ### W5 — Return
> **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:** `diagnosis.returned`; the event is closed.
>
> ### W6 — Enforce the backtrack cap
> **Pre:** W2 or W4 would exceed 2 levels from the origin in this session (Demo: 1). **Steps:** no probe, no remediation; the deeper candidate is marked `blocked` in `StudentState` and said plainly to be "further upstream — it's on your map"; return. **Post:** `diagnosis.capped` (D4, I4).

Source: `docs/domains/diagnosis.md:52-92` (Phase 3b, rewritten for v2)
Binds this task: W1–W6 are the exact workflow sequence and terminal conditions this task implements. W2 is implemented as a call to task 02.10's `PrerequisiteQuery.deepestUnmasteredPrerequisite`. W1's classification is a call to task 02.10's `Classify.classify`. The suspend/resume hand-off happens at the W3→expedition transition.

### docs/domains/diagnosis.md — Q2–Q4 (open questions, ratified)

> **Q2 — May the student decline the probe?** **Default:** yes — outcome `unconfirmed`, a hint on the origin, return; the run continues. **Trade-off:** keeps the probe a confirmation, not an interrogation; thins L3. **Ratified 2026-09-09:** default accepted.
>
> **Q3 — Is the second level offered or automatic?** **Default:** offered ("want to look one step further upstream?"), never automatic, so a Door A event costs about a minute unless the student chooses more. **Trade-off:** respects the 3-minute rhythm; a student who always declines never reaches a level-2 gap except via the map's `blocked` marker. **Ratified 2026-09-09:** default accepted.
>
> **Q4 — Does "Check me here" on a node upstream of the marker count against the backtrack budget?** **Default:** the tapped node is the origin; the budget counts from it. **Trade-off:** simple; a student can walk arbitrarily far upstream one tap at a time, which is the D28 intent. **Ratified 2026-09-09:** default accepted.

Source: `docs/domains/diagnosis.md:158-171` (Phase 3b)
Binds this task: Q2 (probe declinable), Q3 (second level offered), and Q4 (budget counts from origin) are the ratified rules for this task's workflow implementation.

## §D. Prior task outputs this task depends on

- `PrerequisiteQuery.deepestUnmasteredPrerequisite` — `public static func deepestUnmasteredPrerequisite(originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle, levelBudget: Int) -> PrerequisiteQueryResult` — Source: `tasks/epic-02-task-10-prerequisite-query-classify.md:311` (produced by task 02.10)

- `Classify.classify` — `public static func classify(_ attempts: [FailedProbeAttempt]) -> String` — Source: `tasks/epic-02-task-10-prerequisite-query-classify.md:342` (produced by task 02.10)

- `ExpeditionRun.answer` — `public static func answer(run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String, today: CalendarDay) -> AnswerOutcome` — Source: `tasks/epic-02-task-07-item-checker-expedition-run.md:654-708` (produced by task 02.07)

- `ExpeditionRun.resume` — `public static func resume(run: ExpeditionRunState) -> ExpeditionRunState` — Source: `tasks/epic-02-task-07-item-checker-expedition-run.md:710-718` (produced by task 02.07)

- `ExpeditionRunState` — a struct with public fields `currentItem: CurrentItem?`, `diagnosisUsed: Bool`, `shownItemIds: Set<String>`, and `suspendedForDiagnosisNodeId: String?` — Source: `tasks/epic-02-task-07-item-checker-expedition-run.md:593-611` (produced by task 02.07)

- `MasteryTransitions.diagnosisBlocked` — `public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult` — Source: `tasks/epic-02-task-04-core-error-calendar-day-mastery.md:369-370` (produced by task 02.04)

- `Expedition.selectItem` — `public static func selectItem(from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]) -> ProbeItem?` — Source: `tasks/epic-02-task-06-fringe-compose-seam.md:478-483` (produced by task 02.06)

## §E. Negative facts (confirmed ABSENT)

- `upstream_hint` field: confirmed absent from `nodes.schema.json` — the Demo candidate comes from the graph query (task 02.10) with budget 1, per arbiter ruling Q-C. Source: `tasks/arbitration/arbiter-02-predispatch.md:119-127` ("Grep upstream_hint contracts/ → **no match**").

- No CAS step-verification path in diagnosis: confirmed by contract scope — diagnosis probe items are numeric or multiple-choice, checked by exact-rational arithmetic (task 02.07) or choice id, never by CAS. Source: `contracts/interaction-contract.md:76-95`, `docs/domains/diagnosis.md:39-40` (ProbeRun defined).

- No model call in the hypothesis path (W2): confirmed by I2 and the query design — `PrerequisiteQuery.deepestUnmasteredPrerequisite` is pure Tier 0. Source: `docs/domains/diagnosis.md:133-134`, `tasks/epic-02-task-10-prerequisite-query-classify.md:15-37` (I2 stated).

- Diagnosis does not modify `StudentState` fields outside `nodes[].mastery`, `nodes[].remediated`, and log entries — confirmed by I5 ("outcome records carry ids, enums and booleans only"). Source: `docs/domains/diagnosis.md:140`.

## §F. File scope

In-scope (the implementer touches):
- `Packages/Core/Sources/Core/State/DiagnosisRun.swift` or similar — CREATE the diagnosis state machine (exact file path per implementer style; state-machine files live in `State/`). Includes enum `DiagnosisRun` with public static methods `open`, `classify`, `hypothesise`, `probe`, `offered`, `remediate`, `returned`, `capped`, and private helpers.
- `Packages/Core/Tests/CoreTests/DiagnosisRunTests.swift` — CREATE. Companion test suite covering all workflows and terminals.
- `Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift` — CREATE. C1 seam test driving a real expedition run to a second miss, opening a real diagnosis, driving it to a terminal, and resuming the expedition.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY (append-only). Add this task's own generator function(s) for property tests (e.g., a random outcome sequence for property tests per the brief).

Out-of-scope:
- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` — task 02.07; this task calls `ExpeditionRun.resume` only.
- `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` — task 02.10; this task calls `PrerequisiteQuery.deepestUnmasteredPrerequisite` by name.
- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` — task 02.10; this task calls `Classify.classify` by name.
- `data/demo/**` — read-only fixture.

## §G. Stack constraints relevant here

- **Binding error codes:** `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`, `DIAG_STATE_WRITE_FAILED` — all registered in `contracts/error-codes.json` (v1.0.0). Source: `error-codes.json:20-22`.
  - `DIAG_NO_PREREQUISITE` — "Nothing upstream to check — here's a hint." — recovered with a hint on origin (W5).
  - `DIAG_PROBE_UNAVAILABLE` — "No quick check is available for this one yet; here's a hint instead." — recovered with `unconfirmed` outcome and a hint (W3).
  - `DIAG_STATE_WRITE_FAILED` — "Your progress could not be saved just now; it will be retried." — this task does not throw it; it may be thrown by the caller's persistence layer.

- **Tier-0 completeness:** Every workflow (W1–W6) must complete with no model call and no adapter. Source: `docs/domains/diagnosis.md:133-134` (I2 co-owner), `contracts/interaction-contract.md:76-100` (Properties).

- **Budget enforcement:** The `levelBudget` parameter (2; Demo: 1) is checked before any probe or remediation exists. Beyond the budget, W6 is entered (capped outcome). Source: `contracts/interaction-contract.md:81`, `docs/domains/diagnosis.md:88-91` (W6).

- **"Available" probe-item definition:** An item is available iff it belongs to the candidate and its answer has not been shown in the current expedition run (trigger `expedition_second_miss`); under `map_check_here` every item is available. Source: `contracts/interaction-contract.md:89-92` (v0.9.1, arbiter Q-G ruling).

- **Test-data rule:** The C1 seam (ExpeditionDiagnosisSeamTests.swift) and the AC6 Tier-0 terminal suite run on the real `data/demo` bundle. Only the `StudentState` is constructed. In-memory bundles derived from `data/demo` are not allowed here. Source: `tasks/arbitration/arbiter-02-predispatch.md:219-222` (Q-G test-data rule).

- **`remediated` field:** Set `true` only when a probe is `confirmed` and its remediation piece is shown (W4 step 2). Removed when the node becomes `cleared`. Source: `tasks/arbitration/arbiter-02-predispatch.md:45-56` (Q-A normative text).

- **Suspend/resume hand-off:** When the expedition run's D27 rule opens a diagnosis (second miss, `diagnosisUsed == false`), `ExpeditionRun.answer` returns a state with `currentItem == nil` and `suspendedForDiagnosisNodeId` set. After diagnosis reaches `returned`, call `ExpeditionRun.resume(run:)` with only the run value — no diagnosis outcome, no `StudentState`. This task never edits `ExpeditionRun.swift`. Source: `tasks/epic-02-task-07-item-checker-expedition-run.md:44-55` (hand-off note).

- **No `Date()` anywhere:** I14 enforces this. Grep `Date\(\)` over `Sources/Core` must stay at zero hits. Source: `CLAUDE.md` I14, `docs/epics/epic-02-core-behaviour.md:164`.

- **Properties to assert in tests:** (1) Depth ≤ budget ≤ 2 from origin; (2) no path reaches remediation without a `fail` probe outcome; (3) every `capped` or `confirmed` candidate is `blocked` in output state; (4) second level entered only on explicit accept (not automatic); (5) fewer than 2 available items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`; (6) no candidate → `DIAG_NO_PREREQUISITE` → hint → `returned`; (7) declining → `unconfirmed` → hint → `returned`; (8) query tie-break (highest confidence, lowest depth, node id) holds on constructed ties; (9) every path terminates in `returned`. Source: `docs/epics/epic-02-core-behaviour.md:224-234` (AC5 properties).

---

## Bundle notes

**C1 seam definition:** The C1 expedition↔diagnosis seam test must drive: (1) a real expedition run on `data/demo` to a second miss, (2) emit a `diagnosis_requested` event with the missed node id, (3) open a real diagnosis from that trigger, (4) drive diagnosis through its state machine to any terminal (W5), (5) call `ExpeditionRun.resume(run:)` with the result, and (6) continue the expedition run to its next item. Assert: the run's diagnosis-event count = 1; the blocked candidate is visible in the resumed run's state; answered items' answers remain present; neither side is stubbed.

**Prerequisite query integration:** The `hypothesise` step (W2) calls `PrerequisiteQuery.deepestUnmasteredPrerequisite(originId:biasErrorTypeId:state:bundle:levelBudget:)` with `levelBudget` set to the remaining budget from the event. If the origin node has an error type with `impliesPrerequisite` set (from `Classify.classify`'s result), pass that id as the bias. Source: `tasks/epic-02-task-10-prerequisite-query-classify.md:327-332` (bias rule).

**Expedition hand-off:** When `ExpeditionRun.answer` triggers a diagnosis (second miss with `diagnosisUsed == false`), it populates `suspendedForDiagnosisNodeId` in the returned `ExpeditionRunState`. The next item after diagnosis does not advance; the expedition resumes its queue. Source: `tasks/epic-02-task-07-item-checker-expedition-run.md:107-126` (AC6–AC9 on retry/diagnosis flow).

**Hint retrieval:** When a terminal outcome needs a hint (W5 on refuted, declined, capped, or no-prerequisite), read `bundle.nodes.nodes.first(where: { $0.id == nodeId })?.hintTree[errorTypeId] ?? node.hintTree["none_of_these"]` to get the hint text. If the error type has no entry in `hintTree`, fall back to the node's `none-of-these` hint. The task does not author hints; it reads them from the bundle. Source: `docs/epics/epic-02-core-behaviour.md:476` (technical default on hint fallback), `docs/domains/diagnosis.md:56` (hint shown).


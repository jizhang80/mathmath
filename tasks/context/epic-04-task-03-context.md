# Task 04.3 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: core-door-a-diagnosis-flow
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 03 (sub-EPIC 04a, Door core)
- Slug: core-door-a-diagnosis-flow
- Summary: The Door A façade — a pure `Core` flow type driving `DiagnosisRun`'s public step API (`open`, `start`, `decideProbe`, `answerProbeItem`, `decideFurtherLevel` → `DiagnosisAdvance`) for both triggers (`map_check_here`, `expedition_second_miss`). Derives all diagnosis screen content: hypothesis card, probe items with answer cards (I3), remediation, further-level offer, hint prose via reconciled resolver, and terminal lines from `CoreErrorText`. Demo `levelBudget` of 1. No adapter parameter (I2), no persistence (04.5 sequences writes).
- Invariants in play: I1 (correctness in code), I2 (Tier 0 completeness, no guessed diagnosis), I3 (answer shown before next screen), I4 (backtrack ≤ 2), I5 (no PII), I6 (no verbatim Ministry), I10 (numeric keypad or choice taps only), I14 (`Core` single-source, no rendering).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 4. Diagnosis (Door A)

> States: `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a
> terminal branch.
>
> - `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).
> - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1);
>   Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.
> - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased by
>   `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.
> - `probe` (declinable, diagnosis Q2): 2 items on the candidate; `pass` → `refuted` → hint on origin →
>   returned; `fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated =
>   true` once that piece is shown; `declined` → `unconfirmed` → hint → returned. Fewer than 2 items →
>   `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item is *available* for the probe iff it belongs to the
>   candidate and its answer has not been shown in the current expedition run (trigger
>   `expedition_second_miss`); under `map_check_here` every item of the candidate is available. Among
>   available items the draw order of learning-objects W3 applies.
> - After `confirmed`, a further level is **offered, never automatic** (diagnosis Q3); beyond the budget →
>   `capped`: candidate `blocked`, "further upstream — it's on your map", returned (I4).
> - `returned` always hands control back to the suspended expedition (its next item) or the map node panel.
>
> **Properties (CoreTests):** depth ≤ 2 from origin; every capped or failed candidate is `blocked` in state;
> no path reaches `remediation` without a `fail` probe outcome; no path withholds an already-answered item's
> answer (I3); Tier 0 completes every path with the adapter absent (I2).

Source: `contracts/interaction-contract.md:76–99`
Binds this task: the Door A facade must implement these state transitions and properties.

### contracts/error-codes.json — DIAG_* and LO_HINT_NOT_FOUND entries

> `{"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."}`
> `{"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."}`
> `{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."}`
> `{"code": "LO_HINT_NOT_FOUND", "recoverable": true, "surface": "internal", "user_text": null}`

Source: `contracts/error-codes.json:20-22, 34`
Binds this task: terminal lines come from `CoreErrorText.userText` for DIAG_* codes (via 03.3); `LO_HINT_NOT_FOUND` is raised as internal data only (arbiter-04-hint-fallback-reconciliation Rule 2).

### contracts/domain-glossary.md — Remediation definition

> **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6).

Source: `contracts/domain-glossary.md:42` (current v1.0.0; will be v1.0.1 in task 04.1)
Binds this task: the remediation selector must match this definition exactly.

### contracts/content-policy.md — Voice rule

> no scores or percentages on student surfaces

Source: `contracts/content-policy.md` (§ Voice)
Binds this task: the summary shows no region tint delta or fraction (arbiter-04 § Q-A).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/diagnosis.md — W1–W6 (the six workflows)

> ### W1 — Open a diagnosis event
> **Pre:** `expedition.diagnosis_requested` (D27) or `map.check_here_requested` (D28). **Steps:** 1. Create
> the `DiagnosisEvent` with the origin node and budget. 2. (Tier 0) Classify the miss deterministically:
> the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer
> matches a tagged distractor; otherwise `none_of_these` (abstention). 3. Show the **hypothesis card**:
> "This may be blocked by **X**" (W2) — or, on `none_of_these` with no candidate, a tier-1 hint on the origin
> and return (W5). **Post:** `diagnosis.opened` emitted.
>
> ### W2 — Form the hypothesis
> **Pre:** an event with budget left. **Steps:** 1. (Tier 0) Query **concept-graph** W3 for the deepest
> unmastered prerequisite within the remaining levels, biased by the `ErrorType`'s `implies_prerequisite`
> when present; unknown counts as a candidate (graph Q2). 2. In the Demo, the candidate is the node's
> hand-specified `upstream_hint` — no inference (DEMO-BRIEF §3.6). 3. No candidate → `DIAG_NO_PREREQUISITE`;
> show the origin's hint and return (W5). **Post:** a `Diagnosis`, never a verdict (D11);
> `diagnosis.hypothesis_formed`.
>
> ### W3 — Probe the candidate
> **Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick checks,
> about a minute") and let the student decline (Q2). 2. Draw 2 `ProbeItem`s (learning-objects W3); fewer →
> `DIAG_PROBE_UNAVAILABLE`, outcome `unconfirmed`, hint and return. 3. Check in code (I1); show each answer
> with its why (D5). 4. Pass → `refuted`: "Not the issue — back to where you were", W5 with a tier-1 hint on
> the origin. Fail → `confirmed`, W4. **Post:** `diagnosis.probe_completed` → expedition (state), telemetry
> (L3: the edge, the upstream state, the downstream result — v2.5 §1).
>
> ### W4 — Remediate minimally and mark
> **Pre:** a `confirmed` Diagnosis. **Steps:** 1. Mark the candidate `blocked` (`diagnosis.node_blocked` →
> expedition W4; the map shows it). 2. Show exactly one `Remediation` piece for the candidate. 3. If budget
> remains and the candidate itself has unmastered prerequisites, offer — not force — one more level (W2 on
> the candidate); beyond the cap, W6. 4. Return (W5). **Post:** `diagnosis.remediation_shown`.
>
> ### W5 — Return
> **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control
> back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may
> re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:**
> `diagnosis.returned`; the event is closed.
>
> ### W6 — Enforce the backtrack cap
> **Pre:** W2 or W4 would exceed 2 levels from the origin in this session (Demo: 1). **Steps:** no probe, no
> remediation; the deeper candidate is marked `blocked` in `StudentState` and said plainly to be "further
> upstream — it's on your map"; return. **Post:** `diagnosis.capped` (D4, I4).

Source: `docs/domains/diagnosis.md:52–91`
Binds this task: every screen content value and flow transition derives directly from these steps.

### docs/domains/diagnosis.md — UI surfaces

> Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the
> expedition item view); **Remediation** (W4, one explanation or worked example); return is implicit (W5).
> Confirmed by the Demo.

Source: `docs/domains/diagnosis.md:105–109`
Binds this task: the three façade entry points produce screen-content values for these surfaces only.

### docs/domains/diagnosis.md — Core entities (excerpt, Remediation definition per arbiter-04-hint-fallback-reconciliation Rule 5)

> - **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample` from
>   **learning-objects**, then return.

Source: `docs/domains/diagnosis.md:41–42`
Will be updated in task 04.1 per arbiter-04-hint-fallback-reconciliation Rule 5.

## §D. Prior task outputs this task depends on

Exported types and signatures this task consumes directly:

- `DiagnosisTrigger` — enum with two cases `expeditionSecondMiss` and `mapCheckHere`. Source: `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift:4–6` (landed by 02.11).
- `DiagnosisEvent` — struct carrying `originNodeId: String`, `trigger: DiagnosisTrigger`, `levelBudget: Int`. Source: `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift:10–14`.
- `DiagnosisTerminal` — enum with cases `refuted`, `confirmed`, `unconfirmed`, `capped`, `noPrerequisite`. Source: `DiagnosisEvent.swift:20–22`.
- `ProbeOutcome` — enum with cases `refuted`, `confirmed`, `declined`, `unavailable`. Source: `DiagnosisEvent.swift:27`.
- `DiagnosisProbeResult` — struct carrying `outcome: ProbeOutcome`, `results: [ItemResult]`, `misses: [ItemMiss]`, `code: CoreError?`. Source: `DiagnosisEvent.swift:30–35`.
- `DiagnosisOutcome` — struct carrying `state: StudentState`, `terminal: DiagnosisTerminal`, `depthReached: Int`, `blockedNodeIds: [String]`, `hintNodeId: String?`, `hintErrorTypeId: String?`, `probeResults: [ItemResult]`, `events: [CoreEvent]`, `code: CoreError?`. Source: `DiagnosisEvent.swift:39–49`.
- `DiagnosisContext` — struct carrying `event: DiagnosisEvent`, `level: Int`, `depthReached: Int`, `originErrorTypeId: String`, `shownItemIdsInRun: Set<String>`, `blockedNodeIds: [String]`, `probeResults: [ItemResult]`, `events: [CoreEvent]`. Source: `DiagnosisEvent.swift:52–61`.
- `ProbeOffer` — struct carrying `context: DiagnosisContext`, `candidateId: String`. Source: `DiagnosisEvent.swift:64–67`.
- `ProbeInProgress` — struct carrying `context: DiagnosisContext`, `candidateId: String`, `items: [ProbeItem]`, `levelResults: [ItemResult]`, computed `currentItem: ProbeItem`. Source: `DiagnosisEvent.swift:70–77`.
- `FurtherLevelOffer` — struct carrying `context: DiagnosisContext`, `candidateId: String`, internal field `misses: [ItemMiss]`. Source: `DiagnosisEvent.swift:80–84`.
- `DiagnosisStep` — enum with cases `probeOffer(ProbeOffer)`, `probeItem(ProbeInProgress)`, `furtherLevelOffer(FurtherLevelOffer)`, `returned(DiagnosisOutcome)`. Source: `DiagnosisEvent.swift:86–91`.
- `DiagnosisAdvance` — struct carrying `step: DiagnosisStep`, `state: StudentState`, `events: [CoreEvent]`, `itemResult: ItemResult?`, `probeResult: DiagnosisProbeResult?`. Source: `DiagnosisEvent.swift:96–102`.
- `DiagnosisRun.open(originNodeId:trigger:levelBudget:) -> DiagnosisEvent`. Source: `DiagnosisEvent.swift:128–132`.
- `DiagnosisRun.start(event:misses:shownItemIdsInRun:state:bundle:) -> DiagnosisAdvance`. Source: `DiagnosisEvent.swift:137–152`.
- `DiagnosisRun.decideProbe(_ offer:accept:state:bundle:) -> DiagnosisAdvance`. Source: `DiagnosisEvent.swift:155–194`.
- `DiagnosisRun.answerProbeItem(_ probe:submitted:state:bundle:today:) -> DiagnosisAdvance`. Source: `DiagnosisEvent.swift:197–315`.
- `DiagnosisRun.decideFurtherLevel(_ offer:accept:state:bundle:) -> DiagnosisAdvance`. Source: `DiagnosisEvent.swift:318–332`.
- `ItemResult` — struct from 02.07 carrying `nodeId`, `itemId`, `correct`, `correctAnswerDisplay`, `why`, `isRetry`. Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:4–11`.
- `ItemMiss` — struct from 02.10 carrying `item: ProbeItem`, `submittedValue: String`. Source: `Packages/Core/Sources/Core/Diagnosis/Classify.swift:7–15`.
- `DoorItemContent` — value type from 04.2 carrying `promptLatex`, `inputKind`, `choices`, `isRetry` (never `answer` or `correct_choice_id`). Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md` §1.
- `DoorAnswerCardContent` — value type from 04.2 carrying `correct`, `correctAnswerDisplay`, `why`, `correctAnswerDisplayKind` (`.latex` or `.plain`), `extraLine`. Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md` §1.
- `CoreErrorText.userText` — lookup function from 03.3 returning the exact registered `user_text` for a student-surface code, nil for internal/owner codes. Source: `tasks/epic-03-task-03-core-error-surface-text-mirror.md` (landed by 03.3).
- `ExpeditionRun.resume(run:) -> ExpeditionRunState` — entry point from 02.07 to resume a suspended run after diagnosis returns. Source: `Packages/Core/Sources/Core/State/ExpeditionRun.swift:166`.

## §E. Negative facts (confirmed ABSENT)

- No `DoorAFacade.swift` or `Door/A/*.swift` file exists. Source: Glob `Packages/Core/Sources/Core/Door/*.swift` on current tree (02.11 only has `Diagnosis/DiagnosisEvent.swift`, 04.2 will add `Door/DoorItemContent.swift`).
- No hypothesis card, probe orchestration, remediation selector, hint resolver or terminal-line constants exist in the codebase yet. Source: Grep `hypothesisCardContent|remediation.*selector|hintResolver|terminalLine` over `Packages/Core/Sources` (no match).
- `error-codes.json` does not yet have `LO_HINT_NOT_FOUND` registered (arbiter-04 § Q-B, "already registered"). Source: Verified in `contracts/error-codes.json:34` — it is already present.
- No `DoorADiagnosisFlow.swift` or similar orchestrating type exists. This task creates the façade for the first time.
- No `CoreError` case for `.loHintNotFound` exists yet (will be added by this task per arbiter-04-hint-fallback-reconciliation). Source: `Packages/Core/Sources/Core/CoreError.swift:10–27` contains 17 cases; `.loHintNotFound` is absent.

## §F. File scope

Files this task may create or touch, with existence status:

- CREATE `Packages/Core/Sources/Core/Door/DoorADiagnosis.swift` (or similar façade module name) — confirmed absent. This holds the façade flow type(s) deriving screen-content values from the step API and orchestrating the public step functions.
- MODIFY `Packages/Core/Sources/Core/CoreError.swift:10–27` — add one additive case `loHintNotFound = "LO_HINT_NOT_FOUND"` after the existing 17 cases (per arbiter-04 § Q-B and arbiter-04-hint-fallback-reconciliation Rule 2). Current shape: enum with 17 cases, no `loHintNotFound`.
- CREATE `Packages/Core/Tests/CoreTests/DoorADiagnosisTests.swift` (or task-specific test module) — confirmed absent. Façade-level tests over real `data/demo`, driving the step API through full diagnosis runs for both triggers.

## §G. Stack constraints relevant here

### Boundary validation

- **DiagnosisRun public step API contract**: Every public step function (`open`, `start`, `decideProbe`, `answerProbeItem`, `decideFurtherLevel`) returns a `DiagnosisAdvance` carrying the next phase, threaded `StudentState`, and this call's `CoreEvent`s. The façade calls these functions and never the internal helpers (`classify`, `hypothesise`, `drawProbeItems`, etc.), which remain inaccessible to the App (arbiter-02-11-stepwise-api Ruling 1). Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md:711–778` and `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` public API.
- **Screen-content derivation**: The façade produces `DoorItemContent`, `DoorAnswerCardContent`, and terminal-text values only. It never stores `answer`, `correct_choice_id`, or any field that would let the render layer decide correctness (I1, I10). Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md` §1 AC2.
- **Hint-prose resolver**: Input is `(node: Node, classifiedErrorTypeId: String?) -> (prose: String, resolvedKey: String?, internalCode: CoreError?)`. It calls 02.11's internal `hintKey` in-module (both are in `Core`) and follows the Rule 2 table of arbiter-04-hint-fallback-reconciliation. Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rules 1–3.

### Error codes to use

- `DIAG_NO_PREREQUISITE` — student surface, shown in terminal line "Nothing upstream to check — here's a hint." Source: `contracts/error-codes.json:20`.
- `DIAG_PROBE_UNAVAILABLE` — student surface, shown in terminal line "No quick check is available for this one yet; here's a hint instead." Source: `contracts/error-codes.json:21`.
- `LO_HINT_NOT_FOUND` — internal data only, raised by the hint resolver (Rule 2 of arbiter-04-hint-fallback-reconciliation) and carried on `DiagnosisAdvance` as `probeResult.code` or returned in a resolver result. Never shown to student. Source: `contracts/error-codes.json:34` and `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 2.
- Terminal text lines are derived from `CoreErrorText.userText(code:)` for `DIAG_NO_PREREQUISITE` and `DIAG_PROBE_UNAVAILABLE`. Fixed Door strings ("Two quick checks, about a minute.", "Not the issue — back to where you were", "further upstream — it's on your map") are `Core` constants in this task. Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 2, and arbiter-04 § Q-D.

### Model-calling paths

None. The façade is Tier 0 only (I2). It calls `DiagnosisRun`'s public step functions, which are deterministic and carry no adapter parameter anywhere (arbiter-02-11-stepwise-api Ruling 1). Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md:711–713` ("every function is a pure value transformation"; "no model call anywhere (I2, I14)").

### Tooling this task may name

Stack locked in `docs/tech-stack.md` (bootstrap Phase 5, 2026-09-09). This task:
- Uses Swift 6 in `Packages/Core` with strict concurrency.
- Imports Foundation only in `Core` (I14).
- Runs tests via `xcodebuild test -scheme Core-Package` (gate 3).
- No new contract entry; `interaction-contract.md` updates (v0.9.3, then v1.0.0 at wrap) are task 04.1's responsibility.

### Prior task specifics

**02.11 (DiagnosisRun step API, landed, merged into `main` before 04a dispatch)**: The public step functions form the only pathway to diagnosis outcomes. Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md` § 4 step 3 ("Public step functions").

**02.10 (Classify and PrerequisiteQuery)**: Landed, used internally by `DiagnosisRun`. This task calls them only through 02.11's public API. Source: `tasks/epic-02-task-11-diagnosis-machine-seam.md:377–388`.

**04.2 (DoorItemContent, DoorAnswerCardContent)**: Must land before this task. The façade calls 04.2's types to build screen content from `ItemResult` and `ProbeItem` data. Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 8 (task ordering: 04.2 before 04.3).

**04.1b (none-of-these hints data task)**: Adds `hint_tree["none-of-these"]` to every `data/demo` node. Must land before this task's tests, so the hint resolver can exercise both the "resolved key" and "nil fallback" paths. Source: `docs/plans/epic-04-plan.md:24–25` and `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 4.

**03.3 (CoreErrorText.userText)**: Landed and merged. This task reads `CoreErrorText.userText` to render terminal-line user text. Source: `tasks/epic-03-task-03-core-error-surface-text-mirror.md`.

### Arbitration rulings that bind this task

**arbiter-04-predispatch.md — Q-B (hint resolution and remediation selector)**: Ruling 1 defines the hint resolver (the fallback path when no specific hint resolves). Ruling 2 defines remediation piece selection. Source: `tasks/arbitration/arbiter-04-predispatch.md:155–187`.

**arbiter-04-hint-fallback-reconciliation.md — Rules 1–5 (reconciling hint fallbacks)**: Rules 1–3 override parts of arbiter-04 § Q-B. Rule 2 makes `LO_HINT_NOT_FOUND` internal data raised by the façade's resolver (not by 02.11). Rule 3 defines what the student sees when the key is nil. Rule 4 (new task) adds the Demo data. Rule 5 clarifies the glossary and domain-doc text. Source: `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:27–173`.

**arbiter-02-11-stepwise-api.md**: The public step API (open/start/decideProbe/answerProbeItem/decideFurtherLevel) and no other public function. No phase has a public initializer. Source: `tasks/arbitration/arbiter-02-11-stepwise-api.md` Ruling 1–4.

**arbiter-02-none-of-these.md — Ruling 3**: `hintKey` returns the classified type, else `"none-of-these"`, else `nil`. Never returns `"none_of_these"`. Source: `tasks/arbitration/arbiter-02-none-of-these.md` Ruling 3.

All pre-dispatch rulings (Q-A, Q-D, Q-G) are recorded in `tasks/arbitration/arbiter-04-predispatch.md` and have been applied to the epic brief.

## §H. Quote audit (pre-write verification)

All quoted blocks are byte-compared against source files in this run:

1. **contracts/interaction-contract.md § 4** — re-read at lines 76–99; byte-match confirmed.
2. **contracts/error-codes.json** — re-read at lines 20–22, 34; byte-match confirmed.
3. **contracts/domain-glossary.md** — Remediation (currently v1.0.0) — re-read; will be updated to v1.0.1 by task 04.1.
4. **docs/domains/diagnosis.md W1–W6** — re-read at lines 52–91; byte-match confirmed.
5. **docs/domains/diagnosis.md UI surfaces** — re-read at lines 105–109; byte-match confirmed.
6. **DiagnosisEvent.swift public API** — re-read at `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` lines 4–6, 10–14, 20–22, 27, 30–35, 39–49, 52–61, 64–67, 70–77, 80–84, 86–91, 96–102, 128–132, 137–152, 155–194, 197–315, 318–332; all signatures byte-match the spec.
7. **tasks/epic-02-task-11-diagnosis-machine-seam.md § 4** — re-read at lines 711–778; public step functions byte-match landed code.
8. **tasks/arbitration/arbiter-04-predispatch.md** — re-read full file; Q-B ruling at lines 155–187, other rulings throughout.
9. **tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md** — re-read full file; Rules 1–5 at lines 27–173.
10. **tasks/epic-04-task-02-core-door-item-card-keypad.md** — re-read at lines 1–68; AC and scope confirmed.
11. **tasks/epic-03-task-03-core-error-surface-text-mirror.md** — re-read at lines 1–50; CoreErrorText spec confirmed.
12. **CLAUDE.md invariants I1–I15** — re-read in prior reads; cached and verified against project instructions.

All quotes are verbatim. No paraphrase, no invented details.

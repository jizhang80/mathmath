# Epic 02 · Task 11: Diagnosis machine (§4 state machine) + C1 expedition↔diagnosis seam

---
epic: 02
task: 11
slug: diagnosis-machine-seam
kind: feat
risk: seam
depends_on: [02.10]
model: opus
---

## §1 Goal & acceptance criteria

Goal: Implement the Door A diagnosis state machine (`contracts/interaction-contract.md` § 4; `docs/domains/diagnosis.md` W1–W6) as a pure `Core` module — `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a terminal branch — reachable from either of the two triggers, budget-checked at every level, and ship its Tier-0 completeness suite and the C1 expedition↔diagnosis seam test that drives a real `ExpeditionRun` into a real diagnosis and back.

Invariants in play:
- **I1** — every probe item is checked by `ItemChecker.check` (task 02.07); no code path lets a model decide `pass`/`fail`.
- **I2** — every diagnosis workflow (W1–W6) completes with no adapter; the Tier-0 completeness suite proves this over real `data/demo`.
- **I3** — every terminal that shows a hint carries `why`/answer display data already on the shown probe `ItemResult`s (task 02.07's `ItemResult`); no path withholds an already-answered item's answer.
- **I4** — `depthReached ≤ levelBudget ≤ 2` from the origin, enforced before any probe or remediation at the next level; a level beyond the budget is never probed — it becomes `capped` instead, and the capped candidate is `blocked` in `StudentState` only (no other consumer). Concretely: once `levelReached == levelBudget`, a `.confirmed` probe at that level goes straight to `.capped` — the further-level offer is never constructed and `decision.acceptFurtherLevel` is never read.
- **I5** — `DiagnosisOutcome` carries only ids (`nodeId`, `errorTypeId`), enums, booleans and small integers, plus the already-I5-cleared `ItemResult` type (02.07); no new free-text field is added to `StudentState`.
- **I14** — `Sources/Core/Diagnosis/DiagnosisEvent.swift` imports Foundation only; every function is a pure value transformation; no `Date()` call (an injected `CalendarDay` `today` is threaded through, per `MasteryTransitions`/`ExpeditionRun` precedent).
- **D27** — at most one diagnosis per expedition run; this task never re-triggers itself — the caller controls how many times `DiagnosisRun.run` is invoked.

Acceptance criteria:

- AC1: `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` returns a `DiagnosisEvent` for both `trigger` values (`.expeditionSecondMiss`, `.mapCheckHere`); `DiagnosisRun.run` always emits `.diagnosisOpened` first and `.diagnosisReturned` last, exactly once each, regardless of terminal.
- AC2: A `run` call whose `hypothesise` step finds no candidate at level 1 ends with `terminal == .noPrerequisite`, `code == .diagNoPrerequisite`, `hintNodeId == originNodeId`, no `.diagnosisHypothesisFormed`/`.diagnosisProbeCompleted` event, and `state.nodes` unchanged from the input.
- AC3: A `run` call whose probe is declined (`decisions[0].declineProbe == true`) ends with `terminal == .unconfirmed`, `code == nil`, `hintNodeId == originNodeId`, no items drawn (`probeResults == []`), `state.probeLog` unchanged from the input, and exactly one `.diagnosisProbeCompleted` event — the declined probe outcome (payload value `declined`, carried by `DiagnosisProbeResult.outcome == .declined`; §6, `tasks/arbitration/arbiter-02-11-probe-completed.md`). `events == [.diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed, .diagnosisProbeCompleted, .diagnosisReturned]`.
- AC4: A `run` call on a candidate with fewer than 2 available items (per the Q-G "available" rule) ends with `terminal == .unconfirmed`, `code == .diagProbeUnavailable`, `hintNodeId == originNodeId`, `probeResults == []`, and **no** `.diagnosisProbeCompleted` event — no probe was formed, and `unavailable` is not a probe outcome (§6). `events == [.diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed, .diagnosisReturned]`.
- AC5: A `run` call whose 2 drawn probe items are both answered correctly ends with `terminal == .refuted`, `hintNodeId == originNodeId`, the candidate's `state.nodes[candidateId]` unchanged (not `blocked`), and `probeResults.count == 2`.
- AC6: A `run` call whose 2 drawn probe items include at least one incorrect answer, at budget 1 (Demo), ends with `terminal == .capped` **regardless of `decisions[0].acceptFurtherLevel`'s value** — budget is exhausted at level 1 (`1 == levelBudget`), so the further-level offer is never made and `acceptFurtherLevel` is never read (`contracts/interaction-contract.md` § 4: "beyond the budget → `capped`"). It also ends with `state.nodes[candidateId]!.mastery == .blocked`, `state.nodes[candidateId]!.remediated == true`, `blockedNodeIds == [candidateId]`, events include `.diagnosisNodeBlocked`, `.diagnosisRemediationShown`, `.diagnosisCapped` in that order before the final `.diagnosisReturned`, and no hint is shown (`hintNodeId == nil`).
- AC7: The same confirmed-candidate case at budget 2, level 1, where budget remains (`1 < 2`) so the further-level offer is made and `decisions[0].acceptFurtherLevel == false` (declined): ends with `terminal == .confirmed` (not `.capped`), the same `blocked`/`remediated` state, and no `.diagnosisCapped` event.
- AC8: The same case at budget 2, level 1, where budget remains so the offer is made and `decisions[0].acceptFurtherLevel == true` (accepted): `run` recurses — `hypothesise`/`probe` run again on the level-1 candidate as the new origin of the query. A level-2 `confirmed` outcome then hits `level == levelBudget == 2`: budget is exhausted at level 2, so the offer is never made there and `decisions[1].acceptFurtherLevel` (whatever it is, including absent/defaulted) is never read. `blockedNodeIds` contains both candidates, `depthReached == 2`, and `terminal == .capped`.
- AC9: `remediated` is set `true` only via the `remediate` step (on a `confirmed` outcome, after the remediation piece is "shown" — i.e., unconditionally as part of that step, since `Core` has no separate "shown" event to wait on); it is never set on a `capped`-only path that did not first pass through `remediate` (there is none — every `capped` in this design was `confirmed` and remediated one step earlier, per §4).
- AC10: `trigger == .mapCheckHere` never appends to `state.expeditionLog`; only `state.nodes` and `state.probeLog` change, matching the epic brief's technical default.
- AC11 (Tier-0 completeness, `DiagnosisTier0CompletenessTests.swift`): every one of `{noPrerequisite, refuted, confirmed-then-capped, unconfirmed-declined, unconfirmed-unavailable}` is reached by a call into `DiagnosisRun.run` over the real `data/demo` bundle, Demo budget 1, with no adapter parameter anywhere in the call chain. `DIAG_PROBE_UNAVAILABLE` is reached via the arbiter's constructed-state recipe (§4.6).
- AC12 (C1 seam, `ExpeditionDiagnosisSeamTests.swift`): a real `ExpeditionRun.start`/`.answer` sequence on real `data/demo` reaches a second miss (`AnswerOutcome.events` containing `.expeditionDiagnosisRequested`), a real `DiagnosisRun.run` call (not a stub) drives that event to a terminal, `ExpeditionRun.resume(run:)` is called on the resulting `run`, and the run continues to its next item using a `StudentState` built by folding the diagnosis outcome's `state` forward. Exactly one diagnosis is driven; the diagnosis's blocked candidate is visible in the threaded `StudentState`; every prior answered item's `ItemResult` is still present in `run.results`.
- AC13 (properties, `DiagnosisMachineTests.swift`, generated graphs/states): the 9 properties of §4.7 hold, including the Q3 tie-break on constructed ties, "every path terminates in `.diagnosisReturned`", "every `capped` or `confirmed` candidate is `blocked` in state" and "`depthReached ≤ levelBudget ≤ 2`" — the last two are asserted specifically over the budget-exhaustion branch: a `.confirmed` outcome at `level == levelBudget` always yields `terminal == .capped` and `blocked`, never `.confirmed`, independent of the generated `decision.acceptFurtherLevel` value at that level.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — CREATE. The diagnosis types (`DiagnosisTrigger`, `DiagnosisEvent`, `DiagnosisTerminal`, `DiagnosisLevelDecision`, `DiagnosisOutcome`, `ProbeOutcome`, `DiagnosisProbeResult`, `DiagnosisHypothesisResult`) and the `DiagnosisRun` enum namespace (`open`, `classify`, `hypothesise`, `probe`, `offered`, `remediate`, `capped`, `returned`, `run`). Sibling of `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (task 02.10).
- `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift` — CREATE. Unit tests per named step and the §4.7 property suite.
- `Packages/Core/Tests/CoreTests/DiagnosisTier0CompletenessTests.swift` — CREATE. AC11.
- `Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift` — CREATE. AC12 (C1).
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY, append-only. Add this task's own generator(s) (e.g. a random `DiagnosisLevelDecision` sequence, a random `FailedProbeAttempt` list) to the existing `PropertyGen` enum; do not alter any existing function in this file.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` (task 02.07) — call `ExpeditionRun.start`/`.answer`/`.resume` only.
- `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` (task 02.10) — call `PrerequisiteQuery.deepestUnmasteredPrerequisite` by name only.
- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (task 02.10) — call `Classify.classify` by name only.
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift`, `Packages/Core/Sources/Core/State/Expedition.swift`, `Packages/Core/Sources/Core/ItemChecker.swift` — call their public functions only.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift`, `Packages/Core/Sources/Core/CoreError.swift` — every case this task needs already exists (verified below); no edit.
- `Packages/Core/Sources/Core/Model/*.swift`, `contracts/**`, `data/demo/**`, `docs/**` — read-only.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis (Door A)`:
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

  Byte-verified against `contracts/interaction-contract.md:76-99` in the current tree. The line "beyond the
  budget → `capped`: candidate `blocked`" (`:93-94`) is the sole textual anchor for the capped branch:
  `capped` is the terminal that fires exactly when the level reached is at or beyond the budget, with no
  condition on whether the student would have accepted a further level — the offer clause ("offered, never
  automatic") only governs the case where budget still remains. The `probe` bullet names three probe outcomes
  (`pass`, `fail`, `declined`) and states the fewer-than-2-items case separately as an error code — the anchor
  for the §6 `probe_completed` emission rule.

- `contracts/interaction-contract.md` — heading `## 5. Notifications (in-process names, exact)`:
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

- `contracts/domain-glossary.md:42`:
  > - **Probe** — two items on the candidate, ~60 s; outcome **pass / fail / declined** → diagnosis outcome
  >   **refuted / confirmed / unconfirmed / capped**.

- `contracts/telemetry.md` — heading `## Event kinds (closed enum `kind`) and their fields`, rows `item_result` and `edge_observation`:
  > | `item_result` | `node_id`, `correct`, `retry`, `tier` | expedition W2, diagnosis W3 |
  > | `edge_observation` | `edge_id`, `upstream_state ∈ {cleared, blocked, fog}`, `downstream_result ∈ {pass, fail}` | derived on device per prerequisite edge of the item's node (v2.5 §1) |

- `contracts/graph-constraints.md` — heading (unnumbered, "Query rules"):
  > **Query rules (also `Core`):** the deepest-unmastered-prerequisite query walks ≤ 2 levels breadth-first
  > (I4), treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest
  > depth marker, then node id (Q3). The fringe (D48) and the clear rule are in `interaction-contract.md`.

- `contracts/error-codes.json` (v1.0.0), the three `DIAG_*` entries (verbatim JSON):
  > `{"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."}`
  > `{"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."}`
  > `{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."}` — not thrown by this task (§6).

Domain-doc workflows (`docs/domains/diagnosis.md`), verbatim:

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
> **Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick questions,
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

`docs/domains/diagnosis.md` Q2–Q4 (ratified), verbatim:

> **Q2 — May the student decline the probe?** **Default:** yes — outcome `unconfirmed`, a hint on the origin,
> return; the run continues.
> …
> **Ratified 2026-09-09:** default accepted.
>
> **Q3 — Is the second level offered or automatic?** **Default:** offered ("want to look one step further
> upstream?"), never automatic, so a Door A event costs about a minute unless the student chooses more.
> …
> **Ratified 2026-09-09:** default accepted.
>
> **Q4 — Does "Check me here" on a node upstream of the marker count against the backtrack budget?**
> **Default:** the tapped node is the origin; the budget counts from it.
> …
> **Ratified 2026-09-09:** default accepted.

`docs/domains/diagnosis.md` notifications-produced list, verbatim:

> - `diagnosis.opened` — `{ origin_node, trigger }`; `diagnosis.hypothesis_formed` — `{ origin_node,
>   candidate_id, level, error_type|null }`; `diagnosis.remediation_shown` — `{ node_id }`;
>   `diagnosis.returned` — `{ origin_node, outcome }`. Consumers: **expedition**, **telemetry** (D40).
> - `diagnosis.probe_completed` — `{ candidate_id, edge_id, pass|fail|declined }`. Consumers: **expedition**
>   (state), **concept-graph** (local `ProbeStats`), **telemetry** (L3).
> - `diagnosis.node_blocked` — `{ node_id, level }`. Consumers: **expedition** (W4), **map** (W6).
> - `diagnosis.capped` — `{ origin_node, candidate_id, depth }`. Consumers: **expedition**, **map**.

Arbiter rulings (`tasks/arbitration/arbiter-02-predispatch.md`), verbatim:

> **Ruling [Q-A].** Adopt the planner default. This is a technical realisation of a ratified rule. … The
> field name is not on the identifier blocklist (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:246-248`).
>
> § 4 Diagnosis, `probe` bullet: change "`fail` → `confirmed` → candidate `blocked`, one remediation piece" to
> "`fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that
> piece is shown".
>
> **Merge (for Q-B).** The merged value is the logical OR of both sides. It is then removed unless the merged
> `mastery` is `blocked`.

> **Ruling [Q-C].** CONFIRMED as answerable from contracts. The Demo candidate is the graph query with budget
> 1, and no field is added. It lands in 02.10 (query) and 02.11 (budget 1 in the Demo configuration).

> **Ruling [Q-G].** "Available" excludes items whose answer was already shown in the current run. I3
> guarantees the answer is on screen after every item (`interaction-contract.md` § 2 `answer`: "always show
> correct answer + `why`"). A probe on an item answered minutes earlier in the same run tests recall of a
> displayed key, not the prerequisite.
>
> **Reachability on the real `data/demo`.** … Use a constructed `StudentState` and trail: `syllabi = [MTH1W]`,
> `exponent-laws` = `blocked`, `polynomials` = `blocked`, `simplifying-expressions` = `cleared`. Then run the
> following sequence:
> 1. The run shows `exponent-laws` (u2) before `polynomials` (u4) in trail order. `exponent-laws` item 1 is
>    missed and its retry (item 2) is answered correctly, so both of its answers have been shown.
> 2. `polynomials` is missed on its first item and again on the retry. That is the second miss, so a diagnosis
>    opens at `polynomials` with budget 1.
> 3. The candidate is `exponent-laws`. The edge confidence is 0.95 (`edges.json:36-51`), against 0.7 for
>    `simplifying-expressions` (`:228-243`), and `simplifying-expressions` is cleared in any case.
> 4. The candidate has 0 available items, so the result is `DIAG_PROBE_UNAVAILABLE` → `unconfirmed` → hint →
>    `returned`.
>
> **Test-data rule** (02.5, 02.6, 02.11):
> - In-memory bundles derived from `data/demo` are allowed for property tests over generated graphs (brief
>   AC5) and for the extension positive case (02.5, where `data/demo` has no `next_courses` target).
> - The C1 seams (AC7, AC8) and the AC6 terminal suite run on the real `data/demo` bundle. Only the
>   `StudentState` is constructed.
> - A test that substitutes a bundle there fails review.

Arbiter ruling (`tasks/arbitration/arbiter-02-11-probe-completed.md`), verbatim:

> 1. `.diagnosisProbeCompleted` **is emitted** on probe outcomes `pass` (`ProbeOutcome.refuted`), `fail`
>    (`ProbeOutcome.confirmed`) and `declined` (`ProbeOutcome.declined`) — exactly once per level at which one of
>    these outcomes occurs, after `.diagnosisHypothesisFormed` for that level and before any
>    `.diagnosisNodeBlocked` / `.diagnosisReturned`.
> 2. `.diagnosisProbeCompleted` **is not emitted** on `ProbeOutcome.unavailable` (`DIAG_PROBE_UNAVAILABLE`). The
>    terminal is carried by `.diagnosisReturned` plus `DiagnosisOutcome.code == .diagProbeUnavailable`.
> 3. **Representation of a declined probe.** `DiagnosisProbeResult(outcome: .declined, results: [],
>    incorrectAttempts: [], code: nil)`; the diagnosis terminal is `.unconfirmed` with `code == nil`,
>    `probeResults == []`, no `probeLog` row, `depthReached == level - 1`. Because `CoreEvent` is a bare name
>    (no payload), the `pass|fail|declined` payload value is carried by the pairing value
>    `DiagnosisProbeResult.outcome`, mapped `refuted → pass`, `confirmed → fail`, `declined → declined`;
>    `unavailable` has no payload value, which is why it emits no event.

`docs/epics/epic-02-core-behaviour.md` §4 items 5–7 (properties, Tier-0 completeness, C1), verbatim:

> 5. **§4 diagnosis.** Property tests over generated graphs and states cover the following:
>    - depth ≤ budget ≤ 2 from the origin;
>    - no path reaches remediation without a `fail` probe outcome;
>    - every `capped` or `confirmed` candidate is `blocked` in the output state. A `confirmed` candidate
>      carries `remediated = true` once its remediation piece is shown; a `capped` candidate does not (§9 Q-A);
>    - a second level is entered only on an explicit accept;
>    - fewer than 2 **available** items on the candidate → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`. An item
>      is available unless its answer was already shown in the current run (§9 Q-G);
>    - no candidate → `DIAG_NO_PREREQUISITE` → hint → `returned`;
>    - declining → `unconfirmed` → hint → `returned`;
>    - the query tie-break (highest confidence, then lowest depth, then node id) holds on constructed ties;
>    - every path terminates in `returned`.
> 6. **Tier 0 completeness (I2).** Each diagnosis terminal is reached with no adapter and no suggestion
>    input, over `data/demo` with the Demo budget of 1. The `DIAG_PROBE_UNAVAILABLE` terminal is reached on the
>    real `data/demo` with the constructed `StudentState` of §9 Q-G. Only the state is constructed; the bundle
>    is not substituted.
> 7. **C1 seam: expedition ↔ diagnosis.** A test drives a real expedition run on `data/demo` to a second
>    miss. It opens a **real** diagnosis event from the emitted `diagnosis_requested`, drives it to
>    `returned`, and resumes the **same** run at its next item. It asserts: the run's diagnosis count = 1; the
>    blocked candidate is visible to the resumed run's state; the answered items' answers remain present;
>    neither side is stubbed.

`docs/epics/epic-02-core-behaviour.md` § 9 Technical defaults, verbatim:

> - No unused item for a D27 retry → skip the retry, log `EXP_ITEM_POOL_EMPTY`, continue the run.
> - Item draw prefers items with no `probe_log` entry, then the least recently used, deterministic by
>   item id.
> - A hint whose error type has no `hint_tree` entry falls back to the node's `none-of-these` hint.
> - A `map_check_here` diagnosis outside a run logs no `expedition_log` entry (its effects are the
>   `blocked` marks and `probe_log` rows). `diagnosis_events` stays ≤ 1 per entry per the schema.

Prior signatures this task calls (verbatim, byte-verified against the current tree):

- `Packages/Core/Sources/Core/Model/StudentState.swift`:
  ```swift
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
  public struct ProbeLogEntry: Codable, Equatable {
      public let day: String
      public let nodeId: String
      public let itemId: String
      public let correct: Bool
      public let retry: Bool
  }
  ```

- `Packages/Core/Sources/Core/State/MasteryTransitions.swift`:
  ```swift
  public struct MasteryTransitionResult: Equatable {
      public let nodeState: NodeState
      public let event: CoreEvent?
  }
  /// The `fog | diagnosis_blocked(node) | — | blocked` row only. Called on a node whose
  /// `mastery != .fog`, this is a no-op (§6 default): returns `current` unchanged, `event: nil`.
  public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult
  ```

- `Packages/Core/Sources/Core/State/Expedition.swift`:
  ```swift
  public static func selectItem(
      from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]
  ) -> ProbeItem?
  ```

- `Packages/Core/Sources/Core/Model/Nodes.swift`:
  ```swift
  public struct Node: Codable, Equatable {
      public let id: String
      // ...
      public let errorTypes: [ErrorType]
      public let hintTree: [String: [String]]
      public let probeItems: [ProbeItem]
  }
  public struct ErrorType: Codable, Equatable {
      public let id: String
      public let label: String
      public let impliesPrerequisite: String?
  }
  ```

- `Packages/Core/Sources/Core/Events/CoreEvent.swift` (`:3-8` doc comment, then every case this task needs, already registered):
  ```swift
  /// The closed set of in-process notification names (`contracts/interaction-contract.md` § 5), one case
  /// per name, raw value the exact dotted string. `CoreEvent` is a bare name registry — it carries no
  /// payload; payloads are ids, enums, booleans and small integers only (I5), and a caller that needs to
  /// pair an event with data defines its own pairing type (e.g. `MasteryTransitionResult`) rather than
  /// this enum growing an associated value.
  public enum CoreEvent: String, CaseIterable, Equatable {
  case expeditionDiagnosisRequested = "expedition.diagnosis_requested"
  case diagnosisOpened = "diagnosis.opened"
  case diagnosisHypothesisFormed = "diagnosis.hypothesis_formed"
  case diagnosisProbeCompleted = "diagnosis.probe_completed"
  case diagnosisNodeBlocked = "diagnosis.node_blocked"
  case diagnosisCapped = "diagnosis.capped"
  case diagnosisRemediationShown = "diagnosis.remediation_shown"
  case diagnosisReturned = "diagnosis.returned"
  case graphPrerequisiteReturned = "graph.prerequisite_returned"
  ```

- `Packages/Core/Sources/Core/CoreError.swift` (every case this task needs already registered):
  ```swift
  case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
  case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
  case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
  ```

- `tasks/epic-02-task-07-item-checker-expedition-run.md:593-611` (`ExpeditionRunState`, produced by 02.07):
  ```swift
  public struct ExpeditionRunState: Equatable {
      public var queue: [ComposeSlot]
      public var currentItem: CurrentItem?
      public var diagnosisUsed: Bool
      public var missCounts: [String: Int]
      public var shownItemIds: Set<String>
      public var itemPoolEmptyNodeIds: [String]
      public var results: [ItemResult]
      public var clearedNodeIds: [String]
      public var blockedNodeIds: [String]
      public var itemsAnswered: Int
      public var suspendedForDiagnosisNodeId: String?
  }
  public struct ItemResult: Equatable {
      public let nodeId: String
      public let itemId: String
      public let correct: Bool
      public let correctAnswerDisplay: String
      public let why: String
      public let isRetry: Bool
  }
  public static func answer(
      run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String,
      today: CalendarDay
  ) -> AnswerOutcome
  public static func resume(run: ExpeditionRunState) -> ExpeditionRunState
  ```

- `tasks/epic-02-task-07-item-checker-expedition-run.md:539-560` (`ItemChecker`, produced by 02.07):
  ```swift
  public enum ItemChecker {
      public static func check(item: ProbeItem, submitted: String) -> Bool
      public static func correctAnswerDisplay(for item: ProbeItem) -> String
  }
  ```

- `tasks/epic-02-task-10-prerequisite-query-classify.md:306-338` (`PrerequisiteQuery`, produced by 02.10):
  ```swift
  public struct PrerequisiteCandidate: Equatable { public let node: Node; public let depth: Int; public let edgeConfidence: Double }
  public struct PrerequisiteQueryResult: Equatable { public let candidate: PrerequisiteCandidate?; public let code: CoreError? }
  public enum PrerequisiteQuery {
      public static func deepestUnmasteredPrerequisite(
          originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle,
          levelBudget: Int
      ) -> PrerequisiteQueryResult
  }
  ```
  Note: this function does not itself emit `CoreEvent.graphPrerequisiteReturned` — "task 02.11 (the diagnosis
  machine, the only caller) emits it alongside its own event sequence" (02.10 spec, same lines).

- `tasks/epic-02-task-10-prerequisite-query-classify.md:340-348` (`Classify`, produced by 02.10):
  ```swift
  public struct FailedProbeAttempt: Equatable {
      public let item: ProbeItem
      public let submittedValue: String
      public init(item: ProbeItem, submittedValue: String) { self.item = item; self.submittedValue = submittedValue }
  }
  public enum Classify { public static func classify(_ attempts: [FailedProbeAttempt]) -> String }
  ```

## §4 Implementation outline

1. **Layer.** `Sources/Core/Diagnosis/DiagnosisEvent.swift` is layer ④ interaction (the diagnosis workflow),
   composing layer ② concept-graph (`PrerequisiteQuery`) and layer ③ learning-objects data already carried on
   `Node` (`hintTree`, `probeItems`, `errorTypes`). It performs no I/O, no rendering, no system-clock read.

2. **Types** (all public, `Equatable`, no `Codable` needed — these values never cross the wire):
   ```swift
   public enum DiagnosisTrigger: String, Equatable {
       case expeditionSecondMiss = "expedition_second_miss"
       case mapCheckHere = "map_check_here"
   }
   public struct DiagnosisEvent: Equatable {
       public let originNodeId: String
       public let trigger: DiagnosisTrigger
       public let levelBudget: Int
   }
   public enum DiagnosisTerminal: Equatable { case refuted, confirmed, unconfirmed, capped, noPrerequisite }
   public struct DiagnosisLevelDecision: Equatable {
       public let declineProbe: Bool
       public let submittedAnswers: [String]     // matched in order to the 2 drawn probe items
       public let acceptFurtherLevel: Bool       // consulted only after a `confirmed` outcome AND budget remains
       public init(declineProbe: Bool, submittedAnswers: [String], acceptFurtherLevel: Bool) {
           self.declineProbe = declineProbe
           self.submittedAnswers = submittedAnswers
           self.acceptFurtherLevel = acceptFurtherLevel
       }
   }
   // Probe outcome. `refuted` = contract `pass`, `confirmed` = contract `fail`, `declined` = contract
   // `declined` (the three `diagnosis.probe_completed` payload values); `unavailable` = DIAG_PROBE_UNAVAILABLE,
   // not a probe outcome and never paired with `.diagnosisProbeCompleted` (§6).
   public enum ProbeOutcome: Equatable { case refuted, confirmed, declined, unavailable }
   public struct DiagnosisProbeResult: Equatable {
       public let outcome: ProbeOutcome
       public let results: [ItemResult]               // 0 or 2 entries; `isRetry` always false (§6)
       public let incorrectAttempts: [FailedProbeAttempt]  // for re-`classify` at the next level (§4 step 6)
       public let code: CoreError?                     // .diagProbeUnavailable iff outcome == .unavailable
   }
   public struct DiagnosisHypothesisResult: Equatable { public let queryResult: PrerequisiteQueryResult }
   public struct DiagnosisOutcome: Equatable {
       public let state: StudentState
       public let terminal: DiagnosisTerminal
       public let depthReached: Int              // deepest level at which `probe` actually ran; 0 if never
       public let blockedNodeIds: [String]       // every candidate that became blocked across all levels reached
       public let hintNodeId: String?            // == the top-level originNodeId whenever a hint is shown; nil otherwise
       public let hintErrorTypeId: String?       // resolved hint_tree key (with none-of-these fallback), nil otherwise
       public let probeResults: [ItemResult]     // every probe ItemResult across every level reached, in order
       public let events: [CoreEvent]
       public let code: CoreError?               // .diagNoPrerequisite / .diagProbeUnavailable, else nil
   }
   ```

3. **`DiagnosisRun.open(originNodeId:trigger:levelBudget:) -> DiagnosisEvent`.** Pure struct construction; no
   event returned here — `.diagnosisOpened` is emitted once by `run` (step 11) so the event ordering lives in
   one place.

4. **`DiagnosisRun.classify(_ attempts: [FailedProbeAttempt]) -> String`.** A named, one-line forward to
   `Classify.classify(attempts)`, kept as its own method because the plan names it as one of the machine's
   public steps (W1 step 2).

5. **`DiagnosisRun.hypothesise(originId:biasErrorTypeId:state:bundle:levelBudget:) -> DiagnosisHypothesisResult`.**
   A named forward to `PrerequisiteQuery.deepestUnmasteredPrerequisite(originId:biasErrorTypeId:state:bundle:levelBudget:)`,
   wrapped so `run` can attach its own event sequence per the 02.10 note above.

6. **`DiagnosisRun.probe(candidate:trigger:shownItemIdsInRun:declined:submittedAnswers:probeLog:) -> DiagnosisProbeResult`.**
   - `declined == true` → return `DiagnosisProbeResult(outcome: .declined, results: [], incorrectAttempts: [], code: nil)` immediately — no availability check, no draw (Q2: the student declines at W3 step 1, before any item is drawn).
   - Else compute `unavailableIds`: for `trigger == .expeditionSecondMiss`, `unavailableIds = Set(candidate.probeItems.map(\.id)).intersection(shownItemIdsInRun)`; for `trigger == .mapCheckHere`, `unavailableIds = []` (every item available, per Q-G).
   - `item1 = Expedition.selectItem(from: candidate, excluding: unavailableIds, probeLog: probeLog)`. If `nil` → `DiagnosisProbeResult(outcome: .unavailable, results: [], incorrectAttempts: [], code: .diagProbeUnavailable)`.
   - `item2 = Expedition.selectItem(from: candidate, excluding: unavailableIds.union([item1.id]), probeLog: probeLog)`. If `nil` → same `.unavailable` result (fewer than 2 available — Q-G/contract "Fewer than 2 items").
   - Else, for each of `[item1, item2]` paired with `submittedAnswers[0]`/`submittedAnswers[1]` (a missing entry — array shorter than 2 — is treated as an empty submission, which `ItemChecker.check` rejects as incorrect; §6), call `ItemChecker.check(item:submitted:)` and `ItemChecker.correctAnswerDisplay(for:)` to build an `ItemResult(nodeId: candidate.id, itemId:, correct:, correctAnswerDisplay:, why: item.why, isRetry: false)`.
   - `outcome = .refuted` iff both `ItemResult.correct == true`; else `.confirmed`. `incorrectAttempts` = `FailedProbeAttempt(item:, submittedValue:)` for every incorrect one (used to bias the next level's `hypothesise` call, step 11.g below); `code = nil` for both `.refuted` and `.confirmed`.

7. **`DiagnosisRun.offered(levelReached: Int, levelBudget: Int) -> Bool`.** Pure predicate: `levelReached <
   levelBudget` — "does budget remain to make a further-level offer at all", independent of whatever the
   student would decide. `run` consults this **before** ever reading `decision.acceptFurtherLevel`:
   - `false` (budget already exhausted at this level) → the offer is never constructed and
     `decision.acceptFurtherLevel` is never read; the flow goes straight to `capped`.
   - `true` (budget remains) → the offer is made; `run` then reads `decision.acceptFurtherLevel` to choose
     between `confirmed` (declined) and recursing to `levelReached + 1` (accepted).

   `run` never calls `hypothesise`/`probe` for `levelReached + 1` unless **both** `offered(...) == true` and
   `decision.acceptFurtherLevel == true` — this is the literal enforcement of "budget parameter checked before
   any probe" (I4).

8. **`DiagnosisRun.remediate(current: NodeState) -> NodeState`.** `let blocked = MasteryTransitions.diagnosisBlocked(current: current).nodeState` (a no-op if `current.mastery` was already `.blocked`); return `NodeState(mastery: blocked.mastery, correctCount: blocked.correctCount, lastProbe: blocked.lastProbe, nextDue: blocked.nextDue, ladderRung: blocked.ladderRung, remediated: true)`. Always called exactly once, immediately after a `.confirmed` probe outcome at any level (W4 steps 1–2 are inseparable in this design — see §6).

9. **`DiagnosisRun.capped(current: NodeState) -> NodeState`.** `MasteryTransitions.diagnosisBlocked(current: current).nodeState`, `remediated` field untouched (passed through as `current.remediated`, which — per step 8 — is already `true` by the time `capped` is reached, since every `capped` candidate was `remediate`d one step earlier in this design; see §6 for why W6's own "deeper candidate" language does not introduce a second, unprobed node here). This step is called from `run` (step 11.g's `false` branch below) — it is not dead code.

10. **`DiagnosisRun.returned(originNode: Node, hintErrorTypeId: String) -> (hintNodeId: String, hintErrorTypeId: String)`.**
    Resolves the hint-tree fallback key: if `originNode.hintTree[hintErrorTypeId]` is non-nil and non-empty, return
    `(originNode.id, hintErrorTypeId)`; else return `(originNode.id, "none_of_these")` (the technical default
    quoted in §3). This method returns *keys*, never the hint prose (I5, I14) — the caller resolves display text
    from the bundle at render time.

11. **`DiagnosisRun.run(trigger:originNodeId:failedAttempts:levelBudget:decisions:shownItemIdsInRun:state:bundle:today:) -> DiagnosisOutcome`.**
    The orchestrator every test in §5 calls. Signature:
    ```swift
    public static func run(
        trigger: DiagnosisTrigger, originNodeId: String, failedAttempts: [FailedProbeAttempt],
        levelBudget: Int, decisions: [DiagnosisLevelDecision], shownItemIdsInRun: Set<String>,
        state: StudentState, bundle: ContentBundle, today: CalendarDay
    ) -> DiagnosisOutcome
    ```
    Algorithm (a `level` loop from 1 through `levelBudget`, stopping at the first terminal):
    - `events = [.diagnosisOpened]`; `nodes = state.nodes`; `probeLog = state.probeLog`; `blockedNodeIds = []`;
      `hintErrorTypeIdForLevel1 = classify(failedAttempts)` (computed once, reused for the final hint lookup
      regardless of how deep the chain goes — "hint on origin" always means the *original* origin, step 12).
    - `queryOriginId = originNodeId`; `biasErrorTypeId = hintErrorTypeIdForLevel1`; `levelFailedAttempts = failedAttempts`.
    - For `level` in `1...levelBudget`:
      a. `hyp = hypothesise(originId: queryOriginId, biasErrorTypeId: biasErrorTypeId, state: StudentState(...nodes: nodes, probeLog: probeLog...), bundle: bundle, levelBudget: levelBudget - level + 1)`; `events.append(.graphPrerequisiteReturned)`.
      b. No candidate → build the final `StudentState` (nodes, probeLog updated so far), resolve the origin hint via `returned(originNode:, hintErrorTypeId: hintErrorTypeIdForLevel1)`, `events.append(.diagnosisReturned)`, return `DiagnosisOutcome(terminal: .noPrerequisite, code: .diagNoPrerequisite, depthReached: level - 1, ...)`.
      c. Candidate found → `events.append(.diagnosisHypothesisFormed)`. `decision = decisions.indices.contains(level - 1) ? decisions[level - 1] : DiagnosisLevelDecision(declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)` (§6 fallback).
      d. `probeResult = probe(candidate: hyp.queryResult.candidate!.node, trigger:, shownItemIdsInRun:, declined: decision.declineProbe, submittedAnswers: decision.submittedAnswers, probeLog: probeLog)`.
      e. Branch on the two non-checking outcomes (the `probe_completed` emission rule of §6 applies here):
         - `.declined` → `events.append(.diagnosisProbeCompleted)` (a probe outcome — payload value `declined`);
           resolve origin hint; `events.append(.diagnosisReturned)`; return `.unconfirmed` with `code: nil`
           (`probeResult.code`), no `probeLog` row added at this level, `depthReached: level - 1`.
         - `.unavailable` → **no** `.diagnosisProbeCompleted` (no probe was formed; `unavailable` is not a probe
           outcome); resolve origin hint; `events.append(.diagnosisReturned)`; return `.unconfirmed` with
           `code: .diagProbeUnavailable` (`probeResult.code`), `depthReached: level - 1`.
         See §6 for the `depthReached` convention on both.
      f. `.refuted` → `events.append(.diagnosisProbeCompleted)`, resolve origin hint, append `.diagnosisReturned`, return `.refuted` (`depthReached: level`, candidate's `nodes[candidateId]` left untouched).
      g. `.confirmed` → `events.append(contentsOf: [.diagnosisProbeCompleted, .diagnosisNodeBlocked])`; `nodes[candidateId] = remediate(current: nodes[candidateId] ?? <fog default, per 02.07's `priorNodeState` precedent>)`; `events.append(.diagnosisRemediationShown)`; `blockedNodeIds.append(candidateId)`; append the level's 2 `ItemResult`s to the running `probeLog` as `ProbeLogEntry(day: today.iso, nodeId: candidateId, itemId:, correct:, retry: false)`. Then consult `offered(levelReached: level, levelBudget: levelBudget)` — **whether budget remains for a further-level offer at all**:
         - `false` (`level >= levelBudget`, budget exhausted at this level) → the offer is never made and
           `decision.acceptFurtherLevel` is **never read**; `nodes[candidateId] = capped(current: nodes[candidateId]!)`;
           `events.append(contentsOf: [.diagnosisCapped, .diagnosisReturned])`; return `.capped` with
           `hintNodeId: nil, hintErrorTypeId: nil` (W6: no hint, the fixed "further upstream" framing is
           represented purely by `terminal == .capped`, §6), `depthReached: level`, `blockedNodeIds` as
           accumulated.
         - `true` (`level < levelBudget`, budget remains) → the offer is made; branch on
           `decision.acceptFurtherLevel`:
           - `false` (declines) → `events.append(.diagnosisReturned)`, return `.confirmed` (`depthReached:
             level`).
           - `true` (accepts) → set `queryOriginId = candidateId`, `biasErrorTypeId =
             classify(probeResult.incorrectAttempts)`, continue the loop to `level + 1` (guaranteed `<=
             levelBudget`, since `offered(...) == true` already established `level < levelBudget`).
    - The loop never iterates past `levelBudget`: at `level == levelBudget`, `offered(levelReached: level,
      levelBudget: levelBudget)` is `false` by construction, so a `.confirmed` outcome at the final budgeted
      level always falls into the `capped` branch above — `decision.acceptFurtherLevel` is never consulted at
      that level, and no separate post-loop step is needed.

12. **Hint node is always the top-level origin.** Every terminal that shows a hint (`noPrerequisite`, `refuted`,
    `unconfirmed`) resolves it via `returned(originNode: bundle.nodes.nodes.first { $0.id == originNodeId }!, hintErrorTypeId: hintErrorTypeIdForLevel1)` — never the intermediate candidate's own node, matching W3 step 4 ("hint on the origin") and W2 step 3 ("the origin's hint") verbatim. `capped` and `confirmed` show no hint (`hintNodeId == nil`).

13. **Final `StudentState`.** Exactly `state.nodes` (replaced with the accumulated `nodes` dict) and
    `state.probeLog` (replaced with the accumulated `probeLog`) differ from the input; `schemaVersion`,
    `formatVersionSeen`, `syllabi`, `marker`, `trail`, `expeditionLog`, `installDay`, `consentOn` are copied
    through unchanged — `expeditionLog` is **never** appended to by this function, satisfying AC10 for both
    triggers (the technical default names `map_check_here` explicitly; `expedition_second_miss` never touches
    `expeditionLog` either, since that log is owned exclusively by `ExpeditionRun.end`, task 02.07, out of
    scope here).

14. **Error codes thrown.** None — `DiagnosisRun` never `throws`; `DIAG_NO_PREREQUISITE` and
    `DIAG_PROBE_UNAVAILABLE` are represented as data on `DiagnosisOutcome.code` (mirroring `PrerequisiteQueryResult`'s
    own "code as data" shape, 02.10 §3 precedent note), consistent with I3 ("no terminal path gates an
    already-given answer" — a thrown error would abort before the hint/remediation is attached).
    `DIAG_STATE_WRITE_FAILED` is never thrown or returned by this task — it belongs to the caller's
    persistence layer (App/platform, EPIC 03), per the bundle's stack-constraints note.

15. **No model call anywhere in `DiagnosisRun`** (I2): `hypothesise` and `classify` are both named forwards to
    already-Tier-0 functions (02.10); `probe` calls only `ItemChecker.check`/`Expedition.selectItem`. No
    parameter of any function in this file accepts a Tier-1/Tier-2 adapter — the Tier-1 "suggest, never
    decide" path (`classify`'s contract note) is EPIC 13 scope and out of this file entirely.

16. Smoke check: `swift test --package-path Packages/Core --filter DiagnosisMachineTests` (then
    `DiagnosisTier0CompletenessTests` and `ExpeditionDiagnosisSeamTests`) — must be green, followed by the
    full `scripts/gate.sh`.

## §5 Test plan

Instrument for every case below: Swift Testing `@Test` functions run by `swift test --package-path Packages/Core`
(simulator via `xcodebuild test -scheme Core-Package` in the gate). Event-sequence assertions compare the full
`DiagnosisOutcome.events` array by `==`. An empty `events` array always FAILs, because AC1 requires
`.diagnosisOpened` and `.diagnosisReturned`.

- T1 happy path: for each of the six terminals (`refuted`, `confirmed`-not-capped at budget 2, `capped`,
  `unconfirmed`-declined, `unconfirmed`-unavailable, `noPrerequisite`) construct a small hand-built
  `ContentBundle`/`StudentState` fixture (or reuse `data/demo` where convenient) and assert the exact
  `terminal`, `code`, `hintNodeId`/`hintErrorTypeId`, `blockedNodeIds`, and `events` sequence per AC1–AC10.
  For the `capped` case, run it once with `decisions[0].acceptFurtherLevel == false` and once with `== true`,
  both at budget 1: both must yield `terminal == .capped` per AC6 (budget-exhausted at level 1, the offer is
  never made, `acceptFurtherLevel` is never read regardless of its value). The `probe_completed` rule (§6) is
  asserted by exact event arrays: the `.declined` terminal's `events == [.diagnosisOpened,
  .graphPrerequisiteReturned, .diagnosisHypothesisFormed, .diagnosisProbeCompleted, .diagnosisReturned]` with
  `code == nil` (AC3); the `.unavailable` terminal's `events == [.diagnosisOpened, .graphPrerequisiteReturned,
  .diagnosisHypothesisFormed, .diagnosisReturned]` with `code == .diagProbeUnavailable` (AC4) — no
  `.diagnosisProbeCompleted`; `refuted`, `confirmed` and `capped` each contain exactly one
  `.diagnosisProbeCompleted` per level probed; `noPrerequisite` contains none (AC2).
- T2 negative — invalid input rejected at the boundary: `DiagnosisRun.probe` called with `submittedAnswers`
  shorter than the number of drawn items never traps — the missing entry is treated as an incorrect
  submission (asserted directly, not just implied); `decisions` shorter than the levels actually reached never
  traps (the §6 fallback `DiagnosisLevelDecision` applies and the chain still reaches a terminal).
- T3 error-taxonomy: `DiagnosisOutcome.code == .diagNoPrerequisite` iff `terminal == .noPrerequisite`;
  `.diagProbeUnavailable` iff `terminal == .unconfirmed` from an unavailable probe (not from a decline, where
  `code == nil`); `CoreError ⊆` registry is already covered by the existing `ErrorRegistryTests` (no new case
  is added by this task — both codes are already registered, verified in §3).
- T4 conformance per `contracts/interaction-contract.md` § 4 and the applicable invariants: the full FSM
  (`opened → hypothesis → (probe|hint) → (remediation|hint) → returned`, `capped` as a terminal branch) is
  exercised end to end via `run`; I1 (probe checked by `ItemChecker`, never guessed); I2 (Tier-0 completeness,
  AC11); I3 (every `ItemResult` on `probeResults` carries `correctAnswerDisplay` and `why`, non-empty); I4
  (`depthReached ≤ levelBudget ≤ 2`, asserted as a property over generated `levelBudget ∈ {1, 2}`); I5
  (`DiagnosisOutcome`'s own new fields — `hintNodeId`, `hintErrorTypeId`, `terminal`, `code`, `depthReached`,
  `blockedNodeIds` — are ids/enums/booleans/ints only, asserted by a reflection-free type-level check: no
  `String` field on `DiagnosisOutcome` other than `hintNodeId`/`hintErrorTypeId`, both of which are always
  equal to a `Node.id` or a `hintTree` key, never free text).
- T5 negative control for every regression guard:
  - a mutated `DiagnosisRun.probe` that treats "any incorrect" as `.refuted` (inverted logic) must fail the
    T1 confirmed-candidate case;
  - a mutated `offered` that ignores `levelBudget` (always returns `true`) must fail the budget property test
    (AC8-style) once `levelBudget` is exhausted — with the mutation, a `.confirmed` outcome at `level ==
    levelBudget` would still make the further-level offer and consult `decision.acceptFurtherLevel`, instead
    of going straight to `.capped`;
  - a mutated `remediate` that skips setting `remediated` must fail AC6/AC9;
  - a mutated Q-G "available" check that ignores `shownItemIdsInRun` must fail AC4 / the Tier-0
    `DIAG_PROBE_UNAVAILABLE` reachability test (AC11);
  - a mutated step 11.e that swaps the `probe_completed` rule (emits on `.unavailable`, omits on `.declined`)
    must fail both T1 exact-array assertions (AC3 and AC4). A mutation that emits on both, or on neither, must
    fail exactly one of them. The two assertions are independent `@Test`s, so each direction is caught on its
    own.
- T6 idempotency / no-leak: `DiagnosisRun.run`, called twice with the same arguments, returns `Equatable`-equal
  `DiagnosisOutcome`s (pure function, no hidden mutable state); a `.refuted` or `.noPrerequisite` outcome's
  `state.nodes` is byte-identical to the input `state.nodes` (no side effect on a path that found nothing
  wrong with the candidate/no candidate at all).
- T7 (AC13) properties over `PropertyGen`-generated graphs/states, `DiagnosisMachineTests.swift`: the 9
  bullets of §3's Properties/§4-item-5 quote, each as an independent `@Test` with a seeded generator loop
  (matching `PropertyGen`'s existing style — deterministic, no system-clock read). The generator varies
  `levelBudget ∈ {1, 2}` and, independently, `decision.acceptFurtherLevel ∈ {true, false}` at the level where
  `levelReached == levelBudget`, asserting in every case that a `.confirmed` outcome there yields `terminal ==
  .capped` (never `.confirmed`) regardless of the generated `acceptFurtherLevel` value — the properties named
  in §3 as "every `capped` or `confirmed` candidate is `blocked` in state" and "depth ≤ budget ≤ 2 from the
  origin" both hold specifically across this branch. The generated-case count must be > 0 (empty = FAIL).
- T8 (AC11) Tier-0 completeness, `DiagnosisTier0CompletenessTests.swift`: every terminal reached on the real
  `data/demo` bundle (`BundleIO.read(from:)`, precedent shape in `MarkerTrailFringeSeamTests.swift`), Demo
  `levelBudget = 1`, no adapter parameter present anywhere in the call graph (there is none to omit — `run`'s
  signature has no adapter parameter at all, which is itself the I2 proof). `DIAG_PROBE_UNAVAILABLE` uses the
  arbiter's exact constructed-state recipe (§3, `tasks/arbitration/arbiter-02-predispatch.md` § Q-G
  "Reachability"), and its `events` array contains no `.diagnosisProbeCompleted` (§6).
- T9 (AC12) C1 seam, `ExpeditionDiagnosisSeamTests.swift`: a real `ExpeditionRun.start` on real `data/demo`,
  two real `.answer` calls on the same node driving it to a second miss (`events` containing
  `.expeditionDiagnosisRequested`), a real `DiagnosisRun.run` call using `run.shownItemIds` for
  `shownItemIdsInRun` and the second miss's own `FailedProbeAttempt`s for `failedAttempts`, a real
  `ExpeditionRun.resume(run:)` call, then one more real `.answer` call using the diagnosis outcome's `.state`
  as the threaded `StudentState` (per the bundle's hand-off note — `resume` itself takes no `StudentState`).
  The `decisions` array passed to `DiagnosisRun.run` explicitly sets `declineProbe: false` with incorrect
  `submittedAnswers` for the confirmed candidate at every level actually reached (never relying on the §6
  fallback default, which declines) — AC12 requires a `blocked` candidate, which only a `.confirmed` outcome
  produces. Because the probe ran to `fail`, the diagnosis outcome's `events` contain exactly one
  `.diagnosisProbeCompleted` (§6 rule, `fail` case). This test does not exercise the `.declined`/`.unavailable`
  branches. If it is later extended to do so, it must apply the same §6 rule T1 asserts: the event is present
  on a decline and absent on an unavailable probe. It must never choose a second, independent convention.
  Asserts: exactly one diagnosis was driven (a single `DiagnosisRun.run` call in the test, and
  `run.diagnosisUsed == true` throughout); the diagnosis's `blockedNodeIds` candidate has `mastery ==
  .blocked` in the `StudentState` used for the next `.answer` call; every `ItemResult` from the pre-diagnosis
  answers is still present in `run.results` after `resume`; neither `ExpeditionRun` nor `DiagnosisRun` is
  stubbed anywhere in this test.

## §6 Decision defaults

- IF `level >= levelBudget` after a `.confirmed` probe (budget exhausted at this level) THEN the flow enters
  `.capped` immediately, without ever reading `decision.acceptFurtherLevel` — the offer described by W4 step 3
  ("offer — not force") is a **conditional courtesy that itself requires budget to remain**; once budget is
  exhausted there is nothing left to offer, so `run` never constructs or consults an offer at that level. The
  "deeper candidate" of W6's text is the **same, already-`confirmed`-and-`remediate`d level-`level` candidate**,
  not a newly discovered one; `capped` therefore never touches a node the flow has not already blocked one step
  earlier (per `contracts/interaction-contract.md` § 4: "beyond the budget → `capped`: candidate `blocked`" —
  the sentence's own subject, "candidate", is the one just named by the preceding "After confirmed" clause, not
  a new noun). This keeps `remediate`'s "shown" and `capped`'s "blocked" acting on one node, never two, per
  level, and makes `decision.acceptFurtherLevel` unreachable/unread whenever `level >= levelBudget` — a
  property T5 and T7 both assert directly.
- IF a `.confirmed` probe's node is offered a further level but the student declines (`acceptFurtherLevel ==
  false`) while budget still remains THEN the terminal is plain `.confirmed`, not `.capped` — `capped` is
  reserved for the budget-exhaustion path, never for a voluntary decline (`docs/domains/diagnosis.md` W4 step
  3: "offer — not force"; declining is a normal `.confirmed` return, matching AC7/property "a second level is
  entered only on an explicit accept").
- IF `decisions.count < level` when level `level`'s decision is needed THEN default to
  `DiagnosisLevelDecision(declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)` — the safest
  Tier-0 reading (never guesses an answer, never forces a probe the caller did not explicitly authorize),
  matching I2's "the system never guesses a diagnosis."
- **`probe_completed` emission rule** (per `tasks/arbitration/arbiter-02-11-probe-completed.md`):
  - IF `probeResult.outcome ∈ {.refuted, .confirmed, .declined}` THEN `.diagnosisProbeCompleted` is emitted
    exactly once for that level, after that level's `.diagnosisHypothesisFormed` and before any
    `.diagnosisNodeBlocked`/`.diagnosisReturned`. The domain payload names these three values
    (`docs/domains/diagnosis.md` notifications-produced: "`{ candidate_id, edge_id, pass|fail|declined }`"),
    and `contracts/domain-glossary.md:42` defines the probe's outcomes as "**pass / fail / declined**".
  - IF `probeResult.outcome == .unavailable` THEN `.diagnosisProbeCompleted` is **not** emitted.
    `DIAG_PROBE_UNAVAILABLE` is not a probe outcome: W3's **Pre** is "two items available", the contract states
    "Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`" apart from the three probe-outcome arrows,
    and the payload enum has no `unavailable` value. The terminal is carried by `.diagnosisReturned` plus
    `DiagnosisOutcome.code == .diagProbeUnavailable`.
  - This rule is applied identically at every level and in every test in this file (AC3, AC4, T1, T5, T8, T9).
    No test in this file may assert the opposite reading.
- IF a consumer needs the `probe_completed` payload value THEN it reads the pairing value
  `DiagnosisProbeResult.outcome`, mapped `.refuted → pass`, `.confirmed → fail`, `.declined → declined`.
  `CoreEvent` is a bare name registry that "carries no payload" (`Packages/Core/Sources/Core/Events/CoreEvent.swift:3-8`),
  so this file adds no associated value and no new type. A declined probe is represented as
  `DiagnosisProbeResult(outcome: .declined, results: [], incorrectAttempts: [], code: nil)`. It produces no
  `ItemResult` and no `probeLog` row, and therefore no telemetry `item_result` or `edge_observation`, whose
  `downstream_result ∈ {pass, fail}` (`contracts/telemetry.md` § Event kinds). That derivation is EPIC 11 scope.
- IF `probeResult.outcome ∈ {.declined, .unavailable}` THEN `depthReached` for that terminal equals `level - 1`
  (the candidate was named by `hypothesise` but the probe itself never produced a check result) — this keeps
  "depth" meaning "levels actually probed to a pass/fail decision," matching the properties bullet "no path
  reaches remediation without a `fail` probe outcome" (declined/unavailable never remediate, so they should
  not count toward depth either). This is a defensible reading, not a contract-verbatim rule; if a later
  conformance test disagrees, it is a Q4 to the spec-arbiter, not a silent respec here.
- IF the classified `errorTypeId` names a key absent from the candidate node's `hintTree` (or the classified
  value is itself `"none_of_these"` and that key is also absent) THEN `returned` resolves to the literal key
  `"none_of_these"` regardless — the caller/renderer is responsible for handling a still-missing entry at
  render time (out of `Core`'s I14 renderer-free scope); this task does not raise a new error code for that
  case, since none is registered for it and adding one is a contract bump, out of scope.
- IF a `.confirmed` candidate's `NodeState` is absent from `state.nodes` (an unmastered `fog` node with no
  prior entry) THEN `remediate` is called with `NodeState(mastery: .fog, correctCount: 0, lastProbe: nil,
  nextDue: nil, ladderRung: 0, remediated: nil)` as `current` — the same "absent means fresh fog" convention
  `ExpeditionRun.answer` already uses for its own `priorNodeState` (`tasks/epic-02-task-07-item-checker-
  expedition-run.md:668-669`), applied independently here rather than copied, since `MasteryTransitions
  .diagnosisBlocked`'s own `mastery == .fog` guard requires exactly this default to ever fire.
- IF `submittedAnswers` has fewer entries than drawn probe items for a given level THEN the missing entry is
  treated as the empty string `""`, which `ItemChecker.check` (02.07, its own grammar table) already defines
  as never matching any answer — this is a T2 assertion, not new logic in `DiagnosisRun` itself.
- Standing default: identifiers and timestamps follow `contracts/data-model.md` § Identifiers/§ Time (kebab-case
  node/error-type ids; calendar-day granularity via the injected `CalendarDay today`, never `Date()`).
- Standing default: no model call anywhere in this file (I2); the Tier-1 "suggest, never decide" classify path
  is EPIC 13 scope, entirely outside `DiagnosisRun`.
- Standing default: telemetry is out of scope here — `diagnosis.probe_completed`'s L3 telemetry payload
  (edge, upstream state, downstream result) is derived by a telemetry consumer from the emitted `CoreEvent`
  sequence and the paired `DiagnosisProbeResult` in a later EPIC (11), not constructed by this file.
- Standing default: `StudentState.remediated` is set only by `remediate`, cleared only elsewhere (EPIC 03/04,
  on `cleared`) — this file never clears it.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages`)
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package` on the simulator, or `swift test --package-path Packages/Core` locally)
- tests green for every case in §5 (T1–T9), including `DiagnosisMachineTests.swift`,
  `DiagnosisTier0CompletenessTests.swift`, `ExpeditionDiagnosisSeamTests.swift`
- `scripts/gate.sh` green end to end
- conforms to every contract section cited in §3 and §4 (`interaction-contract.md` § 4 and § 5,
  `domain-glossary.md` Probe entry, `telemetry.md` Event kinds, `graph-constraints.md` Query rules,
  `error-codes.json`'s three `DIAG_*` entries) and to every invariant listed in §1 (I1, I2, I3, I4, I5, I14, D27)

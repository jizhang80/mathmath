# Epic 02 · Task 11: Diagnosis machine (§4 state machine, step-wise) + C1 expedition↔diagnosis seam

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

Goal: Implement the Door A diagnosis state machine (`contracts/interaction-contract.md` § 4; `docs/domains/diagnosis.md` W1–W6) as a pure, **step-wise** `Core` module. The states are `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a terminal branch. There is one public function per student decision point, each returning the next phase value, the threaded `StudentState` and that call's `CoreEvent`s. This mirrors `ExpeditionRun`. The machine is reachable from either trigger and is budget-checked on cumulative graph depth. The task also ships a thin batch driver built only on the step functions, its Tier-0 completeness suite, and the C1 expedition↔diagnosis seam test. That test drives a real `ExpeditionRun` into a real step-wise diagnosis and back. The step-wise shape is mandated by `tasks/arbitration/arbiter-02-11-stepwise-api.md`: a touch UI (EPIC 04) learns each decision only after showing the previous screen, and the render layer may not compute state (I14).

Invariants in play:
- **I1** — every probe item is checked by `ItemChecker.check` inside `DiagnosisRun.answerProbeItem`; no code path lets a model decide `pass`/`fail`.
- **I2** — every diagnosis workflow (W1–W6) completes with no adapter; no public function has an adapter parameter; the Tier-0 completeness suite proves this over real `data/demo`.
- **I3** — every `answerProbeItem` call returns the checked item's `ItemResult` (with `correctAnswerDisplay` and `why`) on the same `DiagnosisAdvance` that carries the next phase, so an answer is shown before any next item or terminal is reachable. The terminal outcome keeps every probe `ItemResult` in `probeResults`. No path withholds an already-answered item's answer.
- **I4** — `level` is the **cumulative graph depth from the origin** (sum of `PrerequisiteCandidate.depth` along the chain). Each hypothesis queries only `levelBudget - priorLevel` levels. A `confirmed` probe with `level >= levelBudget` constructs no `FurtherLevelOffer`, so no further-level decision can be taken. The confirmed candidate keeps its W4 effects (`blocked`, one remediation piece, `remediated = true`). W6 then runs in the same advance: the confirmed candidate's own unmastered prerequisite one level up (W6's "deeper candidate") is marked `blocked` in `StudentState` only, with no probe, no remediation and no `remediated`, and the terminal is `capped`. If there is no such prerequisite, the terminal is `confirmed`. `depthReached` counts probed depth only, and `depthReached ≤ levelBudget ≤ 2` holds on every path. Deeper gaps are marked on the map only (`CLAUDE.md` I4; `tasks/arbitration/arbiter-02-11-capped-remediated.md`).
- **I5** — `DiagnosisOutcome` carries only ids (`nodeId`, `errorTypeId`), enums, booleans and small integers, plus the already-I5-cleared `ItemResult` type (02.07); no new free-text field is added to `StudentState`.
- **I14** — `Sources/Core/Diagnosis/DiagnosisEvent.swift` imports Foundation only; every function is a pure value transformation; no `Date()` call (an injected `CalendarDay` `today` is threaded through, per the `MasteryTransitions`/`ExpeditionRun` precedent). The App drives the machine only through the public step functions. The internal helpers are not reachable from `App/Sources`, and no phase value has a public initializer, so the App cannot compute or forge a diagnosis state.
- **D27** — at most one diagnosis per expedition run; this task never re-triggers itself — the caller decides whether to call `DiagnosisRun.start`.

Acceptance criteria (every AC except AC15 is asserted by driving the **step API** directly; "the sequence" means the concatenation of every `DiagnosisAdvance.events` from `start` through the terminal advance):

- AC1: `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` returns a `DiagnosisEvent` carrying exactly its three arguments for both `trigger` values (`.expeditionSecondMiss`, `.mapCheckHere`). `start`'s advance begins with `.diagnosisOpened`. Every path's terminal advance (`step == .returned`) ends with `.diagnosisReturned`. In the sequence each of the two appears exactly once, first and last. The sequence `==` the terminal `DiagnosisOutcome.events`, and every non-terminal advance's `step` is not `.returned`.
- AC2: A `start` whose hypothesis finds no candidate returns `.returned` directly with `terminal == .noPrerequisite`, `code == .diagNoPrerequisite`, `hintNodeId == originNodeId`, `outcome.events == [.diagnosisOpened, .graphPrerequisiteReturned, .diagnosisReturned]`, and `state.nodes` unchanged from the input.
- AC3: `start` → `.probeOffer`, then `decideProbe(accept: false)`, gives `.returned` with `terminal == .unconfirmed`, `code == nil`, `hintNodeId == originNodeId`, `probeResults == []`, and `state.probeLog` unchanged. The advance's `probeResult == DiagnosisProbeResult(outcome: .declined, results: [], incorrectAttempts: [], code: nil)` and its `events == [.diagnosisProbeCompleted, .diagnosisReturned]`. The full sequence `== [.diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed, .diagnosisProbeCompleted, .diagnosisReturned]` (`tasks/arbitration/arbiter-02-11-probe-completed.md`).
- AC4: `decideProbe(accept: true)` on a candidate with fewer than 2 available items (per the Q-G "available" rule) gives `.returned` with `terminal == .unconfirmed`, `code == .diagProbeUnavailable`, `hintNodeId == originNodeId` and `probeResults == []`. The advance's `probeResult?.outcome == .unavailable`, and its `events == [.diagnosisReturned]`, with **no** `.diagnosisProbeCompleted`. The full sequence `== [.diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed, .diagnosisReturned]`.
- AC5: `decideProbe(accept: true)` with ≥ 2 available items returns `.probeItem(p)` with `p.items.count == 2`, `p.levelResults == []`, `events == []`. The first `answerProbeItem` returns `.probeItem(p')` with `p'.levelResults.count == 1`, `itemResult != nil`, `events == []`. When both items are answered correctly, the second call returns `.returned` with `terminal == .refuted`, `hintNodeId == originNodeId`, `state.nodes[candidateId]` unchanged, `probeResults.count == 2`, and advance `events == [.diagnosisProbeCompleted, .diagnosisReturned]`.
- AC6 (capped, budget 1): Fixture: the real `data/demo` bundle, `open(originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)`, and a constructed `StudentState` in which `exponent-laws` and `solving-linear-equations` are absent from `state.nodes` (fog). The candidate is `c == "exponent-laws"` and its only prerequisite is `d == "solving-linear-equations"` (`data/demo/edges.json:21-22`, `:37-38`). A second `answerProbeItem` with at least one incorrect answer among the 2 returns `.returned` with `terminal == .capped` directly. No `.furtherLevelOffer` step is ever returned on this path, because the budget is exhausted (`level 1 == levelBudget 1`). The advance's `state` has:
  - `state.nodes[c]!.mastery == .blocked` and `state.nodes[c]!.remediated == true` (confirmed, remediation piece shown);
  - `state.nodes[d]!.mastery == .blocked` and `state.nodes[d]!.remediated == nil` (a `capped` node never has `remediated` written; `contracts/data-model.md` § StudentState);
  - no `probeLog` row with `nodeId == d`.

  The outcome has `blockedNodeIds == [c, d]`, `depthReached == 1` and `hintNodeId == nil`. The advance `events == [.diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown, .graphPrerequisiteReturned, .diagnosisNodeBlocked, .diagnosisCapped, .diagnosisReturned]`. The thin driver `run` on the same fixture yields `.capped` both for `decisions[0].acceptFurtherLevel == false` and for `== true`.
- AC6b (exhausted budget, no deeper gap): the AC6 fixture with `solving-linear-equations` set to `cleared` in `state.nodes`, and the same failed probe. The call returns `.returned` with `terminal == .confirmed`, `code == nil` and `hintNodeId == nil`. The outcome has `state.nodes[c]!.mastery == .blocked`, `state.nodes[c]!.remediated == true`, `state.nodes["solving-linear-equations"]` unchanged from the input, `blockedNodeIds == [c]` and `depthReached == 1`. The advance `events == [.diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown, .graphPrerequisiteReturned, .diagnosisReturned]`. The sequence contains no `.diagnosisCapped`, and no `.furtherLevelOffer` is ever returned.
- AC7: The same confirmed case at budget 2 with a depth-1 candidate (`1 < 2`, budget remains) returns `.furtherLevelOffer(f)` with `f.candidateId == candidateId`. Its `state` has `state.nodes[candidateId]!.mastery == .blocked` and `state.nodes[candidateId]!.remediated == true`, and its `events == [.diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown]`. `decideFurtherLevel(f, accept: false)` then returns `.returned` with `terminal == .confirmed` (not `.capped`), `hintNodeId == nil` and `events == [.diagnosisReturned]`. The sequence contains no `.diagnosisCapped`.
- AC8: The same offer, `decideFurtherLevel(f, accept: true)`: the advance's `events` begin `[.graphPrerequisiteReturned, …]`, and the hypothesis uses the level-1 candidate `c1` as query origin with `levelBudget - 1` levels. On a found level-2 candidate `c2`, the step is `.probeOffer` with `context.level == 2`. Accept that probe and fail it at `level == levelBudget == 2`, on a fixture where `c2` has an unmastered prerequisite `c3` one level up. The call returns `.returned` directly with:
  - `terminal == .capped`, `blockedNodeIds == [c1, c2, c3]` and `depthReached == 2`;
  - `remediated == true` on `c1` and `c2`;
  - `c3`'s `remediated` equal to its input value (`nil` on a fresh fog node), and no `probeLog` row for `c3`.

  No second `.furtherLevelOffer` is returned.
- AC8b (I4, cumulative depth): at budget 2, a level-1 candidate `c` at graph depth 2 (`PrerequisiteCandidate.depth == 2`) gives `.probeOffer` with `context.level == 2`. Fail its probe, on a fixture where `c` has an unmastered prerequisite `d` one level up (graph depth 3 from the origin). The call returns `.returned` with `terminal == .capped`, `blockedNodeIds == [c, d]` and `depthReached == 2`: `d` is marked, not probed, so its depth is not counted. It never returns a `.furtherLevelOffer`.
- AC9: `remediated` is set `true` only by the confirmed branch of `answerProbeItem`, and only on the probed candidate that failed (via the internal `remediate` helper). It is set unconditionally at that step, since `Core` has no separate "shown" event to wait on. The internal `capped` helper never writes it: the W6 node's `remediated` equals its input value (absent stays absent). No other path writes it: `refuted`, declined, unavailable, `noPrerequisite` and `decideFurtherLevel`. `contracts/data-model.md` § StudentState: "A node blocked by `capped` … does not carry it".
- AC10: no step function ever changes `state.expeditionLog` (for both triggers); only `state.nodes` and `state.probeLog` change, and only in the confirmed branch of `answerProbeItem`.
- AC11 (Tier-0 completeness, `DiagnosisTier0CompletenessTests.swift`): each of the following is reached by step API calls over the real `data/demo` bundle, at Demo budget 1, with no adapter parameter anywhere in the call chain: `noPrerequisite`, `refuted`, `confirmed` (the AC6b recipe), `capped` (the AC6 recipe), `unconfirmed`-declined and `unconfirmed`-unavailable. `DIAG_PROBE_UNAVAILABLE` is reached via the arbiter's constructed-state recipe (§3).
- AC12 (C1 seam, `ExpeditionDiagnosisSeamTests.swift`): a real `ExpeditionRun.start`/`.answer` sequence on real `data/demo` reaches a second miss (`AnswerOutcome.events` containing `.expeditionDiagnosisRequested`). Real step calls (`open` → `start` → `decideProbe` → `answerProbeItem` × 2, none stubbed) drive that miss to a terminal. `ExpeditionRun.resume(run:)` is then called on the suspended run, and the run continues to its next item with the terminal advance's `state` threaded into the next `ExpeditionRun.answer`. Exactly one diagnosis is driven. The diagnosis's probed candidate is visible in the threaded `StudentState` as `blocked` with `remediated == true`. Every prior answered item's `ItemResult` is still present in `run.results`.
- AC13 (properties, `DiagnosisMachineTests.swift`, generated graphs/states): the 9 properties of §3 (epic §4 item 5) hold when the machine is driven step by step with generated accept/decline and answer choices. This includes:
  - the Q3 tie-break on constructed ties;
  - "every path terminates in `.diagnosisReturned`";
  - "every `capped` or `confirmed` candidate is `blocked` in state";
  - "a `confirmed` candidate carries `remediated = true` once its remediation piece is shown; a `capped` candidate does not" (asserted as: each failed probed candidate has `remediated == true`; when `terminal == .capped`, the W6 node `blockedNodeIds.last` has `remediated` equal to its input value);
  - "`depthReached ≤ levelBudget ≤ 2`".

  Additionally, **driver equivalence**: for every generated `decisions` array, `DiagnosisRun.run(...)` `==` the terminal outcome obtained by feeding the same decisions to the step functions by hand.
- AC14 (I3 per item): every `answerProbeItem` advance carries `itemResult != nil` with non-empty `correctAnswerDisplay` and `why`, `itemResult.isRetry == false`. The terminal `probeResults` equals the ordered list of every `itemResult` returned along the path.
- AC15 (no forged phases): `DiagnosisEvent.swift` declares exactly one `public init`, `DiagnosisLevelDecision`'s. `ProbeOffer`, `ProbeInProgress`, `FurtherLevelOffer`, `DiagnosisContext`, `DiagnosisOutcome`, `DiagnosisAdvance`, `DiagnosisProbeResult` and `DiagnosisEvent` rely on Swift's internal memberwise initializer. Instrument: `grep -c 'public init' Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` prints `1` (0 or ≥ 2 = FAIL).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — CREATE. Public diagnosis types (`DiagnosisTrigger`, `DiagnosisEvent`, `DiagnosisTerminal`, `ProbeOutcome`, `DiagnosisProbeResult`, `DiagnosisOutcome`, `DiagnosisContext`, `ProbeOffer`, `ProbeInProgress`, `FurtherLevelOffer`, `DiagnosisStep`, `DiagnosisAdvance`, `DiagnosisLevelDecision`) and the `DiagnosisRun` enum namespace. It exposes the public `open`, `start`, `decideProbe`, `answerProbeItem`, `decideFurtherLevel` and `run` (thin driver), and the internal helpers `classify`, `hypothesise`, `drawProbeItems`, `offered`, `remediate`, `capped`, `hintKey`, `terminal`. Sibling of `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (task 02.10).
- `Packages/Core/Tests/CoreTests/DiagnosisMachineTests.swift` — CREATE. Step-function unit tests, internal-helper tests, the §3 property suite, driver equivalence.
- `Packages/Core/Tests/CoreTests/DiagnosisTier0CompletenessTests.swift` — CREATE. AC11.
- `Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift` — CREATE. AC12 (C1).
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY, append-only. Add this task's own generators (a random `DiagnosisLevelDecision` sequence, a random accept/decline + answer-choice script for the step API, a random `FailedProbeAttempt` list) to the existing `PropertyGen` enum; do not alter any existing function in this file.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` (task 02.07) — call `ExpeditionRun.start`/`.answer`/`.resume` only.
- `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` (task 02.10) — call `PrerequisiteQuery.deepestUnmasteredPrerequisite` by name only.
- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (task 02.10) — call `Classify.classify` by name only.
- `Packages/Core/Sources/Core/State/MasteryTransitions.swift`, `Packages/Core/Sources/Core/State/Expedition.swift`, `Packages/Core/Sources/Core/ItemChecker.swift` — call their public functions only.
- `Packages/Core/Sources/Core/Events/CoreEvent.swift`, `Packages/Core/Sources/Core/CoreError.swift` — every case this task needs already exists (verified in §3); no edit.
- `Packages/Core/Sources/Core/Model/*.swift`, `App/**`, `contracts/**`, `data/demo/**`, `docs/**` — read-only.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis (Door A)` (`:76-99`):
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

  **Capped anchor** (per `tasks/arbitration/arbiter-02-11-capped-remediated.md`).
  - The `probe` bullet's `fail` arrow applies to **every** failed probe, including the one at the last budgeted
    level: "candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown".
  - "beyond the budget → `capped`: candidate `blocked`, "further upstream — it's on your map"" (`:93-94`) names
    **no** remediation piece. W4 step 3 ("beyond the cap, W6") and W6 ("no probe, no remediation; the deeper
    candidate is marked `blocked`") identify its subject: the next unmastered gap upstream of the confirmed
    candidate, which the budget forbids probing.
  - A `capped` node is therefore never the same node as a `fail` candidate, and it never has `remediated`
    (`contracts/data-model.md` § StudentState, below).
  - The contract property "every capped or failed candidate is `blocked`" lists the two as distinct candidates.
  - "Depth ≤ 2 from origin" is the backtrack depth (probed and remediated). The W6 node is beyond it by
    definition and is "marked on the map only" (`CLAUDE.md` I4).
  - "within remaining levels" (`:84`) and "depth ≤ 2 from origin" (`:97`) anchor the cumulative-depth convention
    (§6).
  - The `probe` bullet names three probe outcomes (`pass`, `fail`, `declined`) and states the fewer-than-2-items
    case separately as an error code. That is the anchor for the §6 `probe_completed` emission rule.

- `contracts/data-model.md` — heading `### StudentState (`student-state.schema.json`)` (`:143-147`):
  > `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe
  > outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step
  > and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node
  > blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a
  > fact about a node, never about a person, device, install or session (I5).

- `contracts/interaction-contract.md` — heading `## 2. Expedition (Door B)`, `compose` bullet (`:32-37`), the
  consumer of `remediated`:
  > - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  >   cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  >   requested unit only) ∪ `{n : mastery(n) = blocked}`. …
  >   `remediated(p)` ≡ `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).

  Landed guard, `Packages/Core/Sources/Core/State/Expedition.swift:183-194` (read-only here):
  ```swift
  private static func isRemediated(_ nodeId: String, in state: StudentState) -> Bool {
      state.nodes[nodeId]?.remediated ?? false
  }

  private static func prerequisiteGuardSatisfied(
      _ nodeId: String, state: StudentState, edgesByTo: [String: [Edge]]
  ) -> Bool {
      (edgesByTo[nodeId] ?? []).allSatisfy { edge in
          let p = edge.from
          return mastery(of: p, in: state) == .cleared
              || (mastery(of: p, in: state) == .blocked && isRemediated(p, in: state))
      }
  }
  ```
  A `remediated == true` on a capped node would open this guard for a gap the student was never remediated on.

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

Project invariants (`CLAUDE.md`), verbatim:

> | I4 | Remediation is just-in-time: **backtrack ≤ 2 levels per session**; **deeper gaps are marked on the map only** — no record page, no other consumer. | D4 |

> | I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42 |

Downstream consumers (the reason the API is step-wise), verbatim:

- `docs/epic-plan.md:23`, EPIC 04 row (excerpt): "**App: Expedition (Door B) + Diagnosis (Door A) + acceptance instrument** — item view (numeric keypad / choices), answer card with `why`, retry, hypothesis card, probe, remediation, return, summary; … | App↔`Core` state transitions (every screen action is a `Core` call) | App build; one full expedition + one diagnosis completable by touch on the simulator (§8)".
- `docs/epics/epic-03-app-map-shell.md:58-59`: "**Check me here** → `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` with trigger `map_check_here` and the Demo budget of 1 (02b, task 02.11)."
- `docs/epics/epic-03-app-map-shell.md:268` (W6 test): "a **real** `DiagnosisRun.run` `confirmed` outcome (block), both on `data/demo`" — the reason the thin driver `run` is kept.
- `docs/epics/epic-03-app-map-shell.md:473-476`: "**Note for EPIC 04, not in scope here.** The 02.11 spec gives `DiagnosisRun.run` a batch signature that takes every level's decisions up front (`decisions: [DiagnosisLevelDecision]`). A touch UI decides one step at a time." (Resolved by `tasks/arbitration/arbiter-02-11-stepwise-api.md`.)

Domain-doc workflows (`docs/domains/diagnosis.md:52-91`), verbatim:

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

  (`depthReached == level - 1` in item 3 is written for probe-ordinal levels. Under the cumulative-depth
  convention of `tasks/arbitration/arbiter-02-11-stepwise-api.md` Ruling 4 it reads "the depth reached before
  this candidate". The two are identical for depth-1 candidates, which is every Demo case; see §6.)

Arbiter ruling (`tasks/arbitration/arbiter-02-11-stepwise-api.md`), Rulings 1–4, binding: the public API is
`open` / `start` / `decideProbe` / `answerProbeItem` / `decideFurtherLevel` plus the thin driver `run`. The former
step helpers are `internal`. No phase value has a public initializer. `level` is cumulative graph depth from the
origin.

Arbiter ruling (`tasks/arbitration/arbiter-02-11-capped-remediated.md`), binding:
- `remediated` is written only by `remediate`, on the probed candidate that failed. `capped` never writes it.
- The `capped` node is W6's deeper candidate: the confirmed candidate's unmastered prerequisite one level up, found
  when no budget remains. It is marked `blocked` with no probe, no remediation and no `probeLog` row.
- When no budget remains and no such prerequisite exists, the terminal is `confirmed`.
- `depthReached` counts probed depth only.

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

`data/demo/edges.json` (the AC6/AC6b/AC11 recipe), verified entries: `:21-22` `"from": "solving-linear-equations",
"to": "exponent-laws"` (the only edge into `exponent-laws`); `:37-38` `"from": "exponent-laws", "to": "polynomials"`
(confidence 0.95, `:46`); `:229-230` `"from": "simplifying-expressions", "to": "polynomials"` (confidence 0.7, `:238`).

Prior signatures this task calls (verbatim, verified against the current tree):

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
  (Field order is the one `ExpeditionRun.swift:116-118` and `:158-162` construct these values with.)

- `Packages/Core/Sources/Core/State/MasteryTransitions.swift:85-98`:
  ```swift
  public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult {
      guard current.mastery == .fog else {
          return MasteryTransitionResult(nodeState: current, event: nil)
      }
      let node = NodeState(
          mastery: .blocked,
          correctCount: current.correctCount,
          lastProbe: current.lastProbe,
          nextDue: current.nextDue,
          ladderRung: current.ladderRung,
          remediated: current.remediated
      )
      return MasteryTransitionResult(nodeState: node, event: .diagnosisNodeBlocked)
  }
  ```
  (`MasteryTransitionResult { nodeState: NodeState; event: CoreEvent? }`. `remediated` passes through unchanged.)

- `Packages/Core/Sources/Core/State/Expedition.swift:93-95`:
  ```swift
  public static func selectItem(
      from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]
  ) -> ProbeItem? {
  ```
  (`:92`: "`nil` iff every item of `node` is excluded or `node.probeItems` is empty.")

- `Packages/Core/Sources/Core/Model/Nodes.swift:23-24` (on `Node`, alongside `id` and `errorTypes`):
  ```swift
  public let hintTree: [String: [String]]
  public let probeItems: [ProbeItem]
  ```

- `Packages/Core/Sources/Core/Events/CoreEvent.swift:25-31, :49` (bare names; `:3-8`: "`CoreEvent` is a bare name registry — it carries no payload"):
  ```swift
  case diagnosisOpened = "diagnosis.opened"
  case diagnosisHypothesisFormed = "diagnosis.hypothesis_formed"
  case diagnosisProbeCompleted = "diagnosis.probe_completed"
  case diagnosisNodeBlocked = "diagnosis.node_blocked"
  case diagnosisCapped = "diagnosis.capped"
  case diagnosisRemediationShown = "diagnosis.remediation_shown"
  case diagnosisReturned = "diagnosis.returned"
  case graphPrerequisiteReturned = "graph.prerequisite_returned"
  ```

- `Packages/Core/Sources/Core/CoreError.swift:23-26`:
  ```swift
  case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
  case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
  case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
  case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
  ```

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` (landed, 02.07):
  ```swift
  public struct ItemResult: Equatable {            // :4-11
      public let nodeId: String
      public let itemId: String
      public let correct: Bool
      public let correctAnswerDisplay: String
      public let why: String
      public let isRetry: Bool
  }
  public struct CurrentItem: Equatable {           // :15-20
      public let nodeId: String
      public let item: ProbeItem
      public let kind: SlotKind
      public let isRetry: Bool
  }
  public struct ExpeditionRunState: Equatable {    // :26-44 (excerpt)
      public var currentItem: CurrentItem?
      public var diagnosisUsed: Bool
      public var shownItemIds: Set<String>
      public var results: [ItemResult]
      public var suspendedForDiagnosisNodeId: String?
      // … queue, missCounts, itemPoolEmptyNodeIds, clearedNodeIds, blockedNodeIds, itemsAnswered
  }
  public struct AnswerOutcome: Equatable {         // :51-56
      public let run: ExpeditionRunState
      public let state: StudentState
      public let result: ItemResult
      public let events: [CoreEvent]
  }
  public static func start(compose: ComposeResult) -> StartOutcome                      // :87
  public static func answer(                                                            // :100-103
      run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String,
      today: CalendarDay
  ) -> AnswerOutcome
  public static func resume(run: ExpeditionRunState) -> ExpeditionRunState              // :166
  ```
  Hand-off note (`:77-85`): "Diagnosis (02.11) runs its own state machine entirely in its own file, over its own
  copy of `StudentState`, and — once it reaches `returned` — calls `ExpeditionRun.resume(run:)` with nothing else
  … the diagnosis's effect on mastery/`remediated` is already carried inside whatever `StudentState` the diagnosis
  produced, which the caller threads into the next call to `ExpeditionRun.answer(run:, state:, ...)`."
  `ItemResult`'s memberwise init is internal; `DiagnosisEvent.swift` is in the same module and constructs it.

- `Packages/Core/Sources/Core/ItemChecker.swift:168, :185`:
  ```swift
  public static func check(item: ProbeItem, submitted: String) -> Bool
  public static func correctAnswerDisplay(for item: ProbeItem) -> String
  ```

- `Packages/Core/Sources/Core/Graph/PrerequisiteQuery.swift` (landed, 02.10):
  ```swift
  public struct PrerequisiteCandidate: Equatable {   // :6-10
      public let node: Node
      public let depth: Int
      public let edgeConfidence: Double
  }
  public struct PrerequisiteQueryResult: Equatable { // :15-18
      public let candidate: PrerequisiteCandidate?
      public let code: CoreError?
  }
  public static func deepestUnmasteredPrerequisite(  // :28-31
      originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle,
      levelBudget: Int
  ) -> PrerequisiteQueryResult
  ```
  The walk runs `while depth <= levelBudget` (`:38`) and returns the **deepest** unmastered depth (`:62`), with
  `code: .graphNoPrerequisite` when there is no candidate (`:63`, `:76`). Only `.cleared` is excluded from the
  candidates (`:86-89`). This function emits no `CoreEvent`; the diagnosis machine, its only caller, emits
  `.graphPrerequisiteReturned` after each call.

- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (landed, 02.10):
  ```swift
  public struct FailedProbeAttempt: Equatable {      // :7-15
      public let item: ProbeItem
      public let submittedValue: String
      public init(item: ProbeItem, submittedValue: String)
  }
  public enum Classify {
      public static func classify(_ attempts: [FailedProbeAttempt]) -> String   // :23; "none_of_these" if no match
  }
  ```

- Test-module access: every `Packages/Core/Tests/CoreTests/*.swift` file uses `@testable import Core`, so the
  `internal` helpers of §4 step 5 are unit-testable without being public.

## §4 Implementation outline

1. **Layer.** `Sources/Core/Diagnosis/DiagnosisEvent.swift` is layer ④ interaction (the diagnosis workflow),
   composing layer ② concept-graph (`PrerequisiteQuery`) and layer ③ learning-objects data already carried on
   `Node` (`hintTree`, `probeItems`, `errorTypes`). It performs no I/O, no rendering, no system-clock read.

2. **Public types** (all `Equatable`, no `Codable` — these values never cross the wire; every stored property
   `public let`; **no `public init` except on `DiagnosisLevelDecision`**, AC15):
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
   // `refuted` = contract `pass`, `confirmed` = contract `fail`, `declined` = contract `declined` (the three
   // `diagnosis.probe_completed` payload values); `unavailable` = DIAG_PROBE_UNAVAILABLE, not a probe outcome
   // and never accompanied by `.diagnosisProbeCompleted` (§6).
   public enum ProbeOutcome: Equatable { case refuted, confirmed, declined, unavailable }
   public struct DiagnosisProbeResult: Equatable {
       public let outcome: ProbeOutcome
       public let results: [ItemResult]                    // 0 or 2 entries; `isRetry` always false
       public let incorrectAttempts: [FailedProbeAttempt]  // biases the next level's hypothesis
       public let code: CoreError?                         // .diagProbeUnavailable iff outcome == .unavailable
   }
   public struct DiagnosisOutcome: Equatable {
       public let state: StudentState
       public let terminal: DiagnosisTerminal
       public let depthReached: Int              // cumulative depth of the deepest candidate probed to pass/fail; 0 if none
       public let blockedNodeIds: [String]       // every node blocked along the path, in order; on `.capped` the last is the W6 node
       public let hintNodeId: String?            // == event.originNodeId whenever a hint is shown; nil otherwise
       public let hintErrorTypeId: String?       // resolved hint_tree key (with none-of-these fallback); nil otherwise
       public let probeResults: [ItemResult]     // every probe ItemResult along the path, in order
       public let events: [CoreEvent]            // the full sequence from `start` through this terminal
       public let code: CoreError?               // .diagNoPrerequisite / .diagProbeUnavailable, else nil
   }
   /// The machine's accumulated, read-only context; embedded in every non-terminal phase value.
   public struct DiagnosisContext: Equatable {
       public let event: DiagnosisEvent
       public let level: Int                     // cumulative graph depth of the current candidate from the origin
       public let depthReached: Int              // as on DiagnosisOutcome, so far
       public let originErrorTypeId: String      // Classify.classify(failedAttempts) at start; the origin hint key
       public let shownItemIdsInRun: Set<String>
       public let blockedNodeIds: [String]
       public let probeResults: [ItemResult]
       public let events: [CoreEvent]            // accumulated sequence so far, including the current advance's
   }
   /// Hypothesis card (W1 step 3 / W2 Post; W3 step 1): accept or decline the probe.
   public struct ProbeOffer: Equatable {
       public let context: DiagnosisContext
       public let candidateId: String
   }
   /// A probe with 2 drawn items; exactly `levelResults.count` (0 or 1) of them answered.
   public struct ProbeInProgress: Equatable {
       public let context: DiagnosisContext
       public let candidateId: String
       public let items: [ProbeItem]             // exactly 2, in draw order
       public let levelResults: [ItemResult]     // this level's answered items so far (0 or 1)
       let incorrectAttempts: [FailedProbeAttempt]   // internal
       public var currentItem: ProbeItem { items[levelResults.count] }
   }
   /// Remediation shown for `candidateId`; budget remains; accept or decline one more level (W4 step 3, Q3).
   public struct FurtherLevelOffer: Equatable {
       public let context: DiagnosisContext
       public let candidateId: String
       let incorrectAttempts: [FailedProbeAttempt]   // internal; biases the next hypothesis
   }
   public enum DiagnosisStep: Equatable {
       case probeOffer(ProbeOffer)
       case probeItem(ProbeInProgress)
       case furtherLevelOffer(FurtherLevelOffer)
       case returned(DiagnosisOutcome)
   }
   public struct DiagnosisAdvance: Equatable {
       public let step: DiagnosisStep
       public let state: StudentState            // the caller threads this into the next call
       public let events: [CoreEvent]            // this call's events only
       public let itemResult: ItemResult?        // non-nil iff this call checked a probe item (I3)
       public let probeResult: DiagnosisProbeResult?  // non-nil iff this call concluded the probe
   }
   /// Input to the thin driver `run` only.
   public struct DiagnosisLevelDecision: Equatable {
       public let declineProbe: Bool
       public let submittedAnswers: [String]     // matched in order to the 2 drawn probe items
       public let acceptFurtherLevel: Bool       // read only when a FurtherLevelOffer is actually returned
       public init(declineProbe: Bool, submittedAnswers: [String], acceptFurtherLevel: Bool) {
           self.declineProbe = declineProbe
           self.submittedAnswers = submittedAnswers
           self.acceptFurtherLevel = acceptFurtherLevel
       }
   }
   ```

3. **Public step functions** (`public enum DiagnosisRun`). Each copies every `StudentState` field through
   unchanged except where stated; `advance.state` equals the input `state` on every call except the confirmed
   branch of `answerProbeItem`.

   a. `open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent` — pure
      construction; emits nothing (`.diagnosisOpened` is emitted by `start`). This is the call EPIC 03's "Check me
      here" makes (`docs/epics/epic-03-app-map-shell.md:58-59`).

   b. `start(event: DiagnosisEvent, failedAttempts: [FailedProbeAttempt], shownItemIdsInRun: Set<String>, state:
      StudentState, bundle: ContentBundle) -> DiagnosisAdvance` — W1 + W2 at the first level.
      `originErrorTypeId = classify(failedAttempts)`. The context starts at `level 0`, `depthReached 0`,
      `events [.diagnosisOpened]`, empty accumulators. It then runs `formHypothesis(queryOriginId:
      event.originNodeId, biasErrorTypeId: originErrorTypeId, context:, state:, bundle:)` (step 4). For
      `map_check_here` the caller passes `failedAttempts: []` and `shownItemIdsInRun: []`.

   c. `decideProbe(_ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle) ->
      DiagnosisAdvance` — W3 steps 1–2.
      - `accept == false` → `probeResult = DiagnosisProbeResult(outcome: .declined, results: [],
        incorrectAttempts: [], code: nil)`. Events `[.diagnosisProbeCompleted, .diagnosisReturned]`.
        `terminal(.unconfirmed, code: nil, hint: true)`. No availability check, no draw, no `probeLog` row, no
        node change.
      - `accept == true` → `items = drawProbeItems(candidate:, trigger: offer.context.event.trigger,
        shownItemIdsInRun: offer.context.shownItemIdsInRun, probeLog: state.probeLog)` (candidate = the
        `bundle.nodes.nodes` entry with id `offer.candidateId`).
        - `nil` → `probeResult = DiagnosisProbeResult(outcome: .unavailable, results: [], incorrectAttempts: [],
          code: .diagProbeUnavailable)`. Events `[.diagnosisReturned]` (**no** `.diagnosisProbeCompleted`).
          `terminal(.unconfirmed, code: .diagProbeUnavailable, hint: true)`. No node change.
        - non-nil → `.probeItem(ProbeInProgress(context: offer.context, candidateId:, items:, levelResults: [],
          incorrectAttempts: []))`. Events `[]`, `probeResult nil`, `itemResult nil`.

   d. `answerProbeItem(_ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
      today: CalendarDay) -> DiagnosisAdvance` — W3 step 3 (I1, I3), then W3 step 4 / W4 / W6.
      - `item = probe.currentItem`; `correct = ItemChecker.check(item: item, submitted: submitted)`; `result =
        ItemResult(nodeId: probe.candidateId, itemId: item.id, correct: correct, correctAnswerDisplay:
        ItemChecker.correctAnswerDisplay(for: item), why: item.why, isRetry: false)`. If `!correct`, append
        `FailedProbeAttempt(item: item, submittedValue: submitted)`. Append `result` to the level results and to
        `context.probeResults`. The advance always carries `itemResult: result`.
      - Fewer than 2 answered → `.probeItem(updated)`, events `[]`, state unchanged.
      - Both answered, both correct → `probeResult = (.refuted, results: levelResults, incorrectAttempts: [],
        code: nil)`. `depthReached = context.level`. Events `[.diagnosisProbeCompleted, .diagnosisReturned]`.
        `terminal(.refuted, code: nil, hint: true)`. State unchanged: no node change and no `probeLog` row, the
        same as the prior spec.
      - Both answered, ≥ 1 incorrect (W4) → `probeResult = (.confirmed, results: levelResults,
        incorrectAttempts:, code: nil)`. Events `[.diagnosisProbeCompleted, .diagnosisNodeBlocked]`. Set
        `nodes[candidateId] = remediate(current: nodes[candidateId] ?? fogDefault)`, then append
        `.diagnosisRemediationShown`. Append `candidateId` to `blockedNodeIds`. Append the level's 2 results to
        `probeLog` as `ProbeLogEntry(day: today.iso, nodeId: candidateId, itemId:, correct:, retry: false)`. Set
        `depthReached = context.level`. Then:
        - `offered(levelReached: context.level, levelBudget: event.levelBudget) == true` →
          `.furtherLevelOffer(FurtherLevelOffer(context:, candidateId:, incorrectAttempts:))` with the updated
          `state`.
        - `== false` (budget exhausted; W6) → no `FurtherLevelOffer` is constructed. `deeper =
          hypothesise(originId: candidateId, biasErrorTypeId: classify(incorrectAttempts), state: <the updated
          state>, bundle:, levelBudget: 1)`; append `.graphPrerequisiteReturned`.
          - `deeper.candidate == nil` → append `.diagnosisReturned`; `terminal(.confirmed, code: nil, hint:
            false)`.
          - Else, with `d = deeper.candidate!.node.id`: set `nodes[d] = capped(current: nodes[d] ??
            fogDefault)`, append `d` to `blockedNodeIds`, then append `[.diagnosisNodeBlocked, .diagnosisCapped,
            .diagnosisReturned]` and call `terminal(.capped, code: nil, hint: false)`. For `d` there is no item
            draw, no `ItemResult`, no `probeLog` row, no `.diagnosisRemediationShown` and no `remediated` write.
            `depthReached` stays `context.level`.

   e. `decideFurtherLevel(_ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle) ->
      DiagnosisAdvance` — W4 step 3 (Q3: "offered, never automatic").
      - `accept == false` → events `[.diagnosisReturned]`; `terminal(.confirmed, code: nil, hint: false)`.
      - `accept == true` → `formHypothesis(queryOriginId: offer.candidateId, biasErrorTypeId:
        classify(offer.incorrectAttempts), context: offer.context, state:, bundle:)`.

4. **`formHypothesis` (internal)** — W2 at any level:
   `q = hypothesise(originId: queryOriginId, biasErrorTypeId:, state:, bundle:, levelBudget:
   event.levelBudget - context.level)`; append `.graphPrerequisiteReturned`.
   - `q.candidate == nil` → append `.diagnosisReturned`; `terminal(.noPrerequisite, code: .diagNoPrerequisite,
     hint: true)` (the query's own `.graphNoPrerequisite` is mapped to the diagnosis code, §6).
   - Else → append `.diagnosisHypothesisFormed`; `.probeOffer(ProbeOffer(context: context with level =
     context.level + q.candidate!.depth, candidateId: q.candidate!.node.id))`.

   `formHypothesis` is only ever reached from `start` (`context.level == 0`) or from `decideFurtherLevel` on an
   offer that exists only if `context.level < levelBudget`. The query budget is therefore always ≥ 1, and the new
   level is ≤ `levelBudget`, because the query walks at most `levelBudget - context.level` levels
   (`PrerequisiteQuery.swift:38`). The W6 deeper query of step 3d is **not** `formHypothesis`: it emits no
   `.diagnosisHypothesisFormed`, offers no probe and does not advance `level`.

5. **Internal helpers** (`internal static`, unit-tested via `@testable import Core`; never public):
   - `classify(_ attempts: [FailedProbeAttempt]) -> String` — one-line forward to `Classify.classify(attempts)`.
   - `hypothesise(originId:biasErrorTypeId:state:bundle:levelBudget:) -> PrerequisiteQueryResult` — forward to
     `PrerequisiteQuery.deepestUnmasteredPrerequisite(...)`.
   - `drawProbeItems(candidate: Node, trigger: DiagnosisTrigger, shownItemIdsInRun: Set<String>, probeLog:
     [ProbeLogEntry]) -> [ProbeItem]?`. `unavailableIds` is `Set(candidate.probeItems.map(\.id))
     .intersection(shownItemIdsInRun)` for `.expeditionSecondMiss`, and `[]` for `.mapCheckHere` (Q-G). Then
     `item1 = Expedition.selectItem(from: candidate, excluding: unavailableIds, probeLog:)` and `item2 =
     Expedition.selectItem(from: candidate, excluding: unavailableIds.union([item1.id]), probeLog:)`. If either
     is `nil`, return `nil`; else return `[item1, item2]`.
   - `offered(levelReached: Int, levelBudget: Int) -> Bool` — `levelReached < levelBudget`, evaluated on the
     cumulative depth.
   - `remediate(current: NodeState) -> NodeState` — `let blocked =
     MasteryTransitions.diagnosisBlocked(current: current).nodeState`; return it with `remediated: true` (a no-op
     block if already `.blocked`). Called only on a probed candidate whose probe failed.
   - `capped(current: NodeState) -> NodeState` — returns `MasteryTransitions.diagnosisBlocked(current:
     current).nodeState` and nothing else. `remediated` passes through unchanged (`MasteryTransitions.swift:95`)
     and is never written by this helper (`contracts/data-model.md` § StudentState: "A node blocked by `capped`
     … does not carry it"). Called only on the W6 deeper candidate, never on a probed candidate.
   - `hintKey(originNode: Node, errorTypeId: String) -> String` — `errorTypeId` if
     `originNode.hintTree[errorTypeId]` is non-nil and non-empty, else `"none_of_these"`. Returns keys, never
     hint prose (I5, I14).
   - `terminal(_:code:hint:context:state:bundle:) -> DiagnosisOutcome` — builds the outcome. When `hint ==
     true`, `hintNodeId = event.originNodeId` and `hintErrorTypeId = hintKey(originNode: <the origin's
     bundle node>, errorTypeId: context.originErrorTypeId)`. The hint is always on the **top-level origin**, never
     an intermediate candidate (W3 step 4 "hint on the origin", W2 step 3 "the origin's hint"). When `hint ==
     false`, both are `nil`. `events` = the full accumulated sequence.

6. **`run` — thin driver (public).** The signature is unchanged from the prior spec:
   ```swift
   public static func run(
       trigger: DiagnosisTrigger, originNodeId: String, failedAttempts: [FailedProbeAttempt],
       levelBudget: Int, decisions: [DiagnosisLevelDecision], shownItemIdsInRun: Set<String>,
       state: StudentState, bundle: ContentBundle, today: CalendarDay
   ) -> DiagnosisOutcome
   ```
   It is implemented **only** as: `open` → `start`, then a loop over `advance.step` that threads `advance.state`.
   - `.probeOffer`: `k` = number of `ProbeOffer`s seen so far − 1; `d = decisions[k]` or the §6 fallback;
     call `decideProbe(accept: !d.declineProbe)`.
   - `.probeItem(p)`: `answerProbeItem(p, submitted: d.submittedAnswers[p.levelResults.count]` or `""` if the
     array is too short`)`.
   - `.furtherLevelOffer(f)`: `decideFurtherLevel(f, accept: d.acceptFurtherLevel)`.
   - `.returned(o)`: return `o`.

   `d.acceptFurtherLevel` is read only when a `FurtherLevelOffer` is actually returned, so it is never read at an
   exhausted budget. The driver contains no diagnosis logic of its own. The loop terminates because every level
   takes at most 4 advances and `level` strictly increases by ≥ 1 per accepted further level, bounded by
   `levelBudget ≤ 2`.

7. **Final `StudentState`.** Only `nodes` and `probeLog` ever differ from the input, and only in the confirmed
   branch of `answerProbeItem`. `schemaVersion`, `formatVersionSeen`, `syllabi`, `marker`, `trail`,
   `expeditionLog`, `installDay` and `consentOn` are copied through unchanged. `expeditionLog` is **never**
   appended (AC10); it is owned by `ExpeditionRun.end` (02.07).

8. **Error codes.** None thrown — no `DiagnosisRun` function `throws` or traps on student input.
   `DIAG_NO_PREREQUISITE` and `DIAG_PROBE_UNAVAILABLE` are data on `DiagnosisOutcome.code` ("code as data",
   mirroring `PrerequisiteQueryResult`). This is consistent with I3: a thrown error would abort before the
   hint/remediation is attached. `DIAG_STATE_WRITE_FAILED` is never thrown or returned here; it belongs to the
   caller's persistence layer (App/platform, EPIC 03).

9. **No model call anywhere in `DiagnosisRun`** (I2). `hypothesise` and `classify` forward to Tier-0 functions
   (02.10), and item checking calls only `ItemChecker.check` / `Expedition.selectItem`. No function in this file
   accepts a Tier-1/Tier-2 adapter; the Tier-1 "suggest, never decide" classify path is EPIC 13 scope.

10. Smoke check: `swift test --package-path Packages/Core --filter DiagnosisMachineTests` (then
    `DiagnosisTier0CompletenessTests` and `ExpeditionDiagnosisSeamTests`) must be green, followed by the full
    `scripts/gate.sh`.

## §5 Test plan

Instrument for every case below: Swift Testing `@Test` functions run by `swift test --package-path Packages/Core`
(simulator via `xcodebuild test -scheme Core-Package` in the gate), with `@testable import Core`. The tests call the
step API (`start` / `decideProbe` / `answerProbeItem` / `decideFurtherLevel`) directly unless a case says "driver".
Event assertions compare full arrays by `==`: each advance's `events`, the concatenated sequence, and
`DiagnosisOutcome.events`. An empty concatenated sequence always FAILs, because AC1 requires `.diagnosisOpened`
and `.diagnosisReturned`.

- T1 happy path — each terminal driven step by step. Terminals:
  - `refuted`;
  - `confirmed`-not-capped at budget 2 (AC7);
  - `confirmed` at an exhausted budget 1 with no deeper gap (AC6b);
  - `capped` at budget 1 (AC6);
  - `capped` at level 2 of budget 2 (AC8);
  - `capped` on a depth-2 level-1 candidate (AC8b);
  - `unconfirmed`-declined;
  - `unconfirmed`-unavailable;
  - `noPrerequisite` (at `start`, and at level 2 after an accepted further level).

  Fixtures are small hand-built `ContentBundle`/`StudentState` values, or `data/demo` where it reaches the case
  (AC6/AC6b pin `data/demo`). After every call, assert the exact `step` case. Assert `terminal`, `code`,
  `hintNodeId`/`hintErrorTypeId`, `blockedNodeIds`, `depthReached`, each advance's `events` and `probeResult`, and
  the concatenated sequence per AC1–AC10.

  The `probe_completed` rule (§6) is asserted by exact arrays:
  - The declined advance has `events == [.diagnosisProbeCompleted, .diagnosisReturned]`, `probeResult?.outcome ==
    .declined` and `code == nil` (AC3).
  - The unavailable advance has `events == [.diagnosisReturned]`, `probeResult?.outcome == .unavailable` and `code
    == .diagProbeUnavailable` (AC4).
  - `refuted`, `confirmed` and `capped` each contain exactly one `.diagnosisProbeCompleted` per level probed.
  - `noPrerequisite` at `start` contains none (AC2).

  `remediated` is asserted on every `confirmed`/`capped` terminal:
  - each failed probed candidate has `mastery == .blocked` and `remediated == true`;
  - on `.capped`, the W6 node `blockedNodeIds.last` has `mastery == .blocked`, `remediated` equal to its input
    value, and no `probeLog` row.

  For the budget-1 `capped` case, additionally assert via the driver that `acceptFurtherLevel ∈ {false, true}`
  both yield `.capped` (AC6).
- T2 negative — invalid input at the boundary:
  - `answerProbeItem` with `submitted: ""`, with a non-numeric string on a numeric item, and with an unknown choice
    id on an MC item: each returns an incorrect `ItemResult` and never traps.
  - The driver with `submittedAnswers` shorter than 2 treats the missing entry as `""` (asserted directly).
  - The driver with `decisions` shorter than the probe offers actually reached never traps: the §6 fallback applies
    and a terminal is reached.
  - Wrong-phase calls, such as answering a `ProbeOffer`, are unrepresentable because each function takes its phase
    value's type. AC15's instrument is the guard that the App cannot fabricate one.
- T3 error-taxonomy:
  - `DiagnosisOutcome.code == .diagNoPrerequisite` iff `terminal == .noPrerequisite`.
  - `.diagProbeUnavailable` iff `terminal == .unconfirmed` from an unavailable draw (a decline has `code == nil`).
  - No `DiagnosisOutcome` ever carries `.graphNoPrerequisite`, including the AC6b `confirmed` terminal whose W6
    deeper query returned it.
  - `CoreError ⊆` registry is already covered by the existing `ErrorRegistryTests`; no new case is added.
- T4 conformance per `contracts/interaction-contract.md` § 4 and the applicable invariants. The full FSM is
  exercised end to end via the step API.
  - I1: every probe `ItemResult.correct` equals `ItemChecker.check` on the same item and submission.
  - I2: AC11.
  - I3: AC14.
  - I4: asserted over generated `levelBudget ∈ {1, 2}`:
    - `depthReached ≤ levelBudget ≤ 2`;
    - no `FurtherLevelOffer` is ever returned with `context.level >= levelBudget`;
    - the W6 node (if any) has no `ItemResult` in `probeResults` and no `probeLog` row.
  - I5: a type-level check that `DiagnosisOutcome`'s own `String` fields are only `hintNodeId`/`hintErrorTypeId`,
    always equal to a `Node.id` or a `hintTree` key, never free text.
  - I14: `DiagnosisEvent.swift` imports Foundation only; the existing import-boundary test covers `Sources/Core`.
- T5 negative control for every regression guard. Each mutation is applied temporarily in a scratch edit, observed
  to fail the named test, and reverted:
  - `answerProbeItem` treating "any incorrect" as `.refuted` (inverted) must fail the T1 confirmed case;
  - `offered` always returning `true` must fail AC6: at budget 1 a `.furtherLevelOffer` would be returned instead
    of `.returned(.capped)`;
  - depth bookkeeping that adds `1` per level instead of `PrerequisiteCandidate.depth` (probe-ordinal level) must
    fail AC8b;
  - `remediate` skipping `remediated = true` must fail AC6b, AC7 and AC9;
  - `capped` writing `remediated = true` (the pre-arbitration behaviour) must fail AC6 (`state.nodes[d]!.remediated
    == nil`), AC9 and the AC13 Q-A property;
  - `capped` applied to the probed candidate instead of the W6 deeper candidate must fail AC6 (`blockedNodeIds ==
    [c, d]`, `state.nodes[d]!.mastery == .blocked`);
  - the exhausted-budget branch returning `.capped` without a deeper candidate must fail AC6b;
  - a Q-G draw that ignores `shownItemIdsInRun` must fail AC4 and the Tier-0 `DIAG_PROBE_UNAVAILABLE` test (AC11);
  - swapping the `probe_completed` rule (emitting on unavailable, omitting on declined) must fail both T1 exact-array
    assertions (AC3 and AC4); emitting on both, or on neither, must fail exactly one. The two are independent
    `@Test`s;
  - an `answerProbeItem` that returns `itemResult: nil` for the first item must fail AC14.
- T6 idempotency / no-leak: every step function called twice with the same arguments returns `==` advances (pure,
  no hidden mutable state). A `.refuted`, declined, unavailable or `.noPrerequisite` terminal's `state` `==` the
  `start` input state (no side effect on a path that blocked nothing).
- T7 (AC13) properties over `PropertyGen`-generated graphs/states, `DiagnosisMachineTests.swift`.
  - The 9 bullets of §3 (epic §4 item 5) are each an independent `@Test` with a seeded generator loop. The loop
    drives the step API with a generated accept/decline and answer script (deterministic, no system-clock read).
  - The generator varies `levelBudget ∈ {1, 2}`, candidate depth ∈ {1, 2}, and whether the last probed candidate
    has an unmastered depth-1 prerequisite.
  - Exhausted budget: a confirmed probe at `context.level ≥ levelBudget` yields `.returned`, never
    `.furtherLevelOffer`. The terminal is `.capped` iff `PrerequisiteQuery.deepestUnmasteredPrerequisite(originId:
    <that candidate>, biasErrorTypeId: nil, state: <input state>, bundle:, levelBudget: 1).candidate != nil`, else
    `.confirmed`. The bias only picks among deepest candidates and never changes existence (`PrerequisiteQuery.swift:62-71`).
  - The Q-A bullet ("a `confirmed` candidate carries `remediated = true`…; a `capped` candidate does not") is
    asserted as in T1.
  - "A second level is entered only on an explicit accept" is asserted as: a `.probeOffer` with `context.level >
    first level` appears only immediately after a `decideFurtherLevel(accept: true)`.
  - Driver equivalence: for each generated `decisions` array, `run(...)` `==` the hand-stepped terminal outcome.
  - The generated-case count for each property must be > 0 (empty = FAIL). The `.capped` and exhausted-budget
    `.confirmed` counts must each be > 0 (empty = FAIL).
- T8 (AC11) Tier-0 completeness, `DiagnosisTier0CompletenessTests.swift`.
  - Every terminal of AC11 is reached by step calls on the real `data/demo` bundle (`BundleIO.read(from:)`,
    precedent shape in `MarkerTrailFringeSeamTests.swift`), at Demo `levelBudget = 1`.
  - `capped` and `confirmed` use the AC6 and AC6b recipes.
  - No adapter parameter exists on any public function, which is itself the I2 proof.
  - `DIAG_PROBE_UNAVAILABLE` uses the arbiter's exact constructed-state recipe (§3, Q-G "Reachability"): the real
    `ExpeditionRun` produces `shownItemIds`, and the sequence contains no `.diagnosisProbeCompleted`.
- T9 (AC12) C1 seam, `ExpeditionDiagnosisSeamTests.swift`. Steps:
  1. A real `ExpeditionRun.start` on real `data/demo`, then real `.answer` calls on the same node that drive it to
     a second miss (`events` containing `.expeditionDiagnosisRequested`). The test records each missed
     `run.currentItem!.item` with the string it submitted, as `FailedProbeAttempt`s (§6).
  2. `DiagnosisRun.open(originNodeId: run.suspendedForDiagnosisNodeId!, trigger: .expeditionSecondMiss,
     levelBudget: 1)`.
  3. `start(event:, failedAttempts:, shownItemIdsInRun: run.shownItemIds, state: answerOutcome.state, bundle:)` →
     `.probeOffer`.
  4. `decideProbe(accept: true)` → `.probeItem`.
  5. Two `answerProbeItem` calls with incorrect submissions (a tagged distractor, or `""`), each advance's `state`
     threaded, ending in `.returned(o)`. The test first computes the expected terminal: `.capped` if
     `PrerequisiteQuery.deepestUnmasteredPrerequisite(originId: <the offered candidate>, biasErrorTypeId: nil,
     state: answerOutcome.state, bundle:, levelBudget: 1).candidate != nil`, else `.confirmed`. It asserts
     `o.terminal` equals exactly that value, and that the sequence has exactly one `.diagnosisProbeCompleted` (§6
     `fail` case).
  6. A real `ExpeditionRun.resume(run:)`, then one more real `.answer` with `o.state` as the `StudentState`.

  Asserts, in the `StudentState` passed to the next `.answer`:
  - exactly one diagnosis was driven (one `start` call, and `run.diagnosisUsed == true` throughout);
  - `o.blockedNodeIds.first` (the probed candidate) has `mastery == .blocked` and `remediated == true`;
  - when `o.terminal == .capped`, `o.blockedNodeIds.last` has `mastery == .blocked` and `remediated != true`. This
    is the input the `Expedition.swift:183-194` fringe guard reads;
  - every pre-diagnosis `ItemResult` is still in `run.results` after `resume`;
  - neither `ExpeditionRun` nor `DiagnosisRun` is stubbed.

  If the test is later extended to the declined/unavailable branches, it applies the same §6 rule T1 asserts,
  never a second convention.

## §6 Decision defaults

- IF the student is to take each decision after seeing the previous screen THEN the machine is driven one call per
  decision point (`start`, `decideProbe`, `answerProbeItem`, `decideFurtherLevel`), each returning a
  `DiagnosisAdvance` whose `state` the caller threads into the next call. This mirrors `ExpeditionRun`
  (`ExpeditionRun.swift:26-44`, `:51-56`, `:100-103`) (per `tasks/arbitration/arbiter-02-11-stepwise-api.md`;
  `CLAUDE.md:37` I14; `docs/epic-plan.md:23`).
- IF `level` (cumulative graph depth from the origin) `>= levelBudget` after a `.confirmed` probe THEN:
  - no `FurtherLevelOffer` is constructed and the further-level decision is never read (the budget rule kept by
    `tasks/arbitration/arbiter-02-11-stepwise-api.md`);
  - the confirmed candidate keeps its W4 effects: `blocked`, one remediation piece, `remediated = true`
    (`contracts/interaction-contract.md` § 4 `probe` bullet, `fail` arrow);
  - W6 then runs in the same advance: the W6 deeper query (§4 step 3d) finds W6's "deeper candidate", the next
    gap upstream that the budget forbids probing;
  - found → it is marked `blocked` via `capped`, with no probe, no remediation and no `remediated`, and the
    terminal is `.capped`;
  - not found → the terminal is `.confirmed`, since nothing further upstream exists to put on the map. W4 step 3
    conditions the next level on "the candidate itself has unmastered prerequisites".

  A `capped` node is never a probed candidate (per `tasks/arbitration/arbiter-02-11-capped-remediated.md`;
  `contracts/data-model.md` § StudentState; `docs/domains/diagnosis.md` W4 step 3, W6).
- IF the W6 deeper query runs THEN it uses `levelBudget: 1` from the confirmed candidate, biased by
  `classify(incorrectAttempts)`. W6 marks "the deeper candidate" (singular) one step beyond what the budget
  allowed, the same step a `FurtherLevelOffer` would have explored. Only `.cleared` is excluded
  (`PrerequisiteQuery.swift:86-89`), so an unknown or `fog` prerequisite counts (graph Q2).
- IF the W6 deeper query returns `code == .graphNoPrerequisite` THEN it is not surfaced: the terminal is
  `.confirmed` with `code == nil`. A gap was found and remediated. `DIAG_NO_PREREQUISITE` belongs only to a
  hypothesis with no candidate (contract § 4 `hypothesise`).
- IF the W6 deeper candidate is already `.blocked` THEN `capped` is a no-op on it (`MasteryTransitions.swift:86-87`)
  and any `remediated` it already carries from an earlier diagnosis stands, because `capped` does not write it.
  `.diagnosisNodeBlocked` is still appended for it, matching the unconditional emission for the probed candidate.
  `d` is still appended to `blockedNodeIds`.
- IF the W6 node lies at graph depth `levelBudget + 1` from the origin THEN it is marked only. `depthReached` stays
  the probed depth, so `depthReached ≤ levelBudget ≤ 2` holds. The contract's "depth ≤ 2 from origin" and I4's
  "backtrack ≤ 2 levels" measure probing and remediation; W6's own **Pre** ("W2 or W4 would exceed 2 levels from
  the origin") places the deeper candidate beyond the cap by definition, and I4 says "deeper gaps are marked on the
  map only".
- IF a `.confirmed` candidate is offered a further level and the student declines (`decideFurtherLevel(accept:
  false)`) THEN the terminal is plain `.confirmed`, not `.capped`, and no deeper node is marked. `capped` is
  reserved for budget exhaustion (`docs/domains/diagnosis.md` W4 step 3: "offer — not force").
- IF a level's candidate depth is > 1 (possible only when `levelBudget - priorLevel ≥ 2`) THEN `level` advances by
  that depth, not by 1. The contract's "within remaining levels" and "depth ≤ 2 from origin" measure graph depth
  from the origin, and `PrerequisiteQuery` returns the deepest candidate within its budget (`PrerequisiteQuery.swift:38`,
  `:62`). `depthReached` on a declined/unavailable/noPrerequisite terminal is `context.depthReached`, the
  cumulative depth of the last candidate probed to pass/fail (0 if none). For depth-1 candidates (every Demo case)
  this equals the probe-completed ruling's "`level - 1`" (per `tasks/arbitration/arbiter-02-11-stepwise-api.md`
  Ruling 4).
- IF the driver `run` has `decisions.count ≤ k` when the k-th `ProbeOffer` (0-based) is reached THEN it uses
  `DiagnosisLevelDecision(declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)`. This is the safest
  Tier-0 reading: it never guesses an answer and never forces a probe the caller did not authorize (I2). The step
  API has no such fallback, because every decision is an explicit argument.
- IF the caller opens a diagnosis from `expedition_second_miss` THEN it builds `failedAttempts` from the two missed
  `CurrentItem.item` values and the exact strings it submitted to `ExpeditionRun.answer`
  (`FailedProbeAttempt(item:submittedValue:)`, `Classify.swift:11`). This passes inputs, not state: `ExpeditionRun`
  exposes no submitted value, and `Classify.classify` is still what decides the error type. For `map_check_here`,
  `failedAttempts == []`, so `originErrorTypeId == "none_of_these"`.
- IF `PrerequisiteQuery` returns `code == .graphNoPrerequisite` in `formHypothesis` THEN the diagnosis outcome
  carries `code == .diagNoPrerequisite` (`CoreError.swift:23, :26`; contract § 4 `hypothesise`: "none →
  `DIAG_NO_PREREQUISITE`"). The graph code never appears on a `DiagnosisOutcome`.
- **`probe_completed` emission rule** (per `tasks/arbitration/arbiter-02-11-probe-completed.md`):
  - IF a probe concludes with outcome `∈ {.refuted, .confirmed, .declined}` THEN `.diagnosisProbeCompleted` is
    emitted exactly once for that level, as the first event of the concluding advance: after that level's
    `.diagnosisHypothesisFormed` (an earlier advance) and before any `.diagnosisNodeBlocked`/`.diagnosisReturned`.
    The domain payload names these three values (`docs/domains/diagnosis.md` notifications-produced: "`{
    candidate_id, edge_id, pass|fail|declined }`"), and `contracts/domain-glossary.md:42` defines the probe's
    outcomes as "**pass / fail / declined**". The W6 node is never probed and never produces a
    `.diagnosisProbeCompleted`.
  - IF the draw is `.unavailable` THEN `.diagnosisProbeCompleted` is **not** emitted. `DIAG_PROBE_UNAVAILABLE` is
    not a probe outcome: W3's **Pre** is "two items available", the contract states "Fewer than 2 items →
    `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`" apart from the three probe-outcome arrows, and the payload enum has
    no `unavailable` value. The terminal is carried by `.diagnosisReturned` plus `DiagnosisOutcome.code ==
    .diagProbeUnavailable`.
  - This rule is applied identically at every level and in every test in this file (AC3, AC4, T1, T5, T8, T9).
    No test in this file may assert the opposite reading.
- IF a consumer needs the `probe_completed` payload value THEN it reads `DiagnosisAdvance.probeResult!.outcome` on
  the advance whose `events` contain `.diagnosisProbeCompleted`, mapped `.refuted → pass`, `.confirmed → fail`,
  `.declined → declined`. `CoreEvent` is a bare name registry that "carries no payload" (`CoreEvent.swift:3-8`), so
  no associated value is added. A declined probe produces no `ItemResult` and no `probeLog` row, and therefore no
  telemetry `item_result` or `edge_observation`, whose `downstream_result ∈ {pass, fail}` (`contracts/telemetry.md`
  § Event kinds). That derivation is EPIC 11 scope.
- IF the classified `errorTypeId` names a key absent from the origin node's `hintTree` (including
  `"none_of_these"` itself being absent) THEN `hintKey` returns the literal key `"none_of_these"` regardless. The
  renderer handles a still-missing entry at render time, outside `Core`'s I14 scope. No new error code is raised,
  since none is registered and adding one is a contract bump.
- IF a `.confirmed` candidate's or the W6 deeper candidate's `NodeState` is absent from `state.nodes` THEN
  `remediate` / `capped` is called with `fogDefault = NodeState(mastery: .fog, correctCount: 0, lastProbe: nil,
  nextDue: nil, ladderRung: 0, remediated: nil)`. This is the "absent means fresh fog" convention
  `ExpeditionRun.answer` uses (`ExpeditionRun.swift:114-118`), applied independently, since
  `MasteryTransitions.diagnosisBlocked`'s `mastery == .fog` guard (`MasteryTransitions.swift:86`) needs it to fire.
- IF a phase value would be useful to construct outside `Core` (App, previews) THEN it is not constructible there:
  no public initializer (AC15). The App obtains phase values only from `DiagnosisRun` calls. SwiftUI previews use a
  real `start` over `data/demo`.
- Standing default: identifiers and timestamps follow `contracts/data-model.md` § Identifiers/§ Time (kebab-case
  node/error-type ids; calendar-day granularity via the injected `CalendarDay today`, never `Date()`).
- Standing default: telemetry is out of scope here. `diagnosis.probe_completed`'s L3 telemetry payload is derived
  by a later telemetry consumer (EPIC 11) from the events and the paired `DiagnosisAdvance.probeResult`.
- Standing default: `StudentState.remediated` is written only by `remediate`, only on a probed candidate whose probe
  failed; `capped` never writes it. It is cleared only elsewhere (EPIC 03/04, on `cleared`); this file never
  clears it (`contracts/data-model.md` § StudentState).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages`)
- `Core` build + test green (`swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package` on the simulator, or `swift test --package-path Packages/Core` locally)
- tests green for every case in §5 (T1–T9), including `DiagnosisMachineTests.swift`,
  `DiagnosisTier0CompletenessTests.swift`, `ExpeditionDiagnosisSeamTests.swift`
- `grep -c 'public init' Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` prints `1` (AC15)
- `scripts/gate.sh` green end to end
- conforms to every contract section cited in §3 and §4 (`interaction-contract.md` § 4, § 2 `compose` and § 5,
  `data-model.md` § StudentState, `domain-glossary.md` Probe entry, `telemetry.md` Event kinds,
  `graph-constraints.md` Query rules, `error-codes.json`'s three `DIAG_*` entries) and to every invariant listed in
  §1 (I1, I2, I3, I4, I5, I14, D27)

# ARBITER RULING: task 02.11 — step-wise diagnosis API (touch-driven consumer)

**Date**: 2026-09-10
**Spec**: `tasks/epic-02-task-11-diagnosis-machine-seam.md`
**Trigger**: Q4 spec drift raised by the downstream consumers before implementation: the EPIC 03 brief's note on
`DiagnosisRun` and the EPIC 04 row of `docs/epic-plan.md`. The spec's only public driver, `DiagnosisRun.run(...,
decisions: [DiagnosisLevelDecision], ...)`, needs every student decision up front. A touch UI learns each decision
only after it shows the previous screen. I14 forbids the render layer from re-implementing the machine.
**Prior ruling kept intact**: `tasks/arbitration/arbiter-02-11-probe-completed.md` (the `probe_completed` emission
rule and the declined-probe representation). Also kept: the budget/capped rule (a `confirmed` probe at an exhausted
budget goes straight to `capped` and the further-level decision is never read).

## Ruling

1. **The diagnosis machine is step-wise.** It mirrors `ExpeditionRun` (`Packages/Core/Sources/Core/State/ExpeditionRun.swift:100-103`,
   `answer(run:state:bundle:submitted:today:) -> AnswerOutcome`, which returns the next value state plus `StudentState`
   plus events). Public surface of `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift`:

   ```swift
   public enum DiagnosisRun {
       public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent
       public static func start(
           event: DiagnosisEvent, failedAttempts: [FailedProbeAttempt], shownItemIdsInRun: Set<String>,
           state: StudentState, bundle: ContentBundle
       ) -> DiagnosisAdvance
       public static func decideProbe(
           _ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle
       ) -> DiagnosisAdvance
       public static func answerProbeItem(
           _ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
           today: CalendarDay
       ) -> DiagnosisAdvance
       public static func decideFurtherLevel(
           _ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle
       ) -> DiagnosisAdvance
       public static func run(
           trigger: DiagnosisTrigger, originNodeId: String, failedAttempts: [FailedProbeAttempt],
           levelBudget: Int, decisions: [DiagnosisLevelDecision], shownItemIdsInRun: Set<String>,
           state: StudentState, bundle: ContentBundle, today: CalendarDay
       ) -> DiagnosisOutcome   // thin driver over the four step functions; no logic of its own
   }
   public enum DiagnosisStep: Equatable {
       case probeOffer(ProbeOffer)                 // hypothesis card: accept or decline the probe
       case probeItem(ProbeInProgress)             // one probe item awaiting an answer
       case furtherLevelOffer(FurtherLevelOffer)   // remediation shown; budget remains; accept or decline
       case returned(DiagnosisOutcome)             // terminal
   }
   public struct DiagnosisAdvance: Equatable {
       public let step: DiagnosisStep
       public let state: StudentState
       public let events: [CoreEvent]              // this call's events only
       public let itemResult: ItemResult?          // non-nil iff this call checked a probe item (I3)
       public let probeResult: DiagnosisProbeResult?  // non-nil iff this call concluded the probe (incl. declined/unavailable)
   }
   ```

   `ProbeOffer`, `ProbeInProgress`, `FurtherLevelOffer`, `DiagnosisContext`, `DiagnosisOutcome` and `DiagnosisEvent`
   expose `public let` fields and **no public initializer**. Only `Core` can construct a phase value, so the App
   cannot forge a state (for example, a `FurtherLevelOffer` beyond the budget). Each advance function takes the
   specific phase value it acts on, so calling a step in the wrong phase does not compile. No trap and no runtime
   check is needed.

2. **Former public step helpers become `internal`**: `classify`, `hypothesise`, `drawProbeItems` (the old
   `probe`), `offered`, `remediate`, `capped` and `hintKey` (the old `returned`). The tests still reach them because
   every `CoreTests` file uses `@testable import Core`. With the helpers internal, the App cannot assemble the machine
   from raw pieces, which is what I14 asks for. `DiagnosisHypothesisResult` is removed; it was a wrapper with no
   consumer.

3. **The batch `run` is kept only as a thin driver.** It is implemented solely by calling `start` / `decideProbe` /
   `answerProbeItem` / `decideFurtherLevel`. It is kept because the EPIC 03 brief's W6 test calls "a **real**
   `DiagnosisRun.run` `confirmed` outcome" (`docs/epics/epic-03-app-map-shell.md:268`), and because the
   driver-equivalence property uses it. T1–T9 exercise the step API directly.

4. **Depth is cumulative graph depth from the origin** (this is the new VALID finding 4 below). `DiagnosisContext.level`
   is the sum of the candidate depths along the chain (`PrerequisiteCandidate.depth`). The query at each hypothesis
   receives `levelBudget - priorLevel`. The offer predicate is `offered(levelReached: level, levelBudget:) = level <
   levelBudget`, evaluated on that cumulative depth. The capped rule is unchanged in form: a `confirmed` probe with
   `level >= levelBudget` goes straight to `capped` and constructs no `FurtherLevelOffer`. At the Demo budget of 1,
   and for any chain of depth-1 candidates, behaviour is identical to the prior spec.

No contract text change is needed. No locked decision changes. Not a Q5.

## Findings analysis

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | A batch `decisions:` array cannot be driven by a touch UI that learns each decision after showing the previous screen; I14 forbids the App from re-implementing the machine | `docs/epic-plan.md:23` (EPIC 04): "hypothesis card, probe, remediation, return … App↔`Core` state transitions (every screen action is a `Core` call)"; `CLAUDE.md:37` I14: "the render layer never computes state"; `docs/epics/epic-03-app-map-shell.md:473-476`: "The 02.11 spec gives `DiagnosisRun.run` a batch signature that takes every level's decisions up front … A touch UI decides one step at a time." | VALID. The spec gains a step API, one advance function per student decision point. |
| 2 | The step functions must mirror `ExpeditionRun` | `ExpeditionRun.swift:26-44` (value-type run state, "threaded by the caller through every `answer`/`resume` call alongside its own copy of `StudentState`"), `:51-56` (`AnswerOutcome { run, state, result, events }`), `:77-85` (the hand-off note: diagnosis "runs its own state machine entirely in its own file, over its own copy of `StudentState`") | VALID. `DiagnosisAdvance { step, state, events, itemResult, probeResult }` mirrors `AnswerOutcome`. |
| 3 | EPIC 03 expects `DiagnosisRun.open(originNodeId:trigger:levelBudget:)` returning a `DiagnosisEvent` for `map_check_here`, budget 1 | `docs/epics/epic-03-app-map-shell.md:58-59`, `:276-277`, `:316-317` | VALID and kept unchanged. `open` stays pure construction. `start(event:…)` consumes the `DiagnosisEvent` that EPIC 03 hands to EPIC 04 (`:64-69`). |
| 4 | (Found in P2) The prior spec's level loop counts probes, not graph depth, so at budget 2 a level-1 candidate at depth 2 allows a level-2 query reaching depth 3 from the origin | `PrerequisiteQuery.swift:38` walks `depth <= levelBudget`, and `:62` returns the **deepest** depth. The prior spec §4 step 11.a passed `levelBudget - level + 1` with `level` = probe ordinal. `contracts/interaction-contract.md` § 4: "candidate = deepest unmastered prerequisite within remaining levels", "**Properties (CoreTests):** depth ≤ 2 from origin"; `docs/domains/diagnosis.md:89` W6: "W2 or W4 would exceed 2 levels from the origin" | VALID. It is an I4 hole. It is fixed by cumulative depth (Ruling 4). There is no behaviour change at the Demo budget of 1. |
| 5 | Every §4 property, terminal, event ordering, I3/I4/I5 must hold identically through the step API | `contracts/interaction-contract.md:76-99`; `docs/domains/diagnosis.md:52-91` (W1–W6); `tasks/arbitration/arbiter-02-11-probe-completed.md` Ruling 1–3 | VALID. The spec's ACs are restated on the step API. The concatenation of every advance's `events` equals the terminal `DiagnosisOutcome.events`, and the old arrays are asserted verbatim. |
| 6 | Consumed APIs are unchanged | `PrerequisiteQuery.swift:6-18, :28-31`; `Classify.swift:7-15, :23`; `Expedition.swift:93-95` (`selectItem`); `MasteryTransitions.swift:85` (`diagnosisBlocked`); `ItemChecker.swift:168, :185`; `CoreEvent.swift:25-31, :49`; `CoreError.swift:23-26` | VALID. No out-of-scope file is edited. `PrerequisiteQueryResult.code` is `.graphNoPrerequisite` (`PrerequisiteQuery.swift:63`), so the machine maps it to `DiagnosisOutcome.code == .diagNoPrerequisite`. The spec now states this mapping explicitly (§6). |

## Downstream doc note (not a contract; nothing blocks on it)

`docs/epics/epic-03-app-map-shell.md:473-476` names `hypothesise`, `probe`, `offered`, `remediate` and `returned` as
public step-wise entry points. After this ruling those are `internal`. The public step API is `start` /
`decideProbe` / `answerProbeItem` / `decideFurtherLevel`, and `open` and `run` keep the names the brief uses at
`:58`, `:268` and `:316-317`. **Owner of the edit:** the next docs pass on the EPIC 03 brief (spec-architect/planner),
or EPIC 04's planner. Suggested text: "EPIC 04 drives Door A through `DiagnosisRun.start` → `decideProbe` →
`answerProbeItem` → `decideFurtherLevel`, one call per screen action, threading `DiagnosisAdvance.state`." Task
02.11's §2 excludes `docs/*`.

## Spec sections changed

§1 (goal; I3/I4/I14/D27 bullets; AC1–AC13 restated on the step API; new AC8b depth-2 capped, AC14 I3 per item,
AC15 no public initializer on phase values); §2 (DiagnosisEvent.swift role line; PropertyGen generators); §3 (added
EPIC 04 row, EPIC 03 note, I14, this ruling; prior signatures re-anchored to the landed code with `path:line`); §4
(steps 2–16 rewritten: types, step algorithms, internal helpers, thin driver); §5 (T1–T9 on the step API; new
negative controls for depth bookkeeping and per-item I3; driver-equivalence property); §6 (depth convention;
decision fallback scoped to the driver; caller builds `FailedProbeAttempt`; code mapping; typed phases); §7 (a
`public init` count instrument). The probe-completed rule and the capped rule are carried over word for word in
substance.

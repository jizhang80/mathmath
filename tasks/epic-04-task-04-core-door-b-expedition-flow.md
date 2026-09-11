# Epic 04 · Task 04: Core Door B — expedition flow façade

---
epic: 04
task: 04
slug: core-door-b-expedition-flow
kind: feat
risk: seam
depends_on: [04.1, 04.1b, 04.2, 04.3]
model: opus
---

## §1 Goal & acceptance criteria

Goal: Implement, in `Core`, the Door B façade that drives `ExpeditionRun`'s public step API
(`start`/`answer`/`resume`/`end`) one call per screen action, gates every next item, diagnosis hand-off and
summary behind an explicit `continue`/`resume` call (I3), applies the D27 tolerance rule's student-visible
consequences (retry, hand-off to Door A, the "We'll come back to this one" line), assembles the two missed
`ItemMiss`es and opens 04.3's Door A façade on a second miss, resumes the suspended run once Door A
returns, and derives the run's summary content. The façade calls no adapter anywhere (I2) and performs no I/O
(task 04.5 sequences the writes; this task only computes the Q-G write-ahead value as a pure function).

Invariants in play:

- **I1** — the façade decides no correctness itself; every checked answer comes from
  `ExpeditionRun.answer`'s call into `ItemChecker` (already landed); the raw `submitted` string is passed
  through unsanitised, unnormalised.
- **I2** — every façade function is a pure value transformation over `ExpeditionRun`'s and 04.3's
  already-Tier-0 output; no adapter parameter exists anywhere in `ExpeditionFlow.swift`/`ExpeditionContent.swift`,
  verified by a grep with a planted-violation negative control.
- **I3** — after `answer`, the façade's only immediate output is the just-answered item's
  `DoorAnswerCardContent`; the next screen (the next item, the D27 diagnosis hand-off, or the summary) is
  reachable only through the separate `continueAfterAnswer` call, never through any public field of the value
  `answer` returns. A `CoreTests` property test asserts this over real `data/demo`, with a planted
  card-skipping negative control.
- **I4** — `diagnosisUsed` (already enforced inside `ExpeditionRun.answer`/`applyMiss`) guarantees at most one
  diagnosis hand-off per run; this façade never calls `DoorADiagnosisFlow.open` more than once per run because
  it only does so when `ExpeditionRunState.suspendedForDiagnosisNodeId` is set, which `applyMiss` sets at most
  once. At most one retry per node: `applyMiss` draws a retry only on `missCount == 1`; a property test asserts
  this over real `data/demo`.
- **I5** — every façade value carries only node/item ids, enums, `StudentState` (already I5-clean) and strings
  resolved from the bundle; no field identifies the student, device, install or session.
- **I14** — `ExpeditionFlow.swift` and `ExpeditionContent.swift` import Foundation only, contain no
  `@Observable`/SwiftUI, perform no I/O, and compute all Door B screen content in `Core`; the recursive `Core`
  import-boundary test picks up both new files automatically.

Acceptance criteria (each independently verifiable):

- AC1: `DoorBExpeditionFlow.start`/`.answer`/`.continueAfterAnswer`/`.resumeAfterDiagnosis` drive
  `ExpeditionRun`'s public step API (`start`/`answer`/`resume`/`end`) and 04.3's `DoorADiagnosisFlow`'s public
  step API (`open`/`start`) only — never `applyMiss`, `nextItem` or any other `ExpeditionRun`/`DiagnosisRun`
  private helper — producing `DoorBStartAdvance`/`DoorBAnswerAdvance`/`DoorBContinueAdvance`/
  `DoorBResumeAdvance`, over real `data/demo`.
- AC2 (I3): for a full run driven through the façade on real `data/demo`, `DoorBAnswerAdvance` (the value
  `answer` returns) exposes `answerCard`/`result`/`runState`/`state`/`events` and **no** field that yields a
  `DoorBScreen`; only `continueAfterAnswer(pending:bundle:)` produces the next `DoorBScreen`, and calling it
  twice on an `Equatable`-equal `DoorBAnswerAdvance` yields `Equatable`-equal `DoorBContinueAdvance` values. A
  source scan of `ExpeditionFlow.swift` asserts the `DoorBAnswerAdvance` declaration lines for
  `pendingHandoffMisses` and `pendingEnd` do not begin with `public let` (both must read plain `let`); a
  planted local copy of the struct with `public let pendingEnd` proves the same scan pattern catches it
  (negative control, case count > 0).
- AC3 (D27 retry): on real `data/demo`, a first miss on a node (e.g. `exponent-laws`, mirroring the landed
  `ExpeditionDiagnosisSeamTests` fixture) produces, after `continueAfterAnswer`, a `.item` screen whose
  `DoorItemContent.isRetry == true` and whose `nodeId` is unchanged from the missed item's node.
- AC4 (D27 hand-off assembly): on the node's second miss (`diagnosisUsed == false` entering the call), the
  façade builds `misses` from the two missed `CurrentItem.item` values with the **exact** submitted
  strings — asserted with one submitted string that is a node's own tagged distractor and one that is a
  whitespace-padded numeric string (e.g. `"  0 "`), both byte-equal on `ItemMiss.submittedValue` to
  what was passed into `answer` — and calls `DoorADiagnosisFlow.open(originNodeId:, trigger: .expeditionSecondMiss,
  levelBudget: 1)` then `.start(event:, misses:, shownItemIdsInRun: <the post-miss run's
  shownItemIds>, state:, bundle:)`, surfaced as `.diagnosis(DoorADiagnosisScreen)` on `continueAfterAnswer`.
- AC5 (D27 block + Q5 line): on the node's second miss with `diagnosisUsed == true` entering the call, no
  `DoorADiagnosisFlow` call is made; `answer`'s returned `answerCard.extraLine ==
  DoorBSummaryCopy.secondMissLine` exactly in this case and in no other (never on a first miss, never on the
  miss that opens diagnosis, never on a correct answer), including when the node entered the run already
  `.blocked` (idempotent `MasteryTransitions.diagnosisBlocked`, `ExpeditionRun.swift:213-215`, where
  `blockedNodeIds` is not appended) — the condition is computed from `missCounts` before/after the call, never
  from `blockedNodeIds` membership (§4 item 3, §6).
- AC6 (I4 properties, real `data/demo`): across a run touching every node that misses twice, `diagnosisUsed`
  is set by at most one `answer` call and `DoorADiagnosisFlow.open` is called at most once; no node's
  `missCounts` value ever reaches a THIRD retry-drawn `.item` screen (`isRetry == true`) — the third+ miss on
  any node always routes to hand-off-or-block, never another retry.
- AC7 (resume, Q-A/Q-G "returned always hands control back"): `resumeAfterDiagnosis` calls
  `ExpeditionRun.resume(run:)` and threads the terminal `DiagnosisOutcome.state` into the next screen; the
  run's pre-diagnosis `ExpeditionRunState.results` are all present, unchanged, in the resumed run's `results`
  (mirrors `ExpeditionDiagnosisSeamTests.secondMissOpensRealDiagnosisThenResumes`'s own assertions, driven this
  time through the façade).
- AC8 (Q-G natural end): the run's final `ExpeditionRun.end(..., abandoned: false)` call is made inside the
  SAME façade call that produces the run's last result — either `answer` (when its own `outcome.run` reaches
  an empty, unsuspended queue) or `resumeAfterDiagnosis` (when its own post-`resume` run reaches an empty
  queue) — never inside `continueAfterAnswer`; `continueAfterAnswer`'s returned `state` in the natural-end
  branch is exactly the `state` `answer` already computed (`pending.pendingEnd!.state`), not a value
  `continueAfterAnswer` derives itself — asserted by identity/equality across the two calls.
- AC9 (summary content, `contracts/content-policy.md` § Voice): `DoorBSummaryScreen` carries `itemCount`,
  `clearedNodeNames`, `blockedNodeNames` and the fixed `Start another`/`Back to the map` labels; no field on it
  or on any type in `ExpeditionContent.swift` names a tint, a fraction or a percentage.
- AC10 (Q-G write-ahead value): `DoorBWriteAhead.provisionalAbandonedState(runState:state:today:)` returns
  exactly `ExpeditionRun.end(run: runState.run, state: state, today: today, abandoned: true).state` — a pure
  computation, asserted by direct equality against a same-arguments call to `ExpeditionRun.end` — with no I/O
  anywhere in this task (task 04.5 is the only writer).
- AC11 (I2/I14): `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift` and
  `Packages/Core/Sources/Core/Door/ExpeditionContent.swift` import Foundation only; a grep asserts both files
  are non-empty (found) and contain zero matches for an adapter/model pattern set (`FoundationModels`,
  `Adapter`, `import CoreML`, `URLSession`); a planted-fixture negative control (a local string, never product
  code) proves the same grep pattern catches a violation.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Door/ExpeditionFlow.swift` — CREATE. Holds `DoorBRunState`,
  `DoorBStartAdvance`, `DoorBAnswerAdvance`, `DoorBContinueAdvance`, `DoorBResumeAdvance`,
  `DoorBWriteAhead`, and `DoorBExpeditionFlow` (the four public entry points plus the private screen-derivation
  glue). Confirmed absent (context bundle §E and this run's own `Glob
  "Packages/Core/Sources/Core/Door/ExpeditionFlow.swift"` — empty).
- `Packages/Core/Sources/Core/Door/ExpeditionContent.swift` — CREATE. Holds `DoorBScreen`, `DoorBSummaryScreen`,
  `DoorBSummaryCopy`, and the pure content-derivation `DoorBContent` (item-screen wrapper, summary-screen
  builder). Confirmed absent (same Glob).
- `Packages/Core/Tests/CoreTests/ExpeditionFlowTests.swift` — CREATE. This task's own companion test suite
  (AC1–AC11), over real `data/demo` plus constructed fixtures for the negative controls, following
  `ExpeditionDiagnosisSeamTests.swift`'s bundle-loading and fixture shape.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY, append-only, only if the AC2/AC6
  property tests need a generator not already present (§6). Any addition goes under a new
  `// MARK: - 04.4 additions` comment block; no existing function is edited, reordered or removed.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` — landed file; call its public step functions only,
  never edit it, never call its private helpers (`nextItem`, `applyMiss`) from outside this task.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift`, `Packages/Core/Sources/Core/Diagnosis/Classify.swift`
  — landed 02.11 files; call `ItemMiss`'s public initializer and `DiagnosisOutcome`'s public fields
  only, never edit, never call internal helpers.
- `Packages/Core/Sources/Core/Door/DoorItemContent.swift` (04.2's file) and
  `Packages/Core/Sources/Core/Door/DiagnosisFlow.swift` / `DiagnosisContent.swift` (04.3's files) — call their
  existing public initializers/entry points only, no edit. This task reuses `DoorItemContent` and
  `DoorAnswerCardContent` directly for item/answer-card screen content (§6) rather than re-wrapping them.
- `Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift` — already-landed C1 seam test; read-only
  precedent for this task's own test fixture shape, never edited.
- `contracts/**`, `docs/**`, `data/demo/**`, `App/**` — read-only inputs to this task.
- Any App/Sources file, any persistence (`StudentStateStore.write` or equivalent), the "Back to the map"
  abandon call site, "Start expedition"/"Unit expedition"/"Check me here"/"Start another" entry wiring — task
  04.5, not this task. Nothing in this task's scope writes to disk; `DoorBWriteAhead` is a pure function 04.5
  calls, not a writer.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 2. Expedition` (re-read, byte-compared this run,
  `contracts/interaction-contract.md:28-60`):
  > States: `idle → composing → item → (retry | diagnosing | item) → summary → idle`.
  >
  > - `compose` (D48, D45, D46, v2.7 §3): fringe = `{n : mastery(n) ≠ cleared ∧ ∀ p ∈ prereq(n): mastery(p) =
  >   cleared ∨ (mastery(p) = blocked ∧ remediated(p))}` ∩ (nodes of `marker.unit ∪ next(marker.unit)`, or the
  >   requested unit only) ∪ `{n : mastery(n) = blocked}`. Slots = up to 5: map-queued node first (map Q5, if
  >   on the fringe), then fringe nodes in trail order, then due cleared nodes (`next_due ≤ today`, oldest
  >   `last_probe` first), **≤ 2 review slots** (expedition Q3). Empty → `EXP_NO_FRINGE`. `remediated(p)` ≡
  >   `nodes[p].remediated == true` (`data-model.md` § StudentState; absent = false).
  > - `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by
  >   choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
  > - **Tolerance (D27):** first miss on a node in this run → `retry` with a second item of the same node;
  >   second miss → if `diagnosis_used == false` → `diagnosing` (set `diagnosis_used = true`), else mark the
  >   node `blocked` (expedition Q5: "We'll come back to this one") and continue. **At most one diagnosis per
  >   run.**
  > - `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
  >
  > **Properties (CoreTests):** never draws a new-learning item off the fringe or upstream of the marker unless
  > the node is `blocked`; never more than one diagnosis event per run; never more than 2 review slots; every
  > item shown ends with its answer visible.

  Binds this task: the façade implements the `answer`/`end` contract transitions' student-visible consequences
  — `compose` is out of scope (already implemented by `Expedition.compose`, called by the caller before
  `DoorBExpeditionFlow.start`). The D27 tolerance rule's state machinery already lives inside
  `ExpeditionRun.answer`/`applyMiss`; this task's job is to observe that machinery's output and derive screen
  content and the Door A hand-off from it, never to re-implement the tolerance rule itself.

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis` (re-read, byte-compared this run,
  `contracts/interaction-contract.md:76-99`), the one clause this task depends on:
  > - `returned` always hands control back to the suspended expedition (its next item) or the map node panel.

  Binds this task: `resumeAfterDiagnosis` is the unconditional hand-back point — called once Door A reaches its
  `.terminal` screen, regardless of which `DiagnosisTerminal` case it carries.

- `tasks/arbitration/arbiter-04-predispatch.md` — § Q-A (re-read, byte-compared this run,
  `tasks/arbitration/arbiter-04-predispatch.md:35-98`):
  > "Continue" is a façade entry point, not an App-only presentation flag. After an answer, the façade's
  > current screen value is the answer card. Only the continue call moves it on, to the next item, the retry,
  > the second probe item, the hypothesis card (D27 hand-off), remediation, a terminal line, or the summary.
  > This is what makes the brief's § 4 item 3 guard ("No next-item, terminal or summary value is reachable
  > without one") assertable in `CoreTests`, with its planted negative control. The continue call changes no
  > `StudentState`, so it triggers no write.
  >
  > *Summary region tint deltas.* **Not shown.** ... The summary lists the nodes cleared this run, the fog
  > lifted, the nodes marked `blocked`, and offers "Start another" and "Back to the map". It shows no region
  > tint delta and no fraction; the re-derived map shows the tint on return (map W6).

  Binds this task: `continueAfterAnswer` reveals, but never itself computes via a new mutating `ExpeditionRun`/
  `DiagnosisRun` call, any `StudentState` change — in the D27 hand-off branch it calls `DoorADiagnosisFlow.start`,
  which (verified this run against `DiagnosisEvent.swift`) never mutates `StudentState` at the
  hypothesis-formation stage, so the returned `state` is unchanged; in the natural-end branch it reveals the
  `state` already computed by the preceding `answer` call, not a value it derives itself (§6). The summary
  carries cleared/blocked node names and the two button labels, no tint delta, no fraction.

- `tasks/arbitration/arbiter-04-predispatch.md` — § Q-G (re-read, byte-compared this run,
  `tasks/arbitration/arbiter-04-predispatch.md:263-287`):
  > - **In-run write-ahead.** After every state-changing Door B or Door A call during a run, including the
  >   run-start call, the session persists `ExpeditionRun.end(run: <current run>, state: <threaded state>,
  >   today:, abandoned: true).state`. The in-memory threaded state never contains that entry. At a natural end
  >   the session persists `end(…, abandoned: false).state`. On "Back to the map" mid-run it persists `end(…,
  >   abandoned: true).state`. Either way, the provisional entry is replaced, because it was never in memory.
  > - **Where the natural end is called.** In the same façade call that produces the run's last result: the
  >   final answer, or the `returned` that resumes into an empty queue. The summary value is held behind that
  >   call's answer card and shown on continue (Q-A). So a completed run is never logged abandoned by an OS
  >   kill while its last card is on screen.

  Binds this task: `answer` computes (never persists) `ExpeditionRun.end(..., abandoned: false)` when its own
  `outcome.run` reaches an empty, unsuspended queue, holding the result behind the answer card;
  `resumeAfterDiagnosis` computes the same when its own post-`resume` run reaches an empty queue. The
  write-ahead value itself (the `abandoned: true` provisional entry, called after every state-changing call —
  Door B's own, and every Door A call the caller drives directly between `.diagnosis` and `resumeAfterDiagnosis`)
  is the value `DoorBWriteAhead.provisionalAbandonedState` computes; task 04.5 is the only caller that persists
  it (§6).

Prior signatures this task builds on (verbatim, re-read against the current tree this run):

- `Packages/Core/Sources/Core/State/ExpeditionRun.swift` (full public surface this task calls,
  `ExpeditionRun.swift:1-192`):
  ```swift
  public struct ItemResult: Equatable {
      public let nodeId: String
      public let itemId: String
      public let correct: Bool
      public let correctAnswerDisplay: String
      public let why: String
      public let isRetry: Bool
  }
  public struct CurrentItem: Equatable {
      public let nodeId: String
      public let item: ProbeItem
      public let kind: SlotKind
      public let isRetry: Bool
  }
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
  public struct StartOutcome: Equatable { public let run: ExpeditionRunState; public let event: CoreEvent }
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
      public let event: CoreEvent
  }
  public enum ExpeditionRun {
      public static func start(compose: ComposeResult) -> StartOutcome
      public static func answer(
          run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String,
          today: CalendarDay
      ) -> AnswerOutcome
      public static func resume(run: ExpeditionRunState) -> ExpeditionRunState
      public static func end(
          run: ExpeditionRunState, state: StudentState, today: CalendarDay, abandoned: Bool
      ) -> EndOutcome
  }
  ```
  The `applyMiss` doc comment (private helper, not called directly by this task — read for its documented
  observable consequences only, `ExpeditionRun.swift:205-215`):
  > The D27 branch for a miss, shared by the fog/blocked path and the review path: increments
  > `missCounts[nodeId]`; on the first miss, draws a retry item via
  > `Expedition.selectItem(from:excluding:probeLog:)` excluding `run.shownItemIds` — if `nil` (no unused item),
  > appends `nodeId` to `run.itemPoolEmptyNodeIds` and advances to the next queue item instead of retrying (the
  > arbiter's technical default); on the second miss with `run.diagnosisUsed == false`, sets
  > `run.suspendedForDiagnosisNodeId = nodeId`, `run.diagnosisUsed = true`, `run.currentItem = nil`, appends
  > `.expeditionDiagnosisRequested` to `events`; on the second miss with `run.diagnosisUsed == true`, calls
  > `MasteryTransitions.diagnosisBlocked(current: priorNodeState)`, writes the result into `state`, appends
  > `nodeId` to `run.blockedNodeIds` and `.diagnosisNodeBlocked` to `events` when that call's `event` is
  > non-nil, and advances `run.currentItem` to the next queue item.

  Binds this task: the block branch's `blockedNodeIds`/`.diagnosisNodeBlocked` append is conditional on the
  transition producing a non-nil event (a no-op when the node was already `.blocked`, per
  `MasteryTransitions.diagnosisBlocked`'s guard). The façade's Q5-line/hand-off detection therefore reads
  `missCounts` before/after the call, never `blockedNodeIds` membership (§4 item 3).

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` / `Classify.swift` (the surface this task calls,
  re-read this run):
  ```swift
  public enum DiagnosisTrigger: String, Equatable { case expeditionSecondMiss = "expedition_second_miss"; case mapCheckHere = "map_check_here" }
  public struct DiagnosisEvent: Equatable { public let originNodeId: String; public let trigger: DiagnosisTrigger; public let levelBudget: Int }
  public struct ItemMiss: Equatable {
      public let item: ProbeItem
      public let submittedValue: String
      public init(item: ProbeItem, submittedValue: String)
  }
  public struct DiagnosisOutcome: Equatable {
      public let state: StudentState
      public let terminal: DiagnosisTerminal
      public let depthReached: Int
      public let blockedNodeIds: [String]
      public let hintNodeId: String?
      public let hintErrorTypeId: String?
      public let probeResults: [ItemResult]
      public let events: [CoreEvent]
      public let code: CoreError?
  }
  ```

- `tasks/epic-04-task-03-core-door-a-diagnosis-flow.md` §4 item 4 (04.3's specified — not yet landed on the
  tree this spec is written against, since 04a runs its tasks sequentially; treated as a locked dependency
  signature per the same precedent 04.3 itself used for 04.2/EPIC 03):
  ```swift
  public struct DoorADiagnosisAdvance: Equatable {
      public let screen: DoorADiagnosisScreen
      public let state: StudentState
      public let events: [CoreEvent]
  }
  public enum DoorADiagnosisFlow {
      public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent
      public static func start(
          event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
          state: StudentState, bundle: ContentBundle
      ) -> DoorADiagnosisAdvance
      // decideProbe/answerProbeItem/continueAfterProbeAnswer/decideFurtherLevel: called directly by the App
      // between this task's `.diagnosis` screen and its `resumeAfterDiagnosis` call — never wrapped here.
  }
  public enum DoorADiagnosisScreen: Equatable {
      case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
      case probeItem(content: DoorItemContent, probe: ProbeInProgress)
      case furtherLevelOffer(remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent, decision: FurtherLevelOffer)
      case terminal(DoorATerminalContent)
  }
  ```
  Binds this task: `continueAfterAnswer`'s D27 hand-off branch calls only `DoorADiagnosisFlow.open` then
  `.start`; every later Door A step in the same diagnosis is the App's own direct call against
  `DoorADiagnosisFlow`, never routed back through this façade, until the App observes a `.terminal(...)`
  screen and calls this task's `resumeAfterDiagnosis` with that terminal's `DiagnosisOutcome`.

- `tasks/epic-04-task-02-core-door-item-card-keypad.md` §4 items 2–3 (04.2's landed shape this task reuses
  directly for item/answer-card screen content):
  ```swift
  public struct DoorItemContent: Equatable {
      public let nodeId: String
      public let promptLatex: String
      public let inputKind: DoorItemInputKind
      public let choices: [DoorItemChoice]
      public let isRetry: Bool
      public init(nodeId: String, item: ProbeItem, isRetry: Bool)
  }
  public struct DoorAnswerCardContent: Equatable {
      public let correct: Bool
      public let correctAnswerDisplay: String
      public let correctAnswerDisplayKind: DoorAnswerDisplayKind
      public let why: String
      public let extraLine: String?
      public init(result: ItemResult, itemType: ProbeItemType, extraLine: String? = nil)
  }
  ```

Facts confirmed absent (re-run this run):

- No `Door/ExpeditionFlow.swift` or `Door/ExpeditionContent.swift` exists (`Glob
  "Packages/Core/Sources/Core/Door/*.swift"` returned no results on the tree this spec is written against — the
  `Door/` directory itself does not yet exist).
- `ExpeditionDiagnosisSeamTests.swift` (already landed, read this run) proves the exact
  `ExpeditionRun.start`/`.answer`/real-`DiagnosisRun`-steps/`.resume` sequence this façade wraps compiles and
  passes today with no stub on either side — the reference shape this task's own tests follow, never edited.

## §4 Implementation outline

1. **Layer.** Both new files sit in layer ④ interaction (Door B screen content and flow), composing layer ③
   learning-objects data already carried on `Node`/`ProbeItem` (via `ExpeditionRun`'s output) and 04.3's Door A
   façade for the D27 hand-off. Neither file performs I/O or reads the system clock except through the
   caller-supplied `CalendarDay` it forwards unchanged.

2. **`ExpeditionContent.swift` — screen-content value types and Door B copy.**
   ```swift
   import Foundation

   public enum DoorBSummaryCopy {
       public static let clearedHeading = "Fog lifted"
       public static let blockedHeading = "Marked on the map"
       public static let startAnotherLabel = "Start another"
       public static let backToMapLabel = "Back to the map"
       public static let secondMissLine = "We'll come back to this one"
   }

   /// One screen the Door B façade hands the caller after a state-changing or continue call. `.item` reuses
   /// 04.2's `DoorItemContent` directly (04.2's own §6 default: its screen-content types are shared by both
   /// doors — no second wrapper type here, RULE 2). `.diagnosis` carries 04.3's raw `DoorADiagnosisScreen`
   /// unmodified, for the App to render and drive further itself.
   public enum DoorBScreen: Equatable {
       case item(DoorItemContent)
       case diagnosis(DoorADiagnosisScreen)
       case summary(DoorBSummaryScreen)
   }

   /// Built only from `ExpeditionSummary` (no tint deltas, no fractions/percentages —
   /// `contracts/content-policy.md` § Voice).
   public struct DoorBSummaryScreen: Equatable {
       public let itemCount: Int
       public let clearedNodeNames: [String]
       public let blockedNodeNames: [String]
       public let clearedHeading: String
       public let blockedHeading: String
       public let startAnotherLabel: String
       public let backToMapLabel: String
   }

   enum DoorBContent {
       static func itemScreen(_ current: CurrentItem) -> DoorItemContent {
           DoorItemContent(nodeId: current.nodeId, item: current.item, isRetry: current.isRetry)
       }

       static func summaryScreen(summary: ExpeditionSummary, bundle: ContentBundle) -> DoorBSummaryScreen {
           DoorBSummaryScreen(
               itemCount: summary.itemCount,
               clearedNodeNames: summary.clearedNodeIds.map { nodeName($0, bundle: bundle) },
               blockedNodeNames: summary.blockedNodeIds.map { nodeName($0, bundle: bundle) },
               clearedHeading: DoorBSummaryCopy.clearedHeading,
               blockedHeading: DoorBSummaryCopy.blockedHeading,
               startAnotherLabel: DoorBSummaryCopy.startAnotherLabel,
               backToMapLabel: DoorBSummaryCopy.backToMapLabel)
       }

       private static func nodeName(_ id: String, bundle: ContentBundle) -> String {
           guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
               preconditionFailure("DoorBContent: node \(id) not found in bundle")
           }
           return match.name
       }
   }
   ```

3. **`ExpeditionFlow.swift` — the façade.**
   ```swift
   import Foundation

   /// Door B's own run wrapper: `ExpeditionRun`'s value state plus the one piece of D27 hand-off bookkeeping
   /// `ExpeditionRunState` itself does not carry — the first miss's `ItemMiss`, held only between a
   /// first-miss retry and a possible second-miss hand-off on the SAME node. `pendingFirstMiss` carries no
   /// `public` modifier: no caller constructs or inspects it (§6).
   public struct DoorBRunState: Equatable {
       public let run: ExpeditionRunState
       let pendingFirstMiss: ItemMiss?
   }

   public struct DoorBStartAdvance: Equatable {
       public let runState: DoorBRunState
       public let screen: DoorBScreen
       public let event: CoreEvent
   }

   /// Returned by `answer` (I3): the just-answered item's card only. `pendingHandoffMisses`/`pendingEnd`
   /// carry no `public` modifier — no field of this type yields the next `DoorBScreen`; only
   /// `continueAfterAnswer` does.
   public struct DoorBAnswerAdvance: Equatable {
       public let answerCard: DoorAnswerCardContent
       public let result: ItemResult
       public let runState: DoorBRunState
       public let state: StudentState
       public let events: [CoreEvent]
       let pendingHandoffMisses: [ItemMiss]?
       let pendingEnd: EndOutcome?
   }

   public struct DoorBContinueAdvance: Equatable {
       public let screen: DoorBScreen
       public let runState: DoorBRunState
       public let state: StudentState
       public let events: [CoreEvent]
   }

   public struct DoorBResumeAdvance: Equatable {
       public let screen: DoorBScreen
       public let runState: DoorBRunState
       public let state: StudentState
       public let events: [CoreEvent]
   }

   public enum DoorBExpeditionFlow {
       public static func start(compose: ComposeResult) -> DoorBStartAdvance {
           let outcome = ExpeditionRun.start(compose: compose)
           guard let current = outcome.run.currentItem else {
               preconditionFailure("DoorBExpeditionFlow.start: compose produced no first item")
           }
           return DoorBStartAdvance(
               runState: DoorBRunState(run: outcome.run, pendingFirstMiss: nil),
               screen: .item(DoorBContent.itemScreen(current)), event: outcome.event)
       }

       public static func answer(
           _ runState: DoorBRunState, submitted: String, state: StudentState, bundle: ContentBundle,
           today: CalendarDay
       ) -> DoorBAnswerAdvance {
           guard let current = runState.run.currentItem else {
               preconditionFailure("DoorBExpeditionFlow.answer called with no currentItem (suspended or ended)")
           }
           let outcome = ExpeditionRun.answer(
               run: runState.run, state: state, bundle: bundle, submitted: submitted, today: today)

           // Q5 line / hand-off detection reads missCounts before/after — never blockedNodeIds (§3, §6).
           let priorMissCount = runState.run.missCounts[current.nodeId] ?? 0
           let newMissCount = outcome.run.missCounts[current.nodeId] ?? 0
           let openedDiagnosisHere = outcome.run.suspendedForDiagnosisNodeId == current.nodeId
           let isSecondMissThisCall =
               !outcome.result.correct && priorMissCount == 1 && newMissCount == 2
           let extraLine =
               (isSecondMissThisCall && !openedDiagnosisHere) ? DoorBSummaryCopy.secondMissLine : nil
           let answerCard = DoorAnswerCardContent(
               result: outcome.result, itemType: current.item.type, extraLine: extraLine)

           var newPendingFirstMiss: ItemMiss?
           var pendingHandoffMisses: [ItemMiss]?
           if !outcome.result.correct {
               let thisMiss = ItemMiss(item: current.item, submittedValue: submitted)
               let retryDrawnHere =
                   outcome.run.currentItem?.isRetry == true
                   && outcome.run.currentItem?.nodeId == current.nodeId
               if retryDrawnHere {
                   newPendingFirstMiss = thisMiss
               } else if openedDiagnosisHere {
                   pendingHandoffMisses = [runState.pendingFirstMiss, thisMiss].compactMap { $0 }
               }
               // else: block-after-diagnosisUsed (Q5) or an item-pool dead-end — no pending state kept.
           }

           var pendingEnd: EndOutcome?
           if outcome.run.currentItem == nil && outcome.run.suspendedForDiagnosisNodeId == nil {
               // Q-G: the natural end, computed here, revealed on continue.
               pendingEnd = ExpeditionRun.end(
                   run: outcome.run, state: outcome.state, today: today, abandoned: false)
           }

           return DoorBAnswerAdvance(
               answerCard: answerCard, result: outcome.result,
               runState: DoorBRunState(run: outcome.run, pendingFirstMiss: newPendingFirstMiss),
               state: outcome.state, events: outcome.events,
               pendingHandoffMisses: pendingHandoffMisses, pendingEnd: pendingEnd)
       }

       public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, bundle: ContentBundle)
           -> DoorBContinueAdvance
       {
           if let end = pending.pendingEnd {
               return DoorBContinueAdvance(
                   screen: .summary(DoorBContent.summaryScreen(summary: end.summary, bundle: bundle)),
                   runState: pending.runState, state: end.state, events: [end.event])
           }
           if let misses = pending.pendingHandoffMisses,
               let originNodeId = pending.runState.run.suspendedForDiagnosisNodeId
           {
               let event = DoorADiagnosisFlow.open(
                   originNodeId: originNodeId, trigger: .expeditionSecondMiss, levelBudget: 1)
               let advance = DoorADiagnosisFlow.start(
                   event: event, misses: misses,
                   shownItemIdsInRun: pending.runState.run.shownItemIds, state: pending.state, bundle: bundle)
               return DoorBContinueAdvance(
                   screen: .diagnosis(advance.screen), runState: pending.runState, state: advance.state,
                   events: advance.events)
           }
           guard let current = pending.runState.run.currentItem else {
               preconditionFailure(
                   "DoorBExpeditionFlow.continueAfterAnswer: no next item, no hand-off, no end pending")
           }
           return DoorBContinueAdvance(
               screen: .item(DoorBContent.itemScreen(current)), runState: pending.runState,
               state: pending.state, events: [])
       }

       public static func resumeAfterDiagnosis(
           _ runState: DoorBRunState, outcome: DiagnosisOutcome, bundle: ContentBundle, today: CalendarDay
       ) -> DoorBResumeAdvance {
           let resumedRun = ExpeditionRun.resume(run: runState.run)
           let resumedRunState = DoorBRunState(run: resumedRun, pendingFirstMiss: nil)
           if let current = resumedRun.currentItem {
               return DoorBResumeAdvance(
                   screen: .item(DoorBContent.itemScreen(current)), runState: resumedRunState,
                   state: outcome.state, events: [])
           }
           let end = ExpeditionRun.end(
               run: resumedRun, state: outcome.state, today: today, abandoned: false)
           return DoorBResumeAdvance(
               screen: .summary(DoorBContent.summaryScreen(summary: end.summary, bundle: bundle)),
               runState: resumedRunState, state: end.state, events: [end.event])
       }
   }

   /// Q-G write-ahead value: what task 04.5 persists after every state-changing Door B or Door A call during
   /// a run, replaced by the natural end or "Back to the map" abandon. A pure computation — 04.5 performs the
   /// write. `runState.run` stays unchanged across the whole Door A leg of a diagnosis (it is suspended), so
   /// 04.5 calls this with the same `runState` and each successively newer `state` Door A's own steps thread.
   public enum DoorBWriteAhead {
       public static func provisionalAbandonedState(
           runState: DoorBRunState, state: StudentState, today: CalendarDay
       ) -> StudentState {
           ExpeditionRun.end(run: runState.run, state: state, today: today, abandoned: true).state
       }
   }
   ```

4. **Boundary schema(s).** None: this file parses no untrusted external input. Its inputs (`ComposeResult`, the
   `ExpeditionRunState`/`DoorBRunState` phase types, `ItemResult`, `StudentState`, `ContentBundle`,
   `DiagnosisOutcome`) are already-decoded, already-validated `Core` types. The `submitted` string is passed
   through to `ExpeditionRun.answer` unsanitised and unnormalised — normalisation is `ItemChecker`'s job
   (`contracts/interaction-contract.md` § 2 expedition Q4), never re-implemented here.

5. **Error codes.** None thrown by this file. `EXP_NO_FRINGE` is raised by `Expedition.compose`, upstream of
   `DoorBExpeditionFlow.start`; `EXP_STATE_WRITE_FAILED` is task 04.5's concern (a write failure, and this
   task performs no writes).

6. **Model-calling path.** None anywhere in this file (I2): every function is a pure transformation over
   `ExpeditionRun`'s and `DoorADiagnosisFlow`'s already-Tier-0 output. No adapter type, no confidence threshold,
   no Tier-1 fallback applies here.

7. Smoke check: `swift build --package-path Packages/Core` — must be green.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: a full expedition through the façade on real `data/demo` — `start` → several
  `answer`/`continueAfterAnswer` pairs on correctly-answered items (each reveals the next `.item` screen) →
  the run's natural end (`answer`'s `pendingEnd` set, revealed as `.summary` by `continueAfterAnswer`) — AC1,
  AC9.
- T2 negative — invalid input rejected at the boundary: this file parses no untrusted external input (§4 item
  4); the applicable defensive case is a `submitted` string that fails `ItemChecker`'s numeric grammar (e.g.
  `"abc"`) — `answer` still returns a well-formed `DoorBAnswerAdvance` with `answerCard.correct == false`,
  never a crash (mirrors 04.2/04.3's T2 shape).
- T3 error-taxonomy: this task raises no error codes (§4 item 5); confirmed by grep — no `CoreError` case is
  thrown anywhere in `ExpeditionFlow.swift`/`ExpeditionContent.swift`.
- T4 conformance per requirements §B.1 and the invariants of §1:
  - interaction-contract § 2 Properties, the ones this façade's own behaviour is responsible for: never more
    than one diagnosis event per run (AC6); every item shown ends with its answer visible (AC2's I3 gate, the
    answer card always carries `correctAnswerDisplay`/`why` from `ItemResult`, already guaranteed by 04.2's
    `DoorAnswerCardContent.init`).
  - I3: AC2, over a full real-`data/demo` run.
  - I4: AC3, AC4, AC5, AC6, on real `data/demo`.
  - I5: a `Mirror`-based scan over `DoorBSummaryScreen` and `DoorBScreen` finds no field name matching a
    student/device/install/session identifier pattern (empty pool = FAIL), mirroring 04.2/04.3's shape.
- T5 negative control for every regression guard:
  - AC2's I3 guard: a source scan of `ExpeditionFlow.swift` asserts the `DoorBAnswerAdvance` declaration lines
    for `pendingHandoffMisses` and `pendingEnd` do not begin with `public let`; a planted local copy of the
    struct with `public let pendingEnd` proves the same scan pattern catches it.
  - AC5's `missCounts`-based Q5 detection: a reconstructed local variant using `blockedNodeIds`
    membership-diff instead of `missCounts` fails to set `extraLine` on the already-`.blocked`-entering-the-run
    fixture (the exact case §3's `applyMiss` doc comment documents as a `blockedNodeIds`-silent no-op),
    proving the guard is load-bearing; the variant never touches product code.
  - AC10: `DoorBWriteAhead.provisionalAbandonedState`'s result compared against a locally-reconstructed
    variant that omits `abandoned: true` (passes `false`) — the two differ (`abandoned` flows into the
    `ExpeditionLogEntry`), proving the assertion is load-bearing.
  - AC11's I2 grep: a planted local string containing `"FoundationModels"` (never added to product code) proves
    the pattern match fires; the grep first asserts both scanned files are non-empty (found).
- T6 idempotency / no-leak: `continueAfterAnswer` called twice on the same `Equatable`-equal `DoorBAnswerAdvance`
  returns `Equatable`-equal `DoorBContinueAdvance` values; none of the four façade entry points mutates its
  `StudentState`/`DoorBRunState`/`ComposeResult`/`DiagnosisOutcome` argument (all are `let`-only value types
  passed by value); `DoorBWriteAhead.provisionalAbandonedState` produces no side effect and can be called
  repeatedly with identical results on identical arguments (pure function, asserted by two calls compared for
  equality).

## §6 Decision defaults

- IF a caller needs Door B screen content for the item view or the answer card THEN it reuses 04.2's
  `DoorItemContent`/`DoorAnswerCardContent` directly — no `DoorBItemScreen`/`DoorBAnswerCardScreen` wrapper
  type is introduced, because those types are already the shared-by-both-doors content values (04.2's own
  file-scope note: "Core screen-content values shared by both doors") and a wrapper would duplicate them with
  no second real consumer (`CLAUDE.md` RULE 2). Only the summary gets a Door-B-specific type
  (`DoorBSummaryScreen`), because no such type exists yet anywhere in `Core`.
- IF the second-miss/Q5-line condition is computed THEN it reads `ExpeditionRunState.missCounts[nodeId]`
  before and after the `answer` call (`priorMissCount == 1 && newMissCount == 2`, combined with
  `suspendedForDiagnosisNodeId != nodeId` to exclude the diagnosis-opening miss) — never `blockedNodeIds`
  membership, because `MasteryTransitions.diagnosisBlocked` is a documented no-op (no `blockedNodeIds` append,
  no event) when the node entered the run already `.blocked` (`ExpeditionRun.swift:213-215`, quoted §3), and
  the fringe definition explicitly admits already-`.blocked` nodes into a run's slots
  (`contracts/interaction-contract.md:30`, the `∪ {n : mastery(n) = blocked}` clause).
- IF `runState.pendingFirstMiss` is `nil` at the moment a second-miss hand-off is detected (an item-pool dead
  end on the first miss — `applyMiss`'s `itemPoolEmptyNodeIds` branch, no retry drawn, no `pendingFirstMiss`
  ever stored — followed by a later second encounter of the same node in the same run) THEN
  `misses` is built from the single available miss only (`[thisMiss]`), never force-unwrapped;
  `Classify.classify` accepts any non-empty `[ItemMiss]` (`Classify.swift`'s signature takes an
  array, no arity precondition). This is a defensive fallback for an edge case no cited contract rules out but
  none of `compose`'s documented slot-fill rules is known to produce (a node appearing in two queue slots in
  one run) — conservative, never crashes.
- IF the App needs to drive a diagnosis hand-off's later Door A steps (`decideProbe`, `answerProbeItem`,
  `continueAfterProbeAnswer`, `decideFurtherLevel`) THEN it calls `DoorADiagnosisFlow` directly, never through
  this façade — this task's only Door A calls are the one-time `open`+`start` inside `continueAfterAnswer`
  and the terminal hand-back via `resumeAfterDiagnosis`; wrapping every Door A step here would duplicate
  04.3's own façade with a second implementation (I14's single-source spirit) and contradicts the
  `epic-04-plan.md` seam note ("the Door entry points on EPIC 03's Core map-actions/session type (04.5); 04b
  calls only those entry points").
- IF `DoorBWriteAhead.provisionalAbandonedState` is called during the Door A leg of a diagnosis (between
  `.diagnosis` and `resumeAfterDiagnosis`) THEN the caller (04.5) passes the SAME `runState` each time (Door
  B's own run stays suspended/unchanged through that whole leg) together with whichever `StudentState` Door
  A's own most recent step returned — this task exposes the pure function; task 04.5 owns calling it after
  every state-changing call on either door and owns the actual write (`tasks/arbitration/arbiter-04-predispatch.md`
  § Q-G, quoted §3).
- IF the existing `PropertyGen.swift` fixtures already suffice to construct this task's real-`data/demo`-driven
  tests (as `ExpeditionDiagnosisSeamTests.swift` already demonstrates, with no `PropertyGen` dependency) THEN
  append nothing to `PropertyGen.swift` and leave it untouched (surgical changes — `CLAUDE.md` RULE 3); only
  append a new function there, under a new `// MARK: - 04.4 additions` comment, if a genuinely new generator
  shape is needed that a `ExpeditionFlowTests.swift`-local private helper cannot reasonably express.

Standing defaults: identifiers here are the already-validated node/item id strings threaded through unchanged,
never re-validated or re-generated (`contracts/data-model.md` § Identifiers, unchanged by this task); no model
call anywhere in this file (Tier 0 only, I2); no telemetry client in this file; no field here identifies a
student, device, install or session (I5); nodes carry `paraphrase`, never verbatim Ministry text — this task
introduces no new node-text field, only node names (already I6-clean) for the summary.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`)
- typecheck clean — Swift's typecheck is the build; N/A for Python (this task touches no `pipeline/`)
- `Core` build + test green (`swift build --package-path Packages/Core`; `xcodebuild test -scheme
  Core-Package` on the simulator)
- App build: N/A — this task does not touch `App/Sources`
- tests green for the cases in §5
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 2, the one clause of
  § 4 cited; `contracts/content-policy.md` § Voice; `tasks/arbitration/arbiter-04-predispatch.md` § Q-A, § Q-G)
  and to every invariant listed in §1 (I1, I2, I3, I4, I5, I14)

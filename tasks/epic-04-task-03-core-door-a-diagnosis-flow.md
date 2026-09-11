# Epic 04 · Task 03: Core Door A — diagnosis flow façade

---
epic: 04
task: 03
slug: core-door-a-diagnosis-flow
kind: feat
risk: seam
depends_on: [04.1, 04.1b, 04.2]
model: opus
---

## §1 Goal & acceptance criteria

Goal: Implement, in `Core`, the Door A façade that drives `DiagnosisRun`'s public step API
(`open`/`start`/`decideProbe`/`answerProbeItem`/`decideFurtherLevel`) one call per screen action, for both
triggers (`expedition_second_miss`, `map_check_here`), and derives every diagnosis screen's content from the
result: the hypothesis card, each probe item's item view and answer card, the remediation piece, the
further-level offer, the hint prose (resolved through the reconciled fallback table), and the terminal
lines. The Demo `levelBudget` is 1. The façade calls no adapter anywhere (I2) and persists nothing (task 04.5
sequences the writes).

Invariants in play:

- **I1** — the façade decides no correctness itself; every checked answer comes from `DiagnosisRun.answerProbeItem`'s
  call into `ItemChecker` (already landed, inside 02.11's machine). This file never compares against `answer`
  or `correctChoiceId`.
- **I2** — every façade function is a pure value transformation over `DiagnosisRun`'s already-Tier-0 step
  API; no adapter parameter exists anywhere in `DiagnosisFlow.swift`/`DiagnosisContent.swift`, verified by a
  grep with a planted-violation negative control.
- **I3** — after `answerProbeItem`, the façade's only immediate output is the just-answered item's
  `DoorAnswerCardContent`; the next screen (the second probe item, the further-level offer, or a terminal) is
  reachable only through a separate `continueAfterProbeAnswer` call, never through any public field of the
  value `answerProbeItem` returns. A `CoreTests` property test asserts this over every real `data/demo` node
  and both probe items of a run.
- **I4** — the Demo `levelBudget` of 1 is threaded unchanged from `DiagnosisEvent.levelBudget` into every
  `DiagnosisRun` call the façade makes; a confirmed probe at budget 1 reaches `.capped` with no
  `furtherLevelOffer` screen and no deeper-gap content anywhere in the terminal screen — only the fixed
  capped line and the remediation already shown for the probed candidate.
- **I5** — every façade value carries only node/item ids, enums, `StudentState` (already I5-clean) and
  strings resolved from the bundle; no field identifies the student, device, install or session.
- **I6** — remediation and hint content are the node's own `paraphrase`, `explanation`, `workedExamples` or
  `hint_tree` strings, never Ministry text; the hint resolver never presents an `ErrorType` the student was
  not classified with (never guesses a diagnosis).
- **I14** — `DiagnosisFlow.swift` and `DiagnosisContent.swift` import Foundation only, contain no
  `@Observable`/SwiftUI, and compute all diagnosis screen content in `Core`; the recursive `Core`
  import-boundary test picks up both new files automatically.

Acceptance criteria (each independently verifiable):

- AC1: `DoorADiagnosisFlow.open`/`.start`/`.decideProbe`/`.answerProbeItem`/`.continueAfterProbeAnswer`/`.decideFurtherLevel`
  drive `DiagnosisRun`'s public step API only (never `classify`, `hypothesise`, `drawProbeItems`, `offered`,
  `remediate`, `capped` or `hintKey` directly from outside this file's own hint resolver — see AC5), producing
  a `DoorADiagnosisAdvance` (screen + threaded `StudentState` + `[CoreEvent]`) or a `DoorAProbeAnswerAdvance`
  (answer card + threaded `StudentState` + `[CoreEvent]`), for both `DiagnosisTrigger` cases, over real
  `data/demo`.
- AC2: A full diagnosis run through the façade on real `data/demo`, for **each** trigger:
  - `expedition_second_miss`: `start` (with two real `ItemMiss`es built from a node's own tagged
    distractors) → hypothesis screen naming the candidate → `decideProbe(accept: true)` → two
    `answerProbeItem`/`continueAfterProbeAnswer` pairs (both probe items submitted wrong, tagged distractors)
    → `.terminal` with `terminal == .capped` (Demo budget 1), remediation non-nil, hint nil, line ==
    `DoorADiagnosisCopy.cappedLine`; the candidate is `blocked` in the returned `StudentState`; the events
    include `.diagnosisProbeCompleted`, `.diagnosisNodeBlocked`, `.diagnosisRemediationShown`,
    `.diagnosisCapped`, ending `.diagnosisReturned`.
  - `map_check_here`: (a) `decideProbe(accept: false)` on the opened hypothesis → `.terminal` with
    `terminal == .unconfirmed`, `hint` non-nil (resolved per AC5), `line == nil`, events ending
    `.diagnosisReturned`; (b) both probe items submitted correctly → `.terminal` with `terminal == .refuted`,
    `hint` non-nil, `line == DoorADiagnosisCopy.refutedLine`, events ending `.diagnosisReturned`.
- AC3 (I3): for every real `data/demo` node driven through a full probe, `DoorAProbeAnswerAdvance` (the value
  `answerProbeItem` returns) exposes `answerCard`/`itemResult`/`state`/`events` and **no** field that yields a
  `DoorADiagnosisScreen` or the raw `DiagnosisAdvance`; only `continueAfterProbeAnswer(pending:bundle:)`
  produces the next `DoorADiagnosisScreen`, and it is a pure function of `pending` (calling it twice on an
  `Equatable`-equal `DoorAProbeAnswerAdvance` yields `Equatable`-equal screens) that changes no `StudentState`
  and emits no new `CoreEvent` (its return type is `DoorADiagnosisScreen` alone).
- AC4 (I4): a confirmed probe at `levelBudget: 1` — on real `data/demo` and on a synthetic two-level graph
  built with `PropertyGen.smallLayeredGraphWithProbeItems` (so a deeper prerequisite exists) — reaches
  `.terminal` with `terminal == .capped` in the **same** `answerProbeItem` call that confirms the probe (no
  intervening `furtherLevelOffer` screen); the deeper candidate is `blocked` in `state.nodes`; the terminal's
  `DoorATerminalContent` carries a non-nil `remediation` (the probed candidate's) and `line ==
  DoorADiagnosisCopy.cappedLine`, and no field on `DoorATerminalContent` or `DiagnosisOutcome` names or
  surfaces the deeper candidate's own remediation or hint content.
- AC5 (hint resolver): `resolveHint(node:classifiedToken:)` implements the Rule 2 table of
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` exactly: letting `expected` be
  `"none-of-these"` when `classifiedToken == "none_of_these"`, else `classifiedToken`, and `key =
  DiagnosisRun.hintKey(originNode: node, errorTypeId: classifiedToken)`:
  - `key == expected` → `prose == node.hintTree[key]![0]`, `resolvedKey == key`, `internalCode == nil`;
  - `key != nil && key != expected` → `prose == node.hintTree[key]![0]`, `resolvedKey == key`, `internalCode
    == .loHintNotFound`;
  - `key == nil` → `prose == node.paraphrase`, `resolvedKey == nil`, `internalCode == .loHintNotFound`.

  On real `data/demo` (with 04.1b's `hint_tree["none-of-these"]` present), every `map_check_here` terminal
  hint (declined-`unconfirmed`, `refuted`, `DIAG_NO_PREREQUISITE`) lands on the first row: `resolvedKey ==
  "none-of-these"`, `internalCode == nil`. A constructed `Node` fixture with no `"none-of-these"` `hint_tree`
  entry lands on the third row: `prose == node.paraphrase`, `internalCode == .loHintNotFound`.
- AC6 (remediation selector): `selectRemediation(candidate:misses:)` returns, in this priority
  order: `.explanation(candidate.explanation)` when non-nil and non-empty; else
  `.workedExample(candidate.workedExamples!.first!)` when `workedExamples` is non-nil and non-empty; else
  `.paraphrase(candidate.paraphrase, hint:)`, where `hint` is `resolveHint(node: candidate, classifiedToken:
  Classify.classify(misses)).prose` when that call's `resolvedKey != nil`, else `nil`. It is never
  empty (`paraphrase` is schema-required — confirmed non-optional on `Node`). On every real `data/demo` node
  (post 04.1b) the confirmed branch takes `.paraphrase(_, hint: <non-nil>)`.
- AC7 (negative controls): a locally-reconstructed resolver variant that returns empty `prose` on a resolved
  key fails its own assertion; a locally-reconstructed variant that substitutes a **sibling** error type's
  tier-1 hint for the outcome token (rather than falling back to `"none-of-these"` or `nil`) fails its own
  assertion. Neither variant touches product code (`DiagnosisContent.swift`).
- AC8 (I2): `Packages/Core/Sources/Core/Door/DiagnosisFlow.swift` and
  `Packages/Core/Sources/Core/Door/DiagnosisContent.swift` import Foundation only; a grep asserts both files
  are non-empty (found) and contain zero matches for an adapter/model pattern set (`FoundationModels`,
  `Adapter`, `import CoreML`, `URLSession`); a planted-fixture negative control (a local string, never product
  code) proves the same grep pattern catches a violation.
- AC9: `CoreError` gains exactly one additive case, `loHintNotFound = "LO_HINT_NOT_FOUND"`, appended after the
  last existing case at implementation time, with every prior case byte-unchanged and in order (see §6 for the
  exact insertion point, which depends on whether 03.3's three additions have landed). `ErrorRegistryTests` and
  `ErrorRegistryNegativeControlTests` (both unmodified) stay green with no edit to either file.
- AC10 (terminal lines): `DoorATerminalContent.line` equals, exactly: `DoorADiagnosisCopy.refutedLine` for
  `.refuted`; `DoorADiagnosisCopy.cappedLine` for `.capped`; `CoreErrorText.text(for: .diagNoPrerequisite)` for
  `.noPrerequisite`; `CoreErrorText.text(for: .diagProbeUnavailable)` for `.unconfirmed` reached via
  `DIAG_PROBE_UNAVAILABLE` (`outcome.code == .diagProbeUnavailable`); `nil` for `.unconfirmed` reached via
  decline (`outcome.code == nil`) and for plain `.confirmed` (no ratified copy exists for either — §6).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Door/DiagnosisContent.swift` — CREATE. Holds `DoorADiagnosisCopy`,
  `DoorAHypothesisContent`, `DoorAHintContent`, `DoorARemediationContent`, `DoorAFurtherLevelOfferContent`,
  `DoorATerminalContent`, `DoorADiagnosisScreen`, and the pure content-derivation functions `resolveHint`
  and `selectRemediation`. Confirmed absent this run (context bundle §E and this run's own re-grep of `Door/`
  and `hypothesisCardContent|remediation.*selector|hintResolver|terminalLine` — no match).
- `Packages/Core/Sources/Core/Door/DiagnosisFlow.swift` — CREATE. Holds `DoorADiagnosisAdvance`,
  `DoorAProbeAnswerAdvance`, and `DoorADiagnosisFlow` (the six façade entry points plus the private
  `screen(for:classifiedToken:bundle:)`/`terminalContent(...)`/node-lookup glue). Confirmed absent (same
  grep).
- `Packages/Core/Sources/Core/CoreError.swift` — MODIFY: append exactly one additive case,
  `loHintNotFound = "LO_HINT_NOT_FOUND"`, after the last existing case; no reorder, no edit to any other
  case or to the file's header doc comment (§6 for the exact insertion point). This is the only EPIC 04 writer
  of this file (`docs/plans/epic-04-plan.md` task-scope note; brief §8 file-ownership notes).
- `Packages/Core/Tests/CoreTests/DiagnosisFlowTests.swift` — CREATE. This task's own companion test suite
  (AC1–AC10), over real `data/demo` plus constructed fixtures for the negative controls and the synthetic
  deeper-prerequisite case, following `DiagnosisMachineTests.swift`'s bundle-loading and node/edge-fixture
  shape.
- `Packages/Core/Tests/CoreTests/Support/PropertyGen.swift` — MODIFY, append-only, only if the I3/I4 property
  tests need a generator not already present (`probeableNode`, `smallLayeredGraphWithProbeItems`,
  `diagnosisLevelDecision(s)` already exist from 02.10/02.11 and may be sufficient — see §6). Any addition
  goes under a new `// MARK: - 04.3 additions` comment block, following the file's one-function-per-concern
  shape; no existing function is edited, reordered or removed.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` — 02.11's landed file; call its public step
  functions only, never edit it, never call its internal helpers (`classify`, `hypothesise`, `drawProbeItems`,
  `offered`, `remediate`, `capped`) from outside this task's own `resolveHint`, which calls `hintKey`
  in-module per the reconciliation Rule 2 ("calls `hintKey` in-module... nothing is reimplemented").
- `Packages/Core/Sources/Core/Door/DoorItemContent.swift` — 04.2's file; call `DoorItemContent`'s and
  `DoorAnswerCardContent`'s existing public initializers only, no edit.
- `Packages/Core/Sources/Core/CoreErrorText.swift` — 03.3's file (not present on the tree at the time this
  spec is written — EPIC 03 has not yet merged into the working tree used to compile it; see §6); read its
  public `text(for:)`/`userText` surface only, never edit it, never add a new entry (`LO_HINT_NOT_FOUND` is
  internal and carries no `userText` entry by design).
- `Packages/Core/Sources/Core/Platform/MapLaunch.swift` (03.7's file, not present on the tree at spec-writing
  time) — this task does not call `MapFacade.checkHere`; it consumes the `DiagnosisEvent` value that call
  produces, as a plain constructed-in-tests fixture. No edit.
- `Packages/Core/Tests/CoreTests/ErrorRegistryTests.swift`,
  `Packages/Core/Tests/CoreTests/ErrorRegistryNegativeControlTests.swift` — both already iterate
  `CoreError.allCases` generically; the new case is covered automatically with no edit (03.3 precedent).
- `contracts/**`, `docs/**`, `data/demo/**`, `App/**` — read-only inputs to this task.
- Door B façade (Start expedition, answer, continue, retry, end/abandon, `misses` assembly from the
  D27 hand-off) — task 04.4, not this task. This task's `start` takes `misses`/`shownItemIdsInRun` as
  caller-supplied parameters, exactly as `DiagnosisRun.start` already does; it builds neither.
- Any App/Sources file, any persistence (`StudentStateStore.write` or equivalent) — task 04.5, not this task.
  Nothing in this task's scope writes to disk.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` — heading `## 4. Diagnosis (Door A)` (re-read, byte-compared this run,
  `contracts/interaction-contract.md:76-99`):
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

  Binds this task: the façade must implement these transitions and content over `DiagnosisRun`'s output, and
  the Properties paragraph is this task's own conformance test set (§5 T4).

- `contracts/error-codes.json` — `DIAG_*` and `LO_HINT_NOT_FOUND` entries (re-read, byte-compared this run
  against the file on disk):
  > `{"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."}`
  > `{"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."}`
  > `{"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."}`
  > `{"code": "LO_HINT_NOT_FOUND", "recoverable": true, "surface": "internal", "user_text": null}`

  Binds this task: terminal lines for `DIAG_NO_PREREQUISITE`/`DIAG_PROBE_UNAVAILABLE` come from
  `CoreErrorText.text(for:)`; `DIAG_STATE_WRITE_FAILED` is out of this task's scope (04.5 raises it, not this
  façade — this task writes no state). `LO_HINT_NOT_FOUND` is raised as internal data only by this task's
  `resolveHint`, never thrown, never shown.

- **Quote-fidelity correction to the context bundle.** The bundle's §B quotes
  `contracts/domain-glossary.md:42` as if the following were the file's *current* text:
  > **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus one tier-1 hint (DEMO-BRIEF §3.6).

  This run re-read `contracts/domain-glossary.md` on disk: the file's **current** (v1.0.0) Remediation line
  (`:43`) reads only `"**Remediation** — one Explanation or WorkedExample for a confirmed candidate."`, with no
  paraphrase/hint fallback clause — the bundle's quote does not byte-match the file on disk. The text the
  bundle quoted is in fact `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 5's *replacement*
  glossary sentence, landed by task 04.1 (a dependency of this task) as v1.0.1 — and even there the bundle
  dropped a clause. The byte-verified Rule 5 text (re-read this run,
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:115`) is:
  > **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries
  > neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6).

  Binds this task: because 04.1 lands before this task runs (it is a `depends_on` precondition), the glossary
  will read v1.0.1 with the text above by the time this task executes; `selectRemediation` (AC6) implements it
  exactly, including the "when one resolves" clause (the hint is omitted, not shown as an empty string, when
  `resolveHint` returns `resolvedKey == nil`).

- `contracts/content-policy.md` — heading `## Voice` (re-read, byte-compared this run,
  `contracts/content-policy.md:53-54`):
  > - Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student
  >   surfaces

  Binds this task: no field on any screen-content type here carries a score, a fraction or a percentage.

Prior signatures this task builds on (verbatim, re-read against the current tree this run):

- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift` (full public surface this task calls):
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
  public enum ProbeOutcome: Equatable { case refuted, confirmed, declined, unavailable }
  public struct DiagnosisProbeResult: Equatable {
      public let outcome: ProbeOutcome
      public let results: [ItemResult]
      public let misses: [ItemMiss]
      public let code: CoreError?
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
  public struct DiagnosisContext: Equatable {
      public let event: DiagnosisEvent
      public let level: Int
      public let depthReached: Int
      public let originErrorTypeId: String
      public let shownItemIdsInRun: Set<String>
      public let blockedNodeIds: [String]
      public let probeResults: [ItemResult]
      public let events: [CoreEvent]
  }
  public struct ProbeOffer: Equatable { public let context: DiagnosisContext; public let candidateId: String }
  public struct ProbeInProgress: Equatable {
      public let context: DiagnosisContext
      public let candidateId: String
      public let items: [ProbeItem]
      public let levelResults: [ItemResult]
      let misses: [ItemMiss]
      public var currentItem: ProbeItem { items[levelResults.count] }
  }
  public struct FurtherLevelOffer: Equatable {
      public let context: DiagnosisContext
      public let candidateId: String
      let misses: [ItemMiss]
  }
  public enum DiagnosisStep: Equatable {
      case probeOffer(ProbeOffer)
      case probeItem(ProbeInProgress)
      case furtherLevelOffer(FurtherLevelOffer)
      case returned(DiagnosisOutcome)
  }
  public struct DiagnosisAdvance: Equatable {
      public let step: DiagnosisStep
      public let state: StudentState
      public let events: [CoreEvent]
      public let itemResult: ItemResult?
      public let probeResult: DiagnosisProbeResult?
  }
  public enum DiagnosisRun {
      public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent
      public static func start(
          event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
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
      // Internal helpers (module-visible, never public): classify, hypothesise, drawProbeItems, offered,
      // remediate, capped, hintKey, terminal, updatedContext.
      static func hintKey(originNode: Node, errorTypeId: String) -> String?
  }
  ```
  `hintKey` resolution order (doc comment, verbatim): "`errorTypeId`, when it resolves on the origin's
  `hintTree`; else the catalogue id `"none-of-these"`, when that resolves; else `nil`. Never returns the
  classify outcome token `"none_of_these"` and never substitutes another error type's key
  (`tasks/arbitration/arbiter-02-none-of-these.md`)."

- `Packages/Core/Sources/Core/Diagnosis/Classify.swift` (full file, re-read this run):
  ```swift
  public struct ItemMiss: Equatable {
      public let item: ProbeItem
      public let submittedValue: String
      public init(item: ProbeItem, submittedValue: String)
  }
  public enum Classify {
      public static func classify(_ misses: [ItemMiss]) -> String
  }
  ```

- `tasks/epic-04-task-02-core-door-item-card-keypad.md` §4 items 2–3 (04.2's landed shape this task calls):
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
  04.2's own §6 decision default: "IF the Door A façade (task 04.3) needs probe-item screen content ... THEN
  it calls `DoorItemContent(nodeId: probeInProgress.candidateId, item: probeInProgress.currentItem, isRetry:
  false)` using this task's public, primitive-typed initializer" — this task follows that default exactly.

- `tasks/epic-03-task-03-core-error-surface-text-mirror.md` §4.2 (03.3's specified, not-yet-landed shape —
  `CoreErrorText.swift` is absent from the tree this spec is written against; see §6):
  ```swift
  public enum CoreErrorText {
      public static let userText: [String: String]
      public static func text(for code: CoreError) -> String?
  }
  ```

- `tasks/epic-03-task-07-map-actions-facade-launch.md` (03.7's specified `checkHere`, not-yet-landed — the
  fixture this task's `map_check_here` tests construct by hand, since 03.7's own file is out of scope here):
  ```swift
  public static func checkHere(
      nodeId: String, mapState: MapState
  ) -> (event: DiagnosisEvent, events: [CoreEvent])
  // = (DiagnosisRun.open(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1), [.mapCheckHereRequested])
  ```

- `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` — Rule 2's exact resolution table (re-read,
  byte-compared this run, `:46-52`):
  > Let `expected` = `"none-of-these"` if the token is the outcome token `"none_of_these"`, else the token
  > itself. Then:
  >
  > | Case | Prose | `internalCode` |
  > |---|---|---|
  > | key == `expected` | `node.hintTree[key]![0]` | nil |
  > | key ≠ nil, key ≠ `expected` (a classified type had no entry, so the none-of-these branch served) |
  > `node.hintTree[key]![0]` | `.loHintNotFound` |
  > | key == nil | `node.paraphrase` | `.loHintNotFound` |

  Binds this task: `resolveHint` (AC5) is exactly this table.

Facts confirmed absent (re-run this run):

- No `Door/` file besides 04.2's `DoorItemContent.swift` exists under `Packages/Core/Sources/Core/`.
- No hypothesis card, probe orchestration, remediation selector, hint resolver or terminal-line constants
  exist anywhere in `Packages/Core/Sources`.
- `Packages/Core/Sources/Core/CoreErrorText.swift` and `Packages/Core/Sources/Core/Platform/MapLaunch.swift`
  are absent from the tree used to write this spec — EPIC 03 has not merged into it. Both are `depends_on`
  preconditions this task's implementer must confirm landed (via the branch merge, per the dispatch
  instructions) before starting; if either is still absent, BLOCK on the precondition rather than stubbing it.
- `Packages/Core/Sources/Core/CoreError.swift` currently ends at `case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"`
  (17 cases) on the tree used to write this spec; 03.3 (a precondition of EPIC 03 merging) adds three more
  (`platformStateUnreadable`, `platformStateWriteFailed`, `platformSnapshotRefused`) before this task runs —
  see §6 for the exact insertion point this implies.

## §4 Implementation outline

1. **Layer.** Both new files sit in layer ④ interaction (Door A screen content and flow), composing layer ③
   learning-objects data already carried on `Node`/`ProbeItem` (via `DiagnosisRun`'s already-validated output)
   and layer ② graph data (candidate ids, already resolved by `DiagnosisRun`'s prerequisite query). Neither
   file performs I/O or reads the system clock except through the caller-supplied `CalendarDay` it forwards
   unchanged to `DiagnosisRun.answerProbeItem`.

2. **`DiagnosisContent.swift` — screen-content value types and Door copy.**
   ```swift
   import Foundation

   public enum DoorADiagnosisCopy {
       public static let costLine = "Two quick checks, about a minute."
       public static let refutedLine = "Not the issue — back to where you were"
       public static let cappedLine = "further upstream — it's on your map"
       public static let furtherLevelQuestion = "want to look one step further upstream?"
       public static func hypothesisLine(candidateNodeName: String) -> String {
           "This may be blocked by **\(candidateNodeName)**"
       }
   }

   public struct DoorAHypothesisContent: Equatable {
       public let line: String       // DoorADiagnosisCopy.hypothesisLine(candidateNodeName:)
       public let costLine: String   // DoorADiagnosisCopy.costLine
   }

   /// `internalCode` is data only (`LO_HINT_NOT_FOUND`); never rendered, never thrown
   /// (arbiter-04-hint-fallback-reconciliation Rule 2).
   public struct DoorAHintContent: Equatable {
       public let nodeId: String
       public let prose: String
       public let resolvedKey: String?
       public let internalCode: CoreError?
   }

   /// Priority order per the domain-glossary v1.0.1 Remediation sentence (§3): explanation, else worked
   /// example, else paraphrase with an optional hint. Never an empty case — `paraphrase` is schema-required.
   public enum DoorARemediationContent: Equatable {
       case explanation(String)
       case workedExample(WorkedExample)
       case paraphrase(String, hint: String?)
   }

   public struct DoorAFurtherLevelOfferContent: Equatable {
       public let candidateNodeName: String
       public let question: String   // DoorADiagnosisCopy.furtherLevelQuestion
   }

   /// `remediation` is non-nil iff this terminal followed a `confirmed` probe on the *same* façade call
   /// (`.confirmed`/`.capped` reached from `answerProbeItem`); it is nil when reached from
   /// `decideFurtherLevel`'s decline branch, where remediation was already shown on the preceding
   /// `furtherLevelOffer` screen (never shown twice). `hint` is non-nil iff `outcome.hintNodeId != nil`
   /// (`.refuted`, `.unconfirmed`, `.noPrerequisite`).
   public struct DoorATerminalContent: Equatable {
       public let terminal: DiagnosisTerminal
       public let line: String?
       public let hint: DoorAHintContent?
       public let remediation: DoorARemediationContent?
       public let outcome: DiagnosisOutcome
   }

   /// The Door A screen a caller renders after one façade call. `probeItem`/`furtherLevelOffer`/`hypothesis`
   /// carry the raw `DiagnosisRun` phase value the caller must pass, unmodified, into the matching
   /// `DoorADiagnosisFlow` entry point — never constructed by the caller (no public initializer exists on
   /// any of `ProbeOffer`/`ProbeInProgress`/`FurtherLevelOffer`, arbiter-02-11-stepwise-api Ruling 2).
   public enum DoorADiagnosisScreen: Equatable {
       case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
       case probeItem(content: DoorItemContent, probe: ProbeInProgress)
       case furtherLevelOffer(
           remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent, decision: FurtherLevelOffer)
       case terminal(DoorATerminalContent)
   }
   ```

3. **Hint resolver (AC5).**
   ```swift
   enum DoorADiagnosisContentBuilder {
       /// Rule 2 of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` (§3), verbatim. Calls
       /// `DiagnosisRun.hintKey` in-module (it is internal, not private) — nothing is reimplemented.
       static func resolveHint(node: Node, classifiedToken: String) -> DoorAHintContent {
           let key = DiagnosisRun.hintKey(originNode: node, errorTypeId: classifiedToken)
           let expected = classifiedToken == "none_of_these" ? "none-of-these" : classifiedToken
           switch key {
           case .some(let k) where k == expected:
               // `hintKey` only returns a key whose `hintTree` entry is non-empty, so this force-unwrap is
               // safe by the callee's own contract.
               return DoorAHintContent(
                   nodeId: node.id, prose: node.hintTree[k]![0], resolvedKey: k, internalCode: nil)
           case .some(let k):
               return DoorAHintContent(
                   nodeId: node.id, prose: node.hintTree[k]![0], resolvedKey: k,
                   internalCode: .loHintNotFound)
           case .none:
               return DoorAHintContent(
                   nodeId: node.id, prose: node.paraphrase, resolvedKey: nil,
                   internalCode: .loHintNotFound)
           }
       }

       /// Domain-glossary v1.0.1 Remediation (§3). `probeResult` is the caller's already-checked confirmed
       /// result; its `misses` classifies the remediation's own hint, never the origin's.
       static func selectRemediation(candidate: Node, misses: [ItemMiss])
           -> DoorARemediationContent
       {
           if let explanation = candidate.explanation, !explanation.isEmpty {
               return .explanation(explanation)
           }
           if let example = candidate.workedExamples?.first {
               return .workedExample(example)
           }
           let classifiedToken = Classify.classify(misses)
           let hint = resolveHint(node: candidate, classifiedToken: classifiedToken)
           return .paraphrase(candidate.paraphrase, hint: hint.resolvedKey != nil ? hint.prose : nil)
       }
   }
   ```

4. **`DiagnosisFlow.swift` — the façade.**
   ```swift
   import Foundation

   /// Returned by every façade call except `answerProbeItem`/`continueAfterProbeAnswer`.
   public struct DoorADiagnosisAdvance: Equatable {
       public let screen: DoorADiagnosisScreen
       public let state: StudentState
       public let events: [CoreEvent]
   }

   /// Returned by `answerProbeItem` (I3): the just-answered item's card only. `pendingAdvance` and
   /// `classifiedToken` carry no `public` modifier, so no field of this type yields the next screen — only
   /// `DoorADiagnosisFlow.continueAfterProbeAnswer` does, and it changes no `StudentState`.
   public struct DoorAProbeAnswerAdvance: Equatable {
       public let answerCard: DoorAnswerCardContent
       public let itemResult: ItemResult
       public let state: StudentState
       public let events: [CoreEvent]
       let pendingAdvance: DiagnosisAdvance
       let classifiedToken: String
   }

   public enum DoorADiagnosisFlow {
       public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int)
           -> DiagnosisEvent
       {
           DiagnosisRun.open(originNodeId: originNodeId, trigger: trigger, levelBudget: levelBudget)
       }

       public static func start(
           event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
           state: StudentState, bundle: ContentBundle
       ) -> DoorADiagnosisAdvance {
           let advance = DiagnosisRun.start(
               event: event, misses: misses, shownItemIdsInRun: shownItemIdsInRun,
               state: state, bundle: bundle)
           let classifiedToken = Classify.classify(misses)
           return DoorADiagnosisAdvance(
               screen: screen(for: advance, classifiedToken: classifiedToken, bundle: bundle),
               state: advance.state, events: advance.events)
       }

       public static func decideProbe(
           _ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle
       ) -> DoorADiagnosisAdvance {
           let advance = DiagnosisRun.decideProbe(offer, accept: accept, state: state, bundle: bundle)
           return DoorADiagnosisAdvance(
               screen: screen(
                   for: advance, classifiedToken: offer.context.originErrorTypeId, bundle: bundle),
               state: advance.state, events: advance.events)
       }

       public static func answerProbeItem(
           _ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
           today: CalendarDay
       ) -> DoorAProbeAnswerAdvance {
           let advance = DiagnosisRun.answerProbeItem(
               probe, submitted: submitted, state: state, bundle: bundle, today: today)
           guard let itemResult = advance.itemResult else {
               preconditionFailure(
                   "DoorADiagnosisFlow.answerProbeItem: DiagnosisRun.answerProbeItem returned no itemResult")
           }
           let answerCard = DoorAnswerCardContent(result: itemResult, itemType: probe.currentItem.type)
           return DoorAProbeAnswerAdvance(
               answerCard: answerCard, itemResult: itemResult, state: advance.state,
               events: advance.events, pendingAdvance: advance,
               classifiedToken: probe.context.originErrorTypeId)
       }

       public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, bundle: ContentBundle)
           -> DoorADiagnosisScreen
       {
           screen(for: pending.pendingAdvance, classifiedToken: pending.classifiedToken, bundle: bundle)
       }

       public static func decideFurtherLevel(
           _ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle
       ) -> DoorADiagnosisAdvance {
           let advance = DiagnosisRun.decideFurtherLevel(offer, accept: accept, state: state, bundle: bundle)
           return DoorADiagnosisAdvance(
               screen: screen(
                   for: advance, classifiedToken: offer.context.originErrorTypeId, bundle: bundle),
               state: advance.state, events: advance.events)
       }

       // MARK: - Screen derivation (private: never called except from the entry points above)

       private static func screen(
           for advance: DiagnosisAdvance, classifiedToken: String, bundle: ContentBundle
       ) -> DoorADiagnosisScreen {
           switch advance.step {
           case .probeOffer(let offer):
               let name = nodeName(offer.candidateId, bundle: bundle)
               return .hypothesis(
                   content: DoorAHypothesisContent(
                       line: DoorADiagnosisCopy.hypothesisLine(candidateNodeName: name),
                       costLine: DoorADiagnosisCopy.costLine),
                   offer: offer)
           case .probeItem(let probe):
               let content = DoorItemContent(nodeId: probe.candidateId, item: probe.currentItem, isRetry: false)
               return .probeItem(content: content, probe: probe)
           case .furtherLevelOffer(let offer):
               let candidate = node(offer.candidateId, bundle: bundle)
               let remediation = DoorADiagnosisContentBuilder.selectRemediation(
                   candidate: candidate, misses: offer.misses)
               let offerContent = DoorAFurtherLevelOfferContent(
                   candidateNodeName: candidate.name, question: DoorADiagnosisCopy.furtherLevelQuestion)
               return .furtherLevelOffer(remediation: remediation, offer: offerContent, decision: offer)
           case .returned(let outcome):
               return .terminal(
                   terminalContent(
                       outcome: outcome, advance: advance, classifiedToken: classifiedToken, bundle: bundle))
           }
       }

       private static func terminalContent(
           outcome: DiagnosisOutcome, advance: DiagnosisAdvance, classifiedToken: String,
           bundle: ContentBundle
       ) -> DoorATerminalContent {
           let hint: DoorAHintContent? = outcome.hintNodeId.map {
               DoorADiagnosisContentBuilder.resolveHint(
                   node: node($0, bundle: bundle), classifiedToken: classifiedToken)
           }
           let remediation: DoorARemediationContent? = {
               guard let probeResult = advance.probeResult, probeResult.outcome == .confirmed,
                   let candidateId = probeResult.results.first?.nodeId
               else { return nil }
               return DoorADiagnosisContentBuilder.selectRemediation(
                   candidate: node(candidateId, bundle: bundle),
                   misses: probeResult.misses)
           }()
           let line: String? = {
               switch outcome.terminal {
               case .refuted: return DoorADiagnosisCopy.refutedLine
               case .capped: return DoorADiagnosisCopy.cappedLine
               case .noPrerequisite: return CoreErrorText.text(for: .diagNoPrerequisite)
               case .unconfirmed: return outcome.code.flatMap { CoreErrorText.text(for: $0) }
               case .confirmed: return nil
               }
           }()
           return DoorATerminalContent(
               terminal: outcome.terminal, line: line, hint: hint, remediation: remediation, outcome: outcome)
       }

       private static func node(_ id: String, bundle: ContentBundle) -> Node {
           guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
               preconditionFailure("DoorADiagnosisFlow: node \(id) not found in bundle")
           }
           return match
       }

       private static func nodeName(_ id: String, bundle: ContentBundle) -> String {
           node(id, bundle: bundle).name
       }
   }
   ```

5. **Boundary schema(s).** None: this file parses no untrusted external input. Its inputs (`DiagnosisEvent`,
   the phase types, `ItemResult`, `StudentState`, `ContentBundle`) are already-decoded, already-validated
   `Core` types; raw bundle/state JSON validation happens in `BundleIO`/`StudentStateStore`, out of scope
   here.

6. **Error codes.** `LO_HINT_NOT_FOUND` (`CoreError.loHintNotFound`) is produced only as `DoorAHintContent.internalCode`
   data — never thrown, never rendered (`contracts/error-codes.md` § Rules: "Internal codes never reach a
   student surface"). No function in this file throws.

7. **Model-calling path.** None anywhere in this file (I2): every function is a pure transformation over
   `DiagnosisRun`'s already-Tier-0 output plus bundle lookups. No adapter type, no confidence threshold, no
   Tier-1 fallback applies here.

8. Smoke check: `swift build --package-path Packages/Core` — must be green.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: the AC2 full-run scenarios (both triggers) over real `data/demo`, plus AC5's real-data hint
  resolution and AC6's real-data remediation selection, all driven only through `DoorADiagnosisFlow`'s six
  entry points.
- T2 negative — invalid input rejected at the boundary: this file parses no untrusted external input (§4 item
  5); the applicable defensive case is a `submitted` string that fails `ItemChecker`'s numeric grammar (e.g.
  `"abc"`) — `answerProbeItem` still returns a well-formed `DoorAProbeAnswerAdvance` with `answerCard.correct
  == false`, never a crash (mirrors 04.2 T2's shape).
- T3 error-taxonomy: `CoreError.loHintNotFound.rawValue == "LO_HINT_NOT_FOUND"`; `ErrorRegistryTests`/
  `ErrorRegistryNegativeControlTests` (both unmodified) stay green (AC9); `internalCode` is exactly
  `.loHintNotFound` on Rule 2's two fallback rows and exactly `nil` on its exact-match row (AC5).
- T4 conformance per requirements §B.1 and the invariants of §1:
  - interaction-contract § 4 Properties, each asserted directly: depth ≤ 2 from origin
    (`outcome.depthReached <= event.levelBudget`, with `levelBudget == 1` in every Demo-budget test); every
    capped or failed candidate is `blocked` in the returned `state.nodes`; no `DoorATerminalContent.remediation`
    is non-nil unless `advance.probeResult?.outcome == .confirmed` (no path reaches remediation without a
    `fail` probe outcome); AC3's I3 gate (no already-answered item's card is skippable); Tier 0 completes every
    path (AC8's I2 grep).
  - I4: AC4, on both real `data/demo` and the synthetic deeper-prerequisite graph.
  - I5: a `Mirror`-based scan over `DoorATerminalContent`, `DoorAHintContent`, `DoorARemediationContent` and
    `DoorAHypothesisContent` finds no field name matching a student/device/install/session identifier pattern
    (empty pool = FAIL), mirroring 04.2 AC2's shape (no dedicated negative control needed here beyond 04.2's
    own, since this task introduces no new identifier-shaped field).
- T5 negative control for every regression guard:
  - AC7's two hint-resolver negative controls (empty prose; sibling-type substitution for the outcome token),
    reconstructed locally inside the test file, never touching `DiagnosisContent.swift`.
  - AC8's I2 grep: a planted local string containing `"FoundationModels"` (never added to product code) proves
    the pattern match fires; the grep first asserts both scanned files are non-empty (found), so a
    missing-file typo cannot vacuously pass.
  - AC3's I3 guard: a source scan of `DiagnosisFlow.swift` asserts the `DoorAProbeAnswerAdvance` declaration
    lines for `pendingAdvance` and `classifiedToken` do not begin with `public let` (both must read plain
    `let`); a planted local copy of the struct with `public let pendingAdvance` proves the same scan pattern
    catches it.
- T6 idempotency / no-leak: `continueAfterProbeAnswer` called twice on the same `Equatable`-equal
  `DoorAProbeAnswerAdvance` returns `Equatable`-equal `DoorADiagnosisScreen` values and (structurally, by its
  return type) produces no `StudentState`/`[CoreEvent]`; none of the six façade entry points mutates its
  `StudentState`/bundle/phase-value argument (all are `let`-only value types passed by value — assert once per
  entry point as a documentation-carrying test, per the `Equatable` conformance already declared, mirroring
  04.2 T6's shape).

## §6 Decision defaults

- IF the `CoreError.swift` case list on the tree at implementation time still ends at
  `mapMarkerOffTrail` (17 cases, the state confirmed this run — before 03.3 has landed) THEN this is the
  03.3/EPIC-03-merge precondition failing to hold — BLOCK and report it, per §2's out-of-scope note; do not
  implement against a stale case list. IF (the expected state once EPIC 03 has merged, since this task
  `depends_on` implies 04.1/04.1b/04.2 which in turn require EPIC 03 merged per the dispatch instructions) the
  list ends at `platformSnapshotRefused` (20 cases, 03.3's three additions appended after the original 17)
  THEN append `case loHintNotFound = "LO_HINT_NOT_FOUND"` immediately after `platformSnapshotRefused`, for 21
  cases total, with every prior case byte-unchanged and in order. (Context-bundle correction: the bundle's §F
  says "add ... after the existing 17 cases", which was true only of the pre-EPIC-03 tree this bundle was
  compiled against; the insertion point at this task's actual runtime is after whichever case is last at that
  time, per this default — the count is the material fact to verify, not the specific prior case name.)
- IF the existing `PropertyGen.swift` fixtures (`probeableNode`, `smallLayeredGraphWithProbeItems`,
  `diagnosisLevelDecision(s)`, `minimalNode`, `minimalEdge`) already suffice to construct AC4's synthetic
  deeper-prerequisite graph and any other fixture this task's tests need THEN append nothing to
  `PropertyGen.swift` and leave it untouched (surgical changes — RULE 3); only append a new function there,
  under a new `// MARK: - 04.3 additions` comment, if a genuinely new generator shape is needed that a
  `DiagnosisFlowTests.swift`-local private helper cannot reasonably express (e.g., a reusable node/graph
  builder a future task would otherwise duplicate) — the bar is the same "second real consumer" rule
  `CLAUDE.md` RULE 2 states generally.
- IF there is no ratified copy string for the `.unconfirmed` terminal reached by decline (`outcome.code ==
  nil`) or for a plain `.confirmed` terminal (no further offer, or `decideFurtherLevel` declined) THEN
  `DoorATerminalContent.line` is `nil` for both — no banner text beyond the hint (declined-unconfirmed) or the
  already-shown remediation (confirmed) is shown. This is a genuine content gap in the DEMO-BRIEF/domain-doc
  ground truth (only `refuted`, `capped`, `DIAG_NO_PREREQUISITE` and `DIAG_PROBE_UNAVAILABLE` have prescribed
  text anywhere in the cited sources), so `nil` is the conservative default — it adds no unratified copy
  rather than inventing a line no contract or ruling specifies.
- IF a render layer (a later App task) needs to reach the next Door A screen without an explicit continue
  call THEN it cannot: `DoorAProbeAnswerAdvance`'s `pendingAdvance`/`classifiedToken` fields carry no `public`
  modifier (module-internal), so no field of the value `answerProbeItem` returns yields a
  `DoorADiagnosisScreen` or a raw `DiagnosisAdvance` outside `Core` — only `continueAfterProbeAnswer` does,
  mirroring arbiter-02-11-stepwise-api Ruling 2's "no public initializer" pattern applied here at field level
  instead of at the type level (the type itself must still be `public` so the App can hold and pass it back).
- IF `DoorARemediationContent.paraphrase(_, hint:)`'s hint text is present (non-nil) THEN its
  `internalCode` is discarded, never carried on `DoorARemediationContent` itself — remediation has no "show an
  internal-code banner" concern distinct from the hint-presence boolean already encoded by `hint == nil` vs.
  `hint != nil`; only `DoorAHintContent` (used directly for terminal hints) carries `internalCode`, per AC5's
  scope.
- IF a future task needs `DoorADiagnosisContentBuilder`'s functions directly (rather than through
  `DoorADiagnosisFlow`) THEN it may call them — they are declared at file scope with `internal` (default)
  access inside `DiagnosisContent.swift`, not nested inside `DoorADiagnosisFlow`, specifically so 04.4's D27
  hand-off code (which calls into this façade's `start`, not these builder functions directly) and this task's
  own tests can both reach them without a second implementation.

Standing defaults: identifiers here are the already-validated node/item id strings threaded through
unchanged, never re-validated or re-generated (`contracts/data-model.md` § Identifiers, unchanged by this
task); no model call anywhere in this file (Tier 0 only, I2); no telemetry client in this file; no field here
identifies a student, device, install or session (I5); Ministry text is never introduced — every string this
file surfaces is the node's own `paraphrase`/`explanation`/`workedExamples`/`hint_tree` content or a fixed
`Core`-authored Door copy string (I6).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`)
- typecheck clean — Swift's typecheck is the build; N/A for Python (this task touches no `pipeline/`)
- `Core` build + test green (`swift build --package-path Packages/Core`; `xcodebuild test -scheme
  Core-Package` on the simulator)
- App build: N/A — this task does not touch `App/Sources`
- tests green for the cases in §5
- `ErrorRegistryTests` and `ErrorRegistryNegativeControlTests` stay green with no edit to either file (AC9)
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 4;
  `contracts/error-codes.json`'s `DIAG_*`/`LO_HINT_NOT_FOUND` entries; `contracts/content-policy.md` § Voice;
  `contracts/domain-glossary.md` v1.0.1 Remediation, as landed by task 04.1) and to every invariant listed in
  §1 (I1, I2, I3, I4, I5, I6, I14)

# Epic 04 · Task 09: App diagnosis screens (Door A render layer)

---
epic: 04
task: 09
slug: app-diagnosis-screens
kind: feat
risk: seam
depends_on: [04.8]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`; no `epic-04a-door-core` or
> `epic-04b-door-app` branch yet). The implementer runs this task on `epic-04b-door-app`, AFTER task **04.8**
> (`app-expedition-screens`) has landed on that same branch. By that time:
> - `App/Sources/Doors/ExpeditionItemView.swift`, `ExpeditionAnswerCardView.swift`, `DoorBViewState.swift`
>   exist exactly as `tasks/epic-04-task-08-app-expedition-screens.md` §4 describes (quoted verbatim §3
>   below), and `App/Sources/MapUI/MapActionsView.swift` / `App/Sources/Shell/AppShell.swift` carry 04.8's own
>   edits on top of 03.11's / 03.12's originals (also quoted verbatim §3, from 04.8's own already-written
>   spec, since neither file exists yet on the tree used to write this spec).
> - `Packages/Core/Sources/Core/Door/DiagnosisContent.swift` / `DiagnosisFlow.swift` (04.3) and the Door A
>   half of `Packages/Core/Sources/Core/Platform/MapLaunch.swift`'s `DoorFacade` (04.5) exist exactly as
>   `tasks/epic-04-task-03-core-door-a-diagnosis-flow.md` §4 and `tasks/epic-04-task-05-core-door-entries-
>   persistence-seam.md` §4 describe (quoted verbatim §3).
> - `contracts/domain-glossary.md` reads v1.0.1 (04.1's Rule 5 text) and `docs/domains/diagnosis.md` §
>   Core entities' Remediation sentence reads the Rule 5 replacement text (both quoted §3 in their
>   post-04.1 form, since the tree used to write this spec still shows the pre-04.1 text).
>
> If any of the above is absent, or its public surface differs from the signatures quoted §3, that is an
> EPIC-order precondition failing to hold — BLOCK and report it; do not stub, re-derive or reimplement any of
> 04.3's, 04.5's, 04.8's, 03.11's or 03.12's logic here.
>
> **Quote-fidelity corrections to the compiled context bundle (`tasks/context/epic-04-task-09-context.md`).**
> Two of the bundle's §D/§F claims do not byte-match their sources, re-verified this session:
> 1. The bundle's §D "From 04.5" list names an entry point `startDiagnosis`. No such entry exists.
>    `tasks/epic-04-task-05-*.md` §4.4 (re-read this session) names exactly six Door A `DoorFacade` entries:
>    `checkHere`, `decideProbe`, `answerProbeItem`, `continueAfterProbeAnswer`, `decideFurtherLevel`,
>    `resumeAfterDiagnosis`. `checkHere` alone opens **and** starts the event (it calls `MapFacade.checkHere`
>    then `DoorADiagnosisFlow.start` in one call) — there is no separate "start" entry for the App to call.
> 2. The bundle's §F proposes CREATE paths under `App/Sources/Door/` (singular) with six files, including a
>    dedicated `ProbeView.swift`, `FurtherLevelOfferView.swift`, `TerminalView.swift` and `HintView.swift`.
>    04.8's own, already-written spec (§2, re-read this session) puts the Door B render layer at
>    `App/Sources/Doors/` (**plural**), and probe items are rendered by reusing 04.8's own
>    `ExpeditionItemView`/`ExpeditionAnswerCardView` (a `DoorADiagnosisScreen.probeItem` case carries the same
>    `DoorItemContent` type Door B uses — 04.3 §4 step 2, quoted §3). This spec's own dispatch scope (the
>    task-request that produced this file) narrows the new-file list to three files under `App/Sources/Doors/`
>    (plural) plus the reused item view; that narrower, more recent scope is followed here, and the bundle
>    should be regenerated before it is reused for a sibling task.

## §1 Goal & acceptance criteria

Goal: ship the render-only Door A (diagnosis) screens — the hypothesis card, the probe (reusing 04.8's item
view and answer card), the further-level offer, the terminal line/hint, and the remediation piece they share —
as pure functions of 04.3's already-computed `DoorADiagnosisScreen`/`DoorAProbeAnswerAdvance` values, driven
only through 04.5's `DoorFacade` Door A entries. This task also rewires "Check me here"
(`App/Sources/MapUI/MapActionsView.swift`'s `CheckHereActionButton`, currently a 03.11 stub calling
`MapFacade.checkHere` and handing off a bare `DiagnosisEvent`) to call `DoorFacade.checkHere` instead, and
extends `App/Sources/Shell/AppShell.swift`'s `DoorRunHolder`/`DoorBRunSnapshot`/`DoorBPhase`/`DoorBRunScreen`
machinery (04.8) to present Door A content for both triggers: the D27 hand-off from inside an expedition run
(`DoorBScreen.diagnosis(...)`, revealed by `continueAfterAnswer`), and a standalone `map_check_here` event
opened directly from the map. Both triggers reuse the identical presentation surface and identical Door A
views — no second, competing presentation mechanism is built. Every button in this task's scope calls exactly
one 04.5 `DoorFacade` entry, except the standalone terminal's "Continue", which needs none (04.5 AC8: no
`resumeAfterDiagnosis` call exists or is needed for a `map_check_here` event). Every content string on a Door A
screen is a value 04.3 already computed (`DoorAHypothesisContent`, `DoorARemediationContent`,
`DoorAHintContent.prose`, `DoorATerminalContent.line`, `DoorAFurtherLevelOfferContent`) or the resolved text of
a registered error code (03.3's `CoreErrorText`); no Door A content string is invented in `App/Sources`. This
task's own view files add a small, fixed set of chrome-only button labels ("Yes", "Not now", "Continue"), the
same category 04.8 already established for "Continue"/"Submit" (04.8 §4.6: "an App-authored chrome label with
no domain-noun collision").

**C3 exclusion (verbatim, `tasks/arbitration/arbiter-04-predispatch.md:387-395`).** This task's evidence is
logic, composition and static wiring only. It cannot and does not claim:
1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and
   keypad key → string binding at runtime;
2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are
   on screen);
3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only
   in `CoreTests`.

The literal tap-through is the owner's device verification (D29) — no line in this task's acceptance report
claims it.

Invariants in play:

- **I2** — Tier 0 only. No `FoundationModels`/adapter import anywhere in this task's App-side code; the
  hypothesis card's "what did you do?" line (Tier 1, EPIC 13) is out of scope and not built.
- **I3** — every probe answer is shown as an explicit `ExpeditionAnswerCardView` (reused from 04.8) that only
  an explicit continue tap replaces, via `DoorFacade.continueAfterProbeAnswer`; a terminal's hint/line/
  remediation is likewise shown before the one "Continue" control that returns; no App-local mutation ever
  advances past either.
- **I6** — no Ministry text anywhere in this task's scope. `RemediationView` renders only
  `DoorARemediationContent`'s already-`Core`-selected `.explanation`/`.workedExample`/`.paraphrase(_, hint:)`
  case; `DiagnosisReturnView` renders only `DoorAHintContent.prose` (never `.internalCode`, never a
  "no hint written" placeholder — 04.00.1/04.00.2, quoted §3) and `DoorATerminalContent.line`/`.remediation`.
- **I10** — the probe's only input is 04.8's numeric keypad or choice buttons (reused unmodified); no
  `TextField`, no OCR path, anywhere in this task's scope.
- **I14** — every file in this task's scope holds only presentation state or a plain provenance tag
  (`DoorBRunSnapshot.isStandaloneDiagnosis`, §4.6 — a record of *which hand-off opened this diagnosis event*,
  never a re-derivation of a `Core` fact); every state-changing action calls exactly one 04.5 `DoorFacade` entry
  point (or, for the standalone terminal's return, none — 04.5 AC8); no file constructs a `StudentState`, or calls
  `DoorADiagnosisFlow`, `DiagnosisRun`, `ExpeditionRun`, `Expedition`, `MasteryTransitions`, `MarkerTrail`,
  `L0Checker`, `BundleIO`, `BundleLoader`, `StudentStateStore` or `LayoutEngine` directly.
- **I5** — the one new field this task adds (`DoorBRunSnapshot.isStandaloneDiagnosis: Bool`) carries no
  identifying information; every other value this task's views render is a node id/enum/`String`/`Bool`
  04.3/04.5 already cleared, or a registered error-code string `CoreErrorText` resolves.

Acceptance criteria (each independently verifiable):

- AC1: `HypothesisCardView` renders, for a given `DoorAHypothesisContent`, `content.line` and `content.costLine`
  each as plain `Text` (no Markdown/attribute parsing is introduced anywhere in this task's scope, consistent
  with every prior `Core`-string render site in `App/Sources`), and exactly two buttons — "Yes" and "Not now" —
  whose taps call `onDecision(true)` / `onDecision(false)` respectively, exactly once each, and render no other
  actionable control.
- AC2: `RemediationView` renders, for a given `DoorARemediationContent`: `.explanation(text)` as plain `Text`;
  `.workedExample(example)` as one `MathView(latex:)` per `example.stepsLatex` entry, in order; `.paraphrase
  (text, hint:)` as plain `Text(text)` followed by `Text(hint)` only when `hint != nil`. No case renders an
  `internalCode`, a fraction, a percentage or a "no hint written"/placeholder string anywhere.
- AC3: `DiagnosisReturnView` renders its `.furtherLevelOffer(remediation:, offer:)` content as
  `RemediationView(content: remediation)` followed by `Text(offer.question)` and exactly two buttons ("Yes" /
  "Not now") whose taps call `onFurtherLevelDecision(true)` / `onFurtherLevelDecision(false)` exactly once
  each; it renders its `.terminal(content)` content as `Text(content.line)` when `content.line != nil`,
  `Text(content.hint!.prose)` when `content.hint != nil` (never `content.hint!.internalCode`),
  `RemediationView(content: content.remediation!)` when `content.remediation != nil`, and exactly one
  "Continue" control whose tap calls `onReturn()` exactly once; no scores, fractions or percentages appear on
  either branch (`contracts/content-policy.md` § Voice, quoted §3).
- AC4: `App/Sources/MapUI/MapActionsView.swift`'s `HandOffDestination` keeps exactly three cases —
  `.diagnosisStarted(DoorAStartOutcome)` (replacing 03.11's `.diagnosis(event: DiagnosisEvent)` case),
  `.doorBStarted(DoorBStartOutcome)` (04.8, unchanged), `.included(map: MapState)` (03.11, unchanged) — and
  `CheckHereActionButton`'s action calls `DoorFacade.checkHere(nodeId:, mapState:, today: AppShell
  .resolveToday())` exactly once and calls `handOff` exactly once with `.diagnosisStarted(DoorAStartOutcome
  (runState:, screen:, writeFailureCode:))` carrying that call's three values unchanged; `CheckHereActionButton`
  keeps its existing `(nodeId:, mapState:, handOff:)` initializer shape unchanged, so `NodePanelView.swift`'s
  (03.11) existing call site needs no edit and receives none.
- AC5: `App/Sources/Shell/AppShell.swift`'s `handOff` routes `.diagnosisStarted(let outcome)` into
  `doorHolder.replace(with: DoorBRunSnapshot(runState: outcome.runState, phase: .screen(.diagnosis(outcome
  .screen)), writeFailureCode: outcome.writeFailureCode, isStandaloneDiagnosis: true))`; every pre-existing
  `DoorBRunSnapshot(...)` construction site 04.8 wrote (`.doorBStarted`'s handler, `submit`, `continueTapped`,
  `startAnother` — named and quoted verbatim in §3's 04.8 §4.9 block) is updated to carry
  `isStandaloneDiagnosis: false`, with no other change to any of those four sites' logic. `DoorBRunSnapshot`'s
  field order is exactly `runState`, `phase`, `writeFailureCode`, `isStandaloneDiagnosis` (04.8 §4.9's three
  fields plus this task's one addition, appended last).
- AC6: Inside `DoorBRunScreen`, the new `.screen(.diagnosis(let screen))` case calls a new
  `diagnosisContent(for:current:)` that renders exactly one view per `DoorADiagnosisScreen` case — `.hypothesis`
  → `HypothesisCardView`; `.probeItem` → 04.8's `ExpeditionItemView` (unmodified initializer); `.furtherLevelOffer`
  → `DiagnosisReturnView(content: .furtherLevelOffer(...))`; `.terminal` → `DiagnosisReturnView(content:
  .terminal(...))` — and, above that switch, a write-failure banner (`Text`, sourced only from
  `current.writeFailureCode.flatMap { CoreError(rawValue: $0).flatMap(CoreErrorText.text(for:)) }`) shown only
  when non-`nil`. The new `.diagnosisAnswerCard(let advance)` `DoorBPhase` case (added to the existing enum)
  renders 04.8's `ExpeditionAnswerCardView(content: advance.answerCard)` with its continue control calling
  `continueAfterProbeAnswer`.
- AC7: Every state-changing action reachable from `diagnosisContent(for:current:)` calls exactly one `DoorFacade`
  Door A entry — `decideProbe` (hypothesis Yes/No), `answerProbeItem` (probe item submit), `continueAfterProbeAnswer`
  (probe answer card continue), `decideFurtherLevel` (further-level-offer Yes/No) — each threading
  `current.isStandaloneDiagnosis` unchanged into the `DoorBRunSnapshot` it constructs; no code path in this task's
  scope calls `DoorADiagnosisFlow` or `DiagnosisRun` directly.
- AC8: The terminal's "Continue" control (`returnFromDiagnosis`) branches only on `current.isStandaloneDiagnosis`
  (a diagnosis-event-origin tag fixed at hand-off time), never on `outcome.terminal` or any other
  `DiagnosisOutcome` field: when `false`, it calls `DoorFacade.resumeAfterDiagnosis(current.runState, outcome:,
  today:)` exactly once and replaces `doorHolder.current` with the resumed `DoorBScreen`; when `true`, it calls
  no `DoorFacade` entry, replaces `MapStateHolder.mapState` with `current.runState.map` (already the last state
  04.5's Door A calls persisted), and dismisses the presentation (clears `doorHolder.current`).
- AC9: The App builds green (gate 4, `scripts/gate.sh:22`) with every file in this task's scope compiled into
  the target via the synchronized `Sources` group (no `pbxproj` edit); the 03.9 `AppSourcesBoundary` scan
  (`xcodebuild test -scheme Core-Package`) stays green over the complete `App/Sources` tree, with **no**
  widening of `AppSourcesBoundary.allowedImportModules`/`defaultRules`/`forbiddenCoreTypeNames` by this task
  (§6 default 3 — mirrors 04.8's own §6 default 4 exactly: every call this task's code makes is to
  `DoorFacade.*`, `CoreErrorText.*`, `AppShell.resolveToday()` or `MathView.*`, none of which is on 03.9's
  forbidden-name list, and this task's imports are exactly `SwiftUI`, `Core`, `Rendering`, all three already
  allow-listed); `swift-format lint --strict` is clean on every file in this task's scope; a glossary grep over
  this task's scope (§5 T4) finds no banned synonym.
- AC10: No line in this task's acceptance report claims tap-level, screenshot-level or runtime-sequence
  correctness (the C3 exclusion above); every claim is either a build/scan/format gate result or a source-level
  inspection against an AC.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `App/Sources/Doors/HypothesisCardView.swift` — CREATE. Confirmed absent (`Glob **/HypothesisCardView.swift`
  returns no match at compile time of this spec). The hypothesis card: line, cost line, Yes/Not now.
- `App/Sources/Doors/RemediationView.swift` — CREATE. Confirmed absent. The one shared remediation-piece
  renderer (`DoorARemediationContent`'s three cases).
- `App/Sources/Doors/DiagnosisReturnView.swift` — CREATE. Confirmed absent. The further-level-offer decision
  and the terminal line/hint/remediation/return screen (`DoorADiagnosisScreen`'s `.furtherLevelOffer` and
  `.terminal` cases).
- `App/Sources/MapUI/MapActionsView.swift` — MODIFY (03.11's file, carrying 04.8's own edits by the time this
  task runs, per this spec's Branch note; shape quoted §3). Replace `HandOffDestination.diagnosis(event:
  DiagnosisEvent)` with `.diagnosisStarted(DoorAStartOutcome)` (a new `Equatable` struct added to this same
  file); rewire `CheckHereActionButton` to call `DoorFacade.checkHere` instead of `MapFacade.checkHere`.
- `App/Sources/Shell/AppShell.swift` — MODIFY (03.12's file, carrying 04.8's own edits by the time this task
  runs, per this spec's Branch note; shape quoted §3). Add `isStandaloneDiagnosis: Bool` to `DoorBRunSnapshot`; add
  `.diagnosisAnswerCard(DoorAProbeAnswerAdvance)` to `DoorBPhase`; update `handOff`'s `.diagnosisStarted`
  routing and every existing `DoorBRunSnapshot(...)` construction site's new field; extend `DoorBRunScreen
  .content(for:)` with the two new phase cases and add the private `diagnosisContent(for:current:)`,
  `decideProbe(_:accept:current:)`, `answerProbeItem(_:submitted:current:)`,
  `continueDiagnosisTapped(_:current:)`, `decideFurtherLevel(_:accept:current:)`,
  `returnFromDiagnosis(outcome:current:)` functions.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/**`, `Packages/Rendering/**` — read-only; call only `DoorFacade`'s, `CoreErrorText`'s and
  `MathView`'s public entry points, never a `Core`-internal flow type directly.
- `App/Sources/Doors/ExpeditionItemView.swift`, `ExpeditionAnswerCardView.swift`, `DoorBViewState.swift`,
  `NumericKeypadView.swift`, `ChoiceButtonsView.swift`, `ExpeditionSummaryView.swift` — 04.8's files; this task
  reuses `ExpeditionItemView`'s and `ExpeditionAnswerCardView`'s existing public initializers unchanged and
  edits none of these five files. No `App/Sources/Doors/ProbeView.swift` is created (04.3's own
  `DoorADiagnosisScreen.probeItem` case already carries a `DoorItemContent`, the same type 04.8's
  `ExpeditionItemView` already renders — a second, dedicated probe view would duplicate it).
- `App/Sources/MapUI/NodePanelView.swift`, `RegionPanelView.swift`, `LandmarkPanelView.swift`,
  `CoursePickerView.swift`, `UnitListPickerView.swift` — 03.11's remaining files; `CheckHereActionButton`'s
  initializer shape is unchanged by this task (AC4), so `NodePanelView.swift`'s existing call site needs no
  edit and none is made.
- `App/Sources/Shell/RefusalView.swift` — 03.12's file; untouched.
- `App/Sources/ContentView.swift`, `App/Sources/MathmathApp.swift` — 03.12's scope; `AppShell`'s own public
  shape (`AppShell()`, no init parameters) is unchanged by this task.
- `App/Sources/Map/MapCanvasView.swift`, `App/Sources/Map/MapCamera.swift` — 03.10's files; untouched.
- `App/Sources/DemoSnapshot/*.json` — 03.4's file; read-only, never hand-edited.
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift`,
  `AppSourcesBoundaryNegativeControlTests.swift` — 03.9's/03.12's files; this task's own code is written to
  pass the scan as it exists after 04.8's own no-widening compliance, unmodified by this task (§6 default 3 —
  no allow-list widening is needed or made here; that is 04.10's own, later scope).
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.
- Any file under `App/mathmath.xcodeproj/` — never edited; the synchronized `Sources` group covers new files.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` § 4 Diagnosis (Door A) (re-read, byte-compared this session,
  `contracts/interaction-contract.md:80-103`):
  > States: `opened → hypothesis → (probe | hint) → (remediation | hint) → returned`, with `capped` as a
  > terminal branch.
  >
  > - `open(origin, trigger ∈ {expedition_second_miss, map_check_here})`; `level = 0`; budget 2 (Demo: 1).
  > - `classify`: distractor-tag lookup over the failed items → `error_type` or `none_of_these` (diagnosis Q1);
  >   Tier 1 may *suggest* from the optional typed line (runtime-tiers), never decides.
  > - `hypothesise`: candidate = deepest unmastered prerequisite within remaining levels (graph query), biased
  >   by `implies_prerequisite`; none → `DIAG_NO_PREREQUISITE` → hint → returned.
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

  Binds AC1, AC3, AC6, AC7, AC8: this task's views render only what these transitions already produced; they
  decide none of them.

- `contracts/content-policy.md` § Voice (re-read, byte-compared this session,
  `contracts/content-policy.md:54-55` — the full sentence, not the truncated form the compiled context bundle
  carried):
  > - Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student
  >   surfaces; a node is named, the student never is (diagnosis §7 stance).

  Binds AC1, AC3: no field on any Door A screen in this task's scope carries a score, a fraction or a
  percentage; the hypothesis/terminal screens name the candidate node, never the student.

- `contracts/content-policy.md` § Grade 9–12 tier (re-read, byte-compared this session,
  `contracts/content-policy.md:8-10`):
  > A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field
  > anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate).

  Binds AC2: `RemediationView`'s `.paraphrase` case renders only `Node.paraphrase`/`Core`'s hint prose, never a
  Ministry-text field (none exists on `DoorARemediationContent`).

Domain-doc excerpts (verbatim, re-read this session):

- `docs/domains/diagnosis.md` § UI surfaces, `docs/domains/diagnosis.md:105-109`:
  > Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the
  > expedition item view); **Remediation** (W4, one explanation or worked example); return is implicit (W5).
  > Confirmed by the Demo.

  Binds AC6, §6 default 1: the probe reuses "the expedition item view" (04.8's `ExpeditionItemView`), never a
  dedicated probe view; "a sheet over the expedition or map" is realised, in this task's App-side design, by
  presenting Door A content inside the same `fullScreenCover` 04.8 already built for Door B (§6 default 1
  explains why this satisfies the domain doc's intent without a second presentation surface).

- `docs/domains/diagnosis.md` § W5 — Return, `docs/domains/diagnosis.md:82-86`:
  > **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control
  > back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may
  > re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:**
  > `diagnosis.returned`; the event is closed.

  Binds AC8: step 2's fork (suspended expedition vs. map node panel) is exactly the
  `isStandaloneDiagnosis`-branch this task's `returnFromDiagnosis` implements; step 1 is already done by the
  time the terminal screen renders (04.5's Door A calls already persisted the outcome).

- `docs/domains/diagnosis.md` § Core entities, Remediation, **post-04.1 text** (the Rule 5 replacement,
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:121`, re-read and byte-compared this session —
  the tree used to write this spec still carries the pre-04.1 sentence, per this spec's Branch note):
  > "one `Explanation` or `WorkedExample` from **learning-objects** — or, when the node carries neither, its
  > `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6) — then return."

  Binds AC2: `RemediationView` renders exactly these three cases, in this priority, as `DoorARemediationContent`
  already encodes it (04.3 AC6) — this task adds no new selection logic.

- `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 3 (re-read, byte-compared this session,
  `:56-60`):
  > Every hint slot shows the **origin node's `paraphrase`** in place of hint prose, with no label naming a
  > mistake. This applies to the refuted terminal, `DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`,
  > declined-`unconfirmed`, and the W1 abstention path.
  >
  > The slot is never blank and never shows a sibling type's hint. `LO_HINT_NOT_FOUND` never reaches the
  > screen (`contracts/error-codes.md` § Rules: "Internal codes never reach a student surface"). The
  > prototype's "No hint written for that exact mistake yet" banner (:33) is therefore **not** built.

  Binds AC2, AC3: `DoorAHintContent.prose` is always non-empty by the time this task's code sees it (04.3's own
  guarantee); this task's views render `prose` alone, never `internalCode`, and add no "no hint written" text
  anywhere.

Arbiter rulings (verbatim, re-read this session):

- `tasks/arbitration/arbiter-04-predispatch.md:387-395`, "What it cannot claim" (full text quoted §1 above,
  re-verified against the file this session). Binds this task's §1 C3 paragraph.

- `tasks/arbitration/arbiter-04-predispatch.md:232-236`, Q-D ruling:
  > CONFIRMED. The cost line reads exactly **`Two quick checks, about a minute.`** The word "check" is already
  > the registered student-facing name for the probe: `DIAG_PROBE_UNAVAILABLE`'s `user_text` is "No quick check
  > is available for this one yet; here's a hint instead." (`error-codes.json` line 21). The map's "Check me
  > here" uses it too. "Check" is not a banned synonym anywhere in the glossary. "question" is banned under
  > Item.

  Binds AC1: this task renders `DoorADiagnosisCopy.costLine` verbatim; it invents no cost-line text of its own.

Prior signatures this task builds on (verbatim, re-read against their own already-written specs and, where
present, the current tree, in this session):

```swift
// Packages/Core/Sources/Core/Door/DiagnosisContent.swift (04.3's spec §4 step 2, re-read and byte-compared)
public enum DoorADiagnosisCopy {
    public static let costLine = "Two quick checks, about a minute."
    public static let refutedLine = "Not the issue — back to where you were"
    public static let cappedLine = "further upstream — it's on your map"
    public static let furtherLevelQuestion = "want to look one step further upstream?"
    public static func hypothesisLine(candidateNodeName: String) -> String
}
public struct DoorAHypothesisContent: Equatable {
    public let line: String
    public let costLine: String
}
public struct DoorAHintContent: Equatable {
    public let nodeId: String
    public let prose: String
    public let resolvedKey: String?
    public let internalCode: CoreError?
}
public enum DoorARemediationContent: Equatable {
    case explanation(String)
    case workedExample(WorkedExample)
    case paraphrase(String, hint: String?)
}
public struct DoorAFurtherLevelOfferContent: Equatable {
    public let candidateNodeName: String
    public let question: String
}
public struct DoorATerminalContent: Equatable {
    public let terminal: DiagnosisTerminal
    public let line: String?
    public let hint: DoorAHintContent?
    public let remediation: DoorARemediationContent?
    public let outcome: DiagnosisOutcome
}
public enum DoorADiagnosisScreen: Equatable {
    case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
    case probeItem(content: DoorItemContent, probe: ProbeInProgress)
    case furtherLevelOffer(
        remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent, decision: FurtherLevelOffer)
    case terminal(DoorATerminalContent)
}
```

```swift
// Packages/Core/Sources/Core/Door/DiagnosisFlow.swift (04.3's spec §4 step 4, re-read and byte-compared)
public struct DoorADiagnosisAdvance: Equatable {
    public let screen: DoorADiagnosisScreen
    public let state: StudentState
    public let events: [CoreEvent]
}
public struct DoorAProbeAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let itemResult: ItemResult
    public let state: StudentState
    public let events: [CoreEvent]
    // pendingAdvance and classifiedToken are non-public (module-internal only)
}
```

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift:43-46 (current tree, re-read and byte-compared this session)
public struct WorkedExample: Codable, Equatable {
    public let id: String
    public let stepsLatex: [String]
}
```

```swift
// Packages/Core/Sources/Core/Platform/MapLaunch.swift (04.5's spec §4.1/§4.3/§4.4, re-read and byte-compared —
// the six Door A `DoorFacade` entries this task calls; there is no separate "start"/"open" entry the App calls)
public struct DoorRunState: Equatable {
    public let map: MapState
    let expedition: DoorBRunState?   // NOT public — Core-internal; the App holds DoorRunState opaquely
}
extension DoorFacade {
    public static func checkHere(nodeId: String, mapState: MapState, today: CalendarDay)
        -> (runState: DoorRunState, screen: DoorADiagnosisScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func decideProbe(_ offer: ProbeOffer, accept: Bool, runState: DoorRunState, today: CalendarDay)
        -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorAProbeAnswerAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, runState: DoorRunState)
        -> DoorADiagnosisScreen
    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func resumeAfterDiagnosis(_ runState: DoorRunState, outcome: DiagnosisOutcome, today: CalendarDay)
        -> (advance: DoorBResumeAdvance, runState: DoorRunState, writeFailureCode: String?)
}
```

```swift
// App/Sources/Doors/ExpeditionItemView.swift, ExpeditionAnswerCardView.swift (04.8's spec §4.5/§4.6, re-read
// and byte-compared against 04.8's own already-written spec — this task reuses both, unmodified)
struct ExpeditionItemView: View {
    let content: DoorItemContent
    @Binding var keypadInput: String
    let onSubmitNumeric: (String) -> Void
    let onSubmitChoice: (String) -> Void
}
struct ExpeditionAnswerCardView: View {
    let content: DoorAnswerCardContent
    let onContinue: () -> Void
}
```

```swift
// App/Sources/MapUI/MapActionsView.swift (03.11's spec §4.6, re-read and byte-compared — the exact code this
// task rewires; 04.8's own spec touches this file too but does not edit HandOffDestination.diagnosis or
// CheckHereActionButton, so this shape is unchanged by 04.8)
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case doorBStarted(DoorBStartOutcome)   // 04.8's rename of 03.11's .unitExpedition case
    case included(map: MapState)
}
typealias HandOffHook = (HandOffDestination) -> Void

struct CheckHereActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Check me here") {
            let (event, _) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
            handOff(.diagnosis(event: event))
        }
    }
}
```

```swift
// App/Sources/Shell/AppShell.swift (04.8's spec §4.9, re-read and byte-compared — the exact code this task
// extends; 04.8's own §2 confirms it is "this task's own, private" addition alongside MapStateHolder)
enum DoorBPhase: Equatable {
    case screen(DoorBScreen)
    case answerCard(DoorBAnswerAdvance)
}

struct DoorBRunSnapshot: Equatable {
    let runState: DoorRunState
    let phase: DoorBPhase
    let writeFailureCode: String?
}

@Observable
final class DoorRunHolder {
    private(set) var current: DoorBRunSnapshot?
    func replace(with newValue: DoorBRunSnapshot) { current = newValue }
    func clear() { current = nil }
}
```

```swift
struct AppShell: View {
    // … existing @State private var holder, phase, today (unchanged) …
    @State private var doorHolder = DoorRunHolder()

    // … existing body switch …
    // case .ready:
    //     MapScreen(holder: holder, today: today, handOff: handOff, onChangeCourse: ...)
    //         .fullScreenCover(
    //             isPresented: Binding(
    //                 get: { doorHolder.current != nil }, set: { if !$0 { doorHolder.clear() } })
    //         ) {
    //             DoorBRunScreen(
    //                 holder: doorHolder, mapHolder: holder, today: today,
    //                 onDismiss: { doorHolder.clear() })
    //         }

    private func handOff(_ destination: HandOffDestination) {
        switch destination {
        case .included(let map):
            holder.replace(with: map)
        case .doorBStarted(let outcome):
            doorHolder.replace(
                with: DoorBRunSnapshot(
                    runState: outcome.runState, phase: .screen(outcome.screen),
                    writeFailureCode: outcome.writeFailureCode))
        case .diagnosis:
            break  // EPIC 04 task 04.9 replaces this.
        }
    }
}
```

```swift
private struct DoorBRunScreen: View {
    let holder: DoorRunHolder
    let mapHolder: MapStateHolder
    let today: CalendarDay
    let onDismiss: () -> Void

    @State private var viewState = DoorBViewState()

    var body: some View {
        if let current = holder.current {
            content(for: current)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(for current: DoorBRunSnapshot) -> some View {
        switch current.phase {
        case .screen(.item(let item)):
            ExpeditionItemView(
                content: item, keypadInput: $viewState.keypadInput,
                onSubmitNumeric: { submitted in submit(submitted, current: current) },
                onSubmitChoice: { submitted in submit(submitted, current: current) })
        case .screen(.diagnosis):
            EmptyView()  // EPIC 04 task 04.9 replaces this.
        case .screen(.summary(let summary)):
            ExpeditionSummaryView(
                summary: summary,
                writeFailureText: current.writeFailureCode.flatMap {
                    CoreError(rawValue: $0).flatMap(CoreErrorText.text(for:))
                },
                startAnotherErrorText: viewState.startAnotherErrorText,
                onStartAnother: { startAnother(current: current) },
                onBackToMap: { backToMap(current: current) })
        case .answerCard(let advance):
            ExpeditionAnswerCardView(content: advance.answerCard) {
                continueTapped(advance, current: current)
            }
        }
    }

    private func submit(_ value: String, current: DoorBRunSnapshot) {
        let (advance, runState, failure) = DoorFacade.answer(current.runState, submitted: value, today: today)
        viewState.keypadInput = ""
        holder.replace(
            with: DoorBRunSnapshot(runState: runState, phase: .answerCard(advance), writeFailureCode: failure))
    }

    private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {
        let (screen, runState) = DoorFacade.continueAfterAnswer(advance, runState: current.runState)
        holder.replace(with: DoorBRunSnapshot(runState: runState, phase: .screen(screen), writeFailureCode: nil))
    }

    private func startAnother(current: DoorBRunSnapshot) {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startAnother(
                mapState: current.runState.map, today: today)
            viewState.startAnotherErrorText = nil
            holder.replace(
                with: DoorBRunSnapshot(runState: runState, phase: .screen(screen), writeFailureCode: failure))
        } catch let error as CoreError {
            viewState.startAnotherErrorText = CoreErrorText.text(for: error)
        } catch {
            viewState.startAnotherErrorText = nil
        }
    }

    private func backToMap(current: DoorBRunSnapshot) {
        let (mapState, _) = DoorFacade.backToMap(current.runState, today: today)
        mapHolder.replace(with: mapState)
        onDismiss()
    }
}
```

The block above is quoted byte-for-byte from 04.8's own, already-ratified §4.9 (`tasks/epic-04-task-08-*.md`
§4.9, re-read and byte-compared this session) — its final, post-rename shape (`DoorBRunSnapshot`,
`DoorRunHolder.current`, `current:` parameters throughout), not the pre-rename `DoorBSession`/`.session` draft
an earlier compile of this same spec carried. This task's own §4.6 extends exactly this shape.

`AppSourcesBoundary`'s forbidden-name rule and import allow-list (`tasks/epic-03-task-09-*.md` §4.2, re-read
and byte-compared — governs AC9; unchanged since 04.8 needed no widening):

```swift
static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]
private static let forbiddenCoreTypeNames = [
    "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
    "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
]
```

`DoorFacade`/`DoorRunState`/`DoorADiagnosisFlow`/`DoorBExpeditionFlow` are **not** on this list; `Rendering` is
already in `allowedImportModules`. 04.8's own §6 default 4 established this same conclusion for its own,
larger call surface ("Task 04.10 ... does not need to land before this task, and this task does not need to
land before 04.10 either — the ordering constraint the planner flagged ... is satisfied by construction: this
task's code, written exactly as §4 specifies, introduces zero 03.9 scan violations under the current,
unmodified rule set"); the same reasoning applies here verbatim, over this task's own, smaller call surface
(§6 default 3).

Gate commands (`scripts/gate.sh`, re-read this session):

```sh
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" -configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO
```

Glossary bans relevant to this task's copy (`contracts/domain-glossary.md`, re-read this session):

- `contracts/domain-glossary.md:40` (§ Diagnosis, Door A):
  > - **Diagnosis event** — one Door A occurrence, from an expedition second miss or "Check me here". *Banned:*
  >   "tutoring session", "attempt".
- `contracts/domain-glossary.md:44` (§ Diagnosis, Door A):
  > - **Blocked** — the mastery state set on a candidate that failed its probe, or beyond the cap. The map is
  >   the record (v2.5 §3). *Banned:* "deeper gap recorded", "record page".

  Binds AC1/AC3/§5 T4: this task's code and copy use no banned synonym; none of "tutoring session", "attempt",
  "deeper gap recorded" or "record page" appears anywhere in this task's scope.

- `contracts/domain-glossary.md:29` (§ Expedition, Door B, re-read this session — cited here because it also
  governs this task's identifier choices, not only its copy):
  > - **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry
  >   day-unit), "quest", "level".

  Binds §6 default 1 and §5 T4's Session-identifier scan: "session" is banned repo-wide as a type/property
  identifier, not merely as user-facing copy — the reason 04.8's own holder type is `DoorBRunSnapshot`/
  `DoorRunHolder.current`, and this task's own new field, parameters and construction sites follow the same
  naming discipline. The same discipline governs this task's prose and doc comments: a Door A occurrence is a
  "diagnosis event" (`contracts/domain-glossary.md:40`) and a Door B occurrence is an "expedition run", never a
  "session" (`contracts/domain-glossary.md:62`: "**Session** — in telemetry only: one app foreground period on
  one day. Not a product concept.").

**Quote-fidelity correction (this revision).** The prior draft of this spec carried the pre-04.8-rename
identifiers `DoorBSession`/`DoorRunHolder.session`/`session:`-labelled parameters, obsoleted by 04.8's own
final revision (`tasks/epic-04-task-08-*.md` §4.9, §6 default: renamed to `DoorBRunSnapshot`/
`DoorRunHolder.current`/`current:` because `contracts/domain-glossary.md:29`, quoted above, bans "session" as
an Expedition synonym and `docs/plans/epic-04-plan.md` directs "Do not coin new *Session* identifiers"). This
revision renames every occurrence to `DoorBRunSnapshot`, `DoorRunHolder.current`/`doorHolder.current`, and
every `session:` parameter label to `current:`, throughout §1, §2, the AC list, §4.5, §4.6, §5 and §6 below; no
other content changes.

**Arbitration correction (`tasks/arbitration/arbiter-04-09-standalone-count.md`).** §5 T5's AC5 guard is
recounted against the §4.6 code this spec mandates (ten `DoorBRunSnapshot(` construction sites, not six) and
recast as a structural equality check with an executable negative control; prose that called a diagnosis event
or an expedition run a "session" (§1 I14, AC8, §4.6, §6 default 1) is reworded to the glossary terms above. No
code, AC semantics or file scope changes.

## §4 Implementation outline

### 4.1 Layer placement

Every file in this task's scope is layer ④ interaction's render layer (Door A), `App/Sources`. Each new view is
a pure function of the `Core`-computed value it is handed, plus outgoing callbacks; the two modified files
(`MapActionsView.swift`, `AppShell.swift`) add composition and one `DoorFacade` call per user action (or, for
the standalone terminal's return, zero — §4.6), never new domain logic.

### 4.2 `App/Sources/Doors/HypothesisCardView.swift`

```swift
import Core
import SwiftUI

/// The Door A hypothesis card (W1–W2, diagnosis Q2's declinable cost statement). Every string is 04.3-computed
/// (`content.line`/`content.costLine`); "Yes"/"Not now" are App-authored chrome, the same category as 04.8's
/// "Continue"/"Submit" (04.8 §4.6).
struct HypothesisCardView: View {
    let content: DoorAHypothesisContent
    let onDecision: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(content.line)
            Text(content.costLine)
            Button("Yes") { onDecision(true) }
            Button("Not now") { onDecision(false) }
        }
        .padding()
    }
}
```

### 4.3 `App/Sources/Doors/RemediationView.swift`

```swift
import Core
import Rendering
import SwiftUI

/// The one shared remediation-piece renderer (diagnosis W4; domain-glossary v1.0.1 Remediation, §3). Never
/// renders an `internalCode`, a fraction or a percentage (I6, content-policy § Voice).
struct RemediationView: View {
    let content: DoorARemediationContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch content {
            case .explanation(let text):
                Text(text)
            case .workedExample(let example):
                ForEach(example.stepsLatex, id: \.self) { step in
                    MathView(latex: step)
                }
            case .paraphrase(let text, let hint):
                Text(text)
                if let hint {
                    Text(hint)
                }
            }
        }
        .padding()
    }
}
```

`WorkedExample.stepsLatex` is routed to `MathView(latex:)` per step, following the same "a field named
`...Latex` holds LaTeX" convention `promptLatex`/`choices[].latex` already establish (`contracts/data-model.md`
§ Text, quoted by 04.8 §3). This branch is unreached on real `data/demo` today — 04.3 AC6 confirms every
`data/demo` node's confirmed branch takes `.paraphrase(_, hint:)`, since `data/demo` carries zero
`explanation`/`worked_examples` entries — but it must still compile and render correctly for any future bundle
that populates `worked_examples`.

### 4.4 `App/Sources/Doors/DiagnosisReturnView.swift`

```swift
import Core
import SwiftUI

/// The two screens that lead a diagnosis event toward `returned`: the further-level offer (diagnosis Q3,
/// "offered, never automatic") and the terminal line/hint/remediation (W5). Both reuse `RemediationView`; the
/// terminal never shows a `DoorAHintContent.internalCode` or a placeholder "no hint written" string
/// (arbiter-04-hint-fallback-reconciliation Rule 3, §3).
struct DiagnosisReturnView: View {
    enum Content: Equatable {
        case furtherLevelOffer(remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent)
        case terminal(DoorATerminalContent)
    }

    let content: Content
    let onFurtherLevelDecision: (Bool) -> Void
    let onReturn: () -> Void

    var body: some View {
        switch content {
        case .furtherLevelOffer(let remediation, let offer):
            VStack(spacing: 12) {
                RemediationView(content: remediation)
                Text(offer.question)
                Button("Yes") { onFurtherLevelDecision(true) }
                Button("Not now") { onFurtherLevelDecision(false) }
            }
            .padding()
        case .terminal(let terminal):
            VStack(spacing: 12) {
                if let line = terminal.line {
                    Text(line)
                }
                if let hint = terminal.hint {
                    Text(hint.prose)
                }
                if let remediation = terminal.remediation {
                    RemediationView(content: remediation)
                }
                Button("Continue") { onReturn() }
            }
            .padding()
        }
    }
}
```

Only `hint.prose` is ever rendered — never `hint.internalCode`, never `hint.resolvedKey` — and no second string
is authored for the case where `hint`/`remediation` is `nil` (both branches simply omit the row; §6 default 5).

### 4.5 `App/Sources/MapUI/MapActionsView.swift` — the "Check me here" rewire

```swift
struct DoorAStartOutcome: Equatable {
    let runState: DoorRunState
    let screen: DoorADiagnosisScreen
    let writeFailureCode: String?
}

enum HandOffDestination {
    case diagnosisStarted(DoorAStartOutcome)
    case doorBStarted(DoorBStartOutcome)
    case included(map: MapState)
}

struct CheckHereActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Check me here") {
            let (runState, screen, failure, _) = DoorFacade.checkHere(
                nodeId: nodeId, mapState: mapState, today: AppShell.resolveToday())
            handOff(
                .diagnosisStarted(
                    DoorAStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
        }
    }
}
```

`CheckHereActionButton`'s public shape (`nodeId:`, `mapState:`, `handOff:`) is unchanged, so `NodePanelView
.swift`'s existing call site (03.11, out of scope here) needs no edit and compiles unchanged. `today` is
obtained via `AppShell.resolveToday()` (a plain, non-`private` `static func` on `AppShell`, already reachable
from any file in the App target) rather than threaded as a new parameter, precisely so `NodePanelView.swift`
stays untouched (§6 default 2).

### 4.6 `App/Sources/Shell/AppShell.swift` — the Door A wiring

Extend `DoorBRunSnapshot`/`DoorBPhase` (04.8's types, this same file):

```swift
struct DoorBRunSnapshot: Equatable {
    let runState: DoorRunState
    let phase: DoorBPhase
    let writeFailureCode: String?
    /// True only for a diagnosis event opened via `.diagnosisStarted` (a standalone `map_check_here` event with
    /// no suspended expedition). False for every expedition run, including one that later reveals a diagnosis
    /// screen via the D27 hand-off. A provenance tag this file itself sets once, at construction — never a
    /// re-derivation of `DoorRunState.expedition` (which is Core-internal and unreadable from `App/Sources`,
    /// §6 default 1).
    let isStandaloneDiagnosis: Bool
}

enum DoorBPhase: Equatable {
    case screen(DoorBScreen)
    case answerCard(DoorBAnswerAdvance)
    case diagnosisAnswerCard(DoorAProbeAnswerAdvance)
}
```

Update `handOff` and every pre-existing `DoorBRunSnapshot(...)` construction site (04.8's `.doorBStarted`
handler, `submit`, `continueTapped`, `startAnother`) to carry the new field:

```swift
private func handOff(_ destination: HandOffDestination) {
    switch destination {
    case .included(let map):
        holder.replace(with: map)
    case .doorBStarted(let outcome):
        doorHolder.replace(
            with: DoorBRunSnapshot(
                runState: outcome.runState, phase: .screen(outcome.screen),
                writeFailureCode: outcome.writeFailureCode, isStandaloneDiagnosis: false))
    case .diagnosisStarted(let outcome):
        doorHolder.replace(
            with: DoorBRunSnapshot(
                runState: outcome.runState, phase: .screen(.diagnosis(outcome.screen)),
                writeFailureCode: outcome.writeFailureCode, isStandaloneDiagnosis: true))
    }
}
```

`submit`/`continueTapped`/`startAnother` are reachable only from `.screen(.item(...))`/`.answerCard(...)`
phases, which a standalone diagnosis event never enters — each of their three `DoorBRunSnapshot(...)`
reconstructions gains `isStandaloneDiagnosis: false` unchanged (a correct constant, not a placeholder; §6
default 1).

Extend `DoorBRunScreen.content(for:)` and add the Door A private functions:

```swift
@ViewBuilder
private func content(for current: DoorBRunSnapshot) -> some View {
    switch current.phase {
    case .screen(.item(let item)):
        ExpeditionItemView(/* unchanged, 04.8 */)
    case .screen(.diagnosis(let diagnosisScreen)):
        diagnosisContent(for: diagnosisScreen, current: current)
    case .screen(.summary(let summary)):
        ExpeditionSummaryView(/* unchanged, 04.8 */)
    case .answerCard(let advance):
        ExpeditionAnswerCardView(/* unchanged, 04.8 */)
    case .diagnosisAnswerCard(let advance):
        writeFailureBanner(current).overlay(alignment: .top) {
            EmptyView()
        }
        ExpeditionAnswerCardView(content: advance.answerCard) {
            continueDiagnosisTapped(advance, current: current)
        }
    }
}

@ViewBuilder
private func writeFailureBanner(_ current: DoorBRunSnapshot) -> some View {
    if let code = current.writeFailureCode, let coreError = CoreError(rawValue: code),
        let text = CoreErrorText.text(for: coreError)
    {
        Text(text)
    }
}

@ViewBuilder
private func diagnosisContent(for screen: DoorADiagnosisScreen, current: DoorBRunSnapshot) -> some View {
    VStack {
        writeFailureBanner(current)
        switch screen {
        case .hypothesis(let content, let offer):
            HypothesisCardView(content: content) { accept in
                decideProbe(offer, accept: accept, current: current)
            }
        case .probeItem(let content, let probe):
            ExpeditionItemView(
                content: content, keypadInput: $viewState.keypadInput,
                onSubmitNumeric: { submitted in answerProbeItem(probe, submitted: submitted, current: current) },
                onSubmitChoice: { submitted in answerProbeItem(probe, submitted: submitted, current: current) })
        case .furtherLevelOffer(let remediation, let offer, let decision):
            DiagnosisReturnView(
                content: .furtherLevelOffer(remediation: remediation, offer: offer),
                onFurtherLevelDecision: { accept in decideFurtherLevel(decision, accept: accept, current: current) },
                onReturn: {})
        case .terminal(let terminalContent):
            DiagnosisReturnView(
                content: .terminal(terminalContent),
                onFurtherLevelDecision: { _ in },
                onReturn: { returnFromDiagnosis(outcome: terminalContent.outcome, current: current) })
        }
    }
}

private func decideProbe(_ offer: ProbeOffer, accept: Bool, current: DoorBRunSnapshot) {
    let (advance, runState, failure) = DoorFacade.decideProbe(
        offer, accept: accept, runState: current.runState, today: today)
    holder.replace(
        with: DoorBRunSnapshot(
            runState: runState, phase: .screen(.diagnosis(advance.screen)), writeFailureCode: failure,
            isStandaloneDiagnosis: current.isStandaloneDiagnosis))
}

private func answerProbeItem(_ probe: ProbeInProgress, submitted: String, current: DoorBRunSnapshot) {
    let (advance, runState, failure) = DoorFacade.answerProbeItem(
        probe, submitted: submitted, runState: current.runState, today: today)
    viewState.keypadInput = ""
    holder.replace(
        with: DoorBRunSnapshot(
            runState: runState, phase: .diagnosisAnswerCard(advance), writeFailureCode: failure,
            isStandaloneDiagnosis: current.isStandaloneDiagnosis))
}

private func continueDiagnosisTapped(_ advance: DoorAProbeAnswerAdvance, current: DoorBRunSnapshot) {
    let screen = DoorFacade.continueAfterProbeAnswer(advance, runState: current.runState)
    holder.replace(
        with: DoorBRunSnapshot(
            runState: current.runState, phase: .screen(.diagnosis(screen)), writeFailureCode: nil,
            isStandaloneDiagnosis: current.isStandaloneDiagnosis))
}

private func decideFurtherLevel(_ offer: FurtherLevelOffer, accept: Bool, current: DoorBRunSnapshot) {
    let (advance, runState, failure) = DoorFacade.decideFurtherLevel(
        offer, accept: accept, runState: current.runState, today: today)
    holder.replace(
        with: DoorBRunSnapshot(
            runState: runState, phase: .screen(.diagnosis(advance.screen)), writeFailureCode: failure,
            isStandaloneDiagnosis: current.isStandaloneDiagnosis))
}

private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {
    if current.isStandaloneDiagnosis {
        // 04.5 AC8: no `resumeAfterDiagnosis` call exists or is needed for a standalone `map_check_here`
        // event — `current.runState.map` already carries the last state 04.5's Door A calls persisted.
        mapHolder.replace(with: current.runState.map)
        onDismiss()
    } else {
        let (advance, runState, failure) = DoorFacade.resumeAfterDiagnosis(
            current.runState, outcome: outcome, today: today)
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .screen(advance.screen), writeFailureCode: failure,
                isStandaloneDiagnosis: false))
    }
}
```

`continueDiagnosisTapped` sets `writeFailureCode: nil` because `continueAfterProbeAnswer` never writes
(arbiter-04 § Q-A, quoted 04.8 §3), mirroring 04.8's own `continueTapped`. Every branch above (`decideProbe`,
`answerProbeItem`, `continueDiagnosisTapped`, `decideFurtherLevel`, and the non-standalone arm of
`returnFromDiagnosis`) calls exactly one `DoorFacade` entry; the standalone arm of `returnFromDiagnosis` calls
none, matching 04.5 AC8 exactly (AC7, AC8).

### 4.7 Boundary validation

The only untrusted input any file in this task's scope reads is the student's own keypad/choice taps inside
the reused `ExpeditionItemView` (already bounded by `DoorKeypad.numericKeypadKeys` and `DoorItemChoice.id`, per
04.8 §4.10) and the accept/decline button taps this task's own views add (a fixed, closed `Bool`, never a
free-form value); this task's code performs no additional validation and needs none.

### 4.8 Error codes shown

- `CoreError.diagStateWriteFailed` (`"DIAG_STATE_WRITE_FAILED"`) — the write-failure banner shown above every
  Door A screen (`writeFailureBanner(_:)`), resolved from `DoorBRunSnapshot.writeFailureCode` via
  `CoreError(rawValue:)` + `CoreErrorText.text(for:)`, never a second, hand-authored string.
- `DIAG_NO_PREREQUISITE`/`DIAG_PROBE_UNAVAILABLE` are **not** resolved by this task's code: 04.3's own
  `terminalContent(...)` already bakes their registered text into `DoorATerminalContent.line` before this
  task's views ever see it (04.3 §4 step 4). This task's `DiagnosisReturnView` renders `terminal.line` as
  plain `Text`, whatever registered or fixed string it carries — it never calls `CoreErrorText.text(for:)` a
  second time for these two codes.
- No `CoreError` case is added, thrown or newly referenced by this task; `diagStateWriteFailed` is already
  registered and already resolved by `CoreErrorText` (03.3's file, untouched).

### 4.9 Model-calling paths

None. Every file in this task's scope is Tier 0, synchronous; no `FoundationModels` import, no adapter
parameter anywhere (I2's confidence-threshold/fallback requirement is not engaged). The hypothesis card's
optional Tier-1 "what did you do?" line (EPIC 13) is out of this task's scope and not built.

### 4.10 Smoke check

`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM"
-configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`,
gate 4) — must be green, with every file in this task's scope compiled into the target via the synchronized
`Sources` group.

## §5 Test plan (risk: seam — full plan)

**C3 note (owner-verified, no agent claim of pixel-level or tap-level correctness).** `App/mathmath.xcodeproj`
has no App unit-test target (`tasks/arbitration/arbiter-03-predispatch.md` § Q-F: "No App test target is
needed"). This task's verification is therefore the App build, the lint gate, the 03.9 structural scan, and
source-level inspection against each AC — the same C3 exclusion 03.11's, 03.12's and 04.8's own specs already
establish, restated per this task's own §1 C3 paragraph (arbiter-04 § Q-C). No line in this task's acceptance
report claims screenshot-level or tap-level correctness (D29).

- **T1 happy path:** AC1–AC8 are each verified by (a) the App build (`scripts/gate.sh:22`) succeeding with
  every file in this task's scope compiled in; (b) a full read-through of each file confirming every AC's
  field routing, call count and case list matches §4's code exactly; (c) `swift-format lint --strict` clean on
  every file in this task's scope.
- **T2 negative — invalid input rejected at the boundary:** not applicable in the schema-validation sense (this
  task validates no external payload, §4.7); the closest analogue is a probe item's malformed numeric keypad
  string (e.g. `"//"`) passed through `answerProbeItem`: the probe answer card still renders (`correct ==
  false`, from `ItemChecker`'s own grammar check inside `DiagnosisRun.answerProbeItem`, 04.3's concern), never a
  crash — confirmed by inspection that `answerProbeItem(_:submitted:current:)` performs no precondition on
  `submitted` before calling `DoorFacade.answerProbeItem`.
- **T3 error-taxonomy:** `rg -n "CoreErrorText"` over this task's scope shows exactly one call site
  (`writeFailureBanner(_:)`); `rg -n "\.diagStateWriteFailed"` shows the only registered code this task's code
  ever names; no `Text(` literal anywhere in this task's scope names an error condition ad hoc (every other
  `Text(` call renders a `Core`-supplied string or one of the fixed chrome labels §5 T5 enumerates).
- **T4 conformance per requirements §B.1** (`contracts/interaction-contract.md` § 4, `contracts/content-policy.md`
  §§ Voice / Grade 9–12 tier, `contracts/domain-glossary.md`, and I2/I3/I5/I6/I10/I14 per §1):
  - I3: `rg -n "continueAfterProbeAnswer"` over this task's scope shows exactly one call site
    (`continueDiagnosisTapped`), reachable only from `ExpeditionAnswerCardView`'s single continue control's
    `onContinue` closure — no other code path in this task's scope reaches `.screen(.diagnosis(...))` from
    `.diagnosisAnswerCard(...)` without it.
  - I6: `rg -n "internalCode"` over `App/Sources/Doors/DiagnosisReturnView.swift` shows zero occurrences inside
    any `Text(`/render call (the field is destructured but never displayed); `rg -ni "no hint written"` over
    this task's scope returns no match.
  - I10: `rg -n "TextField"` over this task's scope returns no match; `rg -n "import Vision|VisionKit|PencilKit|FoundationModels"`
    returns no match.
  - I14: the 03.9 `AppSourcesBoundary` scan re-run with this task's files present stays green (AC9); `rg -n
    "DoorADiagnosisFlow\.|DiagnosisRun\.|ExpeditionRun\.|Expedition\.compose|StudentState\("` over this task's
    scope returns no match — every state-changing action goes through `DoorFacade` only.
  - Glossary (§3): `rg -ni "tutoring session|\bAttempt\b|deeper gap recorded|record page"` over
    `App/Sources/Doors/HypothesisCardView.swift`, `RemediationView.swift`, `DiagnosisReturnView.swift`, and the
    changed lines of `MapActionsView.swift`/`AppShell.swift` returns no match.
  - **Session-identifier scan (case-sensitive, catches what the word-boundary grep above cannot):** `rg -n
    "Session"` (no `-i`, unanchored — matches inside a larger identifier such as `DoorBSession`, not just the
    standalone word) over `App/Sources/Doors/HypothesisCardView.swift`, `RemediationView.swift`,
    `DiagnosisReturnView.swift`, and the changed lines of `App/Sources/MapUI/MapActionsView.swift` /
    `App/Sources/Shell/AppShell.swift` returns no match. This mirrors 04.8's own §5 T4 Session-identifier scan
    exactly (`tasks/epic-04-task-08-*.md` §5 T4), re-scoped to this task's own new files and changed lines.
    **Negative control:** the prior, pre-fix draft of this task's own §4.6 code — `struct DoorBSession:
    Equatable { ... }`, `private(set) var session: DoorBSession?`, `func replace(with newValue: DoorBSession)
    { session = newValue }`, and a `session: DoorBSession` parameter on each of `decideProbe`,
    `answerProbeItem`, `continueDiagnosisTapped`, `decideFurtherLevel` and `returnFromDiagnosis` — matched this
    grep well over a dozen times; this revision's code (§4.6, this file) uses `DoorBRunSnapshot` and
    `DoorRunHolder.current`/`current:` parameters throughout, so the scan now returns no match, proving the
    guard is load-bearing.
- **T5 negative control for every regression guard:**
  - AC1/AC3's "no invented content string" guard: `rg -n "Text\(\"" App/Sources/Doors/HypothesisCardView.swift
    App/Sources/Doors/DiagnosisReturnView.swift App/Sources/Doors/RemediationView.swift` returns no match —
    every `Text(` call in these three files renders a variable (`content.line`, `terminal.line`, `hint.prose`,
    `offer.question`, `text`, `hint`), never a string literal; the guard this task's own code passes by
    construction; a version of `DiagnosisReturnView` that added `Text("No hint written for that exact mistake
    yet")` would fail this grep, proving the guard is load-bearing.
  - AC4's exact-three-case guard: `rg -n "case " App/Sources/MapUI/MapActionsView.swift` inside the
    `HandOffDestination` enum body shows exactly three lines — mirrors 03.11's AC9/04.8's AC6 guard, re-scoped
    to the renamed case.
  - AC5/AC7's "isStandaloneDiagnosis threaded, never re-derived" guard — a structural check, not an exact
    line count. Instrument: ripgrep over the text of `App/Sources/Shell/AppShell.swift` only (it proves nothing
    about any other file, nor about runtime values — the compile-time half below covers the latter). Four
    commands, each run from the repo root:
    - (a) `rg --count-matches "DoorBRunSnapshot\(" App/Sources/Shell/AppShell.swift` and (b) `rg
      --count-matches "isStandaloneDiagnosis: (true|false|current\.isStandaloneDiagnosis)\b"
      App/Sources/Shell/AppShell.swift` print the **same** number. Pass condition: (a) == (b), and both equal
      `10` — the ten `DoorBRunSnapshot(` construction sites this spec mandates: 04.8's four (`.doorBStarted`,
      `submit`, `continueTapped`, `startAnother` — 04.8 §4.9 quoted §3; its `backToMap` constructs none),
      this task's `.diagnosisStarted`, the four Door A actions of §4.6 (`decideProbe`, `answerProbeItem`,
      `continueDiagnosisTapped`, `decideFurtherLevel`, each passing `current.isStandaloneDiagnosis`), and
      `returnFromDiagnosis`'s non-standalone arm. The declaration `struct DoorBRunSnapshot:`, the parameter
      type `current: DoorBRunSnapshot)` and the optional `DoorBRunSnapshot?` never match (a), since none is
      followed by `(`; the declaration `let isStandaloneDiagnosis: Bool` never matches (b). Either command
      printing nothing (zero matches) = FAIL.
    - (c) `rg -n "isStandaloneDiagnosis: true" App/Sources/Shell/AppShell.swift` shows exactly one line
      (`handOff`'s `.diagnosisStarted` arm — the only site that opens a standalone diagnosis event). Empty =
      FAIL; two or more lines = FAIL.
    - (d) `rg -n "let isStandaloneDiagnosis: Bool" App/Sources/Shell/AppShell.swift` shows exactly one line
      (the `DoorBRunSnapshot` field), and `rg -n "if current\.isStandaloneDiagnosis"
      App/Sources/Shell/AppShell.swift` shows exactly one line (`returnFromDiagnosis`'s branch, AC8). Either
      empty = FAIL.
    - Compile-time half: `DoorBRunSnapshot`'s memberwise initializer has no default for
      `isStandaloneDiagnosis`, so a construction site that omits the label fails gate 4; `DoorRunState
      .expedition` carries no `public` modifier (04.5's own `DoorRunState` declaration, quoted §3), so any
      re-derivation from `runState.expedition` does not compile from `App/Sources` at all.
    - **Negative control (executable, stdin, no file edit):** `printf 'with: DoorBRunSnapshot(\n
      runState: r, phase: p, writeFailureCode: nil,\n    isStandaloneDiagnosis: r.map.isEmpty))\n' | rg
      --count-matches "DoorBRunSnapshot\("` prints `1`, while the same text piped to (b)'s pattern prints
      nothing (zero) — the counts diverge, so a construction site passing any value other than a literal or
      `current.isStandaloneDiagnosis` is caught. Second control: `printf 'isStandaloneDiagnosis: true))\n
      isStandaloneDiagnosis: true))\n' | rg -n "isStandaloneDiagnosis: true"` prints two lines, which (c)
      rejects — a `returnFromDiagnosis` non-standalone arm mistakenly set to `true` is caught even though (a)
      and (b) still agree.
  - AC8's "branch on origin, never on outcome" guard: `rg -n "outcome\.terminal|outcome\.code|outcome\.blockedNodeIds"
    App/Sources/Shell/AppShell.swift` returns no match inside `returnFromDiagnosis` — the only field of
    `outcome` this task's code reads is the one `resumeAfterDiagnosis(outcome:)` parameter itself, never a
    branch on any of its sub-fields.
- **T6 idempotency / no-leak:** `continueDiagnosisTapped` called twice on the same `Equatable`-equal
  `DoorAProbeAnswerAdvance` (via `DoorFacade.continueAfterProbeAnswer`'s own idempotency, 04.5 T6) returns
  `Equatable`-equal `DoorADiagnosisScreen` values, so this task's rendering re-derives the identical screen
  either way; `rg -n "@State"` over `App/Sources/Doors` shows no new instance beyond 04.8's own
  `DoorBViewState`/button `errorText` fields (this task adds none) — no file holds a `Core` value across calls
  beyond the `DoorRunHolder`/`MapStateHolder` themselves (I14).

## §6 Decision defaults

- IF the App should determine whether a diagnosis is nested inside an expedition run by reading
  `DoorRunState.expedition` directly THEN it cannot and does not — that field carries no `public` modifier
  (04.5's own `DoorRunState` doc comment, quoted §3: "the App holds it opaquely and passes it back
  unmodified"), so it does not compile from `App/Sources`. `DoorBRunSnapshot.isStandaloneDiagnosis` is instead a
  plain App-side provenance tag, set exactly once per diagnosis event or expedition run (at the two hand-off
  sites) and threaded unchanged through every later reconstruction — a record of *which button opened this
  presentation*, never a re-derivation of a `Core`-internal fact (I14).
- IF `CheckHereActionButton` should gain a new `today: CalendarDay` parameter (since `DoorFacade.checkHere`
  needs one, unlike 03.11's `MapFacade.checkHere`) THEN it does not — `NodePanelView.swift`'s existing call
  site (`CheckHereActionButton(nodeId: content.nodeId, mapState: mapState, handOff: handOff)`, 03.11 §4.1) is
  out of this task's file scope, and adding a mandatory parameter would break its compilation. `today` is
  obtained inside `CheckHereActionButton`'s own action closure via `AppShell.resolveToday()` (a plain,
  non-`private` `static func` already reachable from any file in the App target, 03.12's spec §4.2, re-read
  this session) instead.
- IF the 03.9 `AppSourcesBoundary` scan's `allowedImportModules`/`forbiddenCoreTypeNames` (quoted §3) should be
  widened by this task to admit the `DoorFacade`/`DoorRunState`/`DoorADiagnosisScreen`/`DoorAProbeAnswerAdvance`
  symbols this task's code references THEN no widening is made or needed — every one of these is a `Core`
  public type reached only via `import Core` (already allow-listed) and none is on `forbiddenCoreTypeNames`
  (verified unchanged this session); every call this task's code makes is to `DoorFacade.*`, `CoreErrorText.*`,
  `AppShell.resolveToday()` or `MathView.*`, and this task's imports are exactly `SwiftUI`, `Core`, `Rendering`
  — all three already in `allowedImportModules`. This mirrors 04.8's own §6 default 4 conclusion exactly
  (`tasks/epic-04-task-08-*.md` §6, quoted §3): task 04.10 (which "extends 03.9's App/Sources scan with the
  Door rules and widens the allow-list by exactly the 04.5 entries") therefore does not need to land before
  this task, and this task does not need to land before 04.10 either — the ordering constraint the planner
  flagged (`docs/plans/epic-04-plan.md`: "The spec writer must make sure 04.8 and 04.9 do not need allow-list
  entries before 04.10 adds them") is satisfied by construction, for the same reason 04.8 already satisfies it.
- IF a dedicated `App/Sources/Doors/ProbeView.swift` should be created for the probe screen THEN it is not —
  `DoorADiagnosisScreen.probeItem` already carries a `DoorItemContent` (04.3 §4 step 2, quoted §3), the exact
  type 04.8's `ExpeditionItemView` already renders; a second view type over the identical value would duplicate
  04.8's own numeric-keypad/choice-button/`MathView` wiring with no behavioural difference (RULE 2, no
  abstraction for a single-use duplicate).
- IF `DiagnosisReturnView`'s terminal branch, when both `hint` and `remediation` are `nil` and `line` is also
  `nil` (the plain-`.confirmed`-with-no-further-offer case, or the declined-then-immediately-terminal edge —
  04.3 §6's own decision default: "`DoorATerminalContent.line` is `nil` for both" when no ratified copy string
  exists), should show a fallback placeholder string THEN it does not — the view renders only the "Continue"
  control in that case; content-policy § Generated content and this task's own I6 scope forbid inventing a
  Door A content string no `Core` value supplies, and a blank body above the return control is a valid, honest
  rendering of "nothing more to say here", not a defect.
- IF the further-level-offer's accept/decline labels should differ from the hypothesis card's ("Yes"/"Not now"
  reused verbatim on both screens) THEN they are the same pair — both screens ask a declinable yes/no question
  over already-shown content (the cost line; the remediation piece), and reusing one small, reviewed chrome
  literal set across both keeps the T5 negative-control grep simple and avoids inventing a second synonym pair
  with no domain distinction to justify it.
- IF `DoorBSession`/`session:`-labelled parameters (the identifiers a prior draft of this spec carried) should
  be kept THEN they are not — `contracts/domain-glossary.md:29` (quoted §3) bans "session" as an Expedition
  synonym and `docs/plans/epic-04-plan.md` directs "Do not coin new *Session* identifiers"; 04.8's own already-
  ratified spec (§4.9, §6) already made this call for its own holder type (`DoorBRunSnapshot`/
  `DoorRunHolder.current`), and this task's own new field, phase case and five private functions follow the
  identical convention (`current:` parameters, `DoorBRunSnapshot` construction sites) rather than reintroducing
  the banned noun.
- IF the AC5 guard should pin an exact `rg -n "isStandaloneDiagnosis"` line count THEN it does not — that
  count moves with formatting (a label and its `current.isStandaloneDiagnosis` value may share or split a
  line under swift-format) and silently drifted once already (a prior draft named six sites where §4.6
  mandates ten); the guard instead asserts the structural equality `count("DoorBRunSnapshot(") ==
  count("isStandaloneDiagnosis: <literal | current.isStandaloneDiagnosis>")` plus exact single-line checks
  for the declaration, the one `true` site and the one conditional read (§5 T5,
  `tasks/arbitration/arbiter-04-09-standalone-count.md`).

Standing defaults: identifiers and timestamps are untouched by this task — every id/timestamp already on
`DoorADiagnosisScreen`/`DoorATerminalContent`/`DoorRunState`/`MapState` passes through opaquely, and no file
constructs one. Model calls do not exist anywhere in this task's code (I2 vacuous). Telemetry is unaffected: no
telemetry client, no consent field, no identifier is read or written by any file in this task's scope. No
node's Ministry text is read — this task renders only `paraphrase`, `explanation`, `workedExamples.stepsLatex`
and `hintTree`-derived prose, all already `Core`-selected before this task's views ever see them.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`).
- typecheck clean — Swift's typecheck is the build.
- App build green (`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath
  -destination "$SIM" -configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO`,
  `scripts/gate.sh:22`, gate 4) with every file in this task's scope compiled into the target via the
  synchronized `Sources` group.
- the 03.9 `AppSourcesBoundary` scan (`xcodebuild test -scheme Core-Package`, gate 3) stays green with this
  task's files present in `App/Sources`, with no edit to `AppSourcesBoundaryTests.swift` or
  `AppSourcesBoundaryNegativeControlTests.swift` (§6 default 3).
- 03.12's simulator smoke (`scripts/sim-smoke.sh`, gate 4) stays green: this task adds no App launch-path code
  and no state-file interaction of its own beyond what 04.5's already-tested `DoorFacade` performs, so the
  fresh-install and seeded-relaunch scenarios (both scoped to launch/relaunch, before any Door A action) are
  unaffected by this task's file scope.
- tests green for every case in §5 (T1–T6), including T5's AC5/AC7 structural guard ((a) == (b) == 10; (c) and
  (d) exactly one line each) and both of its negative controls.
- glossary grep clean (§5 T4, both the word-boundary scan and the case-sensitive `"Session"` identifier scan)
  and no invented Door A content string anywhere in this task's scope (§5 T5).
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 4,
  `contracts/content-policy.md` §§ Voice / Grade 9–12 tier, `contracts/domain-glossary.md`) and to every
  invariant listed in §1 (I2, I3, I5, I6, I10, I14).
- the C3 exclusion (§1, §5) is honoured: no claim of tap-level, screenshot-level or runtime-sequence
  correctness appears in this task's acceptance report; that is the owner's Demo-wrap check (D29).

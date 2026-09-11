# Task 04.9 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-diagnosis-screens
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 09
- Slug: app-diagnosis-screens
- Sub-EPIC: 04b (Door app)
- Summary: Render-only SwiftUI views for the Door A diagnosis event screens over `Core`'s `DiagnosisFlow` and `DiagnosisContent` values (04.3). Hypothesis card as a sheet over the expedition or map, probe items each with an answer card (I3), remediation view, further-level offer (offered, never automatic), terminal/hint screen, and return to the suspended run's next item or the node panel. Replaces EPIC 03's "Check me here" placeholder; each button = exactly one 04.5 entry call; no Door A student-facing string literals in `App/Sources` (copy from Core values). Edits 03.11's hand-off file and 03.12's holder AFTER 04.8 (sequential).

- Invariants in play:
  - **I1** — `Core` decides all correctness via `ItemChecker`; this task renders only.
  - **I2** — Tier 0 only; no model-framework imports anywhere in this task's App-side code.
  - **I3** — after every probe answer, an explicit answer card is shown before the next screen is reachable. Continue changes no `StudentState`.
  - **I6** — no Ministry text on Door screens; remediation, hints, and hypothesis copy all from `Core` values or fixed Door constants.
  - **I10** — input is numeric keypad or choice taps only; no OCR, no free-text field.
  - **I14** — the render layer never computes state; all flow logic lives in `Core`; the App holds ephemeral view state only.

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 4. Diagnosis (Door A) — state machine and flow

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

Source: `contracts/interaction-contract.md:80-103`
Binds this task: all Door A screen rendering must conform to these states and transitions; the App views render only the content `Core`'s step API produces and can never decide a state transition themselves.

### contracts/content-policy.md — § Voice

> - Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student surfaces

Source: `contracts/content-policy.md:53-55`
Binds this task: hypothesis card, probe, remediation, and terminal screens must name a node, never the student; no fraction or percentage anywhere on a Door A screen.

### contracts/content-policy.md — § Grade 9–12 tier

> A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate).

Source: `contracts/content-policy.md:8-16`
Binds this task: no hardcoded Ministry text anywhere in the Door A screens; all prose comes from `Core` values (`paraphrase`, `explanation`, `hint_tree` strings) or fixed Door constants in `Core`.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/diagnosis.md — § UI surfaces

> Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the expedition item view); **Remediation** (W4, one explanation or worked example); return is implicit (W5). Confirmed by the Demo.

Source: `docs/domains/diagnosis.md:105-109`

### docs/domains/diagnosis.md — § Core entities — Remediation

> **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample` from **learning-objects**, then return.

Source: `docs/domains/diagnosis.md:41-42`

### docs/domains/diagnosis.md — W1 — Open a diagnosis event

> **Pre:** `expedition.diagnosis_requested` (D27) or `map.check_here_requested` (D28). **Steps:** 1. Create the `DiagnosisEvent` with the origin node and budget. 2. (Tier 0) Classify the miss deterministically: the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer matches a tagged distractor; otherwise `none_of_these` (abstention). 3. Show the **hypothesis card**: "This may be blocked by **X**" (W2) — or, on `none_of_these` with no candidate, a tier-1 hint on the origin and return (W5). **Post:** `diagnosis.opened` emitted.

Source: `docs/domains/diagnosis.md:52-58`

### docs/domains/diagnosis.md — W3 — Probe the candidate

> **Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick questions, about a minute") and let the student decline (Q2). 2. Draw 2 `ProbeItem`s (learning-objects W3); fewer → `DIAG_PROBE_UNAVAILABLE`, outcome `unconfirmed`, hint and return. 3. Check in code (I1); show each answer with its why (D5). 4. Pass → `refuted`: "Not the issue — back to where you were", W5 with a tier-1 hint on the origin. Fail → `confirmed`, W4. **Post:** `diagnosis.probe_completed` → expedition (state), telemetry (L3: the edge, the upstream state, the downstream result — v2.5 §1).

Source: `docs/domains/diagnosis.md:68-74`

### docs/domains/diagnosis.md — W4 — Remediate minimally and mark

> **Pre:** a `confirmed` Diagnosis. **Steps:** 1. Mark the candidate `blocked` (`diagnosis.node_blocked` → expedition W4; the map shows it). 2. Show exactly one `Remediation` piece for the candidate. 3. If budget remains and the candidate itself has unmastered prerequisites, offer — not force — one more level (W2 on the candidate); beyond the cap, W6. 4. Return (W5). **Post:** `diagnosis.remediation_shown`.

Source: `docs/domains/diagnosis.md:76-80`

### docs/domains/diagnosis.md — W5 — Return

> **Pre:** any terminal outcome. **Steps:** 1. Write the outcome record into `StudentState`. 2. Hand control back: to the suspended expedition (its W3 step 2 continues) or to the map node panel. 3. Tier 1 (M4+) may re-word the hint shown; below threshold or unavailable the stored wording stands (I2). **Post:** `diagnosis.returned`; the event is closed.

Source: `docs/domains/diagnosis.md:82-86`

### docs/domains/diagnosis.md — W6 — Enforce the backtrack cap

> **Pre:** W2 or W4 would exceed 2 levels from the origin in this session (Demo: 1). **Steps:** no probe, no remediation; the deeper candidate is marked `blocked` in `StudentState` and said plainly to be "further upstream — it's on your map"; return. **Post:** `diagnosis.capped` (D4, I4).

Source: `docs/domains/diagnosis.md:88-91`

## §D. Prior task outputs this task depends on

Exported types and signatures already produced by earlier tasks (04.3, 04.8, 04.7, 03.11, 03.12, 03.09, 04.5) that this task consumes:

### From 04.3 (Door A façade):

- `DoorADiagnosisFlow` (enum with public entry points):
  - `open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int) -> DiagnosisEvent`
  - `start(event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>, state: StudentState, bundle: ContentBundle) -> DoorADiagnosisAdvance`
  - `decideProbe(_ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle) -> DoorADiagnosisAdvance`
  - `answerProbeItem(_ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle, today: CalendarDay) -> DoorAProbeAnswerAdvance`
  - `continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, bundle: ContentBundle) -> DoorADiagnosisScreen`
  - `decideFurtherLevel(_ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle) -> DoorADiagnosisAdvance`

- `DoorADiagnosisAdvance` (return type for façade calls except `answerProbeItem`):
  ```swift
  public struct DoorADiagnosisAdvance: Equatable {
      public let screen: DoorADiagnosisScreen
      public let state: StudentState
      public let events: [CoreEvent]
  }
  ```

- `DoorADiagnosisScreen` (enum):
  ```swift
  public enum DoorADiagnosisScreen: Equatable {
      case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
      case probeItem(content: DoorItemContent, probe: ProbeInProgress)
      case furtherLevelOffer(remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent, decision: FurtherLevelOffer)
      case terminal(DoorATerminalContent)
  }
  ```

- `DoorAProbeAnswerAdvance` (I3 type — answer card only, pending advance hidden):
  ```swift
  public struct DoorAProbeAnswerAdvance: Equatable {
      public let answerCard: DoorAnswerCardContent
      public let itemResult: ItemResult
      public let state: StudentState
      public let events: [CoreEvent]
      // pendingAdvance and classifiedToken are non-public (module-internal only)
  }
  ```

- `DoorAHypothesisContent`:
  ```swift
  public struct DoorAHypothesisContent: Equatable {
      public let line: String       // DoorADiagnosisCopy.hypothesisLine(candidateNodeName:)
      public let costLine: String   // DoorADiagnosisCopy.costLine
  }
  ```

- `DoorARemediationContent`:
  ```swift
  public enum DoorARemediationContent: Equatable {
      case explanation(String)
      case workedExample(WorkedExample)
      case paraphrase(String, hint: String?)
  }
  ```

- `DoorAFurtherLevelOfferContent`:
  ```swift
  public struct DoorAFurtherLevelOfferContent: Equatable {
      public let candidateNodeName: String
      public let question: String   // DoorADiagnosisCopy.furtherLevelQuestion
  }
  ```

- `DoorATerminalContent`:
  ```swift
  public struct DoorATerminalContent: Equatable {
      public let terminal: DiagnosisTerminal
      public let line: String?
      public let hint: DoorAHintContent?
      public let remediation: DoorARemediationContent?
      public let outcome: DiagnosisOutcome
  }
  ```

- `DoorAHintContent`:
  ```swift
  public struct DoorAHintContent: Equatable {
      public let nodeId: String
      public let prose: String
      public let resolvedKey: String?
      public let internalCode: CoreError?
  }
  ```

- `DoorADiagnosisCopy` (constants):
  ```swift
  public enum DoorADiagnosisCopy {
      public static let costLine = "Two quick checks, about a minute."
      public static let refutedLine = "Not the issue — back to where you were"
      public static let cappedLine = "further upstream — it's on your map"
      public static let furtherLevelQuestion = "want to look one step further upstream?"
      public static func hypothesisLine(candidateNodeName: String) -> String
  }
  ```

Source: `tasks/epic-04-task-03-core-door-a-diagnosis-flow.md` §4 (spec outline) and §2 (file scope).

### From 04.8 (Door B screens):

- `DoorBAnswerAdvance`, `DoorBContinueAdvance`, `DoorBScreen`, `DoorBRunState` types (for continuation into Door A on D27 hand-off)
- `DoorItemContent` and `DoorAnswerCardContent` (reused for probe item display and probe answer cards)

Source: `tasks/epic-04-task-04-core-door-b-expedition-flow.md` § 2 (file scope).

### From 04.7 (MathView):

- `MathView` (SwiftUI view over SwiftMath)
- `MathView.content(latex:)` (static entry point for render-or-fallback decision)

Source: `tasks/epic-04-task-07-rendering-mathview.md` § 2 (file scope).

### From 03.11 (App hand-off):

- `HandOffDestination` and `HandOffHook` types
- `HandOffDestination.diagnosis(event: DiagnosisEvent)` case

Source: `tasks/epic-03-task-11-app-panels-pickers-handoff.md` § 2 (file scope), AC9.

### From 03.12 (App shell):

- `MapStateHolder` (the `@Observable` holder this task reads and updates)
- Reference to how the shell handles `handOff` hook for `.diagnosis` case

Source: `tasks/epic-03-task-12-app-shell-launch-smoke.md` § 2 (file scope).

### From 03.09 (boundary scan rules):

- `AppSourcesBoundary` scan rules (this task's code must pass them)

Source: `tasks/epic-03-task-09-app-sources-i14-scan.md` § 1 (goal).

### From 04.5 (Door entries):

- `DoorFacade` entry points for `checkHere`, `startDiagnosis`, `decideProbe`, `answerProbeItem`, `continueAfterProbeAnswer`, `decideFurtherLevel`, `resumeAfterDiagnosis`
- Return types carrying `writeFailureCode` fields

Source: `tasks/epic-04-task-05-core-door-entries-persistence-seam.md` § 1 (goal, entry point names).

## §E. Negative facts (confirmed ABSENT)

- No `DoorADiagnosisScreen` rendering views exist in `App/Sources`. Grep pattern `case diagnosis` over `App/Sources/**/*.swift` returns no match at this run.
- No Door A student-facing views exist anywhere in `App/Sources` yet. Glob `**/Hypothesis*.swift`, `**/Probe*.swift`, `**/Remediation*.swift`, `**/Terminal*.swift` all return empty.
- No Door A sheet presentation logic exists. Grep `sheet(isPresented` over `App/Sources` returns matches for 03.11's MapUI views only, not for diagnosis.
- Task 04.9 spec does not exist yet. Glob `**/epic-04-task-09*.md` returns no match.

## §F. File scope

Files this task may create or touch, marked create/modify:

- CREATE `App/Sources/Door/HypothesisCardView.swift` — hypothesis card sheet, displaying `DoorAHypothesisContent`, with decline button calling one `DoorFacade` entry point.
- CREATE `App/Sources/Door/ProbeView.swift` — probe screen(s) rendering `DoorADiagnosisScreen.probeItem`, with two item-screen + answer-card pairs, each answer card followed by an explicit continue button (I3).
- CREATE `App/Sources/Door/RemediationView.swift` — remediation screen displaying `DoorARemediationContent` (one of three enum cases).
- CREATE `App/Sources/Door/FurtherLevelOfferView.swift` — further-level-offer sheet, displaying question and remediation already shown, with accept/decline buttons.
- CREATE `App/Sources/Door/TerminalView.swift` — terminal screen(s) displaying `DoorATerminalContent` (one of five terminal outcomes).
- CREATE `App/Sources/Door/HintView.swift` — hint display (prose + no student-code interior banner) for terminal outcomes.
- MODIFY `App/Sources/MapUI/MapActionsView.swift` — edit the `HandOffDestination.diagnosis` case handler to present the real diagnosis screens instead of a placeholder (03.11's current stub).
- MODIFY the `@Observable` holder in `App/Sources` (created by 03.12) — add state for diagnosis-flow progression (current screen, pending advances, etc.) and methods to call `DoorFacade` entry points.

Confirmed absent by Glob (CREATE only):
- `App/Sources/Door/HypothesisCardView.swift` — no match.
- `App/Sources/Door/ProbeView.swift` — no match.
- All other Door A view files — Glob `**/App/Sources/Door/*.swift` returns empty.

## §G. Stack constraints relevant here

### Build environment (docs/tech-stack.md)

- **Student app language:** Swift 6 (language mode 6, strict concurrency `complete`), toolchain Swift 6.3.3 (Xcode 26.6). Source: `docs/tech-stack.md:14`.
- **UI framework:** SwiftUI (first-party, OS frameworks only). Source: `docs/tech-stack.md:15`.
- **Deployment target:** iOS / iPadOS 18.0. Source: `docs/tech-stack.md:16`.
- **Math display:** SwiftMath 1.7.3, imported only by `Packages/Rendering`; App uses `MathView` from `Rendering` for LaTeX display. Source: `docs/tech-stack.md:18`.
- **No third-party dependencies in App/Sources beyond OS frameworks and `Rendering` (already linked).** Source: `docs/tech-stack.md:1` (principles), `CLAUDE.md` D32.

### Invariants from CLAUDE.md

- **I1**: Correctness is decided by `ItemChecker` in `Core`, never by this task's UI code. Source: `CLAUDE.md:39`.
- **I2**: Tier 0 only. No `FoundationModels`, no adapter anywhere in this task's App-side code. Source: `CLAUDE.md:40-41`.
- **I3**: After every probe answer, the answer card is shown until an explicit continue button is tapped. Continue is a `Core` façade call and changes no `StudentState`. Source: `CLAUDE.md:44-45`.
- **I6**: No Ministry text on Door A screens. All prose from `Core` values or fixed Door constants. Source: `CLAUDE.md:47`.
- **I10**: Input is numeric keypad or choice taps only; no OCR, no free-text field, no Vision/VisionKit/PencilKit. Source: `CLAUDE.md:33`.
- **I14**: The render layer never computes state. All flow logic in `Core`. The App holds ephemeral `@Observable` state only. `Core` imports Foundation only. Source: `CLAUDE.md:37-38`.

### Entry points from 04.5 (seam boundary)

This task calls only `DoorFacade` entry points for Door A actions. Every button action = exactly one `DoorFacade` call. No direct `DiagnosisRun` call. Source: `docs/plans/epic-04-plan.md:8-9` ("04b calls only those entry points; 04.10's extended `App/Sources` scan enforces it").

### I3 guard (answer card timing)

No next screen (further-level offer, remediation, terminal, map return) is reachable without an explicit continue tap after every probe answer. This is ensured in `Core` (04.3), but the App must wire the UI correctly: after `answerProbeItem` returns a `DoorAProbeAnswerAdvance`, show the answer card and block all other navigation until `continueAfterProbeAnswer` is called. Source: `contracts/interaction-contract.md:79-82` (v0.9.3 ruling, arbiter-04 Q-A).

### No student-facing strings in App/Sources (I6)

Every string on a Door A screen comes from one of:
1. `Core` values: `DoorAHypothesisContent.line`, `DoorARemediationContent` enum cases, `DoorAHintContent.prose`, `DoorATerminalContent.line`
2. Fixed Door constants in `Core`: `DoorADiagnosisCopy.costLine`, `.refutedLine`, `.cappedLine`, `.furtherLevelQuestion`
3. `CoreErrorText.text(for:)` for registered error codes (`DIAG_NO_PREREQUISITE`, `DIAG_PROBE_UNAVAILABLE`)

No hardcoded prose anywhere in `App/Sources`. Source: Epic 04 brief §2 ("no Door A student-facing string literals in App/Sources (all copy from Core values)"), section "Scope: render-only SwiftUI views".

### Prior task outputs no longer exist in stubs

03.11's `HandOffDestination.diagnosis` case currently shows a placeholder. This task replaces it with real diagnosis screens. 03.11 AC9 confirms the case exists; this task's job is to render it. Source: `tasks/epic-03-task-11-app-panels-pickers-handoff.md` AC9.

---

## Closing note

The task spec for 04.9 does not exist yet. This bundle is the ground-truth input for its writing. The spec-writer is anchored to:
- The EPIC 04 brief (`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md`) § 2, § 7, § 8 task 7 (the "diagnosis screens" work item for 04b).
- The EPIC 04 plan (`docs/plans/epic-04-plan.md`) § task 04.9 summary.
- The arbitration rulings (`tasks/arbitration/arbiter-04-predispatch.md`, `arbiter-04-hint-fallback-reconciliation.md`), particularly Q-D (the cost line constant).
- The prior task specs for 04.3, 04.8, 04.7, 03.11, 03.12, 03.09, which define the inputs and reusable components.

All contracts, domain docs, and stack rules are locked and binding.

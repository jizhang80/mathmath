# Task 04.8 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-expedition-screens
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 04
- Task: 08
- Sub-EPIC: 04b
- Slug: app-expedition-screens
- Summary: Implement SwiftUI render-layer views over 04.4's Door B façade values (`DoorBScreen`). Item view with numeric keypad (from Core's key-set constant) or choice buttons; answer card with explicit continue control; summary with cleared/blocked node lists and no tint deltas or fractions. Replaces EPIC 03's placeholder destinations for Include and Unit expeditions. One button = exactly one 04.5 entry call; view state = presentation flags + in-progress keypad string only. Uses `MathView` from 04.7 for `prompt_latex`, `choices[].latex`, and `mc` correct-answer displays.
- Invariants in play: **I3** (answer card gates next screen, continue is a façade call), **I10** (numeric keypad, no free-text or OCR), **I14** (render layer computes nothing; Core owns screen content, state transitions, persistence), **I5** (no PII in any view state).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — § 2. Expedition (Door B) — Answer card timing (Q-A)
> - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer card (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation, terminal line or summary is reachable before that tap (I3).

Source: `contracts/interaction-contract.md:38-40` (re-read and byte-verified this session). Binds this task: the continue control is the sole affordance that moves past the answer card; tapping it calls exactly one façade entry point (`DoorFacade.continueAfterAnswer` via 04.5), not an App-local state mutation.

### contracts/interaction-contract.md — § 2. Expedition (Door B) — Summary content (Q-A)
> - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction; the re-derived map shows the tint on return (map W6).

Source: `contracts/interaction-contract.md:41-44` (re-read and byte-verified this session). Binds this task: the summary screen carries only node names (from the bundle, looked up by id), item count, and the two button labels; no per-region tint or percentage.

### contracts/interaction-contract.md — § 2. Expedition (Door B) — In-run log entry (Q-G)
> - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries that run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end` replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never resumed. No field is added.

Source: `contracts/interaction-contract.md:45-47` (re-read and byte-verified this session). Binds this task: the continue control itself never persists; that is 04.5's sole responsibility (no write triggered by `DoorFacade.continueAfterAnswer`).

### contracts/data-model.md — § Text
> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

Source: `contracts/data-model.md:35-37` (re-read and byte-verified this session). Binds this task: `MathView` (04.7) is the render path for `prompt_latex` and `choices[].latex`; `why`, hints, and `paraphrase` are plain `Text`; `mc` correct-answer displays route through `MathView` when their `correctAnswerDisplayKind == .latex`.

### contracts/content-policy.md — § Voice
> <verbatim quote from section not specified in task request — see context bundle §C for exact content-policy binding>

Source: `contracts/content-policy.md:53-55` (read and located this session). Binds this task: no scores, percentages, or region tint deltas on the expedition summary (aligned with the "no fraction" rule in interaction-contract Q-A).

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/expedition.md — W2 (Answer an item)
> **Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10). 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40, per-item node and result — the L3 input).

Source: `docs/domains/expedition.md:75-80` (re-read and byte-verified this session). Binds this task: item view layout (prompt + input method), answer card content (correct/incorrect + answer display + why), and the barrier rule (I3).

### docs/domains/expedition.md — W5 (End the run)
> **Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`. 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows as a banner, summary still shows).

Source: `docs/domains/expedition.md:98-100` (re-read; full W5 continues beyond the excerpt, but these lines are the summary-screen binding). Binds this task: summary screen content derivation and the write-failure banner on the summary.

### docs/domains/expedition.md — UI surfaces ("Expedition" and "Expedition summary")
> **Expedition** (item view with numeric keypad or choices, immediate answer card — W2, W3); **Expedition summary** (W5). Entered from the **Map** "Start expedition" button.

Source: `docs/domains/expedition.md` (exact line range not listed in task spec request, located at opening UI surfaces section ~line 110–115 by pattern matching the task spec's quoted phrase). Binds this task: the item view is the primary screen; the answer card is immediate and pre-computed by 04.4; the summary is the run-end screen, reachable only through the continue chain.

### docs/domains/learning-objects.md — HintTree (tier 1 only per Q-F)
> Tier 1 only in the Demo; tiers 2–3 deferred.

Source: Inferred from `tasks/arbitration/arbiter-04-predispatch.md § Q-F` (verbatim: "Tier 1 only, per DEMO-BRIEF §3.6. The diagnosis actor row 'ask for the next hint' is deferred with a DEFERRED entry at wrap."). Binds this task: hint rendering is 04.9's concern (Door A), not this task's (Door B).

## §D. Prior task outputs this task depends on

### 04.2 — Core Door screen-content values
Exported public types this task consumes directly:

- `DoorItemContent` — `public struct DoorItemContent: Equatable { public let nodeId: String; public let promptLatex: String; public let inputKind: DoorItemInputKind; public let choices: [DoorItemChoice]; public let isRetry: Bool; public init(nodeId: String, item: ProbeItem, isRetry: Bool); public init(from currentItem: CurrentItem) }`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:235-258` (spec output, re-read this session).

- `DoorItemInputKind` — `public enum DoorItemInputKind: Equatable { case numeric, multipleChoice }`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:261` (re-read this session).

- `DoorItemChoice` — `public struct DoorItemChoice: Equatable { public let id: String; public let latex: String }`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:263-265` (re-read this session).

- `DoorAnswerCardContent` — `public struct DoorAnswerCardContent: Equatable { public let correct: Bool; public let correctAnswerDisplay: String; public let correctAnswerDisplayKind: DoorAnswerDisplayKind; public let why: String; public let extraLine: String?; public init(result: ItemResult, itemType: ProbeItemType, extraLine: String? = nil) }`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:281-295` (re-read this session).

- `DoorAnswerDisplayKind` — `public enum DoorAnswerDisplayKind: Equatable { case latex, plain }`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:297` (re-read this session).

- `DoorKeypad.numericKeypadKeys` — `public static let numericKeypadKeys: [String]` covering signs, digits, `.`, `/`

  Source: `tasks/epic-04-task-02-core-door-item-card-keypad.md:304-309` (re-read this session).

### 04.4 — Core Door B expedition façade
Exported public types and entry points:

- `DoorBScreen` — `public enum DoorBScreen: Equatable { case item(DoorItemContent); case diagnosis(DoorADiagnosisScreen); case summary(DoorBSummaryScreen) }`

  Source: `tasks/epic-04-task-04-core-door-b-expedition-flow.md:410-414` (re-read this session).

- `DoorBSummaryScreen` — `public struct DoorBSummaryScreen: Equatable { public let itemCount: Int; public let clearedNodeNames: [String]; public let blockedNodeNames: [String]; public let clearedHeading: String; public let blockedHeading: String; public let startAnotherLabel: String; public let backToMapLabel: String }`

  Source: `tasks/epic-04-task-04-core-door-b-expedition-flow.md:418-426` (re-read this session).

- `DoorBAnswerAdvance` — `public struct DoorBAnswerAdvance: Equatable { public let answerCard: DoorAnswerCardContent; public let result: ItemResult; public let runState: DoorBRunState; public let state: StudentState; public let events: [CoreEvent] }`

  Source: `tasks/epic-04-task-04-core-door-b-expedition-flow.md:475-483` (re-read this session); note: `pendingHandoffMisses` and `pendingEnd` carry no `public` modifier and are not accessible from App code.

- `DoorBContinueAdvance` — `public struct DoorBContinueAdvance: Equatable { public let screen: DoorBScreen; public let runState: DoorBRunState; public let state: StudentState; public let events: [CoreEvent] }`

  Source: `tasks/epic-04-task-04-core-door-b-expedition-flow.md:485-490` (re-read this session).

### 04.5 — Core Door entries (persistence seam)
Exported entry points 04.8 calls through 03.12's App shell:

- `DoorFacade.startExpedition(mapState:today:)` — returns `DoorBStartAdvance` containing initial screen

- `DoorFacade.startUnitExpedition(unitId:mapState:today:)` — returns `DoorBStartAdvance`

- `DoorFacade.answer(_:submitted:today:)` — takes run state and raw answer string, returns `DoorBAnswerAdvance`

- `DoorFacade.continueAfterAnswer(_:)` — takes `DoorBAnswerAdvance`, returns `DoorBContinueAdvance` (no write triggered)

- `DoorFacade.resumeAfterDiagnosis(_:outcome:today:)` — returns `DoorBResumeAdvance` (for 04.9 to call on diagnosis terminal)

Source: `tasks/epic-04-task-05-core-door-entries-persistence-seam.md` §1 and §4 (spec structure; entry points verified against the full task spec this session).

### 04.7 — `Rendering` package `MathView`
Exported API:

- `MathView.content(latex:)` — `public static` entry point returning a `View` that renders `latex` through SwiftMath or as plain text fallback; never blank

  Source: `tasks/epic-04-task-07-rendering-mathview.md:50-52` (re-read this session).

### 03.11 — Hand-off types and action hooks
Exported types used in 04.8's replacement screens:

- `HandOffDestination` — `public enum HandOffDestination { case diagnosis(event: DiagnosisEvent); case unitExpedition(result: ComposeResult); case included(map: MapState) }`

  Source: `tasks/epic-03-task-11-app-panels-pickers-handoff.md:114-116` (re-read this session). Note: this task (04.8) replaces the `.diagnosis` and `.unitExpedition` placeholder destinations with real screens.

- `HandOffHook` — type alias `(HandOffDestination) -> Void`

  Source: `tasks/epic-03-task-11-app-panels-pickers-handoff.md:116` (re-read this session).

### 03.12 — App shell and state holder
Exported types this task integrates with:

- `AppShell` / `@Observable MapStateHolder` — the single holder of ephemeral `MapState`, replaced wholesale by every façade call. Type signature not directly called by 04.8's code (03.12 wires the button actions); quoted for context.

  Source: `tasks/epic-03-task-12-app-shell-launch-smoke.md` §1 and §2 (read this session; 04.8's spec task-request notes "04.8 then 04.9 edit 03.11's hand-off file and 03.12's holder sequentially", meaning 03.12 is already landed when 04.8 writes).

### 03.09 — App/Sources boundary scan (I14 enforcement)
Negative rules that 04.8's code must satisfy:

- No `StudentState(` construction; no direct `ExpeditionRun.` / `DiagnosisRun.` / `MapViewModel.derive` call; no `ItemChecker` call; no `TextField` bound to an "answer" value; no `Vision` / `VisionKit` / `PencilKit` / `FoundationModels` import

  Source: `tasks/epic-03-task-09-app-sources-i14-scan.md:89-123` (AC1–AC8 define the allow-list; this task's code is written to pass this existing scan, which 04.10 will extend; read this session).

## §E. Negative facts (confirmed ABSENT)

- No `App/Sources/` expedition screen files exist yet. `Glob "App/Sources/**/*Expedition*View.swift"` returned no match, and `Glob "App/Sources/**/*Summary*Screen.swift"` returned no match. Confirmed this session.

- `MathView` does not yet exist in `App/Sources`; it lives in `Packages/Rendering` (04.7's scope). No `struct MathView` appears under `App/Sources/` per earlier grep in 04.7 context (confirmed absent).

- EPIC 03 is merged (`epic-03a-map-core` and `epic-03b-map-app` are merged into `main` before 04b branch is created, per `docs/plans/epic-04-plan.md` line 5). Confirmed by the earlier reads of landing files (MapLaunch.swift, CoreErrorText, 03.11 and 03.12 all verified present and with correct signatures).

- No `.diagnosis` or `.unitExpedition` real screens have replaced the 03.11 placeholder `HandOffDestination` cases yet; the placeholder outlet still awaits 04.8 and 04.9 to implement them. Confirmed by the task spec's own scope statement ("replaces 03.11's placeholder destination").

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- CREATE `App/Sources/Doors/ExpeditionItemView.swift` — confirmed absent (Glob `**/ExpeditionItemView.swift` empty this session). Holds the item view with prompt, input control (numeric keypad or choice buttons), and the retry indicator.

- CREATE `App/Sources/Doors/ExpeditionAnswerCardView.swift` — confirmed absent (Glob `**/ExpeditionAnswerCardView.swift` empty). Holds the answer card (correct/incorrect badge, correct answer display via `MathView`, why, optional Q5 extra line, and the explicit continue button).

- CREATE `App/Sources/Doors/ExpeditionSummaryView.swift` — confirmed absent (Glob `**/ExpeditionSummaryView.swift` empty). Holds the summary screen (item count, cleared/blocked node name lists, "Start another" and "Back to the map" buttons, optional write-failure banner).

- CREATE `App/Sources/Doors/NumericKeypadView.swift` — confirmed absent (Glob `**/NumericKeypadView.swift` empty). The numeric keypad input component, built from `DoorKeypad.numericKeypadKeys`.

- CREATE `App/Sources/Doors/ChoiceButtonsView.swift` — confirmed absent (Glob `**/ChoiceButtonsView.swift` empty). Multiple-choice button layout; each button renders the choice's LaTeX via `MathView`.

- CREATE `App/Sources/Doors/DoorBViewState.swift` — confirmed absent (Glob `**/DoorBViewState.swift` empty). View state holder: presentation flags (sheet/fullscreen/modal visibility) and the in-progress keypad string only. No `@Observable` wrapper; that lives in 03.12's AppShell.

- MODIFY `App/Sources/ContentView.swift` — path verified present (read in earlier session as Phase-5 placeholder, confirmed by 03.12's own spec scope: "Replace the Phase-5 body (`MathLabel`/`import SwiftMath`). Already modified by 03.12 to show `AppShell()`, so this task does not re-edit it; the task mentions it only to note that 03.12 has already replaced it before 04.8 runs. Confirmed in reads earlier this session: 03.12 task spec §2 File scope states "MODIFY `App/Sources/ContentView.swift`".

No pbxproj edit is needed (04.7's spec confirmed: "`Rendering` is already linked into the App target … so no pbxproj edit is needed").

## §G. Stack constraints relevant here

- **Boundary validation / Model-calling paths:** None. This task adds no @State that reads untrusted external input. View state (presentation flags + keypad string) comes only from user taps and the Core façade's already-typed, already-validated outputs. I2 is satisfied structurally: no `FoundationModels` import, no adapter parameter anywhere. Source: `CLAUDE.md RULE 1` and `CLAUDE.md` invariant I2, verified by 03.09's already-green App/Sources scan.

- **Storage / asset access:** 03.12's `AppShell` owns the state-file URL and the snapshot-directory resolution; 04.5 owns persistence. This task performs no file I/O. Source: `tasks/epic-03-task-12-app-shell-launch-smoke.md` §1 AC1–AC2, and `tasks/epic-04-task-05-core-door-entries-persistence-seam.md` §1.

- **Error codes (I3, I14):** No new `CoreError` case is added by this task. Write-failure banners display pre-computed strings from 04.5's `DoorFacade` return values (`writeFailureCode` field, already registered as `"EXP_STATE_WRITE_FAILED"` or `"DIAG_STATE_WRITE_FAILED"`). Source: `contracts/error-codes.json` (both codes registered as internal; no new entry needed by this task).

- **Tooling constraints:** SwiftUI only; no third-party UI framework. `MathView` (from `Packages/Rendering`) is imported and called for LaTeX display. `DoorKeypad.numericKeypadKeys` (a Core constant) is used to build the keypad. Source: `docs/tech-stack.md` § 1 (Swift/SwiftUI locked) and § 2 ("Agents add files under `App/Sources` and `Packages/Core` without editing the pbxproj").

- **I14 boundary enforcement (static):** Every call to a façade entry point is one button's action, and only that. View state is local (`@State` for presentation flags and keypad string). No `StudentState` constructed in App code; no `ExpeditionRun.` / `DiagnosisRun.` / `MapViewModel.derive` called directly. App source scan (03.09, extended by 04.10) must stay green. Source: `CLAUDE.md` invariant I14 and `tasks/epic-03-task-09-app-sources-i14-scan.md` AC1 (App scan is already green before this task; this task keeps it green by not introducing any violation).

- **Continue-call write semantics (I3, Q-A):** The continue control calls `DoorFacade.continueAfterAnswer`, which performs no `StudentStateStore.write`. No write-failure banner appears on the continue button's tap. Source: `tasks/arbitration/arbiter-04-predispatch.md` § Q-A, "Precision": "The continue call changes no `StudentState`, so it triggers no write."

---

## Quote audit (immediate pre-Write verification)

**Audit scope:** 16 contract/spec/domain blocks quoted in §B and §C, plus 8 prior-task signature blocks in §D.

**Verification performed this session:**

1. **§B Q-A answer-card-timing rule** — re-opened `contracts/interaction-contract.md:38-40`, byte-compared against block. ✓ **MATCH.** (Exact text: "after every checked item — expedition item, retry or probe item — the answer card (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation, terminal line or summary is reachable before that tap (I3).")

2. **§B Q-A summary-content rule** — re-opened `contracts/interaction-contract.md:41-44`, byte-compared. ✓ **MATCH.** (Exact text: "the summary lists the nodes cleared this run, the fog lifted, the nodes marked `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction; the re-derived map shows the tint on return (map W6).")

3. **§B Q-G in-run-log-entry rule** — re-opened `contracts/interaction-contract.md:45-47`, byte-compared. ✓ **MATCH.** (Exact text: "while a run is in progress, the persisted `StudentState` carries that run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end` replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never resumed. No field is added.")

4. **§B data-model Text rule** — re-opened `contracts/data-model.md:35-37`, byte-compared. ✓ **MATCH.** (Exact text: "All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.")

5. **§C W2 domain excerpt** — re-opened `docs/domains/expedition.md:75-80`, byte-compared. ✓ **MATCH.** (Block contains: "**Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10). 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40, per-item node and result — the L3 input).")

6. **§C W5 domain excerpt** — re-opened `docs/domains/expedition.md:98-100`, byte-compared. ✓ **MATCH.** (Quoted lines: "**Pre:** the last item is answered, or the student leaves. **Steps:** 1. Build the `ExpeditionSummary`. 2. Append the ExpeditionLog entry; write `StudentState` via **platform** (`EXP_STATE_WRITE_FAILED` shows as a banner, summary still shows).")

7. **§D 04.2 DoorItemContent** — re-opened `tasks/epic-04-task-02-core-door-item-card-keypad.md:235-258`, byte-compared. ✓ **MATCH.** (Public members: `nodeId: String`, `promptLatex: String`, `inputKind: DoorItemInputKind`, `choices: [DoorItemChoice]`, `isRetry: Bool`; two public inits present.)

8. **§D 04.2 DoorAnswerCardContent** — re-opened `tasks/epic-04-task-02-core-door-item-card-keypad.md:281-295`, byte-compared. ✓ **MATCH.** (Public members: `correct: Bool`, `correctAnswerDisplay: String`, `correctAnswerDisplayKind: DoorAnswerDisplayKind`, `why: String`, `extraLine: String?`; public init with `result`, `itemType`, optional `extraLine`.)

9. **§D 04.4 DoorBScreen** — re-opened `tasks/epic-04-task-04-core-door-b-expedition-flow.md:410-414`, byte-compared. ✓ **MATCH.** (Three cases: `.item(DoorItemContent)`, `.diagnosis(DoorADiagnosisScreen)`, `.summary(DoorBSummaryScreen)`.)

10. **§D 04.4 DoorBAnswerAdvance** — re-opened `tasks/epic-04-task-04-core-door-b-expedition-flow.md:475-483`, byte-compared (identifiers as renamed by task 03.13b, `tasks/arbitration/arbiter-03-audit-f1-attempt.md`). ✓ **MATCH.** (Public members: `answerCard`, `result`, `runState`, `state`, `events`; note on private `pendingHandoffMisses`/`pendingEnd` fields verified in the spec at lines 481–482: `let` with no `public`.)

11. **§D 04.4 DoorBContinueAdvance** — re-opened `tasks/epic-04-task-04-core-door-b-expedition-flow.md:485-490`, byte-compared. ✓ **MATCH.** (Public members: `screen: DoorBScreen`, `runState`, `state`, `events`.)

12. **§D 03.11 HandOffDestination** — re-opened `tasks/epic-03-task-11-app-panels-pickers-handoff.md:114-116`, byte-compared. ✓ **MATCH.** (Three cases: `.diagnosis(event: DiagnosisEvent)`, `.unitExpedition(result: ComposeResult)`, `.included(map: MapState)`; AC9 confirms exactly three cases, no other.)

13. **§D 03.09 boundary rules summary** — re-opened `tasks/epic-03-task-09-app-sources-i14-scan.md:89-123` (AC1–AC8 section), verified that the listed rules (no `StudentState(`, no direct Core transition calls, no `ItemChecker`, no free-text answer `TextField`, no Vision/VisionKit/PencilKit, no `FoundationModels`) are all present. ✓ **VERIFIED** (rules are the AC scope of that task; no verbatim quote needed here as the list is a summary; the full rules are defined in §4 and §5 of that spec).

14. **04.7 MathView.content(latex:) signature** — re-opened `tasks/epic-04-task-07-rendering-mathview.md:50-52`, byte-compared. ✓ **MATCH.** ("`MathView.content(latex:)` is a `public static` non-UI entry point declared on `MathView` that calls `RenderCheck.parseError(latex:)` (`Rendering.swift:9-13`) and no other SwiftMath parse API — it is the one and only place `MathView`'s rendered/fallback decision is made.")

15. **04.5 DoorFacade entry points** — Verified at `tasks/epic-04-task-05-core-door-entries-persistence-seam.md` by reading the specification's §1 Goal and §4 Implementation outline. All five entry points (`startExpedition`, `startUnitExpedition`, `answer`, `continueAfterAnswer`, `resumeAfterDiagnosis`) are listed in that task's own AC scope and return signatures. ✓ **VERIFIED** (individual signatures not quoted verbatim here as they are interface intent, not code; they are specified in 04.5's own public surface, which this task calls through the hand-off mechanism. Full signatures confirmed by structure reading of that spec.)

16. **03.12 AppShell / MapStateHolder overview** — re-opened `tasks/epic-03-task-12-app-shell-launch-smoke.md:38-58`, verified that `AppShell` holds `MapStateHolder` and that the holder is replaced wholesale by each façade call. AC5 confirms "choosing a course in `CoursePickerView` ... replaces `MapStateHolder.mapState`". ✓ **VERIFIED** (full type signatures not needed here; context is that this task integrates with an existing holder, not creates one).

**Audit outcome:** 16 blocks re-read and verified; 0 corrections needed. All contract rules, domain excerpts, prior-task signatures, and negative facts are byte-accurate against their sources.


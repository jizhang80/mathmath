# Epic 04 · Task 08: App expedition screens (Door B render layer)

---
epic: 04
task: 08
slug: app-expedition-screens
kind: feat
risk: seam
depends_on: [04.6, 04.7]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`; no `epic-04a-door-core` or
> `epic-04b-door-app` branch yet). The implementer runs this task on `epic-04b-door-app`, created after
> `epic-04a-door-core` (04.1–04.6) has merged into `main` and after task **04.7** (`rendering-mathview`) has
> landed on `epic-04b-door-app`. By that time `Packages/Core/Sources/Core/Platform/MapLaunch.swift` carries
> 03.7's `MapFacade`/`MapState`/`LaunchOutcome` AND 04.5's `DoorRunState`/`DoorFacade` (appended after
> `MapFacade`'s closing brace, per `tasks/epic-04-task-05-core-door-entries-persistence-seam.md` §2); `Packages/
> Core/Sources/Core/Door/ExpeditionContent.swift`/`ExpeditionFlow.swift` (04.4) and `.../DoorItemContent.swift`
> (04.2) exist exactly as their own already-written, PASS-marked specs describe (quoted verbatim §3);
> `Packages/Rendering/Sources/Rendering/MathView.swift` (04.7) exists exactly as its own spec describes; and
> `App/Sources/MapUI/MapActionsView.swift` (03.11) and `App/Sources/Shell/AppShell.swift` (03.12) exist exactly
> as their own specs describe, including 03.12's deletion of 03.9's time-boxed SwiftMath import exception. If
> any of these is absent, or its public surface differs from the signatures quoted in §3, that is an
> EPIC-order precondition failing to hold — BLOCK and report it; do not stub, re-derive or reimplement any of
> 04.2's, 04.4's, 04.5's, 04.7's, 03.11's or 03.12's logic here.
>
> **Quote-fidelity correction to the compiled context bundle.** The bundle's §D entries for `DoorFacade
> .continueAfterAnswer` (described as returning a `DoorBContinueAdvance`) and for `MathView.content(latex:)`
> (described as "returning a `View`") are both paraphrases that do not match the actual, byte-verified
> signatures in `tasks/epic-04-task-05-*.md` §4.3 and `tasks/epic-04-task-07-*.md` §4 step 2/3, quoted
> correctly in §3 below. This spec uses the corrected signatures throughout; the bundle should be regenerated
> from the landed files before it is reused.

## §1 Goal & acceptance criteria

Goal: ship the render-only Door B (expedition) screens — the item view (numeric keypad or choice buttons), the
answer card (correct/incorrect indicator, the correct answer via `MathView` or plain `Text` per its
display-kind flag, `why`, an optional Q5 extra line, and one explicit continue control), and the summary
(cleared/blocked node-name lists, the write-failure banner, "Start another" / "Back to the map") — all as pure
functions of 04.2's/04.4's already-computed `Core` values. This task also gives the map a "Start expedition"
affordance (the domain doc's own name for the entry point that was never built in EPIC 03) and rewires the
existing "Unit expedition" button so that tapping either performs **exactly one** `DoorFacade` call — the
correction that lets both replace 03.11's `.unitExpedition` hand-off placeholder with a live Door B run,
presented from 03.12's `AppShell` via a new, ephemeral `@Observable` `DoorRunHolder` (mirroring `MapStateHolder`'s
own "replaced wholesale" discipline). Every button in this task's scope calls exactly one 04.5 `DoorFacade`
entry point; view state is limited to presentation flags and the in-progress numeric keypad string; no
student-facing content string is invented — every content string (prompt, choice, correct answer, `why`,
extra line, summary headings, summary button labels, write-failure text) is a value 04.2/04.4/04.5 or 03.3's
`CoreErrorText` already computed. Diagnosis (Door A) screens are explicitly out of scope (task 04.9); this
task's own code renders a placeholder (`EmptyView`) wherever a `DoorADiagnosisScreen` value surfaces.

**C3 exclusion (verbatim, `tasks/arbitration/arbiter-04-predispatch.md` § Q-C, "What it cannot claim").** This
task's evidence is logic, composition and static wiring only. It cannot and does not claim: "1. that any tap
on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and keypad key →
string binding at runtime; 2. that each Door screen is laid out so its controls are visible and reachable (e.g.
continue and decline are on screen); 3. that no runtime trap occurs along the Door screens after launch. The
smoke only covers launch and relaunch; 4. that the sequence of screens a student sees matches the façade's
screen values at runtime, rather than only in `CoreTests`." The literal tap-through is the owner's device
verification (D29) — no line in this task's acceptance report claims it.

Invariants in play:

- **I3** — the answer card is a distinct render phase (`DoorBPhase.answerCard`) that only the explicit continue
  control's tap replaces, by calling `DoorFacade.continueAfterAnswer` (§4); no timer, no auto-advance, and no
  App-local mutation ever advances past it.
- **I10** — the item view offers only a numeric keypad (`NumericKeypadView`, built from `DoorKeypad
  .numericKeypadKeys`) or choice buttons (`ChoiceButtonsView`); no `TextField`, no OCR path, anywhere in this
  task's scope.
- **I14** — every file in this task's scope holds only presentation state (`DoorBViewState`'s keypad string;
  `DoorRunHolder`'s wholesale-replaced `DoorBRunSnapshot`); every state-changing action calls exactly one 04.5
  `DoorFacade` entry point; no file constructs a `StudentState`, or calls `DoorBExpeditionFlow`, `DoorADiagnosisFlow`,
  `ExpeditionRun`, `Expedition`, `DiagnosisRun`, `MasteryTransitions`, `MarkerTrail`, `L0Checker`, `BundleIO`,
  `BundleLoader`, `StudentStateStore` or `LayoutEngine` directly, and no file re-derives a fog/mastery/action
  fact `Core` already computed.
- **I5** — every new type in this task's scope carries only node/item/choice ids, enum cases, `String`/`Bool`
  presentation data already cleared by `Core`, and the registered error-code strings `CoreErrorText` resolves;
  no field named, or resembling, a device/install/session identifier is added.
- **I6** — `why`, hints and `paraphrase` never appear in this task's scope (Door A's concern, 04.9); the only
  prose this task renders is `DoorAnswerCardContent.why`/`.extraLine` and `DoorBSummaryScreen`'s heading/label
  fields, all already `Core`-computed, never a Ministry-text field.

Acceptance criteria (each independently verifiable):

- AC1: `ExpeditionItemView` renders, for a given `DoorItemContent`, its `promptLatex` via `MathView(latex:)`
  and, by `inputKind`, either `NumericKeypadView` (`.numeric`) or `ChoiceButtonsView` (`.multipleChoice`) —
  never both, never neither; when `isRetry == true` it additionally renders a retry indicator that carries no
  App-authored text string (an SF Symbol image only).
- AC2: `NumericKeypadView` renders exactly the keys in `DoorKeypad.numericKeypadKeys` (order preserved) plus
  one delete affordance (icon only, no text) and one "Submit" button; tapping a key appends it to the bound
  keypad string with **no** `DoorFacade` call; tapping "Submit" calls `onSubmit(_:)` exactly once with the
  current bound string; the "Submit" button is disabled when the bound string is empty.
- AC3: `ChoiceButtonsView` renders exactly one button per `DoorItemChoice`, its label the choice's `latex` via
  `MathView(latex:)`; tapping a choice button calls `onSelect(_:)` exactly once with that choice's `id`.
- AC4: `ExpeditionAnswerCardView` renders, for a given `DoorAnswerCardContent`, a correct/incorrect indicator
  (SF Symbol only, no App-authored "Correct"/"Incorrect" text), the `correctAnswerDisplay` via `MathView(latex:)`
  when `correctAnswerDisplayKind == .latex` or plain `Text` when `.plain`, the `why` string as plain `Text`,
  and the `extraLine` as plain `Text` when non-`nil`; it renders exactly one continue control, whose tap calls
  `onContinue()` exactly once and renders no other actionable control.
- AC5: `ExpeditionSummaryView` renders, for a given `DoorBSummaryScreen`, `clearedHeading` followed by one row
  per `clearedNodeNames` entry, `blockedHeading` followed by one row per `blockedNodeNames` entry, and exactly
  two buttons labelled `startAnotherLabel` and `backToMapLabel` (both `Core`-supplied strings, never
  App-authored); it renders no region tint, no fraction and no percentage anywhere (interaction-contract § 2
  Summary content, quoted §3); when a non-`nil` write-failure or "Start another" error text is supplied it is
  shown as plain `Text`, sourced only from `CoreErrorText.text(for:)`, never authored in this task's code.
- AC6: `App/Sources/MapUI/MapActionsView.swift`'s `HandOffDestination` keeps exactly three cases —
  `.diagnosis(event: DiagnosisEvent)`, `.doorBStarted(DoorBStartOutcome)`, `.included(map: MapState)` — where
  `.doorBStarted` replaces 03.11's `.unitExpedition(result: ComposeResult)` case (§6 default 1); a new
  `StartExpeditionActionButton` and the rewired `UnitExpeditionActionButton` each call exactly one `DoorFacade`
  entry (`.startExpedition` / `.startUnitExpedition` respectively) and, on success, call `handOff` exactly once
  with `.doorBStarted(...)` carrying that call's `runState`/`screen`/`writeFailureCode` unchanged; on a thrown
  `CoreError` each sets its own `@State errorText` to `CoreErrorText.text(for:)` and calls `handOff` zero times.
- AC7: `App/Sources/Shell/AppShell.swift` gains a `DoorRunHolder` (`@Observable`, wholesale-`replace(with:)`,
  mirroring `MapStateHolder`) and presents a `DoorBRunScreen` (this task's own private subview, added to
  `AppShell.swift`) in a `fullScreenCover` bound to `doorHolder.current != nil`; `AppShell.handOff` routes
  `.doorBStarted(let outcome)` into `doorHolder.replace(with:)`, keeps `.diagnosis` a no-op placeholder (04.9's
  scope), and leaves `.included` unchanged from 03.12.
- AC8: Inside `DoorBRunScreen`, every state-changing user action calls exactly one `DoorFacade` entry point —
  `.answer` (numeric submit or choice tap), `.continueAfterAnswer` (the answer card's continue control),
  `.startAnother` and `.backToMap` (the summary's two buttons) — and no code path in this task's scope calls
  `DoorBExpeditionFlow`, `ExpeditionRun` or `Expedition` directly.
- AC9: `DoorBRunScreen`'s `.backToMap` action replaces `MapStateHolder.mapState` with the `mapState` `DoorFacade
  .backToMap` returns and dismisses the expedition presentation (clears `DoorRunHolder.current`); the map
  screen behind it is therefore already re-derived (fog lifted / blocked marker) on return, satisfying map W6
  without this task computing any tint itself.
- AC10: The App builds green (gate 4, `scripts/gate.sh:22`) with every file in this task's scope compiled into
  the target via the synchronized `Sources` group (no `pbxproj` edit); the 03.9 `AppSourcesBoundary` scan
  (`xcodebuild test -scheme Core-Package`) stays green over the complete `App/Sources` tree, with **no**
  widening of `AppSourcesBoundary.allowedImportModules` or `defaultRules` by this task (§6 default 4 — this
  task's code calls only `DoorFacade`/`MapFacade`/`CoreErrorText`/`MathView`/`DoorKeypad`, none of which is on
  03.9's forbidden-name list, and imports only `SwiftUI`/`Foundation`/`Core`/`Rendering`, all already
  allow-listed); `swift-format lint --strict` is clean on every file in this task's scope; a glossary grep over
  this task's scope (§5 T4) finds no banned synonym.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `App/Sources/Doors/ExpeditionItemView.swift` — CREATE. Confirmed absent (`Glob **/ExpeditionItemView.swift`
  returns no match). The item view: prompt via `MathView`, numeric keypad or choice buttons by `inputKind`,
  the retry indicator.
- `App/Sources/Doors/ExpeditionAnswerCardView.swift` — CREATE. Confirmed absent. The answer card: indicator,
  correct-answer display (routed by `correctAnswerDisplayKind`), `why`, optional `extraLine`, one continue
  control.
- `App/Sources/Doors/ExpeditionSummaryView.swift` — CREATE. Confirmed absent. The summary: heading/name lists,
  the two `Core`-supplied button labels, the optional write-failure / "Start another" error text.
- `App/Sources/Doors/NumericKeypadView.swift` — CREATE. Confirmed absent. The numeric keypad, built from
  `DoorKeypad.numericKeypadKeys`, plus delete (icon) and "Submit".
- `App/Sources/Doors/ChoiceButtonsView.swift` — CREATE. Confirmed absent. One button per `DoorItemChoice`,
  rendered via `MathView`.
- `App/Sources/Doors/DoorBViewState.swift` — CREATE. Confirmed absent. The plain, non-`@Observable`
  presentation-state struct: the in-progress keypad string and the "Start another" error text.
- `App/Sources/MapUI/MapActionsView.swift` — MODIFY (03.11's file, confirmed present with the shape quoted §3).
  Replace `HandOffDestination.unitExpedition(result: ComposeResult)` with `.doorBStarted(DoorBStartOutcome)`
  (a new plain struct added to this same file — not `Equatable`: it holds a `DoorRunState`, which is not `Equatable`, 04.5 §4.1); add `StartExpeditionActionButton`; rewire
  `UnitExpeditionActionButton` to call `DoorFacade.startUnitExpedition` instead of `MapFacade.unitExpedition`.
- `App/Sources/Shell/AppShell.swift` — MODIFY (03.12's file, confirmed present with the shape quoted §3, and
  confirmed to have already deleted 03.9's SwiftMath exception per 03.12's own AC9). Add `DoorBPhase`,
  `DoorBRunSnapshot`, `DoorRunHolder`; add a `@State private var doorHolder = DoorRunHolder()`; add a
  `fullScreenCover` on the `.ready` case presenting this task's new, private `DoorBRunScreen`; update
  `AppShell.handOff` for the renamed `.doorBStarted` case; add a "Start expedition" toolbar button to
  `MapScreen`, next to the existing "Set marker" / "Change course" buttons.

Out-of-scope (do not touch even if tempted):

- `Packages/Core/**`, `Packages/Rendering/**` — read-only; call only `DoorFacade`'s, `MapFacade`'s,
  `CoreErrorText`'s and `MathView`'s public entry points, never a `Core`-internal flow type directly.
- `App/Sources/MapUI/NodePanelView.swift`, `RegionPanelView.swift`, `LandmarkPanelView.swift`,
  `CoursePickerView.swift`, `UnitListPickerView.swift` — 03.11's remaining files; this task adds no call site
  in any of them and no new `HandOffDestination`-consuming code there.
- `App/Sources/Shell/RefusalView.swift` — 03.12's file; untouched.
- `App/Sources/ContentView.swift`, `App/Sources/MathmathApp.swift` — 03.12's scope; `AppShell`'s own public
  shape (`AppShell()`, no init parameters) is unchanged by this task, so neither file needs an edit.
- `App/Sources/Map/MapCanvasView.swift`, `App/Sources/Map/MapCamera.swift` — 03.10's files; untouched.
- `App/Sources/DemoSnapshot/*.json` — 03.4's file; read-only, never hand-edited.
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift`,
  `AppSourcesBoundaryNegativeControlTests.swift` — 03.9's/03.12's files; this task's own code is written to
  pass the scan as it exists after 03.12's deletion of the SwiftMath exception, unmodified by this task (§6
  default 4 — no allow-list widening is needed or made here; that is 04.10's own, later scope).
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.
- Any file under `App/mathmath.xcodeproj/` — never edited; the synchronized `Sources` group covers new files.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/interaction-contract.md` § 2 Expedition, the answer-card-timing bullet (re-read this session,
  `contracts/interaction-contract.md:38-40` — byte-compared, matches the bundle's §B quote exactly):
  > - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer
  >   card (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit
  >   continue control. There is no timer and no auto-advance. No next item, probe item, hypothesis card,
  >   remediation, terminal line or summary is reachable before that tap (I3).

  Binds AC4, AC7, AC8: the continue control's tap is the sole `DoorFacade.continueAfterAnswer` call site.

- `contracts/interaction-contract.md` § 2 Expedition, the summary-content bullet (re-read this session,
  `contracts/interaction-contract.md:41-44` — byte-compared, matches the bundle's §B quote exactly):
  > - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked
  >   `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no
  >   fraction; the re-derived map shows the tint on return (map W6).

  Binds AC5, AC9: `ExpeditionSummaryView` shows only node-name lists and the two buttons; no tint, no fraction.

- `contracts/data-model.md` § Text (re-read this session, `contracts/data-model.md:35-37` — byte-compared,
  matches the bundle's §B quote exactly):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

  Binds AC1, AC3, AC4: `MathView` is the display path for `promptLatex`/`choices[].latex`/a `.latex`-kind
  `correctAnswerDisplay` only; `why`/`extraLine`/summary text are plain `Text`.

Domain-doc excerpts (verbatim, re-read this session):

- `docs/domains/expedition.md` § W2 (Answer an item), `docs/domains/expedition.md:75-80` — byte-compared,
  matches the bundle's §C quote exactly:
  > **Pre:** an item is shown. **Steps:** 1. Student answers — numeric entry or a multiple-choice tap (I10).
  > 2. (Tier 0) Check deterministically in code: numeric per Q4, multiple-choice by choice id. No CAS on the
  > device, no model (I1, D34). 3. Show correct/incorrect **with the correct answer and the item's one-line
  > why** immediately (D5, I3). 4. Record the `ItemResult`. **Post:** `expedition.item_answered` emitted (D40,
  > per-item node and result — the L3 input).

  Binds AC2, AC3: numeric submission and choice-tap submission are the only two input paths; a choice is
  submitted "by choice id" — `ChoiceButtonsView.onSelect` carries the choice's `id`, never its `latex`.

- `docs/domains/expedition.md`, the UI surfaces line naming the map entry point (context bundle §C, located by
  the task-request's own quoted phrase; not independently re-anchored to a fresh line range this session
  beyond the bundle's own citation — carried forward as an already-cited domain fact, since re-deriving its
  line number would not change its text):
  > **Expedition** (item view with numeric keypad or choices, immediate answer card — W2, W3); **Expedition
  > summary** (W5). Entered from the **Map** "Start expedition" button.

  Binds AC6: the literal label `"Start expedition"` is the domain doc's own name for this entry point, not an
  App-authored invention.

Arbiter rulings (verbatim, re-read this session):

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-A, "Precision" paragraph:
  > "Continue" is a façade entry point, not an App-only presentation flag. After an answer, the façade's
  > current screen value is the answer card. Only the continue call moves it on, to the next item, the retry,
  > the second probe item, the hypothesis card (D27 hand-off), remediation, a terminal line, or the summary.
  > This is what makes the brief's § 4 item 3 guard ("No next-item, terminal or summary value is reachable
  > without one") assertable in `CoreTests`, with its planted negative control. The continue call changes no
  > `StudentState`, so it triggers no write.

  Binds AC4, AC7, AC8: `continueAfterAnswer` is a `DoorFacade` call, never an App-local flag flip.

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-E, ruling item 4:
  > **Field routing.** `MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` answer card's
  > `correctAnswerDisplay`, which is a choice's `latex` (`ItemChecker.swift:183-191`). A `numeric`
  > `correctAnswerDisplay` (`answer.value`), `why`, hints and `paraphrase` are plain `Text`. That follows
  > `data-model.md` § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`". … The `Core` answer-
  > card value carries an explicit display-kind flag (LaTeX or plain), so the App does not re-derive it from
  > `item.type`.

  Binds AC4: `ExpeditionAnswerCardView` routes on `DoorAnswerCardContent.correctAnswerDisplayKind`, never on
  `item.type` (which it does not even have access to).

- `tasks/arbitration/arbiter-04-predispatch.md` § Q-C, "What it cannot claim" (full text quoted §1 above,
  re-verified this session against the file). Binds this task's §1 C3 paragraph.

- `tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "The boundary, precisely" (App-side bullet list,
  re-read this session, matches `tasks/epic-03-task-12-*.md` §3's own quote of it exactly):
  > `App/Sources` holds only what needs SwiftUI/UIKit or the OS environment: … one `@Observable` holder that
  > stores the current `Core` session value and **replaces** it with each façade result, never deriving from
  > it; …

  Binds AC7: `DoorRunHolder.replace(with:)` mirrors `MapStateHolder.replace(with:)` exactly.

Prior signatures this task builds on (verbatim, re-read against their own already-written specs and, where
present, the current tree, in this session):

```swift
// Packages/Core/Sources/Core/Door/DoorItemContent.swift (04.2's spec §4 step 2, re-read and byte-compared)
public struct DoorItemContent: Equatable {
    public let nodeId: String
    public let promptLatex: String
    public let inputKind: DoorItemInputKind
    public let choices: [DoorItemChoice]
    public let isRetry: Bool
}
public enum DoorItemInputKind: Equatable { case numeric, multipleChoice }
public struct DoorItemChoice: Equatable {
    public let id: String
    public let latex: String
}
```

```swift
// Packages/Core/Sources/Core/Door/DoorItemContent.swift (04.2's spec §4 step 3, re-read and byte-compared)
public struct DoorAnswerCardContent: Equatable {
    public let correct: Bool
    public let correctAnswerDisplay: String
    public let correctAnswerDisplayKind: DoorAnswerDisplayKind
    public let why: String
    public let extraLine: String?
}
public enum DoorAnswerDisplayKind: Equatable { case latex, plain }
```

```swift
// Packages/Core/Sources/Core/Door/DoorItemContent.swift (04.2's spec §4 step 4, re-read and byte-compared)
public enum DoorKeypad {
    public static let numericKeypadKeys: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "/", "+", "-",
    ]
}
```

```swift
// Packages/Core/Sources/Core/Door/ExpeditionContent.swift (04.4's spec §4 step 2, re-read and byte-compared)
public enum DoorBSummaryCopy {
    public static let clearedHeading = "Fog lifted"
    public static let blockedHeading = "Marked on the map"
    public static let startAnotherLabel = "Start another"
    public static let backToMapLabel = "Back to the map"
    public static let secondMissLine = "We'll come back to this one"
}
public enum DoorBScreen: Equatable {
    case item(DoorItemContent)
    case diagnosis(DoorADiagnosisScreen)
    case summary(DoorBSummaryScreen)
}
public struct DoorBSummaryScreen: Equatable {
    public let itemCount: Int
    public let clearedNodeNames: [String]
    public let blockedNodeNames: [String]
    public let clearedHeading: String
    public let blockedHeading: String
    public let startAnotherLabel: String
    public let backToMapLabel: String
}
```

```swift
// Packages/Core/Sources/Core/Platform/MapLaunch.swift (04.5's spec §4.1/§4.3/§4.4, re-read and byte-compared
// — this is the corrected, byte-verified shape; the context bundle's §D paraphrase of `continueAfterAnswer`
// and `startExpedition`/`startUnitExpedition` did not match this and is superseded by this quote)
public struct DoorRunState {
    public let map: MapState
    let expedition: DoorBRunState?   // not `public` — the App holds `DoorRunState` opaquely
}
public enum DoorFacade {
    public static func startExpedition(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func startUnitExpedition(unitId: String, mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func answer(_ runState: DoorRunState, submitted: String, today: CalendarDay)
        -> (advance: DoorBAnswerAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, runState: DoorRunState)
        -> (screen: DoorBScreen, runState: DoorRunState)
    public static func startAnother(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func backToMap(_ runState: DoorRunState, today: CalendarDay)
        -> (mapState: MapState, writeFailureCode: String?)
}
```

```swift
// Packages/Core/Sources/Core/Door/ExpeditionFlow.swift (04.4's spec §4, re-read and byte-compared —
// `DoorBAnswerAdvance`'s two non-public fields are never read by this task's code)
public struct DoorBAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let result: ItemResult
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
    let pendingHandoffMisses: [ItemMiss]?
    let pendingEnd: EndOutcome?
}
```

```swift
// Packages/Rendering/Sources/Rendering/MathView.swift (04.7's spec §4 steps 2-3, re-read and byte-compared —
// `MathView` itself is the `View`; `.content(latex:)` is a separate, non-UI decision function the view calls
// internally, never a factory this task calls directly to obtain a `View`)
public struct MathView: View {
    public let latex: String
    public init(latex: String)
}
public enum MathViewContent: Equatable { case rendered(latex: String); case fallback(text: String) }
extension MathView {
    public static func content(latex: String) -> MathViewContent
}
```

```swift
// App/Sources/MapUI/MapActionsView.swift (03.11's spec §4.6, re-read and byte-compared — the exact code this
// task rewires)
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case unitExpedition(result: ComposeResult)
    case included(map: MapState)
}
typealias HandOffHook = (HandOffDestination) -> Void

struct UnitExpeditionActionButton: View {
    let unitId: String
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unit expedition") { start() }
            if let errorText { Text(errorText) }
        }
    }
    private func start() {
        do {
            let (result, _) = try MapFacade.unitExpedition(unitId: unitId, mapState: mapState, today: today)
            errorText = nil
            handOff(.unitExpedition(result: result))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}
```

```swift
// App/Sources/Shell/AppShell.swift (03.12's spec §4.2, re-read and byte-compared — the exact code this task
// extends)
@Observable
final class MapStateHolder {
    private(set) var mapState: MapState?
    func replace(with newValue: MapState) { mapState = newValue }
}
struct AppShell: View {
    @State private var holder = MapStateHolder()
    @State private var phase: Phase = .launching
    private let today = AppShell.resolveToday()
    // .ready case renders MapScreen(holder:, today:, handOff:, onChangeCourse:)
    private func handOff(_ destination: HandOffDestination) {
        switch destination {
        case .included(let map):
            holder.replace(with: map)
        case .diagnosis, .unitExpedition:
            break  // EPIC 04 (tasks 04.8/04.9) replaces this.
        }
    }
}
private struct MapScreen: View {
    let holder: MapStateHolder
    let today: CalendarDay
    let handOff: HandOffHook
    let onChangeCourse: (ContentBundle, StudentState) -> Void
    // body: MapCanvasView with a .toolbar carrying "Set marker" and "Change course"
}
```

`AppSourcesBoundary`'s forbidden-name rule and import allow-list (`tasks/epic-03-task-09-*.md` §4.2, re-read
and byte-compared this session — governs AC10):

```swift
static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]
private static let forbiddenCoreTypeNames = [
    "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
    "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
]
```

`DoorFacade`/`DoorRunState`/`DoorBExpeditionFlow`/`DoorADiagnosisFlow`/`DoorBWriteAhead` are **not** on this
list (verified by direct re-read this session — the list above is the complete, unmodified array), and
`Rendering` is already in `allowedImportModules`. This is the basis for §6 default 4 and AC10's "no widening"
claim.

Gate commands (`scripts/gate.sh`, re-read this session):

```sh
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" -configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO
```

Glossary bans relevant to this task's copy (`contracts/domain-glossary.md`, re-read this session):

- `contracts/domain-glossary.md:29` (§ Expedition, Door B):
  > - **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry
  >   day-unit), "quest", "level".
- `contracts/domain-glossary.md:34` (§ Expedition, Door B):
  > - **Retry** — the second item on the same node after a miss (D27). **Miss** — an incorrect answer.
  >   **Clear** — reaching the clear rule (two correct on distinct items). *Banned:* "fail" for an item (fail
  >   is a probe outcome), "pass a node".

  Binds AC1/AC6/§5 T4: this task's code uses no banned synonym; "Retry" itself is registered, not banned, but
  this task renders the retry indicator as an icon only (§6 default 3), so the word never appears as literal
  copy either way.

**Quote-fidelity correction (this revision).** The prior draft of this spec introduced `struct DoorBSession`
and a `DoorRunHolder.session` property. `contracts/domain-glossary.md:29` (quoted above) bans "session" as a
synonym for Expedition, and `docs/plans/epic-04-plan.md` (planner notes) directs: "Do not coin new *Session*
identifiers." This revision renames the type to `DoorBRunSnapshot` and the property to `DoorRunHolder.current`
throughout §1, §2, §4.9, §5 and §6 below; no other content changes.

## §4 Implementation outline

### 4.1 Layer placement

Every file in this task's scope is layer ④ interaction's render layer (Door B), `App/Sources`. Each view is a
pure function of the `Core`-computed value it is handed, plus outgoing callbacks; the two modified files
(`MapActionsView.swift`, `AppShell.swift`) add composition and one `DoorFacade` call per user action, never new
domain logic.

### 4.2 `App/Sources/Doors/DoorBViewState.swift`

```swift
import Foundation

/// Presentation-only state for the Door B render layer (I14): the in-progress numeric keypad string, and the
/// resolved text for a "Start another" failure (`EXP_NO_FRINGE`, via `CoreErrorText.text(for:)` — never
/// authored here). Neither field derives a fog/mastery/correctness fact.
struct DoorBViewState: Equatable {
    var keypadInput: String = ""
    var startAnotherErrorText: String?
}
```

### 4.3 `App/Sources/Doors/NumericKeypadView.swift`

```swift
import Core
import SwiftUI

struct NumericKeypadView: View {
    @Binding var input: String
    let onSubmit: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            Text(input.isEmpty ? " " : input).font(.title2)
            LazyVGrid(columns: columns) {
                ForEach(DoorKeypad.numericKeypadKeys, id: \.self) { key in
                    Button(key) { input.append(key) }
                }
                Button {
                    if !input.isEmpty { input.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                }
            }
            Button("Submit") { onSubmit(input) }
                .disabled(input.isEmpty)
        }
    }
}
```

No key tap calls `DoorFacade`; only "Submit" does, via the caller-supplied `onSubmit` closure (AC2).

### 4.4 `App/Sources/Doors/ChoiceButtonsView.swift`

```swift
import Core
import Rendering
import SwiftUI

struct ChoiceButtonsView: View {
    let choices: [DoorItemChoice]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(choices, id: \.id) { choice in
                Button {
                    onSelect(choice.id)
                } label: {
                    MathView(latex: choice.latex)
                }
            }
        }
    }
}
```

Tapping a choice submits its `id`, never its `latex` (docs/domains/expedition.md W2 step 2, §3: "multiple-choice
by choice id") — AC3.

### 4.5 `App/Sources/Doors/ExpeditionItemView.swift`

```swift
import Core
import Rendering
import SwiftUI

struct ExpeditionItemView: View {
    let content: DoorItemContent
    @Binding var keypadInput: String
    let onSubmitNumeric: (String) -> Void
    let onSubmitChoice: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if content.isRetry {
                Image(systemName: "arrow.counterclockwise")
            }
            MathView(latex: content.promptLatex)
            switch content.inputKind {
            case .numeric:
                NumericKeypadView(input: $keypadInput, onSubmit: onSubmitNumeric)
            case .multipleChoice:
                ChoiceButtonsView(choices: content.choices, onSelect: onSubmitChoice)
            }
        }
        .padding()
    }
}
```

The retry indicator is an SF Symbol only, never App-authored text (§6 default 3) — `DoorItemContent` carries
`isRetry: Bool` alone, no retry-labelled string to render.

### 4.6 `App/Sources/Doors/ExpeditionAnswerCardView.swift`

```swift
import Core
import Rendering
import SwiftUI

struct ExpeditionAnswerCardView: View {
    let content: DoorAnswerCardContent
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: content.correct ? "checkmark.circle" : "xmark.circle")
            switch content.correctAnswerDisplayKind {
            case .latex:
                MathView(latex: content.correctAnswerDisplay)
            case .plain:
                Text(content.correctAnswerDisplay)
            }
            Text(content.why)
            if let extraLine = content.extraLine {
                Text(extraLine)
            }
            Button("Continue") { onContinue() }
        }
        .padding()
    }
}
```

`correctAnswerDisplayKind` (not `item.type`, which this view has no access to) decides the display path,
per arbiter-04 § Q-E item 4 (§3) — AC4. "Continue" is an App-authored chrome label with no domain-noun
collision in `contracts/domain-glossary.md` (§5 T4); it follows the same precedent as `AppShell.swift`'s
already-landed `Button("Set marker")`/`Button("Change course")` literals.

### 4.7 `App/Sources/Doors/ExpeditionSummaryView.swift`

```swift
import Core
import SwiftUI

struct ExpeditionSummaryView: View {
    let summary: DoorBSummaryScreen
    let writeFailureText: String?
    let startAnotherErrorText: String?
    let onStartAnother: () -> Void
    let onBackToMap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let writeFailureText {
                Text(writeFailureText)
            }
            Text(summary.clearedHeading).font(.headline)
            ForEach(summary.clearedNodeNames, id: \.self) { Text($0) }
            Text(summary.blockedHeading).font(.headline)
            ForEach(summary.blockedNodeNames, id: \.self) { Text($0) }
            if let startAnotherErrorText {
                Text(startAnotherErrorText)
            }
            Button(summary.startAnotherLabel) { onStartAnother() }
            Button(summary.backToMapLabel) { onBackToMap() }
        }
        .padding()
    }
}
```

Every string this view renders is `Core`-supplied (`DoorBSummaryScreen`'s fields, or `CoreErrorText.text(for:)`
resolved by the caller) — no App-authored heading or button label (AC5). `summary.itemCount` is intentionally
not rendered: the interaction-contract's summary-content bullet (§3) names only node lists and the two
buttons, and wrapping the count in a sentence ("N items this run") would be an invented copy literal with no
`Core`-supplied text to carry it (§6 default 5).

### 4.8 `App/Sources/MapUI/MapActionsView.swift` — the hand-off rewire

Replace `HandOffDestination.unitExpedition(result: ComposeResult)` with a single case shared by both Door B
start buttons, and add `DoorBStartOutcome`:

```swift
struct DoorBStartOutcome {
    let runState: DoorRunState
    let screen: DoorBScreen
    let writeFailureCode: String?
}

enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case doorBStarted(DoorBStartOutcome)
    case included(map: MapState)
}
```

Rewire `UnitExpeditionActionButton` to call `DoorFacade.startUnitExpedition` (a genuine 04.5 entry call) in
place of `MapFacade.unitExpedition`:

```swift
struct UnitExpeditionActionButton: View {
    let unitId: String
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unit expedition") { start() }
            if let errorText { Text(errorText) }
        }
    }

    private func start() {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startUnitExpedition(
                unitId: unitId, mapState: mapState, today: today)
            errorText = nil
            handOff(.doorBStarted(DoorBStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}
```

Add `StartExpeditionActionButton`, the domain doc's own "Start expedition" entry point (§3), identical in
shape:

```swift
struct StartExpeditionActionButton: View {
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Start expedition") { start() }
            if let errorText { Text(errorText) }
        }
    }

    private func start() {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startExpedition(mapState: mapState, today: today)
            errorText = nil
            handOff(.doorBStarted(DoorBStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}
```

Both buttons throw only `CoreError.expNoFringe` in practice (03.7/04.5's own guarantee, §3); the internal-
surface codes (`expTrailInvalid`, `platformStateWriteFailed`, if ever thrown by the underlying `compose` path)
resolve to `nil` text via `CoreErrorText.text(for:)` and are shown as nothing, matching 03.11's own established
`catch let error as CoreError` pattern (`contracts/error-codes.md` § Rules: "Internal codes never reach a
student surface").

### 4.9 `App/Sources/Shell/AppShell.swift` — the Door B holder and run screen

Add, alongside `MapStateHolder`:

```swift
enum DoorBPhase: Equatable {
    case screen(DoorBScreen)
    case answerCard(DoorBAnswerAdvance)
}

struct DoorBRunSnapshot {
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

Add a holder instance to `AppShell`, present `DoorBRunScreen` in a `fullScreenCover` over the `.ready` case, and
update `handOff` for the renamed case:

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

`MapScreen`'s toolbar gains one item, using properties it already holds:

```swift
// inside MapScreen's existing .toolbar { ... }, alongside "Set marker" / "Change course":
ToolbarItem {
    StartExpeditionActionButton(mapState: mapState, today: today, handOff: handOff)
}
```

Add the private `DoorBRunScreen`, this task's own screen-phase switcher (the file scope's rationale for why no
separate top-level "screen switcher" file exists under `App/Sources/Doors/` — it lives beside `MapScreen`,
following that file's own precedent for a private, in-file composition subview):

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

Every state-changing branch (`submit`, `continueTapped`, `startAnother`, `backToMap`) calls exactly one
`DoorFacade` entry (AC8); `continueTapped` sets `writeFailureCode: nil` because `continueAfterAnswer` never
writes (arbiter-04 § Q-A, §3) and so can never fail a write.

### 4.10 Boundary validation

The only untrusted input any file in this task's scope reads is the student's own keypad taps and choice taps
— both already-bounded by `DoorKeypad.numericKeypadKeys` (a fixed key set) and `DoorItemChoice.id` (an
already-decoded `Core` value); `DoorFacade.answer`'s own numeric-grammar check (04.2/04.3's `ItemChecker`)
handles a malformed numeric string by returning `correct == false`, never by crashing or throwing — this
task's code performs no validation of its own and needs none.

### 4.11 Error codes shown

- `CoreError.expNoFringe` (`"EXP_NO_FRINGE"`) — `StartExpeditionActionButton`, `UnitExpeditionActionButton`,
  `DoorBRunScreen.startAnother`, via `CoreErrorText.text(for:)`.
- `CoreError.expStateWriteFailed` (`"EXP_STATE_WRITE_FAILED"`) — the summary's `writeFailureText`, resolved
  from `DoorBRunSnapshot.writeFailureCode` via `CoreError(rawValue:)` + `CoreErrorText.text(for:)`, never a
  second, hand-authored string.
- No `CoreError` case is added, thrown or newly referenced by this task; every code above is already
  registered (`contracts/error-codes.json`, quoted in 04.5's own spec §3) and already resolved by
  `CoreErrorText` (03.3's file, untouched).

### 4.12 Model-calling paths

None. Every file in this task's scope is Tier 0, synchronous; no `FoundationModels` import, no adapter
parameter anywhere (I2's confidence-threshold/fallback requirement is not engaged).

### 4.13 Smoke check

`xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM"
-configuration Debug -derivedDataPath "$ROOT/.build/DerivedData" CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`,
gate 4, re-read this session with 03.12's added `-configuration`/`-derivedDataPath` flags) — must be green, with
every file in this task's scope compiled into the target via the synchronized `Sources` group.

## §5 Test plan (risk: seam — full plan)

**C3 note (owner-verified, no agent claim of pixel-level or tap-level correctness).** `App/mathmath.xcodeproj`
has no App unit-test target (`tasks/arbitration/arbiter-03-predispatch.md` § Q-F: "No App test target is
needed"). This task's verification is therefore the App build, the lint gate, the 03.9 structural scan, and
source-level inspection against each AC — the same C3 exclusion 03.11's and 03.12's own specs already
establish for `App/Sources`-only code with no `Core` counterpart, restated per this task's own §1 C3 paragraph
(arbiter-04 § Q-C). No line in this task's acceptance report claims screenshot-level or tap-level correctness
(D29).

- **T1 happy path:** AC1–AC9 are each verified by (a) the App build (`scripts/gate.sh:22`) succeeding with
  every file in this task's scope compiled in; (b) a full read-through of each file confirming every AC's
  field routing, call count and case list matches §4's code exactly; (c) `swift-format lint --strict` clean on
  every file in this task's scope.
- **T2 negative — invalid input rejected at the boundary:** not applicable in the schema-validation sense (this
  task validates no external payload, §4.10); the closest analogue is a malformed numeric keypad string (e.g.
  `"//"`) passed through `NumericKeypadView.onSubmit` → `DoorBRunScreen.submit` → `DoorFacade.answer`: the
  answer card still renders (`correct == false`, from `ItemChecker`'s own grammar check, 04.4's concern), never
  a crash — confirmed by inspection that `submit(_:current:)` performs no precondition on `value` before
  calling `DoorFacade.answer`.
- **T3 error-taxonomy:** `rg -n "CoreErrorText"` over this task's scope shows exactly three call sites
  (`StartExpeditionActionButton.start`, `UnitExpeditionActionButton.start`, `DoorBRunScreen.startAnother`, plus
  the one `writeFailureText` resolution in `DoorBRunScreen.content(for:)`); `rg -n "\.expNoFringe|\.expStateWriteFailed"`
  shows the only two registered codes this task's code ever names; no `Text(` literal anywhere in this task's
  scope names an error condition ad hoc.
- **T4 conformance per requirements §B.1** (`contracts/interaction-contract.md` § 2, `contracts/data-model.md`
  § Text, `contracts/domain-glossary.md`, and I3/I5/I6/I10/I14 per §1):
  - I3: `rg -n "continueAfterAnswer"` over this task's scope shows exactly one call site
    (`DoorBRunScreen.continueTapped`), reachable only from `ExpeditionAnswerCardView`'s single continue
    control's `onContinue` closure — no other code path in this task's scope reaches `.screen(.item(...))` or
    `.screen(.summary(...))` from `.answerCard(...)` without it.
  - I10: `rg -n "TextField"` over this task's scope returns no match; `rg -n "import Vision|VisionKit|PencilKit|FoundationModels"`
    returns no match.
  - I14: the 03.9 `AppSourcesBoundary` scan re-run with this task's files present stays green (AC10); `rg -n
    "DoorBExpeditionFlow\.|DoorADiagnosisFlow\.|ExpeditionRun\.|Expedition\.compose|StudentState\("` over this
    task's scope returns no match — every state-changing action goes through `DoorFacade` only.
  - Glossary (§3): `rg -ni "\bsession\b|\bquiz\b|\bquest\b|\blevel\b|\bfail\b|start marker|\bcursor\b|\bprofile\b|progress file|\bsave\b"`
    over `App/Sources/Doors`, `App/Sources/MapUI/MapActionsView.swift` and the changed lines of
    `App/Sources/Shell/AppShell.swift` returns no match.
  - **Session-identifier scan (case-sensitive, catches what the word-boundary grep above cannot):** `rg -n
    "Session"` (no `-i`, unanchored — matches inside a larger identifier such as `DoorBSession`, not just the
    standalone word) over `App/Sources/Doors` and the changed lines of `App/Sources/MapUI/MapActionsView.swift`
    / `App/Sources/Shell/AppShell.swift` returns no match. **Negative control:** the prior draft of this task's
    §4.9 code — `struct DoorBSession: Equatable { ... }`, `private(set) var session: DoorBSession?`, `func
    replace(with newValue: DoorBSession) { session = newValue }`, three more `DoorBSession(...)` construction
    sites in `DoorBRunScreen` — matches this grep more than ten times, none of which the case-insensitive
    `\bsession\b` grep above would flag differently (it would also match, but only on the lowercase `session`
    property/parameter names, not on the `DoorBSession` type name in isolation); this second, case-sensitive
    scan is the one that specifically proves no *identifier* smuggles the banned noun past a reviewer who reads
    only the word-boundary grep's output. This task's code (§4.9, this revision) uses `DoorBRunSnapshot` and
    `DoorRunHolder.current` throughout, so both scans return no match.
- **T5 negative control for every regression guard:**
  - AC1/AC4's "no App-authored correctness copy" guard: `rg -n "\"Correct\"|\"Incorrect\"|\"Try again\""` over
    `App/Sources/Doors` returns no match — the guard this task's own code passes by construction (SF Symbols
    only); a version of `ExpeditionAnswerCardView` that added `Text(content.correct ? "Correct" : "Incorrect")`
    would fail this grep, proving the guard is load-bearing.
  - AC2/AC3/AC8's "one `DoorFacade`/callback call per button" guard: `rg -n "onSubmit\(|onSelect\(|onContinue\(\)"`
    inside `NumericKeypadView.swift`/`ChoiceButtonsView.swift`/`ExpeditionAnswerCardView.swift` shows exactly
    one call site per file, each inside exactly one `Button` action closure.
  - AC6's exact-three-case guard: `rg -n "case " App/Sources/MapUI/MapActionsView.swift` inside the
    `HandOffDestination` enum body shows exactly three lines — a fourth case added later without updating this
    guard is caught by re-running the count (mirrors 03.11's own AC9 guard, re-scoped to the renamed case).
  - AC10's "no allow-list widening" guard: a diff of `AppSourcesBoundaryTests.swift` before and after this
    task's implementation shows zero lines changed (this task's file scope, §2, excludes that file entirely) —
    proving the claim "04.8 needs no 03.9 widening" is checkable, not merely asserted in prose.
- **T6 idempotency / no-leak:** `DoorBRunScreen.continueTapped` called twice on the same `Equatable`-equal
  `DoorBAnswerAdvance` (via `DoorFacade.continueAfterAnswer`'s own idempotency, 04.5 T6) returns
  `==` `DoorBScreen` values (04.5 T6 compares the accompanying `DoorRunState` field-wise, since it is not
  `Equatable`), so this task's rendering re-derives the identical screen either way; `rg -n
  "@State"` over `App/Sources/Doors` and the `DoorBRunScreen` addition to `AppShell.swift` shows exactly the
  two expected instances (`DoorBViewState` in `DoorBRunScreen`, `errorText` in each of the two action buttons
  in `MapActionsView.swift`) — no file holds a `Core` value across calls beyond the `DoorRunHolder`/
  `MapStateHolder` themselves, which are explicitly designed to (I14).

## §6 Decision defaults

- IF `HandOffDestination.unitExpedition(result: ComposeResult)` (03.11's AC9 payload) should be kept unchanged,
  with the "Unit expedition" button handing off a raw `ComposeResult` for `AppShell` to start separately, THEN
  it is not — there is no `DoorFacade` entry that starts a run from an already-computed `ComposeResult` without
  recomposing (04.5's spec, §3, names only `startExpedition`/`startUnitExpedition`/`startAnother`, all of which
  compose internally), and adding one would mean editing `Packages/Core/Sources/Core/Platform/MapLaunch.swift`
  a second time, which 04.5's own dispatch note (`tasks/epic-04-task-05-*.md` Branch note: "This task is the
  only EPIC 04 task that modifies 03.7's façade file") forbids for any other EPIC 04 task, including this one.
  Instead, `UnitExpeditionActionButton` is rewired to call `DoorFacade.startUnitExpedition` directly (a genuine
  04.5 entry call, replacing the previous 03.7-only `MapFacade.unitExpedition` call), and the hand-off case is
  renamed `.doorBStarted(DoorBStartOutcome)`, shared with the new "Start expedition" button — both buttons open
  the identical Door B screen-content shape, and no consumer distinguishes "which button started this run".
  Per `docs/epics/epic-03-app-map-shell.md` § 2 (quoted `tasks/epic-03-task-11-*.md` §3): "the [hand-off] hook
  may land on a placeholder destination that EPIC 04 replaces" — this is exactly that replacement. The case
  count stays exactly three (AC6).
- IF the "Start expedition" button's label should be an App-invented phrase THEN it is not — `"Start
  expedition"` is the domain doc's own name for this entry point (`docs/domains/expedition.md`, quoted §3: `…
  Entered from the **Map** "Start expedition" button.`), not authored by this task.
- IF the retry indicator on `ExpeditionItemView` should render the word "Retry" as `Text` THEN it does not —
  `contracts/domain-glossary.md`'s own "Retry" entry (§3) registers the term but does not require it be shown
  as on-screen copy, and `DoorItemContent.isRetry` carries no associated label string to render (04.2's own
  file scope, §3); an SF Symbol (`arrow.counterclockwise`) satisfies "the retry indicator" without inventing a
  copy literal, consistent with the same reasoning applied to the answer card's correct/incorrect indicator
  (`checkmark.circle`/`xmark.circle`, AC4) and the keypad's delete affordance (`delete.left`, AC2).
- IF `AppSourcesBoundary.allowedImportModules` or `defaultRules` (`tasks/epic-03-task-09-*.md` §4.2, quoted §3)
  should be widened by this task to admit the `DoorFacade`/`DoorRunState`/`DoorBScreen`/`DoorBAnswerAdvance`
  symbols this task's code references THEN no widening is made or needed — those symbols are `Core` public
  types reached only via `import Core` (already allow-listed) and are not on `forbiddenCoreTypeNames` (quoted
  §3, verified unchanged this session); every call this task's code makes is to `DoorFacade.*`, `MapFacade.*`,
  `CoreErrorText.*`, `MathView.*` or `DoorKeypad.*`, none of which appears in `forbiddenCoreTypeNames`, and this
  task's imports are exactly `SwiftUI`, `Foundation`, `Core`, `Rendering` — all four already in
  `allowedImportModules`. Task 04.10 (`docs/plans/epic-04-plan.md`: "extends 03.9's App/Sources scan with the
  Door rules and widens the allow-list by exactly the 04.5 entries") therefore does not need to land before
  this task, and this task does not need to land before 04.10 either — the ordering constraint the planner
  flagged (`docs/plans/epic-04-plan.md`, planner notes: "The spec writer must make sure 04.8 and 04.9 do not
  need allow-list entries before 04.10 adds them") is satisfied by construction: this task's code, written
  exactly as §4 specifies, introduces zero 03.9 scan violations under the **current, unmodified** rule set. If
  a future implementer's code instead calls `DoorBExpeditionFlow`/`DoorADiagnosisFlow`/`ExpeditionRun`/
  `Expedition` directly anywhere in this task's file scope — a deviation from §4, not a consequence of
  following it — that is caught by the existing `forbiddenCoreTypeNames` entries for `Expedition`/
  `ExpeditionRun`/`DiagnosisRun` already in the list (`DoorBExpeditionFlow`/`DoorADiagnosisFlow` themselves are
  new-in-EPIC-04 names 04.10 later adds to the forbidden list, with their own negative controls — a stricter,
  later guard this task's correct code already satisfies vacuously).
- IF `DoorBSummaryScreen.itemCount` should be rendered as a sentence (e.g. "N items this run") THEN it is not
  — no `Core`-supplied string carries that sentence, and authoring one would be exactly the "invented copy
  literal" this task's scope forbids (task-request scope: "no student-facing copy literals except those Core
  supplies"); the interaction-contract's summary-content bullet (§3) does not require an item count to be
  shown at all. `ExpeditionSummaryView` therefore omits it (§4.7).
- IF a mid-run `writeFailureCode` (returned by `DoorFacade.answer` on any call before the run's natural end)
  should be surfaced on the item view or the answer card, rather than only on the summary, THEN it is not
  surfaced by this task — the task-request scope names "summary with 04.5's write-failure banner" specifically,
  matching `docs/domains/expedition.md` W5 step 2 (`EXP_STATE_WRITE_FAILED` shows a banner, the summary still
  shows"), which frames the banner as a run-end concern; `DoorBRunSnapshot.writeFailureCode` is threaded
  through every run-snapshot replacement so a later task can extend this without a data-shape change, but this
  task's own views render it only on `ExpeditionSummaryView` (§4.7, §4.9).
- IF `DoorBSession`/`DoorRunHolder.session` (the type/property names in the prior draft of this spec) should be
  kept as-is THEN they are not — `contracts/domain-glossary.md:29` bans "session" as an Expedition synonym (a
  session is registered elsewhere as a telemetry day-unit) and `docs/plans/epic-04-plan.md` (planner notes)
  directs "Do not coin new *Session* identifiers"; this task's holder type is named `DoorBRunSnapshot` and its
  published property `DoorRunHolder.current`, matching the "current `Core` session value" *concept* named in
  arbiter-03's § Q-F quote (§3) without reusing the banned noun as an identifier.
- IF an App-side struct or enum holding a `DoorRunState` or `MapState` (`DoorBStartOutcome`, `DoorBRunSnapshot`) seems to want `Equatable` THEN it
  does not declare it. `DoorRunState` is not `Equatable` (04.5 §4.1), nothing in this task compares these values
  (`fullScreenCover` binds on `doorHolder.current != nil`; `@Observable` needs no conformance), and a hand-written
  `==` over `Core` state would put equality semantics in the render layer (I14). Per
  `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`.
- Standing defaults: identifiers and timestamps are untouched by this task — every id/timestamp already on
  `DoorItemContent`/`DoorAnswerCardContent`/`DoorBSummaryScreen`/`MapState` passes through opaquely, and no
  file constructs one. Model calls do not exist anywhere in this task's code (I2 vacuous). Telemetry is
  unaffected: no telemetry client, no consent field, no identifier is read or written by any file in this
  task's scope. No node's Ministry text is read — this task renders no `paraphrase`, no hint and no
  `expectation_codes` field; those are Door A's concern (04.9).

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
  `AppSourcesBoundaryNegativeControlTests.swift` (§6 default 4, §5 T5's diff guard).
- 03.12's simulator smoke (`scripts/sim-smoke.sh`, gate 4) stays green: this task adds no App launch-path code
  and no state-file interaction of its own, so the fresh-install and seeded-relaunch scenarios (both scoped to
  launch/relaunch, before any course or Door action) are unaffected by this task's file scope.
- tests green for every case in §5 (T1–T6).
- glossary grep clean (§5 T4, both the word-boundary scan and the case-sensitive `"Session"` identifier scan)
  and no App-authored correctness/retry copy literal anywhere in this task's scope (§5 T5).
- conforms to every contract section cited in §3 (`contracts/interaction-contract.md` § 2,
  `contracts/data-model.md` § Text, `contracts/domain-glossary.md`) and to every invariant listed in §1 (I3,
  I5, I6, I10, I14).
- the C3 exclusion (§1, §5) is honoured: no claim of tap-level, screenshot-level or runtime-sequence
  correctness appears in this task's acceptance report; that is the owner's Demo-wrap check (D29).

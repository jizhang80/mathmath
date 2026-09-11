# Epic 04 · Task 10: extended `App/Sources` boundary scan — Door rules (I1 / I2 / I10 / I14)

---
epic: 04
task: 10
slug: app-sources-door-scan
kind: test
risk: seam
depends_on: [04.8, 04.9]
model: sonnet
---

> **Branch note.** Written against the current tree (clean `main`; `App/Sources` holds exactly
> `MathmathApp.swift` and `ContentView.swift` today — confirmed by Glob this session, no Door files exist yet).
> The implementer runs this task on `epic-04b-door-app`, after task **04.8** (`app-expedition-screens`) and task
> **04.9** (`app-diagnosis-screens`) have both landed on that branch — 04.9's own dispatch note requires it to
> land after 04.8; this task requires both, per `docs/plans/epic-04-plan.md` planner note: "04.10 runs after
> 04.8/04.9, because its one-call-per-button rule needs real Door views." By the time this task runs,
> `App/Sources/Doors/*.swift` (04.8's five files, 04.9's three files), `App/Sources/MapUI/MapActionsView.swift`
> and `App/Sources/Shell/AppShell.swift` (both carrying 04.8's and 04.9's edits on top of 03.11's/03.12's
> originals) and `Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift` / `DoorEntriesTests.swift` (04.5) all
> exist. If any is absent, that is an EPIC-order precondition failing to hold — BLOCK and report it; do not stub
> the missing files.
>
> **04.9 is under review, not PASS, as of this writing.** Its own spec text uses `DoorBSession`/`.session` for
> the Door run holder, while 04.8's final revision (its own "Quote-fidelity correction" note) renamed these to
> `DoorBRunSnapshot`/`.current`. This task's rules never reference either name: every pattern below matches only
> on `DoorFacade.\w+(`, `Button(`/`Text(` literal shapes, and the generic `forbiddenCoreTypeNames`/`ItemChecker`
> denylist tokens — all of which are stable across whichever naming 04.9 lands with. The implementer scans
> whatever tree 04.8/04.9 actually produce; no fixture or assertion in this spec depends on a specific holder
> type or property name.
>
> **C3 exclusion (verbatim, `tasks/arbitration/arbiter-04-predispatch.md` § Q-C, already byte-quoted by both
> 04.8 §1 and 04.9 §1 this session).** This task's scan is exactly the "source scan over the Door view files,
> with a negative control" clause of brief item 8 (`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:
> 391-402`, quoted §3). It proves **call shape**, never tap execution: it cannot and does not claim (1) that any
> tap on a simulator actually fires its action, (2) that a Door screen is laid out so its controls are visible
> and reachable, (3) that no runtime trap occurs along the Door screens after launch, (4) that the sequence of
> screens a student sees at runtime matches the façade's screen values, rather than only in `CoreTests`. The
> literal tap-through is the owner's device verification (D29).

## §1 Goal & acceptance criteria

Goal: extend 03.9's `AppSourcesBoundary` scan (`Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift`)
with a `doorRules` array and one dedicated button-call-shape check, both exercised over the real, landed
`App/Sources` tree with the SwiftMath import exception already deleted (03.12) and no import-allow-list
widening performed — `DoorFacade` is reached via `import Core`, already allow-listed, so no module name is
added. The scan fails the build the moment a Door view constructs its own correctness path, opens a free-text
or camera/handwriting input, imports a model framework, or wires a button to anything other than exactly one
permitted `DoorFacade` entry. Every new violation class ships with a planted negative control, reusing 03.9's
`violations(in:rules:)` walk unmodified (its own AC6 extensibility contract) for the line-scoped rules, plus one
new, block-scoped helper for the button-call-shape rule (which cannot be expressed as a single-line `Rule`).

Invariants in play:

- **I1** — the scan fails on any `ItemChecker` call (already caught by 03.9's `defaultRules` "free-text answer /
  OCR / item-check path" rule) and on any comparison against an `answer`/`correct_choice_id`-named value (a new
  `doorRules` entry), so no `App/Sources` file can re-implement or bypass CAS-decided correctness.
- **I2** — the scan fails on any `FoundationModels` import (already caught by 03.9's "non-allow-listed import"
  rule, since `FoundationModels` is not in `allowedImportModules`); a dedicated negative control plants this
  import specifically, since 03.9's own negative control used `import Vision` as its example.
- **I10** — the scan fails on any `TextField`/`TextEditor` bound to an "answer"-named value (a new `doorRules`
  entry extends 03.9's TextField-only pattern to also match `TextEditor`) and on any `Vision`/`VisionKit`/
  `PencilKit` import (already caught by the non-allow-listed-import rule; a dedicated negative control plants
  `PencilKit` specifically for completeness, since the task's own scope names it).
- **I14** — the scan fails on any direct `ExpeditionRun`/`DiagnosisRun`/`Expedition` call in `App/Sources`
  (already in 03.9's `forbiddenCoreTypeNames`, already tested by 03.9's own negative controls — no new rule
  needed) and, newly, on any Door button/composition-function action that calls zero or more than one
  `DoorFacade` entry, or mixes a `DoorFacade` call with a forbidden Core-internal call, or calls a `DoorFacade`
  member outside the type's own public surface. This is the render layer's proof that it never re-implements a
  Door state transition — `Core`'s own logic is the single source, the App only sequences one call per action.

Acceptance criteria (each independently verifiable):

- AC1: `AppSourcesBoundary.doorRules` (new, in `DoorAppSourcesBoundaryTests.swift`) contains exactly two `Rule`
  values: (a) "answer / correct_choice_id comparison outside CAS", (b) "free-text entry (TextField/TextEditor) bound
  to an answer-named value"; `AppSourcesBoundary.doorCopyRule` (new, same file) is rule (g) "Door student-facing
  copy as an inline string literal (4+ words)", isolated like 03.9's `networkRule` because it runs alone against
  `App/Sources/Doors`. `violations(in: realAppSources, rules: defaultRules + doorRules)` returns `[]` over the real
  `App/Sources` tree, and `violations(in: realAppSources/Doors, rules: [doorCopyRule])` returns `[]` over the real
  `App/Sources/Doors` tree (instrument: Swift Testing `#expect`, gate 3; excludes files outside `Doors`, whose
  EPIC 03 map chrome — `MapActionsView.swift:38`, `UnitListPickerView.swift:19`, `RegionPanelView.swift:16` —
  carries 4+-token literals that are not Door copy; empty `Doors` = FAIL via the helper's own empty-scan guard).
- AC2: for (a), for (g) (`doorCopyRule`, run with `rules: [AppSourcesBoundary.doorCopyRule]`) and for the
  Door-scoped `TextEditor` extension of (b),
  a dedicated negative-control test plants exactly that violation in a synthetic fixture two directories deep
  and asserts `AppSourcesBoundary.violations(in:)` (with `defaultRules + doorRules`) reports it, mirroring
  03.9's own per-class negative-control shape (fresh `UUID()`-named temp dir, `defer`-removed, one plant, one
  assertion).
- AC3: a dedicated negative-control test plants `import FoundationModels` in a fixture and asserts the existing
  "non-allow-listed import" rule (from `defaultRules`, unmodified) reports it — no new `Rule` is added for this
  class, since it is already covered.
- AC4: a dedicated negative-control test plants `import PencilKit` in a fixture and asserts the same existing
  rule reports it — no new `Rule` is added.
- AC5: `AppSourcesBoundary.doorFacadeEntryNames(fromSeamTestSource:)` (new, pure text-parsing function) run
  against the real `DoorFacadeSeamTests.swift` source returns exactly `{"startExpedition", "answer",
  "continueAfterAnswer", "decideProbe", "answerProbeItem", "continueAfterProbeAnswer", "resumeAfterDiagnosis",
  "checkHere"}` (the eight entries 04.5's own AC13/AC14 sequences call, per `tasks/epic-04-task-05-*.md` §1,
  quoted §3) — a drift detector on 04.5's own C1 seam-test coverage, not a restrictive allowlist (§6 default 1
  explains why it is not used as the button-rule's allowlist).
- AC6: `AppSourcesBoundary.doorFacadePublicEntryNames(fromMapLaunchSource:)` (new, pure text-parsing function)
  run against the real `MapLaunch.swift` source returns exactly the twelve `DoorFacade` entry-point names listed
  in `tasks/epic-04-task-05-*.md` §D of the context bundle (quoted verbatim §3) — this is the registry
  `doorButtonActionViolations` validates every button/composition-function `DoorFacade` call against, derived
  from `Core`'s own source, never hand-maintained.
- AC7: `AppSourcesBoundary.doorButtonActionViolations(in:permittedEntryNames:)` (new), run over the two real
  files that own every direct `DoorFacade.*` call site in `App/Sources` (`App/Sources/Shell/AppShell.swift`,
  `App/Sources/MapUI/MapActionsView.swift`), returns `[]` when given `doorFacadePublicEntryNames(fromMapLaunchSource:)`'s
  result as the permitted set, and its `#expect(totalDoorFacadeCalls > 0, …)` empty-match guard passes (at least
  one `DoorFacade.` call exists across the two files).
- AC8: for each of the three failure shapes the button-call-shape rule detects — (i) a function whose body
  contains two `DoorFacade.*` calls, (ii) a function whose body contains a `DoorFacade.*` call and also an
  `ItemChecker`/`ExpeditionRun`/`DiagnosisRun` call in the same body, (iii) a function whose body contains a
  `DoorFacade.doesNotExist(` call (a name outside the permitted set) — a dedicated negative-control test plants
  exactly that shape in a synthetic fixture file and asserts `doorButtonActionViolations(in:permittedEntryNames:)`
  reports it.
- AC9: a dedicated negative-control test builds a fixture tree with zero `DoorFacade.` calls anywhere and
  asserts `doorButtonActionViolations` fails its own empty-match `#expect` (the "empty match over Door buttons =
  FAIL" clause) rather than silently returning `[]`.
- AC10: the App builds green (gate 4, `scripts/gate.sh:22`) — unaffected by this task, since it touches no
  `App/Sources` file; `Core` tests (gate 3, `scripts/gate.sh:18`) are green with every case above passing.
- AC11: no import exception of any kind is added or re-added anywhere in this task's code (§6 default 2); no
  widening of `AppSourcesBoundary.allowedImportModules` occurs (§6 default 3).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Tests/CoreTests/DoorAppSourcesBoundaryTests.swift` — CREATE. Defines `AppSourcesBoundary
  .doorRules` (extension), `AppSourcesBoundary.doorButtonActionViolations(in:permittedEntryNames:)`,
  `AppSourcesBoundary.doorFacadeEntryNames(fromSeamTestSource:)`,
  `AppSourcesBoundary.doorFacadePublicEntryNames(fromMapLaunchSource:)` (all as extensions on 03.9's
  `AppSourcesBoundary` type, added from this file — 03.9's own file is never edited), and the real-tree/registry
  tests (AC5, AC6, AC7, AC9's empty-match guard, AC1's `doorRules` real-tree assertion may also live here or in
  `AppSourcesBoundaryTests.swift`, implementer's choice, as long as it is not duplicated in both). Confirmed
  absent (Glob `**/DoorAppSourcesBoundaryTests.swift` returns no match).
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift` — MODIFY. Adds exactly one new `@Test` to the
  existing `AppSourcesBoundaryTests` suite: `appSourcesIsCleanWithDoorRules()`, calling `AppSourcesBoundary
  .violations(in: appSources, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)` and
  asserting `[]` (AC1's real-tree half). No existing line in this file is edited or reordered; `allowedImportModules`
  is NOT touched (§6 default 3). Confirmed present, created by 03.9.
- `Packages/Core/Tests/CoreTests/AppSourcesBoundaryNegativeControlTests.swift` — MODIFY. Adds the negative-
  control tests for AC2, AC3, AC4, AC8 (three sub-cases), AC9 — one `@Test` per case, each its own fresh
  `UUID()`-named temp directory, `defer`-removed, mirroring 03.9's existing tests' shape exactly. No existing
  test in this file is edited.

Out-of-scope (do not touch even if tempted):

- `App/Sources/**` — read-only. This task reads every file under it (and the two composition files by
  absolute path) to run the scan, but never edits any of them. 04.8/04.9 wrote these files; this task consumes
  them as they exist on the branch.
- `Packages/Core/Sources/Core/Platform/MapLaunch.swift` — read-only. 04.5's `DoorFacade` definitions live here;
  this task reads the file's text (via `String(contentsOf:)`, the same mechanism 03.9 already uses for
  `App/Sources` files) to derive `doorFacadePublicEntryNames`, never edits it.
- `Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift`, `DoorEntriesTests.swift` — 04.5's files; read-only.
  This task reads `DoorFacadeSeamTests.swift`'s text for AC5's drift check; it never edits either file.
- `scripts/gate.sh`, `.github/workflows/ci.yml` — unchanged; this task's tests run under the existing gate 3
  (`xcodebuild test -scheme Core-Package`).
- `contracts/**`, `docs/**`, `data/**` — read-only ground truth.
- Any file under `App/mathmath.xcodeproj/` — never edited.

## §3 Inputs (verbatim — do not paraphrase)

Binding invariant rules (`CLAUDE.md`, Hard invariants table, re-read and byte-compared this run):

- I1:
  > **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No
  > code path lets a model output decide whether a step or a probe answer is right; expedition items are
  > checked deterministically in code.

- I2:
  > **Tier 0 alone must be a usable product**: every model call has a confidence threshold and a deterministic
  > fallback; the system never guesses a diagnosis.

- I10:
  > **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a
  > structured math editor; **no OCR in any door.**

- I14:
  > **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never
  > computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:387-402` (re-read, byte-compared this run), brief
items 7 and 8 this task delivers:

> 7. **Input (I10)**: the keypad key set (a `Core` constant) types every `numeric` `answer.value` in `data/demo`.
>    An `mc` answer is submitted as the choice id. The extended `App/Sources` scan is green, and its planted
>    violations fail it: a free-text answer field, a direct `ItemChecker`/`ExpeditionRun`/`DiagnosisRun` call, a
>    Vision/PencilKit import, and a model-framework import.
> 8. **C1 seam — App ↔ `Core` state transitions**:
>    - the App build is green;
>    - every Door button's action is exactly one façade call (source scan over the Door view files, with a
>      negative control);
>    - the `Core` tests of items 1 and 2 drive the **same** façade entry points the buttons call;
>    - the render side of the seam is evidenced by logic, composition and static wiring only. The 04b task specs
>      and the acceptance report state verbatim what it cannot claim (arbiter-04 § Q-C): (1) that any tap on a
>      simulator actually fires its action — hit-testing, sheet and navigation presentation, and keypad key →
>      string binding at runtime; (2) that each Door screen is laid out so its controls are visible and reachable
>      (e.g. continue and decline are on screen); (3) that no runtime trap occurs along the Door screens after
>      launch (the smoke covers launch and relaunch only); (4) that the sequence of screens a student sees matches
>      the façade's screen values at runtime, rather than only in `CoreTests` (C3; §9 Q-C).

`docs/plans/epic-04-plan.md:78` (re-read, byte-compared this run):

> **04.10:** extends 03.9's App/Sources scan with the Door rules and widens the allow-list by exactly the 04.5
> entries. Each new rule class has a negative control.

`docs/plans/epic-04-plan.md:91-93` (planner notes, re-read, byte-compared this run):

> **04.10 runs after 04.8/04.9**, because its one-call-per-button rule needs real Door views. The spec writer
> must make sure 04.8 and 04.9 do not need allow-list entries before 04.10 adds them. Either land the
> allow-list widening first or merge the two steps.

Prior signatures / rule infrastructure this task builds on (from `tasks/epic-03-task-09-app-sources-i14-scan.md`
§4.2, re-read and byte-compared this run):

```swift
struct Rule {
    let name: String
    let violates: (String) -> Bool
}
static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]
private static let forbiddenCoreTypeNames = [
    "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
    "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
]
static let defaultRules: [Rule] = [
    // "StudentState construction", "direct Core transition/derivation call outside the façade",
    // "read of a data/ path", networkRule, "non-allow-listed import",
    // "free-text answer / OCR / item-check path" (ItemChecker OR TextField(...answer...))
]
static func violations(in root: URL, rules: [Rule] = defaultRules) throws -> [String]
```

The extensibility contract this task relies on (`tasks/epic-03-task-09-*.md` §1, re-read and byte-compared this
run):

> The scan logic is a single, rule-driven helper so EPIC 04 task 04.10 ("extends 03.9's App/Sources scan with
> the Door rules and widens the allow-list by exactly the 04.5 entries", `docs/plans/epic-04-plan.md` line 78)
> can add new violation classes and widen the import allow-list without rewriting the walk or the empty-scan
> guard.

The twelve `DoorFacade` entry points 04.5 landed (`tasks/epic-04-task-05-core-door-entries-persistence-seam.md`
§4.3/§4.4, re-read and byte-compared this run):

```swift
public enum DoorFacade {
    public static func startExpedition(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func startUnitExpedition(unitId: String, mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func answer(_ runState: DoorRunState, submitted: String, today: CalendarDay)
        -> (advance: DoorBAnswerAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, runState: DoorRunState)
        -> (screen: DoorBScreen, runState: DoorRunState)
    public static func resumeAfterDiagnosis(_ runState: DoorRunState, outcome: DiagnosisOutcome, today: CalendarDay)
        -> (advance: DoorBResumeAdvance, runState: DoorRunState, writeFailureCode: String?)
    public static func startAnother(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    public static func backToMap(_ runState: DoorRunState, today: CalendarDay)
        -> (mapState: MapState, writeFailureCode: String?)
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
}
```

So the twelve names AC6's `doorFacadePublicEntryNames` must return are: `startExpedition`,
`startUnitExpedition`, `answer`, `continueAfterAnswer`, `resumeAfterDiagnosis`, `startAnother`, `backToMap`,
`checkHere`, `decideProbe`, `answerProbeItem`, `continueAfterProbeAnswer`, `decideFurtherLevel`.

04.5's own file-scope statement of what `DoorFacadeSeamTests.swift` versus `DoorEntriesTests.swift` each cover
(`tasks/epic-04-task-05-*.md` §2, re-read and byte-compared this run):

> `Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift` — CREATE. AC13, AC14 (the C1 full-expedition and
> full-diagnosis sequences, both triggers, over real `data/demo`, no stubs).
> `Packages/Core/Tests/CoreTests/DoorEntriesTests.swift` — CREATE. AC1–AC3, AC9, AC10, AC11, AC12, AC15 (queue
> behaviour, unit-expedition delegation, `EXP_NO_FRINGE`, Start another, Back to the map, the write-failure
> banner for both doors, the no-new-registry-surface check).

04.5's AC13/AC14 sequence text, confirming exactly which `DoorFacade` entries `DoorFacadeSeamTests.swift` calls
(`tasks/epic-04-task-05-*.md` §1, re-read and byte-compared this run):

> AC13 ...: `DoorFacadeSeamTests.swift` drives, through `DoorFacade` only, on real `data/demo` and a
> temp-directory `stateURL`, with no stub on either side: **Start expedition** → answer every item ... →
> **Continue** through to **summary**.
> AC14 ...: the same file drives, through `DoorFacade` only:
> - (a) `expedition_second_miss`: two misses on one node inside a run → **Continue** reveals `.diagnosis
>   (.hypothesis(...))` → `decideProbe(accept: true)` → two `answerProbeItem`/`continueAfterProbeAnswer` pairs
>   (both wrong) → `.terminal` with `terminal == .capped`, a non-nil remediation → `resumeAfterDiagnosis` →
>   the run resumes at its next item, with the candidate `blocked` in the threaded state.
> - (b) `map_check_here`, decline: `checkHere` → `decideProbe(accept: false)` → `.terminal` with `terminal ==
>   .unconfirmed`, a non-nil hint, return to the (simulated) node panel with no `DoorFacade.resumeAfterDiagnosis`
>   call.
> - (c) `map_check_here`, refuted: `checkHere` → `decideProbe(accept: true)` → two correct `answerProbeItem`/
>   `continueAfterProbeAnswer` pairs → `.terminal` with `terminal == .refuted`.

The `DoorFacade` names appearing in that text — `startExpedition` (from "Start expedition"), `answer` (from
"answer every item"), `continueAfterAnswer` (from "Continue" after an answer), `decideProbe`, `answerProbeItem`,
`continueAfterProbeAnswer`, `resumeAfterDiagnosis`, `checkHere` — are exactly the eight AC5's expected set names.
`startUnitExpedition`, `startAnother`, `backToMap`, `decideFurtherLevel` appear only in the AC1–AC3/AC9/AC15 text
governing `DoorEntriesTests.swift`, never in the AC13/AC14 text governing `DoorFacadeSeamTests.swift`. This is
the basis for §6 default 1.

Gate commands (`scripts/gate.sh:16-22`, re-read and byte-compared this run):

```sh
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
```

Test framework (confirmed by every sibling `CoreTests` file re-read in this run): Swift Testing (`import
Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

## §4 Implementation outline

### 4.1 Layer placement

This is a `Core` test-target addition (`Packages/Core/Tests/CoreTests/`), not product code. It sits at the same
seam 03.9 already tests — the App's render layer (layer ④ interaction, Door B and Door A) versus `Core`'s owned
state transitions — extended to cover the Door-specific violation shapes 04.8/04.9's code introduces the surface
area for. No new `Core`, `App` or pipeline product code is added.

### 4.2 `doorRules` — the three new line-scoped rules (`DoorAppSourcesBoundaryTests.swift`)

```swift
import Foundation
import Testing

@testable import Core

/// Door-specific violation classes (04.10), composed as `defaultRules + doorRules` — 03.9's own extensibility
/// contract (AC6). Adds no import exception and no `allowedImportModules` widening: `DoorFacade` is reached via
/// `import Core`, already allow-listed (§6 default 3). Three of the six lettered violation classes in this
/// task's dispatch scope — (c) Vision/VisionKit/PencilKit import, (d) FoundationModels import, (e) direct
/// ExpeditionRun/DiagnosisRun/Expedition calls — are already caught by `defaultRules`' "non-allow-listed
/// import" and "direct Core transition/derivation call outside the façade" rules; they get dedicated negative
/// controls (§4.4) but no new `Rule` value here, since a duplicate rule would be dead code.
extension AppSourcesBoundary {
    static let doorRules: [Rule] = [
        Rule(name: "answer / correct_choice_id comparison outside CAS") { line in
            line.range(
                of: #"(==|!=)\s*\w*\.?(answer|correct_choice_id|correctChoiceId)\b|\b(answer|correct_choice_id|correctChoiceId)\b\s*(==|!=)"#,
                options: .regularExpression) != nil
        },
        Rule(name: "free-text entry (TextField/TextEditor) bound to an answer-named value") { line in
            line.range(of: #"(TextField|TextEditor)\s*\([^)]*[Aa]nswer"#, options: .regularExpression) != nil
        },
    ]

    /// Rule (g), isolated as its own named rule (03.9's `networkRule` precedent) because it runs alone against
    /// `App/Sources/Doors`, the Door view files: EPIC 03's map chrome outside that directory legitimately
    /// carries 4+-token literals ("Include in my next expedition", "Past the last unit", "% cleared").
    static let doorCopyRule = Rule(name: "Door student-facing copy as an inline string literal (4+ words)") {
        line in
        doorCopyLiteralWordCount(in: line) >= 4
    }

    /// Counts whitespace-delimited words inside a `Text("...")`/`Button("...")` string literal on this line.
    /// Every chrome literal in App/Sources/Doors after 04.8/04.9 ("Continue", "Submit", "Yes", "Not now") is
    /// 1–3 words; a planted sentence-shaped literal (4+ words) is the
    /// class this rule exists to catch — student-facing prose must come from a `Core`-computed value, never be
    /// authored inline in `App/Sources` (I6's spirit, applied to Door copy specifically).
    private static func doorCopyLiteralWordCount(in line: String) -> Int {
        guard
            let regex = try? NSRegularExpression(pattern: #"(Text|Button)\(\s*"([^"]*)""#),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let literalRange = Range(match.range(at: 2), in: line)
        else { return 0 }
        return String(line[literalRange]).split(separator: " ").filter { !$0.isEmpty }.count
    }
}
```

### 4.3 The button-call-shape helper (`DoorAppSourcesBoundaryTests.swift`)

```swift
extension AppSourcesBoundary {
    /// I14 rule (f): every Door composition function that calls `DoorFacade` calls exactly one permitted entry,
    /// never mixed with a forbidden Core-internal call. Scoped to the two files that own every direct
    /// `DoorFacade.*` call site in `App/Sources` — `AppShell.swift`'s `DoorBRunScreen` action functions and
    /// `MapActionsView.swift`'s action-button `start()` methods (confirmed by direct read of 04.8's/04.9's own
    /// specs this session, §3). Resolves at most one level of Swift's own brace structure (a function body),
    /// never a cross-function call-graph trace — this is exactly what "the scan proves call shape, not tap
    /// execution" (C3) means in code: it cannot and does not prove a `Button`'s own trailing closure reaches a
    /// `DoorFacade` call through an arbitrary number of indirections, only that the function actually
    /// performing the call does so exactly once, cleanly.
    static func doorButtonActionViolations(
        in files: [URL], permittedEntryNames: Set<String>
    ) throws -> [String] {
        var violations: [String] = []
        var totalDoorFacadeCalls = 0
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (name, body) in functionBodies(in: text) {
                let calls = doorFacadeCallNames(in: body)
                totalDoorFacadeCalls += calls.count
                guard !calls.isEmpty else { continue }
                if calls.count > 1 {
                    violations.append("\(file.lastPathComponent):\(name): more than one DoorFacade call")
                }
                if calls.contains(where: { !permittedEntryNames.contains($0) }) {
                    violations.append(
                        "\(file.lastPathComponent):\(name): DoorFacade call outside the permitted entry set")
                }
                let forbiddenNames = forbiddenCoreTypeNames + ["ItemChecker"]
                if forbiddenNames.contains(where: {
                    body.range(of: "\\b\($0)\\b", options: .regularExpression) != nil
                }) {
                    violations.append(
                        "\(file.lastPathComponent):\(name): DoorFacade call mixed with a forbidden Core-internal call")
                }
            }
        }
        #expect(
            totalDoorFacadeCalls > 0,
            "no DoorFacade call found across the Door composition files — empty match over Door buttons is a FAIL"
        )
        return violations
    }

    /// Extracts every `func <name>(...) { <body> }` in `text` by matching the opening brace after the
    /// parameter list and counting brace depth to the matching close. A textual heuristic, not a Swift parser
    /// (consistent with 03.9's own per-line, non-AST precedent, §6 default of `tasks/epic-03-task-09-*.md`).
    private static func functionBodies(in text: String) -> [(name: String, body: String)] {
        guard let regex = try? NSRegularExpression(pattern: #"func\s+(\w+)\s*\([^)]*\)[^{]*\{"#) else { return [] }
        let nsText = text as NSString
        let chars = Array(text)
        var results: [(String, String)] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
            let openBrace = match.range.location + match.range.length - 1
            var depth = 1
            var i = openBrace + 1
            while i < chars.count, depth > 0 {
                if chars[i] == "{" { depth += 1 }
                if chars[i] == "}" { depth -= 1 }
                i += 1
            }
            let bodyRange = NSRange(location: openBrace + 1, length: max(0, i - 1 - (openBrace + 1)))
            results.append((String(text[nameRange]), nsText.substring(with: bodyRange)))
        }
        return results
    }

    private static func doorFacadeCallNames(in body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bDoorFacade\.(\w+)\("#) else { return [] }
        let nsBody = body as NSString
        return regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length)).compactMap { match in
            Range(match.range(at: 1), in: body).map { String(body[$0]) }
        }
    }
}
```

### 4.4 Registry-derived name sets (`DoorAppSourcesBoundaryTests.swift`)

```swift
extension AppSourcesBoundary {
    /// AC5: every `DoorFacade.<name>(` call site appearing anywhere in `text`. Applied to the real
    /// `DoorFacadeSeamTests.swift` source, this is a drift detector on 04.5's own C1 seam-test coverage — it is
    /// NOT the permitted-entry allowlist `doorButtonActionViolations` validates against (§6 default 1).
    static func doorFacadeEntryNames(fromSeamTestSource text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\bDoorFacade\.(\w+)\("#) else { return [] }
        let nsText = text as NSString
        return Set(
            regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
                Range(match.range(at: 1), in: text).map { String(text[$0]) }
            })
    }

    /// AC6: every `public static func <name>(` declared inside `DoorFacade`'s base `enum` or an `extension
    /// DoorFacade { }` block in `text`. Applied to the real `MapLaunch.swift` source, this is the registry
    /// `doorButtonActionViolations` uses as its permitted-entry set — derived from `Core`'s own source, never
    /// hand-maintained (guards against a legitimate future 13th entry being rejected by a stale literal list).
    static func doorFacadePublicEntryNames(fromMapLaunchSource text: String) -> Set<String> {
        var names: Set<String> = []
        for pattern in [#"enum\s+DoorFacade\s*\{"#, #"extension\s+DoorFacade\s*\{"#] {
            guard let blockRegex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsText = text as NSString
            for match in blockRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let openBrace = match.range.location + match.range.length - 1
                let chars = Array(text)
                var depth = 1
                var i = openBrace + 1
                while i < chars.count, depth > 0 {
                    if chars[i] == "{" { depth += 1 }
                    if chars[i] == "}" { depth -= 1 }
                    i += 1
                }
                let blockRange = NSRange(location: openBrace + 1, length: max(0, i - 1 - (openBrace + 1)))
                let block = nsText.substring(with: blockRange)
                guard let funcRegex = try? NSRegularExpression(pattern: #"public\s+static\s+func\s+(\w+)\s*\("#)
                else { continue }
                let nsBlock = block as NSString
                for funcMatch in funcRegex.matches(in: block, range: NSRange(location: 0, length: nsBlock.length))
                {
                    if let nameRange = Range(funcMatch.range(at: 1), in: block) {
                        names.insert(String(block[nameRange]))
                    }
                }
            }
        }
        return names
    }
}
```

### 4.5 Real-tree and registry tests (`DoorAppSourcesBoundaryTests.swift` / `AppSourcesBoundaryTests.swift`)

```swift
@Suite("App/Sources boundary: Door rules (04.10)")
struct DoorAppSourcesBoundaryTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    @Test("real DoorFacadeSeamTests.swift calls exactly the eight entries its own C1 sequences name")
    func seamTestEntryNamesMatchExpected() throws {
        let file = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        let derived = AppSourcesBoundary.doorFacadeEntryNames(fromSeamTestSource: text)
        let expected: Set<String> = [
            "startExpedition", "answer", "continueAfterAnswer", "decideProbe", "answerProbeItem",
            "continueAfterProbeAnswer", "resumeAfterDiagnosis", "checkHere",
        ]
        #expect(derived == expected, "DoorFacadeSeamTests.swift's own call set drifted: \(derived)")
    }

    @Test("MapLaunch.swift's public DoorFacade surface is exactly the twelve 04.5 entries")
    func doorFacadePublicSurfaceMatchesExpected() throws {
        let file = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Platform/MapLaunch.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        let derived = AppSourcesBoundary.doorFacadePublicEntryNames(fromMapLaunchSource: text)
        let expected: Set<String> = [
            "startExpedition", "startUnitExpedition", "answer", "continueAfterAnswer", "resumeAfterDiagnosis",
            "startAnother", "backToMap", "checkHere", "decideProbe", "answerProbeItem",
            "continueAfterProbeAnswer", "decideFurtherLevel",
        ]
        #expect(derived == expected, "DoorFacade's public surface drifted from the expected 12: \(derived)")
    }

    @Test("Door button/composition functions call exactly one permitted DoorFacade entry each")
    func doorButtonActionsAreClean() throws {
        let mapLaunch = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Platform/MapLaunch.swift")
        let permitted = AppSourcesBoundary.doorFacadePublicEntryNames(
            fromMapLaunchSource: try String(contentsOf: mapLaunch, encoding: .utf8))
        let files = [
            Self.repoRoot.appendingPathComponent("App/Sources/Shell/AppShell.swift"),
            Self.repoRoot.appendingPathComponent("App/Sources/MapUI/MapActionsView.swift"),
        ]
        let violations = try AppSourcesBoundary.doorButtonActionViolations(in: files, permittedEntryNames: permitted)
        #expect(violations.isEmpty, "Door button/composition call-shape violations: \(violations)")
    }
}
```

Add to the EXISTING `AppSourcesBoundaryTests` suite in `AppSourcesBoundaryTests.swift` (one new `@Test`, no
other line touched):

```swift
@Test("App/Sources has no I1/I2/I10/I14 Door boundary violations (04.10)")
func appSourcesIsCleanWithDoorRules() throws {
    let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
    let violations = try AppSourcesBoundary.violations(
        in: appSources, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
    #expect(violations.isEmpty, "Door boundary violations: \(violations)")
    let copyViolations = try AppSourcesBoundary.violations(
        in: appSources.appendingPathComponent("Doors"), rules: [AppSourcesBoundary.doorCopyRule])
    #expect(copyViolations.isEmpty, "Door copy literal violations: \(copyViolations)")
}
```

### 4.6 Negative controls (`AppSourcesBoundaryNegativeControlTests.swift`, additions)

One `@Test` per case, each: fresh `UUID()`-named temp directory, one planted violation two directories deep,
one assertion, `defer`-removed — mirroring 03.9's existing tests exactly. Skeleton for one (the others follow
the identical shape with a different planted line/assertion):

```swift
@Test("doorRules catches an answer/correct_choice_id comparison planted in a nested subdirectory")
func catchesAnswerComparison() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let nested = tempRoot.appendingPathComponent("Doors")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try "import Foundation\nimport Core\nstruct Clean {}\n"
        .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
    try "import Foundation\nimport Core\nlet ok = submitted == item.correct_choice_id\n"
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

    let violations = try AppSourcesBoundary.violations(
        in: tempRoot, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
    #expect(
        violations.contains {
            $0.contains("Planted.swift") && $0.contains("answer / correct_choice_id comparison outside CAS")
        })
}
```

The implementer writes the remaining cases following this shape exactly, one plant and one assertion per test:

- `TextEditor("Your answer", text: $answerText)` → "free-text entry (TextField/TextEditor) bound to an
  answer-named value".
- `Text("Hard-coded error message here")` (5 words), scanned with `rules: [AppSourcesBoundary.doorCopyRule]` →
  "Door student-facing copy as an inline string literal (4+ words)"; a companion assertion in the SAME or a
  separate test confirms `Text("Continue")` (1 word) and `Button("Check me here")` (3 words) do NOT trigger
  this rule (the clean-fixture proof for AC1).
- `import FoundationModels` → the existing "non-allow-listed import" rule from `defaultRules` (AC3).
- `import PencilKit` → the same existing rule (AC4).
- `doorButtonActionViolations`, planted as a fixture `.swift` file containing a function with two `DoorFacade.*`
  calls in its body → "more than one DoorFacade call" (AC8 i).
- the same helper, a function containing one `DoorFacade.answer(` call and one `ItemChecker.check(` call in the
  same body → "DoorFacade call mixed with a forbidden Core-internal call" (AC8 ii).
- the same helper, a function containing `DoorFacade.doesNotExist(` with a `permittedEntryNames` set that does
  not include `"doesNotExist"` → "DoorFacade call outside the permitted entry set" (AC8 iii).
- the same helper, a fixture with zero `DoorFacade.` calls anywhere → the `#expect(totalDoorFacadeCalls > 0, …)`
  itself fails, not the returned `[]` list (AC9) — this test asserts the helper *throws/fails the expectation*,
  not that it silently reports no violations.

### 4.7 Error codes

None. This task raises and catches no `CoreError`; every failure mode is a Swift Testing `#expect` failure over
a text scan.

### 4.8 Model-calling paths

None. No model is called by this task's code; the scan exists precisely to keep `FoundationModels` and every
other model-calling path out of `App/Sources` (I2).

### 4.9 Smoke check

`( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )`
(`scripts/gate.sh:18`, re-read this run) — must be green, with both new/modified test files' suites passing.

## §5 Test plan (risk: seam — full plan)

- **T1 happy path:** `appSourcesIsCleanWithDoorRules()` (AC1) over the real, landed `App/Sources`; plus
  `doorCopyRule` over `App/Sources/Doors`;
  `doorButtonActionsAreClean()` (AC7) over the real `AppShell.swift`/`MapActionsView.swift`; both registry tests
  (AC5, AC6) resolving to their expected sets over the real `DoorFacadeSeamTests.swift`/`MapLaunch.swift`.
- **T2 negative — invalid input rejected at the boundary:** not applicable in the schema-validation sense (this
  task parses no untrusted external payload); the closest analogue is T5, which asserts the scan *rejects*
  (reports) forbidden source shapes.
- **T3 error-taxonomy:** not applicable — no `CoreError` is raised by this task (§4.7).
- **T4 conformance per requirements §B.1 and the invariants of §1:** `appSourcesIsCleanWithDoorRules()` proves
  I1/I10's line-scoped Door rules hold over real `App/Sources`; `doorButtonActionsAreClean()` proves I14's
  call-shape rule holds over the two composition files; `seamTestEntryNamesMatchExpected()` proves brief item
  8's "the `Core` tests of items 1 and 2 drive the **same** façade entry points" property is checkable, not
  merely asserted in prose.
- **T5 negative control for every regression guard** — one per new/extended violation class:
  1. `answer`/`correct_choice_id` comparison (AC2).
  2. `TextEditor(...answer...)` (AC2).
  3. a 4+-word inline `Text`/`Button` string literal (AC2), with the companion clean-fixture assertion that
     1–3-word chrome literals do NOT trigger it.
  4. `import FoundationModels` (AC3, existing rule).
  5. `import PencilKit` (AC4, existing rule).
  6. a function with two `DoorFacade.*` calls (AC8 i).
  7. a function mixing a `DoorFacade.*` call with `ItemChecker`/`ExpeditionRun`/`DiagnosisRun` (AC8 ii).
  8. a function calling a `DoorFacade` member outside the permitted set (AC8 iii).
  9. a fixture with zero `DoorFacade.` calls anywhere, failing the empty-match `#expect` (AC9).
- **T6 idempotency / no-leak:** each negative-control test creates its own `UUID()`-named temp directory and
  removes it in a `defer`, so no fixture leaks into another test's scan; the real-tree tests (T1) and the
  fixture tests (T5) never share a directory, so a real-tree false positive cannot be masked by fixture cleanup
  order or vice versa.

## §6 Decision defaults

- IF "the permitted `DoorFacade` entry names equal exactly the set referenced in `DoorFacadeSeamTests.swift`"
  is read as "use `DoorFacadeSeamTests.swift`'s own call set AS `doorButtonActionViolations`'s allowlist" THEN
  do NOT: `DoorFacadeSeamTests.swift`'s own AC13/AC14 scope (quoted §3, from 04.5's already-written, byte-
  verified spec) calls only eight of the twelve entries — `startUnitExpedition`, `startAnother`, `backToMap`
  and `decideFurtherLevel` are `DoorEntriesTests.swift`'s scope (AC1–AC3/AC9/AC15, also quoted §3), never
  `DoorFacadeSeamTests.swift`'s. Using that eight-name set as the button rule's allowlist would make the real,
  correct `MapActionsView.swift`/`AppShell.swift` code (which legitimately calls all twelve) fail this task's
  own new rule. Instead: (a) `doorButtonActionViolations`'s allowlist is `doorFacadePublicEntryNames
  (fromMapLaunchSource:)` — derived from `DoorFacade`'s own public API surface in `MapLaunch.swift`, the
  registry the button rule actually checks against, per the guard-test principle "derive every allowlist from
  the registry it checks"; (b) the literal instruction's "assert that equality" is satisfied by
  `seamTestEntryNamesMatchExpected()` (AC5) — an equality assertion between `doorFacadeEntryNames
  (fromSeamTestSource:)`'s result and a hardcoded expected eight-name set, which is a drift detector on 04.5's
  own C1 seam-test coverage (the brief item 8 property: "the `Core` tests of items 1 and 2 drive the same
  façade entry points the buttons call" — items 1/2 are the C1 sequences, a genuine subset of the full button
  surface, not all of it).
- IF the SwiftMath import exception should be widened, re-added, or the import allow-list should admit
  `DoorFacade`, `MapActionsView`, or any other `Core`/App type name THEN it should not: `DoorFacade` is a symbol
  reached via `import Core`, already in `allowedImportModules` (`tasks/epic-03-task-09-*.md` §4.2, quoted §3);
  no module import is needed for a Door screen to call it. `allowedImportModules` gates *module* names
  (`"SwiftUI"`, `"Foundation"`, `"Core"`, `"Rendering"`), never type or symbol names — the "widen the allow-list
  by exactly the 04.5 entries" instruction (`docs/plans/epic-04-plan.md:78`, quoted §3) is satisfied entirely by
  the fact that `defaultRules`' forbidden-call list never named `DoorFacade`, so calls to it were never denied
  in the first place (the scan is a denylist, not an allowlist-complement, per 03.9's own doc comment quoted
  §3). No code changes this fact; this default records it so the implementer does not add a no-op edit.
- IF `AppSourcesBoundaryTests.swift`'s `allowedImportModules` array itself needs to change for this task THEN
  it does not: confirmed by the previous default, and by 04.8 §6 default 4 / 04.9 §6 default 3 (both already-
  written, byte-verified specs quoted §3) independently reaching the same "no widening needed" conclusion for
  their own, larger and smaller call surfaces respectively.
- IF a Door button's action closure calls a same-file wrapper function that itself calls no `DoorFacade` entry
  at all (a stub, e.g. `Button("X") { }`) THEN this task's scan does not catch that specific button in isolation
  — `doorButtonActionViolations`'s empty-match guard (`#expect(totalDoorFacadeCalls > 0, …)`) only catches the
  case where NO function across both composition files calls `DoorFacade` at all. Catching a single stubbed
  button among many correctly-wired ones would require tracing every `Button`'s trailing closure through an
  arbitrary chain of same-file function calls to prove it reaches (or fails to reach) a `DoorFacade` call — a
  full call-graph analysis this Core-test-tier scan does not attempt (C3: "the scan proves call shape, not tap
  execution", quoted in this spec's branch note). This is the same category of accepted heuristic-over-AST
  limitation 03.9 itself already documents for its `TextField`-bound-to-answer rule.
- IF the word-count threshold for rule (g) should be lower (e.g., 2+ words) to catch shorter invented prose THEN
  it stays at 4+, and rule (g) (`doorCopyRule`) runs over `App/Sources/Doors` only: every chrome literal there
  after 04.8/04.9 — "Continue", "Submit", "Yes", "Not now" — is 1–2 words, while three EPIC 03 map-chrome
  literals outside `Doors` are 4+ tokens (`MapActionsView.swift:38`, `UnitListPickerView.swift:19`,
  `RegionPanelView.swift:16` — `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md` F15) and are not
  Door copy; a tree-wide (g) would be red on arrival.
- IF AC9's "fails its own empty-match #expect" needs an instrument THEN wrap the call in Swift
  Testing's `withKnownIssue { … }` so the helper's recorded issue is the asserted outcome (a known issue that does
  not occur fails the test); never assert on the returned `[]`.
- Standing defaults: no identifier or timestamp is introduced by this task (it is test-only); no model call
  exists in this task's code, so the confidence-threshold/Tier-0-fallback rule is satisfied vacuously; no
  telemetry path is touched; no node gains a `paraphrase` or verbatim-text field, since this task adds no
  content.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources` — this task's new/modified test files only).
- typecheck clean — Swift's typecheck is the build (no Python file touched).
- `Core` build + test green: `swift build -c release --product core-cli`; `xcodebuild test -scheme
  Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO` on the simulator, with every case in §5 (AC1–AC9)
  passing.
- App build green (`xcodebuild build -workspace App/mathmath.xcworkspace -scheme mathmath -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO`) — unaffected by this task's file scope, re-verified as part of the gate.
- tests green for every case in §5.
- conforms to every invariant listed in §1 (I1, I2, I10, I14) and to brief items 7 and 8 (§3); the C3 exclusion
  (branch note) is stated verbatim and this task's own acceptance report claims none of its four excluded
  points.

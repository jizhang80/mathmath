# Arbiter addendum: 04.8's Doors structural suite vs 04.9 (ownership, landing, exact assertions)

**Date**: 2026-09-11
**Parent ruling**: `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md` (Q4). This addendum applies the
parent's option (a) to one more file.
**Trigger**: pre-emptive, raised while the 04.9 implementer is running (it has been told to BLOCK rather than edit
the suite). Branch `epic-04b-door-app` at `fc7ffa1`.
**Verdict**: **Option (a), lockstep in-task ownership.** 04.9 widens its §2 to MODIFY
`Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift` and updates it in the same commit as
its product change, exactly per §4 below. 04.10 and 04.12 need no edit for this file.

This is a spec-level resolution. No task is reordered or added. 04.8 (the tester's commit `fc7ffa1`) → 04.9 →
04.10 is already strictly sequential, and 04.10/04.12 write neither this file nor any `App/Sources` file (§5).

## 1 Verified facts (read in this run)

"Working tree" means the checkout as it stands now, and it **includes the running 04.9 implementer's uncommitted
edits**: 04.9's three new Doors files are present, and `AppShell.swift:19` already has
`case diagnosisAnswerCard(DoorAProbeAnswerAdvance)`. I cannot read git objects in this run. So "at `fc7ffa1`" below
means as 04.8 specifies and as the suite asserts, not a byte read of the commit.

| # | Fact | Evidence |
|---|---|---|
| F1 | The suite has 47 `@Test(`. | `rg -c "@Test\("` on the file → 47 |
| F2 | Every Doors-wide scan reads **only** the fixed six-name list `doorFileNames`, not the directory. `combinedDoorsSource()` and `readAllDoors()` iterate that list. | `DoorExpeditionScreensStructuralTests.swift:35-38, 44-52` |
| F3 | `allDoorFilesExist` checks that each listed name exists. It does **not** check that the list is exhaustive. | `:119-126` |
| F4 | `doorBPhaseHasExactlyTwoCases` pins `cases.count == 2`, `case screen(` and `case answerCard(`. Its negative control hard-codes `== 3`. | `:331-343`, `:345-358` |
| F5 | `mathViewHasExactlyThreeCallSitesInDoors` pins a count of 3 plus three named sites over the six listed files. Its control hard-codes `== 4`. | `:692-700`, `:702-713` |
| F6 | `doorsStringLiteralsAreOnlyKnownChrome` asserts `found == ["Continue", "Submit"]` over the six listed files. Its control hard-codes the same pair. | `:717-734`, `:736-753` |
| F7 | `doorBRunScreenActionsMakeExactlyOneCallEach` checks exactly four markers: `submit`, `continueTapped`, `startAnother`, `backToMap`. | `:475-492` |
| F8 | `continueAfterAnswerHasExactlyOneCallSite` counts `DoorFacade\.continueAfterAnswer\(` (which does not match `continueAfterProbeAnswer(`) and isolates the arm `case .answerCard(let advance):` with `caseBranch`. | `:360-399` |
| F9 | `doorBRunScreenHoldsExactlyOneStateProperty` expects exactly `@State private var viewState = DoorBViewState()` in `DoorBRunScreen`. | `:662-674` |
| F10 | 04.9 adds the `DoorBPhase` case `.diagnosisAnswerCard(DoorAProbeAnswerAdvance)`. | 04.9 §2 (AppShell bullet), §4.6 enum block, AC6; working tree `AppShell.swift:16-20` |
| F11 | 04.9 creates `HypothesisCardView.swift`, `RemediationView.swift` and `DiagnosisReturnView.swift` under `App/Sources/Doors`. | 04.9 §2; working tree Glob `App/Sources/Doors/*.swift` → 9 files |
| F12 | 04.9 adds `MathView(latex: step)`, bound by `ForEach(example.stepsLatex, id: \.self) { step in`. | 04.9 §4.3; working tree `RemediationView.swift:16-17` |
| F13 | 04.9 adds the chrome literals `Button("Yes")` and `Button("Not now")` (in two files), plus a second `Button("Continue")`. | 04.9 §4.2, §4.4; working tree `HypothesisCardView.swift:15-16`, `DiagnosisReturnView.swift:24-25,39` |
| F14 | 04.9 adds five `DoorBRunScreen` actions: `decideProbe`, `answerProbeItem`, `continueDiagnosisTapped`, `decideFurtherLevel`, `returnFromDiagnosis`. Each makes one textual `DoorFacade` call. `returnFromDiagnosis`'s standalone arm `if current.isStandaloneDiagnosis {` makes none. | 04.9 §4.6 code, AC7, AC8 |
| F15 | 04.9 adds no `@State` anywhere. It leaves 04.8's four action bodies unchanged except for the new `isStandaloneDiagnosis: false` label, and it does not rename `continueTapped` or `continueAfterAnswer`. | 04.9 §4.6; 04.9 T6 |
| F16 | 04.9's §2 does not name this suite. A grep of `tasks/` for `DoorExpeditionScreensStructural` returns 0 lines. | Grep |
| F17 | The new files contain no `Session`, `attempt`, `@State`, `TextField` or `TextEditor`, and no `"Correct"`/`"Incorrect"`/`"Try again"`. | Grep over `App/Sources/Doors` for `Session\|[Aa]ttempt\|@State\|TextField\|TextEditor` → 0; Read of the 3 files |
| F18 | The Core copy strings exist as public constants: `DoorADiagnosisCopy.costLine`, `.refutedLine`, `.cappedLine`, `.furtherLevelQuestion`. | `Packages/Core/Sources/Core/Door/DiagnosisContent.swift:6-10` |
| F19 | swift-format line length is 110. The longest 04.9 action signature line (`answerProbeItem` / `decideFurtherLevel`, 4-space indent) is about 106 columns, so the markers should stay on one line. | `.swift-format:3`; column count of 04.9 §4.6 signatures |

## 2 Findings: which guards 04.9 breaks (verified one by one)

| Guard | Status under 04.9 as specified | Why |
|---|---|---|
| `doorBPhaseHasExactlyTwoCases` | **BREAKS (red)** | F4 vs F10. The count becomes 3. Already red on the working tree (`AppShell.swift:16-20`). |
| `mathViewHasExactlyThreeCallSitesInDoors` | **Silently loses coverage.** Stays green only because `RemediationView.swift` is not in the list. | F2, F5, F12. Its display text claims "across App/Sources/Doors", which becomes false. It goes red (count 4) the moment the inventory is corrected (§3 E1). |
| `doorsStringLiteralsAreOnlyKnownChrome` | **Silently loses coverage.** Same cause. | F2, F6, F13. It goes red (`found` gains "Yes", "Not now") once the inventory is corrected. |
| `allDoorFilesExist` (":119, all six") | **Stays green; intent lost.** | F3. It never checks exhaustiveness, so three new Doors files escape every Doors-wide guard (I10 `TextField`, the Session/attempt glossary scans, `@State`, correctness copy, forbidden Core types, `MathView`, chrome). |
| `doorsFilesHoldNoStateProperties` | Stays green; loses coverage (six files only). | F2, F17 |
| `noFreeTextEntryInDoors`, `noAppAuthoredCorrectnessCopy`, `noSessionIdentifierInDoors`, `noAttemptWordInDoors`, `noForbiddenCoreTransitionTypeReferenced` | Stay green; the Doors part loses coverage. They stay green after E1 too. | F2, F17. The forbidden list (`:532-537`) has no match in the 04.9 code of §4.2–§4.6 or in working-tree `MapActionsView.swift`. |
| `doorBRunScreenActionsMakeExactlyOneCallEach` | **Stays green; does not cover 04.9's five new actions.** | F7, F14, F15 |
| `continueAfterAnswerHasExactlyOneCallSite` | **Stays green; does not cover the Door A probe answer card.** | F8. `caseBranch("case .answerCard(let advance):")` stops at the next `case .diagnosisAnswerCard(` line, and the regex does not match `continueAfterProbeAnswer(`. |
| `doorBRunScreenHoldsExactlyOneStateProperty` | Stays green, no change needed. | F9, F15 |
| `runSnapshotAndStartOutcomeAreNotEquatable`, `noHandRolledEqualityOverCoreState`, `submitPerformsNoPreconditionOnRawInput`, `backToMapReplacesMapHolderBeforeDismiss`, `writeFailureBannerResolvesOnlyViaCoreErrorText`, `mapActionButtonsMakeExactlyOneDoorFacadeCallEach`, all AC1–AC5 per-file tests (keypad, choices, item view, retry, answer card, summary) | Stay green, no change needed. | Each reads a file or body that 04.9 does not change (F15). `struct DoorBRunSnapshot {` and `enum DoorBPhase: Equatable {` are kept (04.9 §4.6). The `.summary` arm still has exactly one `CoreErrorText.text(for:`. |

**Summary.** Exactly **one** guard goes red (`doorBPhaseHasExactlyTwoCases`). Two more (`MathView` count, chrome
allow-list) are hidden only by the stale six-file inventory, and they would go red as soon as the inventory is made
honest. Two I14/I3 guards stay green but stop covering the shapes 04.9 adds. Leaving the inventory stale would make
the suite's I10/glossary/copy claims false for 04.9's files. That is a silent weakening, so this ruling rejects it.

## 3 Ruling on the assertions (post-04.9 shape, list-driven)

Principles, as in the parent ruling:
- Each re-scoped guard reads its expected shape from one `private static let` list.
- Every negative control is written relative to that list (`expected.count + 1`), so a later task changes one entry
  and no guard logic.
- The code below is normative and its layout follows swift-format. Run `xcrun swift-format format -i` on the file,
  then `lint --strict` must be clean. Test display strings and long marker literals may exceed 110 columns, as the
  existing ones already do (`:361`, `:371`).

### E0 — header doc comment (`:6-8`)

Old: ``/// Comprehensive structural (source-text) guards for task 04.8 (`tasks/epic-04-task-08-app-expedition-screens.md`):
/// the six `App/Sources/Doors/*.swift` files, plus``
New: ``/// Comprehensive structural (source-text) guards for task 04.8 (`tasks/epic-04-task-08-app-expedition-screens.md`),
/// as updated in lockstep by task 04.9 (`tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md`):
/// every `App/Sources/Doors/*.swift` file (`doorFileNames`), plus``
Also in the header: old `the parts of … this task adds` becomes `the parts of … 04.8 and 04.9 add`. The C3
exclusion paragraph does not change.

### E1 — Doors inventory: `doorFileNames` (`:35-38`) and `allDoorFilesExist` (`:117-126`); keeps the "Doors file inventory" intent and adds exhaustiveness

Replace `:35-38` with:

```swift
    /// Every `.swift` file in `App/Sources/Doors` after task 04.9 (§4.2–§4.4). Every Doors-wide scan in this suite
    /// reads exactly this list, and `allDoorFilesExistAndListIsExhaustive` fails when the directory and the list
    /// differ, so a later task that adds a Doors file adds one entry here.
    private static let doorFileNames = [
        "ExpeditionItemView.swift", "ExpeditionAnswerCardView.swift", "ExpeditionSummaryView.swift",
        "NumericKeypadView.swift", "ChoiceButtonsView.swift", "DoorBViewState.swift",
        "HypothesisCardView.swift", "RemediationView.swift", "DiagnosisReturnView.swift",
    ]
```

Replace `:117-126` (the MARK line through the closing brace of `allDoorFilesExist()`) with:

```swift
    // MARK: - Fixture presence (every App/Sources/Doors file is listed, and every listed file exists)

    @Test("every listed App/Sources/Doors file exists, and the list names every .swift file in the directory")
    func allDoorFilesExistAndListIsExhaustive() throws {
        for name in Self.doorFileNames {
            #expect(
                FileManager.default.fileExists(atPath: Self.doorsRoot.appendingPathComponent(name).path),
                "missing file: \(name)")
        }
        let onDisk = try FileManager.default.contentsOfDirectory(atPath: Self.doorsRoot.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!onDisk.isEmpty, "App/Sources/Doors holds no .swift file (empty = FAIL)")
        #expect(
            Set(onDisk) == Set(Self.doorFileNames),
            "Doors inventory drift — unlisted: \(Set(onDisk).subtracting(Self.doorFileNames)), missing: \(Set(Self.doorFileNames).subtracting(onDisk))"
        )
    }

    @Test("negative control: a Doors file absent from doorFileNames is caught by the inventory comparison")
    func plantedUnlistedDoorsFileIsCaught() {
        let onDisk = Self.doorFileNames + ["ProbeView.swift"]
        #expect(Set(onDisk) != Set(Self.doorFileNames), "planted unlisted Doors file was not detected")
    }
```

Also change the `doorsFilesHoldNoStateProperties` display string (`:648`). Old: `"@State discipline: zero @State
properties across all six App/Sources/Doors files (pure render layer)"`. New: `"@State discipline: zero @State
properties across every App/Sources/Doors file (pure render layer)"`. Its logic does not change; it now reads nine
files (F17: 0 matches).

### E2 — I3 phase discipline: replace `:331-358` (both tests) — **the one hard break**

```swift
    /// The exact `DoorBPhase` case prefixes after task 04.9 (§4.6). Each phase is a distinct, explicit render
    /// state that only its own continue control leaves (I3); a later task that adds a phase edits this list only.
    private static let expectedDoorBPhaseCasePrefixes = [
        "case screen(", "case answerCard(", "case diagnosisAnswerCard(",
    ]

    @Test("I3: DoorBPhase declares exactly the expected cases (.screen, .answerCard, .diagnosisAnswerCard)")
    func doorBPhaseHasExactlyTheExpectedCases() throws {
        let source = try Self.readShell()
        guard let body = Self.balancedBraceBlock(after: "enum DoorBPhase: Equatable {", in: source) else {
            Issue.record("could not locate DoorBPhase's body")
            return
        }
        let cases = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
        let expected = Self.expectedDoorBPhaseCasePrefixes
        #expect(cases.count == expected.count, "expected \(expected.count) DoorBPhase cases, found: \(cases)")
        for prefix in expected {
            #expect(
                cases.filter { $0.hasPrefix(prefix) }.count == 1, "expected exactly one \(prefix) case: \(cases)")
        }
    }

    @Test("negative control: a planted extra DoorBPhase case is caught")
    func plantedExtraDoorBPhaseCaseIsCaught() {
        let fixture = """
            enum DoorBPhase: Equatable {
                case screen(DoorBScreen)
                case answerCard(DoorBAnswerAdvance)
                case diagnosisAnswerCard(DoorAProbeAnswerAdvance)
                case autoAdvancing
            }
            """
        guard let body = Self.balancedBraceBlock(after: "enum DoorBPhase: Equatable {", in: fixture) else {
            Issue.record("fixture setup failed")
            return
        }
        let cases = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
        #expect(
            cases.count == Self.expectedDoorBPhaseCasePrefixes.count + 1,
            "planted extra DoorBPhase case was not detected: \(cases)")
    }
```

### E3 — I3 answer-card routing: replace `continueAfterAnswerHasExactlyOneCallSite` (`:360-399`); the control `plantedAnswerCardBypassIsCaught` (`:401-416`) is unchanged

```swift
    /// Each answer-card `DoorBPhase` arm, the one `DoorFacade` continue entry that alone leaves it, the action
    /// method that makes that call, and the call its continue control makes (I3): 04.8's Door B card and 04.9's
    /// Door A probe card (§4.6). A later answer-card phase adds one entry.
    private static let expectedAnswerCardRoutes:
        [(arm: String, facadeCall: String, action: String, onContinue: String)] = [
            (
                arm: "case .answerCard(let advance):", facadeCall: "DoorFacade.continueAfterAnswer(",
                action: "private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {",
                onContinue: "continueTapped(advance, current: current)"
            ),
            (
                arm: "case .diagnosisAnswerCard(let advance):", facadeCall: "DoorFacade.continueAfterProbeAnswer(",
                action:
                    "private func continueDiagnosisTapped(_ advance: DoorAProbeAnswerAdvance, current: DoorBRunSnapshot) {",
                onContinue: "continueDiagnosisTapped(advance, current: current)"
            ),
        ]

    @Test(
        "I3: each answer-card phase is left only via its one DoorFacade continue call, reached only from that phase's ExpeditionAnswerCardView continue control"
    )
    func answerCardPhasesAreLeftOnlyViaTheirContinueCall() throws {
        let shell = try Self.readShell()
        guard let content = Self.balancedBraceBlock(after: "switch current.phase {", in: shell) else {
            Issue.record("could not locate DoorBRunScreen's phase switch")
            return
        }
        for route in Self.expectedAnswerCardRoutes {
            #expect(
                shell.components(separatedBy: route.facadeCall).count - 1 == 1,
                "\(route.facadeCall) must have exactly one call site, in its continue action")
            guard let action = Self.balancedBraceBlock(after: route.action, in: shell) else {
                Issue.record("could not locate the body of \(route.action)")
                continue
            }
            #expect(action.contains(route.facadeCall))
            guard let arm = Self.caseBranch(startingWith: route.arm, in: content) else {
                Issue.record("could not locate the \(route.arm) arm")
                continue
            }
            #expect(arm.contains("ExpeditionAnswerCardView("), "\(route.arm) must render the answer card")
            #expect(arm.contains(route.onContinue), "\(route.arm)'s onContinue must call \(route.onContinue)")
            for next in [
                "ExpeditionItemView(", "ExpeditionSummaryView(", "HypothesisCardView(", "DiagnosisReturnView(",
                "diagnosisContent(",
            ] {
                #expect(!arm.contains(next), "\(route.arm) must not itself render the next screen (\(next))")
            }
        }
    }
```

This keeps every assertion of the old test for the `.answerCard` route. Its `DoorFacade\.continueAfterAnswer\(`
regex count becomes an equivalent literal-substring count over the same raw source. The only change is that the
route is now one list entry.

### E4 — I14 one call per action: replace the local `markers` in `doorBRunScreenActionsMakeExactlyOneCallEach` (`:475-492`); the control `:494-508` is unchanged

```swift
    /// Every `DoorBRunScreen` action method, by its exact signature text through the opening `{`, each making
    /// exactly one textual `DoorFacade` call (I14): 04.8's four, plus 04.9's five (§4.6). `returnFromDiagnosis`'s
    /// one call is `resumeAfterDiagnosis`, in its non-standalone arm; its standalone arm makes none (04.5 AC8),
    /// asserted separately. A later action adds one entry.
    private static let expectedDoorBRunScreenActionMarkers = [
        "private func submit(_ value: String, current: DoorBRunSnapshot) {",
        "private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {",
        "private func startAnother(current: DoorBRunSnapshot) {",
        "private func backToMap(current: DoorBRunSnapshot) {",
        "private func decideProbe(_ offer: ProbeOffer, accept: Bool, current: DoorBRunSnapshot) {",
        "private func answerProbeItem(_ probe: ProbeInProgress, submitted: String, current: DoorBRunSnapshot) {",
        "private func continueDiagnosisTapped(_ advance: DoorAProbeAnswerAdvance, current: DoorBRunSnapshot) {",
        "private func decideFurtherLevel(_ offer: FurtherLevelOffer, accept: Bool, current: DoorBRunSnapshot) {",
        "private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {",
    ]

    @Test(
        "I14: each listed DoorBRunScreen action method makes exactly one DoorFacade call; the standalone diagnosis return makes none"
    )
    func doorBRunScreenActionsMakeExactlyOneCallEach() throws {
        let shell = try Self.readShell()
        for marker in Self.expectedDoorBRunScreenActionMarkers {
            guard let body = Self.balancedBraceBlock(after: marker, in: shell) else {
                Issue.record("could not locate body for \(marker)")
                continue
            }
            let count = Self.matchCount(of: Self.doorFacadeCallPattern, in: body)
            #expect(count == 1, "expected exactly one DoorFacade call in \(marker), found \(count)")
        }
        guard let standalone = Self.balancedBraceBlock(after: "if current.isStandaloneDiagnosis {", in: shell) else {
            Issue.record("could not locate returnFromDiagnosis's standalone arm")
            return
        }
        #expect(
            Self.matchCount(of: Self.doorFacadeCallPattern, in: standalone) == 0,
            "the standalone map_check_here return calls no DoorFacade entry (04.5 AC8, 04.9 AC8)")
    }
```

Markers are the landed signature text. If swift-format wraps a signature, which F19 says it should not, the
marker must copy the landed text including the line break. A marker that matches nothing records an `Issue`
(empty = FAIL). It never passes silently. The existing control (`plantedSecondDoorFacadeCallInSubmitIsCaught`)
already shows that the count pattern detects calls. The zero-count assertion uses the same pattern.

### E5 — `MathView` routing: replace `:690-713` (both tests)

```swift
    // MARK: - MathView usage: exactly the expected call sites, each routing a latex field

    /// Every `MathView(latex:)` call site in `App/Sources/Doors` after task 04.9, each routing a latex field
    /// (`contracts/data-model.md` § Text): 04.8's prompt, choice label and latex answer; 04.9's worked-example
    /// step (§4.3). `why`, hint prose and every plain field never reach `MathView`. A later site adds one entry.
    private static let expectedMathViewSites = [
        "MathView(latex: content.promptLatex)", "MathView(latex: choice.latex)",
        "MathView(latex: content.correctAnswerDisplay)", "MathView(latex: step)",
    ]

    @Test("MathView: the App/Sources/Doors call sites are exactly the expected set, each field-routed")
    func mathViewCallSitesAreExactlyTheExpectedSet() throws {
        let combined = try Self.combinedDoorsSource()
        let count = Self.matchCount(of: #"MathView\(latex:"#, in: combined)
        let expected = Self.expectedMathViewSites
        #expect(count == expected.count, "expected \(expected.count) MathView(latex:) call sites, found \(count)")
        for site in expected {
            #expect(combined.components(separatedBy: site).count - 1 == 1, "expected exactly one \(site)")
        }
        let remediation = try Self.readDoor("RemediationView.swift")
        #expect(
            remediation.contains("ForEach(example.stepsLatex, id: \\.self) { step in"),
            "`step` must be bound from WorkedExample.stepsLatex, never from a plain-text field")
    }

    @Test("negative control: a planted extra MathView(latex:) call site (why, rendered as latex) is caught")
    func plantedExtraMathViewCallSiteIsCaught() {
        let fixture = (Self.expectedMathViewSites + ["MathView(latex: content.why)"]).joined(separator: "\n")
        #expect(
            Self.matchCount(of: #"MathView\(latex:"#, in: fixture) == Self.expectedMathViewSites.count + 1,
            "planted extra MathView call site was not detected")
    }
```

### E6 — chrome-only literals: `:715-753` (both tests)

Add, directly above `doorsStringLiteralsAreOnlyKnownChrome`:

```swift
    /// The App-authored chrome labels permitted in `App/Sources/Doors`: 1–2 words each, never a `Core`-supplied
    /// string. 04.8: "Continue", "Submit" (04.8 §4.6); 04.9: "Yes", "Not now" (04.9 §4.2, §4.4, §6). A later task
    /// that adds a chrome label adds one entry here.
    private static let doorsChromeAllowList: Set<String> = ["Continue", "Submit", "Yes", "Not now"]
```

In `doorsStringLiteralsAreOnlyKnownChrome()`, replace `let allowList: Set<String> = ["Continue", "Submit"]` with
`let allowList = Self.doorsChromeAllowList`. Keep the `found == allowList` expectation. Append after it:

```swift
        for label in allowList {
            #expect(label.split(separator: " ").count <= 2, "chrome label \"\(label)\" exceeds 2 words")
        }
        for copy in [
            DoorADiagnosisCopy.costLine, DoorADiagnosisCopy.refutedLine, DoorADiagnosisCopy.cappedLine,
            DoorADiagnosisCopy.furtherLevelQuestion,
        ] {
            #expect(!combined.contains("\"\(copy)\""), "Core copy duplicated as an App string literal: \(copy)")
        }
```

In `plantedForeignChromeLiteralIsCaught()`, replace `!found.subtracting(["Continue", "Submit"]).isEmpty` with
`!found.subtracting(Self.doorsChromeAllowList).isEmpty`. Append:

```swift
        #expect(
            "Include in my next expedition".split(separator: " ").count > 2,
            "a 4-word label was not caught by the 2-word bound")
        let plantedCoreCopy = "Text(\"\(DoorADiagnosisCopy.costLine)\")"
        #expect(
            plantedCoreCopy.contains("\"\(DoorADiagnosisCopy.costLine)\""),
            "planted Core copy literal was not detected")
```

The chrome stays App-authored chrome only: "Yes" and "Not now" are 1 and 2 words and match no `DoorADiagnosisCopy`
value (F18). Every Door A content string still comes from `Core` (04.9 §1).

### Tests not touched

Every other test in the file stays byte-unchanged (§2 table). `@Test(` count goes from **47 to 48**. The one
addition is `plantedUnlistedDoorsFileIsCaught`. Four tests are renamed in place: `allDoorFilesExist`,
`doorBPhaseHasExactlyTwoCases` / `plantedThirdDoorBPhaseCaseIsCaught`, `continueAfterAnswerHasExactlyOneCallSite`,
and `mathViewHasExactlyThreeCallSitesInDoors` / `plantedFourthMathViewCallSiteIsCaught`. No test is deleted, and none
is `.disabled`.

### Intent kept, guard by guard

| Old guard | Intent | New guard | Negative control |
|---|---|---|---|
| `allDoorFilesExist` | Doors file inventory | `allDoorFilesExistAndListIsExhaustive` (now exhaustive) | `plantedUnlistedDoorsFileIsCaught` (new) |
| `doorBPhaseHasExactlyTwoCases` | I3 phase discipline | `doorBPhaseHasExactlyTheExpectedCases` | `plantedExtraDoorBPhaseCaseIsCaught` (list-relative) |
| `continueAfterAnswerHasExactlyOneCallSite` | I3 only continue leaves a card | `answerCardPhasesAreLeftOnlyViaTheirContinueCall` (both cards) | `plantedAnswerCardBypassIsCaught` (unchanged) |
| `doorBRunScreenActionsMakeExactlyOneCallEach` | I14 one call per action | same name, list of 9, plus the standalone arm = 0 | `plantedSecondDoorFacadeCallInSubmitIsCaught` (unchanged) |
| `mathViewHasExactlyThreeCallSitesInDoors` | `MathView` routes latex fields only | `mathViewCallSitesAreExactlyTheExpectedSet` | `plantedExtraMathViewCallSiteIsCaught` (list-relative) |
| `doorsStringLiteralsAreOnlyKnownChrome` | chrome-only literals | same name, list-driven, plus ≤ 2 words and no Core copy | `plantedForeignChromeLiteralIsCaught` (list-relative, extended) |
| `doorsFilesHoldNoStateProperties` / `doorBRunScreenHoldsExactlyOneStateProperty` | `@State` discipline | unchanged logic, now over 9 files / unchanged | unchanged |

## 4 Exact 04.9 spec edits (`tasks/epic-04-task-09-app-diagnosis-screens.md`, old → new)

Several "old" anchors wrap across source lines. Match them as text.

- **A1 (Branch note, first bullet).** Old: `` / `MapPanelsPickersHandOffStructuralTests.swift` carry 04.8's §4.14 re-scoped guards (also quoted verbatim §3,
  from 04.8's own already-written spec, since neither file exists yet on the tree used to write this spec).``
  New: `` / `MapPanelsPickersHandOffStructuralTests.swift` carry 04.8's §4.14 re-scoped guards (also quoted verbatim §3,
  from 04.8's own already-written spec, since neither file exists yet on the tree used to write this spec), and
  `Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift` exists as 04.8's tester committed it
  (`fc7ffa1`, 47 `@Test`s).``
- **A2 (§2 In-scope).** After the bullet that ends ``Lockstep list deltas for AC4's `.diagnosisStarted` case and `DoorFacade.checkHere` call — exactly
  §4.11.2.``, append:
  ``- `Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift` — MODIFY (04.8 tester's file, commit `fc7ffa1`). Lockstep update, in this task's commit, of the 04.8 guards that this task's §4.2–§4.4 (three new Doors files, `MathView(latex: step)`, "Yes"/"Not now") and §4.6 (`.diagnosisAnswerCard`, five new actions) invalidate or would silently stop covering — exactly §4.11.3; no other test in the file is edited.``
- **A3 (§2 Out-of-scope, first bullet).** Old: ``(except the two structural-suite test files listed in-scope above)``
  New: ``(except the three structural-suite test files listed in-scope above)``
- **A4 (§4.11 heading and lead-in).** Old: `### 4.11 Lockstep EPIC 03 structural-guard updates` New: `### 4.11 Lockstep
  structural-guard updates (EPIC 03 suites and 04.8's Doors suite)`. After the existing lead-in line `(from
  tasks/arbitration/arbiter-04-08-structural-suite-ownership.md §5)`, add: ``§4.11.3 is from
  `tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md` §3.``
- **A5 (end of §4.11.2).** Old: ``@Test(` counts after 04.9: AppShell 44, MapPanels 38. No test is added or removed.``
  New: ``@Test(` counts after 04.9: AppShell 44, MapPanels 38 (no test added or removed in either);
  DoorExpeditionScreens 48 (47 + one negative control, §4.11.3 E1).``
- **A6 (new §4.11.3, inserted after A5's line, before `## §5`).** Insert `#### 4.11.3
  DoorExpeditionScreensStructuralTests.swift`. Under it, insert this lead paragraph:
  > 04.8's tester pins 04.8's exact Doors shapes. This task changes them (§4.2–§4.4, §4.6), so it updates the
  > suite in its own commit. Each guard keeps its intent and its negative control, and each reads its expected
  > shape from one `private static let` list, so a later task changes one entry
  > (`tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md`).

  Then paste addendum §3 **E0–E6 verbatim** (instructions plus code blocks), followed by the addendum's "Tests not
  touched" paragraph and its "Intent kept" table.
- **A7 (AC9).** Old: ``including the two EPIC 03 structural suites as updated by §4.11 —`` New: ``including the two
  EPIC 03 structural suites and 04.8's `DoorExpeditionScreensStructuralTests.swift` as updated by §4.11 —``
- **A8 (§5 T5).** Directly after the sub-bullet `    - Test counts stay 44/38.`, append at the same level as
  `- EPIC 03 structural guards, re-scoped (§4.11):`:
  > - 04.8's Doors structural suite, re-scoped (§4.11.3):
  >   - Assertions: `allDoorFilesExistAndListIsExhaustive`, `doorBPhaseHasExactlyTheExpectedCases`,
  >     `answerCardPhasesAreLeftOnlyViaTheirContinueCall`, `doorBRunScreenActionsMakeExactlyOneCallEach`,
  >     `mathViewCallSitesAreExactlyTheExpectedSet`, `doorsStringLiteralsAreOnlyKnownChrome`, each over its
  >     `private static let` list; every other Doors-wide guard now reads all nine `App/Sources/Doors` files.
  >   - Instrument: Swift Testing `#expect` over source text, gate 3 on the simulator; excludes runtime, tap and
  >     presentation behaviour (C3). An extractor or marker that matches nothing records an `Issue` (empty = FAIL);
  >     an empty `App/Sources/Doors` = FAIL.
  >   - Negative controls: `plantedUnlistedDoorsFileIsCaught` (new), `plantedExtraDoorBPhaseCaseIsCaught`,
  >     `plantedAnswerCardBypassIsCaught`, `plantedSecondDoorFacadeCallInSubmitIsCaught`,
  >     `plantedExtraMathViewCallSiteIsCaught`, `plantedForeignChromeLiteralIsCaught` — list-relative where they
  >     count.
  >   - Test count: `rg -c "@Test\("` gives 48, up from 47. No guard is deleted.
- **A9 (§5 T6).** Old: ``shows no new instance beyond 04.8's own
  `DoorBViewState`/button `errorText` fields (this task adds none)``
  New: ``shows zero matches (this task adds none; pinned by `doorsFilesHoldNoStateProperties` over all nine Doors
  files, §4.11.3), and `DoorBRunScreen` keeps exactly one (`doorBRunScreenHoldsExactlyOneStateProperty`)``.
  This fixes an inaccuracy found while verifying: `App/Sources/Doors` has no `@State` (F17), and the two
  `errorText` properties live in `MapUI` (`MapActionsView.swift:77,111`).
- **A10 (§6, the default beginning `IF an EPIC 03 structural guard pins`).** Old: ``IF an EPIC 03 structural guard pins
  a shape this task's ACs change`` New: ``IF an EPIC 03 structural guard, or a 04.8 guard in
  `DoorExpeditionScreensStructuralTests.swift`, pins a shape this task's ACs change``. At its end, old:
  ``(`tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`)`` New:
  ``(`tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`, `tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md`)``
- **A11 (§6, append).**
  > - IF a Doors-wide guard reads a fixed file list that omits this task's new Doors files (so it stays green
  >   while no longer scanning them) THEN the list is extended and made exhaustive against the directory
  >   (§4.11.3 E1). A guard that passes only because it cannot see the new code is a silent weakening, not a
  >   pass (`tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md` §2).
- **A12 (§7).** Old: ``This includes `AppShellStructuralTests.swift` and
  `MapPanelsPickersHandOffStructuralTests.swift` as updated by §4.11.`` New: ``This includes
  `AppShellStructuralTests.swift`, `MapPanelsPickersHandOffStructuralTests.swift` and
  `DoorExpeditionScreensStructuralTests.swift` as updated by §4.11.``

### Updated dispatch note (orchestrator, replaces the parent ruling's §7.3 text for 04.9)

"Gate 3 must be green at commit. The 03.9 `AppSourcesBoundary` scan and `MapCanvasViewStructuralTests` (03.10) stay
green unmodified. `AppShellStructuralTests.swift` (03.12), `MapPanelsPickersHandOffStructuralTests.swift` (03.11)
and `DoorExpeditionScreensStructuralTests.swift` (04.8 tester, `fc7ffa1`) are updated in this task's commit exactly
per §4.11.1–§4.11.3. No other test in those files may be edited, and none may be deleted, `.disabled` or left red."

**For the running implementer.** Apply A1–A12 to the spec, then resume the 04.9 implementer on the updated spec.
Its working-tree product edits stand. It adds the §4.11.3 edits to the same commit. Its pending BLOCK on this file
is resolved by this addendum and needs no other change.

## 5 04.10 and 04.12

- **04.10: no.**
  - Its §2 creates `DoorAppSourcesBoundaryTests.swift` and modifies `AppSourcesBoundaryTests.swift` and
    `AppSourcesBoundaryNegativeControlTests.swift` (04.10 spec lines 129-145). It lists `App/Sources/**` as
    read-only (:149-151).
  - So it adds no Doors file, no `DoorBPhase` case, no `MathView` site, no chrome literal and no `DoorBRunScreen`
    action. Every list in §3 stays valid.
  - A grep of 04.10 for `DoorExpeditionScreensStructural|DoorBPhase|MathView` returns 0 lines.
  - Its rule (g) `doorCopyRule` over `Doors` (4+ words) agrees with E6's ≤ 2-word allow-list.
  - Cosmetic only: 04.10's Branch note (:19) says "04.8's five files", but 04.8 has six. The note is prose, and no
    assertion depends on it, so no edit is required.
- **04.12: no.** It is a contract-only task. Its out-of-scope list has `Packages/Core/**`, `App/Sources/**` read-only
  (04.12 spec :77), and a grep for this suite, `DoorBPhase` or `MathView` returns 0 lines.

## 6 Prevention (advice for the orchestrator's future tester prompts, not a spec edit)

When a tester authors a structural (source-text) suite over files that a later task **in the same EPIC** is
specified to modify, add this to its prompt:
- Read the later specs' §2 and §4 first. Write every shape-pinning expectation (case lists, call-site sets, file
  inventories, chrome allow-lists, per-action call counts) as one `private static let` list, and make each negative
  control relative to that list (`expected.count + 1`), not to a literal count.
- Make every "anywhere in directory X" scan exhaustive against the directory listing, not a hard-coded file list.
  Otherwise a later file silently escapes the scan, as happened here.
- List in the test commit message which later tasks will need a list-entry update.

This costs a few lines per suite. It turns each later task's lockstep edit into a one-entry substitution the spec
can quote, instead of another arbitration.

## 7 Verification

### Pre-edit baseline (live, working tree including the running 04.9 implementer's uncommitted edits)

| Check | Command | Live result |
|---|---|---|
| B1 | `rg -c "@Test\(" Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift` | 47 |
| B2 | `rg -n "^    case " App/Sources/Shell/AppShell.swift` inside `enum DoorBPhase` | 3 (`:17-19`), so the guard's `== 2` is red |
| B3 | `rg --files App/Sources/Doors -g '*.swift'` | 9 files; `doorFileNames` lists 6 |
| B4 | `rg -n "MathView\(latex:" App/Sources/Doors` | 4 (`ExpeditionItemView:19`, `ExpeditionAnswerCardView:17`, `ChoiceButtonsView:18`, `RemediationView:17`); 3 within the listed six |
| B5 | `rg -n '(Text\|Button)\("[^"]+"\)' App/Sources/Doors` | 7 lines. Distinct values {Submit, Continue, Yes, Not now}; within the listed six: {Submit, Continue} |
| B6 | `rg -n "Session\|[Aa]ttempt\|@State\|TextField\|TextEditor" App/Sources/Doors` | 0 |
| B7 | `rg -n "DoorFacade\.continueAfterAnswer\(" App/Sources/Shell/AppShell.swift` | 1 (`:281`) |
| B8 | `rg -n "DoorExpeditionScreensStructural" tasks/epic-04-task-09-app-diagnosis-screens.md` | 0 |

### Post-edit checks

Spec level, after A1–A12:
1. `rg -n "DoorExpeditionScreensStructuralTests" tasks/epic-04-task-09-app-diagnosis-screens.md`. Pass: ≥ 5 lines
   (Branch note, §2, AC9, §4.11.3, §5 T5, §6, §7). Empty = FAIL.
2. `rg -n "#### 4.11.3" tasks/epic-04-task-09-app-diagnosis-screens.md`. Pass: exactly 1 line.
3. `rg -n "except the two structural-suite" tasks/epic-04-task-09-app-diagnosis-screens.md`. Pass: 0 lines
   (empty = PASS).

Code level, after the 04.9 commit:

4. `rg -c "@Test\(" Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift`. Pass: `48`.
5. `rg -n 'cases.count == 2|count == 3,|== 4,|\["Continue", "Submit"\]|all six' Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift`.
   Pass: 0 lines (empty = PASS). Live before: 5 or more (`:340`, `:357`, `:696`, `:711`, `:731`, `:751`, `:119`,
   `:648`).
6. `rg -n "expectedDoorBPhaseCasePrefixes|expectedAnswerCardRoutes|expectedDoorBRunScreenActionMarkers|expectedMathViewSites|doorsChromeAllowList" Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift`.
   Pass: ≥ 10 lines (each list declared and read at least once, including by its control). Empty = FAIL.
7. The count of `rg --files App/Sources/Doors -g '*.swift'` equals the number of `doorFileNames` entries: 9 = 9.
8. `git diff --name-only fc7ffa1..HEAD -- Packages/Core`. Pass: exactly the three structural files
   (`AppShellStructuralTests.swift`, `MapPanelsPickersHandOffStructuralTests.swift`,
   `DoorExpeditionScreensStructuralTests.swift`).
9. `scripts/gate.sh` passes all four gates (instrument: the gates; gate 3 is `Core` tests on the simulator, which
   excludes physical-device behaviour, D29). Also the parent ruling's §8 checks 9–11 (AppShell 44, MapPanels 38).

# Arbiter ruling: EPIC 03 structural suites vs 04.8/04.9 (ownership, landing, exact assertions)

**Date**: 2026-09-11
**Trigger**: an implementer BLOCK, `tasks/blocked/blocked-04-08.md`. Gate 3 failed with 11 recorded issues in 7
tests across 2 pre-existing `CoreTests` files, and both files are outside 04.8's §2.
**Verdict**: **Option (a), lockstep in-task ownership.**

- 04.8's §2 is widened to MODIFY both files, with the exact edits in §4.1 and §4.2 below.
- 04.9's §2 is widened the same way, with the deltas in §5 below.
- Each task updates the guards its own ACs invalidate, **in the same commit** as the product change.
- **No separate test-only task** (no 04.8a). **04.10 needs a spec edit now** for a different, pre-existing
  defect: its rule (g) is red on EPIC 03 code (§6).
- The orchestrator's dispatch note "the 03.10–03.12 structural suites must stay green" was wrong for these
  two files. The corrected text is in §7.

This is a spec-level resolution, not a decomposition escalation.

- 04.8 → 04.9 → 04.10 are already strictly sequential (04.9 `depends_on: [04.8]`; 04.10 `depends_on: [04.8,
  04.9]`).
- 04.8 and 04.9 already write the same two App files in that order. Adding the two test guards that pin
  those files follows the identical sequential pattern.
- No task is reordered or added, and no parallel write conflict is created.
- 04.10 writes neither structural file.

## 1 Verified facts (read in this run)

| # | Fact | Evidence |
|---|---|---|
| F1 | 03.12's switch guard pins 2 clauses, one literally `case .diagnosis, .unitExpedition:`. | `AppShellStructuralTests.swift:139-141` |
| F2 | 03.12's placeholder guard locates its branch by that literal. | `AppShellStructuralTests.swift:170` |
| F3 | 03.12's text-source guard pins exactly 2 `CoreErrorText.text(for:` sites across Shell. | `AppShellStructuralTests.swift:340-343` |
| F4 | 03.11 pins the case text `unitExpedition(result: ComposeResult)`. | `MapPanelsPickersHandOffStructuralTests.swift:208` |
| F5 | 03.11 pins 3 `MapFacade.` sites, including `MapFacade.unitExpedition(`, 3 `handOff(` sites and `handOff(.unitExpedition(result: result))`. | `MapPanelsPickersHandOffStructuralTests.swift:236-249` |
| F6 | 03.11 pins exactly 1 `CoreErrorText.text(for:` in `MapActionsView.swift`. | `MapPanelsPickersHandOffStructuralTests.swift:576-580` |
| F7 | 03.11 pins exactly 1 `@State` across the six MapUI files. | `MapPanelsPickersHandOffStructuralTests.swift:498` |
| F8 | 04.8 mandates the shapes that break F1–F7. | `tasks/epic-04-task-08-app-expedition-screens.md` AC6, AC7, §4.8 (`.doorBStarted`; `StartExpeditionActionButton` with a second `@State private var errorText: String?`; `DoorFacade.startUnitExpedition`), §4.9 (3 clauses; `flatMap(CoreErrorText.text(for:))` and `CoreErrorText.text(for: error)` added to `AppShell.swift`) |
| F9 | 04.8 names neither test file anywhere. §7 claims only the 03.9 scan and 03.12's smoke stay green. | A grep of 04.8 for either filename returns 0 lines. 04.8 §7 has only the 03.9 bullet and the sim-smoke bullet. |
| F10 | Recount of the 11 issues. AppShell: 2 (F1), 1 (F2), 1 (F3). MapPanels: 1 (F4), 4 (F5), 1 (F6), 1 (F7). | Derived from the expectations at the lines above against 04.8 §4.8/§4.9 |
| F11 | 04.9 re-breaks the same guards. | 04.9 §4.5 replaces `.diagnosis(event:)` with `.diagnosisStarted(DoorAStartOutcome)` and `MapFacade.checkHere(` with `DoorFacade.checkHere(`; its `handOff(` wraps before `.diagnosisStarted(`. 04.9 §4.6 removes the `.diagnosis:` placeholder clause and adds `CoreErrorText.text(for: coreError)`. |
| F12 | swift-format line length is 110. 04.8's `handOff(.doorBStarted(DoorBStartOutcome(…)))` is 116 columns at 12-space indent, so it will wrap. | `.swift-format:3` |
| F13 | Guards that 04.8/04.9 do **not** break were checked one by one against 04.8 §4.8/§4.9 and 04.9 §4.5/§4.6. | `phaseHasExactlyFourCases`: marker `private enum Phase {`, not matched by `enum DoorBPhase`. `MapLaunch.open` count 1. PLATFORM_ literal. Glossary (code-only in Shell). AC10 forbidden constructs (`Expedition.` never appears: `startUnitExpedition(`/`StartExpeditionActionButton` have no `.` after `Expedition`). `unitExpeditionButtonCallsHandOffOnlyOnSuccess` (first catch block stays clean). `AppSourcesBoundary.defaultRules` (`\bExpedition\b` is case-sensitive and whole-word). `AppSourcesBoundaryAuditTests.swift:45-48` (`>= 2` plus two names). |
| F14 | `MapCanvasViewStructuralTests` reads only `App/Sources/Map/*`. `DoorFacadeConformanceTests` reads no `App/Sources` file. | `MapCanvasViewStructuralTests.swift:27,30,123,146,313,357`; a grep of `DoorFacadeConformanceTests.swift` for `App/` returns 0 |
| F15 | 04.10's rule (g) (a 4+-word `Text("…")`/`Button("…")` literal) runs over the whole `App/Sources` tree. It is already red on three EPIC 03 lines. | `MapActionsView.swift:38` `Button("Include in my next expedition")` (5 words). `UnitListPickerView.swift:19` `Button("Past the last unit")` (4). `RegionPanelView.swift:16` `Text("\(Int((fraction * 100).rounded()))% cleared")` (4 space-split tokens). 04.10 AC1 runs `violations(in: App/Sources, rules: defaultRules + doorRules)`. Its §6 claim that "every real, landed chrome literal … is 1–3 words" is false. |
| F16 | 04.10 AC5 matches the landed code. | `DoorFacadeSeamTests.swift` calls exactly {startExpedition, answer, continueAfterAnswer, decideProbe, answerProbeItem, continueAfterProbeAnswer, resumeAfterDiagnosis, checkHere} (grep, 22 call sites) |
| F17 | 04.10 AC6 matches the landed code. | `MapLaunch.swift` declares 7 `public static func` inside `enum DoorFacade` (`:301`, entries at `:344-438`) and 5 inside `extension DoorFacade` (`:451`, entries at `:455-505`), which is 12 |
| F18 | The `@Test(` counts before any edit are AppShell 44 and MapPanels 36. | grep count |

## 2 Findings analysis

| # | Claim | Classification |
|---|---|---|
| 1 | 04.8's mandated code necessarily reds 11 issues in 2 out-of-scope suites. | VALID (F1–F10). |
| 2 | "The 03.10–03.12 structural suites must stay green" (dispatch note). | INVALID for these two files, because it contradicts 04.8 AC6/AC7/AC9. VALID for `MapCanvasViewStructuralTests` (03.10) and for every AppShell/MapPanels test not listed in §4 (F13, F14). |
| 3 | The fix is to disable, quarantine or land red. | REJECTED. A red or disabled gate 3 cannot pass the protected-`main` PR, and `.disabled` drops the guard's intent. Neither is needed. |
| 4 | A separate test-only task (b). | REJECTED. If it lands before 04.8, it asserts shapes that do not exist yet (red). If it lands after, 04.8's own commit is red. Either way one commit is red, so the product change and the guard update must share one commit. |
| 5 | The 04.8 tester owns the edits (c). | REJECTED. The implementer must commit with a green full gate before the tester runs, so option (c) makes the implementer commit red. The implementer makes these edits as spec-mandated guard maintenance, with the exact code given. This does not pre-empt the tester: no new coverage is invented. |
| 6 | 04.9 will hit the same suites. | VALID (F11). The deltas are in §5. |
| 7 | 04.10 will hit these suites. | INVALID. 04.10 edits no `App/Sources` file and neither structural file. It **is** blocked by a different defect (F15), handled in §6. |

## 3 Ownership and landing

| File | 04.8 | 04.9 | 04.10 |
|---|---|---|---|
| `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift` | MODIFY (§4.1), same commit as the `AppShell.swift` change | MODIFY (§5.1), same commit | untouched |
| `Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift` | MODIFY (§4.2), same commit as the `MapActionsView.swift` change | MODIFY (§5.2), same commit | untouched |
| `AppSourcesBoundaryTests.swift`, `AppSourcesBoundaryNegativeControlTests.swift` | untouched | untouched | MODIFY (its own §2; rule (g) re-scoped per §6) |
| `MapCanvasViewStructuralTests.swift`, `AppSourcesBoundaryAuditTests.swift`, `DoorFacade*Tests.swift` | untouched, stay green | untouched, stay green | untouched |

Ownership rules for both tasks:

- The **implementer** of each task writes these test edits. They are part of the task's §2 and are fully specified below.
- The task's **tester** may add new guards to either file.
- Neither the implementer nor the tester may delete, `.disabled`, or weaken any assertion in §4/§5, or edit
  any test in these files that §4/§5 do not name.

Design choice, recorded as a §6 default in both specs: each re-scoped guard reads its expected shape from one
`private static let` list.

- 04.9's edit is then a one-entry list substitution plus the placeholder-branch swap, never a guard rewrite.
- Every negative control is written relative to that list (`expected.count + 1`), so it stays valid across
  04.8 and 04.9 without edits.
- Call-shape assertions are regex with `\s*` after `handOff(`, because swift-format wraps there (F12).
- Counts run over comment-stripped code, so a doc comment that names a retired call shape is not counted as a
  call.

## 4 Exact test changes for 04.8 (post-04.8 shape, derived from 04.8 §4.8/§4.9)

The code content below is normative; layout follows swift-format.

- Run `xcrun swift-format format -i` on the two files.
- Then run lint `--strict`, which must be clean.
- Test display-name string literals may exceed 110 columns, as the existing ones already do
  (`AppShellStructuralTests.swift:130`).

### 4.1 `AppShellStructuralTests.swift`

**A1 — replace lines 127–196 in full.** The span runs from `// MARK: - AC7: handOff switches over exactly three
HandOffDestination names, in two case clauses` through the closing brace of
`plantedFacadeCallInPlaceholderBranchIsCaught()`. It covers 4 tests (`handOffSwitchesOverExactlyThreeDestinationNames`,
`plantedFourthHandOffCaseIsCaught`, `diagnosisAndUnitExpeditionBranchCallsNoFurtherCoreFunction`,
`plantedFacadeCallInPlaceholderBranchIsCaught`). Replace it with this block of 4 tests plus 2 helpers:

```swift
    // MARK: - AC7 (03.12) as re-scoped by 04.8 AC7: one clause per HandOffDestination case; no branch calls Core

    /// The case-clause prefixes `AppShell.handOff`'s switch carries after task 04.8
    /// (`tasks/epic-04-task-08-app-expedition-screens.md` §4.9). Task 04.9 replaces `"case .diagnosis:"` with
    /// `"case .diagnosisStarted("` in this list.
    private static let expectedHandOffCaseClausePrefixes = [
        "case .included(", "case .doorBStarted(", "case .diagnosis:",
    ]

    private static let coreCallPattern = #"\b(MapFacade|DoorFacade|MapLaunch)\.\w+\("#

    /// One `case` clause of `block`: from the line starting with `prefix` up to (excluding) the next line
    /// starting with `case ` or `default:`, or the end of `block`.
    private static func caseBranch(startingWith prefix: String, in block: String) -> String? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard
            let start = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
            })
        else { return nil }
        var branch = [lines[start]]
        for line in lines[(start + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") { break }
            branch.append(line)
        }
        return branch.joined(separator: "\n")
    }

    @Test(
        "AC7 (03.12, re-scoped by 04.8 AC7): AppShell.handOff has exactly one case clause per HandOffDestination case"
    )
    func handOffSwitchHasOneClausePerDestination() throws {
        let source = try Self.readShell("AppShell.swift")
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: source) else {
            Issue.record("could not locate AppShell.handOff's switch body")
            return
        }
        let cases = Self.caseLines(in: body)
        let expected = Self.expectedHandOffCaseClausePrefixes
        #expect(cases.count == expected.count, "expected \(expected.count) case clauses, found: \(cases)")
        for prefix in expected {
            #expect(
                cases.filter { $0.hasPrefix(prefix) }.count == 1,
                "expected exactly one clause starting \(prefix): \(cases)")
        }
        #expect(!body.contains(".unitExpedition"), "03.11's retired .unitExpedition case must not reappear")
    }

    @Test("negative control: a planted extra case clause in the handOff switch is caught")
    func plantedExtraHandOffCaseIsCaught() {
        let fixture = """
            switch destination {
            case .included(let map):
                holder.replace(with: map)
            case .doorBStarted(let outcome):
                doorHolder.replace(with: snapshot(outcome))
            case .diagnosis:
                break
            case .somethingElse:
                break
            }
            """
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: fixture) else {
            Issue.record("fixture setup failed")
            return
        }
        let cases = Self.caseLines(in: body)
        #expect(
            cases.count == Self.expectedHandOffCaseClausePrefixes.count + 1,
            "planted extra case clause was not detected: \(cases)")
    }

    @Test(
        "I14 (04.8 AC7): no handOff branch calls a façade or launch function; .doorBStarted only replaces the door holder; the .diagnosis placeholder touches no holder"
    )
    func handOffBranchesCallNoFurtherCoreFunction() throws {
        let source = try Self.readShell("AppShell.swift")
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: source) else {
            Issue.record("could not locate AppShell.handOff's switch body")
            return
        }
        #expect(
            body.range(of: Self.coreCallPattern, options: .regularExpression) == nil,
            "a handOff branch calls a façade/launch function; the action's one call belongs to its button (I14)")
        guard let doorB = Self.caseBranch(startingWith: "case .doorBStarted(", in: body) else {
            Issue.record("could not isolate the .doorBStarted branch")
            return
        }
        #expect(doorB.components(separatedBy: "doorHolder.replace(").count - 1 == 1)
        guard let placeholder = Self.caseBranch(startingWith: "case .diagnosis:", in: body) else {
            Issue.record("could not isolate the .diagnosis placeholder branch")
            return
        }
        #expect(!placeholder.contains("replace("), "the .diagnosis placeholder must not touch either holder")
    }

    @Test("negative control: a planted DoorFacade call inside a handOff branch is caught")
    func plantedFacadeCallInHandOffBranchIsCaught() {
        let fixture = """
            switch destination {
            case .included(let map):
                holder.replace(with: map)
            case .doorBStarted(let outcome):
                _ = DoorFacade.backToMap(outcome.runState, today: today)
            case .diagnosis:
                break
            }
            """
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: fixture) else {
            Issue.record("fixture setup failed")
            return
        }
        #expect(
            body.range(of: Self.coreCallPattern, options: .regularExpression) != nil,
            "planted façade call was not detected")
        let doorB = Self.caseBranch(startingWith: "case .doorBStarted(", in: body)
        #expect(doorB?.contains("doorHolder.replace(") == false, "planted missing replace was not detected")
    }
```

**A2 — replace lines 333–355 in full.** The span runs from `// MARK: - AC3 / arbiter-03 § Q-A: CoreErrorText is the
only source of student text; one code named` through the closing brace of `plantedThirdCoreErrorTextCallSiteIsCaught()`
and covers 2 tests. Replace it with:

```swift
    // MARK: - AC3 / arbiter-03 § Q-A (re-scoped by 04.8 §4.9): CoreErrorText is the only source of student text

    /// Every `CoreErrorText.text(for:` call site in `App/Sources/Shell` after task 04.8 (§4.9): 03.12's two,
    /// plus 04.8's summary write-failure resolution and `DoorBRunScreen.startAnother`'s error text. Task 04.9
    /// appends `"CoreErrorText.text(for: coreError)"` (its `writeFailureBanner`) and nothing else.
    private static let expectedShellCoreErrorTextSites = [
        "CoreErrorText.text(for: refusal.studentCode)",
        "CoreErrorText.text(for: .platformStateUnreadable)",
        "flatMap(CoreErrorText.text(for:))",
        "CoreErrorText.text(for: error)",
    ]

    @Test(
        "AC3 (03.12, re-scoped by 04.8 §4.9): CoreErrorText.text(for:) is called at exactly the expected App/Sources/Shell sites, no more"
    )
    func coreErrorTextCalledOnlyAtExpectedShellSites() throws {
        let combined = Self.codeOnlyLines(in: try Self.combinedShellSource())
        let count = combined.components(separatedBy: "CoreErrorText.text(for:").count - 1
        let expected = Self.expectedShellCoreErrorTextSites
        #expect(count == expected.count, "expected \(expected.count) CoreErrorText.text(for: sites, found \(count)")
        for site in expected {
            #expect(combined.contains(site), "missing expected CoreErrorText call site: \(site)")
        }
    }

    @Test("negative control: one CoreErrorText.text(for:) call site beyond the expected set is caught by the count")
    func plantedExtraCoreErrorTextCallSiteIsCaught() {
        let fixture = (Self.expectedShellCoreErrorTextSites + ["CoreErrorText.text(for: .expNoFringe)"])
            .joined(separator: "\n")
        let count = fixture.components(separatedBy: "CoreErrorText.text(for:").count - 1
        #expect(
            count == Self.expectedShellCoreErrorTextSites.count + 1, "planted extra call site was not detected")
    }
```

No other line of this file changes. `@Test(` count stays 44.

### 4.2 `MapPanelsPickersHandOffStructuralTests.swift`

**B0 — add these helpers directly after `readAllReal()` (after line 50).**

```swift
    /// Strips `///`/`//` comment lines before a code-only scan, mirroring
    /// `AppShellStructuralTests.codeOnlyLines(in:)`: a doc comment naming a retired call shape is not a call.
    private static func codeOnlyLines(in source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func matchCount(of pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return -1 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
```

**B1 — replace lines 202–227.** This covers `handOffDestinationHasExactlyThreeCases` and
`plantedFourthCaseIsCaught`, from the `@Test("AC9: HandOffDestination has exactly three cases …")` line through the
closing brace of `plantedFourthCaseIsCaught()`. Replace it with:

```swift
    /// The exact `HandOffDestination` case texts after task 04.8 (§4.8). Task 04.9 replaces
    /// `"diagnosis(event: DiagnosisEvent)"` with `"diagnosisStarted(DoorAStartOutcome)"` in this list.
    private static let expectedHandOffCases = [
        "diagnosis(event: DiagnosisEvent)", "doorBStarted(DoorBStartOutcome)", "included(map: MapState)",
    ]

    @Test("AC9 (03.11, re-scoped by 04.8 AC6): HandOffDestination has exactly the three expected cases")
    func handOffDestinationHasExactlyThreeCases() throws {
        let source = try Self.readReal("MapActionsView.swift")
        let cases = Self.handOffDestinationCaseLines(in: source)
        let expected = Self.expectedHandOffCases
        #expect(cases.count == expected.count, "expected \(expected.count) cases, found \(cases.count): \(cases)")
        for text in expected {
            #expect(cases.contains("case \(text)"), "missing case \(text): \(cases)")
        }
        #expect(
            !Self.codeOnlyLines(in: source).contains("ComposeResult"),
            "03.11's retired ComposeResult payload must not reappear")
        #expect(
            source.contains("typealias HandOffHook = (HandOffDestination) -> Void"),
            "HandOffHook must be exactly this type alias")
    }

    @Test("AC9 negative control: a planted fourth case is caught by the extractor")
    func plantedFourthCaseIsCaught() {
        let fixture = """
            enum HandOffDestination {
                case diagnosis(event: DiagnosisEvent)
                case doorBStarted(DoorBStartOutcome)
                case included(map: MapState)
                case somethingElse
            }
            """
        let cases = Self.handOffDestinationCaseLines(in: fixture)
        #expect(cases.count == Self.expectedHandOffCases.count + 1, "planted fourth case was not detected: \(cases)")
    }
```

**B2 — replace lines 229–289.** The span runs from `// MARK: - AC2/AC3/AC4: exactly one façade call per action
button, in MapActionsView.swift` through the closing brace of `catchBlockCallingHandOffIsCaught()`. It covers
`mapActionsViewCallsFacadeExactlyOncePerButton`, `plantedSecondFacadeCallIsCaught`,
`unitExpeditionButtonCallsHandOffOnlyOnSuccess` and `catchBlockCallingHandOffIsCaught`. Keep `textBetween` at
lines 291–296 unchanged. Replace the span with:

```swift
    // MARK: - AC2/AC3/AC4 (03.11, re-scoped by 04.8 AC6): one façade call and one success handOff per button

    /// Every façade call in `MapActionsView.swift` after task 04.8 (§4.8), one per action button. Task 04.9
    /// replaces `"MapFacade.checkHere("` with `"DoorFacade.checkHere("` in this list.
    private static let expectedActionFacadeCalls = [
        "MapFacade.checkHere(", "MapFacade.include(", "DoorFacade.startUnitExpedition(",
        "DoorFacade.startExpedition(",
    ]

    /// Each success-path `handOff(` shape after task 04.8, as a regex (`\s*`: swift-format may wrap after
    /// `handOff(`), with its site count. Task 04.9 replaces the `.diagnosis(event: event)` key with
    /// `#"handOff\(\s*\.diagnosisStarted\(\s*DoorAStartOutcome\("#` (count 1).
    private static let expectedHandOffCallPatterns: [String: Int] = [
        #"handOff\(\s*\.diagnosis\(event: event\)\)"#: 1,
        #"handOff\(\s*\.included\(map: newMap\)\)"#: 1,
        #"handOff\(\s*\.doorBStarted\("#: 2,
    ]

    private static let facadeCallPattern = #"\b(MapFacade|DoorFacade)\.\w+\("#

    @Test(
        "AC2/AC3/AC4 (03.11, re-scoped by 04.8 AC6): MapActionsView.swift makes exactly one façade call and one success-path handOff per action button"
    )
    func mapActionsViewCallsExactlyOneFacadeEntryPerButton() throws {
        let code = Self.codeOnlyLines(in: try Self.readReal("MapActionsView.swift"))
        let calls = Self.expectedActionFacadeCalls
        let total = Self.matchCount(of: Self.facadeCallPattern, in: code)
        #expect(total == calls.count, "expected \(calls.count) façade call sites, found \(total)")
        for call in calls {
            #expect(code.components(separatedBy: call).count - 1 == 1, "expected exactly one \(call) call site")
        }
        #expect(
            !code.contains("MapFacade.unitExpedition("),
            "Unit expedition must call DoorFacade.startUnitExpedition, never MapFacade.unitExpedition (04.8 AC6)")
        let handOffTotal = code.components(separatedBy: "handOff(").count - 1
        let expectedTotal = Self.expectedHandOffCallPatterns.values.reduce(0, +)
        #expect(handOffTotal == expectedTotal, "expected \(expectedTotal) handOff( sites, found \(handOffTotal)")
        for (pattern, count) in Self.expectedHandOffCallPatterns {
            #expect(
                Self.matchCount(of: pattern, in: code) == count,
                "expected \(count) handOff site(s) matching /\(pattern)/")
        }
    }

    @Test("negative control: a planted second façade call in one button is caught by the count")
    func plantedSecondFacadeCallIsCaught() {
        let fixture = """
            private func start() {
                let (runState, screen, failure, _) = try DoorFacade.startExpedition(
                    mapState: mapState, today: today)
                _ = MapFacade.include(nodeId: nodeId, mapState: mapState)
                handOff(.doorBStarted(DoorBStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
            }
            """
        #expect(
            Self.matchCount(of: Self.facadeCallPattern, in: fixture) == 2, "planted extra façade call was not detected")
    }

    @Test("negative control: a wrapped third .doorBStarted handOff is counted, so the per-shape count catches it")
    func plantedWrappedExtraDoorBHandOffIsCaught() {
        let fixture = """
            handOff(.doorBStarted(DoorBStartOutcome(runState: a, screen: b, writeFailureCode: c)))
            handOff(
                .doorBStarted(DoorBStartOutcome(runState: a, screen: b, writeFailureCode: c)))
            handOff(.doorBStarted(DoorBStartOutcome(runState: a, screen: b, writeFailureCode: c)))
            """
        #expect(Self.matchCount(of: #"handOff\(\s*\.doorBStarted\("#, in: fixture) == 3)
    }

    @Test(
        "AC4 (03.11) + 04.8 AC6: every CoreError catch block in MapActionsView.swift sets errorText and calls handOff zero times"
    )
    func actionButtonsCallHandOffOnlyOnSuccess() throws {
        let source = try Self.readReal("MapActionsView.swift")
        var blocks: [String] = []
        var searchFrom = source.startIndex
        while let startRange = source.range(
            of: "catch let error as CoreError {", range: searchFrom..<source.endIndex),
            let endRange = source.range(of: "catch {", range: startRange.upperBound..<source.endIndex)
        {
            blocks.append(String(source[startRange.upperBound..<endRange.lowerBound]))
            searchFrom = endRange.upperBound
        }
        #expect(blocks.count == 2, "expected one CoreError catch block per throwing button, found \(blocks.count)")
        for block in blocks {
            #expect(!block.contains("handOff("), "a CoreError catch block must not call handOff")
            #expect(block.contains("CoreErrorText.text(for: error)"))
        }
    }

    @Test("negative control: a catch block that also calls handOff is caught")
    func catchBlockCallingHandOffIsCaught() {
        let fixture = """
            catch let error as CoreError {
                errorText = CoreErrorText.text(for: error)
                handOff(.doorBStarted(fakeOutcome))
            }
            catch {
            """
        let block = Self.textBetween(fixture, "catch let error as CoreError {", "catch {")
        #expect(block?.contains("handOff(") == true, "planted violation was not detected")
    }
```

**B3 — replace lines 485–510.** The span runs from `// MARK: - I14: exactly one @State property across all six
files; no @State holds a Core state type` through the closing brace of `plantedSecondStatePropertyIsCaught()` and
covers 2 tests. Keep `noStatePropertyHoldsCoreStateType` (line 512 onward) unchanged. Replace the span with:

```swift
    // MARK: - I14 (03.11, re-scoped by 04.8 AC6): exactly two @State properties, one errorText per throwing button

    @Test(
        "I14 (re-scoped by 04.8 AC6): exactly two @State properties exist across all six files, each `@State private var errorText: String?` in MapActionsView.swift, one per Unit/Start button"
    )
    func exactlyTwoStatePropertiesAcrossAllFiles() throws {
        let contents = try Self.readAllReal()
        var stateLines: [String] = []
        for (name, source) in contents {
            for line in source.split(separator: "\n") where line.contains("@State") {
                stateLines.append("\(name): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(stateLines.count == 2, "expected exactly two @State properties, found: \(stateLines)")
        for line in stateLines {
            #expect(
                line == "MapActionsView.swift: @State private var errorText: String?",
                "unexpected @State property: \(line)")
        }
        let actions = try Self.readReal("MapActionsView.swift")
        for button in ["UnitExpeditionActionButton", "StartExpeditionActionButton"] {
            let header = Self.textBetween(actions, "struct \(button): View {", "var body")
            #expect(
                header?.contains("@State private var errorText: String?") == true,
                "\(button) must own its own errorText @State")
        }
    }

    @Test("I14 negative control: a third planted @State property is caught by the count and the name check")
    func plantedThirdStatePropertyIsCaught() {
        let lines = [
            "@State private var errorText: String?", "@State private var errorText: String?",
            "@State private var cachedMapState: MapState?",
        ]
        #expect(lines.filter { $0.contains("@State") }.count == 3, "planted third @State was not detected")
        #expect(
            lines.contains { $0 != "@State private var errorText: String?" }, "planted foreign @State not detected")
    }
```

**B4 — in `errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe()`, replace lines 575–580**, from
`let source = try Self.readReal("MapActionsView.swift")` through the closing `)` of the count `#expect`. Leave the
registry cross-check above it and the test's display name unchanged. The new lines are:

```swift
        let code = Self.codeOnlyLines(in: try Self.readReal("MapActionsView.swift"))
        let coreErrorTextCallCount = code.components(separatedBy: "CoreErrorText.text(for:").count - 1
        #expect(
            coreErrorTextCallCount == 2,
            "expected exactly two CoreErrorText.text(for:) sites (Unit, Start buttons), found \(coreErrorTextCallCount)"
        )
        #expect(code.components(separatedBy: "CoreErrorText.text(for: error)").count - 1 == 2)
```

Then add this negative control directly after that test:

```swift
    @Test("negative control: a third CoreErrorText.text(for:) site in MapActionsView.swift is caught by the count")
    func plantedThirdMapActionsCoreErrorTextSiteIsCaught() {
        let fixture = """
            errorText = CoreErrorText.text(for: error)
            errorText = CoreErrorText.text(for: error)
            Text(CoreErrorText.text(for: .expTrailInvalid) ?? "")
            """
        #expect(fixture.components(separatedBy: "CoreErrorText.text(for:").count - 1 == 3)
    }
```

No other line of this file changes. `@Test(` count: 36 → 38. Two tests are added
(`plantedWrappedExtraDoorBHandOffIsCaught`, `plantedThirdMapActionsCoreErrorTextSiteIsCaught`), and none is
removed.

### 4.3 Intent kept, guard by guard

| Old guard | Intent | New guard | Negative control |
|---|---|---|---|
| `handOffSwitchesOverExactlyThreeDestinationNames` | Exhaustive switch, one clause per case | `handOffSwitchHasOneClausePerDestination` | `plantedExtraHandOffCaseIsCaught` |
| `diagnosisAndUnitExpeditionBranchCallsNoFurtherCoreFunction` | I14: handOff re-enters no façade, and the placeholder touches no holder | `handOffBranchesCallNoFurtherCoreFunction` (now all branches) | `plantedFacadeCallInHandOffBranchIsCaught` |
| `coreErrorTextCalledExactlyTwiceAcrossShell` | `CoreErrorText` is the only text source, at known sites | `coreErrorTextCalledOnlyAtExpectedShellSites` | `plantedExtraCoreErrorTextCallSiteIsCaught` |
| `handOffDestinationHasExactlyThreeCases` | Exactly three destinations | same name, list-driven | `plantedFourthCaseIsCaught` |
| `mapActionsViewCallsFacadeExactlyOncePerButton` | I14 one call per action, one success `handOff` per action | `mapActionsViewCallsExactlyOneFacadeEntryPerButton` | `plantedSecondFacadeCallIsCaught`, `plantedWrappedExtraDoorBHandOffIsCaught` |
| `unitExpeditionButtonCallsHandOffOnlyOnSuccess` (still green) | No `handOff` on a thrown `CoreError` | `actionButtonsCallHandOffOnlyOnSuccess` (now both buttons, per AC6) | `catchBlockCallingHandOffIsCaught` |
| `errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe` | Only the registered student text is shown | same test, count 2 | `plantedThirdMapActionsCoreErrorTextSiteIsCaught` |
| `exactlyOneStatePropertyAcrossAllFiles` | `@State` discipline: presentation-only error text | `exactlyTwoStatePropertiesAcrossAllFiles` | `plantedThirdStatePropertyIsCaught` |

## 5 Exact test deltas for 04.9 (applied on top of §4, in 04.9's own commit)

In every expected-shape list's doc comment named below, replace the sentence that begins `Task 04.9 replaces` or
`Task 04.9 appends` with `Updated by task 04.9.`

### 5.1 `AppShellStructuralTests.swift`

- **D1.** In `expectedHandOffCaseClausePrefixes`, change `"case .diagnosis:"` to `"case .diagnosisStarted("`, and update
  its doc comment as above.
- **D2.** In `handOffBranchesCallNoFurtherCoreFunction()`, replace the `.diagnosis` placeholder check with the
  code below. The old code runs from `guard let placeholder = Self.caseBranch(startingWith: "case .diagnosis:", in: body)`
  through its closing `#expect(!placeholder.contains("replace("), …)`. Also rename the test's display string to
  `"I14 (04.8 AC7, 04.9 AC5): no handOff branch calls a façade or launch function; each door branch only replaces the door holder with its origin tag"`.

  ```swift
          #expect(doorB.contains("isStandaloneDiagnosis: false"), ".doorBStarted opens an expedition run (04.9 AC5)")
          guard let doorA = Self.caseBranch(startingWith: "case .diagnosisStarted(", in: body) else {
              Issue.record("could not isolate the .diagnosisStarted branch")
              return
          }
          #expect(doorA.components(separatedBy: "doorHolder.replace(").count - 1 == 1)
          #expect(doorA.contains("isStandaloneDiagnosis: true"), ".diagnosisStarted opens a standalone event (04.9 AC5)")
  ```

- **D3.** In both negative-control fixtures (`plantedExtraHandOffCaseIsCaught`, `plantedFacadeCallInHandOffBranchIsCaught`),
  change each
  `case .diagnosis:` / `break` pair to `case .diagnosisStarted(let outcome):` / `doorHolder.replace(with: snapshot(outcome))`.
  Both controls stay count- and pattern-relative, so their assertions do not change.
- **D4.** In `expectedShellCoreErrorTextSites`, append `"CoreErrorText.text(for: coreError)",` as the last entry, and
  update its doc comment as above.

### 5.2 `MapPanelsPickersHandOffStructuralTests.swift`

- **D5.** In `expectedHandOffCases`, change `"diagnosis(event: DiagnosisEvent)"` to `"diagnosisStarted(DoorAStartOutcome)"`, and
  update its doc comment as above. In the `plantedFourthCaseIsCaught` fixture, change
  `case diagnosis(event: DiagnosisEvent)` to `case diagnosisStarted(DoorAStartOutcome)`.
- **D6.** In `expectedActionFacadeCalls`, change `"MapFacade.checkHere("` to `"DoorFacade.checkHere("`, and update its doc
  comment as above. In `mapActionsViewCallsExactlyOneFacadeEntryPerButton()`, add this directly after the
  `MapFacade.unitExpedition(` `#expect`:
  `#expect(!code.contains("MapFacade.checkHere("), "Check me here must call DoorFacade.checkHere (04.9 AC4)")`.
- **D7.** In `expectedHandOffCallPatterns`, replace the key `#"handOff\(\s*\.diagnosis\(event: event\)\)"#` with
  `#"handOff\(\s*\.diagnosisStarted\(\s*DoorAStartOutcome\("#`, and update its doc comment as above. Its value stays
  `1`. 04.9 §4.5 wraps after `handOff(` and after `.diagnosisStarted(`, and `\s*` absorbs both.
- **D8.** No `@State` change: 04.9 adds none in MapUI, so the count stays 2. No `CoreErrorText` change in MapUI:
  `CheckHereActionButton` resolves no text, so the count stays 2.
- **D9.** Update the display strings of `handOffDestinationHasExactlyThreeCases` and
  `mapActionsViewCallsExactlyOneFacadeEntryPerButton` from `re-scoped by 04.8 AC6` to `re-scoped by 04.8 AC6 / 04.9 AC4`.

`@Test(` counts after 04.9: AppShell 44, MapPanels 38. No test is added or removed.

## 6 04.10: what it would break, and the edit it needs now

**Scan results.**

- 04.10 writes neither structural file.
- `MapCanvasViewStructuralTests` and `DoorFacadeConformanceTests` do not read 04.8/04.9's files (F14).
- `AppSourcesBoundaryAuditTests` is shape-tolerant (F13).
- AC5 and AC6 hold against the landed code (F16, F17).
- 04.10's AC7 `doorButtonActionViolations` finds exactly one `DoorFacade.` call per function in every
  §4-mandated body across 04.8 and 04.9. `CheckHereActionButton`'s call sits in a `var body` closure, not a
  `func`, so the helper does not see it. That is a coverage gap, not a failure: `mapActionsViewCallsExactlyOneFacadeEntryPerButton`
  already covers it file-wide.

**The one real blocker is F15.** Rule (g) over the whole tree reports 3 EPIC 03 lines, so 04.10 AC1 is red on
arrival. Fix: follow 03.9's own `networkRule` precedent (`AppSourcesBoundaryTests.swift:60-65`, "Isolated as its own
named rule … because AC2 runs it alone against" another tree). Isolate (g) as `doorCopyRule`, applied alone to
`App/Sources/Doors`, the "Door view files" of brief item 8.

Edits to `tasks/epic-04-task-10-app-sources-door-scan.md`:

- **T10-1 (AC1).** Old: ``AC1: `AppSourcesBoundary.doorRules` (new, in `DoorAppSourcesBoundaryTests.swift`) contains exactly three
  `Rule` values: (a) "answer / correct_choice_id comparison outside CAS", (b) "free-text entry (TextField/
  TextEditor) bound to an answer-named value", (g) "Door student-facing copy as an inline string literal (4+
  words)". `AppSourcesBoundary.violations(in: realAppSources, rules: AppSourcesBoundary.defaultRules +
  AppSourcesBoundary.doorRules)` returns `[]` over the real, landed `App/Sources` tree.``
  New: ``AC1: `AppSourcesBoundary.doorRules` (new, in `DoorAppSourcesBoundaryTests.swift`) contains exactly two `Rule`
  values: (a) "answer / correct_choice_id comparison outside CAS", (b) "free-text entry (TextField/TextEditor) bound
  to an answer-named value"; `AppSourcesBoundary.doorCopyRule` (new, same file) is rule (g) "Door student-facing
  copy as an inline string literal (4+ words)", isolated like 03.9's `networkRule` because it runs alone against
  `App/Sources/Doors`. `violations(in: realAppSources, rules: defaultRules + doorRules)` returns `[]` over the real
  `App/Sources` tree, and `violations(in: realAppSources/Doors, rules: [doorCopyRule])` returns `[]` over the real
  `App/Sources/Doors` tree (instrument: Swift Testing `#expect`, gate 3; excludes files outside `Doors`, whose
  EPIC 03 map chrome — `MapActionsView.swift:38`, `UnitListPickerView.swift:19`, `RegionPanelView.swift:16` —
  carries 4+-token literals that are not Door copy; empty `Doors` = FAIL via the helper's own empty-scan guard).``
- **T10-2 (AC2), first clause.** Old: `for each of the two new \`doorRules\` violation classes plus the Door-scoped
  \`TextEditor\` extension of (b),`. New: `for (a), for (g) (\`doorCopyRule\`, run with \`rules:
  [AppSourcesBoundary.doorCopyRule]\`) and for the Door-scoped \`TextEditor\` extension of (b),`.
- **T10-3 (§4.2 code).** Delete the third element (the `Rule(name: "Door student-facing copy …") { … }` entry) from
  `doorRules`. Add, inside the same `extension AppSourcesBoundary`, directly after `doorRules`:

  ```swift
      /// Rule (g), isolated as its own named rule (03.9's `networkRule` precedent) because it runs alone against
      /// `App/Sources/Doors`, the Door view files: EPIC 03's map chrome outside that directory legitimately
      /// carries 4+-token literals ("Include in my next expedition", "Past the last unit", "% cleared").
      static let doorCopyRule = Rule(name: "Door student-facing copy as an inline string literal (4+ words)") {
          line in
          doorCopyLiteralWordCount(in: line) >= 4
      }
  ```

  In `doorCopyLiteralWordCount`'s doc comment, replace `Every legitimate chrome label 04.8/04.9 ship ("Continue",
  "Submit", "Yes", "Not now", "Start expedition", "Unit expedition", "Check me here") is 1–3 words` with `Every
  chrome literal in App/Sources/Doors after 04.8/04.9 ("Continue", "Submit", "Yes", "Not now") is 1–3 words`.
- **T10-4 (§4.5 AC1 test).** In `appSourcesIsCleanWithDoorRules()`, append after its `#expect`:

  ```swift
      let copyViolations = try AppSourcesBoundary.violations(
          in: appSources.appendingPathComponent("Doors"), rules: [AppSourcesBoundary.doorCopyRule])
      #expect(copyViolations.isEmpty, "Door copy literal violations: \(copyViolations)")
  ```

- **T10-5 (§4.6 bullet for the 5-word literal).** Old: `` `Text("Hard-coded error message here")` (5 words) → "Door
  student-facing copy as an inline string literal (4+ words)"; `` New: `` `Text("Hard-coded error message here")` (5
  words), scanned with `rules: [AppSourcesBoundary.doorCopyRule]` → "Door student-facing copy as an inline string literal
  (4+ words)"; ``. The companion clean-fixture assertion is unchanged.
- **T10-6 (§6, threshold default).** Old: ``it stays at 4+: every real, landed chrome literal 04.8/04.9 ship — "Continue",
  "Submit", "Yes", "Not now", "Start expedition", "Unit expedition", "Check me here" — is 1–3 words (confirmed by
  direct read of both specs' code blocks this session, §3); a 2-word or 3-word threshold would false-positive
  against this already-correct, already-landed code.`` New: ``it stays at 4+, and rule (g) (`doorCopyRule`) runs over
  `App/Sources/Doors` only: every chrome literal there after 04.8/04.9 — "Continue", "Submit", "Yes", "Not now" — is
  1–2 words, while three EPIC 03 map-chrome literals outside `Doors` are 4+ tokens (`MapActionsView.swift:38`,
  `UnitListPickerView.swift:19`, `RegionPanelView.swift:16` — `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`
  F15) and are not Door copy; a tree-wide (g) would be red on arrival.``
- **T10-7 (§6, append).** `- IF AC9's "fails its own empty-match #expect" needs an instrument THEN wrap the call in Swift
  Testing's \`withKnownIssue { … }\` so the helper's recorded issue is the asserted outcome (a known issue that does
  not occur fails the test); never assert on the returned \`[]\`.`
- **T10-8 (§5 T1).** After ``(AC1) over the real, landed `App/Sources`;`` insert `` plus `doorCopyRule` over `App/Sources/Doors`;``.

04.10's "existing tests stay green" text needs no other change. It adds no `TIME-BOXED EXCEPTION` /
`contentViewSwiftMathExceptionFile` text to `AppSourcesBoundaryTests.swift`, so
`AppShellStructuralTests.carveOutConstantsNoLongerExistAsSourceText` (`:720-728`) stays green.

## 7 Spec edits for 04.8 and 04.9 (old → new), and the corrected dispatch note

Several "old" anchors below are wrapped across source lines in the spec files. Match them as text, not as single
lines.

### 7.1 `tasks/epic-04-task-08-app-expedition-screens.md`

- **S8-1 (§2 In-scope).** After the `App/Sources/Shell/AppShell.swift — MODIFY …` bullet (it ends ``next to the
  existing "Set marker" / "Change course" buttons.``), append:
  - ``- `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift` — MODIFY (03.12 tester's file, commit `fca1513`). Lockstep update, in this task's commit, of the 03.12 guards AC7/§4.9 invalidate — exactly §4.14.1; no other test in the file is edited.``
  - ``- `Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift` — MODIFY (03.11 tester's file, commit `c4aa9fe`). Lockstep update, in this task's commit, of the 03.11 guards AC6/§4.8 invalidate — exactly §4.14.2; no other test in the file is edited.``
- **S8-2 (§2 Out-of-scope, first bullet).** Old: ``- `Packages/Core/**`, `Packages/Rendering/**` — read-only;``
  New: ``- `Packages/Core/**` (except the two structural-suite test files listed in-scope above), `Packages/Rendering/**` — read-only;``
- **S8-3 (§4, new subsection after §4.13).** Insert `### 4.14 Lockstep EPIC 03 structural-guard updates`. Its first
  paragraph is:
  > AC6/AC7/AC9 change the exact shapes two EPIC 03 structural suites pin, so this task updates them in its own
  > commit, preserving each guard's intent and negative control
  > (`tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`). Expected shapes live in one `private static
  > let` list per guard so 04.9's later deltas are list substitutions.

  Then `#### 4.14.1 AppShellStructuralTests.swift` containing ruling §4.1 A1 and A2 verbatim (instruction plus code
  block), then `#### 4.14.2 MapPanelsPickersHandOffStructuralTests.swift` containing ruling §4.2 B0–B4 verbatim, then
  ruling §4.3's table verbatim.
- **S8-4 (AC10).** After ``stays green over the complete `App/Sources` tree,`` insert `` every `CoreTests` suite is green — including `AppShellStructuralTests.swift` and `MapPanelsPickersHandOffStructuralTests.swift` as updated by §4.14, with every test in them that §4.14 does not name unmodified —``.
- **S8-5 (§5 T3).** Old: ``shows exactly three call sites (`StartExpeditionActionButton.start`, `UnitExpeditionActionButton.start`, `DoorBRunScreen.startAnother`, plus the one `writeFailureText` resolution in `DoorBRunScreen.content(for:)`)``
  New: ``shows exactly four call sites (`StartExpeditionActionButton.start`, `UnitExpeditionActionButton.start`, `DoorBRunScreen.startAnother`, and the `writeFailureText` resolution in `DoorBRunScreen.content(for:)`) — the same four the re-scoped guards of §4.14 pin (two in `MapActionsView.swift`, two added to `AppShell.swift`)``
- **S8-6 (§5 T5, append a bullet).**
  > - EPIC 03 structural guards, re-scoped (§4.14):
  >   - Assertions:
  >     - `handOffSwitchHasOneClausePerDestination`
  >     - `handOffBranchesCallNoFurtherCoreFunction`
  >     - `coreErrorTextCalledOnlyAtExpectedShellSites`
  >     - `handOffDestinationHasExactlyThreeCases`
  >     - `mapActionsViewCallsExactlyOneFacadeEntryPerButton`
  >     - `actionButtonsCallHandOffOnlyOnSuccess`
  >     - `errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe`
  >     - `exactlyTwoStatePropertiesAcrossAllFiles`
  >
  >     Each asserts the post-04.8 shape of §4.8/§4.9.
  >   - Instrument: Swift Testing `#expect` over comment-stripped source text, run by gate 3 on the simulator. It
  >     excludes runtime, tap and presentation behaviour (C3).
  >   - Empty handling: an extractor that returns no case/branch records an `Issue` (empty = FAIL).
  >   - Negative controls:
  >     - `plantedExtraHandOffCaseIsCaught`
  >     - `plantedFacadeCallInHandOffBranchIsCaught`
  >     - `plantedExtraCoreErrorTextCallSiteIsCaught`
  >     - `plantedFourthCaseIsCaught`
  >     - `plantedSecondFacadeCallIsCaught`
  >     - `plantedWrappedExtraDoorBHandOffIsCaught`
  >     - `catchBlockCallingHandOffIsCaught`
  >     - `plantedThirdMapActionsCoreErrorTextSiteIsCaught`
  >     - `plantedThirdStatePropertyIsCaught`
  >   - Test counts: `rg -c "@Test\("` gives 44 (AppShell) and 38 (MapPanels), up from 44/36. No guard is deleted.
- **S8-7 (§5 T6).** Old: ``shows exactly the two expected instances (`DoorBViewState` in `DoorBRunScreen`, `errorText` in each of the two action buttons in `MapActionsView.swift`)``
  New: ``shows exactly one instance (`@State private var viewState = DoorBViewState()` in `DoorBRunScreen`), and `MapActionsView.swift` holds exactly two (`errorText` in each of the two action buttons, pinned by §4.14's `exactlyTwoStatePropertiesAcrossAllFiles`)``
- **S8-8 (§6, append).**
  > - IF an EPIC 03 structural guard pins a shape this task's ACs change THEN this task updates it in its own
  >   commit exactly per §4.14. It never deletes, `.disabled`s or leaves the guard red, and never edits a guard
  >   §4.14 does not name. The tester may add guards but may not weaken §4.14's.
  >   (`tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`)
- **S8-9 (§7).** After the bullet ending ``(§6 default 4, §5 T5's diff guard).``, add:
  > - the full `Core` test suite (gate 3) is green. This includes `AppShellStructuralTests.swift` and
  >   `MapPanelsPickersHandOffStructuralTests.swift` as updated by §4.14. `MapCanvasViewStructuralTests`,
  >   `AppSourcesBoundary*Tests`, `DoorFacade*Tests` and every other `CoreTests` file pass unmodified.

### 7.2 `tasks/epic-04-task-09-app-diagnosis-screens.md`

- **S9-1 (Branch note, first bullet).** After ``carry 04.8's own edits on top of 03.11's / 03.12's originals`` insert
  ``, and `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift` / `MapPanelsPickersHandOffStructuralTests.swift` carry 04.8's §4.14 re-scoped guards``.
- **S9-2 (§2 In-scope).** After the `App/Sources/Shell/AppShell.swift — MODIFY …` bullet (it ends
  ``returnFromDiagnosis(outcome:current:)` functions.``), append:
  - ``- `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift` — MODIFY (carrying 04.8's §4.14 edits). Lockstep list/branch deltas for AC5's `.diagnosisStarted` routing and the `writeFailureBanner` `CoreErrorText` site — exactly §4.11.1.``
  - ``- `Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift` — MODIFY (carrying 04.8's §4.14 edits). Lockstep list deltas for AC4's `.diagnosisStarted` case and `DoorFacade.checkHere` call — exactly §4.11.2.``
- **S9-3 (§2 Out-of-scope, first bullet).** Old: ``- `Packages/Core/**`, `Packages/Rendering/**` — read-only;`` New:
  ``- `Packages/Core/**` (except the two structural-suite test files listed in-scope above), `Packages/Rendering/**` — read-only;``
- **S9-4 (§4, new subsection after §4.10).** Insert `### 4.11 Lockstep EPIC 03 structural-guard updates`, containing
  ruling §5's doc-comment sentence plus §5.1 D1–D4 verbatim as `#### 4.11.1`, and ruling §5.2 D5–D9 verbatim as
  `#### 4.11.2`.
- **S9-5 (AC9).** After ``stays green over the complete `App/Sources` tree,`` insert `` every `CoreTests` suite is green — including the two EPIC 03 structural suites as updated by §4.11 —``.
- **S9-6 (§5 T5, append).**
  > - EPIC 03 structural guards, re-scoped (§4.11):
  >   - Assertions: the same eight guards as 04.8 §5 T5, now asserting `.diagnosisStarted` /
  >     `DoorFacade.checkHere` / `isStandaloneDiagnosis: true|false` per branch and 5 Shell `CoreErrorText` sites.
  >   - Instrument and exclusions: as 04.8 §5 T5.
  >   - Negative controls: the list-relative ones inherited from 04.8.
  >   - Test counts stay 44/38.
- **S9-7 (§6, append).** Append the S8-8 default, with `§4.14` replaced by `§4.11`.
- **S9-8 (§7).** After the bullet ending ``(§6 default 3).``, add the S8-9 bullet, with `§4.14` replaced by `§4.11`.

### 7.3 Corrected dispatch note (orchestrator, pre-dispatch check #6)

Old: "The existing 03.9 `AppSourcesBoundary` scan and the 03.10–03.12 structural suites must stay green"

New: "Gate 3 must be green at commit. The 03.9 `AppSourcesBoundary` scan and `MapCanvasViewStructuralTests` (03.10) stay
green unmodified. `AppShellStructuralTests.swift` (03.12) and `MapPanelsPickersHandOffStructuralTests.swift` (03.11)
are updated in this task's commit exactly per the spec's lockstep-guard subsection (04.8 §4.14 / 04.9 §4.11). No
other test in those files may be edited."

## 8 Post-edit verification

**Spec level (orchestrator, after applying §6–§7):**

1. `rg -n "AppShellStructuralTests.swift|MapPanelsPickersHandOffStructuralTests.swift" tasks/epic-04-task-08-app-expedition-screens.md tasks/epic-04-task-09-app-diagnosis-screens.md`
   - Pass: it shows ≥ 2 lines in each spec (the §2 bullets). Empty for either spec = FAIL.
   - Live before the edits: 04.8 returns 0 lines.
2. `rg -n "exactly three call sites|two expected instances" tasks/epic-04-task-08-app-expedition-screens.md`
   - Pass: 0 lines (empty = PASS).
   - Live before the edits: 2 lines, at `:986` and `:1036`.
3. `rg -n "#### 4.14.1|#### 4.14.2" tasks/epic-04-task-08-*.md` and `rg -n "#### 4.11.1|#### 4.11.2" tasks/epic-04-task-09-*.md`
   - Pass: 2 lines each.
4. `rg -n "doorCopyRule" tasks/epic-04-task-10-app-sources-door-scan.md` returns ≥ 5 lines (AC1, AC2, §4.2, §4.5,
   §4.6, §6). Separately, `rg -n "contains exactly three" tasks/epic-04-task-10-*.md` returns 0 lines (live before
   the edits: 1, AC1).

**Code level (after the 04.8 commit):**

5. `rg -n "case \.diagnosis, \.unitExpedition:|unitExpedition\(result: ComposeResult\)|MapFacade\.unitExpedition\(|handOff\(\.unitExpedition" Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift App/Sources`
   - Pass: exactly 1 line, B2's `!code.contains("MapFacade.unitExpedition(")` expectation.
   - Live before the edits: 13 lines.
     - `AppShellStructuralTests.swift:141,170,189,194`
     - `MapPanelsPickersHandOffStructuralTests.swift:208,220,240,249,283`
     - `AppShell.swift:86`
     - `MapActionsView.swift:9,68,70`
6. `rg -c "@Test\(" Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift` returns `44` and `38`.
7. `git diff --name-only <pre-04.8>..HEAD -- Packages/Core` lists exactly the two structural files. No other `CoreTests` file changes.
8. `scripts/gate.sh` passes all four gates.
   - Instrument: the gates. Gate 3 is `Core` tests on the simulator, which excludes physical-device behaviour (D29).

**Code level (after the 04.9 commit):**

9. `rg -n "\"case \.diagnosis:\"|diagnosis\(event: DiagnosisEvent\)|\"MapFacade\.checkHere\(\"" Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift`
   - Pass: exactly 1 line, D6's `!code.contains("MapFacade.checkHere(")` expectation.
   - Doc comments no longer name the retired shapes (§5 lead-in).
10. `rg -n "CoreErrorText.text\(for: coreError\)" Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift`
    - Pass: 1 line.
11. Checks 6 and 8 again: counts 44/38, and all four gates green.

**Code level (after the 04.10 commit):**

12. `scripts/gate.sh` passes all four gates, with `appSourcesIsCleanWithDoorRules` covering both the tree-wide rules
    and `doorCopyRule` over `Doors`.

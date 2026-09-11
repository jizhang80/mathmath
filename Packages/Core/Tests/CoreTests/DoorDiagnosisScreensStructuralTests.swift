import Foundation
import Testing

@testable import Core

/// Tester-authored structural (source-text) suite for task 04.9
/// (`tasks/epic-04-task-09-app-diagnosis-screens.md`): AC1-AC3's per-case content routing on
/// `HypothesisCardView`/`RemediationView`/`DiagnosisReturnView`, AC5/AC7/AC8's standalone-vs-resumed traps,
/// I2's hint-fallback-never-shown guard, and the I3/I10/I14/Glossary cases this task's own implementer suite
/// (`DoorExpeditionScreensStructuralTests.swift`, the 04.8 tester's file carried in lockstep by this task's
/// commit per `tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md`) does not already assert.
/// This is a NEW file — per `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md` /
/// `arbiter-04-09-doors-structural-suite-addendum.md`, the three lockstep-owned suites
/// (`AppShellStructuralTests.swift`, `MapPanelsPickersHandOffStructuralTests.swift`,
/// `DoorExpeditionScreensStructuralTests.swift`) are the implementer's own commit and are not edited here.
///
/// **C3 exclusion (verbatim, `tasks/arbitration/arbiter-04-predispatch.md` § Q-C "What it cannot claim").**
/// This suite's evidence is logic, composition and static wiring only. It does NOT and cannot claim:
/// 1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation,
///    and keypad key -> string binding at runtime;
/// 2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline
///    are on screen);
/// 3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and
///    relaunch;
/// 4. that the sequence of screens a student sees matches the facade's screen values at runtime, rather than
///    only in `CoreTests`.
/// The literal tap-through is the owner's device verification (D29).
@Suite("App/Sources/Doors 04.9 tester structural guards (AC1-AC3, AC5, AC7, AC8, I2/I3/I10/I14, glossary)")
struct DoorDiagnosisScreensStructuralTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var doorsRoot: URL { repoRoot.appendingPathComponent("App/Sources/Doors") }
    private static var mapUIRoot: URL { repoRoot.appendingPathComponent("App/Sources/MapUI") }
    private static var shellRoot: URL { repoRoot.appendingPathComponent("App/Sources/Shell") }
    private static var appSourcesRoot: URL { repoRoot.appendingPathComponent("App/Sources") }

    private static func readDoor(_ name: String) throws -> String {
        try String(contentsOf: doorsRoot.appendingPathComponent(name), encoding: .utf8)
    }

    private static func readMapActions() throws -> String {
        try String(contentsOf: mapUIRoot.appendingPathComponent("MapActionsView.swift"), encoding: .utf8)
    }

    private static func readShell() throws -> String {
        try String(contentsOf: shellRoot.appendingPathComponent("AppShell.swift"), encoding: .utf8)
    }

    /// Every `.swift` file under `path`, read exhaustively against the directory listing (mandatory tester
    /// guidance for this EPIC: "make every 'anywhere in directory X' scan exhaustive against the directory
    /// listing, not a hard-coded file list" — `tasks/arbitration/arbiter-04-09-doors-structural-suite-addendum.md`
    /// §6). A later Doors file is picked up automatically; no list here needs a lockstep edit.
    private static func allSwiftFiles(under url: URL) throws -> [(name: String, source: String)] {
        let names = try FileManager.default.contentsOfDirectory(atPath: url.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        return try names.map { name in
            (name, try String(contentsOf: url.appendingPathComponent(name), encoding: .utf8))
        }
    }

    private static func combinedDoorsSource() throws -> String {
        try allSwiftFiles(under: doorsRoot).map(\.source).joined(separator: "\n")
    }

    /// Every `.swift` file anywhere under `App/Sources`, walked recursively and exhaustively — used only by
    /// the whole-App-tree I2/I14 scans below, so a later App file that adds a forbidden reference is caught
    /// with no list maintenance.
    private static func allAppSourcesSwiftFiles() throws -> [(name: String, source: String)] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: appSourcesRoot, includingPropertiesForKeys: nil)
        else {
            Issue.record("could not enumerate App/Sources")
            return []
        }
        var files: [(name: String, source: String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            files.append((url.lastPathComponent, try String(contentsOf: url, encoding: .utf8)))
        }
        #expect(!files.isEmpty, "App/Sources holds no .swift file (empty = FAIL)")
        return files
    }

    /// Finds the block between the `{` that follows `marker` and its own matching `}` — a brace-depth walk,
    /// mirroring `AppShellStructuralTests.balancedBraceBlock(after:in:)` /
    /// `DoorExpeditionScreensStructuralTests.balancedBraceBlock(after:in:)`.
    private static func balancedBraceBlock(after marker: String, in source: String) -> String? {
        guard let markerRange = source.range(of: marker) else { return nil }
        var depth = 1
        var index = markerRange.upperBound
        let start = index
        while index < source.endIndex {
            let char = source[index]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func matchCount(of pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return -1 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// One `case` clause of `block`, mirroring the 04.8 lockstep suite's `caseBranch(startingWith:in:)`.
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

    private static func codeOnlyLines(in source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - AC1: HypothesisCardView — exactly two chrome buttons, content from 04.3, no other control

    /// The hypothesis card's two decline-able chrome buttons and the `onDecision` call each makes, exactly
    /// once, per AC1. A later button added to this file must extend this list.
    private static let expectedHypothesisButtons: [(label: String, call: String)] = [
        ("Yes", "onDecision(true)"), ("Not now", "onDecision(false)"),
    ]

    @Test("AC1: HypothesisCardView renders content.line and content.costLine, and exactly two buttons")
    func hypothesisCardRendersLineCostLineAndTwoButtons() throws {
        let source = try Self.readDoor("HypothesisCardView.swift")
        #expect(source.contains("Text(content.line)"))
        #expect(source.contains("Text(content.costLine)"))
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: source) == Self.expectedHypothesisButtons.count,
            "expected exactly \(Self.expectedHypothesisButtons.count) buttons, found \(Self.matchCount(of: #"\bButton\("#, in: source))"
        )
        for (label, call) in Self.expectedHypothesisButtons {
            #expect(
                source.contains(#"Button("\#(label)") { \#(call) }"#),
                "expected a Button(\"\(label)\") calling \(call) exactly once")
        }
    }

    @Test("negative control: a planted third HypothesisCardView button is caught by the count")
    func plantedThirdHypothesisButtonIsCaught() {
        let fixture = """
            Button("Yes") { onDecision(true) }
            Button("Not now") { onDecision(false) }
            Button("Tell me more") { onMore() }
            """
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: fixture) == Self.expectedHypothesisButtons.count + 1,
            "planted extra button was not detected")
    }

    // MARK: - AC6/AC7: probe items render through 04.8's existing ExpeditionItemView, not a dedicated view

    @Test(
        "AC6: DoorADiagnosisScreen.probeItem renders through ExpeditionItemView, never a dedicated ProbeView"
    )
    func probeItemsRenderThroughExistingExpeditionItemView() throws {
        let shell = try Self.readShell()
        guard
            let body = Self.balancedBraceBlock(
                after:
                    "private func diagnosisContent(for screen: DoorADiagnosisScreen, current: DoorBRunSnapshot) -> some View {",
                in: shell)
        else {
            Issue.record("could not locate diagnosisContent's body")
            return
        }
        guard let arm = Self.caseBranch(startingWith: "case .probeItem(let content, let probe):", in: body)
        else {
            Issue.record("could not locate the .probeItem arm")
            return
        }
        #expect(arm.contains("ExpeditionItemView("), "the probe item must render via ExpeditionItemView")
        #expect(!arm.contains("ProbeView("), "no dedicated ProbeView may be introduced (§6 default 4)")
        #expect(
            !FileManager.default.fileExists(
                atPath: Self.doorsRoot.appendingPathComponent("ProbeView.swift").path),
            "App/Sources/Doors/ProbeView.swift must not exist")
    }

    // MARK: - AC2: RemediationView — explanation -> worked example (ordered MathView per step) -> paraphrase+hint

    @Test("AC2: RemediationView.explanation renders content as plain Text, no MathView")
    func remediationExplanationRendersPlainText() throws {
        let source = try Self.readDoor("RemediationView.swift")
        guard let arm = Self.caseBranch(startingWith: "case .explanation(let text):", in: source) else {
            Issue.record("could not locate the .explanation arm")
            return
        }
        let bodyLines = arm.split(separator: "\n", omittingEmptySubsequences: false).dropFirst()
        #expect(
            bodyLines.map({ $0.trimmingCharacters(in: .whitespaces) }).joined() == "Text(text)",
            "the .explanation arm must render exactly Text(text), nothing else")
    }

    @Test(
        "AC2: RemediationView.workedExample renders one MathView(latex:) per example.stepsLatex entry, in order"
    )
    func remediationWorkedExampleRendersOneMathViewPerStepInOrder() throws {
        let source = try Self.readDoor("RemediationView.swift")
        guard let arm = Self.caseBranch(startingWith: "case .workedExample(let example):", in: source) else {
            Issue.record("could not locate the .workedExample arm")
            return
        }
        #expect(
            arm.contains("ForEach(example.stepsLatex, id: \\.self) { step in"),
            "the worked example's steps must be bound from example.stepsLatex, preserving source order")
        guard let loopBody = Self.balancedBraceBlock(after: "{ step in", in: arm) else {
            Issue.record("could not locate the ForEach loop body")
            return
        }
        #expect(
            loopBody.trimmingCharacters(in: .whitespacesAndNewlines) == "MathView(latex: step)",
            "each step must render exactly one MathView(latex: step) call, nothing else")
    }

    @Test("negative control: a worked-example arm that renders steps out of the ForEach's declared order")
    func plantedReversedWorkedExampleOrderIsCaught() {
        let fixture = """
            case .workedExample(let example):
                ForEach(example.stepsLatex.reversed(), id: \\.self) { step in
                    MathView(latex: step)
                }
            """
        #expect(
            fixture.contains("example.stepsLatex.reversed()"),
            "a planted .reversed() call would defeat source order — this control shows the grep detects it")
        #expect(
            !fixture.contains("ForEach(example.stepsLatex, id: \\.self) { step in"),
            "the exact expected binding text must not match a reversed source")
    }

    @Test(
        "AC2: RemediationView.paraphrase renders Text(text) always, then Text(hint) only when hint != nil"
    )
    func remediationParaphraseRendersTextThenOptionalHint() throws {
        let source = try Self.readDoor("RemediationView.swift")
        guard let arm = Self.caseBranch(startingWith: "case .paraphrase(let text, let hint):", in: source)
        else {
            Issue.record("could not locate the .paraphrase arm")
            return
        }
        #expect(arm.contains("Text(text)"))
        #expect(arm.contains("if let hint {"))
        guard let hintBody = Self.balancedBraceBlock(after: "if let hint {", in: arm) else {
            Issue.record("could not locate the if-let-hint body")
            return
        }
        #expect(hintBody.trimmingCharacters(in: .whitespacesAndNewlines) == "Text(hint)")
    }

    @Test("AC2: no RemediationView case renders internalCode, a fraction or a percentage literal")
    func remediationRendersNoInternalCodeFractionOrPercentage() throws {
        let source = try Self.readDoor("RemediationView.swift")
        let code = Self.codeOnlyLines(in: source)
        #expect(!code.contains("internalCode"), "RemediationView must never render internalCode (I6)")
        #expect(!code.contains("%"), "RemediationView must never render a percentage")
        #expect(!code.lowercased().contains("fraction"), "RemediationView must never render a fraction")
    }

    @Test("negative control: a planted internalCode render in RemediationView is caught")
    func plantedInternalCodeRenderInRemediationIsCaught() {
        let fixture = #"Text("\(hint.internalCode)")"#
        #expect(
            Self.codeOnlyLines(in: fixture).contains("internalCode"),
            "planted internalCode render was not detected")
    }

    // MARK: - AC3: DiagnosisReturnView — further-level offer (two buttons, one call each) and terminal screen

    private static let expectedFurtherLevelButtons: [(label: String, call: String)] = [
        ("Yes", "onFurtherLevelDecision(true)"), ("Not now", "onFurtherLevelDecision(false)"),
    ]

    @Test(
        "AC3: the further-level offer renders RemediationView then offer.question, then exactly two buttons calling onFurtherLevelDecision(true/false) once each"
    )
    func furtherLevelOfferRendersRemediationQuestionAndTwoButtons() throws {
        let source = try Self.readDoor("DiagnosisReturnView.swift")
        guard
            let arm = Self.caseBranch(
                startingWith: "case .furtherLevelOffer(let remediation, let offer):", in: source)
        else {
            Issue.record("could not locate the .furtherLevelOffer arm")
            return
        }
        #expect(arm.contains("RemediationView(content: remediation)"))
        #expect(arm.contains("Text(offer.question)"))
        guard
            let remediationRange = arm.range(of: "RemediationView(content: remediation)"),
            let questionRange = arm.range(of: "Text(offer.question)")
        else {
            Issue.record("could not order-check RemediationView vs. offer.question")
            return
        }
        #expect(
            remediationRange.lowerBound < questionRange.lowerBound,
            "the already-shown remediation piece must render before the further-level question")
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: arm) == Self.expectedFurtherLevelButtons.count,
            "expected exactly \(Self.expectedFurtherLevelButtons.count) buttons in the further-level offer")
        for (label, call) in Self.expectedFurtherLevelButtons {
            #expect(
                arm.contains(#"Button("\#(label)") { \#(call) }"#),
                "expected a Button(\"\(label)\") calling \(call) exactly once")
        }
    }

    @Test("negative control: a planted third button in the further-level offer arm is caught")
    func plantedThirdFurtherLevelButtonIsCaught() {
        let fixture = """
            case .furtherLevelOffer(let remediation, let offer):
                RemediationView(content: remediation)
                Text(offer.question)
                Button("Yes") { onFurtherLevelDecision(true) }
                Button("Not now") { onFurtherLevelDecision(false) }
                Button("Skip") { onFurtherLevelDecision(false) }
            """
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: fixture) == Self.expectedFurtherLevelButtons.count + 1,
            "planted extra button was not detected")
    }

    @Test(
        "AC3: the terminal screen renders line/hint.prose/remediation only when non-nil, never hint.internalCode, and exactly one Continue control calling onReturn() once"
    )
    func terminalScreenRendersOptionalPartsAndOneContinueControl() throws {
        let source = try Self.readDoor("DiagnosisReturnView.swift")
        guard let arm = Self.caseBranch(startingWith: "case .terminal(let terminal):", in: source) else {
            Issue.record("could not locate the .terminal arm")
            return
        }
        #expect(arm.contains("if let line = terminal.line {"))
        guard let lineBody = Self.balancedBraceBlock(after: "if let line = terminal.line {", in: arm) else {
            Issue.record("could not locate the line conditional body")
            return
        }
        #expect(lineBody.trimmingCharacters(in: .whitespacesAndNewlines) == "Text(line)")

        #expect(arm.contains("if let hint = terminal.hint {"))
        guard let hintBody = Self.balancedBraceBlock(after: "if let hint = terminal.hint {", in: arm) else {
            Issue.record("could not locate the hint conditional body")
            return
        }
        #expect(hintBody.trimmingCharacters(in: .whitespacesAndNewlines) == "Text(hint.prose)")
        #expect(!hintBody.contains("internalCode"), "the terminal must never render hint.internalCode")

        #expect(arm.contains("if let remediation = terminal.remediation {"))
        guard
            let remediationBody = Self.balancedBraceBlock(
                after: "if let remediation = terminal.remediation {", in: arm)
        else {
            Issue.record("could not locate the remediation conditional body")
            return
        }
        #expect(
            remediationBody.trimmingCharacters(in: .whitespacesAndNewlines)
                == "RemediationView(content: remediation)")

        #expect(
            Self.matchCount(of: #"\bButton\("#, in: arm) == 1,
            "expected exactly one control (\"Continue\") in the terminal branch")
        #expect(arm.contains(#"Button("Continue") { onReturn() }"#))
        #expect(
            Self.matchCount(of: #"onReturn\(\)"#, in: arm) == 1, "expected exactly one onReturn() call site")
        #expect(
            !arm.lowercased().contains("no hint written"),
            "no fallback placeholder string may replace an absent hint (§6 default 5)")
    }

    @Test("negative control: a planted second control in the terminal branch is caught by the count")
    func plantedSecondTerminalControlIsCaught() {
        let fixture = """
            case .terminal(let terminal):
                Button("Continue") { onReturn() }
                Button("Skip") { onReturn() }
            """
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: fixture) == 2, "planted extra control was not detected")
    }

    @Test("negative control: a planted terminal.hint.internalCode render is caught")
    func plantedTerminalHintInternalCodeRenderIsCaught() {
        let fixture = """
            if let hint = terminal.hint {
                Text(hint.internalCode.debugDescription)
            }
            """
        #expect(fixture.contains("internalCode"), "planted internalCode render was not detected")
    }

    @Test("AC3: no score, fraction or percentage literal anywhere in DiagnosisReturnView")
    func diagnosisReturnViewShowsNoScoreFractionOrPercentage() throws {
        let code = Self.codeOnlyLines(in: try Self.readDoor("DiagnosisReturnView.swift"))
        #expect(!code.contains("%"), "DiagnosisReturnView must never render a percentage")
        #expect(!code.lowercased().contains("fraction"), "DiagnosisReturnView must never render a fraction")
        #expect(!code.lowercased().contains("score"), "DiagnosisReturnView must never render a score")
    }

    // MARK: - I3: the diagnosisAnswerCard phase precedes the next probeItem; only continueDiagnosisTapped advances

    @Test(
        "I3: answerProbeItem's result phase is .diagnosisAnswerCard, never .screen(.diagnosis(...)) — the answer card precedes the next probe item"
    )
    func answerProbeItemAlwaysLandsOnTheAnswerCardPhase() throws {
        let shell = try Self.readShell()
        guard
            let body = Self.balancedBraceBlock(
                after:
                    "private func answerProbeItem(_ probe: ProbeInProgress, submitted: String, current: DoorBRunSnapshot) {",
                in: shell)
        else {
            Issue.record("could not locate answerProbeItem's body")
            return
        }
        #expect(
            body.contains("phase: .diagnosisAnswerCard(advance)"),
            "answerProbeItem must land on .diagnosisAnswerCard, not directly on the next probe/terminal screen"
        )
        #expect(
            !body.contains(".screen(.diagnosis("),
            "answerProbeItem must never construct a .screen(.diagnosis(...)) phase directly (I3)")
    }

    @Test(
        "I3: only continueDiagnosisTapped calls DoorFacade.continueAfterProbeAnswer; no other function in this task's scope does"
    )
    func onlyContinueDiagnosisTappedCallsContinueAfterProbeAnswer() throws {
        let shell = try Self.readShell()
        #expect(
            shell.components(separatedBy: "DoorFacade.continueAfterProbeAnswer(").count - 1 == 1,
            "expected exactly one continueAfterProbeAnswer call site, in continueDiagnosisTapped")
        guard
            let body = Self.balancedBraceBlock(
                after:
                    "private func continueDiagnosisTapped(_ advance: DoorAProbeAnswerAdvance, current: DoorBRunSnapshot) {",
                in: shell)
        else {
            Issue.record("could not locate continueDiagnosisTapped's body")
            return
        }
        #expect(body.contains("DoorFacade.continueAfterProbeAnswer(advance, runState: current.runState)"))
    }

    @Test("negative control: a planted direct .screen(.diagnosis(...)) construction inside answerProbeItem")
    func plantedDirectDiagnosisScreenConstructionInAnswerProbeItemIsCaught() {
        let fixture = """
            private func answerProbeItem(_ probe: ProbeInProgress, submitted: String, current: DoorBRunSnapshot) {
                let (advance, runState, failure) = DoorFacade.answerProbeItem(
                    probe, submitted: submitted, runState: current.runState, today: today)
                holder.replace(
                    with: DoorBRunSnapshot(
                        runState: runState, phase: .screen(.diagnosis(advance.screen)), writeFailureCode: failure,
                        isStandaloneDiagnosis: current.isStandaloneDiagnosis))
            }
            """
        #expect(
            fixture.contains(".screen(.diagnosis("),
            "planted I3-violating direct advance was not detected by the grep")
    }

    // MARK: - Trap: resumeAfterDiagnosis is reachable only when isStandaloneDiagnosis == false

    @Test(
        "AC8: DoorFacade.resumeAfterDiagnosis is called exactly once, inside returnFromDiagnosis's non-standalone (else) branch only"
    )
    func resumeAfterDiagnosisIsReachableOnlyInTheNonStandaloneBranch() throws {
        let shell = try Self.readShell()
        #expect(
            shell.components(separatedBy: "DoorFacade.resumeAfterDiagnosis(").count - 1 == 1,
            "expected exactly one resumeAfterDiagnosis call site")
        guard
            let returnBody = Self.balancedBraceBlock(
                after:
                    "private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {",
                in: shell)
        else {
            Issue.record("could not locate returnFromDiagnosis's body")
            return
        }
        guard
            let standaloneBody = Self.balancedBraceBlock(
                after: "if current.isStandaloneDiagnosis {", in: returnBody)
        else {
            Issue.record("could not locate the standalone (if) branch")
            return
        }
        #expect(
            !Self.codeOnlyLines(in: standaloneBody).contains("resumeAfterDiagnosis"),
            "the standalone map_check_here branch must never call resumeAfterDiagnosis")
        guard
            let elseRange = returnBody.range(of: "} else {"),
            let closeRange = returnBody.range(of: "}", range: elseRange.upperBound..<returnBody.endIndex)
        else {
            Issue.record("could not isolate the else branch")
            return
        }
        let elseBranch = String(returnBody[elseRange.upperBound..<closeRange.lowerBound])
        #expect(
            elseBranch.contains("DoorFacade.resumeAfterDiagnosis("),
            "the non-standalone (else) branch must call resumeAfterDiagnosis")
    }

    @Test(
        "negative control: a resumeAfterDiagnosis call planted inside the standalone (if) branch is caught"
    )
    func plantedResumeAfterDiagnosisInStandaloneArmIsCaught() {
        let fixture = """
            private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {
                if current.isStandaloneDiagnosis {
                    let (advance, runState, failure) = DoorFacade.resumeAfterDiagnosis(
                        current.runState, outcome: outcome, today: today)
                    mapHolder.replace(with: current.runState.map)
                    onDismiss()
                } else {
                    let (advance, runState, failure) = DoorFacade.resumeAfterDiagnosis(
                        current.runState, outcome: outcome, today: today)
                }
            }
            """
        let standaloneBody = Self.balancedBraceBlock(
            after: "if current.isStandaloneDiagnosis {",
            in: Self.balancedBraceBlock(
                after:
                    "private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {",
                in: fixture)!)
        #expect(
            standaloneBody?.contains("resumeAfterDiagnosis") == true,
            "planted resumeAfterDiagnosis call in the standalone branch was not detected")
    }

    @Test(".doorBStarted opens with isStandaloneDiagnosis: false; .diagnosisStarted opens with true")
    func handOffSetsIsStandaloneDiagnosisPerDestination() throws {
        let shell = try Self.readShell()
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: shell) else {
            Issue.record("could not locate AppShell.handOff's switch body")
            return
        }
        guard let doorB = Self.caseBranch(startingWith: "case .doorBStarted(", in: body) else {
            Issue.record("could not locate the .doorBStarted arm")
            return
        }
        #expect(doorB.contains("isStandaloneDiagnosis: false"))
        guard let doorA = Self.caseBranch(startingWith: "case .diagnosisStarted(", in: body) else {
            Issue.record("could not locate the .diagnosisStarted arm")
            return
        }
        #expect(doorA.contains("isStandaloneDiagnosis: true"))
    }

    // MARK: - I2: no LO_HINT_NOT_FOUND / loHintNotFound / CoreErrorText for it anywhere in App/Sources

    @Test(
        "I2: hint and remediation prose come only from DoorA*Content; App/Sources never names LO_HINT_NOT_FOUND, loHintNotFound, or resolves CoreErrorText for it"
    )
    func hintFallbackCodeNeverAppearsInAppSources() throws {
        for (name, source) in try Self.allAppSourcesSwiftFiles() {
            let code = Self.codeOnlyLines(in: source)
            #expect(!code.contains("LO_HINT_NOT_FOUND"), "\(name) names the internal code LO_HINT_NOT_FOUND")
            #expect(!code.contains("loHintNotFound"), "\(name) names the internal case loHintNotFound")
            #expect(
                !code.contains("CoreErrorText.text(for: .loHintNotFound)"),
                "\(name) resolves CoreErrorText for the internal hint-fallback code")
            #expect(
                !code.lowercased().contains("no hint written"),
                "\(name) invents a placeholder hint-not-found string (superseded by Rule 3)")
        }
    }

    @Test("negative control: a planted CoreErrorText.text(for: .loHintNotFound) call is caught")
    func plantedLoHintNotFoundResolutionIsCaught() {
        let fixture = "let text = CoreErrorText.text(for: .loHintNotFound)"
        #expect(
            Self.codeOnlyLines(in: fixture).contains("CoreErrorText.text(for: .loHintNotFound)"),
            "planted internal-code resolution was not detected")
    }

    // MARK: - I14: no Core transition types in App code; DoorAStartOutcome is not Equatable

    @Test("I14: DoorAStartOutcome is not Equatable (arbiter-04-doorrunstate-equatable)")
    func doorAStartOutcomeIsNotEquatable() throws {
        let mapActions = try Self.readMapActions()
        #expect(mapActions.contains("struct DoorAStartOutcome {"))
        #expect(!mapActions.contains("struct DoorAStartOutcome: Equatable {"))
    }

    @Test("negative control: a planted Equatable DoorAStartOutcome declaration is caught")
    func plantedEquatableDoorAStartOutcomeIsCaught() {
        let fixture = "struct DoorAStartOutcome: Equatable {\n    let runState: DoorRunState\n}"
        #expect(
            fixture.contains("struct DoorAStartOutcome: Equatable {"),
            "planted Equatable conformance over a DoorRunState-holding struct was not detected")
    }

    @Test("I14: no App/Sources file calls a Core transition type directly, and no file hand-rolls ==")
    func noForbiddenCoreTransitionTypeOrHandRolledEqualityAnywhereInAppSources() throws {
        let forbidden = [
            "ExpeditionRun(", "ExpeditionRun.", "DiagnosisRun(", "DiagnosisRun.", "ItemChecker(",
            "ItemChecker.", "DoorBExpeditionFlow.", "DoorADiagnosisFlow.", "Expedition.compose",
            "MasteryTransitions.", "MarkerTrail.", "L0Checker.", "BundleIO.", "BundleLoader.",
            "StudentStateStore.", "LayoutEngine.", "StudentState(",
        ]
        for (name, source) in try Self.allAppSourcesSwiftFiles() {
            let code = Self.codeOnlyLines(in: source)
            for symbol in forbidden {
                #expect(!code.contains(symbol), "\(name) references the forbidden Core symbol \(symbol)")
            }
            #expect(!code.contains("static func =="), "\(name) hand-rolls an == operator over Core state")
            for type in ["DoorRunState", "MapState", "ContentBundle"] {
                #expect(
                    !code.contains("extension \(type)"),
                    "\(name) retroactively conforms \(type) to Equatable")
            }
        }
    }

    @Test("negative control: a planted DiagnosisRun.classify( reference is caught by the App-wide scan")
    func plantedForbiddenCoreTypeReferenceIsCaught() {
        let fixture = "let token = DiagnosisRun.classify(misses)"
        #expect(fixture.contains("DiagnosisRun."), "planted forbidden Core-type reference was not detected")
    }

    // MARK: - I10: no TextField/TextEditor anywhere in App/Sources/Doors (exhaustive against the directory)

    @Test("I10: no TextField/TextEditor in any .swift file under App/Sources/Doors, scanned exhaustively")
    func noFreeTextEntryAnywhereInDoorsDirectory() throws {
        for (name, source) in try Self.allSwiftFiles(under: Self.doorsRoot) {
            #expect(!source.contains("TextField"), "\(name) contains a forbidden TextField (I10)")
            #expect(!source.contains("TextEditor"), "\(name) contains a forbidden TextEditor (I10)")
        }
    }

    @Test("negative control: a planted TextField anywhere in the Doors directory listing is caught")
    func plantedTextFieldInDoorsDirectoryScanIsCaught() {
        let fixture = "TextField(\"answer\", text: $input)"
        #expect(fixture.contains("TextField"), "planted TextField was not detected")
    }

    // MARK: - Glossary: no Session, no attempt, no "tutoring session" anywhere in the Doors directory (exhaustive)

    @Test(
        "Glossary: no \"Session\" identifier, no \"attempt\", no \"tutoring session\" in any .swift file under App/Sources/Doors"
    )
    func noBannedGlossaryTermsAnywhereInDoorsDirectory() throws {
        for (name, source) in try Self.allSwiftFiles(under: Self.doorsRoot) {
            #expect(!source.contains("Session"), "\(name) contains the banned identifier \"Session\"")
            #expect(!source.lowercased().contains("attempt"), "\(name) contains the banned word \"attempt\"")
            #expect(
                !source.lowercased().contains("tutoring session"),
                "\(name) contains the banned phrase \"tutoring session\"")
        }
    }

    @Test("negative control: a planted \"tutoring session\" phrase is caught by the exhaustive scan")
    func plantedTutoringSessionPhraseIsCaught() {
        let fixture = "// Presented like a short tutoring session, but it is a diagnosis event."
        #expect(
            fixture.lowercased().contains("tutoring session"), "planted banned phrase was not detected")
    }
}

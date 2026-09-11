import Foundation
import Testing

@testable import Core

/// Comprehensive structural (source-text) guards for task 04.8 (`tasks/epic-04-task-08-app-expedition-screens.md`):
/// the six `App/Sources/Doors/*.swift` files, plus the parts of `App/Sources/MapUI/MapActionsView.swift` and
/// `App/Sources/Shell/AppShell.swift` this task adds. This is a NEW file — per
/// `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md`, the pre-existing
/// `AppShellStructuralTests.swift` / `MapPanelsPickersHandOffStructuralTests.swift` guards are owned by the
/// implementer's own commit and are not edited here.
///
/// **C3 exclusion (verbatim, `tasks/arbitration/arbiter-04-predispatch.md` § Q-C).** This suite's evidence is
/// logic, composition and static wiring only. It does NOT and cannot claim: (1) that any tap on a simulator
/// actually fires its action — hit-testing, sheet/cover presentation, keypad key → string binding at runtime;
/// (2) that a Door screen is laid out so its controls are visible and reachable; (3) that no runtime trap
/// occurs along the Door screens after launch; (4) that the sequence of screens a student sees at runtime
/// matches the façade's screen values, rather than only in `CoreTests`. The literal tap-through is the
/// owner's device verification (D29).
@Suite("App/Sources/Doors comprehensive structural guards (04.8 AC1-AC10)")
struct DoorExpeditionScreensStructuralTests {
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

    private static let doorFileNames = [
        "ExpeditionItemView.swift", "ExpeditionAnswerCardView.swift", "ExpeditionSummaryView.swift",
        "NumericKeypadView.swift", "ChoiceButtonsView.swift", "DoorBViewState.swift",
    ]

    private static func readDoor(_ name: String) throws -> String {
        try String(contentsOf: doorsRoot.appendingPathComponent(name), encoding: .utf8)
    }

    private static func readAllDoors() throws -> [String: String] {
        var contents: [String: String] = [:]
        for name in doorFileNames { contents[name] = try readDoor(name) }
        return contents
    }

    private static func combinedDoorsSource() throws -> String {
        try doorFileNames.map { try readDoor($0) }.joined(separator: "\n")
    }

    private static func readMapActions() throws -> String {
        try String(contentsOf: mapUIRoot.appendingPathComponent("MapActionsView.swift"), encoding: .utf8)
    }

    private static func readShell() throws -> String {
        try String(contentsOf: shellRoot.appendingPathComponent("AppShell.swift"), encoding: .utf8)
    }

    /// Finds the block between the `{` that follows `marker` and its own matching `}` — a brace-depth walk,
    /// mirroring `AppShellStructuralTests.balancedBraceBlock(after:in:)`.
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

    /// Strips `///`/`//` comment lines before a code-only scan, mirroring
    /// `AppShellStructuralTests.codeOnlyLines(in:)`: a doc comment that names a field or forbidden word in
    /// prose is not a code-level violation.
    private static func codeOnlyLines(in source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// One `case` clause of `block`: from the line starting with `prefix` up to (excluding) the next line
    /// starting with `case ` or `default:`, or the end of `block` — for switch cases with no per-case braces,
    /// mirroring `tasks/arbitration/arbiter-04-08-structural-suite-ownership.md` §4.1's `caseBranch`.
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

    private static let doorFacadeCallPattern = #"\bDoorFacade\.\w+\("#

    // MARK: - Fixture presence (all six Doors files exist)

    @Test("all six App/Sources/Doors files exist")
    func allDoorFilesExist() {
        for name in Self.doorFileNames {
            #expect(
                FileManager.default.fileExists(atPath: Self.doorsRoot.appendingPathComponent(name).path),
                "missing file: \(name)")
        }
    }

    // MARK: - I10: no free-text entry anywhere in App/Sources/Doors; the numeric keypad is DoorKeypad-only

    @Test("I10: no TextField/TextEditor anywhere in App/Sources/Doors")
    func noFreeTextEntryInDoors() throws {
        let combined = try Self.combinedDoorsSource()
        #expect(!combined.contains("TextField"), "I10: no TextField is permitted in any Door B screen")
        #expect(!combined.contains("TextEditor"), "I10: no TextEditor is permitted in any Door B screen")
    }

    @Test("negative control: a planted TextField in the Doors tree is caught")
    func plantedTextFieldInDoorsIsCaught() {
        let fixture = """
            struct RogueItemView: View {
                @Binding var input: String
                var body: some View { TextField("answer", text: $input) }
            }
            """
        #expect(fixture.contains("TextField"), "planted TextField was not detected")
    }

    @Test("AC2: NumericKeypadView renders exactly DoorKeypad.numericKeypadKeys, no other key source")
    func numericKeypadUsesOnlyDoorKeypadKeys() throws {
        let source = try Self.readDoor("NumericKeypadView.swift")
        let code = Self.codeOnlyLines(in: source)
        #expect(
            source.contains("ForEach(DoorKeypad.numericKeypadKeys, id: \\.self)"),
            "the keypad's key set must come only from DoorKeypad.numericKeypadKeys")
        #expect(
            Self.matchCount(of: #"DoorKeypad\.numericKeypadKeys"#, in: code) == 1,
            "expected exactly one code-level reference to DoorKeypad.numericKeypadKeys")
        #expect(!source.contains(Self.doorFacadeCallPattern), "no key tap may call DoorFacade")
        #expect(
            Self.matchCount(of: Self.doorFacadeCallPattern, in: source) == 0,
            "NumericKeypadView must never call DoorFacade directly")
        #expect(
            Self.matchCount(of: #"onSubmit\("#, in: source) == 1,
            "Submit must call onSubmit(_:) exactly once")
        #expect(
            source.contains(".disabled(input.isEmpty)"),
            "Submit must be disabled when the bound string is empty")
        #expect(
            source.contains(#"Image(systemName: "delete.left")"#),
            "the delete affordance must be an icon, not App-authored text")
    }

    @Test("negative control: a planted second onSubmit( call site in NumericKeypadView is caught")
    func plantedSecondOnSubmitCallIsCaught() {
        let fixture = """
            Button("Submit") { onSubmit(input) }
            Button("Also submit") { onSubmit(input) }
            """
        #expect(
            Self.matchCount(of: #"onSubmit\("#, in: fixture) == 2,
            "planted extra onSubmit( call was not detected")
    }

    // MARK: - AC3: ChoiceButtonsView submits choice id, never latex

    @Test("AC3: ChoiceButtonsView renders one button per DoorItemChoice via MathView, submits choice.id")
    func choiceButtonsSubmitsIdNotLatex() throws {
        let source = try Self.readDoor("ChoiceButtonsView.swift")
        #expect(source.contains("ForEach(choices, id: \\.id)"), "one row per DoorItemChoice, keyed on id")
        #expect(source.contains("onSelect(choice.id)"), "tapping a choice must submit its id")
        #expect(!source.contains("onSelect(choice.latex)"), "a choice tap must never submit its latex")
        #expect(
            Self.matchCount(of: #"onSelect\("#, in: source) == 1, "expected exactly one onSelect( call site")
        #expect(source.contains("MathView(latex: choice.latex)"), "choice label must render via MathView")
    }

    @Test("negative control: a planted onSelect(choice.latex) call is caught")
    func plantedOnSelectLatexIsCaught() {
        let fixture = """
            Button {
                onSelect(choice.latex)
            } label: {
                MathView(latex: choice.latex)
            }
            """
        #expect(fixture.contains("onSelect(choice.latex)"), "planted latex-as-id submission was not detected")
    }

    // MARK: - AC1: ExpeditionItemView — prompt via MathView, exactly one input path, icon-only retry indicator

    @Test("AC1: ExpeditionItemView renders promptLatex via MathView and exactly one input path by inputKind")
    func itemViewRendersExactlyOneInputPath() throws {
        let source = try Self.readDoor("ExpeditionItemView.swift")
        #expect(source.contains("MathView(latex: content.promptLatex)"))
        guard let body = Self.balancedBraceBlock(after: "switch content.inputKind {", in: source) else {
            Issue.record("could not locate the inputKind switch body")
            return
        }
        #expect(body.contains("case .numeric:"))
        #expect(body.contains("case .multipleChoice:"))
        #expect(body.contains("NumericKeypadView("))
        #expect(body.contains("ChoiceButtonsView("))
        #expect(
            Self.matchCount(of: #"case \.(numeric|multipleChoice):"#, in: body) == 2,
            "exactly one clause per DoorItemInputKind case — never both rendered, never neither")
    }

    @Test("AC1: the retry indicator is an SF Symbol only, with no App-authored text inside the isRetry block")
    func retryIndicatorCarriesNoAppAuthoredText() throws {
        let source = try Self.readDoor("ExpeditionItemView.swift")
        guard let body = Self.balancedBraceBlock(after: "if content.isRetry {", in: source) else {
            Issue.record("could not locate the isRetry conditional body")
            return
        }
        #expect(body.contains(#"Image(systemName: "arrow.counterclockwise")"#))
        #expect(
            !body.contains("Text("), "the retry indicator must carry no App-authored text (SF Symbol only)")
    }

    @Test("negative control: a planted Text(\"Retry\") inside the isRetry block is caught")
    func plantedRetryTextIsCaught() {
        let fixture = """
            if content.isRetry {
                Text("Retry")
                Image(systemName: "arrow.counterclockwise")
            }
            """
        let body = Self.balancedBraceBlock(after: "if content.isRetry {", in: fixture)
        #expect(body?.contains("Text(") == true, "planted retry text literal was not detected")
    }

    // MARK: - AC4: ExpeditionAnswerCardView — indicator, display-kind routing, one continue control

    @Test("AC4: no App-authored \"Correct\"/\"Incorrect\"/\"Try again\" copy anywhere in Doors")
    func noAppAuthoredCorrectnessCopy() throws {
        let combined = try Self.combinedDoorsSource()
        for banned in ["\"Correct\"", "\"Incorrect\"", "\"Try again\""] {
            #expect(!combined.contains(banned), "found banned App-authored correctness copy: \(banned)")
        }
        let card = try Self.readDoor("ExpeditionAnswerCardView.swift")
        #expect(
            card.contains(#"Image(systemName: content.correct ? "checkmark.circle" : "xmark.circle")"#),
            "the correct/incorrect indicator must be an SF Symbol driven by content.correct")
    }

    @Test("negative control: a planted Text(content.correct ? \"Correct\" : \"Incorrect\") is caught")
    func plantedCorrectnessCopyIsCaught() {
        let fixture = #"Text(content.correct ? "Correct" : "Incorrect")"#
        #expect(fixture.contains("\"Correct\""), "planted correctness copy literal was not detected")
    }

    @Test(
        "AC4: correctAnswerDisplayKind routes MathView for .latex, plain Text for .plain — both arms present")
    func answerCardRoutesOnDisplayKindNotItemType() throws {
        let source = try Self.readDoor("ExpeditionAnswerCardView.swift")
        guard
            let body = Self.balancedBraceBlock(
                after: "switch content.correctAnswerDisplayKind {", in: source)
        else {
            Issue.record("could not locate the correctAnswerDisplayKind switch body")
            return
        }
        #expect(body.contains("case .latex:"))
        #expect(body.contains("MathView(latex: content.correctAnswerDisplay)"))
        #expect(body.contains("case .plain:"))
        #expect(body.contains("Text(content.correctAnswerDisplay)"))
        #expect(
            !Self.codeOnlyLines(in: source).contains("item.type"),
            "the answer card has no access to item.type and must not name it in code")
        #expect(source.contains("Text(content.why)"), "why is always plain Text, never latex")
    }

    @Test("negative control: an answer card that routes only via MathView regardless of kind is caught")
    func plantedSingleArmDisplayRoutingIsCaught() {
        let fixture = """
            switch content.correctAnswerDisplayKind {
            case .latex:
                MathView(latex: content.correctAnswerDisplay)
            }
            """
        let body = Self.balancedBraceBlock(after: "switch content.correctAnswerDisplayKind {", in: fixture)
        #expect(body?.contains("case .plain:") == false, "planted missing .plain arm was not detected")
    }

    @Test(
        "AC4: ExpeditionAnswerCardView renders exactly one continue control, whose tap calls onContinue() once"
    )
    func answerCardHasExactlyOneContinueControl() throws {
        let source = try Self.readDoor("ExpeditionAnswerCardView.swift")
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: source) == 1,
            "expected exactly one Button( in the answer card")
        #expect(
            Self.matchCount(of: #"onContinue\(\)"#, in: source) == 1,
            "expected exactly one onContinue() call site")
        #expect(source.contains(#"Button("Continue") { onContinue() }"#))
    }

    @Test("negative control: a planted second Button in the answer card is caught by the count")
    func plantedSecondAnswerCardButtonIsCaught() {
        let fixture = """
            Button("Continue") { onContinue() }
            Button("Skip") { onContinue() }
            """
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: fixture) == 2, "planted extra Button( was not detected")
    }

    // MARK: - I3: the answer card is a distinct phase; only continueTapped ever leaves it

    @Test("I3: DoorBPhase declares exactly the two expected cases, .screen and .answerCard")
    func doorBPhaseHasExactlyTwoCases() throws {
        let source = try Self.readShell()
        guard let body = Self.balancedBraceBlock(after: "enum DoorBPhase: Equatable {", in: source) else {
            Issue.record("could not locate DoorBPhase's body")
            return
        }
        let cases = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
        #expect(cases.count == 2, "expected exactly 2 DoorBPhase cases, found: \(cases)")
        #expect(cases.contains { $0.hasPrefix("case screen(") })
        #expect(cases.contains { $0.hasPrefix("case answerCard(") })
    }

    @Test("negative control: a planted third DoorBPhase case is caught")
    func plantedThirdDoorBPhaseCaseIsCaught() {
        let fixture = """
            enum DoorBPhase: Equatable {
                case screen(DoorBScreen)
                case answerCard(DoorBAnswerAdvance)
                case autoAdvancing
            }
            """
        let body = Self.balancedBraceBlock(after: "enum DoorBPhase: Equatable {", in: fixture)
        let cases = body!.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
        #expect(cases.count == 3, "planted third DoorBPhase case was not detected: \(cases)")
    }

    @Test(
        "I3: continueAfterAnswer has exactly one call site (DoorBRunScreen.continueTapped), reachable only from the answer card's continue control"
    )
    func continueAfterAnswerHasExactlyOneCallSite() throws {
        let shell = try Self.readShell()
        #expect(
            Self.matchCount(of: #"DoorFacade\.continueAfterAnswer\("#, in: shell) == 1,
            "continueAfterAnswer must have exactly one call site, in DoorBRunScreen.continueTapped")
        guard
            let continueTapped = Self.balancedBraceBlock(
                after:
                    "private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {",
                in: shell)
        else {
            Issue.record("could not locate continueTapped's body")
            return
        }
        #expect(continueTapped.contains("DoorFacade.continueAfterAnswer("))
        guard let content = Self.balancedBraceBlock(after: "switch current.phase {", in: shell) else {
            Issue.record("could not locate DoorBRunScreen's phase switch")
            return
        }
        guard
            let answerCardArm = Self.caseBranch(startingWith: "case .answerCard(let advance):", in: content)
        else {
            Issue.record("could not locate the .answerCard case arm")
            return
        }
        #expect(
            answerCardArm.contains("ExpeditionAnswerCardView("),
            "the .answerCard phase must render ExpeditionAnswerCardView, not skip to the next screen")
        #expect(
            answerCardArm.contains("continueTapped(advance, current: current)"),
            "the answer card's onContinue closure must call continueTapped")
        #expect(
            !answerCardArm.contains("ExpeditionItemView(")
                && !answerCardArm.contains("ExpeditionSummaryView("),
            "the .answerCard arm must not itself render the next item or summary — only continueTapped can advance"
        )
    }

    @Test(
        "negative control: a .answerCard arm that renders the next item directly, bypassing continueTapped, is caught"
    )
    func plantedAnswerCardBypassIsCaught() {
        let fixture = """
            switch current.phase {
            case .answerCard(let advance):
                ExpeditionItemView(content: advance.answerCard.nextItem, keypadInput: $viewState.keypadInput,
                    onSubmitNumeric: { _ in }, onSubmitChoice: { _ in })
            }
            """
        let arm = Self.caseBranch(startingWith: "case .answerCard(let advance):", in: fixture)
        #expect(
            arm?.contains("ExpeditionItemView(") == true,
            "planted bypass of the explicit continue control was not detected")
    }

    // MARK: - AC5: ExpeditionSummaryView — heading/name lists, two Core-supplied labels, no tint/fraction/percent

    @Test("AC5: ExpeditionSummaryView renders both heading/list pairs and exactly two Core-supplied buttons")
    func summaryRendersHeadingsListsAndTwoButtons() throws {
        let source = try Self.readDoor("ExpeditionSummaryView.swift")
        #expect(source.contains("Text(summary.clearedHeading)"))
        #expect(source.contains("ForEach(summary.clearedNodeNames, id: \\.self)"))
        #expect(source.contains("Text(summary.blockedHeading)"))
        #expect(source.contains("ForEach(summary.blockedNodeNames, id: \\.self)"))
        #expect(
            Self.matchCount(of: #"\bButton\("#, in: source) == 2,
            "expected exactly two buttons in the summary")
        #expect(source.contains("Button(summary.startAnotherLabel)"))
        #expect(source.contains("Button(summary.backToMapLabel)"))
        #expect(
            !source.contains(#"Button(""#),
            "the summary's two buttons must use Core-supplied labels, never an App-authored string literal")
    }

    @Test("AC5: no region tint, fraction or percentage literal anywhere in ExpeditionSummaryView")
    func summaryShowsNoTintFractionOrPercentage() throws {
        let code = Self.codeOnlyLines(in: try Self.readDoor("ExpeditionSummaryView.swift"))
        #expect(!code.contains("%"), "the summary must show no percentage")
        #expect(!code.lowercased().contains("fraction"), "the summary must show no fraction")
        #expect(!code.lowercased().contains("tint"), "the summary must show no region tint")
        #expect(
            !code.contains("summary.itemCount"),
            "the item count is deliberately not rendered in code (§6 default 5)")
    }

    @Test("negative control: a planted percentage literal in ExpeditionSummaryView is caught")
    func plantedPercentageInSummaryIsCaught() {
        let fixture = #"Text("\(Int((fraction * 100).rounded()))% cleared")"#
        #expect(fixture.contains("%"), "planted percentage literal was not detected")
    }

    @Test(
        "AC5: the write-failure and \"Start another\" error texts are plain Text sourced only from a parameter"
    )
    func summaryErrorTextsAreParametersOnly() throws {
        let source = try Self.readDoor("ExpeditionSummaryView.swift")
        #expect(source.contains("if let writeFailureText {"))
        #expect(source.contains("if let startAnotherErrorText {"))
        guard let writeFailureBlock = Self.balancedBraceBlock(after: "if let writeFailureText {", in: source)
        else {
            Issue.record("could not locate the writeFailureText conditional")
            return
        }
        #expect(writeFailureBlock.trimmingCharacters(in: .whitespacesAndNewlines) == "Text(writeFailureText)")
        #expect(
            !source.contains("CoreErrorText"),
            "ExpeditionSummaryView never resolves CoreErrorText itself — its caller passes already-resolved text"
        )
    }

    // MARK: - I14: each Door action/composition method makes exactly one DoorFacade call

    @Test("I14: each of DoorBRunScreen's four action methods makes exactly one DoorFacade call")
    func doorBRunScreenActionsMakeExactlyOneCallEach() throws {
        let shell = try Self.readShell()
        let markers = [
            "private func submit(_ value: String, current: DoorBRunSnapshot) {",
            "private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {",
            "private func startAnother(current: DoorBRunSnapshot) {",
            "private func backToMap(current: DoorBRunSnapshot) {",
        ]
        for marker in markers {
            guard let body = Self.balancedBraceBlock(after: marker, in: shell) else {
                Issue.record("could not locate body for \(marker)")
                continue
            }
            let count = Self.matchCount(of: Self.doorFacadeCallPattern, in: body)
            #expect(count == 1, "expected exactly one DoorFacade call in \(marker), found \(count)")
        }
    }

    @Test("negative control: a planted second DoorFacade call inside submit(_:current:) is caught")
    func plantedSecondDoorFacadeCallInSubmitIsCaught() {
        let fixture = """
            private func submit(_ value: String, current: DoorBRunSnapshot) {
                let (advance, runState, failure) = DoorFacade.answer(current.runState, submitted: value, today: today)
                let (mapState, _) = DoorFacade.backToMap(runState, today: today)
            }
            """
        let body = DoorExpeditionScreensStructuralTests.balancedBraceBlock(
            after: "private func submit(_ value: String, current: DoorBRunSnapshot) {", in: fixture)
        #expect(
            DoorExpeditionScreensStructuralTests.matchCount(
                of: DoorExpeditionScreensStructuralTests.doorFacadeCallPattern, in: body!) == 2,
            "planted extra DoorFacade call was not detected")
    }

    @Test(
        "I14: StartExpeditionActionButton and UnitExpeditionActionButton each make exactly one DoorFacade call"
    )
    func mapActionButtonsMakeExactlyOneDoorFacadeCallEach() throws {
        let source = try Self.readMapActions()
        for structName in ["StartExpeditionActionButton", "UnitExpeditionActionButton"] {
            guard let structBody = Self.balancedBraceBlock(after: "struct \(structName): View {", in: source),
                let startBody = Self.balancedBraceBlock(after: "private func start() {", in: structBody)
            else {
                Issue.record("could not isolate \(structName).start()")
                continue
            }
            let count = Self.matchCount(of: Self.doorFacadeCallPattern, in: startBody)
            #expect(
                count == 1, "expected exactly one DoorFacade call in \(structName).start(), found \(count)")
        }
    }

    @Test("I14: no file in this task's scope references a Core transition type directly")
    func noForbiddenCoreTransitionTypeReferenced() throws {
        let combined =
            try Self.combinedDoorsSource() + "\n" + Self.readMapActions() + "\n" + Self.readShell()
        let forbidden = [
            "ExpeditionRun(", "ExpeditionRun.", "DiagnosisRun(", "DiagnosisRun.", "ItemChecker(",
            "ItemChecker.",
            "DoorBExpeditionFlow.", "DoorADiagnosisFlow.", "Expedition.compose", "MasteryTransitions.",
            "MarkerTrail.", "L0Checker.", "BundleIO.", "BundleLoader.", "StudentStateStore.", "LayoutEngine.",
            "StudentState(",
        ]
        for name in forbidden {
            #expect(!combined.contains(name), "forbidden Core transition-type reference found: \(name)")
        }
    }

    @Test("negative control: a planted ExpeditionRun( construction is caught")
    func plantedForbiddenCoreTypeConstructionIsCaught() {
        let fixture = "let run = ExpeditionRun(state: state, today: today)"
        #expect(
            fixture.contains("ExpeditionRun("), "planted forbidden Core-type construction was not detected")
    }

    @Test("I14: DoorBRunSnapshot and DoorBStartOutcome are not Equatable (arbiter-04-doorrunstate-equatable)")
    func runSnapshotAndStartOutcomeAreNotEquatable() throws {
        let shell = try Self.readShell()
        #expect(shell.contains("struct DoorBRunSnapshot {"))
        #expect(!shell.contains("struct DoorBRunSnapshot: Equatable {"))
        let mapActions = try Self.readMapActions()
        #expect(mapActions.contains("struct DoorBStartOutcome {"))
        #expect(!mapActions.contains("struct DoorBStartOutcome: Equatable {"))
        // DoorBPhase legitimately stays Equatable: its payloads are already-Equatable Core types.
        #expect(shell.contains("enum DoorBPhase: Equatable {"))
    }

    @Test("negative control: a planted Equatable DoorBRunSnapshot declaration is caught")
    func plantedEquatableRunSnapshotIsCaught() {
        let fixture = "struct DoorBRunSnapshot: Equatable {\n    let runState: DoorRunState\n}"
        #expect(
            fixture.contains("struct DoorBRunSnapshot: Equatable {"),
            "planted Equatable conformance over a DoorRunState-holding struct was not detected")
    }

    @Test("I14: no hand-rolled == comparison over a Core run/map state value")
    func noHandRolledEqualityOverCoreState() throws {
        // Per `tasks/arbitration/arbiter-04-doorrunstate-equatable.md` E3: a hand-written `==`/`extension …:
        // Equatable` over `DoorRunState`/`MapState`/`ContentBundle` — in product code or a test file — would
        // reintroduce the reversed EPIC 03 design choice through the back door. This checks App/Sources only;
        // field-access chains like `mapState.state.marker.courseCode` (a plain String comparison) are not
        // flagged, because they never construct a whole-value comparison or a retroactive conformance.
        let combined =
            try Self.combinedDoorsSource() + "\n" + Self.readMapActions() + "\n" + Self.readShell()
        let code = Self.codeOnlyLines(in: combined)
        #expect(!code.contains("static func =="), "no file may hand-roll an == operator over Core state")
        for type in ["DoorRunState", "MapState", "ContentBundle"] {
            #expect(
                !code.contains("extension \(type)"),
                "no file may retroactively conform \(type) to Equatable")
        }
    }

    @Test("negative control: a planted retroactive \"extension MapState: Equatable\" is caught")
    func plantedHandRolledEqualityIsCaught() {
        let fixture =
            "extension MapState: Equatable {\n    public static func == (lhs: MapState, rhs: MapState) -> Bool { true }\n}"
        #expect(fixture.contains("extension MapState"), "planted retroactive conformance was not detected")
        #expect(fixture.contains("static func =="), "planted hand-rolled == operator was not detected")
    }

    // MARK: - AC9: backToMap replaces the map holder, then dismisses; the summary content resolves the write-failure banner via CoreErrorText only

    @Test("AC9: backToMap replaces mapHolder with DoorFacade.backToMap's mapState before dismissing")
    func backToMapReplacesMapHolderBeforeDismiss() throws {
        let shell = try Self.readShell()
        guard
            let body = Self.balancedBraceBlock(
                after: "private func backToMap(current: DoorBRunSnapshot) {", in: shell)
        else {
            Issue.record("could not locate backToMap's body")
            return
        }
        #expect(body.contains("DoorFacade.backToMap(current.runState, today: today)"))
        #expect(body.contains("mapHolder.replace(with: mapState)"))
        #expect(body.contains("onDismiss()"))
        guard let replaceRange = body.range(of: "mapHolder.replace(with: mapState)"),
            let dismissRange = body.range(of: "onDismiss()")
        else {
            Issue.record("could not locate both statements to order-check")
            return
        }
        #expect(
            replaceRange.lowerBound < dismissRange.lowerBound,
            "the map must be re-derived (mapHolder.replace) before the expedition presentation is dismissed")
    }

    @Test(
        "Copy: the summary's write-failure banner resolves only via CoreErrorText.text(for:), never authored text"
    )
    func writeFailureBannerResolvesOnlyViaCoreErrorText() throws {
        let shell = try Self.readShell()
        guard let content = Self.balancedBraceBlock(after: "switch current.phase {", in: shell) else {
            Issue.record("could not locate DoorBRunScreen's phase switch")
            return
        }
        guard
            let summaryArm = Self.caseBranch(
                startingWith: "case .screen(.summary(let summary)):", in: content)
        else {
            Issue.record("could not locate the .screen(.summary) case arm")
            return
        }
        #expect(summaryArm.contains("CoreError(rawValue: $0).flatMap(CoreErrorText.text(for:))"))
        #expect(
            Self.matchCount(of: #"CoreErrorText\.text\(for:"#, in: summaryArm) == 1,
            "expected exactly one CoreErrorText resolution site in the summary arm")
    }

    // MARK: - @State discipline

    @Test(
        "@State discipline: zero @State properties across all six App/Sources/Doors files (pure render layer)"
    )
    func doorsFilesHoldNoStateProperties() throws {
        let contents = try Self.readAllDoors()
        var stateLines: [String] = []
        for (name, source) in contents {
            for line in source.split(separator: "\n") where line.contains("@State") {
                stateLines.append("\(name): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        #expect(
            stateLines.isEmpty, "expected zero @State properties in App/Sources/Doors, found: \(stateLines)")
    }

    @Test("@State discipline: DoorBRunScreen holds exactly one @State property, DoorBViewState")
    func doorBRunScreenHoldsExactlyOneStateProperty() throws {
        let shell = try Self.readShell()
        guard let body = Self.balancedBraceBlock(after: "private struct DoorBRunScreen: View {", in: shell)
        else {
            Issue.record("could not locate DoorBRunScreen's body")
            return
        }
        let stateLines = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("@State") }
        #expect(stateLines.count == 1, "expected exactly one @State property, found: \(stateLines)")
        #expect(stateLines.first == "@State private var viewState = DoorBViewState()")
    }

    @Test("negative control: a planted second @State property in DoorBRunScreen is caught")
    func plantedSecondStatePropertyInRunScreenIsCaught() {
        let fixture = """
            private struct DoorBRunScreen: View {
                @State private var viewState = DoorBViewState()
                @State private var cachedScreen: DoorBScreen?
            }
            """
        let body = Self.balancedBraceBlock(after: "private struct DoorBRunScreen: View {", in: fixture)
        let stateLines = body!.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("@State") }
        #expect(stateLines.count == 2, "planted second @State property was not detected: \(stateLines)")
    }

    // MARK: - MathView usage: exactly three call sites, each field-routed correctly

    @Test("MathView: exactly three call sites across App/Sources/Doors — prompt, choice label, latex answer")
    func mathViewHasExactlyThreeCallSitesInDoors() throws {
        let combined = try Self.combinedDoorsSource()
        let count = Self.matchCount(of: #"MathView\(latex:"#, in: combined)
        #expect(count == 3, "expected exactly 3 MathView(latex:) call sites, found \(count)")
        #expect(combined.contains("MathView(latex: content.promptLatex)"))
        #expect(combined.contains("MathView(latex: choice.latex)"))
        #expect(combined.contains("MathView(latex: content.correctAnswerDisplay)"))
    }

    @Test("negative control: a planted fourth MathView(latex:) call site (why, rendered as latex) is caught")
    func plantedFourthMathViewCallSiteIsCaught() {
        let fixture = """
            MathView(latex: content.promptLatex)
            MathView(latex: choice.latex)
            MathView(latex: content.correctAnswerDisplay)
            MathView(latex: content.why)
            """
        #expect(
            DoorExpeditionScreensStructuralTests.matchCount(of: #"MathView\(latex:"#, in: fixture) == 4,
            "planted extra MathView call site was not detected")
    }

    // MARK: - Copy: student text comes only from Core-supplied values or the known chrome literals

    @Test("Copy: every Text(\"…\")/Button(\"…\") string literal in Doors is in the known chrome allow-list")
    func doorsStringLiteralsAreOnlyKnownChrome() throws {
        let combined = try Self.combinedDoorsSource()
        let pattern = #"(?:Text|Button)\("([^"]+)"\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Issue.record("bad regex")
            return
        }
        let nsrange = NSRange(combined.startIndex..., in: combined)
        var found: Set<String> = []
        regex.enumerateMatches(in: combined, range: nsrange) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: combined) else { return }
            found.insert(String(combined[range]))
        }
        let allowList: Set<String> = ["Continue", "Submit"]
        #expect(
            found == allowList, "unexpected App-authored chrome literal(s): \(found.subtracting(allowList))")
    }

    @Test("negative control: a planted App-authored chrome literal outside the allow-list is caught")
    func plantedForeignChromeLiteralIsCaught() {
        let fixture = #"Button("Skip this one") { onContinue() }"#
        let pattern = #"(?:Text|Button)\("([^"]+)"\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Issue.record("bad regex")
            return
        }
        let nsrange = NSRange(fixture.startIndex..., in: fixture)
        var found: Set<String> = []
        regex.enumerateMatches(in: fixture, range: nsrange) { match, _, _ in
            guard let match, let range = Range(match.range(at: 1), in: fixture) else { return }
            found.insert(String(fixture[range]))
        }
        #expect(
            !found.subtracting(["Continue", "Submit"]).isEmpty,
            "planted foreign chrome literal was not detected")
    }

    // MARK: - Glossary: no Session identifiers, no "attempt"

    @Test("Glossary: no \"Session\" identifier (case-sensitive) anywhere in App/Sources/Doors")
    func noSessionIdentifierInDoors() throws {
        let combined = try Self.combinedDoorsSource()
        #expect(
            !combined.contains("Session"), "the banned Expedition synonym \"Session\" appears in a Doors file"
        )
    }

    @Test("negative control: a planted DoorBSession identifier is caught by the case-sensitive scan")
    func plantedSessionIdentifierIsCaught() {
        let fixture = "struct DoorBSession: Equatable { let keypadInput: String }"
        #expect(fixture.contains("Session"), "planted Session identifier was not detected")
    }

    @Test("Glossary: no \"attempt\" (case-insensitive) anywhere in App/Sources/Doors")
    func noAttemptWordInDoors() throws {
        let combined = try Self.combinedDoorsSource()
        #expect(
            !combined.lowercased().contains("attempt"),
            "the banned Diagnosis-event synonym \"attempt\" appears in a Doors file")
    }

    @Test("negative control: a planted \"attempt\" comment is caught by the case-insensitive scan")
    func plantedAttemptWordIsCaught() {
        let fixture = "// records the student's second attempt at this item"
        #expect(fixture.lowercased().contains("attempt"), "planted banned word was not detected")
    }

    // MARK: - T2 boundary note: submit(_:current:) performs no precondition on the student's raw input

    @Test(
        "T2: submit(_:current:) performs no guard/precondition on the raw keypad/choice value before DoorFacade.answer"
    )
    func submitPerformsNoPreconditionOnRawInput() throws {
        let shell = try Self.readShell()
        guard
            let body = Self.balancedBraceBlock(
                after: "private func submit(_ value: String, current: DoorBRunSnapshot) {", in: shell)
        else {
            Issue.record("could not locate submit's body")
            return
        }
        #expect(
            !body.contains("guard "), "submit must not guard on the raw student value (Core's own concern)")
        #expect(!body.contains("precondition("), "submit must not precondition on the raw student value")
        #expect(
            body.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(
                "let (advance, runState, failure)"),
            "the first statement of submit must be the unconditional DoorFacade.answer call")
    }
}

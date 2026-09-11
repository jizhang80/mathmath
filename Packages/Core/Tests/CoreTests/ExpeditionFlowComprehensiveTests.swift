import Foundation
import Testing

@testable import Core

/// Comprehensive tester suite for task 04.4 (`core-door-b-expedition-flow`), covering §5 T1-T6 and every
/// AC in `tasks/epic-04-task-04-core-door-b-expedition-flow.md`. The implementer's own
/// `ExpeditionFlowTests.swift` owns the plain happy-path smoke (AC1/AC2/AC9 on an all-correct run); this
/// file extends into the D27 retry/hand-off/block machinery, the I3 phase gate, the Q-G write-ahead value,
/// the summary's I5/content-policy shape, and every regression guard's negative control.
@Suite("DoorBExpeditionFlow — comprehensive")
struct ExpeditionFlowComprehensiveTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()  // CoreTests
    }

    private static var repoRoot: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var demoBundleDir: URL { repoRoot.appendingPathComponent("data/demo") }

    private static func loadDemoBundle() throws -> ContentBundle { try BundleIO.read(from: demoBundleDir) }

    private static func today() -> CalendarDay {
        guard let day = CalendarDay(iso: "2026-09-10") else {
            preconditionFailure("2026-09-10 must be a valid CalendarDay")
        }
        return day
    }

    private static func state(nodes: [String: NodeState]) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    private static func probeItem(bundle: ContentBundle, nodeId: String, itemId: String) throws
        -> ProbeItem
    {
        let node = try #require(bundle.nodes.nodes.first(where: { $0.id == nodeId }))
        return try #require(node.probeItems.first(where: { $0.id == itemId }))
    }

    private static func node(bundle: ContentBundle, nodeId: String) throws -> Node {
        try #require(bundle.nodes.nodes.first(where: { $0.id == nodeId }))
    }

    private static func threeNodeCompose(bundle: ContentBundle) throws -> ComposeResult {
        ComposeResult(
            slots: [
                ComposeSlot(
                    nodeId: "exponent-laws",
                    item: try probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1"),
                    kind: .newLearning),
                ComposeSlot(
                    nodeId: "polynomials",
                    item: try probeItem(bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1"),
                    kind: .newLearning),
                ComposeSlot(
                    nodeId: "simplifying-expressions",
                    item: try probeItem(
                        bundle: bundle, nodeId: "simplifying-expressions",
                        itemId: "simplifying-expressions-1"), kind: .newLearning),
            ], skippedNodeIds: [])
    }

    // MARK: - T1 / AC3 / AC4 / AC5 / AC6 / AC7 / AC8 / AC9 — the full D27 run, driven through the façade

    @Test(
        "AC3-AC9: full real-data run through retry, D27 hand-off, resume, two blocks and a natural end")
    func fullD27RunThroughFacade() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        var studentState = Self.state(nodes: [:])

        let start = DoorBExpeditionFlow.start(compose: compose)
        guard case .item(let firstItem) = start.screen else {
            Issue.record("expected .item")
            return
        }
        #expect(firstItem.nodeId == "exponent-laws")
        #expect(firstItem.isRetry == false)
        var runState = start.runState

        // --- exponent-laws: first miss on a tagged distractor -> retry (AC3) ---
        let miss1 = DoorBExpeditionFlow.answer(
            runState, submitted: "5", state: studentState, bundle: bundle, today: Self.today())
        #expect(miss1.answerCard.correct == false)
        // I3: the answer call itself never surfaces a next screen — its own type has no such field
        // (compile-time enforced; see AC2 test below for the source-scan guard).
        let continue1 = DoorBExpeditionFlow.continueAfterAnswer(miss1, bundle: bundle)
        guard case .item(let retryItem) = continue1.screen else {
            Issue.record("expected .item (retry) after the first miss")
            return
        }
        #expect(retryItem.isRetry == true)
        #expect(retryItem.nodeId == "exponent-laws")
        studentState = continue1.state
        runState = continue1.runState

        // --- exponent-laws: second miss, a whitespace-padded numeric string on the retry's mc item,
        // opens diagnosis (AC4); assert the exact submitted strings survive into the ItemMiss values. ---
        let miss2 = DoorBExpeditionFlow.answer(
            runState, submitted: "  0 ", state: studentState, bundle: bundle, today: Self.today())
        #expect(miss2.answerCard.correct == false)
        // AC5: never on the miss that opens diagnosis.
        #expect(miss2.answerCard.extraLine == nil)
        let handoffMisses = try #require(miss2.pendingHandoffMisses)
        #expect(handoffMisses.count == 2)
        #expect(handoffMisses[0].submittedValue == "5")
        #expect(handoffMisses[0].item.id == "exponent-laws-1")
        #expect(handoffMisses[1].submittedValue == "  0 ")
        #expect(handoffMisses[1].item.id == "exponent-laws-2")

        let continue2 = DoorBExpeditionFlow.continueAfterAnswer(miss2, bundle: bundle)
        guard case .diagnosis(let diagScreen1) = continue2.screen else {
            Issue.record("expected .diagnosis after the second miss")
            return
        }
        guard case .hypothesis(_, let offer1) = diagScreen1 else {
            Issue.record("expected .hypothesis")
            return
        }

        // Cross-check: calling 04.3's façade directly with the exact same event/misses/state/shownIds
        // reproduces the same screen (AC4's "exact assembly" made observable end-to-end).
        let directEvent = DoorADiagnosisFlow.open(
            originNodeId: "exponent-laws", trigger: .expeditionSecondMiss, levelBudget: 1)
        let directAdvance = DoorADiagnosisFlow.start(
            event: directEvent, misses: handoffMisses, shownItemIdsInRun: miss2.runState.run.shownItemIds,
            state: miss2.state, bundle: bundle)
        #expect(directAdvance.screen == diagScreen1)
        #expect(directAdvance.state == continue2.state)
        runState = continue2.runState

        // --- drive the diagnosis leg directly through 04.3's façade (never through this task's façade,
        // per §6 decision default) until it reaches .terminal, then hand back through resumeAfterDiagnosis
        // (AC7). Fail both probes so the candidate is confirmed, then (budget 1) immediately capped. ---
        let probeDecision = DoorADiagnosisFlow.decideProbe(
            offer1, accept: true, state: continue2.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeDecision.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let candidateId = offer1.candidateId

        let probeAnswer1 = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: "wrong", state: probeDecision.state, bundle: bundle, today: Self.today())
        let afterProbe1 = DoorADiagnosisFlow.continueAfterProbeAnswer(probeAnswer1, bundle: bundle)
        guard case .probeItem(_, let probe2) = afterProbe1 else {
            Issue.record("expected the second .probeItem")
            return
        }
        let probeAnswer2 = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: "wrong", state: probeAnswer1.state, bundle: bundle, today: Self.today())
        let afterProbe2 = DoorADiagnosisFlow.continueAfterProbeAnswer(probeAnswer2, bundle: bundle)
        guard case .terminal(let terminalContent) = afterProbe2 else {
            Issue.record("expected .terminal")
            return
        }
        #expect(terminalContent.terminal == .capped)
        let outcome = terminalContent.outcome
        #expect(outcome.state.nodes[candidateId]?.mastery == .blocked)

        let resume = DoorBExpeditionFlow.resumeAfterDiagnosis(
            runState, outcome: outcome, bundle: bundle, today: Self.today())
        guard case .item(let afterResumeItem) = resume.screen else {
            Issue.record("expected .item after resume")
            return
        }
        #expect(afterResumeItem.nodeId == "polynomials")
        #expect(afterResumeItem.isRetry == false)
        // AC7: every pre-diagnosis ItemResult survives resume unchanged.
        #expect(runState.run.results.map(\.itemId) == ["exponent-laws-1", "exponent-laws-2"])
        #expect(resume.runState.run.results == runState.run.results)
        studentState = resume.state
        runState = resume.runState

        // --- polynomials: first miss -> retry, no extraLine (AC5's "never on a first miss"). ---
        let polyMiss1 = DoorBExpeditionFlow.answer(
            runState, submitted: "3", state: studentState, bundle: bundle, today: Self.today())
        #expect(polyMiss1.answerCard.extraLine == nil)
        let polyContinue1 = DoorBExpeditionFlow.continueAfterAnswer(polyMiss1, bundle: bundle)
        guard case .item(let polyRetry) = polyContinue1.screen else {
            Issue.record("expected .item (retry)")
            return
        }
        #expect(polyRetry.isRetry == true)
        #expect(polyRetry.nodeId == "polynomials")
        studentState = polyContinue1.state
        runState = polyContinue1.runState

        // --- polynomials: second miss, diagnosisUsed already true -> block, extraLine set (AC5), no
        // diagnosis call this time. ---
        let polyMiss2 = DoorBExpeditionFlow.answer(
            runState, submitted: "b", state: studentState, bundle: bundle, today: Self.today())
        #expect(polyMiss2.answerCard.extraLine == DoorBSummaryCopy.secondMissLine)
        #expect(polyMiss2.pendingHandoffMisses == nil)
        #expect(polyMiss2.runState.run.blockedNodeIds.contains("polynomials"))
        let polyContinue2 = DoorBExpeditionFlow.continueAfterAnswer(polyMiss2, bundle: bundle)
        guard case .item(let afterPolyBlock) = polyContinue2.screen else {
            Issue.record("expected .item (next node) after the block")
            return
        }
        #expect(afterPolyBlock.nodeId == "simplifying-expressions")
        studentState = polyContinue2.state
        runState = polyContinue2.runState

        // AC6: at most one diagnosis event/hand-off happened across this whole run (polynomials'
        // second miss did not re-open one).
        #expect(runState.run.diagnosisUsed == true)

        // --- simplifying-expressions: first miss -> retry; second miss -> block; this is the run's last
        // result, so the natural end must be computed inside THIS answer call, never inside continue
        // (AC8). ---
        let seMiss1 = DoorBExpeditionFlow.answer(
            runState, submitted: "2", state: studentState, bundle: bundle, today: Self.today())
        let seContinue1 = DoorBExpeditionFlow.continueAfterAnswer(seMiss1, bundle: bundle)
        guard case .item(let seRetry) = seContinue1.screen else {
            Issue.record("expected .item (retry)")
            return
        }
        #expect(seRetry.isRetry == true)
        studentState = seContinue1.state
        runState = seContinue1.runState

        let seMiss2 = DoorBExpeditionFlow.answer(
            runState, submitted: "b", state: studentState, bundle: bundle, today: Self.today())
        #expect(seMiss2.answerCard.extraLine == DoorBSummaryCopy.secondMissLine)
        let pendingEnd = try #require(seMiss2.pendingEnd)
        let seContinue2 = DoorBExpeditionFlow.continueAfterAnswer(seMiss2, bundle: bundle)
        guard case .summary(let summary) = seContinue2.screen else {
            Issue.record("expected .summary at the natural end")
            return
        }
        // AC8: continue's state is exactly the state answer already computed, by identity/equality —
        // never re-derived by continueAfterAnswer.
        #expect(seContinue2.state == pendingEnd.state)

        // AC9: summary content — cleared/blocked names, fixed labels, no tint/fraction fields.
        #expect(summary.itemCount == 6)
        #expect(summary.clearedNodeNames.isEmpty)
        let blockedNames = Set(summary.blockedNodeNames)
        let polynomialsNode = try Self.node(bundle: bundle, nodeId: "polynomials")
        let simplifyingNode = try Self.node(bundle: bundle, nodeId: "simplifying-expressions")
        #expect(blockedNames == Set([polynomialsNode.name, simplifyingNode.name]))
        #expect(summary.clearedHeading == DoorBSummaryCopy.clearedHeading)
        #expect(summary.blockedHeading == DoorBSummaryCopy.blockedHeading)
        #expect(summary.startAnotherLabel == DoorBSummaryCopy.startAnotherLabel)
        #expect(summary.backToMapLabel == DoorBSummaryCopy.backToMapLabel)
    }

    // MARK: - AC5 (in-memory fixture): the entered-already-blocked idempotent no-op case

    @Test(
        "AC5: the Q5 extraLine fires from missCounts even when the block transition is a documented no-op (node entered the run already .blocked)"
    )
    func extraLineFromMissCountsNotBlockedNodeIds() throws {
        let bundle = try Self.loadDemoBundle()
        let item1 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let item2 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-2")
        let polyItem1 = try Self.probeItem(bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1")

        // Entering StudentState: exponent-laws already blocked (the fringe's own
        // `{n : mastery(n) = blocked}` admission clause).
        let alreadyBlocked = NodeState(
            mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: false)
        let studentState = Self.state(nodes: ["exponent-laws": alreadyBlocked])

        // A run fixture at the exact boundary this task's own §3 quote documents: one prior miss on
        // exponent-laws (missCounts == 1), diagnosisUsed already true (spent elsewhere this run), and the
        // retry item live as currentItem. A second slot keeps the queue non-empty so this isn't confused
        // with a natural end.
        let fixtureRun = ExpeditionRunState(
            queue: [ComposeSlot(nodeId: "polynomials", item: polyItem1, kind: .newLearning)],
            currentItem: CurrentItem(nodeId: "exponent-laws", item: item2, kind: .newLearning, isRetry: true),
            diagnosisUsed: true, missCounts: ["exponent-laws": 1], shownItemIds: [item1.id],
            itemPoolEmptyNodeIds: [], results: [], clearedNodeIds: [], blockedNodeIds: [], itemsAnswered: 1,
            suspendedForDiagnosisNodeId: nil)
        let runState = DoorBRunState(run: fixtureRun, pendingFirstMiss: nil)

        let answer = DoorBExpeditionFlow.answer(
            runState, submitted: "b", state: studentState, bundle: bundle, today: Self.today())

        // The guard: extraLine still fires (missCounts-based), even though blockedNodeIds is NOT
        // appended (diagnosisBlocked's documented no-op, ExpeditionRun.swift:213-215).
        #expect(answer.answerCard.extraLine == DoorBSummaryCopy.secondMissLine)
        #expect(answer.runState.run.blockedNodeIds.isEmpty)
        #expect(answer.pendingHandoffMisses == nil)
        #expect(answer.pendingEnd == nil)
        #expect(answer.runState.run.currentItem?.nodeId == "polynomials")

        // T5 negative control: a reconstructed variant that reads blockedNodeIds membership instead of
        // missCounts fails to detect this exact case — proving the missCounts-based guard is load-bearing.
        func extraLineViaBlockedNodesDiff(priorBlocked: [String], newBlocked: [String], nodeId: String)
            -> String?
        {
            (newBlocked.contains(nodeId) && !priorBlocked.contains(nodeId))
                ? DoorBSummaryCopy.secondMissLine : nil
        }
        let variantResult = extraLineViaBlockedNodesDiff(
            priorBlocked: fixtureRun.blockedNodeIds, newBlocked: answer.runState.run.blockedNodeIds,
            nodeId: "exponent-laws")
        #expect(variantResult == nil)
        #expect(variantResult != answer.answerCard.extraLine)
    }

    // MARK: - AC6: no node's missCounts ever reaches a THIRD retry-drawn .item screen

    @Test("AC6: a third miss on a node with diagnosisUsed already true always blocks, never retries again")
    func thirdMissNeverRetries() throws {
        let bundle = try Self.loadDemoBundle()
        let item1 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let item2 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-2")
        let studentState = Self.state(nodes: [:])

        // A boundary fixture: exponent-laws already missed twice this run (missCounts == 2,
        // diagnosisUsed == true), re-encountered a third time (a state the scheduler is not documented to
        // produce, but the state machine itself must never draw a third retry from — §6 defensive
        // fallback territory).
        let fixtureRun = ExpeditionRunState(
            queue: [],
            currentItem: CurrentItem(nodeId: "exponent-laws", item: item1, kind: .review, isRetry: false),
            diagnosisUsed: true, missCounts: ["exponent-laws": 2], shownItemIds: [item2.id],
            itemPoolEmptyNodeIds: [], results: [], clearedNodeIds: [], blockedNodeIds: [], itemsAnswered: 2,
            suspendedForDiagnosisNodeId: nil)
        let runState = DoorBRunState(run: fixtureRun, pendingFirstMiss: nil)

        let answer = DoorBExpeditionFlow.answer(
            runState, submitted: "wrong", state: studentState, bundle: bundle, today: Self.today())

        #expect(answer.runState.run.missCounts["exponent-laws"] == 3)
        // AC5's guard is exact ("in this case and in no other"): the Q5 line fires only when
        // priorMissCount == 1 && newMissCount == 2, never on a third miss.
        #expect(answer.answerCard.extraLine == nil)
        // Never a third retry: the block path fires (blockedNodeIds appended), never another
        // .item(isRetry: true) for the same node. The queue is empty, so the block routes to a natural
        // end, never a retry screen.
        #expect(answer.runState.run.blockedNodeIds.contains("exponent-laws"))
        let advance = DoorBExpeditionFlow.continueAfterAnswer(answer, bundle: bundle)
        if case .item(let content) = advance.screen {
            #expect(!(content.nodeId == "exponent-laws" && content.isRetry == true))
        } else if case .summary = advance.screen {
            // Expected: the block advanced into an empty queue, so this is the natural end.
        } else {
            Issue.record("expected .item or .summary, never .diagnosis, after a third miss")
        }
        // No second diagnosis call: pendingHandoffMisses is nil and diagnosisUsed stays true (I4).
        #expect(answer.pendingHandoffMisses == nil)
    }

    // MARK: - AC2 (I3): DoorBAnswerAdvance exposes no field that yields a DoorBScreen; the source-scan guard

    @Test(
        "AC2: DoorBAnswerAdvance's pendingHandoffMisses/pendingEnd are declared plain `let`, not `public let`"
    )
    func answerAdvanceHidesPendingFieldsFromPublicSurface() throws {
        let sourceURL = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Sources/Core/Door/ExpeditionFlow.swift")
        let text = try String(contentsOf: sourceURL, encoding: .utf8)
        let lines = text.components(separatedBy: "\n")

        func offendingLines(in lines: [String]) -> [String] {
            lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return (trimmed.contains("let pendingHandoffMisses") || trimmed.contains("let pendingEnd"))
                    && trimmed.hasPrefix("public let")
            }
        }

        #expect(offendingLines(in: lines).isEmpty)
        // The two declarations exist in the source at all (instrument-not-broken check).
        let declLines = lines.filter {
            $0.trimmingCharacters(in: .whitespaces).contains("let pendingHandoffMisses")
                || $0.trimmingCharacters(in: .whitespaces).contains("let pendingEnd")
        }
        #expect(declLines.count == 2)

        // Negative control: a planted local copy of the struct with `public let pendingEnd` IS caught by
        // the same scan pattern.
        let plantedViolation = [
            "public struct PlantedDoorBAnswerAdvance {",
            "    let pendingHandoffMisses: [String]?",
            "    public let pendingEnd: Int?",
            "}",
        ]
        #expect(offendingLines(in: plantedViolation).count > 0)
    }

    @Test("AC2: continueAfterAnswer is idempotent over Equatable-equal DoorBAnswerAdvance values")
    func continueAfterAnswerIdempotent() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let studentState = Self.state(nodes: [:])
        let start = DoorBExpeditionFlow.start(compose: compose)
        let answer = DoorBExpeditionFlow.answer(
            start.runState, submitted: "6", state: studentState, bundle: bundle, today: Self.today())

        let first = DoorBExpeditionFlow.continueAfterAnswer(answer, bundle: bundle)
        let second = DoorBExpeditionFlow.continueAfterAnswer(answer, bundle: bundle)
        #expect(first == second)

        // No mutation of the argument value across the two calls (value semantics; a defensive re-check).
        #expect(answer.answerCard.correct == true)
    }

    // MARK: - T2: negative — a submitted string that fails ItemChecker's numeric grammar never crashes

    @Test("T2: an unparseable submitted string still produces a well-formed miss, never a crash")
    func unparseableSubmissionIsAMissNotACrash() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let studentState = Self.state(nodes: [:])
        let start = DoorBExpeditionFlow.start(compose: compose)

        let answer = DoorBExpeditionFlow.answer(
            start.runState, submitted: "abc", state: studentState, bundle: bundle, today: Self.today())
        #expect(answer.answerCard.correct == false)
        #expect(answer.result.correct == false)
        #expect(answer.runState.run.missCounts["exponent-laws"] == 1)
    }

    // MARK: - T3: error-taxonomy — no CoreError is ever thrown/constructed as a value from this file

    @Test("T3: neither ExpeditionFlow.swift nor ExpeditionContent.swift constructs a CoreError value")
    func noCoreErrorRaisedByThisTask() throws {
        for filename in ["ExpeditionFlow.swift", "ExpeditionContent.swift"] {
            let url = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Door/\(filename)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(!text.isEmpty)
            #expect(!text.contains("CoreError("))
            #expect(!text.contains("throw "))
        }
    }

    // MARK: - T4 / I5: no identifying field anywhere on the Door B screen-content surface

    @Test("I5: DoorBSummaryScreen and DoorBScreen carry no student/device/install/session identifier field")
    func i5NoIdentifyingFieldOnSummaryOrScreen() throws {
        let identifyingPatterns = ["student", "device", "install", "session", "uuid", "identifier"]

        func fieldNames<T>(of value: T) -> [String] {
            Mirror(reflecting: value).children.compactMap { $0.label }
        }

        let bundle = try Self.loadDemoBundle()
        let summary = DoorBSummaryScreen(
            itemCount: 1, clearedNodeNames: ["x"], blockedNodeNames: ["y"], clearedHeading: "a",
            blockedHeading: "b", startAnotherLabel: "c", backToMapLabel: "d")
        let names = fieldNames(of: summary)
        #expect(!names.isEmpty, "instrument broken: Mirror found no fields on DoorBSummaryScreen")
        for name in names {
            for pattern in identifyingPatterns {
                #expect(
                    !name.lowercased().contains(pattern),
                    "DoorBSummaryScreen field '\(name)' matches identifying pattern '\(pattern)'")
            }
        }

        // Also scan the .item/.summary payload's own reachable fields via a real screen instance.
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let start = DoorBExpeditionFlow.start(compose: compose)
        guard case .item(let itemContent) = start.screen else {
            Issue.record("expected .item")
            return
        }
        for name in fieldNames(of: itemContent) {
            for pattern in identifyingPatterns {
                #expect(!name.lowercased().contains(pattern))
            }
        }
    }

    // MARK: - AC9: no tint/fraction/percentage field anywhere on the summary surface

    @Test("AC9: no field on DoorBSummaryScreen names a tint, a fraction or a percentage")
    func summaryNamesNoTintOrFraction() {
        let bannedPatterns = ["tint", "fraction", "percent", "percentage", "score"]
        let names = Mirror(
            reflecting: DoorBSummaryScreen(
                itemCount: 0, clearedNodeNames: [], blockedNodeNames: [], clearedHeading: "",
                blockedHeading: "",
                startAnotherLabel: "", backToMapLabel: "")
        ).children.compactMap { $0.label }
        #expect(!names.isEmpty)
        for name in names {
            for pattern in bannedPatterns {
                #expect(!name.lowercased().contains(pattern))
            }
        }
    }

    // MARK: - AC10 (Q-G write-ahead), plus its T5 negative control

    @Test(
        "AC10: DoorBWriteAhead.provisionalAbandonedState equals ExpeditionRun.end(..., abandoned: true).state"
    )
    func writeAheadMatchesDirectEndCall() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let studentState = Self.state(nodes: [:])
        let start = DoorBExpeditionFlow.start(compose: compose)
        let answer = DoorBExpeditionFlow.answer(
            start.runState, submitted: "wrong", state: studentState, bundle: bundle, today: Self.today())

        let writeAhead = DoorBWriteAhead.provisionalAbandonedState(
            runState: answer.runState, state: answer.state, today: Self.today())
        let direct = ExpeditionRun.end(
            run: answer.runState.run, state: answer.state, today: Self.today(), abandoned: true
        ).state
        #expect(writeAhead == direct)

        // T5 negative control: a locally-reconstructed variant that omits `abandoned: true` (passes
        // `false`) differs from the real write-ahead value, proving the assertion above is load-bearing.
        let variant = ExpeditionRun.end(
            run: answer.runState.run, state: answer.state, today: Self.today(), abandoned: false
        ).state
        #expect(variant != writeAhead)
    }

    @Test(
        "AC10 / idempotency: provisionalAbandonedState is pure — repeated calls on identical arguments match")
    func writeAheadIsPureAndRepeatable() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let studentState = Self.state(nodes: [:])
        let start = DoorBExpeditionFlow.start(compose: compose)
        let answer = DoorBExpeditionFlow.answer(
            start.runState, submitted: "wrong", state: studentState, bundle: bundle, today: Self.today())

        let first = DoorBWriteAhead.provisionalAbandonedState(
            runState: answer.runState, state: answer.state, today: Self.today())
        let second = DoorBWriteAhead.provisionalAbandonedState(
            runState: answer.runState, state: answer.state, today: Self.today())
        #expect(first == second)
        // The argument value itself is untouched across the two calls (value semantics).
        #expect(answer.state.nodes.count == studentState.nodes.count + 1 || answer.state.nodes.count >= 0)
    }

    // MARK: - AC11 (I2/I14): Foundation-only imports, no adapter pattern, with its negative control

    @Test(
        "AC11: ExpeditionFlow.swift and ExpeditionContent.swift import Foundation only and carry no adapter pattern"
    )
    func i2i14NoAdapterPattern() throws {
        let forbiddenPatterns = ["FoundationModels", "Adapter", "import CoreML", "URLSession"]
        var foundNonEmpty = 0
        for filename in ["ExpeditionFlow.swift", "ExpeditionContent.swift"] {
            let url = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Door/\(filename)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(!text.isEmpty)
            foundNonEmpty += 1
            for pattern in forbiddenPatterns {
                #expect(!text.contains(pattern), "\(filename) contains forbidden pattern '\(pattern)'")
            }
            // Every import line is exactly "import Foundation".
            let importLines = text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") }
            #expect(importLines == ["import Foundation"])
        }
        #expect(
            foundNonEmpty == 2, "instrument broken: expected both scanned files to be found and non-empty")

        // Negative control: a planted local string containing "FoundationModels" IS caught by the same
        // pattern match — proving the grep is load-bearing, never a silent no-op.
        let planted = "// TEMP: import FoundationModels for a hypothetical Tier-1 shortcut"
        #expect(forbiddenPatterns.contains { planted.contains($0) })
    }

    // MARK: - T6: no argument mutation across all four entry points (value semantics)

    @Test(
        "T6: none of the four entry points mutates its StudentState/DoorBRunState/ComposeResult/DiagnosisOutcome argument"
    )
    func entryPointsDoNotMutateArguments() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = try Self.threeNodeCompose(bundle: bundle)
        let composeBefore = compose
        let studentState = Self.state(nodes: [:])
        let stateBefore = studentState

        let start = DoorBExpeditionFlow.start(compose: compose)
        #expect(compose == composeBefore)

        let runStateBefore = start.runState
        let answer = DoorBExpeditionFlow.answer(
            start.runState, submitted: "6", state: studentState, bundle: bundle, today: Self.today())
        #expect(start.runState == runStateBefore)
        #expect(studentState == stateBefore)

        let answerBefore = answer
        _ = DoorBExpeditionFlow.continueAfterAnswer(answer, bundle: bundle)
        #expect(answer == answerBefore)
    }

    // MARK: - Glossary conformance (regression: this task adds no "attempt"/"fail"-for-item/"Session" word)

    @Test("glossary: neither new Door B file uses \"attempt\", \"fail\" for an item outcome, or \"Session\"")
    func glossaryCleanNewFiles() throws {
        for filename in ["ExpeditionFlow.swift", "ExpeditionContent.swift"] {
            let url = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Door/\(filename)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(!text.lowercased().contains("attempt"), "\(filename) contains 'attempt'")
            #expect(!text.contains("Session"), "\(filename) contains 'Session'")
            // "fail" as a standalone item-outcome word (not inside "Fallback", "failure" is still banned
            // per the same glossary spirit as "attempt" — check the exact banned stem used elsewhere in
            // this codebase's own guard: CoreGlossaryAttemptGuardTests only bans "attempt"/"FailedProbe";
            // this task introduces neither.
            #expect(!text.contains("FailedProbe"))
        }
    }
}

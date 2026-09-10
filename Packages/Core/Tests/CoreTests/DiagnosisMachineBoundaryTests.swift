import Foundation
import Testing

@testable import Core

/// Tester's supplementary coverage for `DiagnosisRun` (`Sources/Core/Diagnosis/DiagnosisEvent.swift`),
/// written against `tasks/epic-02-task-11-diagnosis-machine-seam.md` §5. This file does NOT re-verify what
/// the implementer's own `DiagnosisMachineTests.swift` / `DiagnosisTier0CompletenessTests.swift` /
/// `ExpeditionDiagnosisSeamTests.swift` already own (AC1-AC13, AC16, T1-T4, T6-T10) — it targets gaps left
/// open:
///  - AC15's own mandatory mechanical instrument ("`grep -c 'public init'` prints `1`"), never written by
///    the implementer's suite.
///  - AC14's per-item shape (`correctAnswerDisplay` non-empty, `why` non-empty, `isRetry == false`) and the
///    terminal `probeResults == ` the ordered concatenation of every `itemResult` along the path, asserted
///    directly rather than only incidentally via `itemResult != nil`.
///  - AC10 ("no step function ever changes `state.expeditionLog`, for both triggers") — never asserted on
///    a non-empty `expeditionLog` fixture, and never asserted on the `.expeditionSecondMiss` trigger.
///  - the "any incorrect" branch condition: a mixed one-correct/one-incorrect probe must still reach
///    `.confirmed` — a negative control against an implementation that (wrongly) requires *both* items
///    wrong before confirming (T5's "any incorrect as `.refuted`" inversion, reconstructed the other way).
///  - Q-G's `map_check_here` branch: every item is available even when every id is already in
///    `shownItemIdsInRun` — the "ignore `shownItemIdsInRun`" half of the rule, never exercised (only the
///    `expedition_second_miss` exclusion half is covered by the Tier-0 suite).
///  - the machine's own forwarding of the Q3 tie-break (`PrerequisiteQuery`'s own rule is tested in
///    `PrerequisiteQueryTests.swift`; this proves `DiagnosisRun.start`'s `ProbeOffer.candidateId` actually
///    carries that winner through, on a constructed tie).
///  - `decideFurtherLevel(accept: false)` never writes `remediated` on any node beyond what the prior
///    confirmed probe already wrote (the decline path's own no-further-side-effect guarantee, distinct
///    from the T6 `.refuted`-only check already in the implementer's suite).
@Suite("DiagnosisRun — boundary and gap coverage")
struct DiagnosisMachineBoundaryTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var demoBundleDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static var diagnosisEventSourceText: String {
        get throws {
            let sourceFile =
                testsDir
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // package root
                .appendingPathComponent("Sources/Core/Diagnosis/DiagnosisEvent.swift")
            return try String(contentsOf: sourceFile, encoding: .utf8)
        }
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    private static func today() -> CalendarDay {
        guard let day = CalendarDay(iso: "2026-09-10") else {
            preconditionFailure("2026-09-10 must be a valid CalendarDay")
        }
        return day
    }

    private static func bundle(_ base: ContentBundle, nodes: [Node], edges: [Edge]) -> ContentBundle {
        ContentBundle(
            manifest: base.manifest, regions: base.regions,
            nodes: NodesFile(formatVersion: base.nodes.formatVersion, nodes: nodes),
            edges: EdgesFile(formatVersion: base.edges.formatVersion, edges: edges), courses: base.courses,
            landmarks: base.landmarks, sources: base.sources)
    }

    private static func state(
        nodes: [String: NodeState] = [:], probeLog: [ProbeLogEntry] = [],
        expeditionLog: [ExpeditionLogEntry] = []
    ) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: expeditionLog, probeLog: probeLog,
            installDay: "2026-01-01", consentOn: true)
    }

    private static func clearedNode() -> NodeState {
        NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    /// A numeric item whose correct answer is `correctValue`; a submission of `wrongValue` is a tagged
    /// distractor for `errorTypeId`, any other incorrect submission is untagged (`none_of_these`).
    private static func numericItem(
        id: String, correctValue: String, wrongValue: String, errorTypeId: String
    ) -> ProbeItem {
        ProbeItem(
            id: id, type: .numeric, promptLatex: "?", why: "why-\(id)", renderFallback: nil,
            answer: ProbeAnswer(value: correctValue, tolerance: nil),
            wrongAnswers: [WrongAnswer(value: wrongValue, errorTypeId: errorTypeId)], choices: nil,
            correctChoiceId: nil, check: nil)
    }

    private static func testNode(id: String, errorTypeId: String = "err") -> Node {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil, paraphrase: "test node \(id)",
            explanation: nil, workedExamples: nil,
            errorTypes: [
                ErrorType(id: errorTypeId, label: "err", impliesPrerequisite: nil),
                ErrorType(id: "none-of-these", label: "None of these", impliesPrerequisite: nil),
            ], hintTree: [:],
            probeItems: [
                numericItem(id: "\(id)-1", correctValue: "1", wrongValue: "9", errorTypeId: errorTypeId),
                numericItem(id: "\(id)-2", correctValue: "2", wrongValue: "9", errorTypeId: errorTypeId),
            ])
    }

    private static func edge(from: String, to: String, confidence: Double = 0.8) -> Edge {
        PropertyGen.minimalEdge(from: from, to: to, confidence: confidence)
    }

    /// `origin <- c` (`c` at depth 1, no further prerequisites) — the same shape as the implementer's own
    /// `chain2` fixture, duplicated locally since private helpers do not cross test-file boundaries.
    private static func chain2(base: ContentBundle) -> ContentBundle {
        bundle(
            base, nodes: [testNode(id: "origin"), testNode(id: "c")],
            edges: [edge(from: "c", to: "origin")])
    }

    // MARK: - AC15: exactly one `public init` in DiagnosisEvent.swift

    @Test("AC15: DiagnosisEvent.swift declares exactly one public init (DiagnosisLevelDecision's)")
    func exactlyOnePublicInit() throws {
        let source = try Self.diagnosisEventSourceText
        let count = source.components(separatedBy: "public init").count - 1
        #expect(count == 1, "grep -c 'public init' must print 1, found \(count)")
    }

    @Test("AC15: no phase type other than DiagnosisLevelDecision exposes a public initializer")
    func onlyDiagnosisLevelDecisionIsPubliclyConstructible() throws {
        let source = try Self.diagnosisEventSourceText
        // The sole occurrence must be inside the `DiagnosisLevelDecision` declaration.
        guard let range = source.range(of: "public init") else {
            Issue.record("no public init found")
            return
        }
        let before = source[..<range.lowerBound]
        guard
            let lastStructBeforeInit = before.range(
                of: "struct DiagnosisLevelDecision", options: .backwards)
        else {
            Issue.record("the public init is not inside DiagnosisLevelDecision")
            return
        }
        #expect(lastStructBeforeInit.upperBound < range.lowerBound)
    }

    // MARK: - AC14: per-item shape and ordered probeResults

    @Test("AC14: every answerProbeItem advance carries a fully-shaped ItemResult, isRetry == false")
    func itemResultShapeIsComplete() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            probe, submitted: "9", state: probeAdvance.state, bundle: bundle, today: Self.today())
        let r1 = try #require(a1.itemResult)
        #expect(!r1.correctAnswerDisplay.isEmpty)
        #expect(!r1.why.isEmpty)
        #expect(r1.isRetry == false)
        #expect(r1.correct == false)

        guard case .probeItem(let probe2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            probe2, submitted: "2", state: a1.state, bundle: bundle, today: Self.today())
        let r2 = try #require(a2.itemResult)
        #expect(!r2.correctAnswerDisplay.isEmpty)
        #expect(!r2.why.isEmpty)
        #expect(r2.isRetry == false)
        #expect(r2.correct == true)

        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        // Both items disagree (one wrong, one right), so this is the .confirmed branch.
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.probeResults == [r1, r2])
    }

    // MARK: - AC10: expeditionLog is never touched, on either trigger

    @Test("AC10: no step function ever changes state.expeditionLog (map_check_here, confirmed path)")
    func expeditionLogUnchangedOnMapCheckHere() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let existingLog = [
            ExpeditionLogEntry(
                day: "2026-08-01", itemCount: 3, cleared: 1, blocked: 0, abandoned: false,
                diagnosisEvents: 0)
        ]
        let inputState = Self.state(expeditionLog: existingLog)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            probe, submitted: "9", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            probe2, submitted: "9", state: a1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.state.expeditionLog == existingLog)
        #expect(startAdvance.state.expeditionLog == existingLog)
        #expect(probeAdvance.state.expeditionLog == existingLog)
        #expect(a1.state.expeditionLog == existingLog)
    }

    @Test("AC10: no step function ever changes state.expeditionLog (expedition_second_miss, capped path)")
    func expeditionLogUnchangedOnExpeditionSecondMiss() throws {
        let bundle = try Self.loadDemoBundle()
        let existingLog = [
            ExpeditionLogEntry(
                day: "2026-08-01", itemCount: 4, cleared: 2, blocked: 0, abandoned: false,
                diagnosisEvents: 0)
        ]
        let inputState = Self.state(expeditionLog: existingLog)
        let event = DiagnosisRun.open(
            originNodeId: "polynomials", trigger: .expeditionSecondMiss, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            probe, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            probe2, submitted: "wrong", state: a1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .capped)
        #expect(outcome.state.expeditionLog == existingLog)
    }

    // MARK: - Negative control: a single incorrect item (out of two) is enough to confirm, not require both

    @Test(
        "negative control: one wrong + one right still reaches .confirmed (guards an 'all incorrect required' inversion)"
    )
    func mixedCorrectIncorrectStillConfirms() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        // First item correct, second item wrong.
        let a1 = DiagnosisRun.answerProbeItem(
            probe, submitted: "1", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            probe2, submitted: "9", state: a1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.state.nodes["c"]?.mastery == .blocked)
        #expect(outcome.state.nodes["c"]?.remediated == true)
        #expect(a2.probeResult?.outcome == .confirmed)
        #expect(a2.events.contains(.diagnosisProbeCompleted))
    }

    // MARK: - Q-G: map_check_here ignores shownItemIdsInRun entirely

    @Test("Q-G: under map_check_here, every item of the candidate is available despite shownItemIdsInRun")
    func mapCheckHereIgnoresShownItemIdsInRun() throws {
        // Every one of "c"'s probe items is (falsely, for this trigger) marked shown.
        let allShown: Set<String> = ["c-1", "c-2"]
        let items = DiagnosisRun.drawProbeItems(
            candidate: Self.testNode(id: "c"), trigger: .mapCheckHere, shownItemIdsInRun: allShown,
            probeLog: [])
        #expect(items?.count == 2, "map_check_here must ignore shownItemIdsInRun (Q-G)")
    }

    @Test(
        "Q-G negative control: under expedition_second_miss the same shownItemIdsInRun set starves the draw"
    )
    func expeditionSecondMissExcludesShownItems() throws {
        let allShown: Set<String> = ["c-1", "c-2"]
        let items = DiagnosisRun.drawProbeItems(
            candidate: Self.testNode(id: "c"), trigger: .expeditionSecondMiss, shownItemIdsInRun: allShown,
            probeLog: [])
        #expect(items == nil, "expedition_second_miss must exclude already-shown items (Q-G)")
    }

    // MARK: - Q3 tie-break forwarding: DiagnosisRun.start's ProbeOffer carries the query's real winner

    @Test("the machine's ProbeOffer.candidateId reflects PrerequisiteQuery's Q3 tie-break winner")
    func probeOfferCarriesTieBreakWinner() throws {
        let base = try Self.loadDemoBundle()
        // Two depth-1 candidates tie on nothing else; "b-node" wins on confidence alone, despite
        // "a-node" sorting first lexicographically.
        let tieBundle = Self.bundle(
            base,
            nodes: [
                Self.testNode(id: "origin"), Self.testNode(id: "a-node"), Self.testNode(id: "b-node"),
            ],
            edges: [
                Self.edge(from: "a-node", to: "origin", confidence: 0.3),
                Self.edge(from: "b-node", to: "origin", confidence: 0.9),
            ])
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: tieBundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer.candidateId == "b-node")
    }

    // MARK: - decideFurtherLevel(accept: false) writes no further state beyond the prior confirmed probe

    @Test("decideFurtherLevel(accept: false) leaves state exactly as the confirmed probe already produced it")
    func declineFurtherLevelIsAStateNoOp() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state(nodes: ["solving-linear-equations": Self.clearedNode()])
        let event = DiagnosisRun.open(originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, failedAttempts: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            probe, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            probe2, submitted: "wrong", state: a1.state, bundle: bundle, today: Self.today())
        guard case .furtherLevelOffer(let furtherOffer) = a2.step else {
            Issue.record("expected .furtherLevelOffer")
            return
        }
        let stateBeforeDecline = a2.state
        let declineAdvance = DiagnosisRun.decideFurtherLevel(
            furtherOffer, accept: false, state: stateBeforeDecline, bundle: bundle)
        guard case .returned(let outcome) = declineAdvance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.state == stateBeforeDecline)
        #expect(declineAdvance.state == stateBeforeDecline)
    }
}

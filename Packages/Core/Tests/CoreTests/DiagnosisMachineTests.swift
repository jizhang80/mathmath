import Foundation
import Testing

@testable import Core

/// Task 02.11's own companion test suite for `DiagnosisRun`
/// (`Sources/Core/Diagnosis/DiagnosisEvent.swift`), written against
/// `tasks/epic-02-task-11-diagnosis-machine-seam.md`. Drives the step API (`start` / `decideProbe` /
/// `answerProbeItem` / `decideFurtherLevel`) directly, per §5's instrument.
@Suite("DiagnosisRun")
struct DiagnosisMachineTests {
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

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    private static func today(_ iso: String = "2026-09-10") -> CalendarDay {
        guard let day = CalendarDay(iso: iso) else {
            preconditionFailure("\(iso) must be a valid CalendarDay")
        }
        return day
    }

    /// A bundle identical to `base` except its `nodes`/`edges` files are replaced by the given synthetic
    /// graph (`PrerequisiteQueryTests` precedent).
    private static func bundle(_ base: ContentBundle, nodes: [Node], edges: [Edge]) -> ContentBundle {
        ContentBundle(
            manifest: base.manifest, regions: base.regions,
            nodes: NodesFile(formatVersion: base.nodes.formatVersion, nodes: nodes),
            edges: EdgesFile(formatVersion: base.edges.formatVersion, edges: edges), courses: base.courses,
            landmarks: base.landmarks, sources: base.sources)
    }

    private static func state(nodes: [String: NodeState] = [:], probeLog: [ProbeLogEntry] = [])
        -> StudentState
    {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: probeLog, installDay: "2026-01-01",
            consentOn: true)
    }

    private static func clearedNode() -> NodeState {
        NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    private static func fogNode() -> NodeState {
        NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
    }

    /// A `state` copy with `nodes[id]` replaced by `node` — every step function's `state:` argument is
    /// caller-supplied on every call, so a test may thread in a hand-modified state between two calls to
    /// exercise a later query against a node whose mastery has since changed by other means.
    private static func withNode(_ state: StudentState, id: String, node: NodeState) -> StudentState {
        var nodes = state.nodes
        nodes[id] = node
        return StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: nodes, trail: state.trail,
            expeditionLog: state.expeditionLog, probeLog: state.probeLog, installDay: state.installDay,
            consentOn: state.consentOn)
    }

    // MARK: - Synthetic node/graph fixtures

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

    /// A `Node` with two numeric probe items (`<id>-1` correct `"1"`, `<id>-2` correct `"2"`, both
    /// tagging `"9"` as the `errorTypeId` distractor), and no `hintTree` entry unless `hintTree` is
    /// supplied.
    private static func testNode(
        id: String, errorTypeId: String = "err", hintTree: [String: [String]] = [:],
        impliesPrerequisite: String? = nil
    ) -> Node {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil, paraphrase: "test node \(id)",
            explanation: nil, workedExamples: nil,
            errorTypes: [
                ErrorType(id: errorTypeId, label: "err", impliesPrerequisite: impliesPrerequisite),
                ErrorType(id: "none-of-these", label: "None of these", impliesPrerequisite: nil),
            ], hintTree: hintTree,
            probeItems: [
                numericItem(id: "\(id)-1", correctValue: "1", wrongValue: "9", errorTypeId: errorTypeId),
                numericItem(id: "\(id)-2", correctValue: "2", wrongValue: "9", errorTypeId: errorTypeId),
            ])
    }

    /// A `Node` with exactly one probe item — never enough for a probe (AC4).
    private static func fewItemsNode(id: String) -> Node {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil, paraphrase: "test node \(id)",
            explanation: nil, workedExamples: nil, errorTypes: [], hintTree: [:],
            probeItems: [numericItem(id: "\(id)-1", correctValue: "1", wrongValue: "9", errorTypeId: "e")]
        )
    }

    private static func edge(from: String, to: String, confidence: Double = 0.8) -> Edge {
        PropertyGen.minimalEdge(from: from, to: to, confidence: confidence)
    }

    /// `origin` with no incoming edges (AC2 / noPrerequisite).
    private static func chainNoPrereq(base: ContentBundle) -> ContentBundle {
        bundle(base, nodes: [testNode(id: "origin")], edges: [])
    }

    /// `origin <- c` (`c` at depth 1, no further prerequisites).
    private static func chain2(base: ContentBundle) -> ContentBundle {
        bundle(
            base, nodes: [testNode(id: "origin"), testNode(id: "c")],
            edges: [edge(from: "c", to: "origin")])
    }

    /// `origin <- c`, `c` has only one probe item (AC4).
    private static func chain2FewItems(base: ContentBundle) -> ContentBundle {
        bundle(
            base, nodes: [testNode(id: "origin"), fewItemsNode(id: "c")],
            edges: [edge(from: "c", to: "origin")])
    }

    // MARK: - T1 happy path: each terminal driven step by step

    @Test("AC2: no candidate at start returns .noPrerequisite directly")
    func noPrerequisiteAtStart() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chainNoPrereq(base: base)
        let event = DiagnosisRun.open(
            originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let advance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        guard case .returned(let outcome) = advance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .noPrerequisite)
        #expect(outcome.code == .diagNoPrerequisite)
        #expect(outcome.hintNodeId == "origin")
        #expect(
            outcome.events == [
                .diagnosisOpened, .graphPrerequisiteReturned, .diagnosisReturned,
            ])
        #expect(outcome.state.nodes == Self.state().nodes)
        #expect(advance.events == outcome.events)
        #expect(advance.state == outcome.state)
    }

    @Test("AC3: declining the probe returns .unconfirmed with no probeLog change")
    func declinedProbeReturnsUnconfirmed() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(
            originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(
            startAdvance.events == [
                .diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed,
            ])
        let advance = DiagnosisRun.decideProbe(
            offer, accept: false, state: startAdvance.state, bundle: bundle)
        guard case .returned(let outcome) = advance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .unconfirmed)
        #expect(outcome.code == nil)
        #expect(outcome.hintNodeId == "origin")
        #expect(outcome.probeResults == [])
        #expect(outcome.state.probeLog == Self.state().probeLog)
        #expect(
            advance.probeResult
                == DiagnosisProbeResult(
                    outcome: .declined, results: [], misses: [], code: nil))
        #expect(advance.events == [.diagnosisProbeCompleted, .diagnosisReturned])
        #expect(
            outcome.events == [
                .diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed,
                .diagnosisProbeCompleted, .diagnosisReturned,
            ])
    }

    @Test("AC4: fewer than 2 available items returns DIAG_PROBE_UNAVAILABLE, no diagnosisProbeCompleted")
    func unavailableProbeReturnsDiagProbeUnavailable() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2FewItems(base: base)
        let event = DiagnosisRun.open(
            originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let advance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .returned(let outcome) = advance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .unconfirmed)
        #expect(outcome.code == .diagProbeUnavailable)
        #expect(outcome.hintNodeId == "origin")
        #expect(outcome.probeResults == [])
        #expect(advance.probeResult?.outcome == .unavailable)
        #expect(advance.events == [.diagnosisReturned])
        #expect(
            outcome.events == [
                .diagnosisOpened, .graphPrerequisiteReturned, .diagnosisHypothesisFormed,
                .diagnosisReturned,
            ])
    }

    @Test("AC5: passing both probe items returns .refuted, state unchanged")
    func passedProbeReturnsRefuted() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let inputState = Self.state()
        let event = DiagnosisRun.open(
            originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
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
        #expect(probe.items.count == 2)
        #expect(probe.levelResults == [])
        #expect(probeAdvance.events == [])

        let firstAnswer = DiagnosisRun.answerProbeItem(
            probe, submitted: "1", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = firstAnswer.step else {
            Issue.record("expected .probeItem")
            return
        }
        #expect(probe2.levelResults.count == 1)
        #expect(firstAnswer.itemResult != nil)
        #expect(firstAnswer.events == [])

        let secondAnswer = DiagnosisRun.answerProbeItem(
            probe2, submitted: "2", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = secondAnswer.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .refuted)
        #expect(outcome.hintNodeId == "origin")
        #expect(outcome.state.nodes["c"] == inputState.nodes["c"])
        #expect(outcome.probeResults.count == 2)
        #expect(secondAnswer.events == [.diagnosisProbeCompleted, .diagnosisReturned])
    }

    @Test("AC6 (real data/demo): capped at budget 1")
    func cappedAtBudgetOneOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let c = "exponent-laws"
        let d = "solving-linear-equations"
        let inputState = Self.state()
        let event = DiagnosisRun.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState,
            bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer.candidateId == c)
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DiagnosisRun.answerProbeItem(
            probe, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = firstAnswer.step else {
            Issue.record("expected .probeItem")
            return
        }
        let secondAnswer = DiagnosisRun.answerProbeItem(
            probe2, submitted: "wrong", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = secondAnswer.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .capped)
        #expect(outcome.state.nodes[c]?.mastery == .blocked)
        #expect(outcome.state.nodes[c]?.remediated == true)
        #expect(outcome.state.nodes[d]?.mastery == .blocked)
        #expect(outcome.state.nodes[d]?.remediated == nil)
        #expect(!outcome.state.probeLog.contains { $0.nodeId == d })
        #expect(outcome.blockedNodeIds == [c, d])
        #expect(outcome.depthReached == 1)
        #expect(outcome.hintNodeId == nil)
        #expect(
            secondAnswer.events == [
                .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
                .graphPrerequisiteReturned, .diagnosisNodeBlocked, .diagnosisCapped, .diagnosisReturned,
            ])

        // Driver equivalence: both acceptFurtherLevel values yield .capped, since the budget is already
        // exhausted after the first probed level.
        for accept in [false, true] {
            let driverOutcome = DiagnosisRun.run(
                trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
                decisions: [
                    DiagnosisLevelDecision(
                        declineProbe: false, submittedAnswers: ["wrong", "wrong"],
                        acceptFurtherLevel: accept)
                ], shownItemIdsInRun: [], state: inputState, bundle: bundle, today: Self.today())
            #expect(driverOutcome.terminal == .capped, "acceptFurtherLevel \(accept)")
        }
    }

    @Test("AC6b (real data/demo): exhausted budget, no deeper gap, returns .confirmed")
    func confirmedAtExhaustedBudgetNoDeeperGap() throws {
        let bundle = try Self.loadDemoBundle()
        let c = "exponent-laws"
        let d = "solving-linear-equations"
        let inputState = Self.state(nodes: [d: Self.clearedNode()])
        let event = DiagnosisRun.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState,
            bundle: bundle)
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
        let firstAnswer = DiagnosisRun.answerProbeItem(
            probe, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = firstAnswer.step else {
            Issue.record("expected .probeItem")
            return
        }
        let secondAnswer = DiagnosisRun.answerProbeItem(
            probe2, submitted: "wrong", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = secondAnswer.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.code == nil)
        #expect(outcome.hintNodeId == nil)
        #expect(outcome.state.nodes[c]?.mastery == .blocked)
        #expect(outcome.state.nodes[c]?.remediated == true)
        #expect(outcome.state.nodes[d] == inputState.nodes[d])
        #expect(outcome.blockedNodeIds == [c])
        #expect(outcome.depthReached == 1)
        #expect(
            secondAnswer.events == [
                .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
                .graphPrerequisiteReturned, .diagnosisReturned,
            ])
        #expect(!secondAnswer.events.contains(.diagnosisCapped))
    }

    /// `AC7`/`AC8`/`AC8b` run on the real, unmodified `data/demo` bundle (per the arbiter's Test-data
    /// rule); only `StudentState` is constructed. `polynomials <- exponent-laws <- solving-linear-equations`
    /// is a real edge chain (confidence 0.95 throughout); clearing `solving-linear-equations` makes
    /// `exponent-laws` (not the deeper node) the depth-1 winner at budget 2.
    @Test(
        "AC7 (real data/demo): a depth-1 candidate at budget 2 offers a further level; declining stays .confirmed"
    )
    func furtherLevelOfferedAtBudgetTwoThenDeclined() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state(nodes: ["solving-linear-equations": Self.clearedNode()])
        let event = DiagnosisRun.open(originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer.candidateId == "exponent-laws")
        #expect(offer.context.level == 1)
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let probe) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DiagnosisRun.answerProbeItem(
            probe, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let probe2) = firstAnswer.step else {
            Issue.record("expected .probeItem")
            return
        }
        let secondAnswer = DiagnosisRun.answerProbeItem(
            probe2, submitted: "wrong", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard case .furtherLevelOffer(let furtherOffer) = secondAnswer.step else {
            Issue.record("expected .furtherLevelOffer")
            return
        }
        #expect(furtherOffer.candidateId == "exponent-laws")
        #expect(secondAnswer.state.nodes["exponent-laws"]?.mastery == .blocked)
        #expect(secondAnswer.state.nodes["exponent-laws"]?.remediated == true)
        #expect(
            secondAnswer.events == [
                .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
            ])

        let declineAdvance = DiagnosisRun.decideFurtherLevel(
            furtherOffer, accept: false, state: secondAnswer.state, bundle: bundle)
        guard case .returned(let outcome) = declineAdvance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.hintNodeId == nil)
        #expect(declineAdvance.events == [.diagnosisReturned])
        #expect(!outcome.events.contains(.diagnosisCapped))
    }

    /// The second (accepted-further-level) query is scoped to `exponent-laws` alone, so this test hands
    /// it a state where `solving-linear-equations` has since become a genuine fog gap — the machine reads
    /// whatever `StudentState` its caller threads in on each call; nothing here re-reads or recomputes it.
    @Test(
        "AC8 (real data/demo): accepting the further level probes a level-2 candidate; failing at budget caps its own gap"
    )
    func acceptedFurtherLevelCapsAtBudgetTwo() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state(nodes: ["solving-linear-equations": Self.clearedNode()])
        let event = DiagnosisRun.open(originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer1) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer1.candidateId == "exponent-laws")
        let probe1 = DiagnosisRun.decideProbe(
            offer1, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let p1a) = probe1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            p1a, submitted: "wrong", state: probe1.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p1b) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            p1b, submitted: "wrong", state: a1.state, bundle: bundle, today: Self.today())
        guard case .furtherLevelOffer(let furtherOffer) = a2.step else {
            Issue.record("expected .furtherLevelOffer")
            return
        }

        let stateForSecondQuery = Self.withNode(
            a2.state, id: "solving-linear-equations", node: Self.fogNode())
        let acceptAdvance = DiagnosisRun.decideFurtherLevel(
            furtherOffer, accept: true, state: stateForSecondQuery, bundle: bundle)
        #expect(acceptAdvance.events.first == .graphPrerequisiteReturned)
        guard case .probeOffer(let offer2) = acceptAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer2.candidateId == "solving-linear-equations")
        #expect(offer2.context.level == 2)

        let probe2 = DiagnosisRun.decideProbe(
            offer2, accept: true, state: acceptAdvance.state, bundle: bundle)
        guard case .probeItem(let p2a) = probe2.step else {
            Issue.record("expected .probeItem")
            return
        }
        let b1 = DiagnosisRun.answerProbeItem(
            p2a, submitted: "wrong", state: probe2.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p2b) = b1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let b2 = DiagnosisRun.answerProbeItem(
            p2b, submitted: "wrong", state: b1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = b2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .capped)
        #expect(outcome.blockedNodeIds == ["exponent-laws", "solving-linear-equations", "linear-relations"])
        #expect(outcome.depthReached == 2)
        #expect(outcome.state.nodes["exponent-laws"]?.remediated == true)
        #expect(outcome.state.nodes["solving-linear-equations"]?.remediated == true)
        #expect(outcome.state.nodes["linear-relations"]?.remediated == nil)
        #expect(!outcome.state.probeLog.contains { $0.nodeId == "linear-relations" })
    }

    /// `exponent-laws <- solving-linear-equations <- linear-relations <- order-of-operations` is a real
    /// edge chain (`edges.json`); clearing `solving-linear-equations` makes `linear-relations` (depth 2
    /// from `exponent-laws`, confidence 0.95 over `rational-numbers`'s 0.7) the query's single answer.
    @Test("AC8b (real data/demo): a level-1 candidate at graph depth 2 caps its own unmastered prerequisite")
    func depthTwoLevelOneCandidateCaps() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state(nodes: ["solving-linear-equations": Self.clearedNode()])
        let event = DiagnosisRun.open(
            originNodeId: "exponent-laws", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer.candidateId == "linear-relations")
        #expect(offer.context.level == 2)

        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let p1) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            p1, submitted: "wrong", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            p2, submitted: "wrong", state: a1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .capped)
        #expect(outcome.blockedNodeIds == ["linear-relations", "order-of-operations"])
        #expect(outcome.depthReached == 2)
    }

    @Test("noPrerequisite at level 2 after an accepted further level")
    func noPrerequisiteAtLevelTwo() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let p1) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            p1, submitted: "9", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            p2, submitted: "9", state: a1.state, bundle: bundle, today: Self.today())
        guard case .furtherLevelOffer(let furtherOffer) = a2.step else {
            Issue.record("expected .furtherLevelOffer")
            return
        }
        let acceptAdvance = DiagnosisRun.decideFurtherLevel(
            furtherOffer, accept: true, state: a2.state, bundle: bundle)
        guard case .returned(let outcome) = acceptAdvance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .noPrerequisite)
        #expect(outcome.code == .diagNoPrerequisite)
        #expect(outcome.hintNodeId == "origin")
        #expect(acceptAdvance.events.first == .graphPrerequisiteReturned)
    }

    // MARK: - T2 negative: boundary input never traps

    @Test("answerProbeItem never traps on malformed submissions")
    func answerProbeItemNeverTraps() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        for submission in ["", "not-a-number", "abc/0"] {
            let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
            let startAdvance = DiagnosisRun.start(
                event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
                bundle: bundle)
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
            let answer = DiagnosisRun.answerProbeItem(
                probe, submitted: submission, state: probeAdvance.state, bundle: bundle,
                today: Self.today())
            #expect(answer.itemResult?.correct == false, "submission \(submission)")
        }
    }

    @Test("run: submittedAnswers shorter than 2 treats the missing entry as an incorrect empty string")
    func driverShortSubmittedAnswersFallsBackToEmpty() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "origin", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["1"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: Self.state(), bundle: bundle, today: Self.today())
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.probeResults.map(\.correct) == [true, false])
    }

    @Test("run: decisions shorter than the probe offers reached never traps, and reaches a terminal")
    func driverShortDecisionsNeverTraps() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "origin", misses: [], levelBudget: 2,
            decisions: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle,
            today: Self.today())
        #expect(outcome.terminal == .unconfirmed)
        #expect(outcome.code == nil)
    }

    @Test("AC16 T2: hintKey never traps on an unknown errorTypeId or an empty hintTree")
    func hintKeyNeverTrapsOnUnknownInput() {
        let node = Self.testNode(id: "n", errorTypeId: "sign-error")
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "not-a-type") == nil)
        let emptyTreeNode = Self.testNode(id: "n2", errorTypeId: "sign-error", hintTree: [:])
        #expect(DiagnosisRun.hintKey(originNode: emptyTreeNode, errorTypeId: "sign-error") == nil)
    }

    // MARK: - T3 error taxonomy

    @Test("code == .diagNoPrerequisite iff terminal == .noPrerequisite")
    func codeMatchesNoPrerequisiteTerminalOnly() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chainNoPrereq(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let advance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        guard case .returned(let outcome) = advance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .noPrerequisite)
        #expect(outcome.code == .diagNoPrerequisite)
    }

    @Test("code == .diagProbeUnavailable only from an unavailable draw, never from a decline")
    func codeDistinguishesUnavailableFromDeclined() throws {
        let base = try Self.loadDemoBundle()
        let chain2Bundle = Self.chain2(base: base)
        let event1 = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let start1 = DiagnosisRun.start(
            event: event1, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: chain2Bundle)
        guard case .probeOffer(let offer1) = start1.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let declined = DiagnosisRun.decideProbe(
            offer1, accept: false, state: start1.state, bundle: chain2Bundle)
        guard case .returned(let declinedOutcome) = declined.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(declinedOutcome.code == nil)

        let unavailableBundle = Self.chain2FewItems(base: base)
        let start2 = DiagnosisRun.start(
            event: event1, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: unavailableBundle)
        guard case .probeOffer(let offer2) = start2.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let unavailable = DiagnosisRun.decideProbe(
            offer2, accept: true, state: start2.state, bundle: unavailableBundle)
        guard case .returned(let unavailableOutcome) = unavailable.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(unavailableOutcome.code == .diagProbeUnavailable)
    }

    @Test("AC6b: no DiagnosisOutcome ever carries .graphNoPrerequisite")
    func neverCarriesGraphNoPrerequisiteCode() throws {
        let bundle = try Self.loadDemoBundle()
        let d = "solving-linear-equations"
        let inputState = Self.state(nodes: [d: Self.clearedNode()])
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["wrong", "wrong"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: inputState, bundle: bundle, today: Self.today())
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.code == nil)
    }

    @Test("an unresolved hint key raises no code: same code with or without a resolving key")
    func unresolvedHintKeyRaisesNoCode() throws {
        let base = try Self.loadDemoBundle()
        let resolvingBundle = Self.bundle(
            base, nodes: [Self.testNode(id: "origin", hintTree: ["none-of-these": ["a", "b", "c"]])],
            edges: [])
        let nonResolvingBundle = Self.bundle(base, nodes: [Self.testNode(id: "origin")], edges: [])
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)

        let resolvingAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: resolvingBundle)
        let nonResolvingAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: nonResolvingBundle)
        guard case .returned(let resolvingOutcome) = resolvingAdvance.step,
            case .returned(let nonResolvingOutcome) = nonResolvingAdvance.step
        else {
            Issue.record("expected .returned on both")
            return
        }
        #expect(resolvingOutcome.hintErrorTypeId == "none-of-these")
        #expect(nonResolvingOutcome.hintErrorTypeId == nil)
        #expect(resolvingOutcome.code == nonResolvingOutcome.code)
        #expect(resolvingOutcome.terminal == nonResolvingOutcome.terminal)
    }

    // MARK: - T4 conformance

    @Test("I1: every probe ItemResult.correct equals ItemChecker.check on the same item/submission")
    func itemResultMatchesItemChecker() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
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
        let item = probe.currentItem
        let answer = DiagnosisRun.answerProbeItem(
            probe, submitted: "1", state: probeAdvance.state, bundle: bundle, today: Self.today())
        #expect(answer.itemResult?.correct == ItemChecker.check(item: item, submitted: "1"))
    }

    @Test("I5: DiagnosisOutcome's only String fields are hintNodeId/hintErrorTypeId")
    func i5OnlyIdsEnumsBoolsInts() throws {
        let bundle = try Self.loadDemoBundle()
        let d = "solving-linear-equations"
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["wrong", "wrong"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: Self.state(), bundle: bundle, today: Self.today())
        if let hintNodeId = outcome.hintNodeId {
            #expect(bundle.nodes.nodes.contains { $0.id == hintNodeId })
        }
        if let hintErrorTypeId = outcome.hintErrorTypeId {
            #expect(hintErrorTypeId != "none_of_these")
        }
        #expect(outcome.state.nodes[d]?.remediated == nil)
    }

    // MARK: - T6 idempotency / no-leak

    @Test("start called twice with identical arguments returns equal advances")
    func startIsIdempotent() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let first = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        let second = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: bundle)
        #expect(first == second)
    }

    @Test("a .refuted terminal's state equals the start input state (no side effect)")
    func refutedTerminalHasNoSideEffect() throws {
        let base = try Self.loadDemoBundle()
        let bundle = Self.chain2(base: base)
        let inputState = Self.state()
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let p1) = probeAdvance.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            p1, submitted: "1", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            p2, submitted: "2", state: a1.state, bundle: bundle, today: Self.today())
        guard case .returned(let outcome) = a2.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.state == inputState)
    }

    // MARK: - T7 (AC13) properties over PropertyGen-generated graphs/states

    /// Drives a whole diagnosis via the thin driver `run` (itself "only ever the step functions") on a
    /// randomly generated decision script.
    private static func driveRandomDiagnosis(
        _ gen: inout SeededGenerator, bundle: ContentBundle, originId: String, levelBudget: Int,
        state: StudentState, today: CalendarDay
    ) -> DiagnosisOutcome {
        let decisions = PropertyGen.diagnosisLevelDecisions(&gen, count: 3)
        return DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: originId, misses: [], levelBudget: levelBudget,
            decisions: decisions, shownItemIdsInRun: [], state: state, bundle: bundle, today: today)
    }

    /// Independently re-implements `run`'s own loop by hand, calling the step functions directly — the
    /// driver-equivalence oracle for `driverEquivalence()` below.
    private static func driveWithDecisions(
        bundle: ContentBundle, originId: String, levelBudget: Int,
        decisions: [DiagnosisLevelDecision], state: StudentState, today: CalendarDay
    ) -> DiagnosisOutcome {
        let event = DiagnosisRun.open(
            originNodeId: originId, trigger: .mapCheckHere, levelBudget: levelBudget)
        var advance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: state, bundle: bundle)
        let fallback = DiagnosisLevelDecision(
            declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)
        var offerIndex = -1
        var currentDecision = fallback
        while true {
            switch advance.step {
            case .returned(let outcome):
                return outcome
            case .probeOffer(let offer):
                offerIndex += 1
                currentDecision = offerIndex < decisions.count ? decisions[offerIndex] : fallback
                advance = DiagnosisRun.decideProbe(
                    offer, accept: !currentDecision.declineProbe, state: advance.state, bundle: bundle)
            case .probeItem(let probe):
                let idx = probe.levelResults.count
                let submitted =
                    idx < currentDecision.submittedAnswers.count
                    ? currentDecision.submittedAnswers[idx] : ""
                advance = DiagnosisRun.answerProbeItem(
                    probe, submitted: submitted, state: advance.state, bundle: bundle, today: today)
            case .furtherLevelOffer(let offer):
                advance = DiagnosisRun.decideFurtherLevel(
                    offer, accept: currentDecision.acceptFurtherLevel, state: advance.state,
                    bundle: bundle)
            }
        }
    }

    @Test("property: every path terminates in .diagnosisReturned, over generated graphs")
    func everyPathTerminatesInReturned() throws {
        let base = try Self.loadDemoBundle()
        var gen = SeededGenerator(seed: 1)
        var count = 0
        for _ in 0..<20 {
            let graph = PropertyGen.smallLayeredGraphWithProbeItems(&gen, maxLevels: 3, maxBranching: 2)
            let bundle = Self.bundle(base, nodes: graph.nodes, edges: graph.edges)
            let levelBudget = PropertyGen.element(&gen, from: [1, 2])
            let outcome = Self.driveRandomDiagnosis(
                &gen, bundle: bundle, originId: graph.originId, levelBudget: levelBudget,
                state: Self.state(), today: Self.today())
            #expect(outcome.events.last == .diagnosisReturned)
            count += 1
        }
        #expect(count > 0)
    }

    @Test("property: every capped or confirmed candidate is blocked in state")
    func cappedOrConfirmedCandidateIsBlocked() throws {
        let base = try Self.loadDemoBundle()
        var gen = SeededGenerator(seed: 2)
        var confirmedCount = 0
        var cappedCount = 0
        for _ in 0..<30 {
            let graph = PropertyGen.smallLayeredGraphWithProbeItems(&gen, maxLevels: 3, maxBranching: 2)
            let bundle = Self.bundle(base, nodes: graph.nodes, edges: graph.edges)
            let levelBudget = PropertyGen.element(&gen, from: [1, 2])
            let outcome = Self.driveRandomDiagnosis(
                &gen, bundle: bundle, originId: graph.originId, levelBudget: levelBudget,
                state: Self.state(), today: Self.today())
            if outcome.terminal == .confirmed {
                confirmedCount += 1
                if let last = outcome.blockedNodeIds.last {
                    #expect(outcome.state.nodes[last]?.mastery == .blocked)
                    #expect(outcome.state.nodes[last]?.remediated == true)
                }
            }
            if outcome.terminal == .capped {
                cappedCount += 1
                if let last = outcome.blockedNodeIds.last {
                    #expect(outcome.state.nodes[last]?.mastery == .blocked)
                    #expect(outcome.state.nodes[last]?.remediated != true)
                }
            }
        }
        #expect(confirmedCount > 0)
        #expect(cappedCount > 0)
    }

    @Test("property: depthReached <= levelBudget <= 2, over generated graphs and budgets")
    func depthReachedNeverExceedsBudget() throws {
        let base = try Self.loadDemoBundle()
        var gen = SeededGenerator(seed: 3)
        var count = 0
        for _ in 0..<20 {
            let graph = PropertyGen.smallLayeredGraphWithProbeItems(&gen, maxLevels: 3, maxBranching: 2)
            let bundle = Self.bundle(base, nodes: graph.nodes, edges: graph.edges)
            let levelBudget = PropertyGen.element(&gen, from: [1, 2])
            let outcome = Self.driveRandomDiagnosis(
                &gen, bundle: bundle, originId: graph.originId, levelBudget: levelBudget,
                state: Self.state(), today: Self.today())
            #expect(outcome.depthReached <= levelBudget)
            #expect(levelBudget <= 2)
            count += 1
        }
        #expect(count > 0)
    }

    @Test("property: driver run() equals the hand-stepped terminal outcome, over generated decisions")
    func driverEquivalence() throws {
        let base = try Self.loadDemoBundle()
        var gen = SeededGenerator(seed: 4)
        var count = 0
        for _ in 0..<20 {
            let graph = PropertyGen.smallLayeredGraphWithProbeItems(&gen, maxLevels: 3, maxBranching: 2)
            let bundle = Self.bundle(base, nodes: graph.nodes, edges: graph.edges)
            let levelBudget = PropertyGen.element(&gen, from: [1, 2])
            let decisions = PropertyGen.diagnosisLevelDecisions(&gen, count: 3)
            let driverOutcome = DiagnosisRun.run(
                trigger: .mapCheckHere, originNodeId: graph.originId, misses: [],
                levelBudget: levelBudget, decisions: decisions, shownItemIdsInRun: [],
                state: Self.state(), bundle: bundle, today: Self.today())
            let handStepped = Self.driveWithDecisions(
                bundle: bundle, originId: graph.originId, levelBudget: levelBudget,
                decisions: decisions, state: Self.state(), today: Self.today())
            #expect(driverOutcome == handStepped)
            count += 1
        }
        #expect(count > 0)
    }

    @Test("property: a second level is entered only immediately after an explicit accept")
    func secondLevelOnlyAfterExplicitAccept() throws {
        let base = try Self.loadDemoBundle()
        // `origin <- c <- d`; `d` starts `.cleared` so the first (budget-2) query stops at `c`
        // (depth 1) rather than deepening to `d` — the same construction as AC8.
        let bundle = Self.bundle(
            base, nodes: [Self.testNode(id: "origin"), Self.testNode(id: "c"), Self.testNode(id: "d")],
            edges: [Self.edge(from: "c", to: "origin"), Self.edge(from: "d", to: "c")])
        let inputState = Self.state(nodes: ["d": Self.clearedNode()])
        let event = DiagnosisRun.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .probeOffer(let offer1) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let firstLevel = offer1.context.level
        let probe1 = DiagnosisRun.decideProbe(
            offer1, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let p1) = probe1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a1 = DiagnosisRun.answerProbeItem(
            p1, submitted: "9", state: probe1.state, bundle: bundle, today: Self.today())
        guard case .probeItem(let p2) = a1.step else {
            Issue.record("expected .probeItem")
            return
        }
        let a2 = DiagnosisRun.answerProbeItem(
            p2, submitted: "9", state: a1.state, bundle: bundle, today: Self.today())
        guard case .furtherLevelOffer(let furtherOffer) = a2.step else {
            Issue.record("expected .furtherLevelOffer")
            return
        }
        let stateForSecondQuery = Self.withNode(a2.state, id: "d", node: Self.fogNode())
        let accepted = DiagnosisRun.decideFurtherLevel(
            furtherOffer, accept: true, state: stateForSecondQuery, bundle: bundle)
        guard case .probeOffer(let offer2) = accepted.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer2.context.level > firstLevel)
    }

    // MARK: - T10 (AC16) hint-key resolution

    @Test("F1: catalogue fallback resolves when the classified id does not")
    func hintKeyF1CatalogueFallbackResolves() {
        let node = Self.testNode(
            id: "n", errorTypeId: "sign-error",
            hintTree: [
                "sign-error": ["t1", "t2", "t3"], "none-of-these": ["t1", "t2", "t3"],
            ])
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "sign-error") == "sign-error")
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") == "none-of-these")
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "not-a-type") == "none-of-these")
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none-of-these") == "none-of-these")
    }

    @Test("F2: no fallback entry, and no guessing another error type's key")
    func hintKeyF2NoFallbackNoGuessing() {
        let node = Self.testNode(
            id: "n", errorTypeId: "sign-error", hintTree: ["sign-error": ["t1", "t2", "t3"]])
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") == nil)
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "not-a-type") == nil)
        #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "sign-error") == "sign-error")
    }

    @Test("F3: empty hintTree resolves nil for every input")
    func hintKeyF3EmptyTree() {
        let node = Self.testNode(id: "n", errorTypeId: "sign-error", hintTree: [:])
        for errorTypeId in ["sign-error", "none_of_these", "not-a-type", "none-of-these"] {
            #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: errorTypeId) == nil)
        }
    }

    @Test("real data/demo: hintKey is derived from each node's own data, never a hand-kept list")
    func hintKeyOnRealDataDemo() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(bundle.nodes.nodes.count > 0)
        for node in bundle.nodes.nodes {
            let expectedNoneOfThese =
                (node.hintTree["none-of-these"] ?? []).isEmpty ? nil : "none-of-these"
            #expect(
                DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") == expectedNoneOfThese)
            #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: "none_of_these") != "none_of_these")
            for errorType in node.errorTypes where !(node.hintTree[errorType.id] ?? []).isEmpty {
                #expect(DiagnosisRun.hintKey(originNode: node, errorTypeId: errorType.id) == errorType.id)
            }
        }
    }
}

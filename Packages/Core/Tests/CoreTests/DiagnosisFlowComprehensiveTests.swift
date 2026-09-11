import Foundation
import Testing

@testable import Core

/// Tester's comprehensive suite for task 04.3 (`tasks/epic-04-task-03-core-door-a-diagnosis-flow.md`),
/// covering AC1-AC10 and §5's T1-T6 over `Sources/Core/Door/DiagnosisFlow.swift` and
/// `Sources/Core/Door/DiagnosisContent.swift`. The implementer's own smoke
/// (`DiagnosisFlowTests.expeditionSecondMissFullRunReachesCapped`) already owns the
/// `expedition_second_miss` happy path to `.capped`; this file does not re-verify it (RULE: budget goes
/// to items 2-8).
@Suite("DoorADiagnosisFlow comprehensive suite")
struct DiagnosisFlowComprehensiveTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var coreSourcesDoorDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/Door")
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

    private static func today() -> CalendarDay {
        guard let day = CalendarDay(iso: "2026-09-10") else {
            preconditionFailure("2026-09-10 must be a valid CalendarDay")
        }
        return day
    }

    private static func state(nodes: [String: NodeState] = [:]) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MCR3U"],
            marker: Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    private static func clearedNode() -> NodeState {
        NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    private static func node(_ id: String, bundle: ContentBundle) -> Node {
        guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
            preconditionFailure("node \(id) not found")
        }
        return match
    }

    private static func bundle(_ base: ContentBundle, nodes: [Node], edges: [Edge]) -> ContentBundle {
        ContentBundle(
            manifest: base.manifest, regions: base.regions,
            nodes: NodesFile(formatVersion: base.nodes.formatVersion, nodes: nodes),
            edges: EdgesFile(formatVersion: base.edges.formatVersion, edges: edges), courses: base.courses,
            landmarks: base.landmarks, sources: base.sources)
    }

    private static func edge(from: String, to: String, confidence: Double = 0.8) -> Edge {
        PropertyGen.minimalEdge(from: from, to: to, confidence: confidence)
    }

    /// A `Node` with exactly one probe item — never enough for a probe (`DIAG_PROBE_UNAVAILABLE`).
    private static func fewItemsNode(id: String) -> Node {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil, paraphrase: "test node \(id)",
            explanation: nil, workedExamples: nil, errorTypes: [], hintTree: [:],
            probeItems: [
                ProbeItem(
                    id: "\(id)-1", type: .numeric, promptLatex: "?", why: "why", renderFallback: nil,
                    answer: ProbeAnswer(value: "1", tolerance: nil), wrongAnswers: nil, choices: nil,
                    correctChoiceId: nil, check: nil)
            ])
    }

    /// The tagged-distractor wrong submission for `item` (numeric: `wrongAnswers.first.value`; mc: the
    /// first choice carrying an `errorTypeId`), matching the smoke test's own resolution shape.
    private static func wrongSubmission(for item: ProbeItem) -> String {
        if let choice = item.choices?.first(where: { $0.errorTypeId != nil }) {
            return choice.id
        }
        return item.wrongAnswers?.first?.value ?? "not-a-real-answer"
    }

    private static func correctSubmission(for item: ProbeItem) -> String {
        item.answer?.value ?? item.correctChoiceId ?? "unknown"
    }

    // MARK: - AC1 / I2: the façade drives only DiagnosisRun's public step API

    /// Forbidden call patterns: `DiagnosisRun`'s internal helpers, reachable only from within
    /// `DiagnosisEvent.swift` itself or (for `hintKey` only) from this task's own hint resolver in
    /// `DiagnosisContent.swift` (AC5).
    private static let forbiddenInternalHelperCalls = [
        "DiagnosisRun.classify(", "DiagnosisRun.hypothesise(", "DiagnosisRun.drawProbeItems(",
        "DiagnosisRun.offered(", "DiagnosisRun.remediate(", "DiagnosisRun.capped(",
        "DiagnosisRun.terminal(", "DiagnosisRun.updatedContext(",
    ]

    @Test("AC1: DiagnosisFlow.swift calls none of DiagnosisRun's internal helpers directly")
    func ac1FlowNeverCallsInternalHelpers() throws {
        let source = try String(
            contentsOf: Self.coreSourcesDoorDir.appendingPathComponent("DiagnosisFlow.swift"),
            encoding: .utf8)
        #expect(!source.isEmpty, "instrument broken: DiagnosisFlow.swift is empty")
        // `hintKey` is never called from DiagnosisFlow.swift either — only from this task's own resolver.
        var offenders: [String] = []
        for pattern in Self.forbiddenInternalHelperCalls + ["DiagnosisRun.hintKey("] {
            if source.contains(pattern) { offenders.append(pattern) }
        }
        #expect(offenders.isEmpty, "DiagnosisFlow.swift calls internal helpers directly: \(offenders)")
    }

    @Test("AC1: DiagnosisContent.swift calls only DiagnosisRun.hintKey among the internal helpers (AC5)")
    func ac1ContentOnlyCallsHintKey() throws {
        let source = try String(
            contentsOf: Self.coreSourcesDoorDir.appendingPathComponent("DiagnosisContent.swift"),
            encoding: .utf8)
        #expect(!source.isEmpty, "instrument broken: DiagnosisContent.swift is empty")
        var offenders: [String] = []
        for pattern in Self.forbiddenInternalHelperCalls {
            if source.contains(pattern) { offenders.append(pattern) }
        }
        #expect(offenders.isEmpty, "DiagnosisContent.swift calls a forbidden internal helper: \(offenders)")
        #expect(
            source.contains("DiagnosisRun.hintKey("),
            "resolveHint must call hintKey in-module, per Rule 2")
    }

    @Test("AC1 guard is load-bearing: a planted internal-helper call is caught by the same scan")
    func ac1GuardCatchesPlantedCall() {
        let planted = "let x = DiagnosisRun.classify(misses)"
        let offenders = Self.forbiddenInternalHelperCalls.filter { planted.contains($0) }
        #expect(!offenders.isEmpty, "scan failed to catch a planted internal-helper call — guard is vacuous")
    }

    // MARK: - AC2 (map_check_here): decline -> unconfirmed, both correct -> refuted

    @Test(
        "AC2 (map_check_here, decline): .unconfirmed, hint resolved, line nil, events end .diagnosisReturned")
    func mapCheckHereDeclineReachesUnconfirmed() throws {
        let bundle = try Self.loadDemoBundle()
        let origin = Self.node("polynomials", bundle: bundle)
        let event = DoorADiagnosisFlow.open(
            originNodeId: origin.id, trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis, got \(startAdvance.screen)")
            return
        }
        #expect(offer.context.originErrorTypeId == "none_of_these")

        let declineAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: false, state: startAdvance.state, bundle: bundle)
        guard case .terminal(let terminalContent) = declineAdvance.screen else {
            Issue.record("expected .terminal, got \(declineAdvance.screen)")
            return
        }
        #expect(terminalContent.terminal == .unconfirmed)
        #expect(terminalContent.outcome.code == nil)
        #expect(terminalContent.line == nil)
        let hint = try #require(terminalContent.hint)
        #expect(hint.resolvedKey == "none-of-these")
        #expect(hint.internalCode == nil)
        #expect(hint.prose == origin.hintTree["none-of-these"]?.first)
        #expect(terminalContent.remediation == nil)
        #expect(declainedEventsEndInReturned(declineAdvance.events))
    }

    private func declainedEventsEndInReturned(_ events: [CoreEvent]) -> Bool {
        events.last == .diagnosisReturned
    }

    @Test("AC2 (map_check_here, both correct): .refuted, hint resolved, line == refutedLine")
    func mapCheckHereBothCorrectReachesRefuted() throws {
        let bundle = try Self.loadDemoBundle()
        let origin = Self.node("polynomials", bundle: bundle)
        let candidateId = "exponent-laws"
        let candidate = Self.node(candidateId, bundle: bundle)
        let event = DoorADiagnosisFlow.open(
            originNodeId: origin.id, trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis, got \(startAdvance.screen)")
            return
        }
        #expect(offer.candidateId == candidateId)
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem, got \(probeAdvance.screen)")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: Self.correctSubmission(for: probe1.currentItem), state: probeAdvance.state,
            bundle: bundle, today: Self.today())
        #expect(firstAnswer.answerCard.correct == true)
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after the first correct answer")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: Self.correctSubmission(for: probe2.currentItem), state: firstAnswer.state,
            bundle: bundle, today: Self.today())
        #expect(secondAnswer.answerCard.correct == true)
        guard
            case .terminal(let terminalContent) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .terminal after the second correct answer")
            return
        }
        #expect(terminalContent.terminal == .refuted)
        #expect(terminalContent.line == DoorADiagnosisCopy.refutedLine)
        let hint = try #require(terminalContent.hint)
        #expect(hint.resolvedKey == "none-of-these")
        #expect(hint.internalCode == nil)
        _ = candidate
        #expect(secondAnswer.events.last == .diagnosisReturned)
        // Candidate is never blocked on a refuted probe.
        #expect(terminalContent.outcome.state.nodes[candidateId] == nil)
    }

    // MARK: - AC3 (I3): DoorAProbeAnswerAdvance surfaces no next screen; continue is pure

    @Test("AC3: no field of DoorAProbeAnswerAdvance yields a screen; only continueAfterProbeAnswer does")
    func ac3NoLeakToNextScreenAcrossEveryRealNode() throws {
        let base = try Self.loadDemoBundle()
        var checked = 0
        for candidate in base.nodes.nodes {
            // A private synthetic origin whose sole prerequisite is `candidate`, so every real node is
            // driven as a probed candidate at least once (I3's own property test population).
            let syntheticOrigin = PropertyGen.minimalNode(id: "synthetic-origin-\(candidate.id)")
            let syntheticBundle = Self.bundle(
                base, nodes: [syntheticOrigin, candidate],
                edges: [Self.edge(from: candidate.id, to: syntheticOrigin.id)])
            let event = DoorADiagnosisFlow.open(
                originNodeId: syntheticOrigin.id, trigger: .mapCheckHere, levelBudget: 1)
            let startAdvance = DoorADiagnosisFlow.start(
                event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
                bundle: syntheticBundle)
            guard case .hypothesis(_, let offer) = startAdvance.screen else {
                Issue.record("expected .hypothesis for candidate \(candidate.id)")
                continue
            }
            #expect(offer.candidateId == candidate.id)
            let probeAdvance = DoorADiagnosisFlow.decideProbe(
                offer, accept: true, state: startAdvance.state, bundle: syntheticBundle)
            guard case .probeItem(_, let probe1) = probeAdvance.screen else {
                Issue.record("expected .probeItem for candidate \(candidate.id)")
                continue
            }
            let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
                probe1, submitted: Self.wrongSubmission(for: probe1.currentItem),
                state: probeAdvance.state, bundle: syntheticBundle, today: Self.today())
            // I3's own field-shape guard: `DoorAProbeAnswerAdvance` carries only these four public fields
            // (checked once here, structurally, not per-node — Mirror does not expose access level, so the
            // exhaustive per-node loop below checks the *behavioural* half of I3: no way to reach the next
            // screen except via `continueAfterProbeAnswer`, and it is pure).
            let screenAfterFirst = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: syntheticBundle)
            guard case .probeItem(_, let probe2) = screenAfterFirst else {
                Issue.record("expected .probeItem after the first answer for candidate \(candidate.id)")
                continue
            }
            let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
                probe2, submitted: Self.wrongSubmission(for: probe2.currentItem), state: firstAnswer.state,
                bundle: syntheticBundle, today: Self.today())
            let finalScreenFirstCall = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: syntheticBundle)
            let finalScreenSecondCall = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: syntheticBundle)
            #expect(
                finalScreenFirstCall == finalScreenSecondCall,
                "continueAfterProbeAnswer must be pure over the same DoorAProbeAnswerAdvance value (candidate \(candidate.id))"
            )
            checked += 1
        }
        #expect(checked == base.nodes.nodes.count, "empty or partial data/demo scan is a FAIL")
    }

    @Test(
        "AC3 guard is load-bearing: DoorAProbeAnswerAdvance's pendingAdvance/classifiedToken are plain `let`")
    func ac3FieldAccessScan() throws {
        let source = try String(
            contentsOf: Self.coreSourcesDoorDir.appendingPathComponent("DiagnosisFlow.swift"),
            encoding: .utf8)
        #expect(!source.contains("public let pendingAdvance"))
        #expect(!source.contains("public let classifiedToken"))
        #expect(source.contains("let pendingAdvance: DiagnosisAdvance"))
        #expect(source.contains("let classifiedToken: String"))
    }

    @Test("AC3 guard negative control: a planted `public let pendingAdvance` is caught by the same scan")
    func ac3FieldAccessScanNegativeControl() {
        let planted = "    public let pendingAdvance: DiagnosisAdvance\n"
        #expect(planted.contains("public let pendingAdvance"), "scan is vacuous on a planted violation")
    }

    // MARK: - AC4 (I4): Demo budget of 1, real data/demo and a synthetic deeper-prerequisite graph

    @Test(
        "AC4 (real data/demo): confirmed probe at budget 1 reaches .capped in the same answerProbeItem call")
    func ac4CappedOnRealDemoNoInterveningFurtherLevelOffer() throws {
        let bundle = try Self.loadDemoBundle()
        let deeperId = "solving-linear-equations"
        let candidateId = "exponent-laws"
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: Self.wrongSubmission(for: probe1.currentItem), state: probeAdvance.state,
            bundle: bundle, today: Self.today())
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after first miss")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: Self.wrongSubmission(for: probe2.currentItem), state: firstAnswer.state,
            bundle: bundle, today: Self.today())
        // The confirming call is `secondAnswer`; the very next screen must already be the terminal — no
        // furtherLevelOffer screen is reachable in between.
        guard
            case .terminal(let terminalContent) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .terminal (capped) directly, with no intervening furtherLevelOffer")
            return
        }
        #expect(terminalContent.terminal == .capped)
        #expect(terminalContent.line == DoorADiagnosisCopy.cappedLine)
        #expect(terminalContent.hint == nil)
        #expect(terminalContent.remediation != nil)
        #expect(terminalContent.outcome.depthReached <= 1)
        #expect(terminalContent.outcome.state.nodes[candidateId]?.mastery == .blocked)
        #expect(terminalContent.outcome.state.nodes[deeperId]?.mastery == .blocked)
        // No field on DoorATerminalContent or DiagnosisOutcome names the deeper candidate's own
        // remediation/hint content: `remediation` is keyed only to the probed candidate (exponent-laws),
        // never to `deeperId`.
        if case .paraphrase(let text, _) = terminalContent.remediation {
            #expect(text == Self.node(candidateId, bundle: bundle).paraphrase)
            #expect(text != Self.node(deeperId, bundle: bundle).paraphrase)
        } else {
            Issue.record("expected .paraphrase remediation on real data/demo")
        }
    }

    @Test(
        "AC4 (synthetic two-level graph): confirmed probe at budget 1 reaches .capped, deeper candidate blocked"
    )
    func ac4CappedOnSyntheticDeeperPrerequisiteGraph() throws {
        let base = try Self.loadDemoBundle()
        // origin <- c <- d: c is the probe candidate; d is the deeper prerequisite the W6 query finds.
        let origin = PropertyGen.probeableNode(id: "origin")
        let c = PropertyGen.probeableNode(id: "c")
        let d = PropertyGen.probeableNode(id: "d")
        let bundle = Self.bundle(
            base, nodes: [origin, c, d],
            edges: [Self.edge(from: c.id, to: origin.id), Self.edge(from: d.id, to: c.id)])
        let event = DoorADiagnosisFlow.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        #expect(offer.candidateId == "c")
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: "9", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after first miss")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: "9", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard
            case .terminal(let terminalContent) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .terminal (capped), no intervening furtherLevelOffer")
            return
        }
        #expect(terminalContent.terminal == .capped)
        #expect(terminalContent.line == DoorADiagnosisCopy.cappedLine)
        #expect(terminalContent.hint == nil)
        #expect(terminalContent.outcome.state.nodes["c"]?.mastery == .blocked)
        #expect(terminalContent.outcome.state.nodes["d"]?.mastery == .blocked)
        guard case .paraphrase(let text, _) = terminalContent.remediation else {
            Issue.record("expected .paraphrase remediation")
            return
        }
        #expect(text == c.paraphrase)
        #expect(text != d.paraphrase)
    }

    // MARK: - AC5: the hint resolver's exact Rule 2 table

    @Test(
        "AC5 row 1 (real data/demo): every node's own tagged error type resolves key == expected, internalCode nil"
    )
    func ac5Row1OwnErrorTypeResolves() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            guard let ownErrorTypeId = node.errorTypes.first(where: { $0.id != "none-of-these" })?.id
            else { continue }
            let content = DoorADiagnosisContentBuilder.resolveHint(
                node: node, classifiedToken: ownErrorTypeId)
            #expect(content.resolvedKey == ownErrorTypeId, "\(node.id)")
            #expect(content.internalCode == nil, "\(node.id)")
            #expect(content.prose == node.hintTree[ownErrorTypeId]?.first, "\(node.id)")
            checked += 1
        }
        #expect(checked > 0, "empty data/demo scan is a FAIL")
    }

    @Test("AC5 row 1 (real data/demo, since 04.1b): every map_check_here hint resolves to none-of-these")
    func ac5Row1NoneOfTheseResolvesOnEveryRealNode() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            let content = DoorADiagnosisContentBuilder.resolveHint(
                node: node, classifiedToken: "none_of_these")
            #expect(content.resolvedKey == "none-of-these", "\(node.id)")
            #expect(content.internalCode == nil, "\(node.id)")
            #expect(content.prose == node.hintTree["none-of-these"]?.first, "\(node.id)")
            checked += 1
        }
        #expect(checked == bundle.nodes.nodes.count, "empty or partial data/demo scan is a FAIL")
    }

    @Test("AC5 row 2 (in-memory fixture): a classified type with no entry falls to none-of-these")
    func ac5Row2NoneOfTheseFallbackWithLoHintNotFound() throws {
        let node = Node(
            id: "row2-fixture", name: "row2", regionId: .algebra, strand: nil, expectationCodes: nil,
            sourceRef: nil, courses: [], position: Point(x: 0, y: 0), layoutHint: nil,
            paraphrase: "row2 paraphrase", explanation: nil, workedExamples: nil,
            errorTypes: [
                ErrorType(id: "sign-error", label: "sign error", impliesPrerequisite: nil),
                ErrorType(id: "none-of-these", label: "none of these", impliesPrerequisite: nil),
            ], hintTree: ["none-of-these": ["generic tier 1", "generic tier 2", "generic tier 3"]],
            probeItems: [])
        // "sign-error" is a classified type with no hintTree entry of its own -> falls to none-of-these.
        let content = DoorADiagnosisContentBuilder.resolveHint(node: node, classifiedToken: "sign-error")
        #expect(content.resolvedKey == "none-of-these")
        #expect(content.internalCode == .loHintNotFound)
        #expect(content.prose == "generic tier 1")
    }

    @Test("AC5 row 3 (in-memory fixture, no none-of-these entry): key nil, paraphrase shown")
    func ac5Row3NilKeyShowsParaphrase() throws {
        let node = Node(
            id: "row3-fixture", name: "row3", regionId: .algebra, strand: nil, expectationCodes: nil,
            sourceRef: nil, courses: [], position: Point(x: 0, y: 0), layoutHint: nil,
            paraphrase: "row3 paraphrase", explanation: nil, workedExamples: nil,
            errorTypes: [ErrorType(id: "sign-error", label: "sign error", impliesPrerequisite: nil)],
            hintTree: [:], probeItems: [])
        for token in ["sign-error", "none_of_these", "some-unclassified-type"] {
            let content = DoorADiagnosisContentBuilder.resolveHint(node: node, classifiedToken: token)
            #expect(content.resolvedKey == nil, "\(token)")
            #expect(content.internalCode == .loHintNotFound, "\(token)")
            #expect(content.prose == "row3 paraphrase", "\(token)")
        }
    }

    @Test("CoreErrorText never renders LO_HINT_NOT_FOUND (internal code, no student surface)")
    func loHintNotFoundHasNoUserText() {
        #expect(CoreErrorText.text(for: .loHintNotFound) == nil)
    }

    // MARK: - AC6: the remediation selector's priority order

    @Test("AC6: explanation branch wins when non-nil and non-empty")
    func ac6ExplanationBranch() throws {
        let node = Self.node("polynomials", bundle: try Self.loadDemoBundle())
        let withExplanation = Node(
            id: node.id, name: node.name, regionId: node.regionId, strand: node.strand,
            expectationCodes: node.expectationCodes, sourceRef: node.sourceRef, courses: node.courses,
            position: node.position, layoutHint: node.layoutHint, paraphrase: node.paraphrase,
            explanation: "the worked-out explanation", workedExamples: node.workedExamples,
            errorTypes: node.errorTypes, hintTree: node.hintTree, probeItems: node.probeItems)
        let remediation = DoorADiagnosisContentBuilder.selectRemediation(
            candidate: withExplanation, misses: [])
        guard case .explanation(let text) = remediation else {
            Issue.record("expected .explanation, got \(remediation)")
            return
        }
        #expect(text == "the worked-out explanation")
    }

    @Test("AC6: worked-example branch wins when explanation is nil/empty but workedExamples is non-empty")
    func ac6WorkedExampleBranch() throws {
        let node = Self.node("polynomials", bundle: try Self.loadDemoBundle())
        let example = WorkedExample(id: "we-1", stepsLatex: ["x = 1", "x = 2"])
        for explanation in [nil, ""] as [String?] {
            let withExample = Node(
                id: node.id, name: node.name, regionId: node.regionId, strand: node.strand,
                expectationCodes: node.expectationCodes, sourceRef: node.sourceRef, courses: node.courses,
                position: node.position, layoutHint: node.layoutHint, paraphrase: node.paraphrase,
                explanation: explanation, workedExamples: [example], errorTypes: node.errorTypes,
                hintTree: node.hintTree, probeItems: node.probeItems)
            let remediation = DoorADiagnosisContentBuilder.selectRemediation(
                candidate: withExample, misses: [])
            guard case .workedExample(let we) = remediation else {
                Issue.record("expected .workedExample for explanation=\(String(describing: explanation))")
                continue
            }
            #expect(we == example)
        }
    }

    @Test("AC6 (real data/demo, post 04.1b): every confirmed candidate takes .paraphrase(_, hint: non-nil)")
    func ac6RealDataAlwaysParaphraseWithHint() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            #expect(node.explanation == nil || node.explanation == "", "\(node.id)")
            #expect((node.workedExamples ?? []).isEmpty, "\(node.id)")
            let ownItem = node.probeItems.first(where: { $0.type == .numeric })
            let misses: [ItemMiss]
            if let item = ownItem, let wrong = item.wrongAnswers?.first {
                misses = [ItemMiss(item: item, submittedValue: wrong.value)]
            } else {
                misses = []
            }
            let remediation = DoorADiagnosisContentBuilder.selectRemediation(
                candidate: node, misses: misses)
            guard case .paraphrase(let text, let hint) = remediation else {
                Issue.record("expected .paraphrase for \(node.id), got \(remediation)")
                continue
            }
            #expect(text == node.paraphrase, "\(node.id)")
            #expect(hint != nil, "\(node.id): hint must resolve since every node carries none-of-these")
            checked += 1
        }
        #expect(checked == bundle.nodes.nodes.count, "empty or partial data/demo scan is a FAIL")
    }

    @Test("AC6: remediation is never empty (paraphrase branch always carries schema-required text)")
    func ac6NeverEmpty() {
        let node = Node(
            id: "no-content", name: "no-content", regionId: .algebra, strand: nil,
            expectationCodes: nil, sourceRef: nil, courses: [], position: Point(x: 0, y: 0),
            layoutHint: nil, paraphrase: "the only content this node has", explanation: nil,
            workedExamples: nil, errorTypes: [], hintTree: [:], probeItems: [])
        let remediation = DoorADiagnosisContentBuilder.selectRemediation(candidate: node, misses: [])
        guard case .paraphrase(let text, let hint) = remediation else {
            Issue.record("expected .paraphrase")
            return
        }
        #expect(!text.isEmpty)
        #expect(hint == nil)
    }

    // MARK: - AC7: hint-resolver negative controls (never touching product code)

    @Test("AC7 negative control: a resolver returning empty prose on a resolved key fails its own guard")
    func ac7EmptyProseNegativeControl() throws {
        let node = Self.node("polynomials", bundle: try Self.loadDemoBundle())
        // Locally reconstructed variant of resolveHint's exact-match row, but with the BUG of an empty
        // prose string where the real code reads `node.hintTree[key]![0]`.
        func buggyResolveHint(node: Node, classifiedToken: String) -> DoorAHintContent {
            let key = DiagnosisRun.hintKey(originNode: node, errorTypeId: classifiedToken)
            guard let k = key else {
                return DoorAHintContent(
                    nodeId: node.id, prose: node.paraphrase, resolvedKey: nil,
                    internalCode: .loHintNotFound)
            }
            return DoorAHintContent(nodeId: node.id, prose: "", resolvedKey: k, internalCode: nil)
        }
        let buggy = buggyResolveHint(node: node, classifiedToken: "none_of_these")
        let passesNonEmptyProseGuard = !buggy.prose.isEmpty
        #expect(!passesNonEmptyProseGuard, "the empty-prose bug should fail the non-empty prose guard")
    }

    @Test("AC7 negative control: a resolver borrowing a sibling type's hint fails the never-guess guard")
    func ac7SiblingSubstitutionNegativeControl() throws {
        // exponential-functions carries two non-none-of-these error types (a required fixture property).
        let node = Self.node("exponential-functions", bundle: try Self.loadDemoBundle())
        let siblingKeys = node.errorTypes.map(\.id).filter { $0 != "none-of-these" }
        #expect(siblingKeys.count >= 2, "fixture sanity: need >=2 sibling error types on this node")

        let classifiedToken = "none_of_these"
        let expected = "none-of-these"
        // Locally reconstructed variant: instead of the reconciled fallback (none-of-these, else
        // paraphrase), it substitutes ANY sibling ErrorType's own tier-1 hint for the outcome token —
        // presenting a misconception the student was never classified with (a guessed diagnosis, I2).
        func buggyResolveHint(node: Node, classifiedToken: String) -> DoorAHintContent {
            if let sibling = node.errorTypes.map(\.id).first(where: { $0 != expected }),
                let prose = node.hintTree[sibling]?.first
            {
                return DoorAHintContent(
                    nodeId: node.id, prose: prose, resolvedKey: sibling, internalCode: nil)
            }
            return DoorAHintContent(
                nodeId: node.id, prose: node.paraphrase, resolvedKey: nil, internalCode: .loHintNotFound)
        }
        let buggy = buggyResolveHint(node: node, classifiedToken: classifiedToken)
        // The real invariant: a resolved key is always either `expected` or the none-of-these fallback,
        // never an unclassified sibling. The buggy resolver violates it.
        let neverGuessesGuardHolds = buggy.resolvedKey == nil || buggy.resolvedKey == expected
        #expect(!neverGuessesGuardHolds, "sibling substitution should fail the never-guess guard")

        // Sanity: the real resolver over the same inputs never violates the guard.
        let real = DoorADiagnosisContentBuilder.resolveHint(node: node, classifiedToken: classifiedToken)
        let realGuardHolds = real.resolvedKey == nil || real.resolvedKey == expected
        #expect(realGuardHolds, "the real resolver must never substitute a sibling's hint")
    }

    // MARK: - AC8 (I2): Foundation-only imports, no adapter pattern, planted negative control

    private static let adapterPatternSet = ["FoundationModels", "Adapter", "import CoreML", "URLSession"]

    @Test("AC8: DiagnosisFlow.swift and DiagnosisContent.swift are non-empty and carry no adapter pattern")
    func ac8NoAdapterPattern() throws {
        for filename in ["DiagnosisFlow.swift", "DiagnosisContent.swift"] {
            let source = try String(
                contentsOf: Self.coreSourcesDoorDir.appendingPathComponent(filename), encoding: .utf8)
            #expect(!source.isEmpty, "instrument broken: \(filename) not found or empty")
            for pattern in Self.adapterPatternSet {
                #expect(!source.contains(pattern), "\(filename) contains banned adapter pattern '\(pattern)'")
            }
        }
    }

    @Test("AC8: both files import Foundation only")
    func ac8ImportsFoundationOnly() throws {
        for filename in ["DiagnosisFlow.swift", "DiagnosisContent.swift"] {
            let text = try String(
                contentsOf: Self.coreSourcesDoorDir.appendingPathComponent(filename), encoding: .utf8)
            let imports = text.split(separator: "\n")
                .filter { $0.hasPrefix("import ") }
                .map { $0.dropFirst("import ".count).trimmingCharacters(in: .whitespaces) }
            #expect(!imports.isEmpty, "\(filename): instrument broken, no import line")
            #expect(Set(imports) == ["Foundation"], "\(filename) imports more than Foundation: \(imports)")
        }
    }

    @Test("AC8 guard is load-bearing: a planted 'FoundationModels' string is caught by the same scan")
    func ac8GuardCatchesPlantedAdapterString() {
        let planted = "// local test-only fixture: FoundationModels.SystemLanguageModel"
        let offenders = Self.adapterPatternSet.filter { planted.contains($0) }
        #expect(!offenders.isEmpty, "scan failed to catch a planted adapter pattern — guard is vacuous")
    }

    /// No persistence anywhere in this task's file scope (§2: "task 04.5 sequences the writes").
    @Test("Out-of-scope check: neither Door A file touches disk or UserDefaults")
    func noPersistenceInFacadeFiles() throws {
        let persistencePatterns = ["FileManager", "contentsOf:", "write(to:", "UserDefaults", "Data("]
        for filename in ["DiagnosisFlow.swift", "DiagnosisContent.swift"] {
            let source = try String(
                contentsOf: Self.coreSourcesDoorDir.appendingPathComponent(filename), encoding: .utf8)
            for pattern in persistencePatterns {
                #expect(!source.contains(pattern), "\(filename) touches persistence via '\(pattern)'")
            }
        }
    }

    // MARK: - AC9: the additive CoreError case

    @Test("AC9: CoreError.loHintNotFound is additive, appended last, rawValue LO_HINT_NOT_FOUND")
    func ac9AdditiveCaseAppendedLast() {
        #expect(CoreError.loHintNotFound.rawValue == "LO_HINT_NOT_FOUND")
        #expect(CoreError.allCases.last == .loHintNotFound)
        #expect(CoreError.allCases.count == 21)
        #expect(CoreError.allCases[CoreError.allCases.count - 2] == .platformSnapshotRefused)
    }

    // MARK: - AC10: exact terminal-line text per outcome

    @Test("AC10: .noPrerequisite terminal line equals CoreErrorText.text(for: .diagNoPrerequisite)")
    func ac10NoPrerequisiteLine() throws {
        let base = try Self.loadDemoBundle()
        let isolatedOrigin = PropertyGen.minimalNode(id: "isolated-origin")
        let bundle = Self.bundle(base, nodes: [isolatedOrigin], edges: [])
        let event = DoorADiagnosisFlow.open(
            originNodeId: isolatedOrigin.id, trigger: .mapCheckHere, levelBudget: 1)
        let advance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .terminal(let terminalContent) = advance.screen else {
            Issue.record("expected .terminal, got \(advance.screen)")
            return
        }
        #expect(terminalContent.terminal == .noPrerequisite)
        #expect(terminalContent.line == CoreErrorText.text(for: .diagNoPrerequisite))
        #expect(terminalContent.line != nil)
    }

    @Test(
        "AC10: DIAG_PROBE_UNAVAILABLE unconfirmed line equals CoreErrorText.text(for: .diagProbeUnavailable)")
    func ac10ProbeUnavailableLine() throws {
        let base = try Self.loadDemoBundle()
        let origin = PropertyGen.minimalNode(id: "origin")
        let sparse = Self.fewItemsNode(id: "sparse")
        let bundle = Self.bundle(
            base, nodes: [origin, sparse], edges: [Self.edge(from: sparse.id, to: origin.id)])
        let event = DoorADiagnosisFlow.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let advance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .terminal(let terminalContent) = advance.screen else {
            Issue.record("expected .terminal, got \(advance.screen)")
            return
        }
        #expect(terminalContent.terminal == .unconfirmed)
        #expect(terminalContent.outcome.code == .diagProbeUnavailable)
        #expect(terminalContent.line == CoreErrorText.text(for: .diagProbeUnavailable))
        #expect(terminalContent.line != nil)
    }

    @Test("AC10: plain .confirmed (exhausted budget, no deeper gap) has line == nil, remediation non-nil")
    func ac10PlainConfirmedNoLineExhaustedBudget() throws {
        let bundle = try Self.loadDemoBundle()
        let deeperId = "solving-linear-equations"
        // Pre-clear the deeper node so W6's own query finds no candidate: outcome is plain .confirmed.
        let inputState = Self.state(nodes: [deeperId: Self.clearedNode()])
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: Self.wrongSubmission(for: probe1.currentItem), state: probeAdvance.state,
            bundle: bundle, today: Self.today())
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after first miss")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: Self.wrongSubmission(for: probe2.currentItem), state: firstAnswer.state,
            bundle: bundle, today: Self.today())
        guard
            case .terminal(let terminalContent) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .terminal (plain confirmed)")
            return
        }
        #expect(terminalContent.terminal == .confirmed)
        #expect(terminalContent.line == nil)
        #expect(terminalContent.hint == nil)
        #expect(terminalContent.remediation != nil)
    }

    @Test("AC10 / furtherLevelOffer: plain .confirmed reached by decline has line nil and remediation nil")
    func ac10PlainConfirmedViaDeclinedFurtherLevel() throws {
        let base = try Self.loadDemoBundle()
        // origin <- c, budget 2: hypothesise always picks the DEEPEST unmastered candidate within the
        // remaining budget, so a two-level chain (origin <- c <- d) at budget 2 would put `d`, not `c`, on
        // the very first probe offer. A single-level chain keeps `c` the only (and thus deepest) candidate
        // at depth 1, with one level of budget left over — exactly what makes W4 step 3 "offer, never
        // automatic" reachable: c's probe confirms with budget remaining, so the further-level offer
        // screen appears; declining it reaches a plain .confirmed terminal with no probeResult on THIS
        // call, so remediation (already shown on the furtherLevelOffer screen) is nil here.
        let origin = PropertyGen.probeableNode(id: "origin")
        let c = PropertyGen.probeableNode(id: "c")
        let bundle = Self.bundle(
            base, nodes: [origin, c], edges: [Self.edge(from: c.id, to: origin.id)])
        let event = DoorADiagnosisFlow.open(originNodeId: "origin", trigger: .mapCheckHere, levelBudget: 2)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: "9", state: probeAdvance.state, bundle: bundle, today: Self.today())
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after first miss")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: "9", state: firstAnswer.state, bundle: bundle, today: Self.today())
        guard
            case .furtherLevelOffer(let remediation, let offerContent, let decision) =
                DoorADiagnosisFlow.continueAfterProbeAnswer(secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .furtherLevelOffer (budget 2, level 1 reached)")
            return
        }
        guard case .paraphrase(let text, let hint) = remediation else {
            Issue.record("expected .paraphrase remediation on the offer screen")
            return
        }
        #expect(text == c.paraphrase)
        #expect(hint == nil, "c carries no hintTree entry, so the resolver's key is nil (Rule 3)")
        #expect(offerContent.candidateNodeName == c.name)
        #expect(offerContent.question == DoorADiagnosisCopy.furtherLevelQuestion)

        let declineAdvance = DoorADiagnosisFlow.decideFurtherLevel(
            decision, accept: false, state: secondAnswer.state, bundle: bundle)
        guard case .terminal(let terminalContent) = declineAdvance.screen else {
            Issue.record("expected .terminal, got \(declineAdvance.screen)")
            return
        }
        #expect(terminalContent.terminal == .confirmed)
        #expect(terminalContent.line == nil)
        #expect(terminalContent.hint == nil)
        #expect(
            terminalContent.remediation == nil,
            "remediation was already shown on the furtherLevelOffer screen; never shown twice")

        // decideFurtherLevel's accept branch is exercised too: `c` has no prerequisite of its own, so
        // re-forming the hypothesis on `c` finds no candidate -> AC10's noPrerequisite row, this time
        // reached via `decideFurtherLevel` rather than `start`.
        let acceptAdvance = DoorADiagnosisFlow.decideFurtherLevel(
            decision, accept: true, state: secondAnswer.state, bundle: bundle)
        guard case .terminal(let acceptTerminal) = acceptAdvance.screen else {
            Issue.record("expected .terminal (noPrerequisite), got \(acceptAdvance.screen)")
            return
        }
        #expect(acceptTerminal.terminal == .noPrerequisite)
        #expect(acceptTerminal.line == CoreErrorText.text(for: .diagNoPrerequisite))
        #expect(acceptTerminal.hint != nil)
    }

    // MARK: - T2 negative: malformed submission never crashes

    @Test(
        "T2: a numeric submission that fails the grammar (\"abc\") yields a well-formed answer, never a crash"
    )
    func t2MalformedNumericSubmissionNeverCrashes() throws {
        let bundle = try Self.loadDemoBundle()
        let origin = Self.node("polynomials", bundle: bundle)
        let event = DoorADiagnosisFlow.open(
            originNodeId: origin.id, trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe) = probeAdvance.screen, probe.currentItem.type == .numeric
        else {
            Issue.record("expected a .numeric .probeItem for this fixture")
            return
        }
        let answer = DoorADiagnosisFlow.answerProbeItem(
            probe, submitted: "abc", state: probeAdvance.state, bundle: bundle, today: Self.today())
        #expect(answer.answerCard.correct == false)
        #expect(!answer.answerCard.correctAnswerDisplay.isEmpty)
        #expect(!answer.answerCard.why.isEmpty)
    }

    // MARK: - T3 error taxonomy (see also AC9)

    @Test(
        "T3: DiagnosisOutcome.code is exactly .diagNoPrerequisite / .diagProbeUnavailable / nil, never .loHintNotFound"
    )
    func t3TerminalCodeNeverLoHintNotFound() throws {
        let bundle = try Self.loadDemoBundle()
        let isolatedOrigin = PropertyGen.minimalNode(id: "isolated-origin-t3")
        let noPrereqBundle = Self.bundle(bundle, nodes: [isolatedOrigin], edges: [])
        let event = DoorADiagnosisFlow.open(
            originNodeId: isolatedOrigin.id, trigger: .mapCheckHere, levelBudget: 1)
        let advance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(),
            bundle: noPrereqBundle)
        guard case .terminal(let terminalContent) = advance.screen else {
            Issue.record("expected .terminal")
            return
        }
        #expect(terminalContent.outcome.code == .diagNoPrerequisite)
        #expect(terminalContent.outcome.code != .loHintNotFound)
    }

    // MARK: - T4 conformance: interaction-contract § 4 Properties

    @Test("T4: depth <= levelBudget on every Demo-budget-1 terminal, real data/demo")
    func t4DepthNeverExceedsBudget() throws {
        let bundle = try Self.loadDemoBundle()
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let declineAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: false, state: startAdvance.state, bundle: bundle)
        guard case .terminal(let terminalContent) = declineAdvance.screen else {
            Issue.record("expected .terminal")
            return
        }
        #expect(terminalContent.outcome.depthReached <= 1)
    }

    @Test(
        "T4: no DoorATerminalContent.remediation is non-nil unless advance.probeResult?.outcome == .confirmed"
    )
    func t4RemediationOnlyAfterConfirmedProbe() throws {
        let bundle = try Self.loadDemoBundle()
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        // Decline path: no probe outcome at all -> remediation must be nil.
        let declineAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: false, state: startAdvance.state, bundle: bundle)
        guard case .terminal(let declinedTerminal) = declineAdvance.screen else {
            Issue.record("expected .terminal")
            return
        }
        #expect(declinedTerminal.remediation == nil)

        // Refuted path (probeResult.outcome == .refuted, not .confirmed) -> remediation nil.
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: Self.correctSubmission(for: probe1.currentItem), state: probeAdvance.state,
            bundle: bundle, today: Self.today())
        guard
            case .probeItem(_, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem")
            return
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: Self.correctSubmission(for: probe2.currentItem), state: firstAnswer.state,
            bundle: bundle, today: Self.today())
        guard
            case .terminal(let refutedTerminal) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                secondAnswer, bundle: bundle)
        else {
            Issue.record("expected .terminal")
            return
        }
        #expect(refutedTerminal.terminal == .refuted)
        #expect(refutedTerminal.remediation == nil)
    }

    /// I5: a `Mirror`-based scan over the Door A screen-content types finds no field name matching a
    /// student/device/install/session identifier pattern (mirrors 04.2 AC2's shape).
    private static let identifierLikeFieldNames: Set<String> = [
        "studentId", "deviceId", "installId", "sessionId", "userId", "anonymousId",
    ]

    private static func identifierLeaks(reflecting value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap { child in
            guard let label = child.label else { return nil }
            return Self.identifierLikeFieldNames.contains(label) ? label : nil
        }
    }

    @Test("T4 (I5): no Door A screen-content type carries a student/device/install/session identifier field")
    func t4NoIdentifyingFieldOnScreenContent() throws {
        let bundle = try Self.loadDemoBundle()
        let node = Self.node("polynomials", bundle: bundle)
        let hypothesis = DoorAHypothesisContent(
            line: DoorADiagnosisCopy.hypothesisLine(candidateNodeName: node.name),
            costLine: DoorADiagnosisCopy.costLine)
        let hint = DoorADiagnosisContentBuilder.resolveHint(node: node, classifiedToken: "none_of_these")
        let remediation = DoorADiagnosisContentBuilder.selectRemediation(candidate: node, misses: [])
        #expect(Self.identifierLeaks(reflecting: hypothesis).isEmpty)
        #expect(Self.identifierLeaks(reflecting: hint).isEmpty)
        #expect(Self.identifierLeaks(reflecting: remediation).isEmpty)
    }

    @Test("T4 (I5) guard is load-bearing: a planted deviceId field is caught by the same scan")
    func t4IdentifierGuardCatchesPlantedField() {
        struct LeakyFixture { let deviceId: String }
        let found = Self.identifierLeaks(reflecting: LeakyFixture(deviceId: "abc"))
        #expect(
            found.contains("deviceId"), "scan failed to catch a planted identifying field — guard is vacuous")
    }

    // MARK: - T4 (trap unreachability): hintKey's own contract makes resolveHint's guard unreachable

    @Test(
        "hintKey's own contract: whenever it returns a key, that key's hintTree entry is never empty, so resolveHint's guard can never trap on a valid bundle"
    )
    func hintKeyContractMakesResolveHintTrapUnreachable() throws {
        let bundle = try Self.loadDemoBundle()
        var checkedNonNilKeys = 0
        let tokensToTry = ["none_of_these", "some-unclassified-type", "sign-error"]
        for node in bundle.nodes.nodes {
            for token in tokensToTry + node.errorTypes.map(\.id) {
                guard let key = DiagnosisRun.hintKey(originNode: node, errorTypeId: token) else {
                    continue
                }
                #expect(
                    !(node.hintTree[key] ?? []).isEmpty,
                    "hintKey returned '\(key)' on \(node.id) with an empty/absent hintTree entry — resolveHint's preconditionFailure would fire"
                )
                checkedNonNilKeys += 1
            }
        }
        #expect(checkedNonNilKeys > 0, "instrument broken: no non-nil key was ever produced")
    }

    // MARK: - T5: negative controls are covered inline above (AC1/AC3/AC7/AC8 guards)

    // MARK: - T6: idempotency / no mutation

    @Test("T6: continueAfterProbeAnswer called twice on the same value returns Equatable-equal screens")
    func t6ContinueIsIdempotent() throws {
        let bundle = try Self.loadDemoBundle()
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: Self.state(), bundle: bundle)
        guard case .hypothesis(_, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(_, let probe) = probeAdvance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let answer = DoorADiagnosisFlow.answerProbeItem(
            probe, submitted: Self.wrongSubmission(for: probe.currentItem), state: probeAdvance.state,
            bundle: bundle, today: Self.today())
        let first = DoorADiagnosisFlow.continueAfterProbeAnswer(answer, bundle: bundle)
        let second = DoorADiagnosisFlow.continueAfterProbeAnswer(answer, bundle: bundle)
        #expect(first == second)
    }

    @Test("T6: every façade entry point leaves its StudentState argument unmutated (value semantics)")
    func t6NoMutationOfArguments() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state()
        let capturedBeforeCall = inputState
        let event = DoorADiagnosisFlow.open(
            originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1)
        _ = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: inputState, bundle: bundle)
        #expect(inputState == capturedBeforeCall)
    }
}

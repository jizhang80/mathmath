import Foundation
import Testing

@testable import Core

/// The C1 real-composition seam (AC13, AC14 of
/// `tasks/epic-04-task-05-core-door-entries-persistence-seam.md`): drives a full expedition and a full
/// diagnosis on each trigger through `DoorFacade` only, over real `data/demo` and a temp-directory
/// `StudentStateStore`, with no stub on either side. These are the SAME entry points the Door buttons
/// call in 04b (arbiter-04 § Q-C: logic, composition and static wiring only).
@Suite("DoorFacade C1 seam (04.5)")
struct DoorFacadeSeamTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var demoBundleDir: URL { repoRoot.appendingPathComponent("data/demo") }

    private static func loadDemoBundle() throws -> ContentBundle { try BundleIO.read(from: demoBundleDir) }

    private static func today() throws -> CalendarDay {
        try #require(CalendarDay(iso: "2026-09-10"))
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private static func mth1wMarker(bundle: ContentBundle) throws -> Marker {
        try #require(MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle: bundle))
    }

    /// A fresh `MapState` on `MTH1W.u1`, over a fresh temp `stateURL` (never written until a
    /// `DoorFacade`/`StudentStateStore` call writes it).
    private static func mapState(
        bundle: ContentBundle, nodes: [String: NodeState] = [:], today: CalendarDay
    ) throws -> (map: MapState, stateURL: URL) {
        let marker = try Self.mth1wMarker(bundle: bundle)
        return try Self.mapState(bundle: bundle, marker: marker, nodes: nodes, today: today)
    }

    private static func mapState(
        bundle: ContentBundle, marker: Marker, nodes: [String: NodeState], today: CalendarDay
    ) throws -> (map: MapState, stateURL: URL) {
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        let state = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: ["MTH1W"],
            marker: marker, nodes: nodes, trail: report.trail, expeditionLog: [], probeLog: [],
            installDay: "2026-01-01", consentOn: true)
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let viewModel = MapViewModel.derive(bundle: bundle, state: state, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: state, viewModel: viewModel, queuedNodeId: nil)
        return (map, stateURL)
    }

    private static func decodeState(at url: URL) throws -> StudentState {
        try CoreCoding.decoder.decode(StudentState.self, from: try Data(contentsOf: url))
    }

    private static func correctSubmission(for item: ProbeItem) -> String {
        item.answer?.value ?? item.correctChoiceId ?? "unknown"
    }

    private static func wrongSubmission(for item: ProbeItem) -> String {
        if item.type == .mc, let correct = item.correctChoiceId,
            let choice = item.choices?.first(where: { $0.id != correct })
        {
            return choice.id
        }
        return item.wrongAnswers?.first?.value ?? "not-a-real-answer"
    }

    /// The item drawn for `nodeId` at this call: `-1` for the first try, `-2` for the retry (`selectItem`
    /// prefers the unused, lower-id item on a fresh `probeLog` — verified by `Expedition.selectItem`'s
    /// own least-recently-used/id tie-break rule).
    private static func item(nodeId: String, isRetry: Bool, bundle: ContentBundle) -> ProbeItem {
        guard let node = bundle.nodes.nodes.first(where: { $0.id == nodeId }) else {
            preconditionFailure("node \(nodeId) not found")
        }
        let items = node.probeItems.sorted { $0.id < $1.id }
        return isRetry ? items[1] : items[0]
    }

    private static func nodeName(_ id: String, bundle: ContentBundle) -> String {
        bundle.nodes.nodes.first(where: { $0.id == id })?.name ?? id
    }

    // MARK: - AC13: a full expedition, one deliberate first miss + retry, through summary

    @Test(
        "AC13: full expedition through DoorFacade only — start, one miss+retry, all-correct, to summary — every state-changing call writes the write-ahead value; continue never writes; the natural end writes exactly one abandoned:false entry; the re-derived map lifts fog on every cleared node"
    )
    func ac13FullExpeditionThroughFacade() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)

        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        #expect(start.writeFailureCode == nil)
        var runState = start.runState
        var screen = start.screen
        let expectedAfterStart = DoorBWriteAhead.provisionalAbandonedState(
            runState: start.runState.expedition!, state: built.state, today: today)
        #expect(try Self.decodeState(at: stateURL) == expectedAfterStart)

        var eventOrder: [CoreEvent] = [.expeditionStarted]
        var madeFirstMiss = false
        var answerCallCount = 0
        var finalEndState: StudentState?

        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let submitted: String
            if !madeFirstMiss && !content.isRetry {
                submitted = Self.wrongSubmission(for: item)
                madeFirstMiss = true
            } else {
                submitted = Self.correctSubmission(for: item)
            }

            let answer = DoorFacade.answer(runState, submitted: submitted, today: today)
            #expect(answer.writeFailureCode == nil)
            answerCallCount += 1
            eventOrder.append(contentsOf: answer.advance.events.filter { $0 == .expeditionItemAnswered })

            let expectedAfterAnswer: StudentState
            if let pendingEnd = answer.advance.pendingEnd {
                expectedAfterAnswer = pendingEnd.state
                finalEndState = pendingEnd.state
                eventOrder.append(pendingEnd.event)
            } else {
                expectedAfterAnswer = DoorBWriteAhead.provisionalAbandonedState(
                    runState: answer.advance.runState, state: answer.advance.state, today: today)
            }
            #expect(
                try Self.decodeState(at: stateURL) == expectedAfterAnswer, "missed write-ahead after answer")
            runState = answer.runState

            let beforeContinue = try Data(contentsOf: stateURL)
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            let afterContinue = try Data(contentsOf: stateURL)
            #expect(afterContinue == beforeContinue, "continueAfterAnswer must not write (arbiter-04 Q-A)")
            runState = cont.runState
            screen = cont.screen
        }

        #expect(answerCallCount >= 2, "fixture sanity: the u1/u2 fringe should offer >= 2 slots")
        guard case .summary(let summary) = screen else {
            Issue.record("expected .summary, got \(screen)")
            return
        }
        let endState = try #require(finalEndState)
        #expect(try Self.decodeState(at: stateURL) == endState)
        #expect(endState.expeditionLog.count == 1)
        #expect(endState.expeditionLog[0].abandoned == false)

        // I3/Q-A: the event order is expedition.started, then one expedition.item_answered per answer
        // call, then expedition.completed — never anything else, never out of order.
        let expectedOrder =
            [CoreEvent.expeditionStarted] + Array(repeating: .expeditionItemAnswered, count: answerCallCount)
            + [.expeditionCompleted]
        #expect(eventOrder == expectedOrder)

        // The summary's own lists equal the run's.
        let clearedIds = runState.expedition!.run.clearedNodeIds
        let blockedIds = runState.expedition!.run.blockedNodeIds
        #expect(summary.clearedNodeNames == clearedIds.map { Self.nodeName($0, bundle: bundle) })
        #expect(summary.blockedNodeNames == blockedIds.map { Self.nodeName($0, bundle: bundle) })

        // Re-deriving MapViewModel from the final file contents shows the fog lifted on every cleared node.
        let finalFileState = try Self.decodeState(at: stateURL)
        let viewModel = MapViewModel.derive(bundle: bundle, state: finalFileState, today: today)
        for id in clearedIds {
            let nodeView = try #require(viewModel.nodes.first(where: { $0.id == id }))
            #expect(nodeView.fogLevel == .cleared)
        }
    }

    // MARK: - AC14(a): expedition_second_miss, capped, then resumed with the candidate blocked

    @Test(
        "AC14(a): expedition_second_miss -> hypothesis -> two wrong probes -> .capped -> resumeAfterDiagnosis -> the run resumes with the candidate blocked in the threaded state"
    )
    func ac14aExpeditionSecondMissCappedThenResumed() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        // Marker at MTH1W.u4 (window = u4 only): "simplifying-expressions" pre-cleared (so it neither
        // occupies its own slot nor counts as an unmastered prerequisite); "exponent-laws" blocked +
        // remediated (satisfies "polynomials"'s prerequisite guard for both its parents, and is itself
        // unmastered at depth 1 from "polynomials" per `PrerequisiteQuery`'s Q2 rule); its own real
        // prerequisite "solving-linear-equations" is left fog, giving the W6 budget-exhausted query a
        // deeper candidate to find, which is exactly what makes the outcome `.capped` rather than plain
        // `.confirmed` (mirrors `DiagnosisFlowComprehensiveTests.ac4CappedOnRealDemoNoInterveningFurtherLevelOffer`).
        let cleared = NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
            ladderRung: 0, remediated: nil)
        let blockedRemediated = NodeState(
            mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: true)
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: false)
        let (built, stateURL) = try Self.mapState(
            bundle: bundle, marker: marker,
            nodes: ["simplifying-expressions": cleared, "exponent-laws": blockedRemediated], today: today)
        // Include "polynomials" so it is the run's FIRST slot (AC1's own queue mechanism): the second miss
        // then happens on the very first screen, before "exponent-laws"'s own compose-drawn slot is ever
        // reached/answered, so both of its items stay unused for the probe.
        let (included, includeOutcome, _) = MapFacade.include(nodeId: "polynomials", mapState: built)
        #expect(includeOutcome == .queued)

        let start = try DoorFacade.startExpedition(mapState: included, today: today)
        var runState = start.runState
        var screen = start.screen
        let targetNodeId = "polynomials"
        var diagnosisScreen: DoorADiagnosisScreen?

        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let submitted =
                content.nodeId == targetNodeId
                ? Self.wrongSubmission(for: item) : Self.correctSubmission(for: item)
            let answer = DoorFacade.answer(runState, submitted: submitted, today: today)
            runState = answer.runState
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            runState = cont.runState
            screen = cont.screen
            if case .diagnosis(let diagScreen) = screen {
                diagnosisScreen = diagScreen
                break
            }
        }

        guard case .hypothesis(_, let offer) = try #require(diagnosisScreen) else {
            Issue.record("expected .hypothesis")
            return
        }
        let candidateId = offer.candidateId
        #expect(candidateId == "exponent-laws")

        let probeAdvance = DoorFacade.decideProbe(offer, accept: true, runState: runState, today: today)
        runState = probeAdvance.runState
        guard case .probeItem(_, let probe1) = probeAdvance.advance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let ans1 = DoorFacade.answerProbeItem(
            probe1, submitted: Self.wrongSubmission(for: probe1.currentItem), runState: runState,
            today: today)
        runState = ans1.runState
        guard
            case .probeItem(_, let probe2) = DoorFacade.continueAfterProbeAnswer(
                ans1.advance, runState: runState)
        else {
            Issue.record("expected the second .probeItem")
            return
        }
        let ans2 = DoorFacade.answerProbeItem(
            probe2, submitted: Self.wrongSubmission(for: probe2.currentItem), runState: runState,
            today: today)
        runState = ans2.runState
        #expect(ans2.advance.events.last == .diagnosisReturned)

        guard
            case .terminal(let terminalContent) = DoorFacade.continueAfterProbeAnswer(
                ans2.advance, runState: runState)
        else {
            Issue.record("expected .terminal (capped), no intervening furtherLevelOffer at Demo budget 1")
            return
        }
        #expect(terminalContent.terminal == .capped)
        #expect(terminalContent.remediation != nil)
        #expect(terminalContent.outcome.state.nodes[candidateId]?.mastery == .blocked)
        #expect(terminalContent.outcome.state.nodes["solving-linear-equations"]?.mastery == .blocked)

        let resume = DoorFacade.resumeAfterDiagnosis(runState, outcome: terminalContent.outcome, today: today)
        #expect(resume.writeFailureCode == nil)
        #expect(resume.advance.state.nodes[candidateId]?.mastery == .blocked)
        runState = resume.runState
        screen = resume.advance.screen

        // Drain the remainder of the run (correctly) to a natural end.
        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let answer = DoorFacade.answer(
                runState, submitted: Self.correctSubmission(for: item), today: today)
            runState = answer.runState
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            runState = cont.runState
            screen = cont.screen
        }
        guard case .summary = screen else {
            Issue.record("expected .summary, got \(screen)")
            return
        }
        let final = try Self.decodeState(at: stateURL)
        #expect(final.nodes[candidateId]?.mastery == .blocked)
        #expect(final.expeditionLog.count == 1)
        #expect(final.expeditionLog[0].abandoned == false)
        #expect(final.expeditionLog[0].diagnosisEvents == 1)
    }

    // MARK: - AC14(b): map_check_here, decline -> .unconfirmed

    @Test("AC14(b): map_check_here, decline -> .unconfirmed, hint non-nil, events end .diagnosisReturned")
    func ac14bMapCheckHereDeclineReachesUnconfirmed() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)

        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        #expect(opened.runState.expedition == nil)
        guard case .hypothesis(_, let offer) = opened.screen else {
            Issue.record("expected .hypothesis")
            return
        }

        let declineAdvance = DoorFacade.decideProbe(
            offer, accept: false, runState: opened.runState, today: today)
        guard case .terminal(let terminalContent) = declineAdvance.advance.screen else {
            Issue.record("expected .terminal")
            return
        }
        #expect(terminalContent.terminal == .unconfirmed)
        #expect(terminalContent.hint != nil)
        #expect(declineAdvance.advance.events.last == .diagnosisReturned)
    }

    // MARK: - AC14(c): map_check_here, refuted

    @Test("AC14(c): map_check_here, both probes correct -> .refuted, events end .diagnosisReturned")
    func ac14cMapCheckHereBothCorrectReachesRefuted() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)

        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        guard case .hypothesis(_, let offer) = opened.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorFacade.decideProbe(
            offer, accept: true, runState: opened.runState, today: today)
        guard case .probeItem(_, let probe1) = probeAdvance.advance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let ans1 = DoorFacade.answerProbeItem(
            probe1, submitted: Self.correctSubmission(for: probe1.currentItem),
            runState: probeAdvance.runState,
            today: today)
        guard
            case .probeItem(_, let probe2) = DoorFacade.continueAfterProbeAnswer(
                ans1.advance, runState: ans1.runState)
        else {
            Issue.record("expected the second .probeItem")
            return
        }
        let ans2 = DoorFacade.answerProbeItem(
            probe2, submitted: Self.correctSubmission(for: probe2.currentItem), runState: ans1.runState,
            today: today)
        #expect(ans2.advance.events.last == .diagnosisReturned)

        guard
            case .terminal(let terminalContent) = DoorFacade.continueAfterProbeAnswer(
                ans2.advance, runState: ans2.runState)
        else {
            Issue.record("expected .terminal")
            return
        }
        #expect(terminalContent.terminal == .refuted)
    }
}

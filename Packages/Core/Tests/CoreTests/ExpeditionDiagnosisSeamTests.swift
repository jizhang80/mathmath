import Foundation
import Testing

@testable import Core

/// C1 seam test (AC12): a real `ExpeditionRun.start`/`.answer` sequence on real `data/demo` reaches a
/// second miss, real step-wise `DiagnosisRun` calls drive that miss to a terminal, and
/// `ExpeditionRun.resume(run:)` continues the same run at its next item with the terminal's `StudentState`
/// threaded into the next `ExpeditionRun.answer`. Neither side is stubbed
/// (`docs/epics/epic-02-core-behaviour.md` §4 item 7).
@Suite("C1 seam: ExpeditionRun <-> DiagnosisRun")
struct ExpeditionDiagnosisSeamTests {
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

    @Test("AC12: a second miss opens a real diagnosis that resumes the same suspended run")
    func secondMissOpensRealDiagnosisThenResumes() throws {
        let bundle = try Self.loadDemoBundle()
        let compose = ComposeResult(
            slots: [
                ComposeSlot(
                    nodeId: "exponent-laws",
                    item: try Self.probeItem(
                        bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1"),
                    kind: .newLearning),
                ComposeSlot(
                    nodeId: "polynomials",
                    item: try Self.probeItem(bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1"),
                    kind: .newLearning),
                ComposeSlot(
                    nodeId: "simplifying-expressions",
                    item: try Self.probeItem(
                        bundle: bundle, nodeId: "simplifying-expressions",
                        itemId: "simplifying-expressions-1"), kind: .newLearning),
            ], skippedNodeIds: [])
        let inputState = Self.state(nodes: [:])
        let run0 = ExpeditionRun.start(compose: compose).run

        // exponent-laws: two real misses -> a real diagnosis opens at exponent-laws.
        let miss1 = ExpeditionRun.answer(
            run: run0, state: inputState, bundle: bundle, submitted: "0", today: Self.today())
        let miss2 = ExpeditionRun.answer(
            run: miss1.run, state: miss1.state, bundle: bundle, submitted: "0", today: Self.today())
        #expect(miss2.events.contains(.expeditionDiagnosisRequested))
        #expect(miss2.run.diagnosisUsed == true)
        let originNodeId = try #require(miss2.run.suspendedForDiagnosisNodeId)
        #expect(originNodeId == "exponent-laws")

        // Real, step-wise DiagnosisRun calls (none stubbed): the missed items become ItemMisses
        // (§6 decision default).
        let misses = [
            ItemMiss(
                item: try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1"),
                submittedValue: "0"),
            ItemMiss(
                item: try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-2"),
                submittedValue: "0"),
        ]
        let event = DiagnosisRun.open(
            originNodeId: originNodeId, trigger: .expeditionSecondMiss, levelBudget: 1)
        let startAdvance = DiagnosisRun.start(
            event: event, misses: misses, shownItemIdsInRun: miss2.run.shownItemIds,
            state: miss2.state, bundle: bundle)
        guard case .probeOffer(let offer) = startAdvance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        let candidateId = offer.candidateId

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

        // Exactly one diagnosis is driven; the probed candidate is blocked+remediated in the threaded
        // state.
        #expect(outcome.state.nodes[candidateId]?.mastery == .blocked)
        #expect(outcome.state.nodes[candidateId]?.remediated == true)

        // Real ExpeditionRun.resume, then one more real .answer with the diagnosis's own StudentState.
        let resumedRun = ExpeditionRun.resume(run: miss2.run)
        #expect(resumedRun.suspendedForDiagnosisNodeId == nil)
        #expect(resumedRun.currentItem?.nodeId == "polynomials")

        let nextAnswer = ExpeditionRun.answer(
            run: resumedRun, state: outcome.state, bundle: bundle, submitted: "4", today: Self.today())
        #expect(nextAnswer.run.diagnosisUsed == true)

        // Every pre-diagnosis ItemResult is still present after resume.
        #expect(miss2.run.results.map(\.itemId) == ["exponent-laws-1", "exponent-laws-2"])
        #expect(resumedRun.results == miss2.run.results)
        for result in miss2.run.results {
            #expect(nextAnswer.run.results.contains(result))
        }
    }
}

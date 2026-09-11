import Foundation
import Testing

@testable import Core

/// AC11 (I2): every diagnosis terminal is reached by step-API calls over the real `data/demo` bundle at
/// Demo budget 1, with no adapter parameter anywhere in the call chain — `Core`'s own proof that Tier 0
/// alone is a usable product.
@Suite("DiagnosisRun: Tier-0 completeness (AC11, I2)")
struct DiagnosisTier0CompletenessTests {
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

    private static func clearedNode() -> NodeState {
        NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    private static func blockedNode() -> NodeState {
        NodeState(
            mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    @Test("noPrerequisite: a real leaf node (no incoming edges) reaches DIAG_NO_PREREQUISITE")
    func noPrerequisiteReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        // `integer-operations` is never the `to` of any real edge (it is the graph's own root).
        #expect(!bundle.edges.edges.contains { $0.to == "integer-operations" })
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "integer-operations", misses: [],
            levelBudget: 1, decisions: [], shownItemIdsInRun: [], state: Self.state(nodes: [:]),
            bundle: bundle, today: Self.today())
        #expect(outcome.terminal == .noPrerequisite)
        #expect(outcome.code == .diagNoPrerequisite)
    }

    @Test("refuted: passing both probe items on a real candidate returns .refuted")
    func refutedReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["6", "a"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: Self.state(nodes: [:]), bundle: bundle,
            today: Self.today())
        #expect(outcome.terminal == .refuted)
        #expect(outcome.state.nodes["exponent-laws"] == nil)
    }

    @Test("confirmed (AC6b recipe): exhausted budget with a cleared deeper prerequisite returns .confirmed")
    func confirmedReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let inputState = Self.state(nodes: ["solving-linear-equations": Self.clearedNode()])
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["wrong", "wrong"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: inputState, bundle: bundle, today: Self.today())
        #expect(outcome.terminal == .confirmed)
        #expect(outcome.state.nodes["exponent-laws"]?.remediated == true)
    }

    @Test("capped (AC6 recipe): budget 1 with a fog deeper prerequisite returns .capped")
    func cappedReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(
                    declineProbe: false, submittedAnswers: ["wrong", "wrong"], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: Self.state(nodes: [:]), bundle: bundle,
            today: Self.today())
        #expect(outcome.terminal == .capped)
        #expect(outcome.blockedNodeIds == ["exponent-laws", "solving-linear-equations"])
    }

    @Test("unconfirmed-declined: declining the probe on a real candidate returns .unconfirmed")
    func unconfirmedDeclinedReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: [
                DiagnosisLevelDecision(declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)
            ], shownItemIdsInRun: [], state: Self.state(nodes: [:]), bundle: bundle,
            today: Self.today())
        #expect(outcome.terminal == .unconfirmed)
        #expect(outcome.code == nil)
    }

    /// DIAG_PROBE_UNAVAILABLE via the arbiter's exact constructed-state recipe
    /// (`tasks/arbitration/arbiter-02-predispatch.md` Ruling [Q-G] "Reachability"): `exponent-laws` is
    /// missed once, then its retry is answered correctly, so both its items have been shown in the run;
    /// `polynomials` is then missed twice, opening a diagnosis whose candidate (`exponent-laws`, 0.95
    /// confidence, over `simplifying-expressions`'s cleared 0.7) has 0 available items left. The
    /// `shownItemIds` set comes from a real `ExpeditionRun`, not a hand-built value.
    @Test("unconfirmed-unavailable (Q-G recipe): DIAG_PROBE_UNAVAILABLE via a real ExpeditionRun")
    func unconfirmedUnavailableReachedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let exponentLawsNode = try #require(bundle.nodes.nodes.first { $0.id == "exponent-laws" })
        let exponentLawsItem1 = try #require(
            exponentLawsNode.probeItems.first { $0.id == "exponent-laws-1" })
        let polynomialsNode = try #require(bundle.nodes.nodes.first { $0.id == "polynomials" })
        let polynomialsItem1 = try #require(
            polynomialsNode.probeItems.first { $0.id == "polynomials-1" })
        let compose = ComposeResult(
            slots: [
                ComposeSlot(nodeId: "exponent-laws", item: exponentLawsItem1, kind: .newLearning),
                ComposeSlot(nodeId: "polynomials", item: polynomialsItem1, kind: .newLearning),
            ], skippedNodeIds: [])
        let inputState = Self.state(nodes: [
            "exponent-laws": Self.blockedNode(), "polynomials": Self.blockedNode(),
            "simplifying-expressions": Self.clearedNode(),
        ])
        let run0 = ExpeditionRun.start(compose: compose).run

        // exponent-laws: missed, then its retry answered correctly — both its items now shown.
        let miss1 = ExpeditionRun.answer(
            run: run0, state: inputState, bundle: bundle, submitted: "0", today: Self.today())
        #expect(miss1.run.currentItem?.item.id == "exponent-laws-2")
        let retry = ExpeditionRun.answer(
            run: miss1.run, state: miss1.state, bundle: bundle, submitted: "a", today: Self.today())
        #expect(retry.run.shownItemIds == ["exponent-laws-1", "exponent-laws-2"])

        // polynomials: missed twice — the second miss opens a diagnosis.
        let polyMiss1 = ExpeditionRun.answer(
            run: retry.run, state: retry.state, bundle: bundle, submitted: "0", today: Self.today())
        let polyMiss2 = ExpeditionRun.answer(
            run: polyMiss1.run, state: polyMiss1.state, bundle: bundle, submitted: "0",
            today: Self.today())
        #expect(polyMiss2.events.contains(.expeditionDiagnosisRequested))
        #expect(polyMiss2.run.suspendedForDiagnosisNodeId == "polynomials")

        let event = DiagnosisRun.open(
            originNodeId: "polynomials", trigger: .expeditionSecondMiss, levelBudget: 1)
        let advance = DiagnosisRun.start(
            event: event, misses: [], shownItemIdsInRun: polyMiss2.run.shownItemIds,
            state: polyMiss2.state, bundle: bundle)
        guard case .probeOffer(let offer) = advance.step else {
            Issue.record("expected .probeOffer")
            return
        }
        #expect(offer.candidateId == "exponent-laws")
        let probeAdvance = DiagnosisRun.decideProbe(
            offer, accept: true, state: advance.state, bundle: bundle)
        guard case .returned(let outcome) = probeAdvance.step else {
            Issue.record("expected .returned")
            return
        }
        #expect(outcome.terminal == .unconfirmed)
        #expect(outcome.code == .diagProbeUnavailable)
        #expect(probeAdvance.probeResult?.outcome == .unavailable)
        #expect(!probeAdvance.events.contains(.diagnosisProbeCompleted))
    }

    @Test("no adapter parameter exists on any public DiagnosisRun function (I2)")
    func noAdapterParameterAnywhere() throws {
        let source = try String(
            contentsOf: Self.testsDir
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/Core/Diagnosis/DiagnosisEvent.swift"), encoding: .utf8)
        #expect(!source.lowercased().contains("adapter"))
    }
}

import Foundation
import Testing

@testable import Core

/// This task's own companion smoke test for `DoorBExpeditionFlow` (AC1, AC2, AC9): a full expedition
/// driven entirely through the façade on real `data/demo`, with every item answered correctly, proving the
/// answer-card-then-continue wiring (I3) reaches a `.summary` screen with no diagnosis hand-off.
@Suite("DoorBExpeditionFlow")
struct ExpeditionFlowTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()  // CoreTests
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

    @Test("T1: a full correctly-answered run reaches the summary through start/answer/continue only")
    func fullRunReachesSummaryThroughFacade() throws {
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
        var inputState = Self.state(nodes: [:])

        let start = DoorBExpeditionFlow.start(compose: compose)
        guard case .item(let firstItem) = start.screen else {
            Issue.record("expected .item")
            return
        }
        #expect(firstItem.nodeId == "exponent-laws")

        let answers: [(String, String)] = [
            ("exponent-laws", "6"), ("polynomials", "4"), ("simplifying-expressions", "8"),
        ]
        var runState = start.runState
        var lastScreen: DoorBScreen?
        for (nodeId, correctSubmission) in answers {
            let answer = DoorBExpeditionFlow.answer(
                runState, submitted: correctSubmission, state: inputState, bundle: bundle,
                today: Self.today())
            // I3: the answer call's own output is only the answer card, never a next screen.
            #expect(answer.answerCard.correct == true)
            #expect(answer.result.nodeId == nodeId)
            inputState = answer.state
            let advance = DoorBExpeditionFlow.continueAfterAnswer(answer, bundle: bundle)
            runState = advance.runState
            lastScreen = advance.screen
        }

        guard case .summary(let summary) = lastScreen else {
            Issue.record("expected .summary after the last correct answer")
            return
        }
        #expect(summary.itemCount == 3)
        #expect(summary.clearedNodeNames.isEmpty)
        #expect(summary.blockedNodeNames.isEmpty)
        #expect(summary.startAnotherLabel == DoorBSummaryCopy.startAnotherLabel)
        #expect(summary.backToMapLabel == DoorBSummaryCopy.backToMapLabel)
        #expect(runState.run.currentItem == nil)
    }
}

import Foundation
import Testing

@testable import Core

/// Task 04.3's own smoke test for the Door A façade (`Sources/Core/Door/DiagnosisFlow.swift`,
/// `Sources/Core/Door/DiagnosisContent.swift`): the happy path proving the seam wires together end to end
/// over real `data/demo` — `open`/`start`/`decideProbe`/`answerProbeItem`/`continueAfterProbeAnswer`
/// deriving every diagnosis screen's content, ending at a Demo-budget-1 `.capped` terminal with
/// remediation and no hint (I3, I4). The comprehensive AC1-AC10 suite is the tester's follow-on work.
@Suite("DoorADiagnosisFlow")
struct DiagnosisFlowTests {
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

    private static func state() -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MCR3U"],
            marker: Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: false), nodes: [:],
            trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    private static func node(_ id: String, bundle: ContentBundle) -> Node {
        guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
            preconditionFailure("node \(id) not found")
        }
        return match
    }

    @Test(
        "smoke: expedition_second_miss on real data/demo runs open -> start -> decideProbe -> answerProbeItem x2 -> continueAfterProbeAnswer, reaching .capped at Demo budget 1"
    )
    func expeditionSecondMissFullRunReachesCapped() throws {
        let bundle = try Self.loadDemoBundle()
        let origin = Self.node("polynomials", bundle: bundle)
        let inputState = Self.state()

        let event = DoorADiagnosisFlow.open(
            originNodeId: origin.id, trigger: .expeditionSecondMiss, levelBudget: 1)
        #expect(event.levelBudget == 1)

        let misses = [
            ItemMiss(item: origin.probeItems[0], submittedValue: "3"),
            ItemMiss(item: origin.probeItems[1], submittedValue: "b"),
        ]
        let startAdvance = DoorADiagnosisFlow.start(
            event: event, misses: misses, shownItemIdsInRun: [], state: inputState, bundle: bundle)
        guard case .hypothesis(let hypothesisContent, let offer) = startAdvance.screen else {
            Issue.record("expected .hypothesis, got \(startAdvance.screen)")
            return
        }
        let candidate = Self.node(offer.candidateId, bundle: bundle)
        #expect(
            hypothesisContent.line
                == DoorADiagnosisCopy.hypothesisLine(candidateNodeName: candidate.name))
        #expect(hypothesisContent.costLine == DoorADiagnosisCopy.costLine)

        let probeAdvance = DoorADiagnosisFlow.decideProbe(
            offer, accept: true, state: startAdvance.state, bundle: bundle)
        guard case .probeItem(let itemContent1, let probe1) = probeAdvance.screen else {
            Issue.record("expected .probeItem, got \(probeAdvance.screen)")
            return
        }
        #expect(itemContent1.nodeId == candidate.id)

        // Both probe items submitted wrong, tagged distractors -> confirmed -> W4 remediation -> W6
        // capped (Demo budget 1, no furtherLevelOffer screen).
        let wrongSubmission1 = candidate.probeItems[0].wrongAnswers?.first?.value ?? "wrong"
        let firstAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe1, submitted: wrongSubmission1, state: probeAdvance.state, bundle: bundle,
            today: Self.today())
        #expect(firstAnswer.answerCard.correct == false)
        #expect(firstAnswer.answerCard.why == firstAnswer.itemResult.why)

        guard
            case .probeItem(let itemContent2, let probe2) = DoorADiagnosisFlow.continueAfterProbeAnswer(
                firstAnswer, bundle: bundle)
        else {
            Issue.record("expected .probeItem after first answer")
            return
        }
        #expect(itemContent2.nodeId == candidate.id)

        let wrongSubmission2: String
        if let choice = candidate.probeItems[1].choices?.first(where: { $0.errorTypeId != nil }) {
            wrongSubmission2 = choice.id
        } else {
            wrongSubmission2 = candidate.probeItems[1].wrongAnswers?.first?.value ?? "wrong"
        }
        let secondAnswer = DoorADiagnosisFlow.answerProbeItem(
            probe2, submitted: wrongSubmission2, state: firstAnswer.state, bundle: bundle,
            today: Self.today())
        #expect(secondAnswer.answerCard.correct == false)

        let finalScreen = DoorADiagnosisFlow.continueAfterProbeAnswer(secondAnswer, bundle: bundle)
        guard case .terminal(let terminalContent) = finalScreen else {
            Issue.record("expected .terminal, got \(finalScreen)")
            return
        }

        #expect(terminalContent.terminal == .capped)
        #expect(terminalContent.line == DoorADiagnosisCopy.cappedLine)
        #expect(terminalContent.hint == nil)
        #expect(terminalContent.remediation != nil)
        if case .paraphrase(let text, let hint) = terminalContent.remediation {
            #expect(text == candidate.paraphrase)
            #expect(hint != nil)
        } else {
            Issue.record("expected .paraphrase remediation on real data/demo")
        }
        #expect(terminalContent.outcome.state.nodes[candidate.id]?.mastery == .blocked)
        #expect(terminalContent.outcome.state.nodes[candidate.id]?.remediated == true)

        // I3: the same DoorAProbeAnswerAdvance value drives the next screen only through
        // `continueAfterProbeAnswer`, and calling it again yields an Equatable-equal screen.
        let repeatedScreen = DoorADiagnosisFlow.continueAfterProbeAnswer(secondAnswer, bundle: bundle)
        #expect(repeatedScreen == finalScreen)

        #expect(secondAnswer.events.contains(.diagnosisProbeCompleted))
        #expect(secondAnswer.events.contains(.diagnosisNodeBlocked))
        #expect(secondAnswer.events.contains(.diagnosisRemediationShown))
        #expect(secondAnswer.events.contains(.diagnosisCapped))
        #expect(secondAnswer.events.last == .diagnosisReturned)
    }
}

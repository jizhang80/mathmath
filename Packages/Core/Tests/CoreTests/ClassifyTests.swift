import Foundation
import Testing

@testable import Core

/// Task 02.10's own companion test suite for `Classify.classify`
/// (`Sources/Core/Diagnosis/Classify.swift`), written against
/// `tasks/epic-02-task-10-prerequisite-query-classify.md`.
@Suite("Classify.classify")
struct ClassifyTests {
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

    // MARK: - T1 happy path / AC4

    @Test("AC4: every tagged wrong answer / distractor choice in data/demo round-trips through classify")
    func everyTaggedEntryRoundTrips() throws {
        let bundle = try Self.loadDemoBundle()
        var checkedAtLeastOne = false
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                switch item.type {
                case .numeric:
                    for wrongAnswer in item.wrongAnswers ?? [] {
                        checkedAtLeastOne = true
                        #expect(wrongAnswer.errorTypeId != "none-of-these")
                        let attempt = FailedProbeAttempt(item: item, submittedValue: wrongAnswer.value)
                        #expect(Classify.classify([attempt]) == wrongAnswer.errorTypeId)
                    }
                case .mc:
                    for choice in item.choices ?? [] {
                        guard let errorTypeId = choice.errorTypeId else { continue }
                        checkedAtLeastOne = true
                        #expect(errorTypeId != "none-of-these")
                        let attempt = FailedProbeAttempt(item: item, submittedValue: choice.id)
                        #expect(Classify.classify([attempt]) == errorTypeId)
                    }
                }
            }
        }
        #expect(checkedAtLeastOne, "data/demo must carry at least one tagged wrong answer or distractor")
    }

    // MARK: - T2 negative / AC5

    @Test("AC5: a submitted value matching no wrongAnswers[].value and no choices[].id returns none_of_these")
    func unmatchedSubmissionReturnsNoneOfThese() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first { $0.id == "exponent-laws" })
        let item = try #require(node.probeItems.first)
        let attempt = FailedProbeAttempt(item: item, submittedValue: "definitely-not-a-real-answer")
        #expect(Classify.classify([attempt]) == "none_of_these")
    }

    // MARK: - T5 negative controls

    @Test("Classify.classify([]) returns exactly \"none_of_these\" (underscore, not hyphen)")
    func emptyAttemptsReturnsUnderscoreSentinel() {
        #expect(Classify.classify([]) == "none_of_these")
        #expect(Classify.classify([]) != "none-of-these")
    }

    // MARK: - T6 idempotency

    @Test("calling twice with identical arguments returns an equal result")
    func idempotentOnRepeatedCall() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first { $0.id == "exponent-laws" })
        let item = try #require(node.probeItems.first)
        let attempt = FailedProbeAttempt(item: item, submittedValue: "definitely-not-a-real-answer")
        #expect(Classify.classify([attempt]) == Classify.classify([attempt]))
    }
}

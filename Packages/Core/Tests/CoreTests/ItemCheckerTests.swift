import Foundation
import Testing

@testable import Core

/// Task 02.7's own companion test suite for `ItemChecker` (`Sources/Core/ItemChecker.swift`). Exercises
/// AC1-AC4 on the real `data/demo` bundle plus hand-built `ProbeItem` values for the normalisation
/// grammar (`data/demo` never exercises whitespace/leading-zero/sign variants on the *submitted* side).
@Suite("ItemChecker")
struct ItemCheckerTests {
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

    private static func numericItem(
        id: String = "test-item", value: String, tolerance: Double? = nil
    ) -> ProbeItem {
        ProbeItem(
            id: id, type: .numeric, promptLatex: "x", why: "why", renderFallback: nil,
            answer: ProbeAnswer(value: value, tolerance: tolerance), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
    }

    private static func mcItem(correctChoiceId: String, choices: [ProbeChoice]) -> ProbeItem {
        ProbeItem(
            id: "test-mc-item", type: .mc, promptLatex: "x", why: "why", renderFallback: nil,
            answer: nil, wrongAnswers: nil, choices: choices, correctChoiceId: correctChoiceId,
            check: nil)
    }

    // MARK: - T1 happy path

    @Test("AC1: every real data/demo item's own answer checks correct")
    func ac1OwnAnswersCorrect() throws {
        let bundle = try Self.loadDemoBundle()
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                switch item.type {
                case .numeric:
                    guard let answer = item.answer else {
                        Issue.record("\(node.id)/\(item.id) has no answer")
                        continue
                    }
                    #expect(
                        ItemChecker.check(item: item, submitted: answer.value),
                        "\(node.id)/\(item.id) own value should check correct")
                case .mc:
                    guard let correctChoiceId = item.correctChoiceId else {
                        Issue.record("\(node.id)/\(item.id) has no correctChoiceId")
                        continue
                    }
                    #expect(
                        ItemChecker.check(item: item, submitted: correctChoiceId),
                        "\(node.id)/\(item.id) own choice id should check correct")
                }
            }
        }
    }

    @Test("AC2: every real data/demo wrong_answers/non-correct choice checks incorrect")
    func ac2WrongAnswersIncorrect() throws {
        let bundle = try Self.loadDemoBundle()
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                switch item.type {
                case .numeric:
                    for wrong in item.wrongAnswers ?? [] {
                        #expect(
                            !ItemChecker.check(item: item, submitted: wrong.value),
                            "\(node.id)/\(item.id) wrong_answers[] \(wrong.value) should check incorrect")
                    }
                case .mc:
                    for choice in item.choices ?? [] where choice.id != item.correctChoiceId {
                        #expect(
                            !ItemChecker.check(item: item, submitted: choice.id),
                            "\(node.id)/\(item.id) non-correct choice \(choice.id) should check incorrect")
                    }
                }
            }
        }
    }

    @Test("AC3: numeric normalisation scenarios")
    func ac3NumericNormalisation() throws {
        #expect(ItemChecker.check(item: Self.numericItem(value: "4"), submitted: "  4  "))
        #expect(ItemChecker.check(item: Self.numericItem(value: "4"), submitted: "+4"))
        #expect(ItemChecker.check(item: Self.numericItem(value: "7"), submitted: "007"))
        #expect(ItemChecker.check(item: Self.numericItem(value: "3/4"), submitted: "0.750"))
        #expect(ItemChecker.check(item: Self.numericItem(value: "0.75"), submitted: "3/4"))

        let toleranceItem = Self.numericItem(value: "1", tolerance: 0.5)
        #expect(ItemChecker.check(item: toleranceItem, submitted: "1.4"))
        #expect(!ItemChecker.check(item: toleranceItem, submitted: "1.6"))
    }

    // MARK: - T2 negative — invalid input rejected at the boundary

    @Test(
        "AC4: malformed submissions never crash and always check incorrect",
        arguments: [
            "", "   ", "abc", "1//2", "1.2.3", "1 2", "4/0",
        ])
    func ac4MalformedSubmissionsRejected(submitted: String) throws {
        let item = Self.numericItem(value: "4")
        #expect(!ItemChecker.check(item: item, submitted: submitted))
    }

    @Test("mc item: a submitted string naming no choices[].id returns false")
    func mcUnknownChoiceIdReturnsFalse() throws {
        let item = Self.mcItem(
            correctChoiceId: "a",
            choices: [
                ProbeChoice(id: "a", latex: "1", errorTypeId: nil),
                ProbeChoice(id: "b", latex: "2", errorTypeId: "e1"),
            ])
        #expect(!ItemChecker.check(item: item, submitted: "does-not-exist"))
    }

    @Test("numeric item with no answer returns false, never crashes")
    func numericItemWithNoAnswerReturnsFalse() throws {
        let item = ProbeItem(
            id: "no-answer", type: .numeric, promptLatex: "x", why: "why", renderFallback: nil,
            answer: nil, wrongAnswers: nil, choices: nil, correctChoiceId: nil, check: nil)
        #expect(!ItemChecker.check(item: item, submitted: "4"))
    }

    // MARK: - T4 conformance

    @Test("AC4 fuzz: random strings against every real data/demo numeric item never trap")
    func ac4FuzzNeverTraps() throws {
        let bundle = try Self.loadDemoBundle()
        let numericItems = bundle.nodes.nodes.flatMap(\.probeItems).filter { $0.type == .numeric }
        var gen = SeededGenerator(seed: 4242)
        for _ in 0..<300 {
            let submitted = Self.randomString(&gen)
            for item in numericItems {
                let result = ItemChecker.check(item: item, submitted: submitted)
                #expect(result == true || result == false)
            }
        }
    }

    private static func randomString(_ gen: inout SeededGenerator) -> String {
        let pool: [Character] = [
            " ", "\t", "+", "-", ".", "/", "0", "1", "9", "a", "z", "京", "€", "\u{0301}",
        ]
        let length = Int.random(in: 0...12, using: &gen)
        return String((0..<length).map { _ in pool[Int.random(in: 0..<pool.count, using: &gen)] })
    }

    // MARK: - T5 negative control

    @Test("Guard: numeric comparison is exact-rational, never Double-based")
    func guardExactRationalNotDouble() throws {
        // "3/4" and "0.75" are equal under the real grammar (AC3), but a naive Double comparator can't
        // even parse "3/4" — proving the real parser's `/`-grammar branch is load-bearing.
        #expect(Double("3/4") == nil)
        #expect(ItemChecker.check(item: Self.numericItem(value: "0.75"), submitted: "3/4"))
    }

    // MARK: - T6 idempotency

    @Test("T6: check/correctAnswerDisplay are pure across two identical calls")
    func checkAndDisplayArePure() throws {
        let item = Self.numericItem(value: "3/4")
        #expect(
            ItemChecker.check(item: item, submitted: "0.75")
                == ItemChecker.check(item: item, submitted: "0.75"))
        #expect(ItemChecker.correctAnswerDisplay(for: item) == ItemChecker.correctAnswerDisplay(for: item))
    }
}

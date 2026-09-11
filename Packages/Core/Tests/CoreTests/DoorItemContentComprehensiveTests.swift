import Foundation
import Testing

@testable import Core

/// Task 04.2's comprehensive suite for `DoorItemContent.swift` (§5 of
/// `tasks/epic-04-task-02-core-door-item-card-keypad.md`). Covers AC1-AC5, the Mirror-based no-leak
/// negative controls (I1/AC2), the defensive `mc`-with-nil-choices case (T2), the keypad-completeness
/// negative control (AC4/T5) and the idempotency/no-mutation guards (T6).
///
/// T3 error-taxonomy is N/A: this file throws no `CoreError` (§4 item 6 of the task spec) — no test
/// looks for a missing error case.
@Suite("DoorItemContent comprehensive suite")
struct DoorItemContentComprehensiveTests {
    private static var demoBundleDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Packages/Core
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    // MARK: - AC1: field mapping over every real data/demo item

    @Test("AC1: DoorItemContent(nodeId:item:isRetry:) maps every real data/demo probe item's fields")
    func ac1FieldMappingInit() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                for isRetry in [false, true] {
                    let content = DoorItemContent(nodeId: node.id, item: item, isRetry: isRetry)
                    #expect(content.nodeId == node.id)
                    #expect(content.promptLatex == item.promptLatex)
                    #expect(content.isRetry == isRetry)
                    switch item.type {
                    case .numeric:
                        #expect(content.inputKind == .numeric)
                        #expect(content.choices == [])
                    case .mc:
                        #expect(content.inputKind == .multipleChoice)
                        let expected = (item.choices ?? []).map {
                            DoorItemChoice(id: $0.id, latex: $0.latex)
                        }
                        #expect(content.choices == expected)
                    }
                    checked += 1
                }
            }
        }
        #expect(checked > 0, "empty data/demo scan is a FAIL")
    }

    @Test("AC1: DoorItemContent(from:) matches the primary initializer over every real data/demo item")
    func ac1FieldMappingConvenienceInit() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                for kind: SlotKind in [.newLearning, .review] {
                    for isRetry in [false, true] {
                        let currentItem = CurrentItem(
                            nodeId: node.id, item: item, kind: kind, isRetry: isRetry)
                        let fromConvenience = DoorItemContent(from: currentItem)
                        let fromPrimary = DoorItemContent(nodeId: node.id, item: item, isRetry: isRetry)
                        #expect(fromConvenience == fromPrimary)
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 0, "empty data/demo scan is a FAIL")
    }

    // MARK: - AC2: Mirror-based no-leak scan (I1) + planted-field negative control

    /// The scan this task's I1 guard runs: no child label in the banned set anywhere in the reflected
    /// structure (shallow — `DoorItemContent`/`DoorAnswerCardContent` are flat value types, matching the
    /// task spec's "no child label" wording).
    private static let bannedFieldLabels: Set<String> = [
        "answer", "answerValue", "value", "correctChoiceId", "correctChoiceID",
    ]

    private static func leakedLabels(reflecting value: Any) -> [String] {
        Mirror(reflecting: value).children.compactMap { child in
            guard let label = child.label else { return nil }
            return Self.bannedFieldLabels.contains(label) ? label : nil
        }
    }

    @Test("AC2: DoorItemContent built from an mc item leaks no answer/correctChoiceId field via Mirror")
    func ac2NoLeakFromMcItem() throws {
        let bundle = try Self.loadDemoBundle()
        let mcNode = try #require(
            bundle.nodes.nodes.first { $0.probeItems.contains { $0.type == .mc } })
        let mcItem = try #require(mcNode.probeItems.first { $0.type == .mc })
        #expect(mcItem.correctChoiceId != nil, "fixture sanity: the mc item must actually carry the field")

        let content = DoorItemContent(nodeId: mcNode.id, item: mcItem, isRetry: false)
        #expect(Self.leakedLabels(reflecting: content).isEmpty)
        // Nested choices must not leak anything either.
        for choice in content.choices {
            #expect(Self.leakedLabels(reflecting: choice).isEmpty)
        }
    }

    @Test("AC2: DoorItemContent built from a numeric item leaks no answer field via Mirror")
    func ac2NoLeakFromNumericItem() throws {
        let bundle = try Self.loadDemoBundle()
        let numNode = try #require(
            bundle.nodes.nodes.first { $0.probeItems.contains { $0.type == .numeric } })
        let numItem = try #require(numNode.probeItems.first { $0.type == .numeric })
        #expect(numItem.answer != nil, "fixture sanity: the numeric item must actually carry the field")

        let content = DoorItemContent(nodeId: numNode.id, item: numItem, isRetry: false)
        #expect(Self.leakedLabels(reflecting: content).isEmpty)
    }

    /// Planted-field negative control (AC2 / T5): a synthetic fixture type that DOES carry a stored
    /// `answer` field proves the scan is meaningful, not vacuously green.
    private struct LeakyFixture {
        let nodeId: String
        let answer: String
    }

    @Test("AC2 guard is load-bearing: the same Mirror scan catches a planted answer field")
    func ac2GuardCatchesPlantedLeak() throws {
        let leaky = LeakyFixture(nodeId: "n", answer: "42")
        let found = Self.leakedLabels(reflecting: leaky)
        #expect(found.contains("answer"), "scan failed to catch a planted 'answer' field — guard is vacuous")
    }

    // MARK: - AC3: DoorAnswerCardContent built only from a checked ItemResult

    @Test("AC3: DoorAnswerCardContent over a real correct and a real missed ItemResult, every data/demo item")
    func ac3AnswerCardFieldMapping() throws {
        let bundle = try Self.loadDemoBundle()
        var checked = 0
        for node in bundle.nodes.nodes {
            for item in node.probeItems {
                let ownSubmission: String
                let missSubmission: String
                switch item.type {
                case .numeric:
                    ownSubmission = try #require(item.answer?.value)
                    missSubmission = "definitely-not-a-number"
                case .mc:
                    ownSubmission = try #require(item.correctChoiceId)
                    missSubmission = "no-such-choice-id"
                }

                for submitted in [ownSubmission, missSubmission] {
                    let correct = ItemChecker.check(item: item, submitted: submitted)
                    let result = ItemResult(
                        nodeId: node.id, itemId: item.id, correct: correct,
                        correctAnswerDisplay: ItemChecker.correctAnswerDisplay(for: item), why: item.why,
                        isRetry: false)
                    let card = DoorAnswerCardContent(result: result, itemType: item.type)

                    #expect(card.correct == correct)
                    #expect(!card.correctAnswerDisplay.isEmpty, "\(node.id)/\(item.id) empty answer display")
                    #expect(!card.why.isEmpty, "\(node.id)/\(item.id) empty why — I3 requires the why")
                    switch item.type {
                    case .numeric: #expect(card.correctAnswerDisplayKind == .plain)
                    case .mc: #expect(card.correctAnswerDisplayKind == .latex)
                    }
                    checked += 1
                }
            }
        }
        #expect(checked > 0, "empty data/demo scan is a FAIL")
    }

    @Test("AC3: answer card is shown even when the student was wrong (I3, never withheld)")
    func ac3AnswerVisibleOnMiss() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first { $0.probeItems.contains { $0.type == .numeric } })
        let item = try #require(node.probeItems.first { $0.type == .numeric })

        let missed = ItemChecker.check(item: item, submitted: "not-a-number")
        #expect(!missed)
        let result = ItemResult(
            nodeId: node.id, itemId: item.id, correct: missed,
            correctAnswerDisplay: ItemChecker.correctAnswerDisplay(for: item), why: item.why,
            isRetry: false)
        let card = DoorAnswerCardContent(result: result, itemType: .numeric)
        #expect(!card.correct)
        #expect(!card.correctAnswerDisplay.isEmpty, "the correct answer must be shown even on a miss")
        #expect(!card.why.isEmpty)
    }

    @Test("AC3: extraLine is nil when omitted and equals the passed value otherwise")
    func ac3ExtraLineDefaultAndPassthrough() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first)
        let item = try #require(node.probeItems.first)
        let result = ItemResult(
            nodeId: node.id, itemId: item.id, correct: true, correctAnswerDisplay: "x", why: "y",
            isRetry: false)

        let omitted = DoorAnswerCardContent(result: result, itemType: item.type)
        #expect(omitted.extraLine == nil)

        let withLine = DoorAnswerCardContent(
            result: result, itemType: item.type, extraLine: "We'll come back to this one")
        #expect(withLine.extraLine == "We'll come back to this one")
    }

    // MARK: - AC4: keypad completeness over data/demo + negative control

    @Test("AC4: DoorKeypad.numericKeypadKeys covers every character of every real numeric answer.value")
    func ac4KeypadCoversAllNumericAnswerValues() throws {
        let bundle = try Self.loadDemoBundle()
        let numericValues = bundle.nodes.nodes.flatMap(\.probeItems)
            .filter { $0.type == .numeric }
            .compactMap { $0.answer?.value }
        #expect(!numericValues.isEmpty, "empty data/demo numeric-item set is a FAIL per AC4")

        for value in numericValues {
            for character in value {
                #expect(
                    DoorKeypad.numericKeypadKeys.contains(String(character)),
                    "'\(character)' from answer.value '\(value)' is missing from the keypad key set")
            }
        }
    }

    @Test("AC4: the keypad key set contains exactly the numeric-normalisation grammar's characters")
    func ac4KeypadContainsFullGrammar() {
        let expected: Set<String> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "-", ".", "/"]
        #expect(Set(DoorKeypad.numericKeypadKeys) == expected)
    }

    @Test("AC4 guard is load-bearing: removing '/' fails to cover rational-numbers-1's value 5/6")
    func ac4GuardCatchesIncompleteKeySet() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first { $0.id == "rational-numbers" })
        let item = try #require(node.probeItems.first { $0.id == "rational-numbers-1" })
        let value = try #require(item.answer?.value)
        #expect(value == "5/6", "fixture drifted: rational-numbers-1's answer.value is no longer 5/6")

        let incompleteKeySet = DoorKeypad.numericKeypadKeys.filter { $0 != "/" }
        let coversAll = value.allSatisfy { incompleteKeySet.contains(String($0)) }
        #expect(!coversAll, "removing '/' should break coverage of 5/6 — the completeness check is vacuous")
    }

    // MARK: - T2 negative: defensive handling of a malformed mc item (choices: nil)

    @Test("T2: an mc ProbeItem with choices: nil yields DoorItemContent.choices == [], never a crash")
    func t2MalformedMcChoicesNilYieldsEmptyArray() {
        let malformed = ProbeItem(
            id: "malformed-mc", type: .mc, promptLatex: "x", why: "why", renderFallback: nil,
            answer: nil, wrongAnswers: nil, choices: nil, correctChoiceId: "a", check: nil)
        let content = DoorItemContent(nodeId: "node", item: malformed, isRetry: false)
        #expect(content.inputKind == .multipleChoice)
        #expect(content.choices == [])
    }

    // MARK: - AC5: import boundary (Foundation only)

    @Test("AC5: DoorItemContent.swift imports Foundation only")
    func ac5ImportsFoundationOnly() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Packages/Core
            .appendingPathComponent("Sources/Core/Door/DoorItemContent.swift")
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let imports = text.split(separator: "\n")
            .filter { $0.hasPrefix("import ") }
            .map { $0.dropFirst("import ".count).trimmingCharacters(in: .whitespaces) }
        #expect(!imports.isEmpty, "instrument broken: file has no import line")
        #expect(Set(imports) == ["Foundation"])
    }

    // MARK: - T6 idempotency / no mutation

    @Test("T6: DoorItemContent built twice from identical inputs is Equatable-equal")
    func t6DoorItemContentIsIdempotent() throws {
        let bundle = try Self.loadDemoBundle()
        let node = try #require(bundle.nodes.nodes.first)
        let item = try #require(node.probeItems.first)
        let first = DoorItemContent(nodeId: node.id, item: item, isRetry: true)
        let second = DoorItemContent(nodeId: node.id, item: item, isRetry: true)
        #expect(first == second)
        // The source ProbeItem, a let-only value type passed by value, is left unchanged.
        #expect(item == node.probeItems.first)
    }

    @Test("T6: DoorAnswerCardContent built twice from identical inputs is Equatable-equal")
    func t6DoorAnswerCardContentIsIdempotent() throws {
        let result = ItemResult(
            nodeId: "n", itemId: "i", correct: true, correctAnswerDisplay: "5/6", why: "because",
            isRetry: false)
        let first = DoorAnswerCardContent(result: result, itemType: .numeric, extraLine: "line")
        let second = DoorAnswerCardContent(result: result, itemType: .numeric, extraLine: "line")
        #expect(first == second)
        // The source ItemResult, a let-only value type passed by value, is left unchanged.
        #expect(result.correct == true)
        #expect(result.correctAnswerDisplay == "5/6")
    }
}

import Foundation
import Testing

@testable import Core

/// Task 04.2's smoke test: proves `DoorItemContent`, `DoorAnswerCardContent` and `DoorKeypad` wire
/// together end to end over the real `data/demo` bundle. The tester's suite covers AC1-AC5 exhaustively;
/// this is the happy path only. This file throws no `CoreError` and asserts none — N/A (§4 item 6 of the
/// task spec: this seam has no error taxonomy).
@Suite("DoorItemContent smoke")
struct DoorItemContentTests {
    private static var demoBundleDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Packages/Core
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    @Test("happy path: item content, answer card and keypad wire together over data/demo")
    func doorItemContentWiresEndToEnd() throws {
        let bundle = try BundleIO.read(from: Self.demoBundleDir)
        let node = try #require(bundle.nodes.nodes.first { $0.probeItems.contains { $0.type == .numeric } })
        let item = try #require(node.probeItems.first { $0.type == .numeric })
        let answerValue = try #require(item.answer?.value)

        // Input validated (a real ProbeItem from a decoded bundle) through the seam under test.
        let content = DoorItemContent(nodeId: node.id, item: item, isRetry: false)
        #expect(content.promptLatex == item.promptLatex)
        #expect(content.inputKind == .numeric)
        #expect(content.choices == [])
        #expect(content.isRetry == false)

        // Result back: a checked ItemResult produces a non-empty answer card.
        let correct = ItemChecker.check(item: item, submitted: answerValue)
        #expect(correct)
        let result = ItemResult(
            nodeId: node.id, itemId: item.id, correct: correct,
            correctAnswerDisplay: ItemChecker.correctAnswerDisplay(for: item), why: item.why,
            isRetry: false)
        let card = DoorAnswerCardContent(result: result, itemType: .numeric)
        #expect(card.correct)
        #expect(!card.correctAnswerDisplay.isEmpty)
        #expect(!card.why.isEmpty)
        #expect(card.correctAnswerDisplayKind == .plain)
        #expect(card.extraLine == nil)

        // The keypad's key set types the item's own answer value.
        for character in answerValue {
            #expect(DoorKeypad.numericKeypadKeys.contains(String(character)))
        }
    }
}

import Foundation
import Testing

@testable import Core

@Suite("MasteryTransitions")
struct MasteryTransitionsTests {
    private static func today() -> CalendarDay {
        guard let day = CalendarDay(iso: "2026-09-10") else {
            preconditionFailure("2026-09-10 must be a valid CalendarDay")
        }
        return day
    }

    private static func node(
        mastery: Mastery,
        correctCount: Int = 0,
        lastProbe: String? = nil,
        nextDue: String? = nil,
        ladderRung: Int = 0,
        remediated: Bool? = nil
    ) -> NodeState {
        NodeState(
            mastery: mastery,
            correctCount: correctCount,
            lastProbe: lastProbe,
            nextDue: nextDue,
            ladderRung: ladderRung,
            remediated: remediated
        )
    }

    // T1 happy path (AC3, AC4, AC5, AC6).
    @Test("itemCorrect clears a fog node on the second distinct correct item")
    func itemCorrectClearsOnSecondDistinctItem() {
        let day = Self.today()
        let current = Self.node(mastery: .fog, correctCount: 1, remediated: nil)
        let result = MasteryTransitions.itemCorrect(
            current: current, itemId: "item-b", correctItemIds: ["item-a"], today: day)
        #expect(result.nodeState.mastery == .cleared)
        #expect(result.nodeState.ladderRung == 0)
        #expect(result.nodeState.nextDue == day.adding(days: 1).iso)
        #expect(result.nodeState.remediated == nil)
        #expect(result.event == .expeditionNodeCleared)
    }

    @Test("itemCorrect on a cleared node advances the ladder rung")
    func itemCorrectAdvancesLadderRung() {
        let day = Self.today()
        let current = Self.node(mastery: .cleared, ladderRung: 2)
        let result = MasteryTransitions.itemCorrect(
            current: current, itemId: "item-x", correctItemIds: [], today: day)
        #expect(result.nodeState.ladderRung == 3)
        #expect(result.nodeState.nextDue == day.adding(days: 14).iso)
        #expect(result.event == nil)
    }

    @Test("the last ladder rung repeats at 30 days")
    func lastLadderRungRepeats() {
        let day = Self.today()
        var current = Self.node(mastery: .cleared, ladderRung: 4)
        for _ in 0..<3 {
            let result = MasteryTransitions.itemCorrect(
                current: current, itemId: "item-x", correctItemIds: [], today: day)
            #expect(result.nodeState.ladderRung == 4)
            #expect(result.nodeState.nextDue == day.adding(days: 30).iso)
            current = result.nodeState
        }
    }

    @Test("itemMissReview resets a cleared node's ladder rung")
    func itemMissReviewResetsRung() {
        let day = Self.today()
        let current = Self.node(mastery: .cleared, ladderRung: 3)
        let result = MasteryTransitions.itemMissReview(current: current, today: day)
        #expect(result.nodeState.mastery == .cleared)
        #expect(result.nodeState.ladderRung == 0)
        #expect(result.nodeState.nextDue == day.adding(days: 1).iso)
    }

    @Test("diagnosisBlocked sets a fog node to blocked")
    func diagnosisBlockedSetsBlocked() {
        let current = Self.node(mastery: .fog)
        let result = MasteryTransitions.diagnosisBlocked(current: current)
        #expect(result.nodeState.mastery == .blocked)
        #expect(result.event == .diagnosisNodeBlocked)
    }

    // T2 negative — invalid input rejected at the boundary (AC3, AC6 sibling).
    @Test("itemCorrect never clears on the same item id answered twice")
    func itemCorrectNeverClearsOnSameItemIdTwice() {
        let day = Self.today()
        let current = Self.node(mastery: .fog, correctCount: 1)
        let result = MasteryTransitions.itemCorrect(
            current: current, itemId: "item-a", correctItemIds: ["item-a"], today: day)
        #expect(result.nodeState.mastery == .fog)
        #expect(result.event == nil)
    }

    @Test("itemMissReview on a fog or blocked node is a no-op")
    func itemMissReviewNoOpOnNonCleared() {
        let day = Self.today()
        for mastery: Mastery in [.fog, .blocked] {
            let current = Self.node(mastery: mastery, correctCount: 1)
            let result = MasteryTransitions.itemMissReview(current: current, today: day)
            #expect(result.nodeState == current)
            #expect(result.event == nil)
        }
    }

    @Test("diagnosisBlocked on a blocked or cleared node is a no-op")
    func diagnosisBlockedNoOpOnNonFog() {
        for mastery: Mastery in [.blocked, .cleared] {
            let current = Self.node(mastery: mastery)
            let result = MasteryTransitions.diagnosisBlocked(current: current)
            #expect(result.nodeState == current)
            #expect(result.event == nil)
        }
    }

    // T3 error-taxonomy: the ten new CoreError raw values match the registry exactly (AC1).
    @Test(
        "R-6 CoreError raw values match the registry",
        arguments: [
            (CoreError.expNoFringe, "EXP_NO_FRINGE"),
            (CoreError.expTrailInvalid, "EXP_TRAIL_INVALID"),
            (CoreError.expItemPoolEmpty, "EXP_ITEM_POOL_EMPTY"),
            (CoreError.expStateWriteFailed, "EXP_STATE_WRITE_FAILED"),
            (CoreError.expNodeNotInGraph, "EXP_NODE_NOT_IN_GRAPH"),
            (CoreError.diagNoPrerequisite, "DIAG_NO_PREREQUISITE"),
            (CoreError.diagProbeUnavailable, "DIAG_PROBE_UNAVAILABLE"),
            (CoreError.diagStateWriteFailed, "DIAG_STATE_WRITE_FAILED"),
            (CoreError.graphNoPrerequisite, "GRAPH_NO_PREREQUISITE"),
            (CoreError.mapMarkerOffTrail, "MAP_MARKER_OFF_TRAIL"),
        ]
    )
    func r6ErrorCodesMatchRegistry(_ pair: (CoreError, String)) {
        #expect(pair.0.rawValue == pair.1)
    }

    // T4 conformance: property tests over PropertyGen-generated fixtures.
    @Test("fog never returns: once cleared, item_correct/item_miss keep the node cleared")
    func fogNeverReturns() {
        var gen = SeededGenerator(seed: 42)
        for _ in 0..<200 {
            let day = PropertyGen.calendarDay(&gen)
            var current = PropertyGen.nodeState(&gen, today: day)
            current = NodeState(
                mastery: .cleared,
                correctCount: current.correctCount,
                lastProbe: current.lastProbe,
                nextDue: current.nextDue,
                ladderRung: current.ladderRung,
                remediated: current.remediated
            )
            let itemId = "item-\(PropertyGen.int(&gen, in: 0...9))"
            let viaCorrect = MasteryTransitions.itemCorrect(
                current: current, itemId: itemId, correctItemIds: [], today: day)
            #expect(viaCorrect.nodeState.mastery == .cleared)
            let viaMiss = MasteryTransitions.itemMissReview(current: current, today: day)
            #expect(viaMiss.nodeState.mastery == .cleared)
        }
    }

    @Test("expeditionNodeCleared events always carry ladderRung 0 and next_due today + 1")
    func clearedEventCarriesLadderRungZero() {
        var gen = SeededGenerator(seed: 7)
        for _ in 0..<200 {
            let day = PropertyGen.calendarDay(&gen)
            let mastery = PropertyGen.element(&gen, from: [Mastery.fog, Mastery.blocked])
            let current = Self.node(mastery: mastery, correctCount: PropertyGen.int(&gen, in: 0...3))
            let result = MasteryTransitions.itemCorrect(
                current: current, itemId: "item-a", correctItemIds: ["item-b"], today: day)
            if result.event == .expeditionNodeCleared {
                #expect(result.nodeState.ladderRung == 0)
                #expect(result.nodeState.nextDue == day.adding(days: 1).iso)
            }
        }
    }

    @Test("ladderRung stays in 0...4 across any sequence of review calls")
    func ladderRungStaysInBounds() {
        var gen = SeededGenerator(seed: 99)
        for _ in 0..<50 {
            let day = PropertyGen.calendarDay(&gen)
            var current = Self.node(mastery: .cleared, ladderRung: PropertyGen.int(&gen, in: 0...4))
            for _ in 0..<20 {
                if PropertyGen.bool(&gen, trueWeight: 0.5) {
                    current =
                        MasteryTransitions.itemCorrect(
                            current: current, itemId: "item-a", correctItemIds: [], today: day
                        ).nodeState
                } else {
                    current = MasteryTransitions.itemMissReview(current: current, today: day).nodeState
                }
                #expect((0...4).contains(current.ladderRung))
            }
        }
    }

    // T5 negative controls.
    @Test("a count-based clear check wrongly clears on the same item id submitted twice")
    func countBasedClearCheckWronglyClears() {
        func wouldClear(correctItemIds: Set<String>, itemId: String) -> Bool {
            correctItemIds.count + 1 >= 2
        }
        #expect(wouldClear(correctItemIds: ["item-a"], itemId: "item-a"))
        let day = Self.today()
        let current = Self.node(mastery: .fog, correctCount: 1)
        let result = MasteryTransitions.itemCorrect(
            current: current, itemId: "item-a", correctItemIds: ["item-a"], today: day)
        #expect(result.nodeState.mastery != .cleared)
    }

    @Test("a 4-element ladder caps at 14 days instead of the real ladder's 30")
    func fourElementLadderCapsAtFourteen() {
        let shortLadder = [1, 3, 7, 14]
        let day = Self.today()
        let clampedRung = min(4, shortLadder.count - 1)
        #expect(day.adding(days: shortLadder[clampedRung]).iso == day.adding(days: 14).iso)
        var current = Self.node(mastery: .cleared, ladderRung: 4)
        let result = MasteryTransitions.itemCorrect(
            current: current, itemId: "item-a", correctItemIds: [], today: day)
        current = result.nodeState
        #expect(current.nextDue == day.adding(days: 30).iso)
    }

    // T6 idempotency: pure functions return equal results for byte-identical fresh arguments.
    @Test("itemCorrect is pure across two calls with fresh identical arguments")
    func itemCorrectIsPure() {
        let day = Self.today()
        let first = MasteryTransitions.itemCorrect(
            current: Self.node(mastery: .fog, correctCount: 1),
            itemId: "item-b", correctItemIds: ["item-a"], today: day)
        let second = MasteryTransitions.itemCorrect(
            current: Self.node(mastery: .fog, correctCount: 1),
            itemId: "item-b", correctItemIds: ["item-a"], today: day)
        #expect(first == second)
    }

    @Test("itemMissReview is pure across two calls with fresh identical arguments")
    func itemMissReviewIsPure() {
        let day = Self.today()
        let first = MasteryTransitions.itemMissReview(
            current: Self.node(mastery: .cleared, ladderRung: 2), today: day)
        let second = MasteryTransitions.itemMissReview(
            current: Self.node(mastery: .cleared, ladderRung: 2), today: day)
        #expect(first == second)
    }

    @Test("diagnosisBlocked is pure across two calls with fresh identical arguments")
    func diagnosisBlockedIsPure() {
        let first = MasteryTransitions.diagnosisBlocked(current: Self.node(mastery: .fog))
        let second = MasteryTransitions.diagnosisBlocked(current: Self.node(mastery: .fog))
        #expect(first == second)
    }

    // I14: no Date() literal anywhere under Sources/Core (dedicated grep, distinct from
    // CoreTests.swift's import-boundary scan).
    @Test("no file under Sources/Core contains the literal Date()")
    func noDateLiteralInSourcesCore() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("Date()"), "\(file.lastPathComponent) contains the literal Date()")
        }
    }
}

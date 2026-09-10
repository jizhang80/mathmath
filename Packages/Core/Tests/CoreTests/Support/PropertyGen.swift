import Foundation

@testable import Core

/// Deterministic seeded generators for property-based tests across `CoreTests`, built on the existing
/// `SeededGenerator` (`Sources/Core/Layout/SeededGenerator.swift`). Every function takes
/// `inout SeededGenerator` so a whole property-test run advances one deterministic stream and is exactly
/// reproducible from its seed. No function here reads the system clock or any non-deterministic source.
/// Later tasks (02.5-02.7, 02.10-02.12) add their own generator functions to this same file/namespace
/// rather than duplicating a parallel helper (§6 default).
enum PropertyGen {
    /// A day inside `2024-01-01 ... 2029-12-31` — wide enough for any ladder/`next_due` arithmetic a
    /// property test in this EPIC exercises, narrow enough to keep string comparisons in `CalendarDay`
    /// meaningful across a small, human-inspectable range.
    static func calendarDay(_ gen: inout SeededGenerator) -> CalendarDay {
        guard let base = CalendarDay(iso: "2024-01-01") else {
            preconditionFailure("2024-01-01 must be a valid CalendarDay")
        }
        let offset = Int.random(in: 0...(6 * 365), using: &gen)
        return base.adding(days: offset)
    }

    static func mastery(_ gen: inout SeededGenerator) -> Mastery {
        element(&gen, from: [.fog, .cleared, .blocked])
    }

    /// A uniformly-drawn element of `pool`. `pool` must be non-empty; an empty `pool` is a test-authoring
    /// bug, not a runtime case to guard — traps via `precondition`, matching this file's test-only status.
    static func element<T>(_ gen: inout SeededGenerator, from pool: [T]) -> T {
        precondition(!pool.isEmpty, "PropertyGen.element called with an empty pool")
        let index = Int.random(in: 0..<pool.count, using: &gen)
        return pool[index]
    }

    static func bool(_ gen: inout SeededGenerator, trueWeight: Double) -> Bool {
        Double.random(in: 0..<1, using: &gen) < trueWeight
    }

    static func int(_ gen: inout SeededGenerator, in range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &gen)
    }

    /// A syntactically valid `NodeState`: `ladderRung` drawn from `0...4`, `correctCount` from `0...3`,
    /// `lastProbe`/`nextDue` derived from `today` (both present, `nextDue` `0...30` days after `today`, so
    /// generated fixtures exercise the "due" and "not yet due" cases roughly evenly), `remediated` set only
    /// when the drawn `mastery == .blocked` (per the Q-A field contract — a generator that could produce
    /// `remediated == true` on a `.cleared`/`.fog` node would generate a StudentState the encode/decode
    /// round trip could still accept but the field's own semantics forbid, so this is a deliberate
    /// generator-level guard, not decoding validation).
    static func nodeState(_ gen: inout SeededGenerator, today: CalendarDay) -> NodeState {
        let drawnMastery = mastery(&gen)
        let ladderRung = int(&gen, in: 0...4)
        let correctCount = int(&gen, in: 0...3)
        let dueOffset = int(&gen, in: 0...30)
        let remediated: Bool? = drawnMastery == .blocked ? bool(&gen, trueWeight: 0.5) : nil
        return NodeState(
            mastery: drawnMastery,
            correctCount: correctCount,
            lastProbe: today.iso,
            nextDue: today.adding(days: dueOffset).iso,
            ladderRung: ladderRung,
            remediated: remediated
        )
    }

    /// One `nodeState(_:today:)` per id in `nodeIds`, keyed by id.
    static func nodesMap(
        _ gen: inout SeededGenerator, nodeIds: [String], today: CalendarDay
    ) -> [String: NodeState] {
        var result: [String: NodeState] = [:]
        for id in nodeIds {
            result[id] = nodeState(&gen, today: today)
        }
        return result
    }
}

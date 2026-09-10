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

    /// A sequence of `count` correct/incorrect outcomes (02.7's `ExpeditionRun.answer` D27 property
    /// tests), each drawn independently with `correctWeight` probability of `true`.
    static func outcomeSequence(_ gen: inout SeededGenerator, count: Int, correctWeight: Double = 0.5)
        -> [Bool]
    {
        (0..<count).map { _ in bool(&gen, trueWeight: correctWeight) }
    }

    // MARK: - 02.10 additions (`PrerequisiteQueryTests`)

    /// A syntactically minimal `Node`: no expectation codes, no source ref, no probe items — every
    /// non-optional field carries the smallest value that satisfies its type. Never used as-is for L0
    /// or content-policy checks (this task's tests never run those), only as graph-structure filler for
    /// `PrerequisiteQuery`, which reads only `id` and `errorTypes`.
    static func minimalNode(id: String) -> Node {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil,
            paraphrase: "generated node \(id)", explanation: nil, workedExamples: nil, errorTypes: [],
            hintTree: [:], probeItems: [])
    }

    /// A syntactically minimal `Edge` of the given `confidence` — `PrerequisiteQuery` reads only `from`,
    /// `to` and `confidence`.
    static func minimalEdge(from: String, to: String, confidence: Double) -> Edge {
        Edge(
            from: from, to: to, sources: [], generationAgreement: 1, confidence: confidence,
            probeStats: ProbeStats(probes: 0, confirmed: 0, downstreamFailGivenUpstreamFail: nil))
    }

    /// A small synthetic acyclic graph rooted at node id `"origin"`: `1...maxLevels` layers, each layer
    /// holding `1...maxBranching` nodes, each new node's single outgoing edge pointing (as the
    /// prerequisite, `edge.from`) to one randomly-chosen node of the layer directly below it (closer to
    /// `"origin"`) — matching concept-graph's "from = prerequisite (shallower), to = dependent (deeper)"
    /// edge direction. Every edge points to a strictly lower layer index, so the graph is acyclic by
    /// construction; every node beyond `"origin"` is reachable from `"origin"` by walking incoming edges
    /// upward, at the layer's own BFS depth.
    static func smallLayeredGraph(
        _ gen: inout SeededGenerator, maxLevels: Int, maxBranching: Int
    ) -> (nodes: [Node], edges: [Edge], originId: String) {
        var nodesByLevel: [[String]] = [["origin"]]
        var nodes: [Node] = [minimalNode(id: "origin")]
        var edges: [Edge] = []
        let levels = int(&gen, in: 1...maxLevels)
        for level in 1...levels {
            let count = int(&gen, in: 1...maxBranching)
            var ids: [String] = []
            for index in 0..<count {
                let id = "l\(level)n\(index)"
                ids.append(id)
                nodes.append(minimalNode(id: id))
                let parentId = element(&gen, from: nodesByLevel[level - 1])
                let confidence = Double.random(in: 0.5...1, using: &gen)
                edges.append(minimalEdge(from: id, to: parentId, confidence: confidence))
            }
            nodesByLevel.append(ids)
        }
        return (nodes, edges, "origin")
    }
}

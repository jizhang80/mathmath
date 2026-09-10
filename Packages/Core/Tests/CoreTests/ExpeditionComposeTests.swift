import Foundation
import Testing

@testable import Core

/// Task 02.6's own companion test suite for `Expedition.compose`/`Expedition.selectItem`
/// (`Sources/Core/State/Expedition.swift`). Exercises AC1-AC9 on the real `data/demo` bundle (T1/T2/T4/
/// T5/T6). This file never calls `MarkerTrail` — every `Trail` it uses is hand-built, matching this
/// task's own file-scope statement that `Expedition.swift` and this test file depend only on 02.2 and
/// 02.4. The C1 marker->trail->fringe seam (AC10) lives in its own file, `MarkerTrailFringeSeamTests.swift`.
@Suite("Expedition.compose / Expedition.selectItem")
struct ExpeditionComposeTests {
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

    private static func loadValidFixtureBundle() throws -> ContentBundle {
        try BundleIO.read(from: testsDir.appendingPathComponent("Fixtures/l0/valid"))
    }

    /// 02.5 AC1's exact MTH1W course-segment node order (`tasks/epic-02-task-05-marker-trail-
    /// reconciliation.md` §1 AC1), hand-built here rather than obtained by calling `MarkerTrail` — this
    /// file's own trail-independence rule (§2).
    private static let mth1wOrder = [
        "integer-operations", "order-of-operations", "rational-numbers",
        "exponent-laws", "scientific-notation",
        "linear-relations", "solving-linear-equations", "solving-systems-of-equations",
        "simplifying-expressions", "polynomials", "factoring",
    ]

    private static var mth1wTrail: Trail {
        Trail(segments: [TrailSegment(kind: .course, courseCode: "MTH1W", nodeIds: mth1wOrder)])
    }

    private static var defaultMarker: Marker {
        Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
    }

    private static func today(_ iso: String = "2026-09-10") -> CalendarDay {
        guard let day = CalendarDay(iso: iso) else {
            preconditionFailure("\(iso) must be a valid CalendarDay")
        }
        return day
    }

    private static func state(
        nodes: [String: NodeState], marker: Marker = defaultMarker, trail: Trail = mth1wTrail,
        probeLog: [ProbeLogEntry] = []
    ) -> StudentState {
        StudentState(
            schemaVersion: 2,
            formatVersionSeen: "0.0.0",
            syllabi: ["MTH1W"],
            marker: marker,
            nodes: nodes,
            trail: trail,
            expeditionLog: [],
            probeLog: probeLog,
            installDay: "2026-01-01",
            consentOn: true
        )
    }

    // MARK: - T1 happy path

    @Test("AC1: empty state produces the two zero-prerequisite new-learning slots, no review")
    func ac1EmptyStateTwoNewLearningSlots() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today())
        let newLearning = result.slots.filter { $0.kind == .newLearning }
        #expect(newLearning.map(\.nodeId) == ["integer-operations", "rational-numbers"])
        #expect(result.slots.filter { $0.kind == .review }.isEmpty)
        #expect(result.skippedNodeIds == [])
    }

    @Test("AC2: a blocked+remediated exponent-laws admits scientific-notation, order-of-operations absent")
    func ac2BlockedRemediatedAdmitsDownstream() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes = [
            "exponent-laws": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: true)
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today())
        let newLearning = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(
            newLearning
                == ["integer-operations", "rational-numbers", "exponent-laws", "scientific-notation"])
        #expect(!newLearning.contains("order-of-operations"))
    }

    @Test("AC3: a due cleared node adds exactly one review slot alongside the AC1 new-learning pair")
    func ac3DueClearedNodeAddsReviewSlot() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes = [
            "linear-relations": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil)
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today("2026-09-10"))
        let newLearning = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(newLearning == ["integer-operations", "rational-numbers"])
        let review = result.slots.filter { $0.kind == .review }
        #expect(review.count == 1)
        #expect(review[0].nodeId == "linear-relations")
    }

    @Test("AC5: an on-fringe queuedNodeId is promoted to slot 1 without duplication; off-fringe is ignored")
    func ac5QueuedNodeIdOnAndOffFringe() throws {
        let bundle = try Self.loadDemoBundle()
        let onFringe = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), queuedNodeId: "rational-numbers")
        let onFringeOrder = onFringe.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(onFringeOrder == ["rational-numbers", "integer-operations"])

        let offFringe = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), queuedNodeId: "order-of-operations")
        let offFringeOrder = offFringe.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(offFringeOrder == ["integer-operations", "rational-numbers"])
        #expect(!offFringeOrder.contains("order-of-operations"))
    }

    @Test("AC6: a unit-expedition parameter overrides the marker window rather than intersecting with it")
    func ac6UnitExpeditionOverridesWindow() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), unitExpeditionUnitId: "MTH1W.u4")
        let newLearning = result.slots.filter { $0.kind == .newLearning }
        #expect(newLearning.map(\.nodeId) == ["simplifying-expressions"])
    }

    @Test("AC9: selectItem picks unused-first by id, then least-recently-used, deterministically")
    func ac9SelectItemUnusedAndLRU() throws {
        let itemA = ProbeItem(
            id: "item-a", type: .numeric, promptLatex: "1+1", why: "because", renderFallback: nil,
            answer: ProbeAnswer(value: "2", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let itemB = ProbeItem(
            id: "item-b", type: .numeric, promptLatex: "2+2", why: "because", renderFallback: nil,
            answer: ProbeAnswer(value: "4", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let node = Node(
            id: "test-node", name: "Test node", regionId: .numberOperations, strand: nil,
            expectationCodes: nil, sourceRef: nil, courses: [], position: Point(x: 0, y: 0),
            layoutHint: nil, paraphrase: "p", explanation: nil, workedExamples: nil, errorTypes: [],
            hintTree: [:], probeItems: [itemA, itemB])

        let emptyLog = Expedition.selectItem(from: node, excluding: [], probeLog: [])
        #expect(emptyLog?.id == "item-a")

        let probeLog = [
            ProbeLogEntry(
                day: "2026-01-01", nodeId: "test-node", itemId: "item-a", correct: true, retry: false),
            ProbeLogEntry(
                day: "2026-06-01", nodeId: "test-node", itemId: "item-b", correct: true, retry: false),
        ]
        let firstCall = Expedition.selectItem(from: node, excluding: [], probeLog: probeLog)
        #expect(firstCall?.id == "item-a")
        let secondCall = Expedition.selectItem(from: node, excluding: [], probeLog: probeLog)
        #expect(firstCall == secondCall)
    }

    // MARK: - T2 negative — invalid input rejected at the boundary

    @Test("AC7: nothing on the fringe and nothing due throws EXP_NO_FRINGE")
    func ac7NoFringeThrows() throws {
        let bundle = try Self.loadDemoBundle()
        let windowNodeIds = [
            "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
            "scientific-notation",
        ]
        var nodes: [String: NodeState] = [:]
        for nodeId in windowNodeIds {
            nodes[nodeId] = NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2026-12-01",
                ladderRung: 0, remediated: nil)
        }
        #expect(throws: CoreError.expNoFringe) {
            _ = try Expedition.compose(
                state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
                marker: Self.defaultMarker, today: Self.today())
        }
    }

    @Test("AC8: a blocked, item-empty node is skipped, not thrown; slots carry only the item-bearing node")
    func ac8ItemPoolEmptyNodeIsSkipped() throws {
        let bundle = try Self.loadValidFixtureBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let trail = Trail(
            segments: [TrailSegment(kind: .course, courseCode: "MTH1W", nodeIds: ["exponent-laws"])])
        let nodes = [
            "matrix-multiplication": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil)
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes, marker: marker, trail: trail), bundle: bundle, trail: trail,
            marker: marker, today: Self.today())
        #expect(result.skippedNodeIds == ["matrix-multiplication"])
        #expect(result.slots.map(\.nodeId) == ["exponent-laws"])
    }

    @Test("selectItem returns nil for an item-empty node regardless of exclusions/probeLog")
    func selectItemNilOnEmptyPool() throws {
        let bundle = try Self.loadValidFixtureBundle()
        guard let matrixMultiplication = bundle.nodes.nodes.first(where: { $0.id == "matrix-multiplication" })
        else {
            Issue.record("matrix-multiplication must exist in Fixtures/l0/valid")
            return
        }
        #expect(Expedition.selectItem(from: matrixMultiplication, excluding: [], probeLog: []) == nil)
        #expect(
            Expedition.selectItem(from: matrixMultiplication, excluding: ["anything"], probeLog: []) == nil)
    }

    @Test("selectItem returns nil when excludedItemIds covers every item of a two-item node")
    func selectItemNilWhenAllExcluded() throws {
        let bundle = try Self.loadDemoBundle()
        guard let integerOperations = bundle.nodes.nodes.first(where: { $0.id == "integer-operations" })
        else {
            Issue.record("integer-operations must exist in data/demo")
            return
        }
        let allIds = Set(integerOperations.probeItems.map(\.id))
        #expect(Expedition.selectItem(from: integerOperations, excluding: allIds, probeLog: []) == nil)
    }

    // MARK: - T4 conformance

    private static let windowNodeIds = [
        "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
        "scientific-notation",
    ]

    /// Independent recomputation of D48's guard-eligibility formula, restricted to `windowNodeIds`, from
    /// `edges.json` alone — no call into any `Expedition` private helper.
    private static func independentFringeCandidateCount(
        nodes: [String: NodeState], edgesByTo: [String: [Edge]]
    ) -> Int {
        windowNodeIds.filter { nodeId in
            let mastery = nodes[nodeId]?.mastery ?? .fog
            guard mastery != .cleared else { return false }
            if mastery == .blocked { return true }
            return (edgesByTo[nodeId] ?? []).allSatisfy { edge in
                let p = nodes[edge.from]?.mastery ?? .fog
                let remediated = nodes[edge.from]?.remediated ?? false
                return p == .cleared || (p == .blocked && remediated)
            }
        }.count
    }

    private static func independentDueCandidateCount(
        nodes: [String: NodeState], today: CalendarDay
    ) -> Int {
        windowNodeIds.filter { nodeId in
            guard let ns = nodes[nodeId], ns.mastery == .cleared else { return false }
            return ns.nextDue.map { $0 <= today.iso } ?? false
        }.count
    }

    @Test("AC4: slot counts never exceed their contract caps, over generated window states")
    func ac4SlotCountProperty() throws {
        let bundle = try Self.loadDemoBundle()
        let index = GraphIndexForTests(bundle: bundle)
        let today = Self.today("2024-01-01")
        var gen = SeededGenerator(seed: 2026)
        for _ in 0..<200 {
            let nodes = PropertyGen.nodesMap(&gen, nodeIds: Self.windowNodeIds, today: today)
            let fringeCandidateCount = Self.independentFringeCandidateCount(
                nodes: nodes, edgesByTo: index.edgesByTo)
            let dueCandidateCount = Self.independentDueCandidateCount(nodes: nodes, today: today)

            if fringeCandidateCount == 0 && dueCandidateCount == 0 {
                #expect(throws: CoreError.expNoFringe) {
                    _ = try Expedition.compose(
                        state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
                        marker: Self.defaultMarker, today: today)
                }
                continue
            }

            let result = try Expedition.compose(
                state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
                marker: Self.defaultMarker, today: today)
            let reviewCount = result.slots.filter { $0.kind == .review }.count
            let newLearningCount = result.slots.filter { $0.kind == .newLearning }.count
            #expect(reviewCount == min(2, dueCandidateCount))
            #expect(newLearningCount == min(5 - reviewCount, fringeCandidateCount))

            for slot in result.slots where slot.kind == .newLearning {
                let mastery = nodes[slot.nodeId]?.mastery ?? .fog
                if mastery == .blocked { continue }
                let guardOK = (index.edgesByTo[slot.nodeId] ?? []).allSatisfy { edge in
                    let p = nodes[edge.from]?.mastery ?? .fog
                    let remediated = nodes[edge.from]?.remediated ?? false
                    return p == .cleared || (p == .blocked && remediated)
                }
                #expect(guardOK, "\(slot.nodeId) drawn off-fringe/upstream while not blocked")
            }
        }
    }

    @Test("I14: no Date() literal in Expedition.swift")
    func noDateLiteralInNewFile() throws {
        let file = Self.testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/State/Expedition.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("Date()"))
    }

    // MARK: - T5 negative control for every regression guard

    @Test("Guard: review-first reservation is load-bearing, not accidentally satisfied by fringe-first fill")
    func guardReviewReservationIsLoadBearing() throws {
        let bundle = try Self.loadDemoBundle()
        // Fringe pool = 5 (every window node blocked, unconditionally fringe-eligible), due pool = 2.
        var nodes: [String: NodeState] = [
            "linear-relations": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil),
            "solving-linear-equations": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil),
        ]
        for nodeId in Self.windowNodeIds {
            nodes[nodeId] = NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil)
        }
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today("2026-09-10"))
        let reviewCount = result.slots.filter { $0.kind == .review }.count
        #expect(reviewCount == 2)

        // The fringe-first-no-reservation alternative: fill new-learning up to 5 first, review with
        // whatever room is left. On this exact fringe/due pool it produces reviewCount == 0, proving the
        // real ordering (review reserved first) is load-bearing, not accidentally equivalent.
        let fringeCandidateCount = 5
        let alternativeNewLearningCount = min(5, fringeCandidateCount)
        let alternativeReviewCount = min(2, 5 - alternativeNewLearningCount)
        #expect(alternativeReviewCount == 0)
        #expect(alternativeReviewCount != reviewCount)
    }

    @Test("Guard: selectItem prefers unused over LRU, not the reverse")
    func guardUnusedBeatsAnyDatedEntry() throws {
        let itemUnused = ProbeItem(
            id: "item-unused", type: .numeric, promptLatex: "1", why: "w", renderFallback: nil,
            answer: ProbeAnswer(value: "1", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let itemOnceUsedLongAgo = ProbeItem(
            id: "item-old", type: .numeric, promptLatex: "2", why: "w", renderFallback: nil,
            answer: ProbeAnswer(value: "2", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let node = Node(
            id: "test-node", name: "Test node", regionId: .numberOperations, strand: nil,
            expectationCodes: nil, sourceRef: nil, courses: [], position: Point(x: 0, y: 0),
            layoutHint: nil, paraphrase: "p", explanation: nil, workedExamples: nil, errorTypes: [],
            hintTree: [:], probeItems: [itemUnused, itemOnceUsedLongAgo])
        let probeLog = [
            ProbeLogEntry(
                day: "2020-01-01", nodeId: "test-node", itemId: "item-old", correct: true, retry: false)
        ]
        let real = Expedition.selectItem(from: node, excluding: [], probeLog: probeLog)
        #expect(real?.id == "item-unused")

        // The wrong reading: treat `nil` (never used) as "used furthest in the future" and sort purely by
        // `lastUsed` day.
        func wrongSelect() -> String {
            let sentinel = "9999-12-31"
            var lastUsed: [String: String] = [:]
            for entry in probeLog { lastUsed[entry.itemId] = entry.day }
            let candidates = [itemUnused, itemOnceUsedLongAgo]
            let chosen = candidates.min { lhs, rhs in
                (lastUsed[lhs.id] ?? sentinel) < (lastUsed[rhs.id] ?? sentinel)
            }
            return chosen?.id ?? ""
        }
        #expect(wrongSelect() == "item-old")
        #expect(wrongSelect() != real?.id)
    }

    @Test("Guard: a blocked node is fringe-eligible unconditionally, not intersected with the window")
    func guardBlockedNodeUnconditional() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes = [
            "exponent-laws": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: true)
        ]
        // Narrow the window to MTH1W.u4, which excludes exponent-laws (a u2 node).
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), unitExpeditionUnitId: "MTH1W.u4")
        let newLearning = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(newLearning.contains("exponent-laws"))

        // The wrong reading: intersect the blocked set with the window too.
        func wrongFringeContainsExponentLaws() -> Bool {
            let window: Set<String> = ["simplifying-expressions", "polynomials", "factoring"]
            let blocked: Set<String> = ["exponent-laws"]
            return blocked.intersection(window).contains("exponent-laws")
        }
        #expect(!wrongFringeContainsExponentLaws())
    }

    @Test("Guard: an off-fringe queuedNodeId is dropped, not force-inserted")
    func guardOffFringeQueuedNodeIsDropped() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), queuedNodeId: "order-of-operations")
        let newLearning = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(!newLearning.contains("order-of-operations"))

        // The wrong reading: always force-insert queuedNodeId at slot 1.
        var wrongOrder = ["order-of-operations"]
        wrongOrder += newLearning
        #expect(wrongOrder.first == "order-of-operations")
        #expect(wrongOrder != newLearning)
    }

    // MARK: - T6 idempotency / no-leak

    @Test("T6: compose and selectItem are pure across two calls with fresh identical arguments")
    func composeAndSelectItemArePure() throws {
        let bundle1 = try Self.loadDemoBundle()
        let bundle2 = try Self.loadDemoBundle()
        let state1 = Self.state(nodes: [:])
        let state2 = Self.state(nodes: [:])
        let first = try Expedition.compose(
            state: state1, bundle: bundle1, trail: Self.mth1wTrail, marker: Self.defaultMarker,
            today: Self.today())
        let second = try Expedition.compose(
            state: state2, bundle: bundle2, trail: Self.mth1wTrail, marker: Self.defaultMarker,
            today: Self.today())
        #expect(first == second)
        #expect(state1 == state2)
        #expect(bundle1.nodes == bundle2.nodes)

        guard let integerOperations = bundle1.nodes.nodes.first(where: { $0.id == "integer-operations" })
        else {
            Issue.record("integer-operations must exist in data/demo")
            return
        }
        let selectFirst = Expedition.selectItem(from: integerOperations, excluding: [], probeLog: [])
        let selectSecond = Expedition.selectItem(from: integerOperations, excluding: [], probeLog: [])
        #expect(selectFirst == selectSecond)
    }
}

/// A test-local, independent re-derivation of `GraphIndex`'s `edgesByTo` grouping (the real `GraphIndex`
/// is `internal`, reachable via `@testable import Core`, but this task's own `Expedition` uses its own
/// `Dictionary(grouping:by:)` call rather than a shared helper this test could otherwise call directly —
/// building it fresh here keeps the property test's oracle independent of `Expedition`'s internals).
private struct GraphIndexForTests {
    let edgesByTo: [String: [Edge]]

    init(bundle: ContentBundle) {
        edgesByTo = Dictionary(grouping: bundle.edges.edges, by: \.to)
    }
}

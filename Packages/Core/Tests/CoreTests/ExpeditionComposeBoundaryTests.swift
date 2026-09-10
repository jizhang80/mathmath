import Foundation
import Testing

@testable import Core

/// Tester's supplementary coverage for `Expedition.compose`/`Expedition.selectItem`
/// (`Sources/Core/State/Expedition.swift`), written against `tasks/epic-02-task-06-fringe-compose-seam.md`.
/// This file does NOT re-verify AC1-AC10 (the implementer's own `ExpeditionComposeTests.swift` and
/// `MarkerTrailFringeSeamTests.swift` already own that ground) — it targets gaps the implementer's smoke
/// left open:
///  - untrusted/malformed `Marker`/`unitExpeditionUnitId` input (persisted `StudentState` is untrusted
///    input, per the tester charter item 2) degrades to an empty window rather than crashing;
///  - `EXP_ITEM_POOL_EMPTY` skip-and-continue in the REVIEW category (§6 decision default: "skips it ...
///    and continues to the next candidate in that same slot category" — only the new-learning category is
///    covered by AC8);
///  - the due-node tie-break-by-id secondary key (§6 decision default, untested by AC3 since AC3 has only
///    one due candidate);
///  - `selectItem`'s id tie-break when two items share the same most-recent `probeLog` day (AC9 only
///    exercises the "no entry" tie, not the "same dated entry" tie);
///  - a `queuedNodeId` naming a node absent from the bundle entirely (not merely off-fringe).
@Suite("Expedition.compose / Expedition.selectItem — boundary and gap coverage")
struct ExpeditionComposeBoundaryTests {
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

    private static func loadValidFixtureBundle() throws -> ContentBundle {
        try BundleIO.read(from: testsDir.appendingPathComponent("Fixtures/l0/valid"))
    }

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
        nodes: [String: NodeState], marker: Marker = defaultMarker, trail: Trail = mth1wTrail
    ) -> StudentState {
        StudentState(
            schemaVersion: 2,
            formatVersionSeen: "0.0.0",
            syllabi: ["MTH1W"],
            marker: marker,
            nodes: nodes,
            trail: trail,
            expeditionLog: [],
            probeLog: [],
            installDay: "2026-01-01",
            consentOn: true
        )
    }

    // MARK: - Untrusted-input boundary cases (a persisted `Marker`/unit id is untrusted state)

    @Test("Marker naming a course absent from the bundle degrades to an empty window, no crash")
    func unknownMarkerCourseDegradesGracefully() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: false)
        // No blocked node and no due node exists in an all-fog state: the window is empty, the guard-
        // eligible set is empty, and the unconditional-blocked set is empty too, so this throws
        // EXP_NO_FRINGE rather than crashing on a force-unwrap of a missing course/unit lookup.
        #expect(throws: CoreError.expNoFringe) {
            _ = try Expedition.compose(
                state: Self.state(nodes: [:], marker: marker), bundle: bundle, trail: Self.mth1wTrail,
                marker: marker, today: Self.today())
        }
    }

    @Test("Marker naming a unit absent from its own course degrades to an empty window, no crash")
    func unknownMarkerUnitDegradesGracefully() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u99", pastLastUnit: false)
        #expect(throws: CoreError.expNoFringe) {
            _ = try Expedition.compose(
                state: Self.state(nodes: [:], marker: marker), bundle: bundle, trail: Self.mth1wTrail,
                marker: marker, today: Self.today())
        }
    }

    @Test("A blocked node surfaces under an unresolvable marker (degrade doesn't mask the blocked union)")
    func unknownMarkerStillSurfacesBlockedNode() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: false)
        let nodes = [
            "exponent-laws": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil)
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes, marker: marker), bundle: bundle, trail: Self.mth1wTrail,
            marker: marker, today: Self.today())
        #expect(result.slots.map(\.nodeId) == ["exponent-laws"])
    }

    @Test("unitExpeditionUnitId with a malformed (dot-less) string degrades to an empty window, no crash")
    func malformedUnitExpeditionIdDegradesGracefully() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(throws: CoreError.expNoFringe) {
            _ = try Expedition.compose(
                state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
                marker: Self.defaultMarker, today: Self.today(), unitExpeditionUnitId: "GARBAGE")
        }
    }

    @Test("unitExpeditionUnitId naming an unknown course degrades to an empty window, no crash")
    func unitExpeditionUnknownCourseDegradesGracefully() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(throws: CoreError.expNoFringe) {
            _ = try Expedition.compose(
                state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
                marker: Self.defaultMarker, today: Self.today(), unitExpeditionUnitId: "ZZZ9Z.u1")
        }
    }

    @Test("queuedNodeId naming a node absent from the whole bundle is silently dropped, not a crash")
    func queuedNodeIdAbsentFromBundleIsDropped() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try Expedition.compose(
            state: Self.state(nodes: [:]), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today(), queuedNodeId: "no-such-node-id")
        let newLearning = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(newLearning == ["integer-operations", "rational-numbers"])
    }

    // MARK: - EXP_ITEM_POOL_EMPTY skip-and-continue, review category

    @Test("A due, item-empty node is skipped and a later due node backfills the freed review slot")
    func reviewCategorySkipAndContinueBackfills() throws {
        // Fixtures/l0/valid's matrix-multiplication carries zero probe_items; exponent-laws carries two.
        // Both are marked cleared+due; matrix-multiplication sorts first (older lastProbe) so the review
        // loop must skip it and continue to exponent-laws, proving `compose` does not abort the review
        // category on the first empty pool (§6 decision default: "skips it ... and continues to the next
        // candidate in that same slot category").
        let bundle = try Self.loadValidFixtureBundle()
        let nodes = [
            "matrix-multiplication": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2026-06-01",
                ladderRung: 0, remediated: nil),
            "exponent-laws": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-02-01", nextDue: "2026-06-01",
                ladderRung: 0, remediated: nil),
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today("2026-09-10"))
        let review = result.slots.filter { $0.kind == .review }
        #expect(review.map(\.nodeId) == ["exponent-laws"])
        #expect(result.skippedNodeIds.contains("matrix-multiplication"))
    }

    // MARK: - Due-node tie-break by node id ascending (§6 decision default)

    @Test("Due nodes tied on identical lastProbe break by node id ascending")
    func dueNodesTieBreakByIdWhenLastProbeIdentical() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes = [
            "scientific-notation": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil),
            "exponent-laws": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil),
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today("2026-09-10"))
        let review = result.slots.filter { $0.kind == .review }.map(\.nodeId)
        #expect(review == ["exponent-laws", "scientific-notation"])
    }

    @Test("Due nodes both carrying a nil lastProbe break by node id ascending")
    func dueNodesTieBreakByIdWhenLastProbeBothNil() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes = [
            "scientific-notation": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: "2026-09-01", ladderRung: 0,
                remediated: nil),
            "exponent-laws": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: "2026-09-01", ladderRung: 0,
                remediated: nil),
        ]
        let result = try Expedition.compose(
            state: Self.state(nodes: nodes), bundle: bundle, trail: Self.mth1wTrail,
            marker: Self.defaultMarker, today: Self.today("2026-09-10"))
        let review = result.slots.filter { $0.kind == .review }.map(\.nodeId)
        #expect(review == ["exponent-laws", "scientific-notation"])
    }

    // MARK: - selectItem: id tie-break on an identical dated probeLog entry

    @Test("selectItem breaks a tie on the same most-recent probeLog day by id ascending")
    func selectItemTieBreaksByIdOnIdenticalDay() throws {
        let itemX = ProbeItem(
            id: "item-x", type: .numeric, promptLatex: "3+3", why: "because", renderFallback: nil,
            answer: ProbeAnswer(value: "6", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let itemY = ProbeItem(
            id: "item-y", type: .numeric, promptLatex: "4+4", why: "because", renderFallback: nil,
            answer: ProbeAnswer(value: "8", tolerance: nil), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
        let node = Node(
            id: "test-node", name: "Test node", regionId: .numberOperations, strand: nil,
            expectationCodes: nil, sourceRef: nil, courses: [], position: Point(x: 0, y: 0),
            layoutHint: nil, paraphrase: "p", explanation: nil, workedExamples: nil, errorTypes: [],
            hintTree: [:], probeItems: [itemY, itemX])
        let probeLog = [
            ProbeLogEntry(
                day: "2026-05-05", nodeId: "test-node", itemId: "item-y", correct: true, retry: false),
            ProbeLogEntry(
                day: "2026-05-05", nodeId: "test-node", itemId: "item-x", correct: true, retry: false),
        ]
        let chosen = Expedition.selectItem(from: node, excluding: [], probeLog: probeLog)
        #expect(chosen?.id == "item-x")
    }
}

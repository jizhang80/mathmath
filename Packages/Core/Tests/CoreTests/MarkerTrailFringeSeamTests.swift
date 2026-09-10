import Foundation
import Testing

@testable import Core

/// C1 seam test (AC10): a real `MarkerTrail.setMarker` (02.5) call feeding a real `Expedition.compose`
/// (02.6) call, on the real `data/demo` bundle — no stubbed trail, no hand-built fringe. Per the Q-G
/// test-data rule, only the `StudentState` is constructed; both `MarkerTrail`'s and `Expedition`'s own
/// output are used unmodified.
@Suite("C1 seam: MarkerTrail -> Expedition.compose fringe")
struct MarkerTrailFringeSeamTests {
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

    @Test("AC10: every new-learning slot is a member of an independently recomputed fringe set")
    func ac10NewLearningSlotsAreFringeMembers() throws {
        let bundle = try Self.loadDemoBundle()

        // Real MarkerTrail call — no hand-built trail.
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)

        // A non-trivial StudentState (AC2's blocked-and-remediated scenario, reused here).
        let nodes: [String: NodeState] = [
            "exponent-laws": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: true)
        ]
        let state = StudentState(
            schemaVersion: 2,
            formatVersionSeen: "0.0.0",
            syllabi: ["MTH1W"],
            marker: setMarkerResult.marker,
            nodes: nodes,
            trail: setMarkerResult.trail,
            expeditionLog: [],
            probeLog: [],
            installDay: "2026-01-01",
            consentOn: true
        )
        guard let today = CalendarDay(iso: "2026-09-10") else {
            Issue.record("2026-09-10 must be a valid CalendarDay")
            return
        }

        // Real Expedition.compose call — no stubbed fringe.
        let result = try Expedition.compose(
            state: state, bundle: bundle, trail: setMarkerResult.trail, marker: setMarkerResult.marker,
            today: today)

        // Independent, formula-level recomputation of the D48 fringe set (`contracts/interaction-
        // contract.md` § 2 `compose` bullet) for this same (state, trail, marker) — no call into any
        // `Expedition` private helper.
        let fringe = try Self.independentFringe(bundle: bundle, state: state, marker: setMarkerResult.marker)

        let newLearningNodeIds = result.slots.filter { $0.kind == .newLearning }.map(\.nodeId)
        #expect(!newLearningNodeIds.isEmpty)
        for nodeId in newLearningNodeIds {
            #expect(
                fringe.contains(nodeId),
                "\(nodeId) is not a member of the independently recomputed fringe")
        }
    }

    /// Independent (in-test) re-derivation of the D48 fringe formula: `{n : mastery(n) != cleared and
    /// every prerequisite of n is cleared or (blocked and remediated)} intersect (nodes of marker.unit
    /// union next(marker.unit)) union {n : mastery(n) == blocked}`.
    private static func independentFringe(
        bundle: ContentBundle, state: StudentState, marker: Marker
    ) throws -> Set<String> {
        guard let course = bundle.courses.courses.first(where: { $0.courseCode == marker.courseCode }),
            let markerUnitIdx = course.units.firstIndex(where: { $0.unitId == marker.unitId })
        else {
            return []
        }
        let nodesById = Dictionary(uniqueKeysWithValues: bundle.nodes.nodes.map { ($0.id, $0) })
        func unitIndex(_ nodeId: String) -> Int? {
            guard let node = nodesById[nodeId] else { return nil }
            let entries = (node.expectationCodes ?? []).filter { $0.courseCode == course.courseCode }
            let ordinals: [Int] = entries.compactMap { entry in
                guard let unitId = course.expectations.first(where: { $0.code == entry.code })?.unitId
                else { return nil }
                return course.units.firstIndex(where: { $0.unitId == unitId })
            }
            return ordinals.min()
        }
        let window = Set(
            bundle.nodes.nodes.map(\.id).filter { nodeId in
                guard let idx = unitIndex(nodeId) else { return false }
                return idx == markerUnitIdx || idx == markerUnitIdx + 1
            })
        func mastery(of nodeId: String) -> Mastery { state.nodes[nodeId]?.mastery ?? .fog }
        func remediated(_ nodeId: String) -> Bool { state.nodes[nodeId]?.remediated ?? false }
        let edgesByTo = Dictionary(grouping: bundle.edges.edges, by: \.to)
        let guardEligible = bundle.nodes.nodes.map(\.id).filter { nodeId in
            mastery(of: nodeId) != .cleared && window.contains(nodeId)
                && (edgesByTo[nodeId] ?? []).allSatisfy { edge in
                    mastery(of: edge.from) == .cleared
                        || (mastery(of: edge.from) == .blocked && remediated(edge.from))
                }
        }
        let blocked = bundle.nodes.nodes.map(\.id).filter { mastery(of: $0) == .blocked }
        return Set(guardEligible).union(blocked)
    }
}

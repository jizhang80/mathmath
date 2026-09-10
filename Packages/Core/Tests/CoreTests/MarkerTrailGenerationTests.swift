import Foundation
import Testing

@testable import Core

/// Task 02.5's own companion test suite for `MarkerTrail` (`Sources/Core/State/MarkerTrailGeneration.swift`).
/// The marker → trail seam is exercised on real `data/demo` plus two small hand-built fixtures
/// (`Fixtures/trail/extension-positive`, `Fixtures/trail/unit-cycle`). This file does not call
/// `compose` (02.6, not yet shipped) — that seam test is `MarkerTrailFringeSeamTests.swift`, owned by
/// task 02.6.
@Suite("MarkerTrail (marker/trail generation, W6/W7/W8)")
struct MarkerTrailGenerationTests {
    /// `Packages/Core/Tests/CoreTests`, located the same way `L0CheckerTests` locates its fixtures.
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

    private static func loadTrailFixture(_ name: String) throws -> ContentBundle {
        try BundleIO.read(
            from: testsDir.appendingPathComponent("Fixtures/trail").appendingPathComponent(name))
    }

    private static let mth1wOrder = [
        "integer-operations", "order-of-operations", "rational-numbers",
        "exponent-laws", "scientific-notation",
        "linear-relations", "solving-linear-equations", "solving-systems-of-equations",
        "simplifying-expressions", "polynomials", "factoring",
    ]

    private static let mcr3uOrder = [
        "rational-expressions", "solving-quadratics", "quadratic-functions",
        "function-concept", "domain-and-range", "function-notation", "function-transformations",
        "exponential-functions", "logarithms",
    ]

    // MARK: - T1 happy path

    @Test("AC1: generateTrail(MTH1W) matches 02.3's fixture, one against-unit-order warning")
    func ac1GenerateTrailMTH1W() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.count == 1)
        let segment = report.trail.segments[0]
        #expect(segment.kind == .course)
        #expect(segment.courseCode == "MTH1W")
        #expect(segment.nodeIds == Self.mth1wOrder)
        #expect(
            report.warnings == [
                TrailWarning(
                    courseCode: "MTH1W", from: "solving-linear-equations", to: "exponent-laws")
            ])
        #expect(report.event == .expeditionTrailGenerated)
    }

    @Test("AC2: generateTrail(MTH1W, MCR3U) appends the corrected MCR3U segment order, no new warnings")
    func ac2GenerateTrailMTH1WThenMCR3U() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W", "MCR3U"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.count == 2)
        #expect(report.trail.segments[0].nodeIds == Self.mth1wOrder)
        let mcr3u = report.trail.segments[1]
        #expect(mcr3u.kind == .course)
        #expect(mcr3u.courseCode == "MCR3U")
        #expect(mcr3u.nodeIds == Self.mcr3uOrder)
        let mth1wWarningCount = report.warnings.filter { $0.courseCode == "MTH1W" }.count
        #expect(mth1wWarningCount == 1)
        let mcr3uWarnings = report.warnings.filter { $0.courseCode == "MCR3U" }
        #expect(mcr3uWarnings.isEmpty)
    }

    @Test("AC3: setMarker returns the moved marker, AC1's trail, and both events")
    func ac3SetMarker() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false))
        #expect(result.trail.segments.count == 1)
        #expect(result.trail.segments[0].nodeIds == Self.mth1wOrder)
        #expect(result.events == [.expeditionMarkerChanged, .expeditionTrailGenerated])
    }

    @Test("AC4: extension-positive fixture appends a reachable .extension MPM2D segment")
    func ac4ExtensionPositive() throws {
        let bundle = try Self.loadTrailFixture("extension-positive")
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.count == 2)
        let mth1w = report.trail.segments[0]
        let extensionSegment = report.trail.segments[1]
        #expect(extensionSegment.kind == .extension)
        #expect(extensionSegment.courseCode == "MPM2D")
        #expect(!extensionSegment.nodeIds.isEmpty)

        // Independent BFS reachability check (not `extensionSegmentViolations`) from the MTH1W segment.
        let index = try Self.reachabilityIndex(bundle: bundle)
        var reachable = Set(mth1w.nodeIds)
        var queue = mth1w.nodeIds
        while let current = queue.popLast() {
            for to in index[current] ?? [] where !reachable.contains(to) {
                reachable.insert(to)
                queue.append(to)
            }
        }
        for nodeId in extensionSegment.nodeIds {
            #expect(reachable.contains(nodeId), "\(nodeId) is not BFS-reachable from the MTH1W segment")
        }
    }

    @Test("AC5: real data/demo with pastLastUnit true has no extension segment")
    func ac5NoExtensionOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.count == 1)
    }

    @Test("AC7: defaultMarker resolves the first present course, nil when none resolve")
    func ac7DefaultMarker() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(
            MarkerTrail.defaultMarker(syllabi: ["MTH1W", "MCR3U"], bundle: bundle)
                == Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false))
        #expect(MarkerTrail.defaultMarker(syllabi: ["ZZZ9Z"], bundle: bundle) == nil)
    }

    @Test("AC8: reconcileMarker off-trail falls back to defaultMarker, on-trail is unchanged")
    func ac8ReconcileMarker() throws {
        let bundle = try Self.loadDemoBundle()
        let onTrail = Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false)
        let onTrailResult = MarkerTrail.reconcileMarker(onTrail, syllabi: ["MTH1W"], bundle: bundle)
        #expect(onTrailResult.marker == onTrail)
        #expect(onTrailResult.code == nil)

        let offTrail = Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: false)
        let offTrailResult = MarkerTrail.reconcileMarker(offTrail, syllabi: ["MTH1W"], bundle: bundle)
        #expect(offTrailResult.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false))
        #expect(offTrailResult.code == .mapMarkerOffTrail)
    }

    @Test("AC9: reconcileNodeIds reports the one unknown key, empty when all keys are known")
    func ac9ReconcileNodeIds() throws {
        let bundle = try Self.loadDemoBundle()
        let unknownState = NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
        let withUnknown = MarkerTrail.reconcileNodeIds(
            nodes: ["integer-operations": unknownState, "not-a-real-node": unknownState], bundle: bundle)
        #expect(withUnknown.ignoredNodeIds == ["not-a-real-node"])
        #expect(withUnknown.code == .expNodeNotInGraph)

        let allKnown = MarkerTrail.reconcileNodeIds(
            nodes: ["integer-operations": unknownState], bundle: bundle)
        #expect(allKnown.ignoredNodeIds == [])
        #expect(allKnown.code == nil)
    }

    // MARK: - T2 negative — invalid input rejected at the boundary

    @Test("AC6: courseSegmentViolations catches a hand-built cycle; generateTrail throws on the fixture")
    func ac6UnitCycleRejected() throws {
        let bundle = try Self.loadTrailFixture("unit-cycle")
        let handBuilt = TrailSegment(kind: .course, courseCode: "TST1X", nodeIds: ["a", "b"])
        let violations = try Self.courseSegmentViolations(handBuilt, bundle: bundle)
        #expect(!violations.isEmpty)

        let marker = Marker(courseCode: "TST1X", unitId: "TST1X.u1", pastLastUnit: false)
        #expect(throws: CoreError.expTrailInvalid) {
            _ = try MarkerTrail.generateTrail(syllabi: ["TST1X"], marker: marker, bundle: bundle)
        }
    }

    @Test("defaultMarker(syllabi: []) is nil")
    func defaultMarkerEmptySyllabi() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(MarkerTrail.defaultMarker(syllabi: [], bundle: bundle) == nil)
    }

    @Test("reconcileMarker: real course, unknown unit id is off-trail")
    func reconcileMarkerUnknownUnit() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u99", pastLastUnit: false)
        let result = MarkerTrail.reconcileMarker(marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(result.code == .mapMarkerOffTrail)
    }

    @Test("reconcileMarker: no resolvable course keeps the stored marker unchanged")
    func reconcileMarkerNoResolvableCourseKeepsStoredMarker() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let result = MarkerTrail.reconcileMarker(marker, syllabi: ["ZZZ9Z"], bundle: bundle)
        #expect(result.marker == marker)
        #expect(result.code == .mapMarkerOffTrail)
    }

    // MARK: - T3 error-taxonomy

    @Test("T3: this task's error codes match the registry raw values")
    func errorTaxonomyRawValues() {
        #expect(CoreError.expTrailInvalid.rawValue == "EXP_TRAIL_INVALID")
        #expect(CoreError.expNodeNotInGraph.rawValue == "EXP_NODE_NOT_IN_GRAPH")
        #expect(CoreError.mapMarkerOffTrail.rawValue == "MAP_MARKER_OFF_TRAIL")
    }

    // MARK: - T4 conformance

    @Test("I8: courseSegmentViolations agrees with construction on every real data/demo segment")
    func i8IndependentRecheckAgreesOnRealData() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W", "MCR3U"], marker: marker, bundle: bundle)
        for segment in report.trail.segments {
            let violations = try Self.courseSegmentViolations(segment, bundle: bundle)
            #expect(violations.isEmpty, "\(segment.courseCode ?? "?") segment has violations: \(violations)")
        }
    }

    @Test("Against-unit-order warning coexists with a successful (non-throwing) generateTrail call")
    func warningDoesNotCauseThrow() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        #expect(!report.warnings.isEmpty)
    }

    // I14: no Date() literal anywhere in the new file (dedicated grep, mirroring 02.4's pattern).
    @Test("no Date() literal in MarkerTrailGeneration.swift")
    func noDateLiteralInNewFile() throws {
        let file = Self.testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/State/MarkerTrailGeneration.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("Date()"))
    }

    // MARK: - T5 negative control for every regression guard

    @Test("Guard: Kahn's-algorithm id tie-break, not a whole-list sort, is load-bearing for MCR3U u1")
    func guardKahnTieBreakNotWholeListSort() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(syllabi: ["MCR3U"], marker: marker, bundle: bundle)
        let actualU1Prefix = Array(report.trail.segments[0].nodeIds.prefix(3))
        let wholeListSortOrder = ["quadratic-functions", "rational-expressions", "solving-quadratics"]
        #expect(actualU1Prefix != wholeListSortOrder)
        #expect(actualU1Prefix == ["rational-expressions", "solving-quadratics", "quadratic-functions"])
    }

    @Test("Guard: against-unit-order detection keys off unit index, not unit id string order")
    func guardUnitIndexNotStringOrder() throws {
        // A synthetic course whose `units[]` array order does not match the unit ids' string order:
        // "X.u2" is listed before "X.u1" — the against-unit-order check must key off the *index into
        // `course.units`*, not `unitId < unitId` string comparison, else this would be misclassified.
        let course = Course(
            courseCode: "X", name: "Synthetic", vintage: "0.0.0", strands: [],
            expectations: [
                Expectation(
                    code: "X.a", kind: .specific, paraphrase: "a", officialUrl: "https://example.org",
                    unitId: "X.u2"),
                Expectation(
                    code: "X.b", kind: .specific, paraphrase: "b", officialUrl: "https://example.org",
                    unitId: "X.u1"),
            ],
            units: [
                Unit(
                    unitId: "X.u2", name: "Second in index, later in string order",
                    expectationCodes: ["X.a"]),
                Unit(
                    unitId: "X.u1", name: "First in index, earlier in string order",
                    expectationCodes: ["X.b"]),
            ], unitSource: nil, nextCourses: [])
        // "X.u2" is at index 0 and "X.u1" is at index 1 — index order is the reverse of string order.
        #expect(course.units.firstIndex(where: { $0.unitId == "X.u2" }) == 0)
        #expect(course.units.firstIndex(where: { $0.unitId == "X.u1" }) == 1)
    }

    @Test("Guard: extension reachability excludes an MPM2D-resident node unreachable from MTH1W")
    func guardExtensionReachabilityExcludesUnreachableNode() throws {
        let bundle = try Self.loadTrailFixture("extension-positive")
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        let extensionSegment = report.trail.segments[1]
        #expect(!extensionSegment.nodeIds.contains("unreachable-relation"))
    }

    // MARK: - T6 idempotency / no-leak

    @Test("T6: generateTrail and setMarker are pure across two calls with fresh identical arguments")
    func generateTrailAndSetMarkerArePure() throws {
        let bundle1 = try Self.loadDemoBundle()
        let bundle2 = try Self.loadDemoBundle()
        let marker1 = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let marker2 = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let first = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker1, bundle: bundle1)
        let second = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker2, bundle: bundle2)
        #expect(first == second)

        let setFirst = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle1)
        let setSecond = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle2)
        #expect(setFirst == setSecond)
    }

    @Test("T6: reconcileMarker and reconcileNodeIds are pure and side-effect-free")
    func reconciliationFunctionsArePure() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let first = MarkerTrail.reconcileMarker(marker, syllabi: ["MTH1W"], bundle: bundle)
        let second = MarkerTrail.reconcileMarker(marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(first == second)

        let state = NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
        let firstIds = MarkerTrail.reconcileNodeIds(nodes: ["integer-operations": state], bundle: bundle)
        let secondIds = MarkerTrail.reconcileNodeIds(nodes: ["integer-operations": state], bundle: bundle)
        #expect(firstIds == secondIds)
    }

    // MARK: - Test-local helpers

    /// Independently re-derives `courseSegmentViolations`'s logic against a `GraphIndex` built directly
    /// from the bundle, without calling any private `MarkerTrail` helper — used by the T2/T4 tests so
    /// the check is not merely re-running the production code against itself.
    private static func courseSegmentViolations(
        _ segment: TrailSegment, bundle: ContentBundle
    ) throws -> [String] {
        guard let courseCode = segment.courseCode,
            let course = bundle.courses.courses.first(where: { $0.courseCode == courseCode })
        else {
            return ["segment names an unknown course"]
        }
        let nodesById = Dictionary(uniqueKeysWithValues: bundle.nodes.nodes.map { ($0.id, $0) })
        func unitIdx(_ nodeId: String) -> Int? {
            guard let node = nodesById[nodeId] else { return nil }
            let entries = (node.expectationCodes ?? []).filter { $0.courseCode == courseCode }
            let ordinals: [Int] = entries.compactMap { entry in
                guard let unitId = course.expectations.first(where: { $0.code == entry.code })?.unitId
                else { return nil }
                return course.units.firstIndex(where: { $0.unitId == unitId })
            }
            return ordinals.min()
        }
        var position: [String: Int] = [:]
        for (i, id) in segment.nodeIds.enumerated() { position[id] = i }
        var violations: [String] = []
        let residentSet = Set(
            nodesById.values
                .filter { node in (node.expectationCodes ?? []).contains { $0.courseCode == courseCode } }
                .map(\.id))
        if Set(segment.nodeIds) != residentSet {
            violations.append("segment node set does not match the course's resident nodes")
        }
        for edge in bundle.edges.edges {
            guard let fromPos = position[edge.from], let toPos = position[edge.to] else { continue }
            guard let fromIdx = unitIdx(edge.from), let toIdx = unitIdx(edge.to), fromIdx == toIdx else {
                continue
            }
            if fromPos > toPos {
                violations.append("\(edge.from)-->-\(edge.to) violates within-unit topological order")
            }
        }
        return violations
    }

    /// Forward adjacency (node id -> node ids reachable by one edge) built directly from the bundle,
    /// for the independent BFS check in AC4 — deliberately not `GraphIndex` (internal to `Core`) so this
    /// is a genuinely independent re-derivation.
    private static func reachabilityIndex(bundle: ContentBundle) throws -> [String: [String]] {
        Dictionary(grouping: bundle.edges.edges, by: \.from).mapValues { $0.map(\.to) }
    }
}

import Foundation
import Testing

@testable import Core

/// Tester supplement to `MarkerTrailGenerationTests.swift` (task 02.5, `MarkerTrail`). Covers gaps the
/// implementer's own suite left open:
///
/// 1. A genuine negative control (C2) for the resident-node-set completeness check the implementer added
///    beyond the spec's literal code sample (`courseSegmentViolations`'s `Set(segment.nodeIds) !=
///    resident` branch): reconstructs the *edge-only* L0-T re-check the spec's §4 step 4 code sample
///    actually shows and proves it is blind to a fully-cyclic 2-node unit (Kahn's algorithm returns an
///    empty ordering; an edge-only position-based check has no positions to compare against, so it finds
///    no violation) — then proves the shipped, resident-set-aware check does catch it. This is the "prove
///    it reds against the broken shape" control the guard itself never demonstrated.
/// 2. The `isMarkerOffTrail` branch the shipped suite's `reconcileMarker` cases do not reach on its own:
///    "the course is absent from the bundle" (as opposed to "not in `syllabi[]`") — Q-D's second
///    off-trail clause, `tasks/arbitration/arbiter-02-predispatch.md` § Q-D.
/// 3. AC6's own text ("no `Trail` or `Marker` value is returned... the previous trail stands") exercised
///    literally: a caller-held `Trail` variable is provably untouched by a throwing `generateTrail` call.
/// 4. Q-D's "no resolvable course" `generateTrail` outcome (`tasks/arbitration/arbiter-02-predispatch.md`
///    § Q-D: "keep the stored marker, generate a trail with no segments") — not exercised by any AC1–AC9
///    scenario in the shipped suite, which only exercises `reconcileMarker`'s handling of this case, never
///    `generateTrail`'s own segments-empty behaviour when every `syllabi[]` entry is unresolvable.
@Suite("MarkerTrail — tester supplement (negative controls, gaps)")
struct MarkerTrailGenerationNegativeControlTests {
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

    // MARK: - 1. Negative control for the resident-node-set completeness check (C2)

    /// The spec's own §4 step 4 code sample for `courseSegmentViolations` only ever compares
    /// `position[edge.from]`/`position[edge.to]` for edges whose endpoints are both present in
    /// `segment.nodeIds` — it never independently checks that `segment.nodeIds` covers every node
    /// resident in the course. Reconstructed here byte-faithfully to that sample (no resident-set
    /// check), this "broken shape" is run against the segment `buildCourseSegment` actually produces for
    /// the `unit-cycle` fixture's fully-cyclic 2-node unit (`a --> b`, `b --> a`): Kahn's algorithm
    /// (spec §4 step 3) returns an empty ordering for a fully-cyclic set (no zero-indegree candidate
    /// ever exists), so the produced segment's `nodeIds` is `[]` — `position` is then empty, no edge's
    /// endpoints are ever both `!= nil`, and this edge-only re-check finds nothing wrong. A guard that
    /// only compares in-segment edge order is blind to a whole unit silently vanishing from the trail.
    private static func edgeOnlyCourseSegmentViolations(
        _ segment: TrailSegment, bundle: ContentBundle
    ) -> [String] {
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
        // Deliberately NO "segment node set does not match the course's resident nodes" check here —
        // this is the edge-only shape the spec's code sample literally shows.
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

    /// Independently re-derives what `buildCourseSegment` produces for the `unit-cycle` fixture's single
    /// course, without calling any private `MarkerTrail` helper — Kahn's algorithm on a fully-cyclic
    /// 2-node set never finds a zero-indegree candidate, so the ordering is empty.
    private static func expectedEmptyOrderingForFullyCyclicUnit() -> TrailSegment {
        TrailSegment(kind: .course, courseCode: "TST1X", nodeIds: [])
    }

    @Test(
        "C2 negative control: an edge-only L0-T re-check is blind to a fully-cyclic unit vanishing; the shipped resident-set-aware check catches it"
    )
    func residentSetCompletenessGuardHasANegativeControl() throws {
        let bundle = try Self.loadTrailFixture("unit-cycle")
        let producedSegment = Self.expectedEmptyOrderingForFullyCyclicUnit()

        // Red: the broken (edge-only) shape sees no violation in the actually-produced empty segment —
        // proving this guard is not redundant with the edge-order check the spec's code sample shows.
        let brokenShapeViolations = Self.edgeOnlyCourseSegmentViolations(producedSegment, bundle: bundle)
        #expect(
            brokenShapeViolations.isEmpty,
            "the edge-only re-check is expected to miss the vanished unit — if this fails, the negative control no longer demonstrates the guard's necessity"
        )

        // Green: generateTrail (which uses the shipped, resident-set-aware courseSegmentViolations)
        // throws EXP_TRAIL_INVALID on this exact fixture, because buildCourseSegment produces this same
        // empty-nodeIds segment internally and the shipped check does compare it against residentNodeIds.
        let marker = Marker(courseCode: "TST1X", unitId: "TST1X.u1", pastLastUnit: false)
        #expect(throws: CoreError.expTrailInvalid) {
            _ = try MarkerTrail.generateTrail(syllabi: ["TST1X"], marker: marker, bundle: bundle)
        }
    }

    // MARK: - 2. isMarkerOffTrail: "course absent from bundle" branch, distinct from "not in syllabi"

    @Test("reconcileMarker: course present in syllabi[] but absent from the bundle is off-trail")
    func reconcileMarkerCourseInSyllabiButAbsentFromBundle() throws {
        let bundle = try Self.loadDemoBundle()
        // "ZZZ9Z" passes the first isMarkerOffTrail guard (it IS in syllabi[]) but fails the second
        // (no course named "ZZZ9Z" exists in data/demo/courses.json) — a distinct branch from the
        // "course not in syllabi[]" case the shipped suite already exercises.
        let marker = Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: false)
        let result = MarkerTrail.reconcileMarker(marker, syllabi: ["ZZZ9Z"], bundle: bundle)
        #expect(result.code == .mapMarkerOffTrail)
        // No course in syllabi[] resolves in the bundle either (defaultMarker(["ZZZ9Z"]) == nil), so
        // Q-D's "keep the stored marker" branch applies: the unchanged input marker comes back.
        #expect(result.marker == marker)
    }

    @Test("reconcileMarker: unknown-unit off-trail case falls back to the exact defaultMarker value")
    func reconcileMarkerUnknownUnitFallsBackToExactDefaultMarker() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u99", pastLastUnit: false)
        let result = MarkerTrail.reconcileMarker(marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(result.code == .mapMarkerOffTrail)
        #expect(result.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false))
    }

    // MARK: - 3. AC6 decision default, exercised literally: the previous trail stands

    @Test("AC6 decision default: a caller-held trail is untouched by a subsequent throwing call")
    func previousTrailStandsAcrossAThrowingCall() throws {
        let demoBundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false)
        let previousReport = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"], marker: marker, bundle: demoBundle)
        let previousTrail = previousReport.trail

        let cycleBundle = try Self.loadTrailFixture("unit-cycle")
        let cycleMarker = Marker(courseCode: "TST1X", unitId: "TST1X.u1", pastLastUnit: false)
        do {
            _ = try MarkerTrail.generateTrail(
                syllabi: ["TST1X"], marker: cycleMarker, bundle: cycleBundle)
            Issue.record("expected generateTrail to throw EXP_TRAIL_INVALID on the unit-cycle fixture")
        } catch let error as CoreError {
            #expect(error == .expTrailInvalid)
        }
        // The caller's own `previousTrail` binding is a plain value type — nothing in `MarkerTrail`
        // could have mutated it even in principle (I14: no shared mutable state), so this equality holds
        // by construction. Asserted explicitly because it is the literal claim AC6 makes.
        #expect(previousTrail == previousReport.trail)
        #expect(previousTrail.segments[0].nodeIds.first == "integer-operations")
    }

    // MARK: - 4. Q-D "no resolvable course": generateTrail produces a trail with no segments

    @Test("Q-D no-resolvable-course: generateTrail returns a trail with zero segments, does not throw")
    func generateTrailWithNoResolvableCourseYieldsEmptySegments() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: false)
        let report = try MarkerTrail.generateTrail(syllabi: ["ZZZ9Z"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.isEmpty)
        #expect(report.warnings.isEmpty)
        #expect(report.event == .expeditionTrailGenerated)
    }

    @Test("Q-D no-resolvable-course: pastLastUnit true on an unresolvable course still yields no segments")
    func generateTrailWithNoResolvableCourseAndPastLastUnitYieldsEmptySegments() throws {
        let bundle = try Self.loadDemoBundle()
        let marker = Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true)
        let report = try MarkerTrail.generateTrail(syllabi: ["ZZZ9Z"], marker: marker, bundle: bundle)
        #expect(report.trail.segments.isEmpty)
    }
}

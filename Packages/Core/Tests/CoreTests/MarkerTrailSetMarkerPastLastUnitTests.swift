import Foundation
import Testing

@testable import Core

/// Task 02.5b's regression suite for `MarkerTrail.setMarker(…, pastLastUnit: true)`
/// (`Sources/Core/State/MarkerTrailGeneration.swift`). Q4 arbitration
/// `tasks/arbitration/arbiter-03-07-past-last-unit.md`: 02.5 quoted
/// `contracts/interaction-contract.md` § 3's rule ("setting it writes the course's last unit as
/// `unit_id`") but never implemented it in `setMarker`. This file exercises the fix, its negative
/// control, the unchanged trail/warnings/events, the `EXP_TRAIL_INVALID` error path, and the
/// set → relaunch reconciliation seam.
@Suite("MarkerTrail.setMarker past the last unit (interaction-contract § 3)")
struct MarkerTrailSetMarkerPastLastUnitTests {
    /// `Packages/Core/Tests/CoreTests`, located the same way `MarkerTrailGenerationTests` does.
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

    // MARK: - T1 happy path

    @Test("AC1: MTH1W, past last unit, writes u4 whatever unitId the caller passed")
    func ac1MTH1WWritesLastUnit() throws {
        let bundle = try Self.loadDemoBundle()
        let mth1w = try #require(bundle.courses.courses.first { $0.courseCode == "MTH1W" })
        let lastUnitId = try #require(mth1w.units.last?.unitId)
        #expect(lastUnitId == "MTH1W.u4")
        #expect(lastUnitId != "MTH1W.u2")

        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true))
    }

    @Test("AC2: MCR3U, past last unit, writes u3 whatever unitId the caller passed")
    func ac2MCR3UWritesLastUnit() throws {
        let bundle = try Self.loadDemoBundle()
        let mcr3u = try #require(bundle.courses.courses.first { $0.courseCode == "MCR3U" })
        let lastUnitId = try #require(mcr3u.units.last?.unitId)
        #expect(lastUnitId == "MCR3U.u3")
        #expect(lastUnitId != "MCR3U.u1")

        let result = try MarkerTrail.setMarker(
            courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: true, syllabi: ["MCR3U"],
            bundle: bundle)
        #expect(result.marker.unitId == "MCR3U.u3")
        #expect(result.marker.pastLastUnit == true)
    }

    @Test("AC3: idempotent when the caller already passed the last unit")
    func ac3IdempotentOnLastUnit() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true))
    }

    // MARK: - T2 negative

    @Test("AC4: pastLastUnit false, unitId passes through unchanged — negative control")
    func ac4NegativeControlFlagGatesSubstitution() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false))
    }

    @Test("AC7: unresolvable course keeps the caller's unitId and does not throw")
    func ac7UnresolvableCourseKeepsCallerUnitId() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker == Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true))
    }

    // MARK: - T3 error taxonomy

    @Test("AC8: EXP_TRAIL_INVALID still propagates when pastLastUnit is true")
    func ac8ErrorTaxonomyUnchanged() throws {
        let bundle = try Self.loadTrailFixture("unit-cycle")
        #expect(throws: CoreError.expTrailInvalid) {
            try MarkerTrail.setMarker(
                courseCode: "TST1X", unitId: "TST1X.u1", pastLastUnit: true, syllabi: ["TST1X"],
                bundle: bundle)
        }
        #expect(CoreError.expTrailInvalid.rawValue == "EXP_TRAIL_INVALID")
    }

    // MARK: - T4 conformance: trail/warnings/events unchanged, real composition

    @Test("AC5: trail, warnings and events unchanged on real data/demo")
    func ac5TrailWarningsEventsUnchangedOnRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        let directReport = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true), bundle: bundle)
        #expect(result.trail == directReport.trail)
        #expect(result.warnings == directReport.warnings)
        #expect(result.events == [.expeditionMarkerChanged, .expeditionTrailGenerated])
    }

    @Test("AC5: extension segment is still built on the extension-positive fixture")
    func ac5ExtensionSegmentStillBuilt() throws {
        let bundle = try Self.loadTrailFixture("extension-positive")
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        #expect(result.marker.unitId == "MTH1W.u4")
        let directReport = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true), bundle: bundle)
        #expect(result.trail == directReport.trail)
        let lastSegment = try #require(result.trail.segments.last)
        #expect(lastSegment.kind == .extension)
        #expect(lastSegment.courseCode == "MPM2D")
    }

    // MARK: - T4/seam: set, then relaunch reconciliation

    @Test("AC6: the set marker still reconciles on the trail at relaunch")
    func ac6ReconcilesAfterSet() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle)
        let reconciled = MarkerTrail.reconcileMarker(result.marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(reconciled.code == nil)
        #expect(reconciled.marker == result.marker)
    }

    // MARK: - T6 idempotency across fresh bundles

    @Test("T6: two AC1 calls over two freshly loaded bundles return equal results")
    func ac1IdempotentAcrossFreshBundles() throws {
        let bundle1 = try Self.loadDemoBundle()
        let bundle2 = try Self.loadDemoBundle()
        let first = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle1)
        let second = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: bundle2)
        #expect(first == second)
    }
}

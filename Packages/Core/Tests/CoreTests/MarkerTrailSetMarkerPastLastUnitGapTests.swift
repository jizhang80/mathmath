import Foundation
import Testing

@testable import Core

/// Tester's gap-filling suite for task 02.5b (implementer commit c9e893d). Reads
/// `MarkerTrailSetMarkerPastLastUnitTests.swift` (AC1-AC8, T1-T6) as the baseline and adds only what it
/// does not already cover: the C2 negative-control demonstration that the regression guard actually reds
/// on a reconstructed pre-fix implementation, the AC7 -> `reconcileMarker` off-trail chain the contract
/// names but the implementer's suite stops short of, the full set -> persist -> reconcile -> regenerate
/// relaunch seam run twice for stability, and the `StateMerge` tie-break case where BOTH sides' markers
/// have `pastLastUnit == true` (absent from `StateMergeTests.swift`/`StateMergeBoundaryTests.swift` — grep
/// confirmed no existing case pairs two `pastLastUnit: true` markers).
@Suite(
    "MarkerTrail.setMarker past the last unit — gap-filling (interaction-contract § 3, data-model § StudentState)"
)
struct MarkerTrailSetMarkerPastLastUnitGapTests {
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

    // MARK: - C2 negative control: the guard must red against the reconstructed pre-fix shape

    /// Reproduces the exact pre-02.5b body quoted in the task spec §1 ("The code being corrected") — a
    /// test-local reconstruction only, never a call into product code, so this does not touch
    /// `Sources/Core`. It proves AC1's assertion is load-bearing: an implementation that never substitutes
    /// the last unit fails the same assertion the fixed `setMarker` passes.
    private static func preFixSetMarkerUnitId(courseCode: String, unitId: String, pastLastUnit: Bool)
        -> String
    {
        // Pre-02.5b `MarkerTrailGeneration.swift:94`: `Marker(courseCode:, unitId: unitId, pastLastUnit:)`
        // — `unitId` is never looked up against `bundle.courses`.
        unitId
    }

    @Test("C2: the reconstructed pre-fix shape reds against AC1's assertion")
    func negativeControlRedsOnPreFixShape() throws {
        let bundle = try Self.loadDemoBundle()
        let mth1w = try #require(bundle.courses.courses.first { $0.courseCode == "MTH1W" })
        let lastUnitId = try #require(mth1w.units.last?.unitId)
        #expect(lastUnitId == "MTH1W.u4")

        // The fixed implementation passes this assertion (mirrors AC1).
        let fixed = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"], bundle: bundle)
        #expect(fixed.marker.unitId == lastUnitId)

        // The reconstructed pre-fix shape does NOT: it keeps the caller's unitId verbatim. This is the red
        // repro that shows the guard discriminates fixed from broken.
        let preFixUnitId = Self.preFixSetMarkerUnitId(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true)
        #expect(preFixUnitId != lastUnitId)
        #expect(preFixUnitId == "MTH1W.u2")
    }

    // MARK: - AC7 -> reconcileMarker off-trail chain (interaction-contract § 3, "regardless of past_last_unit")

    @Test("AC7 chain: a course absent from syllabi reconciles off-trail to the syllabi's default marker")
    func ac7ChainReconcilesOffTrailToDefault() throws {
        let bundle = try Self.loadDemoBundle()
        let result = try MarkerTrail.setMarker(
            courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true, syllabi: ["MTH1W"], bundle: bundle)
        #expect(result.marker == Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true))

        let reconciled = MarkerTrail.reconcileMarker(result.marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(reconciled.code == .mapMarkerOffTrail)
        let expectedDefault = try #require(MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle: bundle))
        #expect(reconciled.marker == expectedDefault)
        // The contract's "regardless of past_last_unit" clause: the marker is off-trail even though the
        // caller set past_last_unit true, not despite it.
        #expect(reconciled.marker.pastLastUnit != true)
    }

    // MARK: - Full relaunch seam, run twice for stability (setMarker -> persist -> reconcileMarker -> generateTrail)

    @Test("seam: setMarker -> reconcileMarker -> generateTrail is stable across two relaunches")
    func relaunchSeamStableAcrossTwoCycles() throws {
        let bundle = try Self.loadDemoBundle()
        let setResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true, syllabi: ["MTH1W"], bundle: bundle)
        #expect(setResult.marker.unitId == "MTH1W.u4")

        // Relaunch cycle 1: the persisted marker (simulated by `setResult.marker`, since Core owns no
        // file I/O — persistence is the app's concern) reconciles clean and regenerates the same trail.
        let reconciled1 = MarkerTrail.reconcileMarker(setResult.marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(reconciled1.code == nil)
        #expect(reconciled1.marker == setResult.marker)
        let regenerated1 = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"], marker: reconciled1.marker, bundle: bundle)
        #expect(regenerated1.trail == setResult.trail)

        // Relaunch cycle 2: feeding cycle 1's reconciled marker back in produces an identical result —
        // the seam does not drift on repeated application.
        let reconciled2 = MarkerTrail.reconcileMarker(reconciled1.marker, syllabi: ["MTH1W"], bundle: bundle)
        #expect(reconciled2.code == nil)
        #expect(reconciled2.marker == reconciled1.marker)
        let regenerated2 = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"], marker: reconciled2.marker, bundle: bundle)
        #expect(regenerated2.trail == regenerated1.trail)
    }

    // MARK: - StateMerge: both sides' markers have pastLastUnit == true (absent from StateMergeTests)

    private static func trail(courseCode: String = "MTH1W", nodeIds: [String] = []) -> Trail {
        Trail(segments: [TrailSegment(kind: .course, courseCode: courseCode, nodeIds: nodeIds)])
    }

    private static func state(marker: Marker) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "1.0.0", syllabi: [marker.courseCode], marker: marker,
            nodes: [:], trail: Self.trail(courseCode: marker.courseCode), expeditionLog: [], probeLog: [],
            installDay: "2026-01-01", consentOn: true)
    }

    @Test("StateMerge: both markers past_last_unit true, tie broken by the greater unit ordinal")
    func mergeBothPastLastUnitTrueTieBreaksByOrdinal() {
        // data-model § StudentState merge: "past_last_unit: true ranks above any unit, else the greater
        // unit ordinal n of unit_id". When BOTH sides rank equally on the first tier (both true), the
        // ranking falls through to the unit-ordinal comparison, exactly as it would for two `false`
        // markers — this pairing is the one case no existing StateMerge test exercises.
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)
        let markerB = Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true)
        let a = Self.state(marker: markerA)
        let b = Self.state(marker: markerB)
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerA)
        // Commutativity holds for this pairing too.
        let mergedReversed = StateMerge.merge(b, a)
        #expect(mergedReversed.marker == markerA)
    }
}

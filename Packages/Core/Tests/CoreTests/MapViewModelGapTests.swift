import Foundation
import Testing

@testable import Core

/// Additional coverage for `MapViewModel` (`Sources/Core/Map/MapViewModel.swift`) beyond the
/// implementer's own T1-T9b suite in `MapViewModelTests.swift`
/// (`tasks/epic-03-task-06-map-view-model.md` §5). Finds gaps the smoke does not close: the position
/// indicator (AC5) was never asserted at all; the W2-step-2 "no action" branch (Q-D) was never isolated;
/// the record-half guard (AC9/I4) was only ever exercised over two hand-picked nodes rather than every
/// node in the bundle; the focus frame's extension-window branch (AC8, past_last_unit) was untested; the
/// due ring's exclusion of non-cleared mastery was never pushed against an adversarial (but
/// schema-legal) `nextDue` on a non-cleared node; and no test asserted the "no I/O, no clock read"
/// (§4 step 8, I14) property structurally, with its own negative control.
@Suite("MapViewModel: gap coverage")
struct MapViewModelGapTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var demoBundleDir: URL {
        repoRoot.appendingPathComponent("data/demo")
    }

    private static var extensionPositiveFixtureDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/trail/extension-positive")
    }

    private static var mapViewModelSourcePath: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/Map/MapViewModel.swift")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    private static func today() throws -> CalendarDay {
        try #require(CalendarDay(iso: "2026-09-10"))
    }

    private static func emptyState(
        bundle: ContentBundle, marker: Marker, trail: Trail, nodes: [String: NodeState] = [:],
        syllabi: [String] = ["MTH1W"]
    ) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: syllabi, marker: marker,
            nodes: nodes, trail: trail, expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    // MARK: - AC5: position indicator

    @Test("AC5: position indicator is the first trail node that is not upstream and not cleared")
    func positionIndicatorSkipsUpstreamAndClearedInTrailOrder() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        // Marker at MTH1W.u3: units u1 (integer-operations, order-of-operations, rational-numbers) and
        // u2 (exponent-laws, scientific-notation) are upstream — verified against data/demo's own
        // expectation_codes (task context bundle "Data re-read", cross-checked against
        // data/demo/courses.json's unit ordering) independently of MapViewModel's own upstream helper.
        let upstreamKnown: Set<String> = [
            "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
            "scientific-notation",
        ]
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u3", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        let trailFlat = setMarkerResult.trail.segments.flatMap(\.nodeIds)
        let expected = trailFlat.first { id in
            !upstreamKnown.contains(id) && (state.nodes[id]?.mastery ?? .fog) != .cleared
        }
        #expect(expected != nil, "the fixture must produce a non-vacuous trail order")
        #expect(model.positionIndicatorNodeId == expected)
    }

    @Test("AC5: position indicator is nil once every trail-resident node is cleared")
    func positionIndicatorNilWhenEveryTrailNodeIsCleared() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        let trailFlat = setMarkerResult.trail.segments.flatMap(\.nodeIds)
        #expect(!trailFlat.isEmpty, "the trail must be non-empty for this test to be meaningful")

        var nodes: [String: NodeState] = [:]
        for id in trailFlat {
            nodes[id] = NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
                ladderRung: 0, remediated: nil)
        }
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)
        #expect(model.positionIndicatorNodeId == nil)
    }

    // MARK: - Q-D: no-action branch of W2 step 2

    @Test("W2 step 2 / Q-D: a fog node that is neither on the fringe nor upstream offers no action")
    func fogNodeOffFringeAndOffUpstreamOffersNoAction() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        // quadratic-functions carries no MTH1W expectation_codes (data/demo/nodes.json), so it is
        // neither resident of MTH1W (hence never upstream) nor ever inside MTH1W's window (hence never
        // fringe-eligible via the window guard) nor blocked — the pure Q-D "else -> nil" case.
        let offTrailNode = try #require(model.nodes.first { $0.id == "quadratic-functions" })
        #expect(offTrailNode.fogLevel == .fog)
        #expect(offTrailNode.upstream == false)
        #expect(offTrailNode.action == nil)
    }

    // MARK: - AC9 / I4 record half, exhaustive over every bundle node

    @Test("I4 record half: every bundle node, blocked one at a time, always gets checkHere and never include")
    func everyNodeBlockedIndividuallyAlwaysGetsCheckHere() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)

        for node in bundle.nodes.nodes {
            let nodes: [String: NodeState] = [
                node.id: NodeState(
                    mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                    remediated: nil)
            ]
            let state = Self.emptyState(
                bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes)
            let model = MapViewModel.derive(bundle: bundle, state: state, today: today)
            let view = try #require(model.nodes.first { $0.id == node.id })
            #expect(view.action == .checkHere, "node \(node.id) must offer checkHere while blocked")
            #expect(view.fogLevel == .blocked)
        }
    }

    // MARK: - AC1 refined: exactly the three populated content regions carry a fraction

    @Test("AC1: only number-operations, algebra and functions carry a non-nil cleared fraction")
    func onlyThePopulatedRegionsCarryAFraction() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W", "MCR3U"],
            bundle: bundle)
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail,
            syllabi: ["MTH1W", "MCR3U"])

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        let populated: Set<RegionId> = [.numberOperations, .algebra, .functions]
        for region in model.regions {
            if populated.contains(region.id) {
                #expect(
                    region.clearedFraction != nil,
                    "\(region.id) has bundle nodes and must carry a fraction")
            } else {
                #expect(
                    region.clearedFraction == nil,
                    "\(region.id) has no bundle nodes (or is horizon) and must be pure fog")
            }
        }
    }

    // MARK: - AC8: focus frame over the extension window (past_last_unit)

    @Test("AC8: past_last_unit focus frame is the bounding box of the extension segment's own nodes")
    func focusFrameBoundsExtensionSegmentWhenPastLastUnit() throws {
        let fixtureBundle = try BundleIO.read(from: Self.extensionPositiveFixtureDir)
        let today = try Self.today()
        let mth1w = try #require(fixtureBundle.courses.courses.first(where: { $0.courseCode == "MTH1W" }))
        let lastUnitId = try #require(mth1w.units.last?.unitId)
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: lastUnitId, pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: fixtureBundle)
        let state = Self.emptyState(
            bundle: fixtureBundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)

        let model = MapViewModel.derive(bundle: fixtureBundle, state: state, today: today)

        // The extension segment's own (already-verified, T6/AC4) node list is the ground truth for the
        // past_last_unit window (contract §3: "the marker.unit ∪ next(marker.unit) window ... is the
        // nodes of the extension segment"); positions are looked up independently via a freshly built
        // GraphIndex, never through MapViewModel's own private focus-frame computation.
        let extensionSegment = try #require(model.trailSegments.first { $0.dashed == true })
        #expect(!extensionSegment.nodeIds.isEmpty, "the fixture's extension segment must be non-empty")
        let index = GraphIndex(bundle: fixtureBundle)
        let positions = extensionSegment.nodeIds.compactMap { index.nodesById[$0]?.position }
        #expect(model.focusFrame.minX == positions.map(\.x).min())
        #expect(model.focusFrame.minY == positions.map(\.y).min())
        #expect(model.focusFrame.maxX == positions.map(\.x).max())
        #expect(model.focusFrame.maxY == positions.map(\.y).max())
    }

    // MARK: - AC3: due ring never appears on a non-cleared node, even given a schema-legal past nextDue

    @Test("AC3: a blocked or fog node with a past nextDue never gets a due ring")
    func dueRingNeverAppearsOnNonClearedMasteryEvenWithPastNextDue() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        // Schema-legal but adversarial: nextDue in the past on a blocked node and on an untouched (fog)
        // node's stand-in — StudentState's NodeState carries nextDue independently of mastery.
        let nodes: [String: NodeState] = [
            "polynomials": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: "2020-01-01", nextDue: "2020-01-02",
                ladderRung: 0, remediated: nil)
        ]
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)
        let blockedView = try #require(model.nodes.first { $0.id == "polynomials" })
        #expect(blockedView.due == false)
        // A fog node (no NodeState entry at all, so no nextDue) also never carries a due ring.
        let fogView = try #require(model.nodes.first { $0.id == "factoring" })
        #expect(fogView.due == false)
    }

    // MARK: - Determinism over independently-constructed-but-equal inputs (AC11, stronger than same-instance)

    @Test("AC11: two independently constructed but value-equal inputs derive to equal models")
    func independentlyConstructedEqualInputsDeriveEqualModels() throws {
        let bundleA = try Self.loadDemoBundle()
        let bundleB = try Self.loadDemoBundle()
        let todayA = try #require(CalendarDay(iso: "2026-09-10"))
        let todayB = try #require(CalendarDay(iso: "2026-09-10"))
        let markerA = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundleA)
        let markerB = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundleB)
        let stateA = Self.emptyState(bundle: bundleA, marker: markerA.marker, trail: markerA.trail)
        let stateB = Self.emptyState(bundle: bundleB, marker: markerB.marker, trail: markerB.trail)

        let modelA = MapViewModel.derive(bundle: bundleA, state: stateA, today: todayA)
        let modelB = MapViewModel.derive(bundle: bundleB, state: stateB, today: todayB)
        #expect(modelA == modelB)
    }

    // MARK: - I14 / §4 step 8: no I/O, no clock read, structural guard with its own negative control

    private static let forbiddenTimeAndIOTokens = [
        "Date()", "FileManager", "contentsOf", "Bundle.main", "URLSession", "TimeZone.current",
        "Locale.current", "ProcessInfo",
    ]

    /// Returns the subset of `forbiddenTimeAndIOTokens` present anywhere in `source`, skipping `//`-only
    /// comment lines. Mirrors the shape of `MapViewModelTests.restatedDeclarations(in:)` / the codebase's
    /// `ImportBoundaryNegativeControlTests` precedent: one small scan helper, exercised over both the
    /// real file and synthetic text.
    private static func forbiddenTimeOrIOTokens(in source: String) -> Set<String> {
        var found: Set<String> = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            for token in forbiddenTimeAndIOTokens where line.contains(token) {
                found.insert(token)
            }
        }
        return found
    }

    @Test("§4 step 8 / I14: MapViewModel.swift reads no clock and performs no I/O")
    func realFileContainsNoClockOrIOTokens() throws {
        let text = try String(contentsOf: Self.mapViewModelSourcePath, encoding: .utf8)
        #expect(!text.isEmpty, "empty scan is a FAIL")
        #expect(text.contains("static func derive("), "the real file must resolve and contain derive(")
        let found = Self.forbiddenTimeOrIOTokens(in: text)
        #expect(found.isEmpty, "MapViewModel.swift reads the clock or performs I/O via: \(found)")
    }

    @Test("negative control: the clock/IO scan detects a planted Date() and FileManager use")
    func clockOrIOScanDetectsPlantedViolation() throws {
        let planted = """
            static func derive(bundle: ContentBundle) -> MapViewModel {
                let now = Date()
                let files = FileManager.default.contentsOfDirectory(atPath: ".")
                return MapViewModel()
            }
            """
        let found = Self.forbiddenTimeOrIOTokens(in: planted)
        #expect(found.contains("Date()"))
        #expect(found.contains("FileManager"))
    }

    @Test(
        "negative control: the clock/IO scan reports nothing on a clean fixture (comment mentioning Date())"
    )
    func clockOrIOScanIsCleanOnACommentOnlyMention() throws {
        let clean = """
            static func derive(bundle: ContentBundle) -> MapViewModel {
                // never call Date() or FileManager here — today is always the caller's CalendarDay
                return MapViewModel()
            }
            """
        let found = Self.forbiddenTimeOrIOTokens(in: clean)
        #expect(found.isEmpty)
    }

    // MARK: - I11: the zoom threshold constant carries its required [ESTIMATE] tag

    @Test("I11: nodeNameZoomThreshold's declaration is documented with an [ESTIMATE] tag")
    func zoomThresholdConstantCarriesEstimateTag() throws {
        let text = try String(contentsOf: Self.mapViewModelSourcePath, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let declarationIndex = try #require(
            lines.firstIndex { $0.contains("static let nodeNameZoomThreshold") })
        // The tagging convention is a doc comment on the lines immediately above the declaration.
        let precedingWindow = lines[max(0, declarationIndex - 5)..<declarationIndex].joined(separator: "\n")
        #expect(precedingWindow.contains("[ESTIMATE"), "the zoom threshold constant must carry [ESTIMATE]")
    }
}

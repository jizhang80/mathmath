import Foundation
import Testing

@testable import Core

/// Gap coverage for `MapFacade` beyond `MapFacadeTests.swift`'s AC5-AC14 happy paths: read-only panel
/// actions never write to disk, and `include` on a node genuinely upstream of the marker (distinct from
/// the "neither fringe nor upstream" gap `MapFacadeTests` already covers) is `.ignored` with no student
/// text (arbiter-03-predispatch.md § Q-D).
@Suite("MapFacade — gap coverage")
struct MapFacadeGapTests {
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

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    private static func today() throws -> CalendarDay {
        try #require(CalendarDay(iso: "2026-09-10"))
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private static func freshMTH1WMap() throws -> (map: MapState, bundle: ContentBundle, stateURL: URL) {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let (map, _) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil,
            today: try Self.today())
        return (map, bundle, stateURL)
    }

    // MARK: - Read-only panel actions never write (arbiter-03 § Q-F: façade actions either persist or don't)

    @Test("nodePanelContent/regionPanelContent/landmarkPanelContent never touch stateURL's bytes")
    func panelContentActionsNeverWrite() throws {
        let (map, _, stateURL) = try Self.freshMTH1WMap()
        let before = try Data(contentsOf: stateURL)

        _ = MapFacade.nodePanelContent(nodeId: "integer-operations", mapState: map)
        _ = MapFacade.regionPanelContent(regionId: .numberOperations, mapState: map)
        _ = MapFacade.landmarkPanelContent(
            landmarkId: "canadian-mortgage-compounding", mapState: map)
        // Unknown ids too — a `nil`-returning lookup must not have written as a side effect either.
        _ = MapFacade.nodePanelContent(nodeId: "not-a-real-node", mapState: map)
        _ = MapFacade.regionPanelContent(regionId: .analysis, mapState: map)
        _ = MapFacade.landmarkPanelContent(landmarkId: "not-a-real-landmark", mapState: map)

        #expect(try Data(contentsOf: stateURL) == before)
    }

    @Test("checkHere and unitExpedition never touch stateURL's bytes (hand-off actions, no persistence)")
    func handOffActionsNeverWrite() throws {
        let (map, _, stateURL) = try Self.freshMTH1WMap()
        let before = try Data(contentsOf: stateURL)

        _ = MapFacade.checkHere(nodeId: "polynomials", mapState: map)
        _ = try MapFacade.unitExpedition(unitId: "MTH1W.u1", mapState: map, today: try Self.today())

        #expect(try Data(contentsOf: stateURL) == before)
    }

    // MARK: - include: genuinely upstream node is ignored (Q-D), distinct from the "neither" gap case

    @Test(
        "include on a node upstream of the marker (action == .checkHere) is ignored, no student text (Q-D)"
    )
    func includeIgnoredForGenuinelyUpstreamNode() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let today = try Self.today()
        // Move the marker forward so earlier-unit nodes become upstream of the marker (map W5 step 3:
        // "nodes upstream of the marker are fog ... never cleared", surfaced by 03.6 as `.checkHere`).
        let (movedMap, _) = try MapFacade.setMarker(
            unitId: "MTH1W.u3", pastLastUnit: false, mapState: map, today: today)

        let upstreamNode = try #require(movedMap.viewModel.nodes.first { $0.upstream })
        #expect(upstreamNode.action == .checkHere)

        let (unchangedMap, outcome, events) = MapFacade.include(
            nodeId: upstreamNode.id, mapState: movedMap)

        #expect(outcome == .ignored)
        #expect(unchangedMap.queuedNodeId == movedMap.queuedNodeId)
        #expect(events == [])
    }
}

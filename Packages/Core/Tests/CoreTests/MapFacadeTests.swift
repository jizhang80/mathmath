import Foundation
import Testing

@testable import Core

/// `MapFacade` — panel content (map W2/W3/W4), `selectCourse`, `setMarker`, `include`,
/// `unitExpedition`, `checkHere`. AC5–AC14 of
/// `tasks/epic-03-task-07-map-actions-facade-launch.md`.
@Suite("MapFacade (map W2-W5, D45/D46/D48 hand-offs)")
struct MapFacadeTests {
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

    /// Builds a fresh `MapState` on `MTH1W` via the real `selectCourse`, over a fresh temp `stateURL`.
    private static func freshMTH1WMap() throws -> (map: MapState, bundle: ContentBundle, stateURL: URL) {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let (map, _) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil,
            today: try Self.today())
        return (map, bundle, stateURL)
    }

    // MARK: - AC5 node panel content

    @Test(
        "nodePanelContent surfaces paraphrase, expectation code links and a plain-words mastery label (AC5)")
    func nodePanelContentSurfacesExpectedFields() throws {
        let (map, bundle, _) = try Self.freshMTH1WMap()
        let node = try #require(bundle.nodes.nodes.first { $0.id == "integer-operations" })
        #expect(!(node.expectationCodes ?? []).isEmpty)

        let result = MapFacade.nodePanelContent(nodeId: "integer-operations", mapState: map)
        let (content, events) = try #require(result)

        #expect(content.paraphrase == node.paraphrase)
        let expectedLink = try #require(content.expectationCodeLinks.first)
        let course = try #require(bundle.courses.courses.first { $0.courseCode == "MTH1W" })
        let expectation = try #require(course.expectations.first { $0.code == expectedLink.code })
        #expect(expectedLink.officialUrl == expectation.officialUrl)
        #expect(
            ["under fog", "cleared", "blocked — something upstream is in the way"].contains(
                content.masteryLabel))
        #expect(events == [.mapNodeOpened])

        // I6/I15 T4: no leaked field — the node's actual `error_types`/`hint_tree` content never
        // appears in any panel-content string field.
        let errorTypeLabels = node.errorTypes.map(\.label)
        let hintFragments = node.hintTree.values.flatMap { $0 }
        for text in [content.name, content.paraphrase, content.masteryLabel] {
            #expect(!errorTypeLabels.contains(text))
            #expect(!hintFragments.contains(text))
        }
    }

    @Test("nodePanelContent returns nil for an unknown node id (T2)")
    func nodePanelContentUnknownIdReturnsNil() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        #expect(MapFacade.nodePanelContent(nodeId: "not-a-real-node", mapState: map) == nil)
    }

    // MARK: - AC6 region panel content

    @Test("regionPanelContent returns nil for a horizon region (AC6)")
    func regionPanelContentHorizonReturnsNil() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        #expect(MapFacade.regionPanelContent(regionId: .analysis, mapState: map) == nil)
    }

    @Test(
        "regionPanelContent for a populated content region reports clearedFraction and crossing courses (AC6)"
    )
    func regionPanelContentPopulatedRegion() throws {
        let (map, bundle, _) = try Self.freshMTH1WMap()
        let region = try #require(bundle.regions.regions.first { $0.id == .numberOperations })

        let result = MapFacade.regionPanelContent(regionId: .numberOperations, mapState: map)
        let (content, events) = try #require(result)

        #expect(content.about == region.about)
        let regionView = try #require(map.viewModel.regions.first { $0.id == .numberOperations })
        #expect(content.clearedFraction == regionView.clearedFraction)
        #expect(content.courseCodesCrossingHere == ["MTH1W"])
        #expect(events == [.mapRegionOpened])
    }

    @Test("regionPanelContent for an unpopulated content region has no crossing course (T2)")
    func regionPanelContentEmptyRegionNoCrossing() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let result = MapFacade.regionPanelContent(regionId: .geometryMeasurement, mapState: map)
        let (content, _) = try #require(result)
        #expect(content.courseCodesCrossingHere == [])
    }

    // MARK: - AC7 landmark panel content

    @Test("landmarkPanelContent surfaces what_it_is, source_url and linked node ids (AC7)")
    func landmarkPanelContentSurfacesExpectedFields() throws {
        let (map, bundle, _) = try Self.freshMTH1WMap()
        let landmark = try #require(
            bundle.landmarks.landmarks.first { $0.id == "canadian-mortgage-compounding" })

        let result = MapFacade.landmarkPanelContent(
            landmarkId: "canadian-mortgage-compounding", mapState: map)
        let (content, events) = try #require(result)

        #expect(content.whatItIs == landmark.whatItIs)
        #expect(!content.sourceUrl.isEmpty)
        #expect(content.nodeIds == ["exponent-laws", "exponential-functions"])
        #expect(events == [.mapLandmarkOpened])
    }

    @Test("landmarkPanelContent returns nil for an unknown landmark id (T2)")
    func landmarkPanelContentUnknownIdReturnsNil() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        #expect(MapFacade.landmarkPanelContent(landmarkId: "not-a-real-landmark", mapState: map) == nil)
    }

    // MARK: - AC8 setMarker (D45, unit list; save-after-every-action)

    @Test("in-course move: setMarker persists the new marker/trail, survives relaunch (AC8)")
    func setMarkerInCourseMove() throws {
        let (map, bundle, stateURL) = try Self.freshMTH1WMap()
        let today = try Self.today()

        let (newMap, events) = try MapFacade.setMarker(
            unitId: "MTH1W.u2", pastLastUnit: false, mapState: map, today: today)

        #expect(newMap.state.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false))
        #expect(
            events == [
                .expeditionMarkerChanged, .expeditionTrailGenerated, .platformStateWritten, .mapMarkerMoved,
            ])

        let outcome = MapLaunch.open(snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: today)
        guard case .ready(let relaunched, _, _) = outcome else {
            Issue.record("expected .ready, got \(outcome)")
            return
        }
        #expect(relaunched.state.marker == newMap.state.marker)
        #expect(relaunched.state.trail == newMap.state.trail)
        _ = bundle
    }

    @Test("past the last unit, from a non-last unit: setMarker substitutes the course's last unit (AC8)")
    func setMarkerPastLastUnit() throws {
        let (map, bundle, stateURL) = try Self.freshMTH1WMap()
        let today = try Self.today()
        let lastUnitId = try #require(
            bundle.courses.courses.first { $0.courseCode == "MTH1W" }?.units.last?.unitId)
        #expect(!lastUnitId.isEmpty)
        #expect(lastUnitId != "MTH1W.u2")

        let (newMap, _) = try MapFacade.setMarker(
            unitId: "MTH1W.u2", pastLastUnit: true, mapState: map, today: today)

        #expect(newMap.state.marker == Marker(courseCode: "MTH1W", unitId: lastUnitId, pastLastUnit: true))

        let (readResult, _) = try StudentStateStore.read(at: stateURL)
        guard case .loaded(let readState, _) = readResult else {
            Issue.record("expected .loaded, got \(readResult)")
            return
        }
        #expect(readState.marker.unitId == lastUnitId)
        #expect(readState.marker.pastLastUnit == true)

        let outcome = MapLaunch.open(snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: today)
        guard case .ready(let relaunched, _, _) = outcome else {
            Issue.record("expected .ready, got \(outcome)")
            return
        }
        #expect(relaunched.state.marker == newMap.state.marker)
    }

    @Test("negative control: pastLastUnit false keeps the caller's unitId unchanged (AC8)")
    func setMarkerNegativeControlFlagGatesSubstitution() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let (newMap, _) = try MapFacade.setMarker(
            unitId: "MTH1W.u2", pastLastUnit: false, mapState: map, today: try Self.today())
        #expect(newMap.state.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false))
    }

    // MARK: - AC9 selectCourse, later course change (Q-E)

    @Test("selectCourse for a later course replaces syllabi/marker but keeps mastery (AC9)")
    func selectCourseLaterChangeKeepsMastery() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let today = try Self.today()
        let (firstMap, _) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil, today: today)
        let previousStateWithMastery = StudentState(
            schemaVersion: firstMap.state.schemaVersion, formatVersionSeen: firstMap.state.formatVersionSeen,
            syllabi: firstMap.state.syllabi, marker: firstMap.state.marker,
            nodes: [
                "integer-operations": NodeState(
                    mastery: .cleared, correctCount: 2, lastProbe: "2026-09-01", nextDue: "2026-10-01",
                    ladderRung: 1, remediated: nil)
            ], trail: firstMap.state.trail, expeditionLog: [], probeLog: [],
            installDay: firstMap.state.installDay,
            consentOn: true)

        let (newMap, _) = try MapFacade.selectCourse(
            courseCode: "MCR3U", bundle: bundle, stateURL: stateURL, previousState: previousStateWithMastery,
            today: today)

        #expect(newMap.state.syllabi == ["MCR3U"])
        #expect(newMap.state.marker == MarkerTrail.defaultMarker(syllabi: ["MCR3U"], bundle: bundle))
        #expect(newMap.state.nodes == previousStateWithMastery.nodes)
    }

    // MARK: - AC10 checkHere (hand-off)

    @Test("checkHere on a blocked node opens a diagnosis event, mutates no StudentState (AC10)")
    func checkHereOnBlockedNode() throws {
        let (map, bundle, _) = try Self.freshMTH1WMap()
        let today = try Self.today()
        let blockedState = StudentState(
            schemaVersion: map.state.schemaVersion, formatVersionSeen: map.state.formatVersionSeen,
            syllabi: map.state.syllabi, marker: map.state.marker,
            nodes: [
                "polynomials": NodeState(
                    mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                    remediated: nil)
            ], trail: map.state.trail, expeditionLog: [], probeLog: [], installDay: map.state.installDay,
            consentOn: true)
        let blockedMap = MapState(
            bundle: bundle, stateURL: map.stateURL, state: blockedState,
            viewModel: MapViewModel.derive(bundle: bundle, state: blockedState, today: today),
            queuedNodeId: nil)

        let (event, events) = MapFacade.checkHere(nodeId: "polynomials", mapState: blockedMap)

        #expect(event == DiagnosisEvent(originNodeId: "polynomials", trigger: .mapCheckHere, levelBudget: 1))
        #expect(events == [.mapCheckHereRequested])
    }

    // MARK: - AC11 unitExpedition (hand-off, D46, delegated to Expedition.compose)

    @Test("unitExpedition on a unit with a non-empty fringe returns slots drawn only from that unit (AC11)")
    func unitExpeditionHappyPath() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let today = try Self.today()

        let (result, events) = try MapFacade.unitExpedition(unitId: "MTH1W.u1", mapState: map, today: today)

        #expect(!result.slots.isEmpty)
        let windowNodeIds: Set<String> = [
            "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
            "scientific-notation",
        ]
        for slot in result.slots where slot.kind == .newLearning {
            #expect(windowNodeIds.contains(slot.nodeId))
        }
        #expect(events == [.mapUnitExpeditionRequested])
    }

    @Test("unitExpedition on an empty-fringe unit/state combination throws expNoFringe (AC11)")
    func unitExpeditionEmptyFringeThrows() throws {
        let (map, bundle, _) = try Self.freshMTH1WMap()
        let today = try Self.today()
        let windowNodeIds = [
            "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
            "scientific-notation",
        ]
        var clearedNodes: [String: NodeState] = [:]
        for nodeId in windowNodeIds {
            clearedNodes[nodeId] = NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2026-12-01",
                ladderRung: 0, remediated: nil)
        }
        let clearedState = StudentState(
            schemaVersion: map.state.schemaVersion, formatVersionSeen: map.state.formatVersionSeen,
            syllabi: map.state.syllabi, marker: map.state.marker, nodes: clearedNodes, trail: map.state.trail,
            expeditionLog: [], probeLog: [], installDay: map.state.installDay, consentOn: true)
        let clearedMap = MapState(
            bundle: bundle, stateURL: map.stateURL, state: clearedState,
            viewModel: MapViewModel.derive(bundle: bundle, state: clearedState, today: today),
            queuedNodeId: nil)

        do {
            _ = try MapFacade.unitExpedition(unitId: "MTH1W.u1", mapState: clearedMap, today: today)
            Issue.record("expected unitExpedition to throw")
        } catch let error as CoreError {
            #expect(error == .expNoFringe)
        }
    }

    // MARK: - AC12 include (Q-D, in-memory queue)

    @Test("include on a fringe fog node queues it, never persists it (AC12)")
    func includeQueuesEligibleNode() throws {
        let (map, _, stateURL) = try Self.freshMTH1WMap()
        let bytesAfterSelectCourse = try Data(contentsOf: stateURL)

        let nodeView = try #require(map.viewModel.nodes.first { $0.id == "integer-operations" })
        #expect(nodeView.action == .include)

        let (queuedMap, outcome, events) = MapFacade.include(nodeId: "integer-operations", mapState: map)

        #expect(outcome == .queued)
        #expect(queuedMap.queuedNodeId == "integer-operations")
        #expect(events == [.mapIncludeRequested])
        #expect(try Data(contentsOf: stateURL) == bytesAfterSelectCourse)
    }

    @Test("a second include with a different eligible node replaces the queue, never accumulates (AC12)")
    func includeReplacesTheQueue() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let (firstMap, firstOutcome, _) = MapFacade.include(nodeId: "integer-operations", mapState: map)
        #expect(firstOutcome == .queued)
        #expect(firstMap.queuedNodeId == "integer-operations")

        let (secondMap, secondOutcome, _) = MapFacade.include(nodeId: "rational-numbers", mapState: firstMap)

        #expect(secondOutcome == .queued)
        #expect(secondMap.queuedNodeId == "rational-numbers")
        #expect(secondMap.queuedNodeId != "integer-operations")
    }

    @Test("include on a node whose action is not .include is ignored, queue unchanged, no throw (AC12)")
    func includeOnIneligibleNodeIsIgnored() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let nodeView = try #require(map.viewModel.nodes.first { $0.id == "order-of-operations" })
        #expect(nodeView.action != .include)

        let (unchangedMap, outcome, events) = MapFacade.include(nodeId: "order-of-operations", mapState: map)

        #expect(outcome == .ignored)
        #expect(unchangedMap.queuedNodeId == map.queuedNodeId)
        #expect(events == [])
    }

    @Test(
        "a real Expedition.compose places the queued node as slot 0 of newLearning when still on the fringe (AC12)"
    )
    func includeQueuedNodePlacedAsSlotZero() throws {
        let (map, _, _) = try Self.freshMTH1WMap()
        let today = try Self.today()
        let (queuedMap, _, _) = MapFacade.include(nodeId: "rational-numbers", mapState: map)

        let result = try Expedition.compose(
            state: queuedMap.state, bundle: queuedMap.bundle, trail: queuedMap.state.trail,
            marker: queuedMap.state.marker, today: today, queuedNodeId: queuedMap.queuedNodeId)

        let firstNewLearningSlot = try #require(result.slots.first { $0.kind == .newLearning })
        #expect(firstNewLearningSlot.nodeId == "rational-numbers")
    }

    @Test(
        "the queue never reaches disk: raw bytes after include are byte-identical to selectCourse's write (AC12)"
    )
    func includeNeverWritesToDisk() throws {
        let (map, _, stateURL) = try Self.freshMTH1WMap()
        let before = try Data(contentsOf: stateURL)

        _ = MapFacade.include(nodeId: "integer-operations", mapState: map)

        #expect(try Data(contentsOf: stateURL) == before)
    }

    // MARK: - AC13 save-after-every-action + missed-write negative control

    @Test("selectCourse then setMarker each write to stateURL (AC13)")
    func saveAfterEveryStateChangingAction() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let today = try Self.today()

        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
        let (map, _) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil, today: today)
        #expect(FileManager.default.fileExists(atPath: stateURL.path))
        let afterSelectCourse = try Data(contentsOf: stateURL)

        _ = try MapFacade.setMarker(unitId: "MTH1W.u2", pastLastUnit: false, mapState: map, today: today)
        let afterSetMarker = try Data(contentsOf: stateURL)
        #expect(afterSetMarker != afterSelectCourse)
    }

    @Test("a write failure throws platformStateWriteFailed, leaves the file byte-unchanged (AC13)")
    func missedWriteNegativeControl() throws {
        let (map, _, stateURL) = try Self.freshMTH1WMap()
        let before = try Data(contentsOf: stateURL)
        let containingDir = stateURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: containingDir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: containingDir.path)
        }

        do {
            _ = try MapFacade.setMarker(
                unitId: "MTH1W.u2", pastLastUnit: false, mapState: map, today: try Self.today())
            Issue.record("expected setMarker to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateWriteFailed)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: containingDir.path)
        #expect(try Data(contentsOf: stateURL) == before)
    }

    // MARK: - AC14 event-name conformance

    @Test(
        "every façade action's events are a subset of the interaction-contract's §5 notification set (AC14)")
    func eventNameConformance() throws {
        let allowedNames: Set<String> = [
            "map.opened", "map.node_opened", "map.region_opened", "map.landmark_opened", "map.marker_moved",
            "map.check_here_requested", "map.include_requested", "map.unit_expedition_requested",
            "platform.launched", "platform.state_written", "expedition.marker_changed",
            "expedition.trail_generated",
        ]
        for name in allowedNames {
            #expect(CoreEvent.allCases.map(\.rawValue).contains(name))
        }

        let (map, bundle, stateURL) = try Self.freshMTH1WMap()
        let today = try Self.today()

        var actual: [CoreEvent] = []
        actual += MapFacade.nodePanelContent(nodeId: "integer-operations", mapState: map)?.events ?? []
        actual += MapFacade.regionPanelContent(regionId: .numberOperations, mapState: map)?.events ?? []
        actual +=
            MapFacade.landmarkPanelContent(
                landmarkId: "canadian-mortgage-compounding", mapState: map)?.events ?? []
        let (afterSelectCourse, selectCourseEvents) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil, today: today)
        actual += selectCourseEvents
        let (afterSetMarker, setMarkerEvents) = try MapFacade.setMarker(
            unitId: "MTH1W.u2", pastLastUnit: false, mapState: afterSelectCourse, today: today)
        actual += setMarkerEvents
        actual += MapFacade.checkHere(nodeId: "polynomials", mapState: afterSetMarker).events
        actual += MapFacade.include(nodeId: "rational-numbers", mapState: afterSetMarker).events
        let (_, unitExpeditionEvents) = try MapFacade.unitExpedition(
            unitId: "MTH1W.u1", mapState: afterSetMarker, today: today)
        actual += unitExpeditionEvents

        for event in actual {
            #expect(allowedNames.contains(event.rawValue))
        }

        // T5 negative control: removing a required event from a captured actual-events array makes the
        // "contains exactly" assertion fail — proving the assertion is not vacuously true.
        var missingMarkerMoved = actual
        if let index = missingMarkerMoved.firstIndex(of: .mapMarkerMoved) {
            missingMarkerMoved.remove(at: index)
        }
        #expect(!missingMarkerMoved.contains(.mapMarkerMoved))
        #expect(actual.contains(.mapMarkerMoved))
    }
}

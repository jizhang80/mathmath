import Foundation
import Testing

@testable import Core

/// `MapViewModel` (`Sources/Core/Map/MapViewModel.swift`) — the pure map derivation. T1-T9b per
/// `tasks/epic-03-task-06-map-view-model.md` § 5.
@Suite("MapViewModel: pure map derivation")
struct MapViewModelTests {
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

    // MARK: - T1

    @Test(
        "T1: happy path over real data/demo — regions, rivers, fog levels, actions, focus frame, determinism"
    )
    func t1HappyPathOverRealDemo() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()

        // Marker at MTH1W.u3: window = {u3, u4} residents; upstream = {u1, u2} residents. Both Demo
        // courses on the trail so all 3 populated regions (AC1) carry a non-nil fraction.
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u3", pastLastUnit: false,
            syllabi: ["MTH1W", "MCR3U"], bundle: bundle)

        let nodes: [String: NodeState] = [
            // blocked, inside the window (u4).
            "polynomials": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil),
            // blocked, outside the window (u1, upstream).
            "integer-operations": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil),
            // cleared, due today (past nextDue).
            "linear-relations": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 0, remediated: nil),
        ]
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes,
            syllabi: ["MTH1W", "MCR3U"])

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        // AC1: 14 regions, 10 content + 4 horizon.
        #expect(model.regions.count == 14)
        #expect(model.regions.filter(\.horizon).count == 4)
        for region in model.regions {
            #expect(region.horizon == bundle.regions.regions.first { $0.id == region.id }?.horizon)
        }
        // 11 of 14 regions are pure fog (7 empty content regions + 4 horizon).
        #expect(model.regions.filter { $0.clearedFraction == nil }.count == 11)

        // AC2: one river per edge, order preserved.
        #expect(model.rivers.count == bundle.edges.edges.count)
        for (river, edge) in zip(model.rivers, bundle.edges.edges) {
            #expect(river.from == edge.from)
            #expect(river.to == edge.to)
        }

        // AC3: fog level always mirrors real mastery, unconditionally.
        for nodeView in model.nodes {
            #expect(nodeView.fogLevel == (state.nodes[nodeView.id]?.mastery ?? .fog))
        }
        let linearRelations = try #require(model.nodes.first { $0.id == "linear-relations" })
        #expect(linearRelations.fogLevel == .cleared)
        #expect(linearRelations.due == true)
        for nodeView in model.nodes where nodeView.fogLevel != .cleared {
            #expect(nodeView.due == false)
        }

        // AC6: one landmark per bundle entry, unchanged fields.
        #expect(model.landmarks.count == bundle.landmarks.landmarks.count)
        for (view, landmark) in zip(model.landmarks, bundle.landmarks.landmarks) {
            #expect(view.id == landmark.id)
            #expect(view.position == landmark.position)
            #expect(view.nodeIds == landmark.nodeIds)
        }

        // AC7: label set thresholds.
        let below = model.labelSet(atZoom: MapViewModel.nodeNameZoomThreshold - 1)
        #expect(below.landmarkNames == true)
        #expect(below.nodeNames == false)
        #expect(below.regionNames == true)
        let atThreshold = model.labelSet(atZoom: MapViewModel.nodeNameZoomThreshold)
        #expect(atThreshold.nodeNames == true)
        #expect(atThreshold.regionNames == false)
        #expect(atThreshold.landmarkNames == true)
        let above = model.labelSet(atZoom: MapViewModel.nodeNameZoomThreshold + 1)
        #expect(above.nodeNames == true)
        #expect(above.regionNames == false)

        // AC8: focus frame is the bounding box over the window (u3/u4 residents).
        let index = GraphIndex(bundle: bundle)
        let windowIds: Set<String> = [
            "linear-relations", "solving-linear-equations", "solving-systems-of-equations",
            "simplifying-expressions", "polynomials", "factoring",
        ]
        let windowPositions = windowIds.compactMap { index.nodesById[$0]?.position }
        #expect(model.focusFrame.minX == windowPositions.map(\.x).min())
        #expect(model.focusFrame.minY == windowPositions.map(\.y).min())
        #expect(model.focusFrame.maxX == windowPositions.map(\.x).max())
        #expect(model.focusFrame.maxY == windowPositions.map(\.y).max())

        // AC9 (I4 record half): every blocked node gets .checkHere and nothing else, in and out of window.
        let blockedIds = state.nodes.filter { $0.value.mastery == .blocked }.map(\.key)
        for id in blockedIds {
            let nodeView = try #require(model.nodes.first { $0.id == id })
            #expect(nodeView.action == .checkHere)
        }

        // AC10: action split (fringe-and-not-upstream -> include; upstream fog -> checkHere; cleared -> nil).
        for nodeView in model.nodes {
            switch nodeView.fogLevel {
            case .cleared:
                #expect(nodeView.action == nil)
            case .blocked:
                #expect(nodeView.action == .checkHere)
            case .fog:
                if nodeView.upstream {
                    #expect(nodeView.action == .checkHere)
                }
            }
        }

        // AC11: determinism.
        let model2 = MapViewModel.derive(bundle: bundle, state: state, today: today)
        #expect(model == model2)
    }

    // MARK: - T2 (never-throws boundary)

    @Test("T2: a marker naming a course absent from the bundle never crashes; empty sets, empty frame")
    func t2MarkerOffTrailNeverCrashes() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let marker = Marker(courseCode: "NOT-A-COURSE", unitId: "nope", pastLastUnit: false)
        let state = Self.emptyState(bundle: bundle, marker: marker, trail: Trail(segments: []))

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        for nodeView in model.nodes {
            #expect(nodeView.upstream == false)
            #expect(nodeView.fogLevel == .fog)
            #expect(nodeView.action == nil)
        }
        #expect(model.focusFrame == FocusFrame(minX: 0, minY: 0, maxX: 1, maxY: 1))
    }

    // MARK: - T4 / T5 (single-implementation cross-check, AC12/AC14)

    @Test("T4/T5: .include set equals the directly-called fringe intersected with fog/non-upstream")
    func t4IncludeSetMatchesFringeIntersection() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()

        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)

        let nodes: [String: NodeState] = [
            "exponent-laws": NodeState(
                mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: true)
        ]
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes)

        let index = GraphIndex(bundle: bundle)
        let edgesByTo = Dictionary(grouping: index.edges, by: \.to)
        let fringe = Expedition.fringeNodeIds(
            state: state, bundle: bundle, index: index, edgesByTo: edgesByTo,
            marker: setMarkerResult.marker, trail: setMarkerResult.trail, unitExpeditionUnitId: nil)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)
        let includeIds = Set(model.nodes.filter { $0.action == .include }.map(\.id))
        let upstreamIds = Set(model.nodes.filter(\.upstream).map(\.id))
        let expected = fringe.filter { id in
            (state.nodes[id]?.mastery ?? .fog) == .fog && !upstreamIds.contains(id)
        }

        // T5: the fixture must be non-trivial (a bug returning nil everywhere must not vacuously pass).
        #expect(!expected.isEmpty)
        #expect(includeIds == Set(expected))

        // AC12: every real compose() new-learning slot, over a state with no blocked node (so no
        // fringe member can be anything but fog), is a subset of the .include set.
        let ac12State = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)
        let ac12Model = MapViewModel.derive(bundle: bundle, state: ac12State, today: today)
        let ac12IncludeIds = Set(ac12Model.nodes.filter { $0.action == .include }.map(\.id))
        let compose = try Expedition.compose(
            state: ac12State, bundle: bundle, trail: setMarkerResult.trail, marker: setMarkerResult.marker,
            today: today)
        let newLearningIds = Set(compose.slots.filter { $0.kind == .newLearning }.map(\.nodeId))
        #expect(!newLearningIds.isEmpty)
        #expect(newLearningIds.isSubset(of: ac12IncludeIds))
        for id in newLearningIds {
            let nodeView = try #require(ac12Model.nodes.first { $0.id == id })
            #expect(nodeView.fogLevel == .fog)
        }
    }

    // MARK: - T6 (AC4, extension segment dashed)

    @Test("T6: extension segment renders dashed; real data/demo produces no dashed segment")
    func t6ExtensionSegmentDashed() throws {
        let fixtureBundle = try BundleIO.read(from: Self.extensionPositiveFixtureDir)
        let today = try Self.today()
        let mth1w = fixtureBundle.courses.courses.first(where: { $0.courseCode == "MTH1W" })
        guard let lastUnitId = mth1w?.units.last?.unitId else {
            Issue.record("fixture bundle must carry an MTH1W course with >= 1 unit")
            return
        }
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: lastUnitId, pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: fixtureBundle)
        let state = Self.emptyState(
            bundle: fixtureBundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)

        let model = MapViewModel.derive(bundle: fixtureBundle, state: state, today: today)
        let extensionSegment = try #require(
            model.trailSegments.first { $0.courseCode == "MPM2D" })
        #expect(extensionSegment.dashed == true)
        let courseSegment = try #require(model.trailSegments.first { $0.courseCode == "MTH1W" })
        #expect(courseSegment.dashed == false)

        // AC4 real-data negative half: MPM2D/MHF4U are absent from data/demo.
        let demoBundle = try Self.loadDemoBundle()
        let demoSetMarker = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true, syllabi: ["MTH1W"],
            bundle: demoBundle)
        let demoState = Self.emptyState(
            bundle: demoBundle, marker: demoSetMarker.marker, trail: demoSetMarker.trail)
        let demoModel = MapViewModel.derive(bundle: demoBundle, state: demoState, today: today)
        #expect(!demoModel.trailSegments.contains { $0.dashed == true })
    }

    // MARK: - T7 (AC3, upstream never overrides fog level)

    @Test("T7: upstream nodes keep their real mastery — cleared stays action-nil, fog stays checkHere")
    func t7UpstreamNeverOverridesFogLevel() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u3", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)

        // integer-operations and exponent-laws are both upstream of unit u3.
        let nodes: [String: NodeState] = [
            "integer-operations": NodeState(
                mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
                ladderRung: 0, remediated: nil)
        ]
        let state = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail, nodes: nodes)

        let model = MapViewModel.derive(bundle: bundle, state: state, today: today)

        let clearedUpstream = try #require(model.nodes.first { $0.id == "integer-operations" })
        #expect(clearedUpstream.upstream == true)
        #expect(clearedUpstream.fogLevel == .cleared)
        #expect(clearedUpstream.action == nil)

        let fogUpstream = try #require(model.nodes.first { $0.id == "exponent-laws" })
        #expect(fogUpstream.upstream == true)
        #expect(fogUpstream.fogLevel == .fog)
        #expect(fogUpstream.action == .checkHere)
    }

    // MARK: - T8 (AC13, W6 re-derivation through real transitions)

    @Test("T8: W6 re-derivation over a real itemCorrect clear and a real confirmed diagnosis block")
    func t8W6ReDerivationOverRealTransitions() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let setMarkerResult = try MarkerTrail.setMarker(
            courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false, syllabi: ["MTH1W"],
            bundle: bundle)
        let baseState = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail)

        // Real MasteryTransitions.itemCorrect, twice, over two distinct items -> cleared.
        let initialNodeState = NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
        let first = MasteryTransitions.itemCorrect(
            current: initialNodeState, itemId: "linear-relations-1", correctItemIds: [], today: today)
        let second = MasteryTransitions.itemCorrect(
            current: first.nodeState, itemId: "linear-relations-2",
            correctItemIds: ["linear-relations-1"], today: today)
        #expect(second.nodeState.mastery == .cleared)

        // Real DiagnosisRun.run: block polynomials via a confirmed diagnosis on its own prerequisite
        // exponent-laws, at budget 1 with exponent-laws's own prerequisite (solving-linear-equations)
        // already cleared, so exponent-laws is the exhausted-budget, no-deeper-gap winner (matches
        // DiagnosisMachineTests.confirmedAtExhaustedBudgetNoDeeperGap's real-edge-chain scenario).
        var diagnosisNodes = baseState.nodes
        diagnosisNodes["solving-linear-equations"] = NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
        let diagnosisState = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail,
            nodes: diagnosisNodes)
        let decisions = [
            DiagnosisLevelDecision(
                declineProbe: false, submittedAnswers: ["wrong", "wrong"], acceptFurtherLevel: false)
        ]
        let outcome = DiagnosisRun.run(
            trigger: .mapCheckHere, originNodeId: "polynomials", misses: [], levelBudget: 1,
            decisions: decisions, shownItemIdsInRun: [], state: diagnosisState, bundle: bundle,
            today: today)
        #expect(outcome.terminal == .confirmed)
        let blockedNodeId = try #require(outcome.blockedNodeIds.first)
        #expect(outcome.state.nodes[blockedNodeId]?.mastery == .blocked)

        var mergedNodes = outcome.state.nodes
        mergedNodes["linear-relations"] = second.nodeState
        let mergedState = Self.emptyState(
            bundle: bundle, marker: setMarkerResult.marker, trail: setMarkerResult.trail,
            nodes: mergedNodes)

        let model = MapViewModel.derive(bundle: bundle, state: mergedState, today: today)
        let clearedView = try #require(model.nodes.first { $0.id == "linear-relations" })
        #expect(clearedView.fogLevel == .cleared)
        let blockedView = try #require(model.nodes.first { $0.id == blockedNodeId })
        #expect(blockedView.fogLevel == .blocked)
        #expect(blockedView.action == .checkHere)
    }

    // MARK: - T9 / T9b (AC14, structural single-source guard)

    private static let singleSourceNames = ["scopeWindow", "fringeNodeIds", "residentNodeIds", "unitIndex"]

    /// Returns the subset of `singleSourceNames` declared (`func <name>`, any access modifier, `static`
    /// or not) in `source`. Lines whose trimmed form begins with `//` are skipped; call sites
    /// (`Expedition.<name>(`) never match because they carry no `func ` token.
    private static func restatedDeclarations(in source: String) -> Set<String> {
        var found: Set<String> = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("//") { continue }
            for name in singleSourceNames where line.contains("func \(name)(") {
                found.insert(name)
            }
        }
        return found
    }

    @Test("T9: MapViewModel.swift declares no scopeWindow/fringeNodeIds/residentNodeIds/unitIndex")
    func t9NoRestatedDeclarationsInRealFile() throws {
        let mapViewModelPath =
            URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/Map/MapViewModel.swift")
        let text = try String(contentsOf: mapViewModelPath, encoding: .utf8)
        #expect(!text.isEmpty, "empty scan is a FAIL")
        #expect(text.contains("static func derive("), "the real file must resolve and contain derive(")

        let restated = Self.restatedDeclarations(in: text)
        #expect(restated.isEmpty, "MapViewModel.swift restates: \(restated)")
    }

    @Test("T9b: restatedDeclarations(in:) detects a planted violation of all four names")
    func t9bDetectsPlantedViolation() throws {
        let planted = """
            private static func scopeWindow(marker: Marker) -> Set<String> { [] }
            static func fringeNodeIds(state: StudentState) -> Set<String> { [] }
            internal static func residentNodeIds(course: Course) -> Set<String> { [] }
            public static func unitIndex(nodeId: String) -> Int? { nil }
            static func derive(bundle: ContentBundle) -> MapViewModel { fatalError() }
            """
        let found = Self.restatedDeclarations(in: planted)
        #expect(found == Set(Self.singleSourceNames))
    }

    @Test("T9b: restatedDeclarations(in:) reports nothing on a clean fixture (call sites + comment)")
    func t9bCleanOnCallSitesAndComments() throws {
        let clean = """
            static func derive(bundle: ContentBundle) -> MapViewModel {
                let window = Expedition.scopeWindow(marker: marker, trail: trail)
                let fringe = Expedition.fringeNodeIds(state: state, bundle: bundle)
                let resident = Expedition.residentNodeIds(course: course, index: index)
                let idx = Expedition.unitIndex(nodeId: id, course: course, index: index)
                // no func scopeWindow( here
                return MapViewModel()
            }
            """
        let found = Self.restatedDeclarations(in: clean)
        #expect(found.isEmpty)
    }
}

import Foundation
import Testing

@testable import Core

/// Task 04.5's own companion tests for `DoorFacade`'s short, focused cases: AC1-AC3, AC9, AC10, AC11,
/// AC12, AC15 of `tasks/epic-04-task-05-core-door-entries-persistence-seam.md`. The long C1
/// real-composition sequences (AC13, AC14) live in `DoorFacadeSeamTests.swift`.
@Suite("DoorFacade entries (04.5)")
struct DoorEntriesTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var demoBundleDir: URL { repoRoot.appendingPathComponent("data/demo") }

    private static func loadDemoBundle() throws -> ContentBundle { try BundleIO.read(from: demoBundleDir) }

    private static func today() throws -> CalendarDay {
        try #require(CalendarDay(iso: "2026-09-10"))
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private static func mth1wMarker(bundle: ContentBundle) throws -> Marker {
        try #require(MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle: bundle))
    }

    /// A fresh `MapState` on `MTH1W.u1` with the given `nodes`/`probeLog`, over a fresh temp `stateURL`
    /// (never written until a `DoorFacade`/`StudentStateStore` call writes it).
    private static func mapState(
        bundle: ContentBundle, nodes: [String: NodeState] = [:], probeLog: [ProbeLogEntry] = [],
        queuedNodeId: String? = nil, today: CalendarDay
    ) throws -> (map: MapState, stateURL: URL) {
        let marker = try Self.mth1wMarker(bundle: bundle)
        let report = try MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker: marker, bundle: bundle)
        let state = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: ["MTH1W"],
            marker: marker, nodes: nodes, trail: report.trail, expeditionLog: [], probeLog: probeLog,
            installDay: "2026-01-01", consentOn: true)
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let viewModel = MapViewModel.derive(bundle: bundle, state: state, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: state, viewModel: viewModel,
            queuedNodeId: queuedNodeId)
        return (map, stateURL)
    }

    private static func correctSubmission(for item: ProbeItem) -> String {
        item.answer?.value ?? item.correctChoiceId ?? "unknown"
    }

    private static func decodeState(at url: URL) throws -> StudentState {
        try CoreCoding.decoder.decode(StudentState.self, from: try Data(contentsOf: url))
    }

    // MARK: - AC1: startExpedition consumes the Include queue

    @Test("AC1: startExpedition consumes and empties the queued node; it becomes the run's first slot")
    func ac1StartExpeditionConsumesQueue() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let (included, outcome, _) = MapFacade.include(nodeId: "rational-numbers", mapState: built)
        #expect(outcome == .queued)
        #expect(included.queuedNodeId == "rational-numbers")

        let result = try DoorFacade.startExpedition(mapState: included, today: today)
        #expect(result.runState.map.queuedNodeId == nil)
        #expect(result.writeFailureCode == nil)
        #expect(result.events.contains(.platformStateWritten))
        guard case .item(let content) = result.screen else {
            Issue.record("expected .item")
            return
        }
        #expect(content.nodeId == "rational-numbers")

        let expected = DoorBWriteAhead.provisionalAbandonedState(
            runState: result.runState.expedition!, state: included.state, today: today)
        #expect(try Self.decodeState(at: stateURL) == expected)
    }

    // MARK: - AC2: startUnitExpedition delegates verbatim, never touches the queue

    @Test("AC2: startUnitExpedition delegates to MapFacade.unitExpedition; queuedNodeId is unchanged")
    func ac2StartUnitExpeditionPreservesQueue() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(
            bundle: bundle, queuedNodeId: "rational-numbers", today: today)

        let result = try DoorFacade.startUnitExpedition(unitId: "MTH1W.u4", mapState: built, today: today)
        #expect(result.runState.map.queuedNodeId == "rational-numbers")
        #expect(result.writeFailureCode == nil)
        guard case .item(let content) = result.screen else {
            Issue.record("expected .item")
            return
        }
        #expect(content.nodeId == "simplifying-expressions")

        let expected = DoorBWriteAhead.provisionalAbandonedState(
            runState: result.runState.expedition!, state: built.state, today: today)
        #expect(try Self.decodeState(at: stateURL) == expected)
    }

    // MARK: - AC3: EXP_NO_FRINGE starts no run, writes nothing

    private static func fullyClearedU1U2Nodes() -> [String: NodeState] {
        let cleared = NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
            ladderRung: 0, remediated: nil)
        var nodes: [String: NodeState] = [:]
        for id in [
            "integer-operations", "order-of-operations", "rational-numbers", "exponent-laws",
            "scientific-notation",
        ] {
            nodes[id] = cleared
        }
        return nodes
    }

    @Test("AC3: startExpedition throws expNoFringe on an empty fringe/due set; nothing is written")
    func ac3StartExpeditionThrowsExpNoFringe() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(
            bundle: bundle, nodes: Self.fullyClearedU1U2Nodes(), today: today)

        #expect(throws: CoreError.expNoFringe) {
            _ = try DoorFacade.startExpedition(mapState: built, today: today)
        }
        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
    }

    @Test("AC3: startUnitExpedition throws expNoFringe on an empty unit fringe/due set; nothing is written")
    func ac3StartUnitExpeditionThrowsExpNoFringe() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let cleared = NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
            ladderRung: 0, remediated: nil)
        let nodes: [String: NodeState] = [
            "simplifying-expressions": cleared, "polynomials": cleared, "factoring": cleared,
        ]
        let (built, stateURL) = try Self.mapState(bundle: bundle, nodes: nodes, today: today)

        #expect(throws: CoreError.expNoFringe) {
            _ = try DoorFacade.startUnitExpedition(unitId: "MTH1W.u4", mapState: built, today: today)
        }
        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
    }

    @Test("AC3: CoreErrorText resolves EXP_NO_FRINGE to the registered student text")
    func ac3ExpNoFringeText() {
        #expect(
            CoreErrorText.text(for: .expNoFringe)
                == "You've cleared everything up to here. Move your class marker forward, or explore the map."
        )
    }

    // MARK: - AC9: Start another composes from the post-run state

    @Test("AC9: startAnother composes from post-run state; the just-cleared node is no longer on the fringe")
    func ac9StartAnotherExcludesClearedNode() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        // Pre-seed one correct probe_log entry on a DIFFERENT item so this run's own correct answer on
        // "rational-numbers-1" (freshly drawn, least-recently-used) supplies the second distinct correct
        // item the clear rule needs (MasteryTransitions.itemCorrect: distinctCorrect.count >= 2).
        let priorLog = ProbeLogEntry(
            day: "2026-01-01", nodeId: "rational-numbers", itemId: "rational-numbers-2", correct: true,
            retry: false)
        let (built, _) = try Self.mapState(bundle: bundle, probeLog: [priorLog], today: today)

        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        var runState = start.runState
        var screen = start.screen
        while case .item(let content) = screen {
            let node = try #require(bundle.nodes.nodes.first(where: { $0.id == content.nodeId }))
            let items = node.probeItems.sorted { $0.id < $1.id }
            let item = content.isRetry ? items[1] : items[0]
            let answer = DoorFacade.answer(
                runState, submitted: Self.correctSubmission(for: item), today: today)
            runState = answer.runState
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            runState = cont.runState
            screen = cont.screen
        }
        guard case .summary(let summary) = screen else {
            Issue.record("expected .summary")
            return
        }
        #expect(summary.clearedNodeNames.contains("Operations with rational numbers"))

        let postRunMap = runState.map
        let again = try DoorFacade.startAnother(mapState: postRunMap, today: today)
        let visitedNodeIds =
            Set(again.runState.expedition!.run.queue.map(\.nodeId))
            .union(again.runState.expedition!.run.currentItem.map { [$0.nodeId] } ?? [])
        #expect(!visitedNodeIds.contains("rational-numbers"))
    }

    // MARK: - AC10: Back to the map, mid-run abandon; simulated kill

    @Test("AC10: backToMap persists the final abandoned:true entry, replacing the write-ahead value")
    func ac10BackToMapAbandonsMidRun() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        guard case .item(let content) = start.screen else {
            Issue.record("expected .item")
            return
        }
        let node = try #require(bundle.nodes.nodes.first(where: { $0.id == content.nodeId }))
        let item = node.probeItems.sorted { $0.id < $1.id }[0]
        let answer = DoorFacade.answer(
            start.runState, submitted: Self.correctSubmission(for: item), today: today)

        let (mapAfter, failure) = DoorFacade.backToMap(answer.runState, today: today)
        #expect(failure == nil)
        let decoded = try Self.decodeState(at: stateURL)
        #expect(decoded.expeditionLog.count == 1)
        let entry = try #require(decoded.expeditionLog.first)
        #expect(entry.abandoned == true)
        #expect(entry.itemCount == 1)
        #expect(mapAfter.state == decoded)
    }

    @Test(
        "AC10 simulated kill: dropping the in-memory runState after a call leaves exactly one abandoned entry"
    )
    func ac10SimulatedKillLeavesOneAbandonedEntry() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        guard case .item(let content) = start.screen else {
            Issue.record("expected .item")
            return
        }
        let node = try #require(bundle.nodes.nodes.first(where: { $0.id == content.nodeId }))
        let item = node.probeItems.sorted { $0.id < $1.id }[0]
        let answer = DoorFacade.answer(
            start.runState, submitted: Self.correctSubmission(for: item), today: today)
        // Simulated kill: the in-memory `runState` (answer.runState) is dropped here, never used again.
        _ = answer

        let decoded = try Self.decodeState(at: stateURL)
        #expect(decoded.expeditionLog.count == 1)
        #expect(decoded.expeditionLog[0].abandoned == true)
        #expect(decoded.expeditionLog[0].itemCount == 1)
    }

    @Test("AC10 negative control: skipping the write-ahead write fails the simulated-kill case")
    func ac10NegativeControlNoWriteAheadFailsSimulatedKill() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        // A locally reconstructed variant of `startExpedition` that never persists (test-file-only).
        let compose = try Expedition.compose(
            state: built.state, bundle: built.bundle, trail: built.state.trail, marker: built.state.marker,
            today: today, queuedNodeId: nil, unitExpeditionUnitId: nil)
        let advance = DoorBExpeditionFlow.start(compose: compose)
        _ = advance  // deliberately never written: the write-ahead call is skipped
        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
    }

    // MARK: - AC11: write-failure banner surfaces while the computed value is still returned

    @Test(
        "AC11(a): a Door B write failure surfaces EXP_STATE_WRITE_FAILED while the advance is still returned")
    func ac11DoorBWriteFailureBanner() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        guard case .item(let content) = start.screen else {
            Issue.record("expected .item")
            return
        }
        let node = try #require(bundle.nodes.nodes.first(where: { $0.id == content.nodeId }))
        let item = node.probeItems.sorted { $0.id < $1.id }[0]

        let containingDir = stateURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: containingDir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: containingDir.path)
        }

        let answer = DoorFacade.answer(
            start.runState, submitted: Self.correctSubmission(for: item), today: today)
        #expect(answer.writeFailureCode == CoreError.expStateWriteFailed.rawValue)
        #expect(answer.writeFailureCode == "EXP_STATE_WRITE_FAILED")
        #expect(answer.advance.answerCard.correct == true)
    }

    @Test(
        "AC11(b): a Door A write failure surfaces DIAG_STATE_WRITE_FAILED while the advance is still returned"
    )
    func ac11DoorAWriteFailureBanner() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)

        let containingDir = stateURL.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: containingDir.path)
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: containingDir.path)
        }

        let result = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        #expect(result.writeFailureCode == CoreError.diagStateWriteFailed.rawValue)
        #expect(result.writeFailureCode == "DIAG_STATE_WRITE_FAILED")
        guard case .hypothesis = result.screen else {
            Issue.record("expected .hypothesis, got \(result.screen)")
            return
        }
    }

    // MARK: - AC12: no new registry surface

    @Test("AC12: neither CoreError nor CoreEvent gains a new case in this task's diff")
    func ac12NoNewRegistryCase() {
        #expect(CoreError.allCases.count == 21)
        #expect(CoreEvent.allCases.count == 41)
        #expect(CoreError.expStateWriteFailed.rawValue == "EXP_STATE_WRITE_FAILED")
        #expect(CoreError.diagStateWriteFailed.rawValue == "DIAG_STATE_WRITE_FAILED")
        #expect(CoreError.expNoFringe.rawValue == "EXP_NO_FRINGE")
    }

    // MARK: - I2: no adapter pattern, Foundation only

    private static let adapterPatternSet = ["FoundationModels", "Adapter", "import CoreML", "URLSession"]

    @Test("I2: the DoorFacade additions to MapLaunch.swift carry no adapter pattern")
    func i2NoAdapterPattern() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(
                "Packages/Core/Sources/Core/Platform/MapLaunch.swift"), encoding: .utf8)
        #expect(source.contains("enum DoorFacade"), "instrument broken: DoorFacade not found")
        for pattern in Self.adapterPatternSet {
            #expect(!source.contains(pattern), "MapLaunch.swift contains banned adapter pattern '\(pattern)'")
        }
    }

    @Test("I2 guard is load-bearing: a planted 'FoundationModels' string is caught by the same scan")
    func i2GuardCatchesPlantedAdapterString() {
        let planted = "// FoundationModels.SystemLanguageModel"
        let offenders = Self.adapterPatternSet.filter { planted.contains($0) }
        #expect(!offenders.isEmpty, "scan failed to catch a planted adapter pattern — guard is vacuous")
    }
}

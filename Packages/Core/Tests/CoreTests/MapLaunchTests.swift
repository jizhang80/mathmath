import Foundation
import Testing

@testable import Core

/// `MapLaunch.open(snapshotDir:stateURL:today:)` — the App-launch entry point (map W1, expedition W7).
/// AC1–AC4 of `tasks/epic-03-task-07-map-actions-facade-launch.md`.
@Suite("MapLaunch.open (docs/domains/platform.md § W1, expedition.md § W7)")
struct MapLaunchTests {
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

    private static func tempCopyOfDataDemo() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: demoBundleDir, to: tempDir)
        return tempDir
    }

    private static func seedState(
        bundle: ContentBundle, courseCode: String, unitId: String, syllabi: [String],
        nodes: [String: NodeState] = [:]
    ) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: syllabi,
            marker: Marker(courseCode: courseCode, unitId: unitId, pastLastUnit: nil), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    // MARK: - AC1

    @Test("fresh install: no state file returns courseSelectionNeeded, writes nothing (AC1)")
    func freshInstallReturnsCourseSelectionNeeded() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .courseSelectionNeeded(_, let messages, let events) = outcome else {
            Issue.record("expected .courseSelectionNeeded, got \(outcome)")
            return
        }
        #expect(messages == [])
        #expect(events.contains(.platformLaunched))
        #expect(!events.contains(.mapOpened))
        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
    }

    // MARK: - AC2

    @Test("a refused bundle returns .refused, never reads or writes stateURL (AC2)")
    func refusedBundleNeverTouchesState() throws {
        let tempBundleDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempBundleDir) }
        try FileManager.default.removeItem(at: tempBundleDir.appendingPathComponent("edges.json"))
        let tempStateDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempStateDir) }
        let stateURL = tempStateDir.appendingPathComponent("student-state.json")

        let outcome = MapLaunch.open(snapshotDir: tempBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .refused(let refusal) = outcome else {
            Issue.record("expected .refused, got \(outcome)")
            return
        }
        #expect(refusal.studentCode == .platformSnapshotRefused)
        #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        #expect(FileManager.default.fileExists(atPath: stateURL.path) == false)
    }

    @Test("BundleLoader.load's documented throw type is exhaustively BundleRefusal (AC2 T2)")
    func bundleLoaderThrowsOnlyBundleRefusal() throws {
        let tempBundleDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempBundleDir) }
        try FileManager.default.removeItem(at: tempBundleDir.appendingPathComponent("edges.json"))

        do {
            _ = try BundleLoader.load(from: tempBundleDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        } catch {
            Issue.record("expected a BundleRefusal, got \(error) — MapLaunch.open's defensive catch is live")
        }
    }

    // MARK: - AC3

    @Test("selectCourse persists the first StudentState, a subsequent read returns it back (AC3)")
    func selectCoursePersistsFirstState() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let today = try Self.today()

        let (map, events) = try MapFacade.selectCourse(
            courseCode: "MTH1W", bundle: bundle, stateURL: stateURL, previousState: nil, today: today)

        #expect(map.state.schemaVersion == 2)
        #expect(map.state.installDay == today.iso)
        #expect(map.state.syllabi == ["MTH1W"])
        #expect(map.state.marker == MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle: bundle))
        #expect(map.state.nodes.isEmpty)
        #expect(events == [.platformStateWritten])

        let (readResult, _) = try StudentStateStore.read(at: stateURL)
        guard case .loaded(let readState, _) = readResult else {
            Issue.record("expected .loaded, got \(readResult)")
            return
        }
        #expect(readState == map.state)
    }

    // MARK: - AC4

    @Test(
        "W7 reconciliation: MCR3U.u9 (absent) falls back to the default marker, no write, empty messages (AC4)"
    )
    func w7ReconciliationMCR3Uu9FallsBackToDefault() throws {
        let bundle = try Self.loadDemoBundle()
        let mcr3u = try #require(bundle.courses.courses.first { $0.courseCode == "MCR3U" })
        #expect(!mcr3u.units.contains { $0.unitId == "MCR3U.u9" })

        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let nodes: [String: NodeState] = [
            "integer-operations": NodeState(
                mastery: .cleared, correctCount: 3, lastProbe: "2026-08-01", nextDue: "2026-09-01",
                ladderRung: 1, remediated: nil)
        ]
        let seeded = Self.seedState(
            bundle: bundle, courseCode: "MCR3U", unitId: "MCR3U.u9", syllabi: ["MCR3U"], nodes: nodes)
        _ = try StudentStateStore.write(seeded, to: stateURL)
        let bytesBefore = try Data(contentsOf: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .ready(let map, let messages, _) = outcome else {
            Issue.record("expected .ready, got \(outcome)")
            return
        }
        #expect(map.state.marker == MarkerTrail.defaultMarker(syllabi: ["MCR3U"], bundle: bundle))
        #expect(map.state.nodes == seeded.nodes)
        #expect(messages == [])
        #expect(try Data(contentsOf: stateURL) == bytesBefore)
    }

    @Test("W7 negative control: MCR3U.u1 (real unit) is unchanged, no reconciliation fires (AC4)")
    func w7NegativeControlRealUnitUnchanged() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let seeded = Self.seedState(
            bundle: bundle, courseCode: "MCR3U", unitId: "MCR3U.u1", syllabi: ["MCR3U"])
        _ = try StudentStateStore.write(seeded, to: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .ready(let map, _, _) = outcome else {
            Issue.record("expected .ready, got \(outcome)")
            return
        }
        #expect(map.state.marker == Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: nil))
    }

    @Test("W7 MHF4U variant: no course in syllabi resolves, returns courseSelectionNeeded (AC4)")
    func w7MHF4UVariantReturnsCourseSelectionNeeded() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(!bundle.courses.courses.contains { $0.courseCode == "MHF4U" })

        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let seeded = Self.seedState(
            bundle: bundle, courseCode: "MHF4U", unitId: "MHF4U.u1", syllabi: ["MHF4U"])
        _ = try StudentStateStore.write(seeded, to: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .courseSelectionNeeded(_, let messages, _) = outcome else {
            Issue.record("expected .courseSelectionNeeded, got \(outcome)")
            return
        }
        #expect(messages == [])
    }

    // MARK: - T4: I14 silent load path (no code ever surfaces as a message)

    @Test("no LaunchOutcome ever surfaces MAP_MARKER_OFF_TRAIL or EXP_NODE_NOT_IN_GRAPH as a message")
    func silentLoadPathNeverSurfacesReconciliationCodes() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let seeded = Self.seedState(
            bundle: bundle, courseCode: "MCR3U", unitId: "MCR3U.u9", syllabi: ["MCR3U"],
            nodes: [
                "not-a-real-node-id": NodeState(
                    mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                    remediated: nil)
            ])
        _ = try StudentStateStore.write(seeded, to: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        let messages: [String]
        switch outcome {
        case .ready(_, let m, _): messages = m
        case .courseSelectionNeeded(_, let m, _): messages = m
        case .refused: messages = []
        }
        #expect(messages.allSatisfy { $0 == "PLATFORM_STATE_UNREADABLE" || $0.isEmpty } || messages.isEmpty)
        #expect(!messages.contains("MAP_MARKER_OFF_TRAIL"))
        #expect(!messages.contains("EXP_NODE_NOT_IN_GRAPH"))
    }

    // MARK: - T6 idempotency

    @Test("two successive opens over the same unmodified inputs return field-equal .ready states")
    func twoSuccessiveOpensAreEqual() throws {
        let bundle = try Self.loadDemoBundle()
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let seeded = Self.seedState(
            bundle: bundle, courseCode: "MCR3U", unitId: "MCR3U.u1", syllabi: ["MCR3U"])
        _ = try StudentStateStore.write(seeded, to: stateURL)
        let today = try Self.today()

        let outcome1 = MapLaunch.open(snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: today)
        let outcome2 = MapLaunch.open(snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: today)

        guard case .ready(let map1, _, _) = outcome1, case .ready(let map2, _, _) = outcome2 else {
            Issue.record("expected both outcomes to be .ready")
            return
        }
        #expect(map1.state == map2.state)
        #expect(map1.viewModel == map2.viewModel)
    }
}

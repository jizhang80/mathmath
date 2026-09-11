import Foundation
import Testing

@testable import Core

/// Gap coverage for `MapLaunch.open` beyond `MapLaunchTests.swift`'s AC1-AC4 happy paths:
/// the `PLATFORM_STATE_UNREADABLE` branch, the `PLATFORM_SNAPSHOT_REFUSED` text mirror, the
/// W7 "kept in the file but absent from the model" claim for an unknown node id, and the
/// glossary guard (`docs/plans/epic-03-plan.md` planner note) over this task's own product file.
@Suite("MapLaunch.open — gap coverage")
struct MapLaunchGapTests {
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

    // MARK: - PLATFORM_STATE_UNREADABLE (§4.2, §4.7; arbiter-03 § Q-F "computed here, as registry codes")

    @Test(
        "an undecodable state file returns courseSelectionNeeded with PLATFORM_STATE_UNREADABLE, file kept"
    )
    func unreadableStateSurfacesTheCodeAndKeepsTheFile() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let garbage = Data("{ this is not valid JSON at all".utf8)
        try garbage.write(to: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .courseSelectionNeeded(_, let messages, let events) = outcome else {
            Issue.record("expected .courseSelectionNeeded, got \(outcome)")
            return
        }
        // `MapLaunch.open` folds `CoreError.platformStateUnreadable` into `messages` as the registry code
        // string, never resolved text (arbiter-03 § Q-F).
        #expect(messages == [CoreError.platformStateUnreadable.rawValue])
        #expect(messages == ["PLATFORM_STATE_UNREADABLE"])
        #expect(!events.contains(.mapOpened))
        // Platform W3 / this task's §4.7: the file is never rewritten on a failed read.
        #expect(try Data(contentsOf: stateURL) == garbage)
        // The registry code resolves to real student-facing text (CoreErrorText, task 03.3) — proving the
        // code this task hands back is a real, resolvable one, not a stray literal.
        let text = try #require(CoreErrorText.text(for: .platformStateUnreadable))
        #expect(!text.isEmpty)
    }

    @Test("a refused bundle's studentCode resolves to real CoreErrorText (AC2 sibling)")
    func refusedBundleStudentCodeHasResolvableText() throws {
        let tempBundleDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempBundleDir) }
        try FileManager.default.removeItem(at: tempBundleDir)
        try FileManager.default.copyItem(at: Self.demoBundleDir, to: tempBundleDir)
        try FileManager.default.removeItem(at: tempBundleDir.appendingPathComponent("edges.json"))
        let stateDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: stateDir) }
        let stateURL = stateDir.appendingPathComponent("student-state.json")

        let outcome = MapLaunch.open(snapshotDir: tempBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .refused(let refusal) = outcome else {
            Issue.record("expected .refused, got \(outcome)")
            return
        }
        #expect(refusal.studentCode == .platformSnapshotRefused)
        let text = try #require(CoreErrorText.text(for: refusal.studentCode))
        #expect(!text.isEmpty)
        #expect(CoreErrorText.userText["PLATFORM_SNAPSHOT_REFUSED"] == text)
    }

    // MARK: - W7: an unknown node id is kept in StudentState.nodes but absent from MapViewModel (map W1/W7)

    @Test(
        "an unknown node id stays in StudentState.nodes after launch but never appears in MapViewModel.nodes"
    )
    func unknownNodeIdKeptInFileAbsentFromViewModel() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(!bundle.nodes.nodes.contains { $0.id == "not-a-real-node-id" })

        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let seeded = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil),
            nodes: [
                "not-a-real-node-id": NodeState(
                    mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                    remediated: nil)
            ], trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
        _ = try StudentStateStore.write(seeded, to: stateURL)

        let outcome = MapLaunch.open(
            snapshotDir: Self.demoBundleDir, stateURL: stateURL, today: try Self.today())

        guard case .ready(let map, let messages, _) = outcome else {
            Issue.record("expected .ready, got \(outcome)")
            return
        }
        // Expedition W7: "ids no longer in the graph are kept in the file but ignored" — kept in
        // `StudentState.nodes` (the model layer this task passes through unchanged) ...
        #expect(map.state.nodes.keys.contains("not-a-real-node-id"))
        // ... but never surfaced by the derived render model (`MapViewModel.nodes` is built by iterating
        // `bundle.nodes.nodes`, never the stored state's own keys — 03.6's own rule, consumed here).
        #expect(!map.viewModel.nodes.contains { $0.id == "not-a-real-node-id" })
        // and the `EXP_NODE_NOT_IN_GRAPH` code this ignoring implies never reaches the student (§6).
        #expect(!messages.contains("EXP_NODE_NOT_IN_GRAPH"))
    }

    // MARK: - Glossary guard (docs/plans/epic-02-plan.md / epic-03-plan.md planner note)

    /// Never use "session", "start marker", "cursor", "profile" or "save" in new identifiers or copy.
    /// Scans this task's own file, line by line, stripping `//`/`///` comment text first so that a
    /// comment *explaining* why the word is avoided (e.g. `MapLaunch.swift`'s own "Never called
    /// \"session\"" note) does not trip the guard — the rule targets identifiers and prose *copy* that
    /// the App would show or the codebase would use as a name, not a meta-comment about the ban itself.
    private static func codeLines(of url: URL) throws -> [String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            if let range = line.range(of: "//") {
                return String(line[line.startIndex..<range.lowerBound])
            }
            return String(line)
        }
    }

    private static func forbiddenWordsFound(in lines: [String]) -> [String] {
        let forbidden = ["session", "profile", "cursor", "save", "start marker"]
        var found: [String] = []
        for line in lines {
            let lower = line.lowercased()
            for word in forbidden where lower.contains(word) {
                found.append(word)
            }
        }
        return found
    }

    @Test("glossary guard: MapLaunch.swift's non-comment code carries none of the banned identifiers")
    func glossaryGuardOnRealProductFile() throws {
        let url = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Sources/Core/Platform/MapLaunch.swift")
        let lines = try Self.codeLines(of: url)
        #expect(Self.forbiddenWordsFound(in: lines).isEmpty)
        // "Session" (capitalized, as a type name would be) never appears anywhere in the file at all,
        // not even in a comment — the file's own doc comment only ever uses lowercase "session" inside a
        // quoted denial ("Never called \"session\"").
        let rawText = try String(contentsOf: url, encoding: .utf8)
        #expect(!rawText.contains("Session"))
    }

    @Test("glossary guard is load-bearing: a fixture with a banned identifier fails it (negative control)")
    func glossaryGuardNegativeControl() throws {
        let violatingFixture = [
            "public struct MapSession {",
            "    public let cursor: Int",
            "    func save() {}",
            "}",
        ]
        let found = Self.forbiddenWordsFound(in: violatingFixture)
        #expect(!found.isEmpty)
        #expect(found.contains("cursor"))
        #expect(found.contains("save"))
    }
}

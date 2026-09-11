import Foundation
import Testing

@testable import Core

/// `StudentStateStore.read(at:)` / `.write(_:to:)` (`docs/domains/platform.md` § W3, arbiter-03 § Q-F
/// item 2) — AC1–AC7 of the task spec, against a fresh temporary directory per test, no App context.
@Suite("StudentStateStore (docs/domains/platform.md § W3)")
struct StudentStateStoreTests {
    /// `Packages/Core/Tests/CoreTests` -> `Tests` -> `Core` (package root) -> `Packages` -> repo root,
    /// the same five-call chain `BundleIOIntegrityTests`/`ErrorRegistryTests` use.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var v2FixtureURL: URL {
        repoRoot.appendingPathComponent("contracts/examples/student-state.json")
    }

    private static var schemaURL: URL {
        repoRoot.appendingPathComponent("contracts/schemas/student-state.schema.json")
    }

    private static var productFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // StudentStateStoreTests.swift -> CoreTests
            .deletingLastPathComponent()  // CoreTests -> Tests
            .deletingLastPathComponent()  // Tests -> package root (Packages/Core)
            .appendingPathComponent("Sources/Core/Platform/StudentStateStore.swift")
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Builds a `schema_version: 1` variant of the v2 fixture: `matrix-multiplication`'s `remediated`
    /// key is dropped and `schema_version` is set to `1` — a valid v1 document per the contract's own
    /// identity-migration rule.
    private static func v1FixtureData() throws -> Data {
        let v2Data = try Data(contentsOf: v2FixtureURL)
        guard var object = try JSONSerialization.jsonObject(with: v2Data) as? [String: Any] else {
            Issue.record("expected a JSON object in the v2 fixture")
            return v2Data
        }
        object["schema_version"] = 1
        guard var nodes = object["nodes"] as? [String: Any],
            var matrixNode = nodes["matrix-multiplication"] as? [String: Any]
        else {
            Issue.record("expected the matrix-multiplication node in the v2 fixture")
            return v2Data
        }
        matrixNode.removeValue(forKey: "remediated")
        nodes["matrix-multiplication"] = matrixNode
        object["nodes"] = nodes
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func decodedV2Fixture() throws -> StudentState {
        try CoreCoding.decoder.decode(StudentState.self, from: Data(contentsOf: v2FixtureURL))
    }

    // MARK: - AC1

    @Test("read(at:) on a missing file returns .absent, writes nothing (AC1)")
    func readAbsentFile() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")

        let (result, events) = try StudentStateStore.read(at: url)

        #expect(result == .absent)
        #expect(events.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    // MARK: - AC2

    @Test("read(at:) on a schema_version 2 file loads it unchanged, writes nothing (AC2)")
    func readV2FileLoadsUnchanged() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        let originalData = try Data(contentsOf: Self.v2FixtureURL)
        try originalData.write(to: url)

        let (result, events) = try StudentStateStore.read(at: url)

        guard case .loaded(let state, let migratedFrom) = result else {
            Issue.record("expected .loaded, got \(result)")
            return
        }
        #expect(migratedFrom == nil)
        #expect(state == (try Self.decodedV2Fixture()))
        #expect(events.isEmpty)
        #expect(try Data(contentsOf: url) == originalData)
    }

    // MARK: - AC3

    @Test("read(at:) migrates a schema_version 1 file to 2 by identity (AC3)")
    func readV1FileMigrates() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        let v1Data = try Self.v1FixtureData()
        try v1Data.write(to: url)
        let v1Decoded = try CoreCoding.decoder.decode(StudentState.self, from: v1Data)

        let (result, events) = try StudentStateStore.read(at: url)

        guard case .loaded(let migrated, let migratedFrom) = result else {
            Issue.record("expected .loaded, got \(result)")
            return
        }
        #expect(migratedFrom == 1)
        #expect(migrated.schemaVersion == 2)
        #expect(migrated.formatVersionSeen == v1Decoded.formatVersionSeen)
        #expect(migrated.syllabi == v1Decoded.syllabi)
        #expect(migrated.marker == v1Decoded.marker)
        #expect(migrated.nodes == v1Decoded.nodes)
        #expect(migrated.trail == v1Decoded.trail)
        #expect(migrated.expeditionLog == v1Decoded.expeditionLog)
        #expect(migrated.probeLog == v1Decoded.probeLog)
        #expect(migrated.installDay == v1Decoded.installDay)
        #expect(migrated.consentOn == v1Decoded.consentOn)
        #expect(events == [.platformStateMigrated])
        #expect(try Data(contentsOf: url) == (try CoreCoding.encoder.encode(migrated)))
        let preMigrationURL = url.appendingPathExtension("pre-migration")
        #expect(FileManager.default.fileExists(atPath: preMigrationURL.path) == false)
    }

    // MARK: - AC4

    @Test("read(at:) throws platformStateUnreadable on invalid JSON, bytes unchanged (AC4a)")
    func readInvalidJSONThrows() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        let originalData = Data("{ not valid json at all".utf8)
        try originalData.write(to: url)

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record("expected read(at:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }
        #expect(try Data(contentsOf: url) == originalData)
        #expect(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("pre-migration").path)
                == false)
    }

    @Test("read(at:) throws platformStateUnreadable on a missing required key, bytes unchanged (AC4b)")
    func readMissingRequiredKeyThrows() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        guard
            var object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.v2FixtureURL))
                as? [String: Any]
        else {
            Issue.record("expected a JSON object in the v2 fixture")
            return
        }
        object.removeValue(forKey: "marker")
        let originalData = try JSONSerialization.data(withJSONObject: object)
        try originalData.write(to: url)

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record("expected read(at:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }
        #expect(try Data(contentsOf: url) == originalData)
        #expect(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("pre-migration").path)
                == false)
    }

    @Test("read(at:) throws platformStateUnreadable on schema_version 3, bytes unchanged (AC4c)")
    func readTooNewSchemaVersionThrows() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        guard
            var object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.v2FixtureURL))
                as? [String: Any]
        else {
            Issue.record("expected a JSON object in the v2 fixture")
            return
        }
        object["schema_version"] = 3
        let originalData = try JSONSerialization.data(withJSONObject: object)
        try originalData.write(to: url)

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record("expected read(at:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }
        #expect(try Data(contentsOf: url) == originalData)
        #expect(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("pre-migration").path)
                == false)
    }

    // MARK: - AC5

    @Test("write(_:to:) round-trips byte-equal through CoreCoding, read returns it back (AC5)")
    func writeThenReadRoundTrips() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        let state = try Self.decodedV2Fixture()

        let writeEvents = try StudentStateStore.write(state, to: url)

        #expect(writeEvents == [.platformStateWritten])
        #expect(try Data(contentsOf: url) == (try CoreCoding.encoder.encode(state)))

        let (result, readEvents) = try StudentStateStore.read(at: url)
        guard case .loaded(let readState, let migratedFrom) = result else {
            Issue.record("expected .loaded, got \(result)")
            return
        }
        #expect(readState == state)
        #expect(migratedFrom == nil)
        #expect(readEvents.isEmpty)
    }

    @Test("write(_:to:) is deterministic: two writes of an equal value produce identical bytes")
    func writeIsDeterministic() throws {
        let tempDirA = try Self.makeTempDir()
        let tempDirB = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: tempDirA)
            try? FileManager.default.removeItem(at: tempDirB)
        }
        let urlA = tempDirA.appendingPathComponent("student-state.json")
        let urlB = tempDirB.appendingPathComponent("student-state.json")

        _ = try StudentStateStore.write(try Self.decodedV2Fixture(), to: urlA)
        _ = try StudentStateStore.write(try Self.decodedV2Fixture(), to: urlB)

        #expect(try Data(contentsOf: urlA) == (try Data(contentsOf: urlB)))
    }

    // MARK: - AC6

    @Test("write(_:to:) throws platformStateWriteFailed when the target directory is absent (AC6)")
    func writeToMissingDirectoryThrows() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("no-such-subdirectory")
            .appendingPathComponent("student-state.json")

        do {
            _ = try StudentStateStore.write(try Self.decodedV2Fixture(), to: url)
            Issue.record("expected write(_:to:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateWriteFailed)
        }
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
    }

    // MARK: - AC7

    @Test(
        "a failed migration write-back throws platformStateUnreadable, keeps the v1 file and the pre-migration backup (AC7)"
    )
    func migrationWriteFailureKeepsBothFiles() throws {
        let tempDir = try Self.makeTempDir()
        let url = tempDir.appendingPathComponent("student-state.json")
        let v1Data = try Self.v1FixtureData()
        try v1Data.write(to: url)

        // Making `url` itself immutable lets the migration's backup write (a *new* file, the
        // `.pre-migration` sibling) succeed while `write`'s internal `FileManager.replaceItemAt(url:)`
        // fails — isolating the failure to the internal write step, as AC7 requires (a read-only
        // *directory* would block the backup write too, never exercising this branch).
        try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record("expected read(at:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }

        try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        #expect(try Data(contentsOf: url) == v1Data)
        let preMigrationURL = url.appendingPathExtension("pre-migration")
        #expect(FileManager.default.fileExists(atPath: preMigrationURL.path))
        #expect(try Data(contentsOf: preMigrationURL) == v1Data)
    }

    // MARK: - T4: I5 written key set

    @Test(
        "the raw written JSON's top-level key set equals student-state.schema.json's closed required set (I5)"
    )
    func writtenKeySetMatchesSchemaRequired() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")

        _ = try StudentStateStore.write(try Self.decodedV2Fixture(), to: url)

        let writtenObject =
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let writtenKeys = Set((writtenObject ?? [:]).keys)
        #expect(!writtenKeys.isEmpty, "empty parse of the written file is a FAIL")

        let schemaObject =
            try JSONSerialization.jsonObject(with: Data(contentsOf: Self.schemaURL)) as? [String: Any]
        let requiredKeys = Set((schemaObject?["required"] as? [String]) ?? [])
        #expect(!requiredKeys.isEmpty, "empty read of the schema's required array is a FAIL")

        #expect(writtenKeys == requiredKeys)
    }

    // MARK: - T4: I14 local regression guard

    @Test("StudentStateStore.swift constructs no JSONDecoder/JSONEncoder directly (I14)")
    func productFileConstructsNoCodersDirectly() throws {
        let text = try String(contentsOf: Self.productFileURL, encoding: .utf8)
        #expect(!text.isEmpty, "empty read of StudentStateStore.swift is a FAIL")
        #expect(!text.contains("JSONDecoder("))
        #expect(!text.contains("JSONEncoder("))
    }

    // MARK: - T6: idempotency / no-leak

    @Test("a second read after a migration is byte-identical to the migrated file (relaunch)")
    func secondReadAfterMigrationIsByteIdentical() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        try (try Self.v1FixtureData()).write(to: url)

        _ = try StudentStateStore.read(at: url)
        let afterFirstRead = try Data(contentsOf: url)

        let (result, events) = try StudentStateStore.read(at: url)
        guard case .loaded(_, let migratedFrom) = result else {
            Issue.record("expected .loaded, got \(result)")
            return
        }
        #expect(migratedFrom == nil)
        #expect(events.isEmpty)
        #expect(try Data(contentsOf: url) == afterFirstRead)
    }

    @Test("no .tmp- prefixed file leaks after a successful or a failed write")
    func noLeakedTempFiles() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")

        _ = try StudentStateStore.write(try Self.decodedV2Fixture(), to: url)

        let missingDirURL = tempDir.appendingPathComponent("no-such-subdirectory")
            .appendingPathComponent("student-state.json")
        _ = try? StudentStateStore.write(try Self.decodedV2Fixture(), to: missingDirURL)

        let listing = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(!listing.contains { $0.contains(".tmp-") })
    }
}

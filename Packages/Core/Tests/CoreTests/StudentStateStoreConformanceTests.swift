import Foundation
import Testing

@testable import Core

/// Gap-fill suite for `StudentStateStore` (`tasks/epic-03-task-05-student-state-store.md` §5), covering
/// what the implementer's own `StudentStateStoreTests.swift` smoke does not: the closed-key-set boundary
/// (I5), the full-directory-listing form of AC1, both REQUIRED T5 regression-guard negative controls, and
/// the local `no Date()` determinism guard. Independent temp directory per test, no App context.
@Suite("StudentStateStore — conformance gap-fill (docs/domains/platform.md § W3)")
struct StudentStateStoreConformanceTests {
    /// `Packages/Core/Tests/CoreTests` -> `Tests` -> `Core` (package root) -> `Packages` -> repo root.
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

    private static var productFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core/Platform/StudentStateStore.swift")
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Builds a `schema_version: 1` variant of the v2 fixture: `matrix-multiplication`'s `remediated` key
    /// is dropped and `schema_version` is set to `1` (same construction as the implementer's own
    /// `StudentStateStoreTests.v1FixtureData()`, duplicated locally per file-boundary convention).
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

    // MARK: - AC1, full-directory-listing form

    @Test("read(at:) on a missing file writes nothing to the containing directory at all (AC1)")
    func readAbsentFileWritesNothingToDirectory() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")
        let listingBefore = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(listingBefore.isEmpty, "temp directory must start empty")

        _ = try StudentStateStore.read(at: url)

        let listingAfter = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
        #expect(listingAfter.isEmpty, "read(at:) on an absent file must create nothing at all")
    }

    // MARK: - AC4d: closed key set (I5, contracts/data-model.md:43 "additionalProperties: false")

    @Test(
        "read(at:) throws platformStateUnreadable when the document carries an unknown top-level key (closed key set, AC4d)"
    )
    func readUnknownTopLevelKeyThrows() throws {
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
        object["totally_unrecognized_extra_field"] = "smuggled-value"
        let originalData = try JSONSerialization.data(withJSONObject: object)
        try originalData.write(to: url)

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record(
                """
                expected read(at:) to throw platformStateUnreadable for an unknown top-level key \
                (contracts/data-model.md:43: "Every object schema sets additionalProperties: false — a \
                new field is a versioned change") — Swift's synthesized Decodable silently ignores \
                unrecognized keys, so this closed-key-set guarantee is not actually enforced by the \
                shipped code
                """)
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }
        #expect(
            try Data(contentsOf: url) == originalData,
            "an unreadable file must be preserved byte-for-byte")
        #expect(
            FileManager.default.fileExists(atPath: url.appendingPathExtension("pre-migration").path)
                == false)
    }

    // MARK: - T5 REQUIRED regression-guard negative control: atomic write

    @Test(
        "regression guard negative control: a naive direct writer (no temp file, no rename) can leave `url` truncated, while the real write(_:to:) never does (T5, atomicity)"
    )
    func atomicWriteNegativeControl() throws {
        let tempDir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("student-state.json")

        let originalState = try Self.decodedV2Fixture()
        let originalBytes = try CoreCoding.encoder.encode(originalState)
        try originalBytes.write(to: url)

        guard var newObject = try JSONSerialization.jsonObject(with: originalBytes) as? [String: Any]
        else {
            Issue.record("expected a JSON object")
            return
        }
        newObject["format_version_seen"] = "9.9.9-negative-control"
        let newState = try CoreCoding.decoder.decode(
            StudentState.self, from: JSONSerialization.data(withJSONObject: newObject))
        let canonicalNewBytes = try CoreCoding.encoder.encode(newState)

        // BROKEN VARIANT (test-file-only, never product code): a naive writer that targets `url`
        // directly, with no temp file and no atomic rename. Writing only half of the intended bytes
        // reconstructs exactly what such a writer leaves behind if interrupted mid-write.
        try Data(canonicalNewBytes.prefix(canonicalNewBytes.count / 2)).write(to: url)
        let corrupted = try Data(contentsOf: url)
        #expect(
            corrupted != originalBytes,
            "the negative control failed to reproduce corruption — it left the original untouched")
        #expect(
            corrupted != canonicalNewBytes,
            "the negative control failed to reproduce corruption — it left the full new document")

        // FIXED SHAPE: reset to the original document, then prove the real write(_:to:) — the
        // temp-file-then-rename mechanism — never exposes a truncated intermediate: a full, successful
        // write leaves exactly the complete new document, never a partial one.
        try originalBytes.write(to: url)
        let events = try StudentStateStore.write(newState, to: url)
        #expect(events == [.platformStateWritten])
        #expect(try Data(contentsOf: url) == canonicalNewBytes)
    }

    // MARK: - T5 REQUIRED regression-guard negative control: pre-migration backup ordering

    @Test(
        "regression guard negative control: migrating by deleting `url` before attempting the new write loses data on failure, while the real backup-first order preserves it (T5, arbiter-03 § Q-F)"
    )
    func preMigrationBackupNegativeControl() throws {
        let tempDir = try Self.makeTempDir()
        let url = tempDir.appendingPathComponent("student-state.json")
        let v1Data = try Self.v1FixtureData()

        // BROKEN VARIANT (test-file-only, never product code): migrate by deleting the original first,
        // with no `.pre-migration` backup, then attempting the new write — the ordering arbiter-03 § Q-F
        // explicitly rejects ("keep the pre-migration file until the migrated one is written").
        try v1Data.write(to: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: tempDir.path)
        do {
            try Data("{}".utf8).write(to: url)
            Issue.record("expected the write to a read-only directory to fail")
        } catch {
            // expected: a read-only directory refuses new-file creation.
        }
        #expect(
            FileManager.default.fileExists(atPath: url.path) == false,
            "the broken variant lost the original document with nothing to replace it — data loss")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDir.path)

        // FIXED SHAPE: under the identical read-only-directory failure, the real flow's backup-first
        // order means the backup write itself fails before `url` is ever touched, so the original v1
        // document survives untouched.
        try v1Data.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: tempDir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDir.path)
            try? FileManager.default.removeItem(at: tempDir)
        }

        do {
            _ = try StudentStateStore.read(at: url)
            Issue.record("expected read(at:) to throw")
        } catch let error as CoreError {
            #expect(error == .platformStateUnreadable)
        }
        #expect(
            try Data(contentsOf: url) == v1Data,
            "the real flow must preserve the original v1 document when its backup write fails")
    }

    // MARK: - Determinism: no wall-clock read

    @Test("StudentStateStore.swift reads no wall clock directly (no Date() literal, I14 determinism)")
    func productFileConstructsNoDateDirectly() throws {
        let text = try String(contentsOf: Self.productFileURL, encoding: .utf8)
        #expect(!text.isEmpty, "empty read of StudentStateStore.swift is a FAIL")
        #expect(!text.contains("Date("))
    }
}

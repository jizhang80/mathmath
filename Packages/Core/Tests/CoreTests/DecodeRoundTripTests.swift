import Foundation
import Testing

@testable import Core

@Suite("Decode round trip (contracts/examples/)")
struct DecodeRoundTripTests {
    /// `contracts/examples/`, located the same way `coreImportBoundary()` locates `Sources/Core`:
    /// from `#filePath` (`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`), three
    /// `.deletingLastPathComponent()` calls reach the package root (`Packages/Core`), two more reach
    /// the repo root, then `.appendingPathComponent("contracts/examples")`.
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/examples")
    }

    /// Decodes `data` into `T`, re-encodes it, and asserts the original and re-encoded documents are
    /// structurally JSON-equal (key order excluded) by comparing their `JSONSerialization` object
    /// graphs — order-independent on objects, order-sensitive on arrays.
    private static func assertRoundTrip<T: Codable>(_ type: T.Type, data: Data, file: String) throws {
        let decoded = try CoreCoding.decoder.decode(type, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let original = try JSONSerialization.jsonObject(with: data) as? NSObject
        let roundTripped = try JSONSerialization.jsonObject(with: reencoded) as? NSObject
        #expect(original == roundTripped, "\(file) did not round-trip to a structurally equal document")
    }

    // AC2: `telemetry-batch.json` is excluded by name — there is no `Core` type for it (telemetry is
    // EPICs 10–11's scope).
    @Test("all 8 named example files round-trip (AC1, AC2, AC5)")
    func decodeRoundTrip() throws {
        let files = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json",
            "landmarks.json", "sources.json", "student-state.json",
        ]
        // C3 anti-vacuity guard: an empty or partial list is a FAIL.
        #expect(files.count == 8, "expected 8 example files — empty or partial list is a FAIL")

        for file in files {
            let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent(file))
            switch file {
            case "manifest.json":
                try Self.assertRoundTrip(Manifest.self, data: data, file: file)
            case "regions.json":
                try Self.assertRoundTrip(RegionsFile.self, data: data, file: file)
            case "nodes.json":
                try Self.assertRoundTrip(NodesFile.self, data: data, file: file)
            case "edges.json":
                try Self.assertRoundTrip(EdgesFile.self, data: data, file: file)
            case "courses.json":
                try Self.assertRoundTrip(CoursesFile.self, data: data, file: file)
            case "landmarks.json":
                try Self.assertRoundTrip(LandmarksFile.self, data: data, file: file)
            case "sources.json":
                try Self.assertRoundTrip(SourcesFile.self, data: data, file: file)
            case "student-state.json":
                try Self.assertRoundTrip(StudentState.self, data: data, file: file)
            default:
                Issue.record("unhandled example file \(file)")
            }
        }
    }

    // T2: enums are closed — an unknown value fails decode (`contracts/data-model.md` § Nulls).
    @Test("unrecognized enum raw value fails decode")
    func unrecognizedEnumValueFailsDecode() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json"))
        var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var nodes = try #require(json?["nodes"] as? [[String: Any]])
        nodes[0]["region_id"] = "made-up-region"
        json?["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json as Any)
        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(NodesFile.self, from: mutated)
        }
    }

    // T5: negative control for the recursive import-boundary walk — proves the walk actually
    // descends into `Model/` rather than staying flat.
    @Test("import boundary walk includes Model/ files")
    func importBoundaryWalkIncludesModelDirectory() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        let hasModelFile = files.contains { url in
            url.deletingLastPathComponent().lastPathComponent == "Model"
        }
        #expect(hasModelFile, "recursive walk did not find any Model/*.swift file")
    }

    // T6: `BundleIO.write` idempotency — deterministic output across two writes.
    @Test("BundleIO.write is deterministic across two writes")
    func bundleWriteIsIdempotent() throws {
        let manifest = try CoreCoding.decoder.decode(
            Manifest.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json")))
        let regions = try CoreCoding.decoder.decode(
            RegionsFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("regions.json")))
        let nodes = try CoreCoding.decoder.decode(
            NodesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json")))
        let edges = try CoreCoding.decoder.decode(
            EdgesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("edges.json")))
        let courses = try CoreCoding.decoder.decode(
            CoursesFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("courses.json")))
        let landmarks = try CoreCoding.decoder.decode(
            LandmarksFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("landmarks.json")))
        let sources = try CoreCoding.decoder.decode(
            SourcesFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("sources.json")))
        let bundle = ContentBundle(
            manifest: manifest, regions: regions, nodes: nodes, edges: edges, courses: courses,
            landmarks: landmarks, sources: sources)

        let tempDir1 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tempDir2 = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir2, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir1)
            try? FileManager.default.removeItem(at: tempDir2)
        }

        try BundleIO.write(bundle, to: tempDir1)
        try BundleIO.write(bundle, to: tempDir2)

        for name in [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json", "landmarks.json",
            "sources.json",
        ] {
            let data1 = try Data(contentsOf: tempDir1.appendingPathComponent(name))
            let data2 = try Data(contentsOf: tempDir2.appendingPathComponent(name))
            #expect(data1 == data2, "\(name) was not written deterministically")
        }
    }

    // AC7 / T6: `BundleIO.read` throws `CoreError.platformBundleIntegrityFailed` when a manifest-listed
    // file is missing from disk, before constructing any `ContentBundle`.
    @Test("BundleIO.read throws platformBundleIntegrityFailed on a missing manifest-listed file")
    func bundleReadThrowsOnMissingFile() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestData = try Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json"))
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))
        // Deliberately omit every file named in manifest.files (nodes.json etc.).

        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try BundleIO.read(from: tempDir)
        }
    }

    /// Identifier blocklist (mirrors `pipeline/tests/test_contracts.py::IDENTIFIER_BLOCKLIST`, §3).
    private static let identifierBlocklist: Set<String> = [
        "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
    ]

    /// Collects every object key at every nesting level of a `JSONSerialization` object graph,
    /// descending into both dictionaries and arrays.
    private static func collectKeys(_ value: Any) -> Set<String> {
        var keys: Set<String> = []
        if let dict = value as? [String: Any] {
            for (key, nested) in dict {
                keys.insert(key)
                keys.formUnion(collectKeys(nested))
            }
        } else if let array = value as? [Any] {
            for element in array {
                keys.formUnion(collectKeys(element))
            }
        }
        return keys
    }

    /// AC6 / I5: the wire key set of the **re-encoded** `StudentState` document is disjoint from the
    /// identifier blocklist. `contracts/data-model.md` § StudentState: "the schema's closed key set is
    /// the guard" — this replaced the `CodingKeys`-reflection instrument that `StudentState` no longer
    /// has (`tasks/blocked/tester-blocked-01-01.md`).
    @Test("re-encoded StudentState document carries no identifying key (I5, AC6)")
    func studentStateWireKeysRejectIdentifierBlocklist() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedObject = try JSONSerialization.jsonObject(with: reencoded)
        let collected = Self.collectKeys(reencodedObject)

        // Anti-vacuity: a collector that returned an empty or shallow set cannot pass.
        let requiredTopLevelNames: Set<String> = [
            "schema_version", "format_version_seen", "syllabi", "marker", "nodes", "trail",
            "expedition_log", "probe_log", "install_day", "consent_on",
        ]
        #expect(
            requiredTopLevelNames.isSubset(of: collected),
            "collected key set is missing required top-level names — empty or shallow collector is a FAIL")

        #expect(
            collected.isDisjoint(with: Self.identifierBlocklist),
            "re-encoded StudentState document carries identifying keys: \(collected.intersection(Self.identifierBlocklist))"
        )
    }

    // T5 negative control for the I5 wire-key guard: injecting an identifier key into the nested
    // `marker` object must make the same collector report the intersection — proving the collector
    // descends past the top level and the disjointness assertion is live, not vacuous.
    @Test("wire-key collector catches an identifier key injected into a nested object")
    func wireKeyCollectorCatchesNestedIdentifierKey() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        var document = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        var marker = try #require(document["marker"] as? [String: Any])
        marker["device_id"] = "x"
        document["marker"] = marker

        let collected = Self.collectKeys(document)
        #expect(
            collected.intersection(Self.identifierBlocklist) == ["device_id"],
            "collector failed to catch device_id injected into the nested marker object")
    }
}

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

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// `StudentState` and its nested types declare explicit `CodingKeys` whose raw values already
    /// equal the JSON's snake_case keys (§4.10). `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`
    /// converts every incoming key before matching it against a `CodingKeys` raw value (verified
    /// empirically), so applying it on top of an already-snake_case explicit raw value produces a
    /// spurious `keyNotFound`. `.useDefaultKeys` (the decoder default) matches the explicit raw value
    /// directly and is the correct strategy for this one type.
    private static var studentStateDecoder: JSONDecoder {
        JSONDecoder()
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    /// Decodes `data` into `T`, re-encodes it, and asserts the original and re-encoded documents are
    /// structurally JSON-equal (key order excluded) by comparing their `JSONSerialization` object
    /// graphs — order-independent on objects, order-sensitive on arrays.
    private static func assertRoundTrip<T: Codable>(
        _ type: T.Type, data: Data, file: String, decoder: JSONDecoder = DecodeRoundTripTests.decoder
    ) throws {
        let decoded = try decoder.decode(type, from: data)
        let reencoded = try encoder.encode(decoded)
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
                try Self.assertRoundTrip(
                    StudentState.self, data: data, file: file, decoder: Self.studentStateDecoder)
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
            try Self.decoder.decode(NodesFile.self, from: mutated)
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
        let manifest = try Self.decoder.decode(
            Manifest.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json")))
        let regions = try Self.decoder.decode(
            RegionsFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("regions.json")))
        let nodes = try Self.decoder.decode(
            NodesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json")))
        let edges = try Self.decoder.decode(
            EdgesFile.self, from: Data(contentsOf: Self.examplesDir.appendingPathComponent("edges.json")))
        let courses = try Self.decoder.decode(
            CoursesFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("courses.json")))
        let landmarks = try Self.decoder.decode(
            LandmarksFile.self,
            from: Data(contentsOf: Self.examplesDir.appendingPathComponent("landmarks.json")))
        let sources = try Self.decoder.decode(
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

    // AC6 / I5: `StudentState` and every nested type it is built from expose a `CodingKeys` case set
    // with no intersection with the identifier blocklist (mirrors
    // `pipeline/tests/test_contracts.py::test_transmitted_shapes_reject_identifier_keys`).
    @Test("StudentState CodingKeys carry no identifying field (I5, AC6)")
    func studentStateCodingKeysRejectIdentifierBlocklist() throws {
        let identifierBlocklist: Set<String> = [
            "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
        ]

        // Trail has no explicit `CodingKeys` (its only field, `segments`, is not identifier-shaped) —
        // only the types that declare an explicit `CodingKeys: CaseIterable` are checked here.
        let allKeySets: [[String]] = [
            StudentState.CodingKeys.allCases.map(\.rawValue),
            Marker.CodingKeys.allCases.map(\.rawValue),
            NodeState.CodingKeys.allCases.map(\.rawValue),
            TrailSegment.CodingKeys.allCases.map(\.rawValue),
            ExpeditionLogEntry.CodingKeys.allCases.map(\.rawValue),
            ProbeLogEntry.CodingKeys.allCases.map(\.rawValue),
        ]

        for keys in allKeySets {
            // Anti-vacuity: a type with zero declared keys would vacuously "pass".
            #expect(!keys.isEmpty, "a CodingKeys case set must not be empty")
        }

        let allKeys = Set(allKeySets.flatMap { $0 })
        #expect(!allKeys.isEmpty, "expected at least one CodingKeys case across StudentState's types")
        #expect(
            allKeys.isDisjoint(with: identifierBlocklist),
            "StudentState CodingKeys intersect the identifier blocklist: \(allKeys.intersection(identifierBlocklist))"
        )
    }
}

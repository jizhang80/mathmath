import Foundation
import Testing

@testable import Core

/// Deepens `BundleIO` coverage beyond `DecodeRoundTripTests.bundleReadThrowsOnMissingFile` (AC7):
/// proves the manifest-completeness check happens *before* any content file is decoded (not merely
/// that the end-to-end call throws the right error), and exercises `BundleIO.read`/`write` together.
@Suite("BundleIO: manifest integrity ordering and read/write integration")
struct BundleIOIntegrityTests {
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/examples")
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static func loadBundle() throws -> ContentBundle {
        func decode<T: Decodable>(_ type: T.Type, _ file: String) throws -> T {
            try decoder.decode(type, from: Data(contentsOf: examplesDir.appendingPathComponent(file)))
        }
        return ContentBundle(
            manifest: try decode(Manifest.self, "manifest.json"),
            regions: try decode(RegionsFile.self, "regions.json"),
            nodes: try decode(NodesFile.self, "nodes.json"),
            edges: try decode(EdgesFile.self, "edges.json"),
            courses: try decode(CoursesFile.self, "courses.json"),
            landmarks: try decode(LandmarksFile.self, "landmarks.json"),
            sources: try decode(SourcesFile.self, "sources.json"))
    }

    // AC7 deepened: the file-presence check runs to completion over the full manifest.files list
    // BEFORE any content file is decoded. Proven by planting a content file that would throw a
    // *different* error (a DecodingError, from invalid JSON) if it were ever opened, alongside a
    // missing manifest-listed file. If BundleIO decoded content before finishing the presence check,
    // this test would observe a DecodingError instead of platformBundleIntegrityFailed.
    @Test("BundleIO.read throws platformBundleIntegrityFailed before decoding any content file")
    func integrityCheckPrecedesContentDecode() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let manifestData = try Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json"))
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))

        // Plant a deliberately-corrupt regions.json — if BundleIO ever tried to decode it, decode
        // would throw a DecodingError, not platformBundleIntegrityFailed.
        try "{ not valid json at all".data(using: .utf8)!.write(
            to: tempDir.appendingPathComponent("regions.json"))
        // Deliberately omit nodes.json (and every other manifest-listed file) entirely.

        do {
            _ = try BundleIO.read(from: tempDir)
            Issue.record("expected BundleIO.read to throw")
        } catch let error as CoreError {
            #expect(
                error == .platformBundleIntegrityFailed,
                "expected platformBundleIntegrityFailed, got CoreError.\(error)")
        } catch {
            Issue.record(
                "expected CoreError.platformBundleIntegrityFailed but content decode ran first and threw \(error) — the presence check does not precede content decode"
            )
        }
    }

    // Malformed manifest.json itself (invalid JSON syntax) is a plain decode failure, not
    // platformBundleIntegrityFailed — the manifest is the one file BundleIO.read decodes before any
    // presence check can even run.
    @Test("BundleIO.read on a malformed manifest.json fails decode, not integrity")
    func malformedManifestFailsDecodeNotIntegrity() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "{ not valid json at all".data(using: .utf8)!.write(
            to: tempDir.appendingPathComponent("manifest.json"))

        #expect(throws: DecodingError.self) {
            try BundleIO.read(from: tempDir)
        }
    }

    // Happy-path fidelity extension (budget: one per public operation, item 1): a bundle written by
    // `BundleIO.write` and read back by `BundleIO.read` round-trips to an `Equatable`-equal
    // `ContentBundle` — the smoke test only proves `write` is deterministic, not that `read` can
    // consume what `write` produces.
    @Test("BundleIO.write then BundleIO.read round-trips to an equal ContentBundle")
    func writeThenReadRoundTrips() throws {
        let bundle = try Self.loadBundle()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try BundleIO.write(bundle, to: tempDir)
        let readBack = try BundleIO.read(from: tempDir)

        #expect(readBack.manifest == bundle.manifest)
        #expect(readBack.regions == bundle.regions)
        #expect(readBack.nodes == bundle.nodes)
        #expect(readBack.edges == bundle.edges)
        #expect(readBack.courses == bundle.courses)
        #expect(readBack.landmarks == bundle.landmarks)
        #expect(readBack.sources == bundle.sources)
    }
}

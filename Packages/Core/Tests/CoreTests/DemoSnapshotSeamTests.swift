import Foundation
import Testing

@testable import Core

/// AC8 (byte-identity of `App/Sources/DemoSnapshot/` against `data/demo/`) and AC9 (the C1 seam:
/// `BundleLoader.load(from:)` over both, neither stubbed).
@Suite("Embedded demo snapshot: byte-identity and C1 loader seam")
struct DemoSnapshotSeamTests {
    /// `Packages/Core/Tests/CoreTests` -> `Tests` -> `Core` (package root) -> `Packages` -> repo root.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var dataDemoDir: URL { repoRoot.appendingPathComponent("data/demo") }
    private static var embeddedDir: URL { repoRoot.appendingPathComponent("App/Sources/DemoSnapshot") }

    // Fixed list, not a directory glob — an empty or partial embed directory must not vacuously pass.
    private static let fileNames = [
        "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json", "landmarks.json",
        "sources.json",
    ]

    // AC8: every embedded file is byte-identical to its data/demo counterpart.
    @Test("App/Sources/DemoSnapshot is byte-identical to data/demo (AC8)")
    func embeddedSnapshotIsByteIdentical() throws {
        #expect(!Self.fileNames.isEmpty, "the comparison set must not be empty")
        for name in Self.fileNames {
            let sourceData = try Data(contentsOf: Self.dataDemoDir.appendingPathComponent(name))
            let embeddedData = try Data(contentsOf: Self.embeddedDir.appendingPathComponent(name))
            #expect(
                sourceData == embeddedData, "\(name) differs between data/demo and App/Sources/DemoSnapshot")
        }
    }

    // AC8 negative control: a planted one-byte diff must fail the same comparison.
    @Test("a planted one-byte diff fails the byte-identity comparison (AC8 negative control)")
    func plantedByteDiffFailsComparison() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var manifestData = try Data(contentsOf: Self.embeddedDir.appendingPathComponent("manifest.json"))
        #expect(!manifestData.isEmpty)
        manifestData[0] = manifestData[0] &+ 1
        let plantedPath = tempDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: plantedPath)

        let sourceData = try Data(contentsOf: Self.dataDemoDir.appendingPathComponent("manifest.json"))
        let plantedData = try Data(contentsOf: plantedPath)
        #expect(sourceData != plantedData)
    }

    // AC9 / C1 seam: BundleLoader.load(from:) drives both the real data/demo and the embedded copy,
    // neither stubbed, and their reports agree.
    @Test("BundleLoader.load(from:) succeeds over both data/demo and App/Sources/DemoSnapshot (AC9)")
    func loaderSeamAgreesOverBothCopies() throws {
        let fromDataDemo = try BundleLoader.load(from: Self.dataDemoDir)
        let fromEmbedded = try BundleLoader.load(from: Self.embeddedDir)

        #expect(fromDataDemo.report.passed == true)
        #expect(fromEmbedded.report.passed == true)
        #expect(fromDataDemo.report == fromEmbedded.report)
    }
}

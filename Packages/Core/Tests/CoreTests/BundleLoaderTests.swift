import Foundation
import Testing

@testable import Core

/// `BundleLoader.load(from:)` — the app-launch load/validate seam (AC1–AC6).
@Suite("BundleLoader.load(from:) (docs/domains/platform.md § W1 step 1)")
struct BundleLoaderTests {
    /// `Packages/Core/Tests/CoreTests` -> `Tests` -> `Core` (package root) -> `Packages` -> repo root,
    /// same five-call chain `BundleIOIntegrityTests` uses to reach `contracts/examples`.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var dataDemoDir: URL {
        repoRoot.appendingPathComponent("data/demo")
    }

    /// Copies `data/demo` into a fresh temp directory so a test can mutate one file without touching
    /// the real fixture.
    private static func tempCopyOfDataDemo() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: dataDemoDir, to: tempDir)
        return tempDir
    }

    private static func rewriteJSONObject(at url: URL, mutate: (inout [String: Any]) -> Void) throws {
        let data = try Data(contentsOf: url)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("expected a JSON object at \(url)")
            return
        }
        mutate(&object)
        let rewritten = try JSONSerialization.data(withJSONObject: object)
        try rewritten.write(to: url)
    }

    // T1 / AC1 / AC2: happy path over `data/demo` itself.
    @Test("data/demo loads and passes every L0 rule (AC1, AC2)")
    func dataDemoLoadsClean() throws {
        let (bundle, report) = try BundleLoader.load(from: Self.dataDemoDir)
        #expect(report.passed == true)
        #expect(bundle.manifest.bundleId == "demo")
    }

    // T2 / AC3a: a manifest-listed file missing from disk.
    @Test("a missing manifest-listed file refuses with platformBundleIntegrityFailed (AC3)")
    func missingManifestListedFileRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.removeItem(at: tempDir.appendingPathComponent("edges.json"))

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        }
    }

    // T2 / AC3b: a format_version major mismatch.
    @Test("a format_version major mismatch refuses with platformBundleIntegrityFailed (AC3)")
    func formatMajorMismatchRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("manifest.json")) { object in
            object["format_version"] = "1.0.0"
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        }
    }

    // T2 / AC4: a deleted required key is a decode failure, not an L0 violation.
    @Test("a deleted required node key refuses with platformBundleIntegrityFailed (AC4)")
    func deletedRequiredKeyRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("nodes.json")) { object in
            guard var nodes = object["nodes"] as? [[String: Any]], var first = nodes.first else {
                Issue.record("expected at least one node")
                return
            }
            first.removeValue(forKey: "position")
            nodes[0] = first
            object["nodes"] = nodes
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        }
    }

    // T3 / AC5: an added edge that creates a cycle.
    @Test("an edge that creates a cycle refuses with graphL0Failed and a failing L0-1 (AC5)")
    func cycleEdgeRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("edges.json")) { object in
            guard var edges = object["edges"] as? [[String: Any]] else {
                Issue.record("expected an edges array")
                return
            }
            edges.append([
                "from": "solving-linear-equations",
                "to": "linear-relations",
                "sources": [["tag": "ministry_prereq", "origin": "MCR3U-2007"]],
                "generation_agreement": 1,
                "confidence": 0.95,
                "probe_stats": ["probes": 0, "confirmed": 0],
            ])
            object["edges"] = edges
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .graphL0Failed)
            let l01 = try #require(refusal.report?.checks.first { $0.id == "L0-1" })
            #expect(l01.passed == false)
            #expect(!l01.violations.isEmpty)
        }
    }

    // T3 / AC6: a node position moved outside every region polygon.
    @Test("a position outside every region polygon refuses with mapLayoutMissing and a failing L0-7 (AC6)")
    func positionOutsidePolygonRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("nodes.json")) { object in
            guard var nodes = object["nodes"] as? [[String: Any]], var first = nodes.first else {
                Issue.record("expected at least one node")
                return
            }
            first["position"] = ["x": 999, "y": 999]
            nodes[0] = first
            object["nodes"] = nodes
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .mapLayoutMissing)
            let l07 = try #require(refusal.report?.checks.first { $0.id == "L0-7" })
            #expect(l07.passed == false)
            #expect(!l07.violations.isEmpty)
        }
    }
}

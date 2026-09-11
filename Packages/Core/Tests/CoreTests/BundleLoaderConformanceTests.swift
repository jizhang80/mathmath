import Foundation
import Testing

@testable import Core

/// Additional coverage for `BundleLoader.load(from:)` beyond `BundleLoaderTests`' AC1-AC6 smoke: I14's
/// "exactly one format-major implementation", I15's landmark decode refusal, no-`ContentBundle`-escape,
/// determinism/idempotency, and the embedded-snapshot directory-membership and embed-script guards that
/// `DemoSnapshotSeamTests` does not cover. Every regression guard here ships with a negative control that
/// reconstructs the defect and proves the guard fails on it before trusting it passes on the fixed shape.
@Suite("BundleLoader / L0Checker extraction: conformance and regression controls")
struct BundleLoaderConformanceTests {
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
    private static var coreSourcesDir: URL {
        repoRoot.appendingPathComponent("Packages/Core/Sources/Core")
    }
    private static var embedScript: URL { repoRoot.appendingPathComponent("scripts/embed-demo-snapshot.sh") }

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

    // MARK: - I14: exactly one format-major implementation

    /// Scans every `.swift` file under `directory` for the literal expression `L0Checker.swift` uses to
    /// compare the bundle's `format_version` major against `CoreInfo.dataFormatVersion`. Returns the
    /// files that contain it. A grep-style regression guard: the fixed literal is deliberately specific
    /// (not just "split(separator:")) so it does not false-positive on unrelated semver splits elsewhere
    /// in `Core` (e.g. `StateMerge.swift`'s `higherSemver`).
    private static func filesContainingFormatMajorLiteral(under directory: URL) throws -> [String] {
        let pattern = "dataFormatVersion.split(separator:"
        var hits: [String] = []
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: nil)
        else {
            return hits
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            if contents.contains(pattern) {
                hits.append(fileURL.lastPathComponent)
            }
        }
        return hits
    }

    // I14 positive: the only file in `Core`'s sources containing the format-major comparison literal
    // is `L0Checker.swift` itself (`BundleLoader.swift` reuses `L0Checker.formatMajorMatches` instead of
    // reimplementing the comparison, per §4 step 1 of the task spec).
    @Test("the format-major comparison literal exists in exactly one Core source file (I14/D42)")
    func formatMajorComparisonExistsExactlyOnce() throws {
        let hits = try Self.filesContainingFormatMajorLiteral(under: Self.coreSourcesDir)
        #expect(hits == ["L0Checker.swift"])
    }

    // I14 negative control: prove the scanner above is not vacuously green by planting a duplicate
    // implementation into a temp directory and asserting the same scan detects it.
    @Test("the format-major scanner detects a planted duplicate implementation (negative control)")
    func formatMajorScannerDetectsPlantedDuplicate() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let plantedSource = """
            import Foundation
            enum RogueDuplicate {
                static func matches(_ major: String) -> Bool {
                    major == CoreInfo.dataFormatVersion.split(separator: ".").first.map(String.init)
                }
            }
            """
        try plantedSource.write(
            to: tempDir.appendingPathComponent("RogueDuplicate.swift"), atomically: true, encoding: .utf8)

        let hits = try Self.filesContainingFormatMajorLiteral(under: tempDir)
        #expect(hits == ["RogueDuplicate.swift"], "the scanner must flag a reimplementation, not miss it")
    }

    // MARK: - I15: a landmark without source_url is refused, never silently dropped or passed through

    // T2 / I15: `landmarks.json` with `source_url` removed from its one landmark fails to decode
    // (`Landmark.sourceUrl` is non-optional), refusing before any bundle value escapes.
    @Test("a landmark missing source_url refuses with platformBundleIntegrityFailed (I15)")
    func landmarkMissingSourceUrlRefuses() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("landmarks.json")) { object in
            guard var landmarks = object["landmarks"] as? [[String: Any]], var first = landmarks.first
            else {
                Issue.record("expected at least one landmark")
                return
            }
            first.removeValue(forKey: "source_url")
            landmarks[0] = first
            object["landmarks"] = landmarks
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        }
    }

    // MARK: - Decision default: any non-CoreError/DecodingError failure from BundleIO.read also collapses

    // The §6 decision default: a directory that does not exist raises a Foundation file-system error
    // (neither a `CoreError` nor a `DecodingError`), which `BundleLoader`'s untyped catch must still map
    // to `.platformBundleIntegrityFailed`, never let escape uncaught.
    @Test("a nonexistent directory refuses with platformBundleIntegrityFailed, not an uncaught error")
    func nonexistentDirectoryRefuses() throws {
        let missingDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            _ = try BundleLoader.load(from: missingDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            #expect(refusal.studentCode == .platformSnapshotRefused)
            #expect(refusal.internalCode == .platformBundleIntegrityFailed)
        }
    }

    // MARK: - No ContentBundle value ever escapes on refusal

    // Runtime negative control on `BundleRefusal`'s shape: enumerate its stored properties via `Mirror`
    // and assert none is typed `ContentBundle`. This guards against a future edit that attaches the
    // decoded bundle to the refusal for "convenience", which would violate this task's stated invariant
    // and I8 ("a violation refuses the bundle rather than rendering a broken map").
    @Test("BundleRefusal carries no ContentBundle-typed field")
    func bundleRefusalCarriesNoContentBundle() throws {
        let tempDir = try Self.tempCopyOfDataDemo()
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try Self.rewriteJSONObject(at: tempDir.appendingPathComponent("manifest.json")) { object in
            object["format_version"] = "1.0.0"
        }

        do {
            _ = try BundleLoader.load(from: tempDir)
            Issue.record("expected BundleLoader.load(from:) to throw")
        } catch let refusal as BundleRefusal {
            let mirror = Mirror(reflecting: refusal)
            for child in mirror.children {
                #expect(
                    !(child.value is ContentBundle),
                    "BundleRefusal must never carry a ContentBundle value")
            }
        }
    }

    // MARK: - Determinism: first-failing check in fixed order wins when multiple rules fail at once

    // §6 decision default: when both L0-1 (cycle) and L0-7 (position outside polygon) fail
    // simultaneously, `internalCode` is the code for L0-1 (earlier in `L0Checker.validate(bundle:)`'s
    // fixed check order), not L0-7 — a determinism guard on the "first failing check wins" rule.
    @Test("simultaneous L0-1 and L0-7 violations resolve to the earlier check's code, deterministically")
    func multipleSimultaneousViolationsResolveToFirstCheckInOrder() throws {
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
            #expect(refusal.internalCode == .graphL0Failed, "L0-1 precedes L0-7 in the fixed check order")
            let l01 = try #require(refusal.report?.checks.first { $0.id == "L0-1" })
            let l07 = try #require(refusal.report?.checks.first { $0.id == "L0-7" })
            #expect(l01.passed == false)
            #expect(
                l07.passed == false,
                "both violations are present in the report even though only one wins the code")
        }
    }

    // MARK: - Idempotency: the same directory loaded twice yields equal reports, no accumulated state

    @Test("loading the same directory twice returns two equal reports (pure function of the directory)")
    func loadingSameDirectoryTwiceIsIdempotent() throws {
        let first = try BundleLoader.load(from: Self.dataDemoDir)
        let second = try BundleLoader.load(from: Self.dataDemoDir)
        #expect(first.report == second.report)
    }

    // MARK: - AC8: the embedded directory contains exactly the 7 named files, nothing extra

    // `DemoSnapshotSeamTests`' byte-identity test iterates a fixed name list, which would not catch an
    // extra stray file left in `App/Sources/DemoSnapshot/` (e.g. a `.DS_Store` or a leftover `.swift`
    // file, which would violate AC9's "no second loader ... exists in App/Sources"). This test asserts
    // the directory's actual membership equals the fixed set exactly.
    @Test("App/Sources/DemoSnapshot contains exactly the 7 named files, no more, no fewer (AC8/AC9)")
    func embeddedDirectoryHasNoExtraneousFiles() throws {
        let expected: Set<String> = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json",
            "landmarks.json", "sources.json",
        ]
        let actual = try FileManager.default.contentsOfDirectory(atPath: Self.embeddedDir.path)
        #expect(Set(actual) == expected)
        #expect(actual.allSatisfy { $0.hasSuffix(".json") }, "no Swift source may live under DemoSnapshot")
    }

    // MARK: - AC8 negative control (stronger): the same 7-file comparison loop detects a diff planted
    // into a full temp copy of the embedded directory, isolated to exactly the corrupted file.

    @Test("a one-byte diff planted into a full temp copy of the embedded snapshot is detected file-by-file")
    func byteIdentityLoopDetectsCorruptionInFullCopy() throws {
        let fileNames = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json",
            "landmarks.json", "sources.json",
        ]
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: Self.embeddedDir, to: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var nodesData = try Data(contentsOf: tempDir.appendingPathComponent("nodes.json"))
        nodesData[0] = nodesData[0] &+ 1
        try nodesData.write(to: tempDir.appendingPathComponent("nodes.json"))

        var mismatches: [String] = []
        for name in fileNames {
            let sourceData = try Data(contentsOf: Self.dataDemoDir.appendingPathComponent(name))
            let candidateData = try Data(contentsOf: tempDir.appendingPathComponent(name))
            if sourceData != candidateData {
                mismatches.append(name)
            }
        }
        #expect(mismatches == ["nodes.json"], "exactly the corrupted file must be flagged, no more, no fewer")
    }

    // MARK: - Embed script idempotency

    // `Foundation.Process` (needed to actually spawn `scripts/embed-demo-snapshot.sh`) does not exist on
    // iOS/iPadOS, and `Core-Package`'s tests run on the iOS simulator (docs/tech-stack.md §3, D29) — so
    // this suite cannot shell out to the script itself; documenting that per this task's explicit escape
    // hatch ("test via a temp checkout copy if feasible, else document why not") rather than skip the
    // requirement silently. Instead, this test proves idempotency the way the spec's script text
    // guarantees it: the script (§4 step 6) runs an unconditional `cp "$SRC/$f" "$DEST/$f"` per file, no
    // `mv`, no append (`>>`), no existence check that could skip a file on a second run — reproduced here
    // as the identical two-pass plain-copy operation the script performs, over a temp checkout copy of
    // `data/demo`, asserting the destination is byte-identical after the first and the second pass.
    @Test("scripts/embed-demo-snapshot.sh's copy operation is idempotent: two passes agree byte-for-byte")
    func embedScriptCopyOperationIsIdempotent() throws {
        let scriptText = try String(contentsOf: Self.embedScript, encoding: .utf8)
        #expect(scriptText.contains("cp \"$SRC/$f\" \"$DEST/$f\""))
        #expect(!scriptText.contains(">>"), "the script must not append to the destination")
        #expect(!scriptText.contains("mv "), "the script must copy, not move, the source files")

        let fileNames = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json",
            "landmarks.json", "sources.json",
        ]
        let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDest, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDest) }

        func copyPass() throws {
            for name in fileNames {
                let dest = tempDest.appendingPathComponent(name)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(
                    at: Self.dataDemoDir.appendingPathComponent(name), to: dest)
            }
        }

        try copyPass()
        var firstPassContents: [String: Data] = [:]
        for name in fileNames {
            firstPassContents[name] = try Data(contentsOf: tempDest.appendingPathComponent(name))
        }

        try copyPass()
        for name in fileNames {
            let secondPassData = try Data(contentsOf: tempDest.appendingPathComponent(name))
            #expect(secondPassData == firstPassContents[name], "\(name) changed on the second pass")
        }
    }
}

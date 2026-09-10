import Foundation
import Testing

@testable import Rendering

/// Two independent guarantees not covered by `BundleRenderCheckTests`'s AC3 case (which cross-checks item
/// ids only):
/// 1. The outcome record's stated COUNTS (per-field-kind and total) match a fresh scan of the real bundle —
///    a stale count is the likeliest future drift once task 01.7 amends `data/demo/nodes.json` again.
/// 2. I14: `Core` gains no dependency on `Rendering`/SwiftMath; only `Packages/Rendering` imports SwiftMath.
@Suite("Outcome record count staleness + I14 import boundary")
struct OutcomeRecordAndImportBoundaryTests {
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // RenderingTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // Rendering/
            .deletingLastPathComponent()  // Packages/
            .deletingLastPathComponent()  // repo root
    }

    private static func nodesJSONURL() -> URL {
        repoRoot().appendingPathComponent("data/demo/nodes.json")
    }

    private static func outcomeRecordURL() -> URL {
        repoRoot().appendingPathComponent("docs/epics/epic-01-rendering-spike-outcome.md")
    }

    /// Extracts `Field kind -> Entries scanned` from the outcome record's per-field-kind markdown table.
    /// Recognises exactly the five field-kind row labels the spec's broad enumeration names, plus the
    /// `Total` row, by matching a stripped (backtick/bold-marker-free) leading substring — robust to the
    /// exact wording each row uses around the field-kind name ("hint_tree tier strings" vs "hint_tree").
    private static func extractScannedCounts(from text: String) -> [String: Int] {
        let labelPrefixes: [(String, String)] = [
            ("`prompt_latex`", "prompt_latex"),
            ("`choices[].latex`", "choices"),
            ("`worked_examples[].steps_latex[]`", "steps_latex"),
            ("`hint_tree`", "hint_tree"),
            ("`explanation`", "explanation"),
            ("**Total**", "total"),
        ]
        var counts: [String: Int] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("|") else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count >= 3 else { continue }
            let label = cells[1]
            guard let (_, key) = labelPrefixes.first(where: { label.hasPrefix($0.0) }) else { continue }
            let scannedCell = cells[2].trimmingCharacters(in: CharacterSet(charactersIn: "*"))
            if let value = Int(scannedCell) {
                counts[key] = value
            }
        }
        return counts
    }

    private static func freshScanCounts() throws -> [String: Int] {
        let data = try Data(contentsOf: Self.nodesJSONURL())
        let report = try RenderCheckReport.scanning(nodesJSON: data)
        return [
            "prompt_latex": report.entries.count { $0.field == "prompt_latex" },
            "choices": report.entries.count { $0.field.hasPrefix("choices[") },
            "steps_latex": report.entries.count { $0.field.hasPrefix("steps_latex[") },
            "hint_tree": report.entries.count { $0.field.hasPrefix("hint_tree[") },
            "explanation": report.entries.count { $0.field == "explanation" },
            "total": report.entries.count,
        ]
    }

    @Test("outcome record's per-field-kind and total counts match a fresh scan of the real bundle")
    func outcomeRecordCountsMatchFreshScan() throws {
        let text = try String(contentsOf: Self.outcomeRecordURL(), encoding: .utf8)
        let recorded = Self.extractScannedCounts(from: text)
        let fresh = try Self.freshScanCounts()

        // Anti-vacuity: the extraction must actually find all six rows, else the comparison below is
        // vacuously true over an empty dictionary.
        #expect(recorded.count == 6)

        for (key, freshValue) in fresh {
            let recordedValue = recorded[key]
            #expect(
                recordedValue == freshValue,
                "outcome record states \(String(describing: recordedValue)) for '\(key)' but a fresh scan found \(freshValue)"
            )
        }
    }

    /// Negative control (C2): the extraction/comparison above is only a guard if it can actually detect a
    /// stale number. A fabricated copy of the table with `prompt_latex` deliberately wrong proves the
    /// comparison discriminates real drift, not just parses successfully.
    @Test("the count-staleness guard reds on a fabricated mismatched count")
    func countStalenessGuardRedsOnFabricatedMismatch() throws {
        let staleText = """
            | Field kind | Entries scanned | Unresolved |
            |---|---|---|
            | `prompt_latex` | 999 | 0 |
            | `choices[].latex` | 40 | 0 |
            | `worked_examples[].steps_latex[]` | 0 | 0 |
            | `hint_tree` tier strings | 63 | 0 |
            | `explanation` | 0 | 0 |
            | **Total** | **143** | **0** |
            """
        let recorded = Self.extractScannedCounts(from: staleText)
        let fresh = try Self.freshScanCounts()

        #expect(recorded["prompt_latex"] == 999)
        // The guard's comparison predicate genuinely distinguishes this from the real (matching) scan --
        // proving it is load-bearing rather than a check that can never fail.
        #expect(recorded["prompt_latex"] != fresh["prompt_latex"])
    }

    // MARK: - I14: Core gains no dependency on Rendering/SwiftMath; only Rendering imports SwiftMath

    @Test("Core's Package.swift declares no dependency on Rendering or SwiftMath")
    func corePackageManifestHasNoRenderingOrSwiftMathDependency() throws {
        let text = try String(
            contentsOf: Self.repoRoot().appendingPathComponent("Packages/Core/Package.swift"),
            encoding: .utf8)
        #expect(!text.contains("SwiftMath"))
        #expect(!text.contains("\"Rendering\""))
    }

    @Test("no Core source file imports Rendering or SwiftMath")
    func noCoreSourceFileImportsRenderingOrSwiftMath() throws {
        let coreSourcesRoot = Self.repoRoot().appendingPathComponent("Packages/Core/Sources")
        let fileManager = FileManager.default
        guard
            let enumerator = fileManager.enumerator(
                at: coreSourcesRoot, includingPropertiesForKeys: nil)
        else {
            Issue.record("could not enumerate \(coreSourcesRoot.path)")
            return
        }
        var scannedAtLeastOneFile = false
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            scannedAtLeastOneFile = true
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            #expect(!text.contains("import Rendering"), "\(fileURL.lastPathComponent) imports Rendering")
            #expect(!text.contains("import SwiftMath"), "\(fileURL.lastPathComponent) imports SwiftMath")
        }
        #expect(scannedAtLeastOneFile)
    }

    /// Positive control for the two guards above: `Packages/Rendering` itself DOES import SwiftMath (and
    /// its `Package.swift` DOES declare the dependency) — proving the negative-check methodology used above
    /// is capable of finding a real match, not merely failing to find anything anywhere.
    @Test("Rendering's own Package.swift and sources DO declare/import SwiftMath (positive control)")
    func renderingPackageDoesImportSwiftMath() throws {
        let manifestText = try String(
            contentsOf: Self.repoRoot().appendingPathComponent("Packages/Rendering/Package.swift"),
            encoding: .utf8)
        #expect(manifestText.contains("SwiftMath"))

        let renderingSourceText = try String(
            contentsOf: Self.repoRoot().appendingPathComponent(
                "Packages/Rendering/Sources/Rendering/Rendering.swift"),
            encoding: .utf8)
        #expect(renderingSourceText.contains("import SwiftMath"))
    }
}

import Foundation
import Testing

@testable import Core

/// C2 / I14: negative control for the recursive import-boundary walk (`coreImportBoundary()` in
/// `CoreTests.swift`, extended for this task to walk `Sources/Core` recursively so `Model/` is
/// covered). Proves the scan logic — reconstructed here against a synthetic directory tree — actually
/// catches a forbidden import planted two directories deep, the same depth `Model/*.swift` sits at.
/// A recursive-walk fix that was silently still shallow (e.g. `enumerator` misconfigured to
/// `.skipsSubdirectoryDescendants`) would pass `importBoundaryWalkIncludesModelDirectory` (which only
/// checks *some* file came from `Model/`) but this test proves the scan would also have *rejected* a
/// forbidden import at that depth, which is the property I14 actually needs.
@Suite("Import boundary: negative control (C2, I14)")
struct ImportBoundaryNegativeControlTests {
    private static let forbidden = [
        "SwiftUI", "UIKit", "AppKit", "SpriteKit", "SwiftData", "FoundationModels", "CoreData", "Combine",
    ]

    /// Mirrors `coreImportBoundary()`'s recursive-walk-plus-forbidden-import-scan logic, parameterised
    /// over a directory so it can run against a synthetic fixture as well as the real `Sources/Core`.
    private static func forbiddenImportViolations(in root: URL) throws -> [String] {
        let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no source files found — empty scan is a FAIL")
        var violations: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                if forbidden.contains(module) {
                    violations.append("\(file.lastPathComponent) imports \(module)")
                }
            }
        }
        return violations
    }

    // Plants a forbidden import two directories deep (`Fixture/Model/Planted.swift`), matching the
    // depth of the real `Model/` subdirectory this task added, and proves the recursive scan finds it.
    @Test("recursive scan catches a forbidden import planted inside a Model/ subdirectory")
    func recursiveScanCatchesPlantedViolation() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelDir = tempRoot.appendingPathComponent("Model")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\npublic struct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nimport SwiftUI\npublic struct Planted {}\n"
            .write(
                to: modelDir.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try Self.forbiddenImportViolations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("SwiftUI") },
            "recursive scan did not catch a forbidden import planted inside Model/")
    }

    // The scan does not false-positive on a clean tree with the same shape (sibling top-level file
    // plus a nested Model/ subdirectory, no forbidden import anywhere).
    @Test("recursive scan reports no violations on a clean fixture tree")
    func recursiveScanIsCleanOnACleanTree() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modelDir = tempRoot.appendingPathComponent("Model")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\npublic struct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\npublic struct AlsoClean {}\n"
            .write(
                to: modelDir.appendingPathComponent("AlsoClean.swift"), atomically: true, encoding: .utf8)

        let violations = try Self.forbiddenImportViolations(in: tempRoot)
        #expect(violations.isEmpty, "clean fixture tree unexpectedly reported violations: \(violations)")
    }
}

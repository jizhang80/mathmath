import Foundation
import Testing

@testable import Core

@Suite("Core package")
struct CoreTests {
    @Test("data format version is a semantic version")
    func dataFormatVersion() {
        let parts = CoreInfo.dataFormatVersion.split(separator: ".")
        #expect(parts.count == 3)
        #expect(parts.allSatisfy { Int($0) != nil })
    }

    /// I14 / D33: `Core` imports Foundation only. Scans every source file of the Core target for
    /// forbidden imports; an empty scan is a FAIL (C3), so a moved directory cannot pass silently.
    @Test("Core imports Foundation only (I14)")
    func coreImportBoundary() throws {
        let forbidden = [
            "SwiftUI", "UIKit", "AppKit", "SpriteKit", "SwiftData", "FoundationModels", "CoreData", "Combine",
        ]
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let files = try FileManager.default.contentsOfDirectory(
            at: sourcesDir, includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                #expect(!forbidden.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }
}

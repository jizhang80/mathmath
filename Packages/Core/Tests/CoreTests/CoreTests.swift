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
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n") where line.hasPrefix("import ") {
                let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
                #expect(!forbidden.contains(module), "\(file.lastPathComponent) imports \(module)")
            }
        }
    }

    /// AC9: `CoreCoding.swift` is the sole site under `Sources/Core` that configures a
    /// `JSONDecoder`/`JSONEncoder` — the wire-format decode/encode recipe lives in product code,
    /// exactly once. Scans `Sources/Core` only; `Tests/CoreTests` is explicitly excluded because that
    /// tree also decodes non-wire JSON (`contracts/error-codes.json`, `ErrorRegistryTests`) and
    /// contains files owned by other EPIC-01 tasks, so scanning it would couple this task to theirs.
    @Test("only CoreCoding.swift constructs a JSONDecoder/JSONEncoder in Sources/Core (AC9)")
    func onlyCoreCodingConstructsCoders() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")

        guard let coreCodingFile = files.first(where: { $0.lastPathComponent == "CoreCoding.swift" })
        else {
            Issue.record("CoreCoding.swift not found under Sources/Core — empty scan is a FAIL")
            return
        }
        let coreCodingText = try String(contentsOf: coreCodingFile, encoding: .utf8)
        #expect(
            coreCodingText.contains("JSONDecoder(") && coreCodingText.contains("JSONEncoder("),
            "CoreCoding.swift does not contain the expected coder construction — detector cannot be trusted"
        )

        for file in files where file.lastPathComponent != "CoreCoding.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(
                !text.contains("JSONDecoder("),
                "\(file.lastPathComponent) constructs a JSONDecoder outside CoreCoding.swift")
            #expect(
                !text.contains("JSONEncoder("),
                "\(file.lastPathComponent) constructs a JSONEncoder outside CoreCoding.swift")
        }
    }
}

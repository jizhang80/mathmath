import Foundation
import Testing

@testable import Core

/// Glossary guard (`contracts/domain-glossary.md`; `tasks/arbitration/arbiter-03-audit-f1-attempt.md`):
/// no `.swift` file under `Packages/Core/Sources/Core` carries the banned word "attempt" (any case, any
/// position — identifiers, comments and string literals alike) or the retired type-name stem
/// "FailedProbe". The concept is named **Miss** ("an incorrect answer"), e.g. `ItemMiss`.
@Suite("Core glossary guard — no \"attempt\" in Core sources")
struct CoreGlossaryAttemptGuardTests {
    private static var coreSourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core")
    }

    /// The guard's rule, isolated so the negative control exercises the exact function the real scan uses.
    static func violations(in text: String) -> [String] {
        var found: [String] = []
        if text.lowercased().contains("attempt") { found.append("attempt") }
        if text.contains("FailedProbe") { found.append("FailedProbe") }
        return found
    }

    @Test("no .swift file under Packages/Core/Sources/Core contains \"attempt\" or \"FailedProbe\"")
    func coreSourcesCarryNoAttempt() throws {
        let enumerator = try #require(
            FileManager.default.enumerator(at: Self.coreSourcesDir, includingPropertiesForKeys: nil))
        var scanned = 0
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            for word in Self.violations(in: text) {
                offenders.append("\(url.lastPathComponent): \(word)")
            }
        }
        #expect(scanned > 0, "instrument broken: no .swift file under \(Self.coreSourcesDir.path)")
        #expect(offenders.isEmpty, "banned glossary word in Core sources: \(offenders)")
    }

    @Test("guard is load-bearing: the pre-rename declaration fails it (negative control)")
    func guardNegativeControl() {
        let preRename = "public struct FailedProbeAttempt: Equatable {"
        let found = Self.violations(in: preRename)
        #expect(found.contains("attempt"))
        #expect(found.contains("FailedProbe"))
        #expect(Self.violations(in: "for miss in misses {").isEmpty)
    }
}

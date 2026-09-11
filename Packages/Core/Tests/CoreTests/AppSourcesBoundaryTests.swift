import Foundation
import Testing

@testable import Core

/// I14 / I5 / I1 / I10 / D24: a rule-driven scan over App/Sources (and, for the network rule, over
/// Packages/Core/Sources/Core) that fails the build the moment the render layer crosses the Core ↔ App
/// boundary arbiter-03 § Q-F draws. `defaultRules` is a forbidden-pattern list, mirroring
/// `ImportBoundaryNegativeControlTests.forbiddenImportViolations`'s shape — not an allow-list complement —
/// so a legitimate future identifier never becomes a false positive by omission. `violations(in:rules:)`
/// takes its rule set as a parameter so EPIC 04 task 04.10 can call it with `defaultRules + doorRules`
/// without editing this file. 04.10 widens only the call allow-list (new `Rule` values / a wider
/// `forbiddenCoreTypeNames`-shaped list it constructs); it never re-adds an import exception — the one
/// exception this file defines (below) is 03.9-owned and time-boxed to before 03.12 runs.
enum AppSourcesBoundary {
    /// One boundary rule: a name for the violation message, and a predicate over a single source line.
    struct Rule: Sendable {
        let name: String
        let violates: @Sendable (String) -> Bool
    }

    /// Modules App/Sources may import. Deliberately excludes `SwiftMath`: `docs/tech-stack.md` §1 Math
    /// display row states `SwiftMath` is "imported only by the `Packages/Rendering` package", and
    /// `App/Sources` is not `Packages/Rendering`. `Rendering` is listed for the package 04.7 lands.
    static let allowedImportModules: [String] = ["SwiftUI", "Foundation", "Core", "Rendering"]

    /// Names of Core-internal types the App must never call directly — every state-changing or state-
    /// deriving path other than `MapLaunch.open` and `MapFacade`'s eight entry points (§3). Matched as whole
    /// words, so `unitExpedition`/`ExpeditionRun` do not false-positive against a bare `Expedition` rule.
    private static let forbiddenCoreTypeNames = [
        "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
        "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
    ]

    static let defaultRules: [Rule] = [
        Rule(name: "StudentState construction") { line in
            line.range(of: #"\bStudentState\s*\("#, options: .regularExpression) != nil
        },
        Rule(name: "direct Core transition/derivation call outside the façade") { line in
            for name in forbiddenCoreTypeNames {
                if line.range(of: "\\b\(name)\\b", options: .regularExpression) != nil { return true }
            }
            return line.range(of: #"MapViewModel\.derive\("#, options: .regularExpression) != nil
        },
        Rule(name: "read of a data/ path") { line in
            line.range(of: #""data/"#, options: .regularExpression) != nil
        },
        networkRule,
        Rule(name: "non-allow-listed import") { line in
            guard line.hasPrefix("import ") else { return false }
            let module = line.dropFirst("import ".count).trimmingCharacters(in: .whitespaces)
            return !allowedImportModules.contains(String(module))
        },
        Rule(name: "free-text answer / OCR / item-check path") { line in
            if line.range(of: #"\bItemChecker\b"#, options: .regularExpression) != nil { return true }
            return line.range(of: #"TextField\s*\([^)]*[Aa]nswer"#, options: .regularExpression) != nil
        },
    ]

    /// Isolated as its own named rule (not just a `defaultRules` entry) because AC2 runs it alone against
    /// `Packages/Core/Sources/Core` — a tree the other rules (StudentState construction, façade calls, the
    /// import allow-list) do not apply to, since Core legitimately contains all of those symbols.
    static let networkRule = Rule(name: "URLSession or URLRequest") { line in
        line.range(of: #"\bURLSession\b|\bURLRequest\b"#, options: .regularExpression) != nil
    }

    /// Recursively scans `root` for `.swift` files only — `.json` payloads (e.g. `App/Sources/DemoSnapshot`'s
    /// copy of `data/demo`) are excluded by the `pathExtension == "swift"` filter before any rule runs
    /// (AC5). Empty scan (zero `.swift` files found) is a FAIL, matching `CoreTests.swift`'s and
    /// `ImportBoundaryNegativeControlTests.swift`'s existing rule for this scan shape.
    static func violations(in root: URL, rules: [Rule] = defaultRules) throws -> [String] {
        let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no .swift source files found under \(root.path) — empty scan is a FAIL")
        var violations: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let lineText = String(line)
                for rule in rules where rule.violates(lineText) {
                    violations.append("\(file.lastPathComponent): \(rule.name)")
                }
            }
        }
        return violations
    }
}

@Suite("App/Sources boundary (I14 / I5 / I1 / I10 / D24, 03.9)")
struct AppSourcesBoundaryTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    @Test("App/Sources has no I14/I5/I1/I10/D24 boundary violations")
    func appSourcesIsClean() throws {
        let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
        let violations = try AppSourcesBoundary.violations(in: appSources)
        #expect(violations.isEmpty, "App/Sources boundary violations: \(violations)")
    }

    @Test("Packages/Core/Sources has no URLSession or URLRequest (I5)")
    func coreSourcesHasNoNetworkCode() throws {
        let coreSources = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core")
        let violations = try AppSourcesBoundary.violations(
            in: coreSources, rules: [AppSourcesBoundary.networkRule])
        #expect(violations.isEmpty, "Core network-code violations: \(violations)")
    }

    // AC6: the rule set is data-driven — a caller-supplied rule array is honored without editing the walk.
    @Test("violations(in:rules:) honors a caller-supplied rule set distinct from defaultRules")
    func customRuleSetIsHonored() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        try "import Foundation\nlet x = ExpeditionRunViewFutureDoorThing()\n"
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let customRule = AppSourcesBoundary.Rule(name: "planted future-door marker") { line in
            line.contains("ExpeditionRunViewFutureDoorThing")
        }
        let violations = try AppSourcesBoundary.violations(in: tempRoot, rules: [customRule])
        #expect(violations.contains { $0.contains("planted future-door marker") })
    }

    // 04.10 AC1: the extended Door rule set (defaultRules + doorRules) is clean over the real App/Sources
    // tree, and doorCopyRule (run alone, since it applies only to Door student-facing copy) is clean over
    // App/Sources/Doors.
    @Test("App/Sources has no I1/I2/I10/I14 Door boundary violations (04.10)")
    func appSourcesIsCleanWithDoorRules() throws {
        let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
        let violations = try AppSourcesBoundary.violations(
            in: appSources, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
        #expect(violations.isEmpty, "Door boundary violations: \(violations)")
        let copyViolations = try AppSourcesBoundary.violations(
            in: appSources.appendingPathComponent("Doors"), rules: [AppSourcesBoundary.doorCopyRule])
        #expect(copyViolations.isEmpty, "Door copy literal violations: \(copyViolations)")
    }

    // AC8: the façade's own call surface must never false-positive against the forbidden-call rule, and
    // genuine Core-internal calls in the same tree must still be caught.
    @Test(
        "façade calls and panel-content access are not false positives; Expedition-internal calls still are")
    func facadeCallsAreNotFalsePositives() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try """
        import Foundation
        import Core
        struct Clean {
            func go(facade: MapFacade, id: NodeID) {
                let outcome = facade.unitExpedition(node: id)
                _ = facade.checkHere(node: id)
                let content = facade.nodePanelContent(for: id)
                let title = content.title
            }
        }
        """
        .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)

        let cleanViolations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(cleanViolations.isEmpty, "façade-only calls falsely flagged: \(cleanViolations)")

        try """
        import Foundation
        import Core
        struct Planted {
            func bad() {
                Expedition.compose(items: [])
                ExpeditionRun.resume()
            }
        }
        """
        .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("direct Core transition/derivation call outside the façade")
            })
    }
}

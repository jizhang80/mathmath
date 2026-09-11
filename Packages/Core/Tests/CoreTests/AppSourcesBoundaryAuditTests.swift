import Foundation
import Testing

@testable import Core

/// Second-pair-of-eyes audit for `AppSourcesBoundary` (task 03.9, `AppSourcesBoundaryTests.swift` /
/// `AppSourcesBoundaryNegativeControlTests.swift`). Closes coverage gaps the implementer's own suite left
/// open: most of `forbiddenCoreTypeNames` (§4.2) are never independently exercised by a negative control
/// (only `MarkerTrail`, `MapViewModel.derive`, `Expedition`, `ExpeditionRun` are), the `URLRequest` half of
/// the network rule's alternation is untested, the SwiftMath exception's exact-line scoping (not just
/// exact-path scoping) is untested, only one non-Swift extension (`.json`) proves the extension filter, and
/// no test independently proves the real `App/Sources` walk is non-vacuous beyond the helper's own internal
/// `#expect(!files.isEmpty)` guard (I14, `docs/domains/map.md:131-132`).
@Suite("App/Sources boundary: tester audit (I14 / I5 / I1 / I10 / D24)")
struct AppSourcesBoundaryAuditTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    // MARK: - Non-vacuous real-tree walk (I14: "a test asserts the import boundary" must actually inspect files)

    /// A scan whose helper silently found zero files could still report `violations.isEmpty` (vacuously
    /// true) and pass AC1 for the wrong reason. This test independently re-derives the file list (using the
    /// same enumeration approach the precedent tests use) and asserts the real `App/Sources` walk actually
    /// reaches the two known top-level files, so the AC1 pass is not vacuous.
    @Test("the real App/Sources scan is not vacuous: it reaches a nonzero, known set of .swift files")
    func realAppSourcesWalkIsNotVacuous() throws {
        let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
        let enumerator = FileManager.default.enumerator(
            at: appSources, includingPropertiesForKeys: [.isDirectoryKey])
        var names: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                names.append(url.lastPathComponent)
            }
        }
        #expect(
            names.count >= 2, "expected at least MathmathApp.swift and ContentView.swift, found: \(names)")
        #expect(names.contains("MathmathApp.swift"), "walk did not reach MathmathApp.swift: \(names)")
        #expect(names.contains("ContentView.swift"), "walk did not reach ContentView.swift: \(names)")
    }

    // MARK: - Full forbidden-Core-type-name coverage (rule 2)

    /// `forbiddenCoreTypeNames` lists ten names; the implementer's negative controls exercise only
    /// `MarkerTrail` (+ `MapViewModel.derive` separately) and `Expedition`/`ExpeditionRun` (via the AC8
    /// façade test). A typo or bad escape in any of the other six entries would go undetected by the
    /// shipped suite. This proves each of the remaining names is independently caught.
    @Test(
        "catches every remaining forbidden Core-internal type name, one per fixture",
        arguments: [
            "DiagnosisRun", "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
            "MasteryTransitions",
        ])
    func catchesEachRemainingForbiddenCoreTypeName(_ name: String) throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nimport Core\nlet x = \(name).someCall()\n"
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("direct Core transition/derivation call outside the façade")
            },
            "forbidden name \(name) was not caught: \(violations)")
    }

    /// `StudentStateStore` sits in both the exclusion list (rule 2, "direct call") and shares a prefix with
    /// rule 1's `StudentState(` construction pattern. Proves `StudentStateStore.read(...)` is caught by
    /// rule 2 and is NOT double-reported (or mis-reported) as "StudentState construction" — the two rules'
    /// patterns must not collide on the shared prefix.
    @Test(
        "StudentStateStore.read( is reported as a direct-call violation, never as StudentState construction")
    func studentStateStoreDoesNotCollideWithStudentStateConstruction() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nlet s = StudentStateStore.read(from: url)\n"
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0 == "Planted.swift: direct Core transition/derivation call outside the façade"
            },
            "StudentStateStore call not reported as a direct-call violation: \(violations)")
        #expect(
            !violations.contains { $0 == "Planted.swift: StudentState construction" },
            "StudentStateStore.read( was wrongly also flagged as StudentState( construction: \(violations)")
    }

    // MARK: - URLRequest half of the network rule (rule 4's alternation is untested for its second branch)

    @Test("catches URLRequest usage independently of URLSession")
    func catchesURLRequest() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nlet r = URLRequest(url: someURL)\n"
            .write(to: tempRoot.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("URLSession or URLRequest") },
            "URLRequest not caught: \(violations)")
    }

    @Test(
        "the network rule alone also catches URLRequest in Packages/Core/Sources/Core's real tree (I5, AC2)")
    func coreSourcesHasNoURLRequestEither() throws {
        let coreSources = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core")
        let violations = try AppSourcesBoundary.violations(
            in: coreSources, rules: [AppSourcesBoundary.networkRule])
        #expect(violations.isEmpty, "Core network-code violations (URLSession/URLRequest): \(violations)")
    }

    // MARK: - SwiftMath exception is exact-line-scoped, not just exact-path-scoped

    /// The exception's skip block requires the trimmed line to equal exactly `"import SwiftMath"`. A
    /// trailing comment or extra token on the same import line must NOT be silently exempted — proving the
    /// carve-out is as narrow as §4.2 documents (a single exact line, not "any SwiftMath reference in
    /// ContentView.swift").
    @Test("a modified import SwiftMath line (trailing comment) in the exempt file is still caught")
    func modifiedSwiftMathImportLineInContentViewIsNotExempt() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try """
        import SwiftMath // TODO: remove in 03.12
        import SwiftUI
        struct ContentView: View { var body: some View { Text("") } }
        """
        .write(to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("ContentView.swift") && $0.contains("non-allow-listed import")
            },
            "a modified import SwiftMath line was wrongly exempted by the exact-path carve-out: \(violations)"
        )
    }

    // MARK: - Non-Swift file filtering beyond .json

    @Test("a planted violation inside a .plist file is not reported — filter is not json-specific")
    func plistFilesAreSkipped() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "<plist><string>StudentState(schemaVersion: 2) URLSession URLRequest data/demo</string></plist>"
            .write(to: tempRoot.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, ".plist payload text leaked into the Swift-source scan: \(violations)")
    }

    // MARK: - Determinism (the enumerator's traversal order is not contractually sorted)

    /// `FileManager.default.enumerator` does not guarantee a stable file order; two independent scans of
    /// the same tree must still report the same *set* of violations, so a later task relying on this scan
    /// as a build gate never sees a flaky pass/fail depending on traversal order.
    @Test("repeated scans of the same real App/Sources tree report the identical violation set")
    func repeatedScansAreDeterministic() throws {
        let appSources = Self.repoRoot.appendingPathComponent("App/Sources")
        let first = try AppSourcesBoundary.violations(in: appSources)
        let second = try AppSourcesBoundary.violations(in: appSources)
        #expect(Set(first) == Set(second), "repeated scans of the same tree disagree: \(first) vs \(second)")
    }
}

import Foundation
import Testing

@testable import Core

/// I14 / I5 / I1 / I10 / D24: negative controls for `AppSourcesBoundary.violations(in:rules:)`
/// (`AppSourcesBoundaryTests.swift`). One `@Test` per violation class, each over its own `UUID()`-named
/// temp fixture tree, planting exactly one violation shape and asserting only on that class's name
/// substring. Mirrors the shape of `ImportBoundaryNegativeControlTests.swift`.
@Suite("App/Sources boundary: negative control (I14 / I5 / I1 / I10 / D24)")
struct AppSourcesBoundaryNegativeControlTests {
    @Test("catches StudentState( construction planted inside a nested subdirectory")
    func catchesStudentStateConstruction() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nimport Core\nlet s = StudentState(schemaVersion: 2)\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("StudentState construction") })
    }

    @Test("catches a direct MarkerTrail call and a direct MapViewModel.derive call")
    func catchesDirectCoreTransitionOrDerivationCalls() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try """
        import Foundation
        import Core
        struct Planted {
            func bad() {
                MarkerTrail.setMarker(courseCode: "MCV4U", unitId: 1)
                let vm = MapViewModel.derive(state: nil)
            }
        }
        """
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("direct Core transition/derivation call outside the façade")
            })
    }

    @Test("catches a data/ path literal")
    func catchesDataPathLiteral() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try """
        import Foundation
        struct Planted {
            let url = Bundle.main.url(forResource: "data/demo/courses", withExtension: "json")
        }
        """
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.contains { $0.contains("Planted.swift") && $0.contains("read of a data/ path") })
    }

    @Test("catches URLSession usage")
    func catchesURLSession() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nstruct Planted {\n    let s = URLSession.shared\n}\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("URLSession or URLRequest") })
    }

    @Test("catches a non-allow-listed import (Vision)")
    func catchesNonAllowListedImport() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Vision\nstruct Planted {}\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("non-allow-listed import") })
    }

    @Test("catches an ItemChecker call and a TextField bound to an answer-named value")
    func catchesFreeTextAnswerOrItemCheckPaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try """
        import Foundation
        import SwiftUI
        import Core
        struct Planted: View {
            @State var answerText = ""
            var body: some View {
                TextField("Your answer", text: $answerText)
            }
            func check() {
                ItemChecker.check(answer: answerText)
            }
        }
        """
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains {
                $0.contains("Planted.swift") && $0.contains("free-text answer / OCR / item-check path")
            })
    }

    @Test("reports no violations on a clean fixture tree shaped like App/Sources")
    func cleanFixtureTreeIsClean() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nimport SwiftUI\nstruct App1 {}\n"
            .write(
                to: tempRoot.appendingPathComponent("MathmathApp.swift"), atomically: true, encoding: .utf8)
        try "import SwiftUI\nimport Core\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
            .write(to: nested.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, "clean fixture tree unexpectedly reported violations: \(violations)")
    }

    @Test("a planted violation inside a .json file is not reported — the scan is Swift-source only")
    func jsonFilesAreSkipped() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let snapshot = tempRoot.appendingPathComponent("DemoSnapshot")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "{\"note\": \"StudentState(schemaVersion: 2) URLSession data/demo\"}"
            .write(to: snapshot.appendingPathComponent("courses.json"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(violations.isEmpty, "JSON payload text leaked into the Swift-source scan: \(violations)")
    }

    // AC7 (a): the SwiftMath exception is not a module-wide re-admission. Empty=FAIL.
    @Test("catches import SwiftMath planted in a top-level file other than ContentView.swift")
    func catchesSwiftMathImportOutsideException() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import SwiftMath\nimport SwiftUI\nstruct MathView: View { var body: some View { Text(\"\") } }\n"
            .write(to: tempRoot.appendingPathComponent("MathView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0.contains("MathView.swift") && $0.contains("non-allow-listed import") })
    }

    // AC7 (b): the exception is path-scoped, not file-name-scoped — a nested ContentView.swift is NOT exempt.
    // Empty=FAIL for both assertions.
    @Test("catches import SwiftMath planted in a nested Views/ContentView.swift")
    func catchesSwiftMathImportInNestedContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Views")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let body =
            "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
        try body.write(
            to: nested.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        // Nested file alone: its import SwiftMath is reported.
        let nestedOnly = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            nestedOnly.filter { $0 == "ContentView.swift: non-allow-listed import" }.count == 1,
            "nested Views/ContentView.swift was wrongly exempted: \(nestedOnly)")

        // Add the exempt top-level ContentView.swift beside it: still exactly one report — the nested one.
        try body.write(
            to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
        let both = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            both.filter { $0 == "ContentView.swift: non-allow-listed import" }.count == 1,
            "expected exactly one SwiftMath report (the nested file), got: \(both)")
    }

    // AC7 (c): positive case — the exact top-level path is exempt. Empty=PASS.
    @Test("does not flag import SwiftMath inside the top-level ContentView.swift of the scanned root")
    func exemptsSwiftMathInsideTopLevelContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try
            "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
            .write(
                to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.isEmpty,
            "the top-level ContentView.swift SwiftMath exception did not apply: \(violations)")
    }
}

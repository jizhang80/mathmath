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

    // Once 03.12 removed the exception, a nested ContentView.swift is caught (never was exempt), and — since
    // no carve-out survives anywhere — a top-level ContentView.swift now next to it is caught too.
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

        // Add a top-level ContentView.swift beside it: now both are reported — no carve-out remains anywhere.
        try body.write(
            to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)
        let both = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            both.filter { $0 == "ContentView.swift: non-allow-listed import" }.count == 2,
            "expected both the nested and top-level SwiftMath imports to be reported, got: \(both)")
    }

    // 03.12 removed the time-boxed exception once ContentView.swift no longer imports SwiftMath. This test
    // proves the removal actually re-enables detection at the exact path the exception used to cover.
    @Test("catches import SwiftMath now that the top-level ContentView.swift exception is gone")
    func catchesSwiftMathImportInTopLevelContentView() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let body =
            "import SwiftMath\nimport SwiftUI\nstruct ContentView: View { var body: some View { Text(\"\") } }\n"
        try body.write(
            to: tempRoot.appendingPathComponent("ContentView.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(in: tempRoot)
        #expect(
            violations.contains { $0 == "ContentView.swift: non-allow-listed import" },
            "the top-level ContentView.swift exception should be gone after 03.12 — got: \(violations)")
    }

    // 04.10 AC2: doorRules catches an answer/correct_choice_id comparison planted in a nested subdirectory.
    @Test("doorRules catches an answer/correct_choice_id comparison planted in a nested subdirectory")
    func catchesAnswerComparison() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Doors")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nimport Core\nlet ok = submitted == item.correct_choice_id\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(
            in: tempRoot, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("answer / correct_choice_id comparison outside CAS")
            })
    }

    // 04.10 AC2: doorRules catches a TextEditor bound to an answer-named value.
    @Test("doorRules catches a TextEditor bound to an answer-named value")
    func catchesTextEditorBoundToAnswer() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Doors")
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
                TextEditor("Your answer", text: $answerText)
            }
        }
        """
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(
            in: tempRoot, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("free-text entry (TextField/TextEditor) bound to an answer-named value")
            })
    }

    // 04.10 AC1/AC2: doorCopyRule catches a 4+-word inline Door copy literal, and does not flag the real
    // Door chrome literals (1-3 words), proving the clean-fixture side of AC1.
    @Test("doorCopyRule catches a 4+-word inline Text/Button literal but not short chrome literals")
    func catchesDoorCopyLiteralButNotChrome() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Doors")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try """
        import SwiftUI
        struct Planted: View {
            var body: some View {
                Text("Hard-coded error message here")
            }
        }
        """
        .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(
            in: nested, rules: [AppSourcesBoundary.doorCopyRule])
        #expect(
            violations.contains {
                $0.contains("Planted.swift")
                    && $0.contains("Door student-facing copy as an inline string literal (4+ words)")
            })

        let chromeRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let chromeNested = chromeRoot.appendingPathComponent("Doors")
        try FileManager.default.createDirectory(at: chromeNested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: chromeRoot) }

        try """
        import SwiftUI
        struct Chrome: View {
            var body: some View {
                Text("Continue")
                Button("Check me here") { }
            }
        }
        """
        .write(to: chromeNested.appendingPathComponent("Chrome.swift"), atomically: true, encoding: .utf8)

        let chromeViolations = try AppSourcesBoundary.violations(
            in: chromeNested, rules: [AppSourcesBoundary.doorCopyRule])
        #expect(chromeViolations.isEmpty, "short chrome literals were wrongly flagged: \(chromeViolations)")
    }

    // 04.10 AC3: import FoundationModels is caught by the existing, unmodified non-allow-listed-import rule.
    @Test("import FoundationModels is caught by the existing non-allow-listed import rule")
    func catchesFoundationModelsImport() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Doors")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import FoundationModels\nstruct Planted {}\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(
            in: tempRoot, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("non-allow-listed import") })
    }

    // 04.10 AC4: import PencilKit is caught by the same existing rule.
    @Test("import PencilKit is caught by the existing non-allow-listed import rule")
    func catchesPencilKitImport() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = tempRoot.appendingPathComponent("Doors")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try "import Foundation\nimport Core\nstruct Clean {}\n"
            .write(to: tempRoot.appendingPathComponent("Clean.swift"), atomically: true, encoding: .utf8)
        try "import PencilKit\nstruct Planted {}\n"
            .write(to: nested.appendingPathComponent("Planted.swift"), atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.violations(
            in: tempRoot, rules: AppSourcesBoundary.defaultRules + AppSourcesBoundary.doorRules)
        #expect(
            violations.contains { $0.contains("Planted.swift") && $0.contains("non-allow-listed import") })
    }

    // 04.10 AC8 (i): a function whose body contains two DoorFacade.* calls.
    @Test("doorButtonActionViolations catches a function with two DoorFacade calls")
    func catchesTwoDoorFacadeCallsInOneFunction() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        struct Planted {
            func bad() {
                _ = DoorFacade.startExpedition(mapState: mapState, today: today)
                _ = DoorFacade.startAnother(mapState: mapState, today: today)
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["startExpedition", "startAnother"])
        #expect(violations.contains { $0.contains("more than one DoorFacade call") })
    }

    // 04.10 AC8 (ii): a function mixing a DoorFacade call with a forbidden Core-internal call.
    @Test("doorButtonActionViolations catches a DoorFacade call mixed with a forbidden Core-internal call")
    func catchesDoorFacadeMixedWithForbiddenCall() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        struct Planted {
            func bad() {
                let ok = ItemChecker.check(answer: submitted)
                _ = DoorFacade.answer(runState, submitted: submitted, today: today)
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["answer"])
        #expect(violations.contains { $0.contains("mixed with a forbidden Core-internal call") })
    }

    // 04.10 AC8 (iii): a function calling a DoorFacade member outside the permitted set.
    @Test("doorButtonActionViolations catches a DoorFacade call outside the permitted entry set")
    func catchesDoorFacadeCallOutsidePermittedSet() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        struct Planted {
            func bad() {
                _ = DoorFacade.doesNotExist(mapState: mapState, today: today)
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["startExpedition", "answer"])
        #expect(violations.contains { $0.contains("outside the permitted entry set") })
    }

    // 04.10 AC9: a fixture tree with zero DoorFacade calls fails the helper's own empty-match #expect,
    // rather than silently returning an empty violations list.
    @Test("doorButtonActionViolations fails its own empty-match guard when no DoorFacade call exists")
    func emptyMatchOverDoorButtonsIsAFail() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Empty.swift")
        try "import Core\nstruct Empty {\n    func bad() {\n        let x = 1\n    }\n}\n"
            .write(to: fixture, atomically: true, encoding: .utf8)

        withKnownIssue("no DoorFacade call found — the helper's own empty-match #expect must fail") {
            _ = try AppSourcesBoundary.doorButtonActionViolations(in: [fixture], permittedEntryNames: [])
        }
    }
}

import Foundation
import Testing

@testable import Core

/// Tester-added coverage for task `04.10` (`tasks/epic-04-task-10-app-sources-door-scan.md`), filling three
/// gaps left by the implementer's commit `688b421`: the C3 helper-routed exclusion (documented, not silently
/// left uncovered), a drift guard on the byte-identical `forbiddenCoreTypeNames` / `doorForbiddenCoreTypeNames`
/// copies (§6 note: the product-tier `private` access level is never widened by a test), and the
/// computed-`var` extension the implementer made to `functionBodies` (deviation 1 of the implementer's report).
/// Test-file only — no product code is touched.
@Suite("App/Sources boundary: Door rules — tester gap coverage (04.10)")
struct DoorAppSourcesBoundaryGapTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    // MARK: - Gap 1: the documented C3 limitation — a helper-routed façade call is NOT detected

    /// C3, quoted verbatim from `tasks/epic-04-task-10-app-sources-door-scan.md:398` (the button-call-shape
    /// helper's own doc comment): "this is exactly what \"the scan proves call shape, not tap execution\" (C3)
    /// means in code: it cannot and does not prove a `Button`'s own trailing closure reaches a `DoorFacade`
    /// call through an arbitrary number of indirections, only that the function ... actually performing the
    /// call does so exactly once, cleanly."
    ///
    /// And from the same spec's §6 default, lines 718-722: "IF a Door button's action closure calls a
    /// same-file wrapper function that itself calls no `DoorFacade` entry at all (a stub, e.g. `Button("X") {
    /// }`) THEN this task's scan does not catch that specific button in isolation — `doorButtonActionViolations`'s
    /// empty-match guard (`#expect(totalDoorFacadeCalls > 0, …)`) only catches the case where NO function
    /// across both composition files calls `DoorFacade` at all. Catching a single stubbed button among many
    /// correctly-wired ones would require tracing every `Button`'s trailing closure through an arbitrary chain
    /// of same-file function calls to prove it reaches (or fails to reach) a `DoorFacade` call — a full
    /// call-graph analysis this Core-test-tier scan does not attempt".
    ///
    /// This test proves BOTH halves of that honest exclusion, exactly:
    /// (1) a `Button`'s trailing closure that only calls a same-file helper — never `DoorFacade` directly —
    ///     produces NO violation attributable to the button's own action closure, because the scan cannot
    ///     trace across the call, so the button is invisible to the "one DoorFacade call per action" check;
    /// (2) the helper itself, which DOES contain two `DoorFacade.*` calls in its own body, is still caught by
    ///     the per-function scan — because `doorButtonActionViolations` resolves at most one level of brace
    ///     structure per function/computed-property body, and the helper's body is scanned on its own merits.
    @Test(
        "a helper-routed façade call (button -> same-file helper -> two DoorFacade calls) is not attributed to the button, but the helper's own body is still caught (C3)"
    )
    func helperRoutedFacadeCallEscapesButtonAttributionButHelperBodyIsCaught() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        // The button's own action closure calls only `doSomethingViaHelper()` — never `DoorFacade` directly.
        // The helper it routes through makes TWO DoorFacade calls in its own body.
        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        import SwiftUI
        struct Planted: View {
            var body: some View {
                Button("Do the thing") {
                    doSomethingViaHelper()
                }
            }
            func doSomethingViaHelper() {
                _ = DoorFacade.startExpedition(mapState: mapState, today: today)
                _ = DoorFacade.startAnother(mapState: mapState, today: today)
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["startExpedition", "startAnother"])

        // Half (1): no violation names the button's own `body` computed property — the scan cannot prove the
        // button's closure reaches the helper, so it is silent about the button in isolation.
        #expect(
            !violations.contains { $0.contains(":body:") },
            "the scan should not be able to attribute the helper's calls to the button's own body — got: \(violations)"
        )

        // Half (2): the helper's own body — which really does contain two DoorFacade calls — is still caught,
        // because the per-function scan looks at `doSomethingViaHelper`'s own body on its own merits.
        #expect(
            violations.contains {
                $0.contains(":doSomethingViaHelper:") && $0.contains("more than one DoorFacade call")
            },
            "the helper's own two-call body should still be caught by the per-function scan — got: \(violations)"
        )
    }

    // MARK: - Gap 2: a drift guard for the duplicated `forbiddenCoreTypeNames` list

    /// Extracts the quoted string literals inside `static let <name> = [ ... ]` (allowing an intervening
    /// `private`) from `text`. A small, test-only text scan — not a product parser.
    private static func stringArrayLiteral(named name: String, in text: String) -> [String] {
        guard
            let declRegex = try? NSRegularExpression(
                pattern: #"(?:private\s+)?static\s+let\s+\#(name)\s*=\s*\[([^\]]*)\]"#)
        else { return [] }
        let nsText = text as NSString
        guard
            let match = declRegex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
            let bodyRange = Range(match.range(at: 1), in: text)
        else { return [] }
        let body = String(text[bodyRange])
        guard let literalRegex = try? NSRegularExpression(pattern: #""([^"]*)""#) else { return [] }
        let nsBody = body as NSString
        return literalRegex.matches(in: body, range: NSRange(location: 0, length: nsBody.length)).compactMap {
            match in
            Range(match.range(at: 1), in: body).map { String(body[$0]) }
        }
    }

    /// The two lists must hold the identical set of names. `AppSourcesBoundaryTests.swift`'s
    /// `forbiddenCoreTypeNames` is `private` to that file (Swift's `private` scopes to the declaring file, not
    /// the declaring type, across files — the implementer's documented deviation 2), so
    /// `DoorAppSourcesBoundaryTests.swift` carries a byte-identical local copy, `doorForbiddenCoreTypeNames`.
    /// This test reads both files' source text directly (never widening either list's access level) and
    /// asserts the two extracted sets are equal, so a future edit to one without the other is caught here
    /// rather than silently drifting.
    @Test("forbiddenCoreTypeNames and doorForbiddenCoreTypeNames hold the identical set of names")
    func forbiddenCoreTypeNameListsMatch() throws {
        let appSourcesFile = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift")
        let doorFile = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Tests/CoreTests/DoorAppSourcesBoundaryTests.swift")
        let appNames = Self.stringArrayLiteral(
            named: "forbiddenCoreTypeNames", in: try String(contentsOf: appSourcesFile, encoding: .utf8))
        let doorNames = Self.stringArrayLiteral(
            named: "doorForbiddenCoreTypeNames", in: try String(contentsOf: doorFile, encoding: .utf8))

        #expect(
            !appNames.isEmpty, "extraction found no names in AppSourcesBoundaryTests.swift — regex drifted")
        #expect(
            !doorNames.isEmpty,
            "extraction found no names in DoorAppSourcesBoundaryTests.swift — regex drifted"
        )
        #expect(
            Set(appNames) == Set(doorNames),
            "forbiddenCoreTypeNames and doorForbiddenCoreTypeNames have drifted apart: \(appNames) vs \(doorNames)"
        )
    }

    /// Negative control for the guard above: proves the equality check the previous test relies on actually
    /// discriminates a real drift, using a mutated IN-MEMORY copy (never a product-code edit). Without this,
    /// a vacuously-true comparison (e.g. comparing a list to itself by accident) would never be shown to fail.
    @Test("the drift guard's own equality check fails against a deliberately mutated in-memory copy")
    func forbiddenCoreTypeNameDriftGuardCatchesAMutation() throws {
        let appSourcesFile = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift")
        let appNames = Self.stringArrayLiteral(
            named: "forbiddenCoreTypeNames", in: try String(contentsOf: appSourcesFile, encoding: .utf8))
        #expect(!appNames.isEmpty)

        // Reds against the broken shape: an added name the other list does not carry.
        let mutatedWithExtra = appNames + ["SomethingNotInTheDoorCopy"]
        #expect(Set(appNames) != Set(mutatedWithExtra), "the guard failed to detect an added name")

        // Reds against the broken shape: a dropped name.
        let mutatedMissingOne = Array(appNames.dropLast())
        #expect(Set(appNames) != Set(mutatedMissingOne), "the guard failed to detect a dropped name")

        // Passes on the fixed shape: an identical copy.
        #expect(Set(appNames) == Set(appNames), "the guard falsely rejected an identical copy")
    }

    // MARK: - Gap 3: the computed-`var` extension to `functionBodies`

    /// Positive: the real `CheckHereActionButton.body` (`App/Sources/MapUI/MapActionsView.swift`) is a
    /// computed `var`, not a `func`, and its single `DoorFacade.checkHere` call must be counted by the scan.
    /// Proven by scanning the real file with a permitted set that DELIBERATELY excludes `checkHere`: if the
    /// computed-`var` extension were absent, the call would be invisible and no violation would appear; since
    /// it is present, "outside the permitted entry set" must appear, attributed to `body`.
    @Test(
        "the real CheckHereActionButton.body's DoorFacade.checkHere call is counted (computed var, not func)")
    func realCheckHereActionButtonBodyIsCounted() throws {
        let file = Self.repoRoot.appendingPathComponent("App/Sources/MapUI/MapActionsView.swift")
        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [file], permittedEntryNames: ["startExpedition", "startUnitExpedition"])
        #expect(
            violations.contains { $0.contains(":body:") && $0.contains("outside the permitted entry set") },
            "CheckHereActionButton.body's DoorFacade.checkHere call was not counted — got: \(violations)")
    }

    /// Negative control: a planted computed `var` (not a `func`) holding two `DoorFacade` calls is caught,
    /// mirroring AC8(i) but for the `var` shape specifically.
    @Test("a planted computed var with two DoorFacade calls is caught")
    func plantedComputedVarWithTwoCallsIsCaught() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        import SwiftUI
        struct Planted: View {
            var body: some View {
                _ = DoorFacade.startExpedition(mapState: mapState, today: today)
                _ = DoorFacade.startAnother(mapState: mapState, today: today)
                return EmptyView()
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["startExpedition", "startAnother"])
        #expect(
            violations.contains { $0.contains(":body:") && $0.contains("more than one DoorFacade call") },
            "a computed var with two DoorFacade calls was not caught — got: \(violations)")
    }

    /// Confirms stored properties with initializers (`var x = …`, with or without a type annotation) and
    /// `@State var` are not mis-parsed as function/computed-property bodies — they carry no brace immediately
    /// reachable from the `var <name>: <type> {` pattern, so `functionBodies`'s `var` extension must not treat
    /// them as bodies, and must not let their text corrupt the brace-depth walk for the real function that
    /// follows.
    @Test("stored properties with initializers and @State var are not mis-parsed as bodies")
    func storedPropertiesAreNotMisParsedAsBodies() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fixture = tempRoot.appendingPathComponent("Planted.swift")
        try """
        import Core
        import SwiftUI
        struct Planted: View {
            @State var flag = false
            var config: String = "default"
            func good() {
                _ = DoorFacade.answer(runState, submitted: "x", today: today)
            }
        }
        """
        .write(to: fixture, atomically: true, encoding: .utf8)

        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: [fixture], permittedEntryNames: ["answer"])
        #expect(
            violations.isEmpty,
            "stored properties with initializers were mis-parsed as bodies, producing false positives: \(violations)"
        )
    }
}

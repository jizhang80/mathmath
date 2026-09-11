import Foundation
import Testing

@testable import Core

/// Door-specific violation classes (04.10), composed as `defaultRules + doorRules` — 03.9's own extensibility
/// contract (AC6). Adds no import exception and no `allowedImportModules` widening: `DoorFacade` is reached via
/// `import Core`, already allow-listed (§6 default 2). Three of the six lettered violation classes in this
/// task's dispatch scope — Vision/VisionKit/PencilKit import, FoundationModels import, direct
/// ExpeditionRun/DiagnosisRun/Expedition calls — are already caught by `defaultRules`' "non-allow-listed
/// import" and "direct Core transition/derivation call outside the façade" rules; they get dedicated negative
/// controls (`AppSourcesBoundaryNegativeControlTests.swift`) but no new `Rule` value here, since a duplicate
/// rule would be dead code.
extension AppSourcesBoundary {
    static let doorRules: [Rule] = [
        Rule(name: "answer / correct_choice_id comparison outside CAS") { line in
            line.range(
                of:
                    #"(==|!=)\s*\w*\.?(answer|correct_choice_id|correctChoiceId)\b|\b(answer|correct_choice_id|correctChoiceId)\b\s*(==|!=)"#,
                options: .regularExpression) != nil
        },
        Rule(name: "free-text entry (TextField/TextEditor) bound to an answer-named value") { line in
            line.range(of: #"(TextField|TextEditor)\s*\([^)]*[Aa]nswer"#, options: .regularExpression) != nil
        },
    ]

    /// Isolated as its own named rule (03.9's `networkRule` precedent) because it runs alone against
    /// `App/Sources/Doors`, the Door view files: EPIC 03's map chrome outside that directory legitimately
    /// carries 4+-token literals ("Include in my next expedition", "Past the last unit", "% cleared").
    static let doorCopyRule = Rule(name: "Door student-facing copy as an inline string literal (4+ words)") {
        line in
        doorCopyLiteralWordCount(in: line) >= 4
    }

    /// Counts whitespace-delimited words inside a `Text("...")`/`Button("...")` string literal on this line.
    /// Every chrome literal in `App/Sources/Doors` after 04.8/04.9 ("Continue", "Submit", "Yes", "Not now") is
    /// 1–2 words; a planted sentence-shaped literal (4+ words) is the class this rule exists to catch —
    /// student-facing prose must come from a `Core`-computed value, never be authored inline in `App/Sources`
    /// (I6's spirit, applied to Door copy specifically).
    private static func doorCopyLiteralWordCount(in line: String) -> Int {
        guard
            let regex = try? NSRegularExpression(pattern: #"(Text|Button)\(\s*"([^"]*)""#),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let literalRange = Range(match.range(at: 2), in: line)
        else { return 0 }
        return String(line[literalRange]).split(separator: " ").filter { !$0.isEmpty }.count
    }
}

extension AppSourcesBoundary {
    /// A local copy of 03.9's `forbiddenCoreTypeNames` (that array is `private` to
    /// `AppSourcesBoundaryTests.swift`, so it is not visible to this file's extension — Swift's `private`
    /// scopes access to the declaring file, not the declaring type, across files). Kept byte-identical to the
    /// source list so the two never drift silently.
    private static let doorForbiddenCoreTypeNames = [
        "MasteryTransitions", "MarkerTrail", "Expedition", "ExpeditionRun", "DiagnosisRun",
        "L0Checker", "BundleIO", "BundleLoader", "StudentStateStore", "LayoutEngine",
    ]

    /// I14 rule (f): every Door composition function that calls `DoorFacade` calls exactly one permitted entry,
    /// never mixed with a forbidden Core-internal call. Scoped to the two files that own every direct
    /// `DoorFacade.*` call site in `App/Sources` — `AppShell.swift`'s `DoorBRunScreen` action functions and
    /// `MapActionsView.swift`'s action-button `start()` methods and `CheckHereActionButton`'s `body`.
    /// Resolves at most one level of Swift's own brace structure (a function body or a computed `var` body),
    /// never a cross-function call-graph trace — this is exactly what "the scan proves call shape, not tap
    /// execution" (C3) means in code: it cannot and does not prove a `Button`'s own trailing closure reaches a
    /// `DoorFacade` call through an arbitrary number of indirections, only that the function or computed
    /// property body actually performing the call does so exactly once, cleanly.
    static func doorButtonActionViolations(
        in files: [URL], permittedEntryNames: Set<String>
    ) throws -> [String] {
        var violations: [String] = []
        var totalDoorFacadeCalls = 0
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (name, body) in functionBodies(in: text) {
                let calls = doorFacadeCallNames(in: body)
                totalDoorFacadeCalls += calls.count
                guard !calls.isEmpty else { continue }
                if calls.count > 1 {
                    violations.append("\(file.lastPathComponent):\(name): more than one DoorFacade call")
                }
                if calls.contains(where: { !permittedEntryNames.contains($0) }) {
                    violations.append(
                        "\(file.lastPathComponent):\(name): DoorFacade call outside the permitted entry set")
                }
                let forbiddenNames = doorForbiddenCoreTypeNames + ["ItemChecker"]
                if forbiddenNames.contains(where: {
                    body.range(of: "\\b\($0)\\b", options: .regularExpression) != nil
                }) {
                    violations.append(
                        "\(file.lastPathComponent):\(name): DoorFacade call mixed with a forbidden Core-internal call"
                    )
                }
            }
        }
        #expect(
            totalDoorFacadeCalls > 0,
            "no DoorFacade call found across the Door composition files — empty match over Door buttons is a FAIL"
        )
        return violations
    }

    /// Extracts every `func <name>(...) { <body> }` AND every `var <name>: <Type> { <body> }` computed
    /// property in `text`, matching the opening brace and counting brace depth to the matching close. A
    /// textual heuristic, not a Swift parser (consistent with 03.9's own per-line, non-AST precedent). The
    /// `var` pattern is required because `CheckHereActionButton` calls `DoorFacade.checkHere` directly inside
    /// its `Button` trailing closure inside a computed `body`, with no wrapping `func` at all — without it,
    /// that call site (and its `#expect(totalDoorFacadeCalls > 0, …)` contribution) would be invisible to this
    /// scan.
    private static func functionBodies(in text: String) -> [(name: String, body: String)] {
        let patterns = [
            #"func\s+(\w+)\s*\([^)]*\)[^{]*\{"#,
            #"var\s+(\w+)\s*:[^{;=\n]*\{"#,
        ]
        let nsText = text as NSString
        let chars = Array(text)
        var results: [(String, String)] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                let openBrace = match.range.location + match.range.length - 1
                var depth = 1
                var i = openBrace + 1
                while i < chars.count, depth > 0 {
                    if chars[i] == "{" { depth += 1 }
                    if chars[i] == "}" { depth -= 1 }
                    i += 1
                }
                let bodyRange = NSRange(location: openBrace + 1, length: max(0, i - 1 - (openBrace + 1)))
                results.append((String(text[nameRange]), nsText.substring(with: bodyRange)))
            }
        }
        return results
    }

    private static func doorFacadeCallNames(in body: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bDoorFacade\.(\w+)\("#) else { return [] }
        let nsBody = body as NSString
        return regex.matches(in: body, range: NSRange(location: 0, length: nsBody.length)).compactMap {
            match in
            Range(match.range(at: 1), in: body).map { String(body[$0]) }
        }
    }
}

extension AppSourcesBoundary {
    /// AC5: every `DoorFacade.<name>(` call site appearing anywhere in `text`. Applied to the real
    /// `DoorFacadeSeamTests.swift` source, this is a drift detector on 04.5's own C1 seam-test coverage — it is
    /// NOT the permitted-entry allowlist `doorButtonActionViolations` validates against (§6 default 1).
    static func doorFacadeEntryNames(fromSeamTestSource text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\bDoorFacade\.(\w+)\("#) else { return [] }
        let nsText = text as NSString
        return Set(
            regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
                Range(match.range(at: 1), in: text).map { String(text[$0]) }
            })
    }

    /// AC6: every `public static func <name>(` declared inside `DoorFacade`'s base `enum` or an `extension
    /// DoorFacade { }` block in `text`. Applied to the real `MapLaunch.swift` source, this is the registry
    /// `doorButtonActionViolations` uses as its permitted-entry set — derived from `Core`'s own source, never
    /// hand-maintained (guards against a legitimate future 13th entry being rejected by a stale literal list).
    static func doorFacadePublicEntryNames(fromMapLaunchSource text: String) -> Set<String> {
        var names: Set<String> = []
        for pattern in [#"enum\s+DoorFacade\s*\{"#, #"extension\s+DoorFacade\s*\{"#] {
            guard let blockRegex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsText = text as NSString
            for match in blockRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let openBrace = match.range.location + match.range.length - 1
                let chars = Array(text)
                var depth = 1
                var i = openBrace + 1
                while i < chars.count, depth > 0 {
                    if chars[i] == "{" { depth += 1 }
                    if chars[i] == "}" { depth -= 1 }
                    i += 1
                }
                let blockRange = NSRange(location: openBrace + 1, length: max(0, i - 1 - (openBrace + 1)))
                let block = nsText.substring(with: blockRange)
                guard
                    let funcRegex = try? NSRegularExpression(pattern: #"public\s+static\s+func\s+(\w+)\s*\("#)
                else { continue }
                let nsBlock = block as NSString
                for funcMatch in funcRegex.matches(
                    in: block, range: NSRange(location: 0, length: nsBlock.length))
                {
                    if let nameRange = Range(funcMatch.range(at: 1), in: block) {
                        names.insert(String(block[nameRange]))
                    }
                }
            }
        }
        return names
    }
}

@Suite("App/Sources boundary: Door rules (04.10)")
struct DoorAppSourcesBoundaryTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    @Test("real DoorFacadeSeamTests.swift calls exactly the eight entries its own C1 sequences name")
    func seamTestEntryNamesMatchExpected() throws {
        let file = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        let derived = AppSourcesBoundary.doorFacadeEntryNames(fromSeamTestSource: text)
        let expected: Set<String> = [
            "startExpedition", "answer", "continueAfterAnswer", "decideProbe", "answerProbeItem",
            "continueAfterProbeAnswer", "resumeAfterDiagnosis", "checkHere",
        ]
        #expect(derived == expected, "DoorFacadeSeamTests.swift's own call set drifted: \(derived)")
    }

    @Test("MapLaunch.swift's public DoorFacade surface is exactly the twelve 04.5 entries")
    func doorFacadePublicSurfaceMatchesExpected() throws {
        let file = Self.repoRoot.appendingPathComponent("Packages/Core/Sources/Core/Platform/MapLaunch.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        let derived = AppSourcesBoundary.doorFacadePublicEntryNames(fromMapLaunchSource: text)
        let expected: Set<String> = [
            "startExpedition", "startUnitExpedition", "answer", "continueAfterAnswer", "resumeAfterDiagnosis",
            "startAnother", "backToMap", "checkHere", "decideProbe", "answerProbeItem",
            "continueAfterProbeAnswer", "decideFurtherLevel",
        ]
        #expect(derived == expected, "DoorFacade's public surface drifted from the expected 12: \(derived)")
    }

    @Test("Door button/composition functions call exactly one permitted DoorFacade entry each")
    func doorButtonActionsAreClean() throws {
        let mapLaunch = Self.repoRoot.appendingPathComponent(
            "Packages/Core/Sources/Core/Platform/MapLaunch.swift")
        let permitted = AppSourcesBoundary.doorFacadePublicEntryNames(
            fromMapLaunchSource: try String(contentsOf: mapLaunch, encoding: .utf8))
        let files = [
            Self.repoRoot.appendingPathComponent("App/Sources/Shell/AppShell.swift"),
            Self.repoRoot.appendingPathComponent("App/Sources/MapUI/MapActionsView.swift"),
        ]
        let violations = try AppSourcesBoundary.doorButtonActionViolations(
            in: files, permittedEntryNames: permitted)
        #expect(violations.isEmpty, "Door button/composition call-shape violations: \(violations)")
    }
}

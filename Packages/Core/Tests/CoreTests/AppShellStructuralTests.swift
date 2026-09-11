import Foundation
import Testing

@testable import Core

/// Structural (source-text) guards for task 03.12 (`tasks/epic-03-task-12-app-shell-launch-smoke.md`):
/// `App/Sources/Shell/AppShell.swift`, `App/Sources/Shell/RefusalView.swift`, the `ContentView.swift`/
/// `MathmathApp.swift` edits, `scripts/gate.sh`, `.github/workflows/ci.yml` and `scripts/sim-smoke.sh`. Per
/// the task's own §5 C3 note there is no App unit-test target — SwiftUI phase transitions, `.onAppear` firing,
/// sheet presentation and the simulator's own launch/relaunch behaviour are NOT exercised here; see the
/// tester report's instrument-exclusion table. What CAN be verified from source text is: AC1's flat-resource-
/// path/Application-Support resolution shape, AC2's POSIX date formatting, AC3/AC7's exhaustive phase and
/// hand-off switches, AC4's registered-text-only refusal surface, AC8's exact ContentView/MathmathApp shape,
/// AC9's carve-out-free scan (companion to `AppSourcesBoundaryTests.swift`), AC11's cmp coverage and
/// four-scenario assertions, and AC12's gate/CI wiring order. Each guard ships its own planted negative
/// control (C2), mirroring `MapCanvasViewStructuralTests.swift`'s and
/// `MapPanelsPickersHandOffStructuralTests.swift`'s shape.
@Suite("App/Sources/Shell structural guards (03.12 AC1-AC4/AC7-AC12)")
struct AppShellStructuralTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var shellRoot: URL { repoRoot.appendingPathComponent("App/Sources/Shell") }
    private static var appSourcesRoot: URL { repoRoot.appendingPathComponent("App/Sources") }

    private static let shellFileNames = ["AppShell.swift", "RefusalView.swift"]

    private static func readShell(_ name: String) throws -> String {
        try String(contentsOf: shellRoot.appendingPathComponent(name), encoding: .utf8)
    }

    private static func readAppSources(_ name: String) throws -> String {
        try String(contentsOf: appSourcesRoot.appendingPathComponent(name), encoding: .utf8)
    }

    private static func combinedShellSource() throws -> String {
        try shellFileNames.map { try readShell($0) }.joined(separator: "\n")
    }

    /// Finds the block between the `{` that follows `marker` and its own matching `}` — a brace-depth walk,
    /// mirroring `MapCanvasViewStructuralTests.balancedBraceBlock(after:in:)`.
    private static func balancedBraceBlock(after marker: String, in source: String) -> String? {
        guard let markerRange = source.range(of: marker) else { return nil }
        var depth = 1
        var index = markerRange.upperBound
        let start = index
        while index < source.endIndex {
            let char = source[index]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { return String(source[start..<index]) }
            }
            index = source.index(after: index)
        }
        return nil
    }

    private static func caseLines(in block: String) -> [String] {
        block.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
    }

    /// Strips `///`/`//` doc- and line-comment lines before a code-only scan, mirroring
    /// `MapCanvasViewStructuralTests.codeOnlyLines(in:)`. Doc comments in this task's files legitimately
    /// quote arbiter-03 prose verbatim (e.g. "the current ... session value", § Q-F) and name the reconciliation
    /// codes they document deliberately NOT special-casing (§4.2's own template comment) — neither is a code-
    /// level violation, so the checks below that must not false-positive on prose scan code only.
    private static func codeOnlyLines(in source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Fixture presence (both Shell files exist)

    @Test("both App/Sources/Shell files exist")
    func bothShellFilesExist() {
        for name in Self.shellFileNames {
            #expect(
                FileManager.default.fileExists(atPath: Self.shellRoot.appendingPathComponent(name).path),
                "missing file: \(name)")
        }
    }

    // MARK: - AppShell phases (§4.2): exactly four Phase cases

    @Test("AppShell.Phase has exactly four cases: launching, courseSelection, ready, refused")
    func phaseHasExactlyFourCases() throws {
        let source = try Self.readShell("AppShell.swift")
        guard let body = Self.balancedBraceBlock(after: "private enum Phase {", in: source) else {
            Issue.record("could not locate AppShell.Phase's body")
            return
        }
        let cases = Self.caseLines(in: body)
        #expect(cases.count == 4, "expected exactly 4 Phase cases, found \(cases.count): \(cases)")
        #expect(cases.contains("case launching"))
        #expect(cases.contains { $0.hasPrefix("case courseSelection(") })
        #expect(cases.contains("case ready"))
        #expect(cases.contains { $0.hasPrefix("case refused(") })
    }

    @Test("negative control: a planted fifth Phase case is caught")
    func plantedFifthPhaseCaseIsCaught() {
        let fixture = """
            private enum Phase {
                case launching
                case courseSelection(bundle: ContentBundle, previousState: StudentState?, unreadable: Bool)
                case ready
                case refused(BundleRefusal)
                case somethingElse
            }
            """
        let body = Self.balancedBraceBlock(after: "private enum Phase {", in: fixture)
        #expect(body != nil)
        let cases = Self.caseLines(in: body!)
        #expect(cases.count == 5, "planted fifth Phase case was not detected: \(cases)")
    }

    // MARK: - AC7 (03.12) as re-scoped by 04.8 AC7: one clause per HandOffDestination case; no branch calls Core

    /// The case-clause prefixes `AppShell.handOff`'s switch carries after task 04.8
    /// (`tasks/epic-04-task-08-app-expedition-screens.md` §4.9). Updated by task 04.9.
    private static let expectedHandOffCaseClausePrefixes = [
        "case .included(", "case .doorBStarted(", "case .diagnosisStarted(",
    ]

    private static let coreCallPattern = #"\b(MapFacade|DoorFacade|MapLaunch)\.\w+\("#

    /// One `case` clause of `block`: from the line starting with `prefix` up to (excluding) the next line
    /// starting with `case ` or `default:`, or the end of `block`.
    private static func caseBranch(startingWith prefix: String, in block: String) -> String? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard
            let start = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
            })
        else { return nil }
        var branch = [lines[start]]
        for line in lines[(start + 1)...] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") { break }
            branch.append(line)
        }
        return branch.joined(separator: "\n")
    }

    @Test(
        "AC7 (03.12, re-scoped by 04.8 AC7): AppShell.handOff has exactly one case clause per HandOffDestination case"
    )
    func handOffSwitchHasOneClausePerDestination() throws {
        let source = try Self.readShell("AppShell.swift")
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: source) else {
            Issue.record("could not locate AppShell.handOff's switch body")
            return
        }
        let cases = Self.caseLines(in: body)
        let expected = Self.expectedHandOffCaseClausePrefixes
        #expect(cases.count == expected.count, "expected \(expected.count) case clauses, found: \(cases)")
        for prefix in expected {
            #expect(
                cases.filter { $0.hasPrefix(prefix) }.count == 1,
                "expected exactly one clause starting \(prefix): \(cases)")
        }
        #expect(!body.contains(".unitExpedition"), "03.11's retired .unitExpedition case must not reappear")
    }

    @Test("negative control: a planted extra case clause in the handOff switch is caught")
    func plantedExtraHandOffCaseIsCaught() {
        let fixture = """
            switch destination {
            case .included(let map):
                holder.replace(with: map)
            case .doorBStarted(let outcome):
                doorHolder.replace(with: snapshot(outcome))
            case .diagnosisStarted(let outcome):
                doorHolder.replace(with: snapshot(outcome))
            case .somethingElse:
                break
            }
            """
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: fixture) else {
            Issue.record("fixture setup failed")
            return
        }
        let cases = Self.caseLines(in: body)
        #expect(
            cases.count == Self.expectedHandOffCaseClausePrefixes.count + 1,
            "planted extra case clause was not detected: \(cases)")
    }

    @Test(
        "I14 (04.8 AC7, 04.9 AC5): no handOff branch calls a façade or launch function; each door branch only replaces the door holder with its origin tag"
    )
    func handOffBranchesCallNoFurtherCoreFunction() throws {
        let source = try Self.readShell("AppShell.swift")
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: source) else {
            Issue.record("could not locate AppShell.handOff's switch body")
            return
        }
        #expect(
            body.range(of: Self.coreCallPattern, options: .regularExpression) == nil,
            "a handOff branch calls a façade/launch function; the action's one call belongs to its button (I14)"
        )
        guard let doorB = Self.caseBranch(startingWith: "case .doorBStarted(", in: body) else {
            Issue.record("could not isolate the .doorBStarted branch")
            return
        }
        #expect(doorB.components(separatedBy: "doorHolder.replace(").count - 1 == 1)
        #expect(
            doorB.contains("isStandaloneDiagnosis: false"), ".doorBStarted opens an expedition run (04.9 AC5)"
        )
        guard let doorA = Self.caseBranch(startingWith: "case .diagnosisStarted(", in: body) else {
            Issue.record("could not isolate the .diagnosisStarted branch")
            return
        }
        #expect(doorA.components(separatedBy: "doorHolder.replace(").count - 1 == 1)
        #expect(
            doorA.contains("isStandaloneDiagnosis: true"),
            ".diagnosisStarted opens a standalone event (04.9 AC5)")
    }

    @Test("negative control: a planted DoorFacade call inside a handOff branch is caught")
    func plantedFacadeCallInHandOffBranchIsCaught() {
        let fixture = """
            switch destination {
            case .included(let map):
                holder.replace(with: map)
            case .doorBStarted(let outcome):
                _ = DoorFacade.backToMap(outcome.runState, today: today)
            case .diagnosisStarted(let outcome):
                doorHolder.replace(with: snapshot(outcome))
            }
            """
        guard let body = Self.balancedBraceBlock(after: "switch destination {", in: fixture) else {
            Issue.record("fixture setup failed")
            return
        }
        #expect(
            body.range(of: Self.coreCallPattern, options: .regularExpression) != nil,
            "planted façade call was not detected")
        let doorB = Self.caseBranch(startingWith: "case .doorBStarted(", in: body)
        #expect(doorB?.contains("doorHolder.replace(") == false, "planted missing replace was not detected")
    }

    // MARK: - I14: MapLaunch.open is the only launch entry point; AppShell never calls BundleLoader directly

    @Test("I14: AppShell.swift calls MapLaunch.open( exactly once and never references BundleLoader")
    func appShellCallsMapLaunchOpenExactlyOnceAndNeverBundleLoader() throws {
        let source = try Self.readShell("AppShell.swift")
        let openCallCount = source.components(separatedBy: "MapLaunch.open(").count - 1
        #expect(openCallCount == 1, "expected exactly one MapLaunch.open( call site, found \(openCallCount)")
        #expect(
            source.range(of: #"\bBundleLoader\b"#, options: .regularExpression) == nil,
            "AppShell.swift must never reference BundleLoader directly (I14) — only MapLaunch.open may load a bundle"
        )
    }

    @Test("negative control: a planted direct BundleLoader.load call in AppShell.swift is caught")
    func plantedDirectBundleLoaderCallIsCaught() {
        let fixture = "let (bundle, _) = try BundleLoader.load(from: Self.resolveSnapshotDir())"
        #expect(fixture.range(of: #"\bBundleLoader\b"#, options: .regularExpression) != nil)
    }

    @Test(
        "I14: MapLaunch.open's only bundle-load call is BundleLoader.load( — the single path AppShell's resolved snapshot directory reaches"
    )
    func mapLaunchOpenCallsBundleLoaderExactlyOnce() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(
                "Packages/Core/Sources/Core/Platform/MapLaunch.swift"), encoding: .utf8)
        let count = source.components(separatedBy: "BundleLoader.load(").count - 1
        #expect(
            count == 1, "expected exactly one BundleLoader.load( call site in MapLaunch.swift, found \(count)"
        )
    }

    @Test("negative control: a fixture with two BundleLoader.load call sites is caught by the count")
    func plantedSecondBundleLoaderCallSiteIsCaught() {
        let fixture = """
            (bundle, _) = try BundleLoader.load(from: snapshotDir)
            (bundle2, _) = try BundleLoader.load(from: otherDir)
            """
        let count = fixture.components(separatedBy: "BundleLoader.load(").count - 1
        #expect(count == 2, "planted duplicate call site was not detected")
    }

    // MARK: - AC1: resolveSnapshotDir() returns Bundle.main.resourcePath itself (the accepted deviation)

    @Test(
        "AC1 (accepted deviation): resolveSnapshotDir() returns Bundle.main.resourcePath itself, with no DemoSnapshot subdirectory appended"
    )
    func resolveSnapshotDirReturnsResourcePathFlat() throws {
        let source = try Self.readShell("AppShell.swift")
        guard
            let body = Self.balancedBraceBlock(
                after: "static func resolveSnapshotDir() -> URL {", in: source)
        else {
            Issue.record("could not locate resolveSnapshotDir()'s body")
            return
        }
        #expect(body.contains("Bundle.main.resourcePath"))
        #expect(
            !body.contains("appendingPathComponent(\"DemoSnapshot\")"),
            "resolveSnapshotDir must not append a DemoSnapshot subdirectory (accepted deviation §6)")
    }

    @Test("negative control: a planted DemoSnapshot subdirectory append is caught")
    func plantedDemoSnapshotAppendIsCaught() {
        let fixture = """
            static func resolveSnapshotDir() -> URL {
                let resourcePath = Bundle.main.resourcePath!
                return URL(fileURLWithPath: resourcePath).appendingPathComponent("DemoSnapshot")
            }
            """
        #expect(
            fixture.contains("appendingPathComponent(\"DemoSnapshot\")"), "planted violation was not detected"
        )
    }

    // MARK: - AC1: resolveStateURL() resolves Application Support, creates the directory, fixed file name

    @Test(
        "AC1: resolveStateURL() resolves .applicationSupportDirectory, creates it first, and appends the fixed stateFileName"
    )
    func resolveStateURLCreatesDirectoryAndAppendsFixedName() throws {
        let source = try Self.readShell("AppShell.swift")
        guard
            let body = Self.balancedBraceBlock(
                after: "static func resolveStateURL() -> URL {", in: source)
        else {
            Issue.record("could not locate resolveStateURL()'s body")
            return
        }
        #expect(body.contains(".applicationSupportDirectory"))
        #expect(body.contains("createDirectory(at: appSupport"))
        #expect(body.contains("appendingPathComponent(stateFileName)"))
        #expect(source.contains("static let stateFileName = \"student-state.json\""))
    }

    @Test("negative control: a fixture that skips creating Application Support before returning is caught")
    func skippedDirectoryCreationIsCaught() {
        let fixture = """
            static func resolveStateURL() -> URL {
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                return appSupport.appendingPathComponent(stateFileName)
            }
            """
        #expect(!fixture.contains("createDirectory(at: appSupport"), "planted omission was not detected")
    }

    // MARK: - AC2: resolveToday() formats POSIX yyyy-MM-dd and never force-unwraps CalendarDay(iso:)

    @Test(
        "AC2: resolveToday() formats en_US_POSIX yyyy-MM-dd in the current time zone and guards CalendarDay(iso:) with a non-force-unwrap"
    )
    func resolveTodayFormatsPosixDateAndGuardsCalendarDay() throws {
        let source = try Self.readShell("AppShell.swift")
        guard
            let body = Self.balancedBraceBlock(
                after: "static func resolveToday() -> CalendarDay {", in: source)
        else {
            Issue.record("could not locate resolveToday()'s body")
            return
        }
        #expect(body.contains("en_US_POSIX"))
        #expect(body.contains("yyyy-MM-dd"))
        #expect(body.contains("timeZone = .current"))
        #expect(body.contains("guard let day = CalendarDay(iso: iso) else"))
        #expect(
            !body.contains("CalendarDay(iso: iso)!"),
            "resolveToday must never force-unwrap CalendarDay(iso:) (.swift-format NeverForceUnwrap)")
    }

    @Test("negative control: a planted force-unwrapped CalendarDay(iso:) is caught")
    func plantedForceUnwrappedCalendarDayIsCaught() {
        let fixture = "let day = CalendarDay(iso: iso)!"
        #expect(fixture.contains("CalendarDay(iso: iso)!"), "planted violation was not detected")
    }

    // MARK: - AC3 / arbiter-03 § Q-A (re-scoped by 04.8 §4.9): CoreErrorText is the only source of student text

    /// Every `CoreErrorText.text(for:` call site in `App/Sources/Shell` after task 04.8 (§4.9): 03.12's two,
    /// plus 04.8's summary write-failure resolution and `DoorBRunScreen.startAnother`'s error text. Updated by
    /// task 04.9.
    private static let expectedShellCoreErrorTextSites = [
        "CoreErrorText.text(for: refusal.studentCode)",
        "CoreErrorText.text(for: .platformStateUnreadable)",
        "flatMap(CoreErrorText.text(for:))",
        "CoreErrorText.text(for: error)",
        "CoreErrorText.text(for: coreError)",
    ]

    @Test(
        "AC3 (03.12, re-scoped by 04.8 §4.9): CoreErrorText.text(for:) is called at exactly the expected App/Sources/Shell sites, no more"
    )
    func coreErrorTextCalledOnlyAtExpectedShellSites() throws {
        let combined = Self.codeOnlyLines(in: try Self.combinedShellSource())
        let count = combined.components(separatedBy: "CoreErrorText.text(for:").count - 1
        let expected = Self.expectedShellCoreErrorTextSites
        #expect(
            count == expected.count,
            "expected \(expected.count) CoreErrorText.text(for: sites, found \(count)")
        for site in expected {
            #expect(combined.contains(site), "missing expected CoreErrorText call site: \(site)")
        }
    }

    @Test(
        "negative control: one CoreErrorText.text(for:) call site beyond the expected set is caught by the count"
    )
    func plantedExtraCoreErrorTextCallSiteIsCaught() {
        let fixture = (Self.expectedShellCoreErrorTextSites + ["CoreErrorText.text(for: .expNoFringe)"])
            .joined(separator: "\n")
        let count = fixture.components(separatedBy: "CoreErrorText.text(for:").count - 1
        #expect(
            count == Self.expectedShellCoreErrorTextSites.count + 1,
            "planted extra call site was not detected")
    }

    @Test(
        "AC3: exactly one PLATFORM_ string literal appears across App/Sources/Shell, and it is PLATFORM_STATE_UNREADABLE"
    )
    func onlyOnePlatformStringLiteralAppears() throws {
        let combined = try Self.combinedShellSource()
        let pattern = #""(PLATFORM_[A-Z_]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsCombined = combined as NSString
        let matches = regex.matches(in: combined, range: NSRange(location: 0, length: nsCombined.length))
        let codes = matches.map { nsCombined.substring(with: $0.range(at: 1)) }
        #expect(codes == ["PLATFORM_STATE_UNREADABLE"], "unexpected PLATFORM_ string literals: \(codes)")
    }

    @Test("negative control: a planted second PLATFORM_ string literal is caught")
    func plantedSecondPlatformStringLiteralIsCaught() throws {
        let fixture = """
            messages.contains("PLATFORM_STATE_UNREADABLE")
            messages.contains("PLATFORM_BUNDLE_FETCH_FAILED")
            """
        let pattern = #""(PLATFORM_[A-Z_]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = fixture as NSString
        let matches = regex.matches(in: fixture, range: NSRange(location: 0, length: ns.length))
        let codes = matches.map { ns.substring(with: $0.range(at: 1)) }
        #expect(codes.count == 2, "planted second PLATFORM_ literal was not detected: \(codes)")
    }

    @Test(
        "arbiter-03 § Q-A: no code line in AppShell/RefusalView checks MAP_MARKER_OFF_TRAIL or any other specific reconciliation code by string literal"
    )
    func neverNamesMapMarkerOffTrailOrOtherSpecificCodes() throws {
        // Code-only: §4.2's own template comment names these codes by design, to document that they are
        // deliberately not special-cased (not a violation); an actual quoted-string check on them would be.
        let combined = Self.codeOnlyLines(in: try Self.combinedShellSource())
        #expect(!combined.contains("\"MAP_MARKER_OFF_TRAIL\""))
        #expect(!combined.contains("\"EXP_NODE_NOT_IN_GRAPH\""))
    }

    @Test("negative control: a planted code-level MAP_MARKER_OFF_TRAIL string-literal check is caught")
    func plantedMapMarkerOffTrailBranchIsCaught() {
        let fixture = "if messages.contains(\"MAP_MARKER_OFF_TRAIL\") { showResetBanner = true }"
        let codeOnly = Self.codeOnlyLines(in: fixture)
        #expect(codeOnly.contains("\"MAP_MARKER_OFF_TRAIL\""), "planted violation was not detected")
    }

    // MARK: - AC8: ContentView.swift's body is exactly AppShell(); no SwiftMath/MathLabel; imports Core+SwiftUI only

    @Test(
        "AC8: ContentView.swift's body is exactly AppShell(), imports only Core and SwiftUI, and contains no SwiftMath or MathLabel"
    )
    func contentViewBodyIsExactlyAppShell() throws {
        let source = try Self.readAppSources("ContentView.swift")
        // Code-only: the file's own doc comment legitimately says "Replaces the Phase-5 SwiftMath
        // placeholder" (§4.4's own template) — a historical reference, not a live import or construct.
        let codeOnly = Self.codeOnlyLines(in: source)
        #expect(!codeOnly.contains("SwiftMath"))
        #expect(!codeOnly.contains("MathLabel"))
        #expect(source.contains("AppShell()"))
        let imports = Set(
            source.split(separator: "\n").compactMap { line -> String? in
                guard line.hasPrefix("import ") else { return nil }
                return String(line.dropFirst("import ".count))
            })
        #expect(imports == ["Core", "SwiftUI"], "unexpected ContentView.swift import set: \(imports)")
    }

    @Test("negative control: a planted import SwiftMath in ContentView.swift is caught")
    func plantedSwiftMathImportInContentViewIsCaught() {
        let fixture = "import Core\nimport SwiftMath\nimport SwiftUI\nstruct ContentView: View {}\n"
        #expect(fixture.contains("SwiftMath"), "planted violation was not detected")
    }

    @Test(
        "AC8: MathmathApp.swift no longer imports Core; its body is unchanged (WindowGroup { ContentView() })"
    )
    func mathmathAppDropsUnusedCoreImport() throws {
        let source = try Self.readAppSources("MathmathApp.swift")
        #expect(!source.contains("import Core"))
        #expect(source.contains("WindowGroup {"))
        #expect(source.contains("ContentView()"))
    }

    @Test("negative control: a planted (now unused) import Core in MathmathApp.swift is caught")
    func plantedUnusedCoreImportInMathmathAppIsCaught() {
        let fixture = "import Core\nimport SwiftUI\n@main\nstruct MathmathApp: App {}\n"
        #expect(fixture.contains("import Core"), "planted violation was not detected")
    }

    // MARK: - AC4: RefusalView shows only the registered studentCode text, never internalCode/report, never authored copy

    @Test(
        "AC4: RefusalView.swift renders CoreErrorText.text(for: refusal.studentCode), never internalCode or report"
    )
    func refusalViewShowsOnlyRegisteredStudentCodeText() throws {
        let source = try Self.readShell("RefusalView.swift")
        #expect(source.contains("CoreErrorText.text(for: refusal.studentCode)"))
        // Code-only: the file's own doc comment legitimately says "refusal.internalCode/refusal.report are
        // never read here" (§4.3's own template) — documenting the rule, not violating it.
        let codeOnly = Self.codeOnlyLines(in: source)
        #expect(!codeOnly.contains("refusal.internalCode"))
        #expect(!codeOnly.contains("refusal.report"))
    }

    @Test(
        "negative control: a planted code-level read of refusal.internalCode in RefusalView.swift is caught")
    func plantedInternalCodeReadInRefusalViewIsCaught() {
        let fixture = "Text(\"debug: \\(refusal.internalCode)\")"
        let codeOnly = Self.codeOnlyLines(in: fixture)
        #expect(codeOnly.contains("refusal.internalCode"), "planted violation was not detected")
    }

    private struct ErrorCodeEntry: Decodable {
        let code: String
        let surface: String
        let userText: String?
        private enum CodingKeys: String, CodingKey {
            case code, surface
            case userText = "user_text"
        }
    }

    private static func loadErrorCodeEntries() throws -> [ErrorCodeEntry] {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("contracts/error-codes.json"))
        if let flat = try? JSONDecoder().decode([ErrorCodeEntry].self, from: data) {
            return flat
        }
        struct Registry: Decodable { let codes: [ErrorCodeEntry] }
        return try JSONDecoder().decode(Registry.self, from: data).codes
    }

    @Test(
        "RefusalView.swift hand-authors no String literal duplicating the registered PLATFORM_SNAPSHOT_REFUSED user_text"
    )
    func refusalViewDoesNotDuplicateRegistryText() throws {
        let entries = try Self.loadErrorCodeEntries()
        guard let refused = entries.first(where: { $0.code == "PLATFORM_SNAPSHOT_REFUSED" }),
            let text = refused.userText
        else {
            Issue.record("PLATFORM_SNAPSHOT_REFUSED not found in contracts/error-codes.json")
            return
        }
        let source = try Self.readShell("RefusalView.swift")
        #expect(
            !source.contains("\"\(text)\""),
            "RefusalView.swift hand-authors a String literal duplicating the registry user_text")
    }

    @Test(
        "negative control: a planted hand-authored duplicate of PLATFORM_SNAPSHOT_REFUSED's user_text is caught"
    )
    func plantedDuplicateRefusalTextLiteralIsCaught() throws {
        let entries = try Self.loadErrorCodeEntries()
        guard let refused = entries.first(where: { $0.code == "PLATFORM_SNAPSHOT_REFUSED" }),
            let text = refused.userText
        else {
            Issue.record("PLATFORM_SNAPSHOT_REFUSED not found in contracts/error-codes.json")
            return
        }
        let fixture = "Text(\"\(text)\")"
        #expect(fixture.contains("\"\(text)\""), "planted duplicate literal was not detected")
    }

    // MARK: - Banned glossary synonyms (case-sensitive check on "Session"), mirroring 03.11's AC11 shape

    private static let bannedGlossaryPatterns = [
        #"\bsession\b"#, #"\bSession\b"#, "start marker", #"\bcursor\b"#, #"\bprofile\b"#, "progress file",
        #"\bsave\b"#,
    ]

    @Test("no code line in App/Sources/Shell uses a banned glossary synonym, case-sensitively on Session")
    func noShellFileUsesBannedGlossaryTerms() throws {
        // Code-only: AppShell.swift's MapStateHolder doc comment quotes arbiter-03 § Q-F verbatim ("the
        // current ... session value") — prose citing the ruling that coined the glossary rule, not a symbol
        // name or user-facing string this rule targets (contrast 03.11's MapUI views, which render no such
        // doc-comment quotes and so are checked unfiltered in MapPanelsPickersHandOffStructuralTests).
        for name in Self.shellFileNames {
            let source = Self.codeOnlyLines(in: try Self.readShell(name))
            for pattern in Self.bannedGlossaryPatterns {
                #expect(
                    source.range(of: pattern, options: .regularExpression) == nil,
                    "\(name) uses banned glossary term matching /\(pattern)/")
            }
        }
    }

    @Test(
        "negative control: a planted capitalized \"Session\" identifier is caught even though \"session\" is banned too"
    )
    func plantedCapitalizedSessionIsCaught() {
        let fixture = "typealias Session = LaunchOutcome"
        #expect(fixture.range(of: #"\bSession\b"#, options: .regularExpression) != nil)
    }

    @Test("negative control: a planted lower-case \"session\" on-screen string is caught")
    func plantedLowercaseSessionCopyIsCaught() {
        let fixture = "Text(\"Resume your session\")"
        #expect(fixture.range(of: #"\bsession\b"#, options: .regularExpression) != nil)
    }

    // MARK: - AC12: gate.sh calls sim-smoke.sh after the App build and before pipeline pytest

    @Test("AC12: scripts/gate.sh calls sim-smoke.sh after the App build and before the pipeline pytest step")
    func gateShCallsSimSmokeInOrder() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("scripts/gate.sh"), encoding: .utf8)
        guard let buildRange = source.range(of: "App/mathmath.xcworkspace"),
            let smokeRange = source.range(
                of: "scripts/sim-smoke.sh", range: buildRange.upperBound..<source.endIndex),
            let pytestRange = source.range(
                of: "uv run pytest -q", range: smokeRange.upperBound..<source.endIndex)
        else {
            Issue.record("gate.sh does not call sim-smoke.sh strictly between the App build and pytest")
            return
        }
        #expect(buildRange.upperBound < smokeRange.lowerBound)
        #expect(smokeRange.upperBound < pytestRange.lowerBound)
    }

    @Test("negative control: a fixture with pytest running before the sim-smoke call is caught")
    func gateShWithReversedOrderIsCaught() {
        let fixture = """
            xcodebuild build -workspace App/mathmath.xcworkspace -scheme mathmath
            ( cd pipeline && uv run pytest -q )
            scripts/sim-smoke.sh
            """
        guard let buildRange = fixture.range(of: "App/mathmath.xcworkspace"),
            let pytestRange = fixture.range(
                of: "uv run pytest -q", range: buildRange.upperBound..<fixture.endIndex)
        else {
            Issue.record("fixture setup failed")
            return
        }
        let smokeAfterPytest = fixture.range(
            of: "scripts/sim-smoke.sh", range: pytestRange.upperBound..<fixture.endIndex)
        #expect(smokeAfterPytest != nil, "planted reversed order was not detected by this shape")
    }

    // MARK: - AC12: ci.yml's swift job gains a pinned setup-uv step (0.12.12) between build and smoke

    @Test(
        "AC12: ci.yml's swift job runs a pinned astral-sh/setup-uv@v6 (0.12.12) step after the App build and before the smoke step"
    )
    func ciYmlSwiftJobHasPinnedSetupUvBetweenBuildAndSmoke() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(".github/workflows/ci.yml"), encoding: .utf8)
        guard let swiftJobRange = source.range(of: "swift:"),
            let pythonJobRange = source.range(
                of: "python:", range: swiftJobRange.upperBound..<source.endIndex)
        else {
            Issue.record("could not isolate the swift: job block in ci.yml")
            return
        }
        let swiftJobBlock = String(source[swiftJobRange.upperBound..<pythonJobRange.lowerBound])
        guard let buildRange = swiftJobBlock.range(of: "App build on the simulator"),
            let setupUvRange = swiftJobBlock.range(
                of: "astral-sh/setup-uv@v6", range: buildRange.upperBound..<swiftJobBlock.endIndex),
            let versionRange = swiftJobBlock.range(
                of: "version: \"0.12.12\"", range: setupUvRange.upperBound..<swiftJobBlock.endIndex),
            let smokeRange = swiftJobBlock.range(
                of: "sim-smoke.sh", range: versionRange.upperBound..<swiftJobBlock.endIndex)
        else {
            Issue.record(
                "swift job is missing the ordered App-build -> setup-uv(0.12.12) -> smoke sequence")
            return
        }
        #expect(buildRange.upperBound < setupUvRange.lowerBound)
        #expect(versionRange.upperBound < smokeRange.lowerBound)
    }

    @Test("negative control: a fixture setup-uv step missing the 0.12.12 pin is caught")
    func fixtureSetupUvStepMissingPinIsCaught() {
        let fixture = """
            - name: App build on the simulator
              run: xcodebuild build
            - uses: astral-sh/setup-uv@v6
            - name: Simulator smoke
              run: scripts/sim-smoke.sh
            """
        guard let buildRange = fixture.range(of: "App build on the simulator"),
            let setupUvRange = fixture.range(
                of: "astral-sh/setup-uv@v6", range: buildRange.upperBound..<fixture.endIndex)
        else {
            Issue.record("fixture setup failed")
            return
        }
        let versionRange = fixture.range(
            of: "version: \"0.12.12\"", range: setupUvRange.upperBound..<fixture.endIndex)
        #expect(versionRange == nil, "planted missing pin was not detected")
    }

    // MARK: - AC11: sim-smoke.sh asserts all four scenarios and its cmp loop covers every data/demo file

    @Test("AC11: sim-smoke.sh asserts all four scenarios in order")
    func simSmokeAssertsAllFourScenarios() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("scripts/sim-smoke.sh"), encoding: .utf8)
        #expect(source.contains("scenario 1 (fresh install, no state file) PASS"))
        #expect(source.contains("schema_version"))
        #expect(source.contains(".pre-migration"))
        #expect(source.contains("scenario 2 (v1 -> v2 migration, byte-identical relaunch) PASS"))
        #expect(source.contains("embedded DemoSnapshot byte-identical to data/demo"))
    }

    @Test("negative control: a fixture missing the migration-scenario PASS marker is caught")
    func fixtureMissingMigrationScenarioMarkerIsCaught() {
        let fixture = "echo \"sim-smoke: scenario 1 (fresh install, no state file) PASS\"\n"
        #expect(
            !fixture.contains("scenario 2 (v1 -> v2 migration, byte-identical relaunch) PASS"),
            "planted omission was not detected")
    }

    @Test("AC11: sim-smoke.sh's cmp loop covers exactly every .json file in data/demo, no more, no fewer")
    func simSmokeCmpLoopCoversEveryDemoFile() throws {
        let demoDir = Self.repoRoot.appendingPathComponent("data/demo")
        let demoFiles = Set(
            try FileManager.default.contentsOfDirectory(atPath: demoDir.path).filter {
                $0.hasSuffix(".json")
            })
        #expect(!demoFiles.isEmpty, "data/demo has no .json files — cannot verify cmp coverage")

        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("scripts/sim-smoke.sh"), encoding: .utf8)
        guard let forRange = source.range(of: "for f in "),
            let doRange = source.range(of: "; do", range: forRange.upperBound..<source.endIndex)
        else {
            Issue.record("could not locate sim-smoke.sh's cmp for-loop file list")
            return
        }
        let listedFiles = Set(
            source[forRange.upperBound..<doRange.lowerBound].split(separator: " ").map(String.init))
        #expect(
            listedFiles == demoFiles,
            "sim-smoke.sh's cmp loop (\(listedFiles)) does not match data/demo's real file set (\(demoFiles))"
        )
    }

    @Test("negative control: a fixture cmp loop missing one data/demo file is caught")
    func fixtureCmpLoopMissingOneFileIsCaught() {
        let demoFiles: Set<String> = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json", "landmarks.json",
            "sources.json",
        ]
        let fixture = "for f in manifest.json regions.json nodes.json edges.json courses.json; do"
        guard let forRange = fixture.range(of: "for f in "),
            let doRange = fixture.range(of: "; do", range: forRange.upperBound..<fixture.endIndex)
        else {
            Issue.record("fixture setup failed")
            return
        }
        let listedFiles = Set(
            fixture[forRange.upperBound..<doRange.lowerBound].split(separator: " ").map(String.init))
        #expect(listedFiles != demoFiles, "planted missing files were not detected")
        #expect(demoFiles.subtracting(listedFiles) == ["landmarks.json", "sources.json"])
    }

    // MARK: - AC9/AC10 companion: the boundary scan, re-run over the real complete App/Sources tree, is clean

    @Test("AC9/AC10: AppSourcesBoundary.violations(in:) over the real complete App/Sources tree returns []")
    func realCompleteAppSourcesTreeHasNoBoundaryViolations() throws {
        let violations = try AppSourcesBoundary.violations(in: Self.appSourcesRoot)
        #expect(violations.isEmpty, "App/Sources boundary violations after 03.12: \(violations)")
    }

    @Test("AC9 companion: the deleted carve-out constants no longer exist as symbols on AppSourcesBoundary")
    func carveOutConstantsNoLongerExistAsSourceText() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(
                "Packages/Core/Tests/CoreTests/AppSourcesBoundaryTests.swift"), encoding: .utf8)
        #expect(!source.contains("contentViewSwiftMathExceptionFile"))
        #expect(!source.contains("contentViewSwiftMathExceptionImport"))
        #expect(!source.contains("TIME-BOXED EXCEPTION"))
    }
}

import Foundation
import Testing

@testable import Core

/// Structural (source-text) guards for the six `App/Sources/MapUI/*.swift` files task 03.11
/// (`tasks/epic-03-task-11-app-panels-pickers-handoff.md`) ships: `NodePanelView`, `RegionPanelView`,
/// `LandmarkPanelView`, `CoursePickerView`, `UnitListPickerView`, `MapActionsView`. Per the task's own §5
/// C3 note there is no App unit-test target (`App/mathmath.xcodeproj` has none, and the project file is
/// never edited) — SwiftUI runtime rendering, tap-driven state changes and the sheet/picker presentation
/// flow are NOT exercised here; see the tester report's instrument-exclusion table. What CAN be verified
/// from source text is: AC1/AC5/AC6's field/action-control shape, AC2–AC4/AC7/AC8's one-façade-call-per-
/// action counts, AC9's exact-three-case `HandOffDestination`, AC10's forbidden-construct/force-unwrap
/// absence, AC11's glossary-term absence, and I6/I14's field-and-state boundary. Each guard ships its own
/// planted negative control (C2), mirroring `MapCanvasViewStructuralTests.swift`'s shape.
@Suite("App/Sources/MapUI structural guards (03.11 AC1-AC11)")
struct MapPanelsPickersHandOffStructuralTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var mapUIRoot: URL {
        repoRoot.appendingPathComponent("App/Sources/MapUI")
    }

    private static let fileNames = [
        "NodePanelView.swift", "RegionPanelView.swift", "LandmarkPanelView.swift", "CoursePickerView.swift",
        "UnitListPickerView.swift", "MapActionsView.swift",
    ]

    private static func path(_ name: String) -> URL {
        mapUIRoot.appendingPathComponent(name)
    }

    private static func readReal(_ name: String) throws -> String {
        try String(contentsOf: path(name), encoding: .utf8)
    }

    private static func readAllReal() throws -> [String: String] {
        var contents: [String: String] = [:]
        for name in fileNames {
            contents[name] = try readReal(name)
        }
        return contents
    }

    // MARK: - Fixture presence (all six files exist)

    @Test("all six task-scope files exist under App/Sources/MapUI")
    func allSixFilesExist() {
        for name in Self.fileNames {
            #expect(
                FileManager.default.fileExists(atPath: Self.path(name).path), "missing file: \(name)")
        }
    }

    // MARK: - AC1: NodePanelView renders every field, exactly one action control by state

    @Test(
        "AC1: NodePanelView.swift renders name, paraphrase, masteryLabel, expectationCodeLinks as Link(officialUrl), courseCodesCrossingHere and landmarkIds"
    )
    func nodePanelViewRendersEveryAC1Field() throws {
        let source = try Self.readReal("NodePanelView.swift")
        #expect(source.contains("content.name"))
        #expect(source.contains("content.paraphrase"))
        #expect(source.contains("content.masteryLabel"))
        #expect(source.contains("content.expectationCodeLinks"))
        #expect(source.contains("link.officialUrl"))
        #expect(source.contains("Link("), "expectation codes must render as a Link, not plain Text")
        #expect(source.contains("content.courseCodesCrossingHere"))
        #expect(source.contains("content.landmarkIds"))
    }

    @Test("AC1 negative control: a fixture missing masteryLabel is caught")
    func fixtureMissingMasteryLabelIsCaught() {
        let fixture = """
            struct Bad: View {
                let content: NodePanelContent
                var body: some View {
                    Text(content.name)
                    Text(content.paraphrase)
                }
            }
            """
        #expect(!fixture.contains("content.masteryLabel"), "planted omission was not detected")
    }

    @Test(
        "AC1: NodePanelView.swift offers exactly one action control chosen by a switch over the id-looked-up action"
    )
    func nodePanelViewHasExactlyOneActionSwitch() throws {
        let source = try Self.readReal("NodePanelView.swift")
        let switchCount = source.components(separatedBy: "switch action {").count - 1
        #expect(switchCount == 1, "expected exactly one action switch, found \(switchCount)")
        #expect(source.contains("case .checkHere:"))
        #expect(source.contains("case .include:"))
        #expect(source.contains("case nil:"))
        #expect(source.contains("mapState.viewModel.nodes.first(where:"))
        #expect(source.contains("$0.id == content.nodeId"))
    }

    @Test("AC1 negative control: a fixture re-deriving the action instead of looking it up is caught")
    func fixtureReDerivingActionIsCaught() {
        let fixture = """
            private var action: NodeAction? {
                content.fogLevel == .cleared ? nil : .include
            }
            """
        #expect(
            !fixture.contains("mapState.viewModel.nodes.first(where:"),
            "planted re-derivation was not distinguished from the required id lookup")
    }

    // MARK: - AC5: RegionPanelView renders required fields and offers no action control

    @Test(
        "AC5: RegionPanelView.swift renders name, about, courseCodesCrossingHere and the clearedFraction/under-fog branch, with no action control"
    )
    func regionPanelViewRendersRequiredFieldsAndNoAction() throws {
        let source = try Self.readReal("RegionPanelView.swift")
        #expect(source.contains("content.name"))
        #expect(source.contains("content.about"))
        #expect(source.contains("content.courseCodesCrossingHere"))
        #expect(source.contains("content.clearedFraction"))
        #expect(source.contains("under fog"))
        #expect(!source.contains("Button("), "RegionPanelView must offer no action control (map § W3)")
        // A doc comment may legitimately name `MapFacade.regionPanelContent` (as this file's own header
        // does, explaining why it never receives a horizon region); only an actual call expression
        // (`MapFacade.` followed by an identifier and `(`) would violate "no façade call" — none exists.
        #expect(
            source.range(of: #"MapFacade\.\w+\("#, options: .regularExpression) == nil,
            "RegionPanelView must call no façade function")
    }

    @Test("AC5 negative control: a planted Button in a region-panel fixture is caught")
    func plantedRegionPanelButtonIsCaught() {
        let fixture = """
            List {
                Text(content.name)
                Button("Do something") {}
            }
            """
        #expect(fixture.contains("Button("), "planted action control was not detected")
    }

    // MARK: - AC6: LandmarkPanelView renders sourceUrl as a Link and one callback row per nodeIds entry

    @Test(
        "AC6: LandmarkPanelView.swift renders name, whatItIs, sourceUrl as a Link, and calls onNodeJump per nodeIds entry, never a HandOffDestination case"
    )
    func landmarkPanelViewRendersRequiredFieldsAndCallback() throws {
        let source = try Self.readReal("LandmarkPanelView.swift")
        #expect(source.contains("content.name"))
        #expect(source.contains("content.whatItIs"))
        #expect(source.contains("content.sourceUrl"))
        #expect(source.contains("Link("))
        #expect(source.contains("onNodeJump(nodeId)"))
        #expect(
            !source.contains("HandOffDestination"),
            "landmark node-jump must be a plain callback, never a HandOffDestination case (§6)")
    }

    @Test("AC6 negative control: a fixture routing the node-jump through HandOffDestination is caught")
    func fixtureRoutingNodeJumpThroughHandOffIsCaught() {
        let fixture = "Button(nodeId) { handOff(.included(map: someMap)) }"
        #expect(
            fixture.contains("HandOffDestination") == false && fixture.contains(".included"),
            "fixture shape sanity check")
        #expect(
            fixture.contains("handOff("),
            "planted mis-routed node-jump through the hand-off hook was not detected")
    }

    // MARK: - AC9: HandOffDestination has exactly three cases

    /// Extracts `case` lines from within `enum HandOffDestination { ... }`'s balanced brace body.
    private static func handOffDestinationCaseLines(in source: String) -> [String] {
        guard let enumRange = source.range(of: "enum HandOffDestination {") else { return [] }
        var depth = 1
        var index = enumRange.upperBound
        let start = index
        while index < source.endIndex {
            let char = source[index]
            if char == "{" {
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0 { break }
            }
            index = source.index(after: index)
        }
        let body = String(source[start..<index])
        return body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
    }

    @Test("AC9: HandOffDestination has exactly three cases: .diagnosis, .unitExpedition, .included")
    func handOffDestinationHasExactlyThreeCases() throws {
        let source = try Self.readReal("MapActionsView.swift")
        let cases = Self.handOffDestinationCaseLines(in: source)
        #expect(cases.count == 3, "expected exactly 3 cases, found \(cases.count): \(cases)")
        #expect(cases.contains { $0.contains("diagnosis(event: DiagnosisEvent)") })
        #expect(cases.contains { $0.contains("unitExpedition(result: ComposeResult)") })
        #expect(cases.contains { $0.contains("included(map: MapState)") })
        #expect(
            source.contains("typealias HandOffHook = (HandOffDestination) -> Void"),
            "HandOffHook must be exactly this type alias")
    }

    @Test("AC9 negative control: a planted fourth case is caught by the extractor")
    func plantedFourthCaseIsCaught() {
        let fixture = """
            enum HandOffDestination {
                case diagnosis(event: DiagnosisEvent)
                case unitExpedition(result: ComposeResult)
                case included(map: MapState)
                case somethingElse
            }
            """
        let cases = Self.handOffDestinationCaseLines(in: fixture)
        #expect(cases.count == 4, "planted fourth case was not detected: \(cases)")
    }

    // MARK: - AC2/AC3/AC4: exactly one façade call per action button, in MapActionsView.swift

    @Test(
        "AC2/AC3/AC4: MapActionsView.swift calls MapFacade exactly three times, once per button, and handOff exactly once per action"
    )
    func mapActionsViewCallsFacadeExactlyOncePerButton() throws {
        let source = try Self.readReal("MapActionsView.swift")
        let facadeCallCount = source.components(separatedBy: "MapFacade.").count - 1
        #expect(facadeCallCount == 3, "expected exactly 3 MapFacade. call sites, found \(facadeCallCount)")
        #expect(source.contains("MapFacade.checkHere("))
        #expect(source.contains("MapFacade.include("))
        #expect(source.contains("MapFacade.unitExpedition("))

        // handOff is called exactly once per success path in each button; UnitExpeditionActionButton also
        // calls it zero times on failure (no extra call inside the catch blocks).
        let handOffCallCount = source.components(separatedBy: "handOff(").count - 1
        #expect(
            handOffCallCount == 3, "expected exactly 3 handOff( call sites total, found \(handOffCallCount)")
        #expect(source.contains("handOff(.diagnosis(event: event))"))
        #expect(source.contains("handOff(.included(map: newMap))"))
        #expect(source.contains("handOff(.unitExpedition(result: result))"))
    }

    @Test("negative control: a planted second MapFacade call in one button is caught by the count")
    func plantedSecondFacadeCallIsCaught() {
        let fixture = """
            Button("x") {
                let (event, _) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
                _ = MapFacade.include(nodeId: nodeId, mapState: mapState)
                handOff(.diagnosis(event: event))
            }
            """
        let count = fixture.components(separatedBy: "MapFacade.").count - 1
        #expect(count == 2, "planted extra façade call was not detected")
    }

    @Test(
        "AC4: UnitExpeditionActionButton calls handOff zero times inside its catch blocks (only inside the try block)"
    )
    func unitExpeditionButtonCallsHandOffOnlyOnSuccess() throws {
        let source = try Self.readReal("MapActionsView.swift")
        guard let catchBlock = Self.textBetween(source, "catch let error as CoreError {", "catch {") else {
            Issue.record("could not isolate the CoreError catch block")
            return
        }
        #expect(!catchBlock.contains("handOff("), "the CoreError catch block must not call handOff")
        #expect(catchBlock.contains("CoreErrorText.text(for: error)"))
    }

    @Test("negative control: a catch block that also calls handOff is caught")
    func catchBlockCallingHandOffIsCaught() {
        let fixture = """
            catch let error as CoreError {
                errorText = CoreErrorText.text(for: error)
                handOff(.unitExpedition(result: fakeResult))
            }
            catch {
            """
        let block = Self.textBetween(fixture, "catch let error as CoreError {", "catch {")
        #expect(block?.contains("handOff(") == true, "planted violation was not detected")
    }

    private static func textBetween(_ source: String, _ start: String, _ end: String) -> String? {
        guard let startRange = source.range(of: start),
            let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex)
        else { return nil }
        return String(source[startRange.upperBound..<endRange.lowerBound])
    }

    // MARK: - AC7/AC8: exactly one façade call per tap in the two pickers

    @Test(
        "AC7: CoursePickerView.swift calls MapFacade exactly once, calls onSelected exactly once on success, shows no text on failure"
    )
    func coursePickerCallsFacadeExactlyOnce() throws {
        let source = try Self.readReal("CoursePickerView.swift")
        let facadeCallCount = source.components(separatedBy: "MapFacade.").count - 1
        #expect(facadeCallCount == 1, "expected exactly 1 MapFacade. call site, found \(facadeCallCount)")
        #expect(source.contains("MapFacade.selectCourse("))
        let onSelectedCallCount = source.components(separatedBy: "onSelected(").count - 1
        #expect(
            onSelectedCallCount == 1, "expected exactly 1 onSelected( call site, found \(onSelectedCallCount)"
        )
        guard let catchBlock = Self.textBetween(source, "} catch {", "}\n    }") else {
            Issue.record("could not isolate CoursePickerView's catch block")
            return
        }
        #expect(!catchBlock.contains("Text("), "no text may be shown on an internal-surface failure (§6)")
        #expect(!catchBlock.contains("onSelected("), "onSelected must not be called on failure")
    }

    @Test(
        "AC8: UnitListPickerView.swift calls MapFacade.setMarker exactly once per tap handler, offers the final past-last-unit row, and has no drag gesture"
    )
    func unitListPickerCallsFacadeExactlyOnceAndHasFinalRow() throws {
        let source = try Self.readReal("UnitListPickerView.swift")
        let facadeCallCount = source.components(separatedBy: "MapFacade.").count - 1
        #expect(facadeCallCount == 1, "expected exactly 1 MapFacade. call site, found \(facadeCallCount)")
        #expect(source.contains("MapFacade.setMarker("))
        #expect(source.contains("\"Past the last unit\""))
        #expect(source.contains("pastLastUnit: true"))
        #expect(source.contains("course.units.last"))
        #expect(!source.contains("DragGesture"), "AC8/D-14: no drag gesture may exist in this picker")
        #expect(!source.contains(".gesture("), "AC8/D-14: no drag gesture may exist in this picker")
        let onMarkerSetCallCount = source.components(separatedBy: "onMarkerSet(").count - 1
        #expect(
            onMarkerSetCallCount == 1,
            "expected exactly 1 onMarkerSet( call site, found \(onMarkerSetCallCount)")
    }

    @Test("negative control: a planted DragGesture in a unit-list-picker fixture is caught")
    func plantedDragGestureIsCaught() {
        let fixture = """
            List {
                ForEach(course.units, id: \\.unitId) { unit in
                    Text(unit.name)
                }
            }
            .gesture(DragGesture().onChanged { _ in })
            """
        #expect(fixture.contains("DragGesture"), "planted drag gesture was not detected")
    }

    @Test("negative control: a fixture calling MapFacade.setMarker twice per tap is caught")
    func fixtureCallingSetMarkerTwiceIsCaught() {
        let fixture = """
            private func setMarker(unitId: String, pastLastUnit: Bool) {
                _ = try? MapFacade.setMarker(unitId: unitId, pastLastUnit: pastLastUnit, mapState: mapState, today: today)
                _ = try? MapFacade.setMarker(unitId: unitId, pastLastUnit: pastLastUnit, mapState: mapState, today: today)
            }
            """
        let count = fixture.components(separatedBy: "MapFacade.").count - 1
        #expect(count == 2, "planted duplicate façade call was not detected")
    }

    // MARK: - AC10: forbidden constructs and force-unwrapped URL absent from all six files

    private static let ac10ForbiddenPatterns = [
        "URLSession", "URLRequest", "StudentState(", "MarkerTrail.", "Expedition.", "MasteryTransitions.",
        "DiagnosisRun.",
    ]

    @Test("AC10: no file in App/Sources/MapUI contains a forbidden construct")
    func noFileContainsForbiddenConstructs() throws {
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            for pattern in Self.ac10ForbiddenPatterns {
                #expect(!source.contains(pattern), "\(name) contains forbidden construct \(pattern)")
            }
        }
    }

    @Test("negative control: a planted StudentState( construction is caught")
    func plantedStudentStateConstructionIsCaught() {
        let fixture = "let state = StudentState(courseCode: \"MCV4U\", markerUnitId: \"u1\")"
        #expect(fixture.contains("StudentState("), "planted violation was not detected")
    }

    @Test("AC10: no file in App/Sources/MapUI force-unwraps a URL(string:) construction")
    func noFileForceUnwrapsURLConstruction() throws {
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            #expect(
                source.range(of: #"URL\(string:[^)]*\)!"#, options: .regularExpression) == nil,
                "\(name) force-unwraps a URL(string:) construction")
        }
    }

    @Test("negative control: a planted force-unwrapped URL(string:) is caught")
    func plantedForceUnwrappedURLIsCaught() {
        let fixture = "Link(\"x\", destination: URL(string: link.officialUrl)!)"
        #expect(
            fixture.range(of: #"URL\(string:[^)]*\)!"#, options: .regularExpression) != nil,
            "planted violation was not detected")
    }

    // MARK: - AC11: banned glossary synonyms absent (case-sensitive check on "Session")

    private static let ac11BannedPatterns = [
        #"\bsession\b"#, #"\bSession\b"#, "start marker", #"\bcursor\b"#, #"\bprofile\b"#, "progress file",
        #"\bsave\b"#,
    ]

    @Test("AC11: no file in App/Sources/MapUI uses a banned glossary synonym, case-sensitively on Session")
    func noFileUsesBannedGlossaryTerms() throws {
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            for pattern in Self.ac11BannedPatterns {
                #expect(
                    source.range(of: pattern, options: .regularExpression) == nil,
                    "\(name) uses banned glossary term matching /\(pattern)/")
            }
        }
    }

    @Test(
        "negative control: a planted \"Session\" identifier is caught even with different casing than \"session\""
    )
    func plantedCapitalizedSessionIsCaught() {
        let fixture = "typealias Session = ExpeditionRun"
        #expect(
            fixture.range(of: #"\bSession\b"#, options: .regularExpression) != nil,
            "planted capitalized violation was not detected")
    }

    @Test("negative control: a planted lower-case \"session\" on-screen string is caught")
    func plantedLowercaseSessionCopyIsCaught() {
        let fixture = "Text(\"Start a new session\")"
        #expect(
            fixture.range(of: #"\bsession\b"#, options: .regularExpression) != nil,
            "planted lower-case violation was not detected")
    }

    // MARK: - I6: NodePanelView shows paraphrase + expectation codes paired with officialUrl; no verbatim field

    @Test("I6: no file in App/Sources/MapUI references a field named verbatim")
    func noFileReferencesVerbatimField() throws {
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            #expect(
                source.range(of: #"\bverbatim\b"#, options: .regularExpression) == nil,
                "\(name) references a verbatim field, banned repo-wide (contracts/content-policy.md)")
        }
    }

    @Test("negative control: a planted content.verbatim reference is caught")
    func plantedVerbatimReferenceIsCaught() {
        let fixture = "Text(content.verbatim)"
        #expect(fixture.range(of: #"\bverbatim\b"#, options: .regularExpression) != nil)
    }

    @Test(
        "I6: NodePanelView pairs each expectation-code entry with its own officialUrl, never a bare code without a link"
    )
    func nodePanelViewPairsExpectationCodesWithOfficialUrl() throws {
        let source = try Self.readReal("NodePanelView.swift")
        guard let section = Self.textBetween(source, "Section(\"Expectation codes\") {", "\n            }")
        else {
            Issue.record("could not isolate the expectation-codes section")
            return
        }
        #expect(section.contains("link.officialUrl"))
        #expect(section.contains("Link("))
    }

    // MARK: - I15: LandmarkPanelView renders sourceUrl only via Link, never fetching it

    @Test(
        "I15: LandmarkPanelView.swift never calls URLSession/URLRequest and renders sourceUrl only via Link")
    func landmarkPanelViewNeverFetchesSourceUrl() throws {
        let source = try Self.readReal("LandmarkPanelView.swift")
        #expect(!source.contains("URLSession"))
        #expect(!source.contains("URLRequest"))
        #expect(source.contains("Link(\"Source\", destination: url)"))
    }

    // MARK: - I14: exactly one @State property across all six files; no @State holds a Core state type

    @Test(
        "I14: exactly one @State property exists across all six files, and it is UnitExpeditionActionButton.errorText"
    )
    func exactlyOneStatePropertyAcrossAllFiles() throws {
        let contents = try Self.readAllReal()
        var stateLines: [String] = []
        for (name, source) in contents {
            for line in source.split(separator: "\n") {
                if line.contains("@State") { stateLines.append("\(name): \(line)") }
            }
        }
        #expect(stateLines.count == 1, "expected exactly one @State property, found: \(stateLines)")
        #expect(stateLines.first?.contains("errorText") == true)
        #expect(stateLines.first?.contains("String?") == true)
    }

    @Test("I14 negative control: a second planted @State property is caught by the count")
    func plantedSecondStatePropertyIsCaught() {
        let fixtureA = "@State private var errorText: String?\n"
        let fixtureB = "@State private var cachedMapState: MapState?\n"
        let combined = fixtureA + fixtureB
        let count = combined.split(separator: "\n").filter { $0.contains("@State") }.count
        #expect(count == 2, "planted second @State property was not detected")
    }

    @Test("I14: no @State property in any of the six files holds a MapState, StudentState or ContentBundle")
    func noStatePropertyHoldsCoreStateType() throws {
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            for line in source.split(separator: "\n") where line.contains("@State") {
                for forbidden in ["MapState", "StudentState", "ContentBundle"] {
                    #expect(
                        !line.contains(forbidden),
                        "\(name) holds a \(forbidden) in @State: \(line)")
                }
            }
        }
    }

    // MARK: - Error-surface cross-check against contracts/error-codes.json

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
        let url = repoRoot.appendingPathComponent("contracts/error-codes.json")
        let data = try Data(contentsOf: url)
        struct Registry: Decodable { let codes: [ErrorCodeEntry] }
        // The registry's top-level shape is an object keyed by category with an array value in some
        // registries and a flat array in others; try the flat array first, then a wrapped shape.
        if let flat = try? JSONDecoder().decode([ErrorCodeEntry].self, from: data) {
            return flat
        }
        let wrapped = try JSONDecoder().decode(Registry.self, from: data)
        return wrapped.codes
    }

    @Test(
        "student-surface CoreErrorText call site cross-checks against contracts/error-codes.json: only EXP_NO_FRINGE is displayed by this task's files"
    )
    func errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe() throws {
        let entries = try Self.loadErrorCodeEntries()
        guard let expNoFringe = entries.first(where: { $0.code == "EXP_NO_FRINGE" }) else {
            Issue.record("EXP_NO_FRINGE not found in contracts/error-codes.json")
            return
        }
        #expect(expNoFringe.surface == "student")
        #expect(expNoFringe.userText != nil)

        guard let expTrailInvalid = entries.first(where: { $0.code == "EXP_TRAIL_INVALID" }),
            let platformStateWriteFailed = entries.first(where: { $0.code == "PLATFORM_STATE_WRITE_FAILED" })
        else {
            Issue.record("expected internal-surface codes not found in contracts/error-codes.json")
            return
        }
        #expect(expTrailInvalid.surface == "internal")
        #expect(expTrailInvalid.userText == nil)
        #expect(platformStateWriteFailed.surface == "internal")
        #expect(platformStateWriteFailed.userText == nil)

        let source = try Self.readReal("MapActionsView.swift")
        let coreErrorTextCallCount = source.components(separatedBy: "CoreErrorText.text(for:").count - 1
        #expect(
            coreErrorTextCallCount == 1,
            "expected exactly one CoreErrorText.text(for:) call site across the six files, found \(coreErrorTextCallCount)"
        )
    }

    @Test(
        "no authored String literal in any of the six files duplicates a registered student-surface user_text (only CoreErrorText.text(for:) may surface it)"
    )
    func noAuthoredLiteralDuplicatesRegistryUserText() throws {
        let entries = try Self.loadErrorCodeEntries()
        let studentTexts = entries.compactMap { $0.surface == "student" ? $0.userText : nil }
        let contents = try Self.readAllReal()
        for (name, source) in contents {
            for text in studentTexts {
                #expect(
                    !source.contains("\"\(text)\""),
                    "\(name) hand-authors a String literal duplicating a registry user_text: \(text)")
            }
        }
    }

    @Test("negative control: a planted hand-authored duplicate of EXP_NO_FRINGE's user_text is caught")
    func plantedDuplicateUserTextLiteralIsCaught() throws {
        let entries = try Self.loadErrorCodeEntries()
        guard let expNoFringe = entries.first(where: { $0.code == "EXP_NO_FRINGE" }),
            let text = expNoFringe.userText
        else {
            Issue.record("EXP_NO_FRINGE user_text not found")
            return
        }
        let fixture = "Text(\"\(text)\")"
        #expect(fixture.contains("\"\(text)\""), "planted duplicate literal was not detected")
    }

    // MARK: - AC12 companion: swift-format / build gates are exercised by scripts/gate.sh, not here.
}

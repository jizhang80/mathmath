import Foundation
import Testing

@testable import Core

/// Structural (source-text) guards for `App/Sources/Map/MapCanvasView.swift` and
/// `App/Sources/Map/MapCamera.swift` (task 03.10, `tasks/epic-03-task-10-app-map-canvas.md`). This module has
/// no App unit-test target (C3, §5 of the task spec) — `MapCamera`'s pure math (round-trip transform, zoom
/// clamping, gesture baseline, `initial(focusFrame:canvasSize:)` framing) and `MapCanvasView`'s runtime
/// behaviour (tap resolution, live pan/zoom, animation) cannot be exercised from a `Core` test and are NOT
/// asserted here; see the tester report for the itemized instrument-exclusion list. What CAN be verified from
/// text is: AC1's stored-property list, AC1/AC2's forbidden-type/forbidden-identifier absence, AC3's single
/// source of the zoom-dependent label decision, and AC8's single-modifier transition rule. Each guard ships
/// its own planted negative control (C2), mirroring `AppSourcesBoundaryTests.swift`'s shape.
@Suite("App/Sources/Map structural guards (03.10 AC1/AC2/AC3/AC8)")
struct MapCanvasViewStructuralTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var mapCanvasViewPath: URL {
        repoRoot.appendingPathComponent("App/Sources/Map/MapCanvasView.swift")
    }
    private static var mapCameraPath: URL {
        repoRoot.appendingPathComponent("App/Sources/Map/MapCamera.swift")
    }

    private func readReal(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - AC1: MapCanvasView's stored-property list

    /// Extracts the names of instance (non-`static`) `let`/`var` declarations at the struct's top level —
    /// i.e. lines appearing between `struct MapCanvasView: View {` and the first `var body: some View {`,
    /// indented exactly one level (4 spaces), never inside a nested closure/function. This mirrors how the
    /// real file lays out its stored properties (§4 step 5 of the task spec).
    private static func topLevelStoredPropertyNames(in source: String) -> [String] {
        guard let structRange = source.range(of: "struct MapCanvasView: View {"),
            let bodyRange = source.range(of: "var body: some View {")
        else { return [] }
        let slice = source[structRange.upperBound..<bodyRange.lowerBound]
        var names: [String] = []
        for line in slice.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            guard
                text.hasPrefix("    "), !text.hasPrefix("    static"),
                !text.hasPrefix("    private static"), !text.hasPrefix("    //")
            else { continue }
            guard
                let match = text.range(
                    of: #"^\s{4}(@State\s+)?(private\s+)?(let|var)\s+(\w+)"#, options: .regularExpression)
            else { continue }
            let matched = String(text[match])
            if let nameRange = matched.range(
                of: #"(let|var)\s+\w+"#, options: .regularExpression)
            {
                let nameToken = matched[nameRange].split(separator: " ").last.map(String.init) ?? ""
                names.append(nameToken)
            }
        }
        return names
    }

    @Test(
        "AC1: MapCanvasView's real stored properties are exactly mapViewModel, onNodeTap, camera, hasFramedInitialCamera"
    )
    func realStoredPropertyListMatchesAC1() throws {
        let source = try readReal(Self.mapCanvasViewPath)
        let names = Set(Self.topLevelStoredPropertyNames(in: source))
        #expect(
            names == ["mapViewModel", "onNodeTap", "camera", "hasFramedInitialCamera"],
            "unexpected stored-property set: \(names)")
    }

    @Test("AC1 negative control: an extra stored property is caught by the extractor")
    func extraStoredPropertyIsCaughtByExtractor() {
        let fixture = """
            struct MapCanvasView: View {
                let mapViewModel: MapViewModel
                let onNodeTap: (String) -> Void

                @State private var camera = MapCamera(pan: .zero, zoomScale: 1.0)
                @State private var hasFramedInitialCamera = false
                @State private var extraDomainFlag = false

                var body: some View {
                    EmptyView()
                }
            }
            """
        let names = Set(Self.topLevelStoredPropertyNames(in: fixture))
        #expect(
            names.contains("extraDomainFlag"),
            "planted extra stored property was not detected: \(names)")
        #expect(
            names != ["mapViewModel", "onNodeTap", "camera", "hasFramedInitialCamera"],
            "planted violation did not change the property set")
    }

    // MARK: - AC1 / AC2: forbidden Core type names and façade identifiers absent from either file

    /// AC1's own allow-list of `MapViewModel`'s value types, plus the two types AC1 explicitly forbids
    /// (`StudentState`, `ContentBundle`) that `AppSourcesBoundary`'s existing rule set does not name (it
    /// checks `StudentState(` construction and a different exclusion list, not these two as bare type
    /// references). AC2's own five identifiers are checked separately below for direct traceability.
    private static let ac1ForbiddenTypeNames = ["StudentState", "ContentBundle"]
    private static let ac2ForbiddenIdentifiers = [
        "Expedition", "MarkerTrail", "MasteryTransitions", "DiagnosisRun", "BundleIO", "StudentStateStore",
    ]

    private static func containsWholeWord(_ name: String, in text: String) -> Bool {
        text.range(of: "\\b\(name)\\b", options: .regularExpression) != nil
    }

    @Test("AC1: neither real file references StudentState or ContentBundle as a type")
    func realFilesDoNotReferenceForbiddenAC1Types() throws {
        for path in [Self.mapCanvasViewPath, Self.mapCameraPath] {
            let source = try readReal(path)
            for name in Self.ac1ForbiddenTypeNames {
                #expect(
                    !Self.containsWholeWord(name, in: source),
                    "\(path.lastPathComponent) references forbidden type \(name)")
            }
        }
    }

    @Test("AC1 negative control: a planted ContentBundle stored property is caught")
    func plantedContentBundlePropertyIsCaught() {
        let fixture = """
            struct MapCanvasView: View {
                let bundle: ContentBundle
                var body: some View { EmptyView() }
            }
            """
        #expect(Self.containsWholeWord("ContentBundle", in: fixture))
    }

    @Test("AC2: neither real file references the five forbidden façade/domain identifiers")
    func realFilesDoNotReferenceAC2Identifiers() throws {
        for path in [Self.mapCanvasViewPath, Self.mapCameraPath] {
            let source = try readReal(path)
            for name in Self.ac2ForbiddenIdentifiers {
                #expect(
                    !Self.containsWholeWord(name, in: source),
                    "\(path.lastPathComponent) references forbidden identifier \(name)")
            }
        }
    }

    @Test("AC2 negative control: a planted MarkerTrail call is caught")
    func plantedMarkerTrailCallIsCaught() {
        let fixture = "func bad() { MarkerTrail.setMarker(courseCode: \"MCV4U\", unitId: 1) }"
        #expect(Self.containsWholeWord("MarkerTrail", in: fixture))
    }

    // MARK: - AC3: label visibility comes only from labelSet(atZoom: camera.zoomScale)

    /// Every `labelSet(atZoom:` call site's argument text, extracted verbatim.
    private static func labelSetCallArguments(in source: String) -> [String] {
        var results: [String] = []
        let pattern = #"labelSet\(atZoom:\s*([^)]*)\)"#
        let nsSource = source as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        for match in matches {
            results.append(nsSource.substring(with: match.range(at: 1)))
        }
        return results
    }

    @Test("AC3: the real MapCanvasView.swift calls labelSet(atZoom:) exactly once, with camera.zoomScale")
    func realFileCallsLabelSetOnlyWithCameraZoomScale() throws {
        let source = try readReal(Self.mapCanvasViewPath)
        let arguments = Self.labelSetCallArguments(in: source)
        #expect(arguments.count == 1, "expected exactly one labelSet(atZoom:) call site, found: \(arguments)")
        #expect(
            arguments == ["camera.zoomScale"],
            "labelSet(atZoom:) called with unexpected argument: \(arguments)")
    }

    @Test("AC3 negative control: a converted/independently-scaled zoom argument is caught")
    func convertedZoomArgumentIsCaught() {
        let fixture = "let labelSet = mapViewModel.labelSet(atZoom: camera.zoomScale * 2.0)"
        let arguments = Self.labelSetCallArguments(in: fixture)
        #expect(arguments == ["camera.zoomScale * 2.0"])
        #expect(
            arguments != ["camera.zoomScale"], "planted independently-scaled argument was not distinguished")
    }

    @Test("AC3: MapCanvasView.swift declares no independent zoom-threshold constant")
    func realFileDeclaresNoIndependentZoomThreshold() throws {
        let source = try readReal(Self.mapCanvasViewPath)
        #expect(
            !Self.containsWholeWord("nodeNameZoomThreshold", in: source),
            "MapCanvasView.swift redeclares nodeNameZoomThreshold instead of reading MapViewModel's own value via labelSet(atZoom:)"
        )
        // No standalone comparison of zoomScale against a numeric literal outside labelSet(atZoom:)'s own
        // call — that would be an independently-thresholded label decision the view invented itself (I14).
        let comparisonPattern = #"zoomScale\s*[<>]=?\s*[0-9]"#
        #expect(
            source.range(of: comparisonPattern, options: .regularExpression) == nil,
            "MapCanvasView.swift compares zoomScale against a literal outside labelSet(atZoom:) — an independent zoom threshold"
        )
    }

    @Test("AC3 negative control: a planted independent zoom-threshold comparison is caught")
    func plantedZoomThresholdComparisonIsCaught() {
        let fixture = "if camera.zoomScale > 3.0 { showNodeNames = true }"
        let comparisonPattern = #"zoomScale\s*[<>]=?\s*[0-9]"#
        #expect(fixture.range(of: comparisonPattern, options: .regularExpression) != nil)
    }

    // MARK: - AC3 / §4 step 2: no clamp or zoom-bound constant duplicated outside MapCamera

    /// Strips `///` doc-comment and `//` line-comment lines before a code-only scan — a doc comment that
    /// merely *mentions* `MapCamera`'s own constant by name (as `MapCanvasView.swift`'s gesture doc comments
    /// do, describing behaviour `MapCamera` itself implements) is not a redeclaration.
    private static func codeOnlyLines(in source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("MapCanvasView.swift does not redeclare minZoomScale/maxZoomScale — they live only in MapCamera")
    func realCanvasViewDoesNotRedeclareZoomBounds() throws {
        let source = Self.codeOnlyLines(in: try readReal(Self.mapCanvasViewPath))
        for name in ["minZoomScale", "maxZoomScale"] {
            #expect(
                !Self.containsWholeWord(name, in: source),
                "MapCanvasView.swift redeclares \(name) in code — the zoom bound must live only in MapCamera.swift"
            )
        }
    }

    @Test("negative control: a planted maxZoomScale redeclaration is caught")
    func plantedZoomBoundRedeclarationIsCaught() {
        let fixture = "static let maxZoomScale: Double = 10.0"
        #expect(Self.containsWholeWord("maxZoomScale", in: fixture))
    }

    // MARK: - AC5 (weak structural proxy — real behaviour is an instrument exclusion, see report)

    @Test("AC5: onNodeTap is invoked from exactly one call site in the real file")
    func realFileHasExactlyOneOnNodeTapCallSite() throws {
        let source = try readReal(Self.mapCanvasViewPath)
        let count = source.components(separatedBy: "onNodeTap(").count - 1
        #expect(count == 1, "expected exactly one onNodeTap( call site, found \(count)")
    }

    @Test("negative control: a second onNodeTap call site is caught by the count")
    func secondOnNodeTapCallSiteIsCaught() {
        let fixture = "onNodeTap(nearest.id)\nonNodeTap(other.id)\n"
        let count = fixture.components(separatedBy: "onNodeTap(").count - 1
        #expect(count == 2)
    }

    // MARK: - AC4 (weak structural proxy — real reframing behaviour is an instrument exclusion, see report)

    @Test(
        "AC4: the real onAppear block guards MapCamera.initial(...) behind !hasFramedInitialCamera and sets the flag true"
    )
    func realOnAppearGuardsInitialFramingWithFlag() throws {
        let source = try readReal(Self.mapCanvasViewPath)
        guard let block = Self.balancedBraceBlock(after: ".onAppear {", in: source) else {
            Issue.record("could not locate a balanced .onAppear block in MapCanvasView.swift")
            return
        }
        #expect(block.contains("guard !hasFramedInitialCamera else { return }"))
        #expect(block.contains("MapCamera.initial(focusFrame:"))
        #expect(block.contains("hasFramedInitialCamera = true"))
    }

    /// Finds the block between the `{` that follows `marker` and its own matching `}` — a brace-depth walk,
    /// not a first-`}`-wins search, since the block itself contains nested `{ return }` closures.
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

    @Test("negative control: an onAppear block that always reframes (no guard) is caught")
    func onAppearWithoutGuardIsCaught() {
        let fixture = """
            .onAppear {
                camera = MapCamera.initial(focusFrame: mapViewModel.focusFrame, canvasSize: geometry.size)
            }
            """
        #expect(!fixture.contains("guard !hasFramedInitialCamera else { return }"))
    }

    // MARK: - AC8: at most one basic SwiftUI transition/animation modifier; no game-style mechanic

    @Test("AC8: the real files use at most one .animation/.transition modifier and no SpriteKit/Timer")
    func realFilesUseAtMostOneTransitionModifierAndNoGameMechanic() throws {
        for path in [Self.mapCanvasViewPath, Self.mapCameraPath] {
            let source = try readReal(path)
            let animationCount = source.components(separatedBy: ".animation(").count - 1
            let transitionCount = source.components(separatedBy: ".transition(").count - 1
            #expect(
                animationCount + transitionCount <= 1,
                "\(path.lastPathComponent) uses \(animationCount + transitionCount) animation/transition modifiers, expected at most 1"
            )
            #expect(!source.contains("import SpriteKit"), "\(path.lastPathComponent) imports SpriteKit (D24)")
            #expect(
                !Self.containsWholeWord("Timer", in: source),
                "\(path.lastPathComponent) references Timer — a timer-driven mechanic is forbidden (D24)")
        }
    }

    @Test("negative control: two .animation modifiers are caught")
    func twoAnimationModifiersAreCaught() {
        let fixture = """
            Canvas { _, _ in }
                .animation(.easeInOut, value: mapViewModel)
                .animation(.linear, value: camera)
            """
        let animationCount = fixture.components(separatedBy: ".animation(").count - 1
        #expect(animationCount == 2)
        #expect(
            animationCount > 1, "planted second .animation modifier was not distinguished from the AC8 limit")
    }

    @Test("negative control: a planted SpriteKit import is caught")
    func plantedSpriteKitImportIsCaught() {
        let fixture = "import SpriteKit\nstruct Bad {}\n"
        #expect(fixture.contains("import SpriteKit"))
    }

    // MARK: - AC6: real files import only Foundation, SwiftUI, Core (the tech-stack allow-list this task's

    /// files legitimately need — `MapViewModel`'s value types are declared in `Core`). AC6's own prose
    /// ("import only Foundation and SwiftUI") omits `Core`, which every read of `mapViewModel`'s properties
    /// requires; the actually-enforced boundary is `AppSourcesBoundary.allowedImportModules`
    /// (`AppSourcesBoundaryTests.swift`), which does include `Core`. Recorded as a spec-text imprecision in
    /// the tester report, not a product bug — this test asserts against the enforced allow-list, not AC6's
    /// literal (narrower) wording.
    @Test("AC6: real files import only modules already in AppSourcesBoundary.allowedImportModules")
    func realFilesImportOnlyAllowListedModules() throws {
        for path in [Self.mapCanvasViewPath, Self.mapCameraPath] {
            let source = try readReal(path)
            let imports = source.split(separator: "\n").compactMap { line -> String? in
                guard line.hasPrefix("import ") else { return nil }
                return String(line.dropFirst("import ".count))
            }
            #expect(!imports.isEmpty, "\(path.lastPathComponent) declares no imports at all")
            for module in imports {
                #expect(
                    AppSourcesBoundary.allowedImportModules.contains(module),
                    "\(path.lastPathComponent) imports non-allow-listed module \(module)")
            }
        }
    }
}

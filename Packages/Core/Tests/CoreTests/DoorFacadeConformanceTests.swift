import Foundation
import Testing

@testable import Core

/// Tester's own coverage for `tasks/epic-04-task-05-core-door-entries-persistence-seam.md`, filling the gaps
/// the implementer's `DoorEntriesTests.swift`/`DoorFacadeSeamTests.swift` leave open: the write-failure banner
/// text mapping, `continueAfterProbeAnswer`'s no-write guarantee, AC5's hand-off byte-identity case, the I5
/// Mirror scan, the brief-item-8 source-scan proof that the C1 seam reaches `Core` only through `DoorFacade`,
/// T2's malformed-submission boundary case, T5's AC4/AC7 and AC6/AC8 branch negative controls, and T6
/// idempotency. Real `data/demo` and a temp-directory `StudentStateStore`, no stub on either side.
@Suite("DoorFacade conformance (04.5 tester coverage)")
struct DoorFacadeConformanceTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var demoBundleDir: URL { repoRoot.appendingPathComponent("data/demo") }

    private static func loadDemoBundle() throws -> ContentBundle { try BundleIO.read(from: demoBundleDir) }

    private static func today() throws -> CalendarDay {
        try #require(CalendarDay(iso: "2026-09-10"))
    }

    private static func makeTempDir() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private static func mth1wMarker(bundle: ContentBundle) throws -> Marker {
        try #require(MarkerTrail.defaultMarker(syllabi: ["MTH1W"], bundle: bundle))
    }

    private static func mapState(
        bundle: ContentBundle, marker: Marker? = nil, nodes: [String: NodeState] = [:], today: CalendarDay
    ) throws -> (map: MapState, stateURL: URL) {
        let resolvedMarker = try marker ?? Self.mth1wMarker(bundle: bundle)
        let report = try MarkerTrail.generateTrail(
            syllabi: ["MTH1W"], marker: resolvedMarker, bundle: bundle)
        let state = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: ["MTH1W"],
            marker: resolvedMarker, nodes: nodes, trail: report.trail, expeditionLog: [], probeLog: [],
            installDay: "2026-01-01", consentOn: true)
        let tempDir = try Self.makeTempDir()
        let stateURL = tempDir.appendingPathComponent("student-state.json")
        let viewModel = MapViewModel.derive(bundle: bundle, state: state, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: state, viewModel: viewModel, queuedNodeId: nil)
        return (map, stateURL)
    }

    private static func decodeState(at url: URL) throws -> StudentState {
        try CoreCoding.decoder.decode(StudentState.self, from: try Data(contentsOf: url))
    }

    private static func correctSubmission(for item: ProbeItem) -> String {
        item.answer?.value ?? item.correctChoiceId ?? "unknown"
    }

    private static func wrongSubmission(for item: ProbeItem) -> String {
        if item.type == .mc, let correct = item.correctChoiceId,
            let choice = item.choices?.first(where: { $0.id != correct })
        {
            return choice.id
        }
        return item.wrongAnswers?.first?.value ?? "not-a-real-answer"
    }

    private static func item(nodeId: String, isRetry: Bool, bundle: ContentBundle) -> ProbeItem {
        guard let node = bundle.nodes.nodes.first(where: { $0.id == nodeId }) else {
            preconditionFailure("node \(nodeId) not found")
        }
        let items = node.probeItems.sorted { $0.id < $1.id }
        return isRetry ? items[1] : items[0]
    }

    // MARK: - Audit item 3: write-failure banners resolve via CoreErrorText, not duplicated copy

    @Test(
        "AC11: CoreErrorText resolves EXP_STATE_WRITE_FAILED and DIAG_STATE_WRITE_FAILED to the registered banner text"
    )
    func writeFailureCodesResolveToRegisteredBannerText() {
        let expected = "Your progress could not be saved just now; it will be retried."
        #expect(CoreErrorText.text(for: .expStateWriteFailed) == expected)
        #expect(CoreErrorText.text(for: .diagStateWriteFailed) == expected)
    }

    // MARK: - AC6: continueAfterProbeAnswer performs no write (arbiter-04 Q-A, mirrors AC4(b))

    @Test(
        "continueAfterProbeAnswer performs no write; the file at stateURL is byte-identical across the call")
    func continueAfterProbeAnswerNeverWrites() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)

        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        guard case .hypothesis(_, let offer) = opened.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorFacade.decideProbe(
            offer, accept: true, runState: opened.runState, today: today)
        guard case .probeItem(_, let probe) = probeAdvance.advance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let ans = DoorFacade.answerProbeItem(
            probe, submitted: Self.correctSubmission(for: probe.currentItem),
            runState: probeAdvance.runState, today: today)

        let before = try Data(contentsOf: stateURL)
        _ = DoorFacade.continueAfterProbeAnswer(ans.advance, runState: ans.runState)
        let after = try Data(contentsOf: stateURL)
        #expect(before == after, "continueAfterProbeAnswer must not write (arbiter-04 Q-A)")
    }

    // MARK: - AC5: the D27 hand-off's own continueAfterAnswer writes nothing

    @Test(
        "AC5: the specific continueAfterAnswer call that reveals .diagnosis leaves stateURL byte-identical"
    )
    func handoffRevealingDiagnosisWritesNothing() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let cleared = NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: "2026-01-01", nextDue: "2099-01-01",
            ladderRung: 0, remediated: nil)
        let blockedRemediated = NodeState(
            mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: true)
        let marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: false)
        let (built, stateURL) = try Self.mapState(
            bundle: bundle, marker: marker,
            nodes: ["simplifying-expressions": cleared, "exponent-laws": blockedRemediated], today: today)
        let (included, includeOutcome, _) = MapFacade.include(nodeId: "polynomials", mapState: built)
        #expect(includeOutcome == .queued)

        let start = try DoorFacade.startExpedition(mapState: included, today: today)
        var runState = start.runState
        var screen = start.screen
        let targetNodeId = "polynomials"
        var sawDiagnosisReveal = false

        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let submitted =
                content.nodeId == targetNodeId
                ? Self.wrongSubmission(for: item) : Self.correctSubmission(for: item)
            let answer = DoorFacade.answer(runState, submitted: submitted, today: today)
            runState = answer.runState

            let before = try Data(contentsOf: stateURL)
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            let after = try Data(contentsOf: stateURL)
            runState = cont.runState
            screen = cont.screen

            if case .diagnosis = screen {
                #expect(before == after, "the hand-off's own continueAfterAnswer call must not write")
                sawDiagnosisReveal = true
                break
            }
            // Every non-hand-off continueAfterAnswer call is also a no-write call (AC4/AC5's general rule).
            #expect(before == after)
        }
        #expect(sawDiagnosisReveal, "fixture sanity: the second miss on 'polynomials' must reveal .diagnosis")
    }

    // MARK: - I5: no identifying field on DoorRunState / its writeFailureCode-carrying return values

    private static let identifyingPatterns = [
        "student", "device", "session", "uuid", "identifier", "account",
    ]

    private static func fieldNames<T>(of value: T) -> [String] {
        Mirror(reflecting: value).children.compactMap { $0.label }
    }

    @Test("I5: DoorRunState and its MapState/DoorBRunState components carry no identifying field name")
    func i5NoIdentifyingFieldOnDoorRunState() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)

        var names = Self.fieldNames(of: start.runState)
        names += Self.fieldNames(of: start.runState.map)
        if let expedition = start.runState.expedition {
            names += Self.fieldNames(of: expedition)
        }
        // The return tuple itself (advance/runState/screen/writeFailureCode/events labels).
        names += ["runState", "screen", "writeFailureCode", "events"]

        #expect(!names.isEmpty, "instrument broken: Mirror found no fields")
        for name in names {
            for pattern in Self.identifyingPatterns {
                #expect(
                    !name.lowercased().contains(pattern),
                    "field '\(name)' matches identifying pattern '\(pattern)'")
            }
        }
    }

    @Test("I5 guard is load-bearing: a planted 'deviceId'-shaped field name is caught by the same scan")
    func i5GuardCatchesPlantedIdentifierName() {
        let planted = ["deviceId", "sessionToken", "studentUuid"]
        for name in planted {
            let caught = Self.identifyingPatterns.contains { name.lowercased().contains($0) }
            #expect(
                caught, "scan failed to catch planted identifier-shaped name '\(name)' — guard is vacuous")
        }
    }

    // MARK: - Brief item 8: the C1 seam reaches Core only through DoorFacade, never the wrapped types directly

    private static let forbiddenDirectCallPatterns = [
        "ExpeditionRun.", "DiagnosisRun.", "DoorBExpeditionFlow.", "DoorADiagnosisFlow.",
        "Expedition.compose",
    ]

    @Test(
        "brief item 8: DoorFacadeSeamTests.swift (the C1 seam) calls Core only through DoorFacade.*, never through ExpeditionRun/DiagnosisRun/DoorBExpeditionFlow/DoorADiagnosisFlow/Expedition.compose directly"
    )
    func seamTestsReachCoreOnlyThroughDoorFacade() throws {
        let source = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(
                "Packages/Core/Tests/CoreTests/DoorFacadeSeamTests.swift"), encoding: .utf8)
        #expect(source.contains("DoorFacade."), "instrument broken: no DoorFacade call found")
        for pattern in Self.forbiddenDirectCallPatterns {
            #expect(
                !source.contains(pattern),
                "DoorFacadeSeamTests.swift calls '\(pattern)' directly, bypassing DoorFacade")
        }
    }

    @Test(
        "brief item 8 guard is load-bearing: a planted direct 'ExpeditionRun.end(' call is caught by the scan"
    )
    func seamScanGuardCatchesPlantedDirectCall() {
        let planted = "let outcome = ExpeditionRun.end(run: r, state: s, today: t, abandoned: true)"
        let offenders = Self.forbiddenDirectCallPatterns.filter { planted.contains($0) }
        #expect(!offenders.isEmpty, "scan failed to catch a planted direct-call pattern — guard is vacuous")
    }

    // MARK: - T2: a malformed submission never crashes; it is simply a miss

    @Test("T2: DoorFacade.answer never crashes on a non-numeric submission; it is a miss, not a throw")
    func answerWithMalformedSubmissionIsAMissNotACrash() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        guard case .item = start.screen else {
            Issue.record("expected .item")
            return
        }
        let answer = DoorFacade.answer(start.runState, submitted: "abc", today: today)
        #expect(answer.advance.answerCard.correct == false)
        #expect(answer.writeFailureCode == nil)
    }

    @Test(
        "T2: DoorFacade.answerProbeItem never crashes on a non-numeric submission; it is a miss, not a throw"
    )
    func answerProbeItemWithMalformedSubmissionIsAMissNotACrash() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)
        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        guard case .hypothesis(_, let offer) = opened.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorFacade.decideProbe(
            offer, accept: true, runState: opened.runState, today: today)
        guard case .probeItem(_, let probe) = probeAdvance.advance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let ans = DoorFacade.answerProbeItem(
            probe, submitted: "not-a-number", runState: probeAdvance.runState, today: today)
        #expect(ans.advance.itemResult.correct == false)
        #expect(ans.writeFailureCode == nil)
    }

    // MARK: - T5 negative control: AC4/AC7's final-vs-write-ahead branch is load-bearing

    @Test(
        "T5 negative control: always persisting the write-ahead value instead of the run's final entry leaves abandoned:true where the real implementation leaves false"
    )
    func negativeControlAlwaysWriteAheadInsteadOfFinalEntry() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        var runState = start.runState
        var screen = start.screen
        var lastAdvance: DoorBAnswerAdvance?

        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let answer = DoorFacade.answer(
                runState, submitted: Self.correctSubmission(for: item), today: today)
            runState = answer.runState
            lastAdvance = answer.advance
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: runState)
            runState = cont.runState
            screen = cont.screen
        }
        guard case .summary = screen else {
            Issue.record("expected .summary")
            return
        }
        // Real implementation: the file's final entry is abandoned == false.
        let realFinal = try Self.decodeState(at: stateURL)
        #expect(realFinal.expeditionLog.count == 1)
        #expect(realFinal.expeditionLog[0].abandoned == false)

        // Locally reconstructed "broken" variant (test-file-only): always persists the write-ahead value,
        // even though `pendingEnd` was present on the run's last answer call.
        let finalAnswer = try #require(lastAdvance)
        #expect(finalAnswer.pendingEnd != nil, "fixture sanity: the last answer call must have ended the run")
        let broken = DoorBWriteAhead.provisionalAbandonedState(
            runState: finalAnswer.runState, state: finalAnswer.state, today: today)
        #expect(
            broken.expeditionLog[0].abandoned == true,
            "the write-ahead branch is load-bearing: skipping it would leave abandoned:true on a naturally-ended run"
        )
    }

    // MARK: - T5 negative control: AC6/AC8's write-ahead-vs-plain branch is load-bearing

    @Test(
        "T5 negative control: wrapping a standalone map_check_here write with write-ahead logic produces a nonsensical expedition_log entry where the real implementation writes plainly"
    )
    func negativeControlWriteAheadWrapOnStandaloneCheckHereIsWrong() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)

        // Real implementation: checkHere with runState.expedition == nil writes plainly — no expedition_log
        // entry appears for an event with no run.
        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        #expect(opened.runState.expedition == nil)
        let realDecoded = try Self.decodeState(at: stateURL)
        #expect(
            realDecoded.expeditionLog.isEmpty,
            "a standalone map_check_here event logs no expedition_log entry")

        // Locally reconstructed "broken" variant (test-file-only): pretends a run is active and wraps the
        // same state with write-ahead logic anyway, using a synthetic run started from the same map. This is
        // exactly the shape `persistDoorA`'s `expedition == nil ? plain : write-ahead` branch prevents.
        let compose = try Expedition.compose(
            state: built.state, bundle: built.bundle, trail: built.state.trail, marker: built.state.marker,
            today: today, queuedNodeId: nil, unitExpeditionUnitId: nil)
        let syntheticStart = DoorBExpeditionFlow.start(compose: compose)
        let wronglyWrapped = DoorBWriteAhead.provisionalAbandonedState(
            runState: syntheticStart.runState, state: opened.runState.map.state, today: today)
        #expect(
            wronglyWrapped.expeditionLog.count == 1 && wronglyWrapped.expeditionLog[0].abandoned == true,
            "the plain-write branch is load-bearing: wrapping unconditionally would fabricate a bogus abandoned run entry for an event with no run"
        )
    }

    // MARK: - T6 idempotency: continue calls are pure and repeatable; no write occurs on either call

    /// The field-wise comparison mandated by arbiter ruling `arbiter-04-doorrunstate-equatable.md` §5.1 E2:
    /// `DoorRunState`/`MapState` are deliberately not `Equatable` (04.5 §4.1), so a whole-value `==` does not
    /// compile. This compares the five named fields — `map.state`, `map.viewModel`, `map.queuedNodeId`,
    /// `map.stateURL` and `expedition` (internal, reached via `@testable import Core`) — and returns the names
    /// of any that disagree, so both the positive assertion (empty list) and the negative control (non-empty
    /// list) can use the same instrument.
    private static func differingRunStateFields(_ a: DoorRunState, _ b: DoorRunState) -> [String] {
        var differing: [String] = []
        if a.map.state != b.map.state { differing.append("map.state") }
        if a.map.viewModel != b.map.viewModel { differing.append("map.viewModel") }
        if a.map.queuedNodeId != b.map.queuedNodeId { differing.append("map.queuedNodeId") }
        if a.map.stateURL != b.map.stateURL { differing.append("map.stateURL") }
        if a.expedition != b.expedition { differing.append("expedition") }
        return differing
    }

    @Test(
        "T6: continueAfterAnswer called twice on the same pending value and input DoorRunState returns == screen and field-wise agreeing runState; neither call writes"
    )
    func continueAfterAnswerCalledTwiceIsIdempotentAndNeverWrites() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, stateURL) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        guard case .item(let content) = start.screen else {
            Issue.record("expected .item")
            return
        }
        let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
        let answer = DoorFacade.answer(
            start.runState, submitted: Self.correctSubmission(for: item), today: today)

        let before = try Data(contentsOf: stateURL)
        let first = DoorFacade.continueAfterAnswer(answer.advance, runState: answer.runState)
        let afterFirst = try Data(contentsOf: stateURL)
        let second = DoorFacade.continueAfterAnswer(answer.advance, runState: answer.runState)
        let afterSecond = try Data(contentsOf: stateURL)

        #expect(before == afterFirst, "continueAfterAnswer must not write")
        #expect(before == afterSecond, "a repeated continueAfterAnswer call must not write either")
        #expect(first.screen == second.screen)
        #expect(
            Self.differingRunStateFields(first.runState, second.runState).isEmpty,
            "the two continueAfterAnswer calls must agree on every field")
    }

    // MARK: - T6 negative control: the field-wise comparison can go red

    @Test(
        "T6 negative control: comparing a continueAfterAnswer result against the preceding answer's DoorRunState finds a differing field, proving the helper is load-bearing"
    )
    func differingRunStateFieldsHelperCanGoRed() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        var runState = start.runState
        var screen = start.screen
        var lastAnswerAdvance: DoorBAnswerAdvance?
        var lastAnswerRunState: DoorRunState?

        // Drive the run to its natural end: the run's last `answer` call resolves `pendingEnd`, so its
        // `runState.map.state` (the write-ahead value) differs from the value `continueAfterAnswer` returns
        // (the run's final `abandoned: false` entry) — the same distinction T5's negative control exercises.
        while case .item(let content) = screen {
            let item = Self.item(nodeId: content.nodeId, isRetry: content.isRetry, bundle: bundle)
            let answer = DoorFacade.answer(
                runState, submitted: Self.correctSubmission(for: item), today: today)
            lastAnswerAdvance = answer.advance
            lastAnswerRunState = answer.runState
            let cont = DoorFacade.continueAfterAnswer(answer.advance, runState: answer.runState)
            runState = cont.runState
            screen = cont.screen
        }
        guard case .summary = screen else {
            Issue.record("fixture sanity: expected the run to reach .summary")
            return
        }
        let finalAdvance = try #require(lastAnswerAdvance)
        let precedingAnswerRunState = try #require(lastAnswerRunState)
        #expect(
            finalAdvance.pendingEnd != nil, "fixture sanity: the last answer call must have ended the run")
        let cont = DoorFacade.continueAfterAnswer(finalAdvance, runState: precedingAnswerRunState)

        let offenders = Self.differingRunStateFields(cont.runState, precedingAnswerRunState)
        #expect(
            !offenders.isEmpty,
            "the comparison never differs between the pre-answer and post-continue run states — the helper cannot go red"
        )
        for field in offenders {
            #expect(
                field == "map.state" || field == "expedition",
                "unexpected differing field '\(field)' (arbiter ruling names only map.state or expedition)")
        }
    }

    // MARK: - T6: continueAfterProbeAnswer called twice returns == DoorADiagnosisScreen values

    @Test(
        "T6: continueAfterProbeAnswer called twice on the same pending value returns == DoorADiagnosisScreen values"
    )
    func continueAfterProbeAnswerCalledTwiceReturnsEqualScreens() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)

        let opened = DoorFacade.checkHere(nodeId: "polynomials", mapState: built, today: today)
        guard case .hypothesis(_, let offer) = opened.screen else {
            Issue.record("expected .hypothesis")
            return
        }
        let probeAdvance = DoorFacade.decideProbe(
            offer, accept: true, runState: opened.runState, today: today)
        guard case .probeItem(_, let probe) = probeAdvance.advance.screen else {
            Issue.record("expected .probeItem")
            return
        }
        let ans = DoorFacade.answerProbeItem(
            probe, submitted: Self.correctSubmission(for: probe.currentItem),
            runState: probeAdvance.runState, today: today)

        let first = DoorFacade.continueAfterProbeAnswer(ans.advance, runState: ans.runState)
        let second = DoorFacade.continueAfterProbeAnswer(ans.advance, runState: ans.runState)
        #expect(first == second, "continueAfterProbeAnswer must be idempotent across repeated calls")
    }

    // MARK: - T6 idempotency / determinism: two independently-constructed calls produce byte-identical files

    @Test(
        "T6: two independent DoorFacade.answer calls with freshly-constructed, value-identical arguments produce byte-identical written files"
    )
    func twoIndependentAnswerCallsProduceByteIdenticalFiles() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()

        let (builtA, stateURLA) = try Self.mapState(bundle: bundle, today: today)
        let startA = try DoorFacade.startExpedition(mapState: builtA, today: today)
        guard case .item(let contentA) = startA.screen else {
            Issue.record("expected .item")
            return
        }
        let itemA = Self.item(nodeId: contentA.nodeId, isRetry: contentA.isRetry, bundle: bundle)
        _ = DoorFacade.answer(startA.runState, submitted: Self.correctSubmission(for: itemA), today: today)

        let (builtB, stateURLB) = try Self.mapState(bundle: bundle, today: today)
        let startB = try DoorFacade.startExpedition(mapState: builtB, today: today)
        guard case .item(let contentB) = startB.screen else {
            Issue.record("expected .item")
            return
        }
        let itemB = Self.item(nodeId: contentB.nodeId, isRetry: contentB.isRetry, bundle: bundle)
        _ = DoorFacade.answer(startB.runState, submitted: Self.correctSubmission(for: itemB), today: today)

        let dataA = try Data(contentsOf: stateURLA)
        let dataB = try Data(contentsOf: stateURLB)
        #expect(dataA == dataB, "two value-identical DoorFacade sequences must write byte-identical files")
    }

    // MARK: - Deviation confirmation: no AC depends on DoorRunState being Equatable

    @Test(
        "DoorRunState components are compared piecewise (map.state, map.queuedNodeId, expedition); this compiles without DoorRunState itself being Equatable"
    )
    func doorRunStateComparedByComponentNotAsAWhole() throws {
        let bundle = try Self.loadDemoBundle()
        let today = try Self.today()
        let (built, _) = try Self.mapState(bundle: bundle, today: today)
        let start = try DoorFacade.startExpedition(mapState: built, today: today)
        let again = try DoorFacade.startExpedition(mapState: built, today: today)
        // DoorBRunState (the `expedition` field) IS Equatable (04.4 AC-quoted signature) and StudentState IS
        // Equatable; MapState is not (it embeds ContentBundle/MapViewModel), matching the implementer's
        // reported deviation. Component-wise comparison is therefore the correct, compiling idiom here.
        #expect(start.runState.expedition == again.runState.expedition)
        #expect(start.runState.map.state == again.runState.map.state)
        #expect(start.runState.map.queuedNodeId == again.runState.map.queuedNodeId)
    }
}

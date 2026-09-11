import Core
import SwiftUI

/// The App's single `@Observable` holder over the current map session (arbiter-03 § Q-F: "one `@Observable`
/// holder that stores the current `Core` session value and replaces it with each façade result, never deriving
/// from it"). `mapState` is replaced wholesale by every façade call's result — never partially mutated here.
@Observable
final class MapStateHolder {
    private(set) var mapState: MapState?
    func replace(with newValue: MapState) { mapState = newValue }
}

/// The Door B render phase `DoorRunHolder` presents: either a screen `DoorFacade` returned, or the pending
/// answer card `DoorFacade.answer`/`DoorFacade.answerProbeItem` returned, until the continue control's tap
/// replaces it (I3).
enum DoorBPhase: Equatable {
    case screen(DoorBScreen)
    case answerCard(DoorBAnswerAdvance)
    case diagnosisAnswerCard(DoorAProbeAnswerAdvance)
}

/// One Door B run's presentation state (§1: never named `*Session*`, `contracts/domain-glossary.md:29`).
/// Not `Equatable`: it holds a `DoorRunState`, which is not `Equatable` (04.5 §4.1,
/// `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`).
struct DoorBRunSnapshot {
    let runState: DoorRunState
    let phase: DoorBPhase
    let writeFailureCode: String?
    /// True only for a diagnosis event opened via `.diagnosisStarted` (a standalone `map_check_here` event with
    /// no suspended expedition). False for every expedition run, including one that later reveals a diagnosis
    /// screen via the D27 hand-off. A provenance tag this file itself sets once, at construction — never a
    /// re-derivation of `DoorRunState.expedition` (which is Core-internal and unreadable from `App/Sources`,
    /// §6 default 1).
    let isStandaloneDiagnosis: Bool
}

/// The App's ephemeral `@Observable` holder over the current Door B run, mirroring `MapStateHolder`'s own
/// "replaced wholesale" discipline (arbiter-03 § Q-F).
@Observable
final class DoorRunHolder {
    private(set) var current: DoorBRunSnapshot?
    func replace(with newValue: DoorBRunSnapshot) { current = newValue }
    func clear() { current = nil }
}

/// The App's launch shell (EPIC 03 task 03.12): resolves the embedded snapshot URL and the Application
/// Support state-file URL, reads today from the device calendar, calls `MapLaunch.open`, and renders the
/// refusal screen, the course picker, or the map screen. Composes 03.7's `MapLaunch`/`MapFacade`, 03.10's
/// `MapCanvasView` and 03.11's panels/pickers only — no domain logic of its own (I14).
struct AppShell: View {
    static let stateFileName = "student-state.json"

    private enum Phase {
        case launching
        case courseSelection(bundle: ContentBundle, previousState: StudentState?, unreadable: Bool)
        case ready
        case refused(BundleRefusal)
    }

    @State private var holder = MapStateHolder()
    @State private var doorHolder = DoorRunHolder()
    @State private var phase: Phase = .launching
    private let today = AppShell.resolveToday()

    var body: some View {
        Group {
            switch phase {
            case .launching:
                ProgressView()
            case .refused(let refusal):
                RefusalView(refusal: refusal)
            case .courseSelection(let bundle, let previousState, let unreadable):
                VStack {
                    if unreadable, let text = CoreErrorText.text(for: .platformStateUnreadable) {
                        Text(text)
                    }
                    CoursePickerView(
                        bundle: bundle, stateURL: Self.resolveStateURL(), previousState: previousState,
                        today: today,
                        onSelected: { map in
                            holder.replace(with: map)
                            phase = .ready
                        })
                }
            case .ready:
                MapScreen(
                    holder: holder, today: today, handOff: handOff,
                    onChangeCourse: { bundle, state in
                        phase = .courseSelection(bundle: bundle, previousState: state, unreadable: false)
                    }
                )
                .fullScreenCover(
                    isPresented: Binding(
                        get: { doorHolder.current != nil }, set: { if !$0 { doorHolder.clear() } })
                ) {
                    DoorBRunScreen(
                        holder: doorHolder, mapHolder: holder, today: today,
                        onDismiss: { doorHolder.clear() })
                }
            }
        }
        .onAppear(perform: launch)
    }

    private func launch() {
        let outcome = MapLaunch.open(
            snapshotDir: Self.resolveSnapshotDir(), stateURL: Self.resolveStateURL(), today: today)
        switch outcome {
        case .ready(let map, _, _):
            holder.replace(with: map)
            phase = .ready
        case .courseSelectionNeeded(let bundle, let messages, _):
            // Silent load-path marker reset (arbiter-03 § Q-A): `messages` is rendered generically — this
            // is the only code this task ever names, and only because it has registered student-surface text.
            // MAP_MARKER_OFF_TRAIL / EXP_NODE_NOT_IN_GRAPH are never in `messages` on the load path (03.7's
            // own guarantee); this task does not special-case them.
            phase = .courseSelection(
                bundle: bundle, previousState: nil,
                unreadable: messages.contains("PLATFORM_STATE_UNREADABLE"))
        case .refused(let refusal):
            phase = .refused(refusal)
        }
    }

    private func handOff(_ destination: HandOffDestination) {
        switch destination {
        case .included(let map):
            holder.replace(with: map)
        case .doorBStarted(let outcome):
            doorHolder.replace(
                with: DoorBRunSnapshot(
                    runState: outcome.runState, phase: .screen(outcome.screen),
                    writeFailureCode: outcome.writeFailureCode, isStandaloneDiagnosis: false))
        case .diagnosisStarted(let outcome):
            doorHolder.replace(
                with: DoorBRunSnapshot(
                    runState: outcome.runState, phase: .screen(.diagnosis(outcome.screen)),
                    writeFailureCode: outcome.writeFailureCode, isStandaloneDiagnosis: true))
        }
    }

    static func resolveSnapshotDir() -> URL {
        // Xcode's file-system-synchronized group copies `App/Sources/DemoSnapshot`'s JSON files flat into the
        // built product's resource root — it does not preserve a `DemoSnapshot` subdirectory (confirmed against
        // the real built `.app` by `scripts/sim-smoke.sh`'s embedded-snapshot `cmp`, §6 decision default).
        guard let resourcePath = Bundle.main.resourcePath else {
            fatalError("Bundle.main.resourcePath is nil — the app bundle is malformed")
        }
        return URL(fileURLWithPath: resourcePath)
    }

    static func resolveStateURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent(stateFileName)
    }

    static func resolveToday() -> CalendarDay {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let iso = formatter.string(from: Date())
        guard let day = CalendarDay(iso: iso) else {
            fatalError("device calendar produced an unparsable date: \(iso)")
        }
        return day
    }
}

/// The "ready" surface: 03.10's `MapCanvasView` over the current `MapState.viewModel`, with 03.11's node panel
/// and unit-list picker presented as sheets. Region/landmark panels have no trigger surface here — 03.10's
/// `MapCanvasView` ships a node-tap callback only (03.10 §6 decision default); this is a known, intentionally
/// deferred gap, not a Q5.
private struct MapScreen: View {
    let holder: MapStateHolder
    let today: CalendarDay
    let handOff: HandOffHook
    let onChangeCourse: (ContentBundle, StudentState) -> Void

    @State private var openNodeId: String?
    @State private var showingUnitPicker = false

    var body: some View {
        if let mapState = holder.mapState {
            MapCanvasView(mapViewModel: mapState.viewModel) { nodeId in openNodeId = nodeId }
                .toolbar {
                    ToolbarItem { Button("Set marker") { showingUnitPicker = true } }
                    ToolbarItem {
                        Button("Change course") { onChangeCourse(mapState.bundle, mapState.state) }
                    }
                    ToolbarItem {
                        StartExpeditionActionButton(mapState: mapState, today: today, handOff: handOff)
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { openNodeId != nil }, set: { if !$0 { openNodeId = nil } })
                ) {
                    if let nodeId = openNodeId,
                        let (content, _) = MapFacade.nodePanelContent(nodeId: nodeId, mapState: mapState)
                    {
                        NodePanelView(content: content, mapState: mapState, handOff: handOff)
                    }
                }
                .sheet(isPresented: $showingUnitPicker) {
                    if let course = mapState.bundle.courses.courses.first(where: {
                        $0.courseCode == mapState.state.marker.courseCode
                    }) {
                        UnitListPickerView(
                            course: course, mapState: mapState, today: today,
                            onMarkerSet: { newMap in
                                holder.replace(with: newMap)
                                showingUnitPicker = false
                            })
                    }
                }
        } else {
            EmptyView()
        }
    }
}

/// The Door B (expedition) run screen: a pure phase switcher over `DoorRunHolder.current`, composing 04.8's and
/// 04.9's `App/Sources/Doors` views. Every state-changing action calls exactly one `DoorFacade` entry point
/// (I14), except the standalone terminal's return, which needs none (04.5 AC8).
private struct DoorBRunScreen: View {
    let holder: DoorRunHolder
    let mapHolder: MapStateHolder
    let today: CalendarDay
    let onDismiss: () -> Void

    @State private var viewState = DoorBViewState()

    var body: some View {
        if let current = holder.current {
            content(for: current)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func content(for current: DoorBRunSnapshot) -> some View {
        switch current.phase {
        case .screen(.item(let item)):
            ExpeditionItemView(
                content: item, keypadInput: $viewState.keypadInput,
                onSubmitNumeric: { submitted in submit(submitted, current: current) },
                onSubmitChoice: { submitted in submit(submitted, current: current) })
        case .screen(.diagnosis(let diagnosisScreen)):
            diagnosisContent(for: diagnosisScreen, current: current)
        case .screen(.summary(let summary)):
            ExpeditionSummaryView(
                summary: summary,
                writeFailureText: current.writeFailureCode.flatMap {
                    CoreError(rawValue: $0).flatMap(CoreErrorText.text(for:))
                },
                startAnotherErrorText: viewState.startAnotherErrorText,
                onStartAnother: { startAnother(current: current) },
                onBackToMap: { backToMap(current: current) })
        case .answerCard(let advance):
            ExpeditionAnswerCardView(content: advance.answerCard) {
                continueTapped(advance, current: current)
            }
        case .diagnosisAnswerCard(let advance):
            ExpeditionAnswerCardView(content: advance.answerCard) {
                continueDiagnosisTapped(advance, current: current)
            }
        }
    }

    @ViewBuilder
    private func writeFailureBanner(_ current: DoorBRunSnapshot) -> some View {
        if let code = current.writeFailureCode, let coreError = CoreError(rawValue: code),
            let text = CoreErrorText.text(for: coreError)
        {
            Text(text)
        }
    }

    @ViewBuilder
    private func diagnosisContent(for screen: DoorADiagnosisScreen, current: DoorBRunSnapshot) -> some View {
        VStack {
            writeFailureBanner(current)
            switch screen {
            case .hypothesis(let content, let offer):
                HypothesisCardView(content: content) { accept in
                    decideProbe(offer, accept: accept, current: current)
                }
            case .probeItem(let content, let probe):
                ExpeditionItemView(
                    content: content, keypadInput: $viewState.keypadInput,
                    onSubmitNumeric: { submitted in
                        answerProbeItem(probe, submitted: submitted, current: current)
                    },
                    onSubmitChoice: { submitted in
                        answerProbeItem(probe, submitted: submitted, current: current)
                    })
            case .furtherLevelOffer(let remediation, let offer, let decision):
                DiagnosisReturnView(
                    content: .furtherLevelOffer(remediation: remediation, offer: offer),
                    onFurtherLevelDecision: { accept in
                        decideFurtherLevel(decision, accept: accept, current: current)
                    },
                    onReturn: {})
            case .terminal(let terminalContent):
                DiagnosisReturnView(
                    content: .terminal(terminalContent),
                    onFurtherLevelDecision: { _ in },
                    onReturn: { returnFromDiagnosis(outcome: terminalContent.outcome, current: current) })
            }
        }
    }

    private func submit(_ value: String, current: DoorBRunSnapshot) {
        let (advance, runState, failure) = DoorFacade.answer(current.runState, submitted: value, today: today)
        viewState.keypadInput = ""
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .answerCard(advance), writeFailureCode: failure,
                isStandaloneDiagnosis: false))
    }

    private func continueTapped(_ advance: DoorBAnswerAdvance, current: DoorBRunSnapshot) {
        let (screen, runState) = DoorFacade.continueAfterAnswer(advance, runState: current.runState)
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .screen(screen), writeFailureCode: nil,
                isStandaloneDiagnosis: false))
    }

    private func startAnother(current: DoorBRunSnapshot) {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startAnother(
                mapState: current.runState.map, today: today)
            viewState.startAnotherErrorText = nil
            holder.replace(
                with: DoorBRunSnapshot(
                    runState: runState, phase: .screen(screen), writeFailureCode: failure,
                    isStandaloneDiagnosis: false))
        } catch let error as CoreError {
            viewState.startAnotherErrorText = CoreErrorText.text(for: error)
        } catch {
            viewState.startAnotherErrorText = nil
        }
    }

    private func backToMap(current: DoorBRunSnapshot) {
        let (mapState, _) = DoorFacade.backToMap(current.runState, today: today)
        mapHolder.replace(with: mapState)
        onDismiss()
    }

    private func decideProbe(_ offer: ProbeOffer, accept: Bool, current: DoorBRunSnapshot) {
        let (advance, runState, failure) = DoorFacade.decideProbe(
            offer, accept: accept, runState: current.runState, today: today)
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .screen(.diagnosis(advance.screen)), writeFailureCode: failure,
                isStandaloneDiagnosis: current.isStandaloneDiagnosis))
    }

    private func answerProbeItem(_ probe: ProbeInProgress, submitted: String, current: DoorBRunSnapshot) {
        let (advance, runState, failure) = DoorFacade.answerProbeItem(
            probe, submitted: submitted, runState: current.runState, today: today)
        viewState.keypadInput = ""
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .diagnosisAnswerCard(advance), writeFailureCode: failure,
                isStandaloneDiagnosis: current.isStandaloneDiagnosis))
    }

    private func continueDiagnosisTapped(_ advance: DoorAProbeAnswerAdvance, current: DoorBRunSnapshot) {
        let screen = DoorFacade.continueAfterProbeAnswer(advance, runState: current.runState)
        holder.replace(
            with: DoorBRunSnapshot(
                runState: current.runState, phase: .screen(.diagnosis(screen)), writeFailureCode: nil,
                isStandaloneDiagnosis: current.isStandaloneDiagnosis))
    }

    private func decideFurtherLevel(_ offer: FurtherLevelOffer, accept: Bool, current: DoorBRunSnapshot) {
        let (advance, runState, failure) = DoorFacade.decideFurtherLevel(
            offer, accept: accept, runState: current.runState, today: today)
        holder.replace(
            with: DoorBRunSnapshot(
                runState: runState, phase: .screen(.diagnosis(advance.screen)), writeFailureCode: failure,
                isStandaloneDiagnosis: current.isStandaloneDiagnosis))
    }

    private func returnFromDiagnosis(outcome: DiagnosisOutcome, current: DoorBRunSnapshot) {
        if current.isStandaloneDiagnosis {
            // 04.5 AC8: no `resumeAfterDiagnosis` call exists or is needed for a standalone `map_check_here`
            // event — `current.runState.map` already carries the last state 04.5's Door A calls persisted.
            mapHolder.replace(with: current.runState.map)
            onDismiss()
        } else {
            let (advance, runState, failure) = DoorFacade.resumeAfterDiagnosis(
                current.runState, outcome: outcome, today: today)
            holder.replace(
                with: DoorBRunSnapshot(
                    runState: runState, phase: .screen(advance.screen), writeFailureCode: failure,
                    isStandaloneDiagnosis: false))
        }
    }
}

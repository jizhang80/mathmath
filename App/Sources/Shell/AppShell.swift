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
                    })
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
        case .diagnosis, .unitExpedition:
            break  // EPIC 04 (tasks 04.8/04.9) replaces this with a real screen.
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

import Core
import SwiftUI

/// EPIC 04 task 04.9 replaces the `.diagnosis` destination this enum stands in for
/// (`docs/epics/epic-03-app-map-shell.md` § 2). Each case carries exactly the value its façade call
/// already returns — nothing this task invents.
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case doorBStarted(DoorBStartOutcome)
    case included(map: MapState)
}

typealias HandOffHook = (HandOffDestination) -> Void

/// The payload `.doorBStarted` carries — one `DoorFacade` start call's result, unchanged, for `AppShell` to
/// hand to its `DoorRunHolder`. Not `Equatable`: it holds a `DoorRunState`, which is not `Equatable`
/// (04.5 §4.1, `tasks/arbitration/arbiter-04-doorrunstate-equatable.md`).
struct DoorBStartOutcome {
    let runState: DoorRunState
    let screen: DoorBScreen
    let writeFailureCode: String?
}

/// Map W2 step 2, the `blocked`/upstream branch: opens diagnosis (D28) on this node.
struct CheckHereActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Check me here") {
            let (event, _) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
            handOff(.diagnosis(event: event))
        }
    }
}

/// Map W2 step 2, the fogged-and-reachable branch (map Q5): queues the node ahead of the scheduler's
/// pick, or is ignored with no student text if it is upstream of the marker — either way the returned
/// `MapState` already carries the only signal that matters (`queuedNodeId`).
struct IncludeActionButton: View {
    let nodeId: String
    let mapState: MapState
    let handOff: HandOffHook

    var body: some View {
        Button("Include in my next expedition") {
            let (newMap, _, _) = MapFacade.include(nodeId: nodeId, mapState: mapState)
            handOff(.included(map: newMap))
        }
    }
}

/// D46, expedition W6: a reusable component; which screen instantiates it, and with which `unitId`, is
/// left to a later task (§6). On `CoreError.expNoFringe` (the only student-surface code among this
/// task's façade calls) it shows the registered text; every other thrown code is discarded, per the
/// internal-surface rule (`contracts/error-codes.md` § Rules).
struct UnitExpeditionActionButton: View {
    let unitId: String
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook

    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Unit expedition") { start() }
            if let errorText {
                Text(errorText)
            }
        }
    }

    private func start() {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startUnitExpedition(
                unitId: unitId, mapState: mapState, today: today)
            errorText = nil
            handOff(
                .doorBStarted(
                    DoorBStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}

/// The domain doc's own name for the map entry point into Door B (`docs/domains/expedition.md`: "Entered
/// from the Map 'Start expedition' button"), identical in shape to `UnitExpeditionActionButton`.
struct StartExpeditionActionButton: View {
    let mapState: MapState
    let today: CalendarDay
    let handOff: HandOffHook

    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading) {
            Button("Start expedition") { start() }
            if let errorText {
                Text(errorText)
            }
        }
    }

    private func start() {
        do {
            let (runState, screen, failure, _) = try DoorFacade.startExpedition(
                mapState: mapState, today: today)
            errorText = nil
            handOff(
                .doorBStarted(
                    DoorBStartOutcome(runState: runState, screen: screen, writeFailureCode: failure)))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}

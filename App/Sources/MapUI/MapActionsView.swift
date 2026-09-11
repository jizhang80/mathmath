import Core
import SwiftUI

/// EPIC 04 (tasks 04.8/04.9) replaces the destinations this enum stands in for
/// (`docs/epics/epic-03-app-map-shell.md` § 2). Each case carries exactly the value its façade call
/// already returns — nothing this task invents.
enum HandOffDestination {
    case diagnosis(event: DiagnosisEvent)
    case unitExpedition(result: ComposeResult)
    case included(map: MapState)
}

typealias HandOffHook = (HandOffDestination) -> Void

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
            let (result, _) = try MapFacade.unitExpedition(unitId: unitId, mapState: mapState, today: today)
            errorText = nil
            handOff(.unitExpedition(result: result))
        } catch let error as CoreError {
            errorText = CoreErrorText.text(for: error)
        } catch {
            errorText = nil
        }
    }
}

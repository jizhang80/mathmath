import Core
import SwiftUI

/// The node panel (map W2 step 1): name, `paraphrase`, expectation codes with the official link (I6),
/// mastery state in plain words, which courses walk through here, and linked landmarks (as raw ids —
/// §6). Offers exactly one action by state (step 2), read from `mapState.viewModel.nodes` — a
/// presentation-only id lookup over an already-derived array, never a re-derivation (I14).
struct NodePanelView: View {
    let content: NodePanelContent
    let mapState: MapState
    let handOff: HandOffHook

    private var action: NodeAction? {
        mapState.viewModel.nodes.first(where: { $0.id == content.nodeId })?.action
    }

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.paraphrase)
                Text(content.masteryLabel)
            }
            if !content.expectationCodeLinks.isEmpty {
                Section("Expectation codes") {
                    ForEach(content.expectationCodeLinks, id: \.code) { link in
                        if let url = URL(string: link.officialUrl) {
                            Link("\(link.courseCode) \(link.code)", destination: url)
                        } else {
                            Text("\(link.courseCode) \(link.code)")
                        }
                    }
                }
            }
            if !content.courseCodesCrossingHere.isEmpty {
                Section("Courses that walk through here") {
                    ForEach(content.courseCodesCrossingHere, id: \.self) { Text($0) }
                }
            }
            if !content.landmarkIds.isEmpty {
                Section("Linked landmarks") {
                    ForEach(content.landmarkIds, id: \.self) { Text($0) }
                }
            }
            switch action {
            case .checkHere:
                CheckHereActionButton(nodeId: content.nodeId, mapState: mapState, handOff: handOff)
            case .include:
                IncludeActionButton(nodeId: content.nodeId, mapState: mapState, handOff: handOff)
            case nil:
                EmptyView()
            }
        }
    }
}

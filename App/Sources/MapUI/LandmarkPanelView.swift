import Core
import SwiftUI

/// The landmark panel (map W4): name, `what_it_is`, the source link (I15), and "which parts of the map
/// this touches" as jump links, one per linked node, each landing on W2 for that node. `onNodeJump` is
/// same-EPIC navigation, a plain callback — the caller (task 03.12) fetches that node's
/// `NodePanelContent` via `MapFacade.nodePanelContent` and presents `NodePanelView` for it.
struct LandmarkPanelView: View {
    let content: LandmarkPanelContent
    let onNodeJump: (String) -> Void

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.whatItIs)
                if let url = URL(string: content.sourceUrl) {
                    Link("Source", destination: url)
                } else {
                    Text(content.sourceUrl)
                }
            }
            if !content.nodeIds.isEmpty {
                Section("Where this touches the map") {
                    ForEach(content.nodeIds, id: \.self) { nodeId in
                        Button(nodeId) { onNodeJump(nodeId) }
                    }
                }
            }
        }
    }
}

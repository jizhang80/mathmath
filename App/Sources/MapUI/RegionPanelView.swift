import Core
import SwiftUI

/// The region panel (map W3): name, the one-sentence description, fraction cleared (Q2), and the
/// trails that cross it. No action control — region panels offer none; `MapFacade.regionPanelContent`
/// already returns `nil` for a `horizon` region, so this view never receives one.
struct RegionPanelView: View {
    let content: RegionPanelContent

    var body: some View {
        List {
            Section {
                Text(content.name).font(.headline)
                Text(content.about)
                if let fraction = content.clearedFraction {
                    Text("\(Int((fraction * 100).rounded()))% cleared")
                } else {
                    Text("under fog")
                }
            }
            if !content.courseCodesCrossingHere.isEmpty {
                Section("Courses that cross this region") {
                    ForEach(content.courseCodesCrossingHere, id: \.self) { Text($0) }
                }
            }
        }
    }
}

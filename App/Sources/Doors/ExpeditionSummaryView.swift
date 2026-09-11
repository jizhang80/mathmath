import Core
import SwiftUI

/// The summary (W5): cleared/blocked node-name lists, the two `Core`-supplied button labels, and the
/// optional write-failure / "Start another" error text. No region tint, no fraction, no percentage anywhere
/// (interaction-contract § 2 Summary content) — `summary.itemCount` is intentionally not rendered (§6
/// default 5).
struct ExpeditionSummaryView: View {
    let summary: DoorBSummaryScreen
    let writeFailureText: String?
    let startAnotherErrorText: String?
    let onStartAnother: () -> Void
    let onBackToMap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let writeFailureText {
                Text(writeFailureText)
            }
            Text(summary.clearedHeading).font(.headline)
            ForEach(summary.clearedNodeNames, id: \.self) { Text($0) }
            Text(summary.blockedHeading).font(.headline)
            ForEach(summary.blockedNodeNames, id: \.self) { Text($0) }
            if let startAnotherErrorText {
                Text(startAnotherErrorText)
            }
            Button(summary.startAnotherLabel) { onStartAnother() }
            Button(summary.backToMapLabel) { onBackToMap() }
        }
        .padding()
    }
}

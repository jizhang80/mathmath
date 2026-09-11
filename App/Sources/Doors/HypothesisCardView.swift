import Core
import SwiftUI

/// The Door A hypothesis card (W1–W2, diagnosis Q2's declinable cost statement). Every string is 04.3-computed
/// (`content.line`/`content.costLine`); "Yes"/"Not now" are App-authored chrome, the same category as 04.8's
/// "Continue"/"Submit" (04.8 §4.6).
struct HypothesisCardView: View {
    let content: DoorAHypothesisContent
    let onDecision: (Bool) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(content.line)
            Text(content.costLine)
            Button("Yes") { onDecision(true) }
            Button("Not now") { onDecision(false) }
        }
        .padding()
    }
}

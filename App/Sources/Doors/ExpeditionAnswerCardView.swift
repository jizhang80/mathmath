import Core
import Rendering
import SwiftUI

/// The answer card (I3): a distinct render phase that only the explicit continue control's tap replaces.
/// `correctAnswerDisplayKind` (not `item.type`, which this view has no access to) decides the display path
/// (arbiter-04 § Q-E item 4). No timer, no auto-advance.
struct ExpeditionAnswerCardView: View {
    let content: DoorAnswerCardContent
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: content.correct ? "checkmark.circle" : "xmark.circle")
            switch content.correctAnswerDisplayKind {
            case .latex:
                MathView(latex: content.correctAnswerDisplay)
            case .plain:
                Text(content.correctAnswerDisplay)
            }
            Text(content.why)
            if let extraLine = content.extraLine {
                Text(extraLine)
            }
            Button("Continue") { onContinue() }
        }
        .padding()
    }
}

import Core
import Rendering
import SwiftUI

/// The item view (Door B, W2/W3): the prompt via `MathView`, and either the numeric keypad or choice buttons
/// by `content.inputKind` — never both, never neither. The retry indicator is an SF Symbol only, never
/// App-authored text (§6 default 3): `DoorItemContent` carries `isRetry: Bool` alone, no label string.
struct ExpeditionItemView: View {
    let content: DoorItemContent
    @Binding var keypadInput: String
    let onSubmitNumeric: (String) -> Void
    let onSubmitChoice: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if content.isRetry {
                Image(systemName: "arrow.counterclockwise")
            }
            MathView(latex: content.promptLatex)
            switch content.inputKind {
            case .numeric:
                NumericKeypadView(input: $keypadInput, onSubmit: onSubmitNumeric)
            case .multipleChoice:
                ChoiceButtonsView(choices: content.choices, onSelect: onSubmitChoice)
            }
        }
        .padding()
    }
}

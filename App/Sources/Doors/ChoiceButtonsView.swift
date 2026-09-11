import Core
import Rendering
import SwiftUI

/// The multiple-choice input path (I10): one button per `DoorItemChoice`, its label rendered via `MathView`.
/// Tapping a choice submits its `id`, never its `latex` (docs/domains/expedition.md W2 step 2: "multiple-choice
/// by choice id").
struct ChoiceButtonsView: View {
    let choices: [DoorItemChoice]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(choices, id: \.id) { choice in
                Button {
                    onSelect(choice.id)
                } label: {
                    MathView(latex: choice.latex)
                }
            }
        }
    }
}

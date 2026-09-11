import Core
import SwiftUI

/// The numeric-entry input path (I10): the fixed key set from `DoorKeypad.numericKeypadKeys`, plus one
/// delete affordance and one "Submit" control. No key tap calls `DoorFacade`; only "Submit" does, via the
/// caller-supplied `onSubmit` closure.
struct NumericKeypadView: View {
    @Binding var input: String
    let onSubmit: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            Text(input.isEmpty ? " " : input).font(.title2)
            LazyVGrid(columns: columns) {
                ForEach(DoorKeypad.numericKeypadKeys, id: \.self) { key in
                    Button(key) { input.append(key) }
                }
                Button {
                    if !input.isEmpty { input.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                }
            }
            Button("Submit") { onSubmit(input) }
                .disabled(input.isEmpty)
        }
    }
}

import Core
import SwiftMath
import SwiftUI

/// Phase 5 placeholder. The Demo EPIC replaces this with the Map (Door C).
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("mathmath")
                .font(.largeTitle)
            Text("core data format \(CoreInfo.dataFormatVersion)")
                .font(.footnote)
            // Proves SwiftMath links and renders; the rendering spike (Demo task 1) exercises it properly.
            MathLabel(latex: #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#)
                .frame(height: 60)
        }
        .padding()
    }
}

/// Minimal SwiftUI bridge over SwiftMath's `MTMathUILabel` (UIKit). Replaced by a proper view in the Demo.
struct MathLabel: UIViewRepresentable {
    let latex: String

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        label.latex = latex
        label.textAlignment = .center
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.latex = latex
    }
}

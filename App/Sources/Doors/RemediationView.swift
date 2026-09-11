import Core
import Rendering
import SwiftUI

/// The one shared remediation-piece renderer (diagnosis W4; domain-glossary v1.0.1 Remediation, §3). Never
/// renders an `internalCode`, a fraction or a percentage (I6, content-policy § Voice).
struct RemediationView: View {
    let content: DoorARemediationContent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch content {
            case .explanation(let text):
                Text(text)
            case .workedExample(let example):
                ForEach(example.stepsLatex, id: \.self) { step in
                    MathView(latex: step)
                }
            case .paraphrase(let text, let hint):
                Text(text)
                if let hint {
                    Text(hint)
                }
            }
        }
        .padding()
    }
}

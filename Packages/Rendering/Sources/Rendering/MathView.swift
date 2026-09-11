import SwiftMath
import SwiftUI

/// What `MathView` shows for `latex`. Never blank (I3).
public enum MathViewContent: Equatable, Sendable {
    case rendered(latex: String)
    case fallback(text: String)
}

/// A SwiftUI view over SwiftMath's `MTMathUILabel`, for the app's only LaTeX-bearing fields
/// (`prompt_latex`, `choices[].latex`, and an `mc` `correctAnswerDisplay`). When SwiftMath cannot parse
/// `latex`, shows the unmodified source string as plain `Text` — never blank, never an error string, no
/// student code (arbiter-04 § Q-E).
public struct MathView: View {
    public let latex: String

    public init(latex: String) {
        self.latex = latex
    }

    public var body: some View {
        switch MathView.content(latex: latex) {
        case .rendered:
            #if canImport(UIKit)
                MathLabel(latex: latex)
            #else
                Text(latex)
            #endif
        case .fallback(let text):
            Text(text)
        }
    }
}

extension MathView {
    /// Non-UI entry point `MathView.body` itself calls. Reuses `RenderCheck.parseError(latex:)` — the same
    /// parser `RenderCheckReport`/`BundleRenderCheckTests` already gate the bundle with — never a second
    /// parser.
    public static nonisolated func content(latex: String) -> MathViewContent {
        RenderCheck.parseError(latex: latex) == nil
            ? .rendered(latex: latex)
            : .fallback(text: latex)
    }
}

#if canImport(UIKit)
    /// UIKit bridge over SwiftMath's `MTMathUILabel`, used only when `MathView.content(latex:)` resolves
    /// `.rendered` — i.e. `RenderCheck.parseError(latex:)` returned nil for this string.
    private struct MathLabel: UIViewRepresentable {
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
#endif

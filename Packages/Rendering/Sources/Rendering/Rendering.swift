import Foundation
import SwiftMath

/// Rendering — Phase 7 placeholder. EPIC 01 (rendering spike) fills this in: `MathView` and
/// `RenderCheck.canRender(latex:)`, which parses LaTeX with SwiftMath's parser and reports whether it is
/// in the renderable subset (learning-objects W1 5b; `LO_ITEM_UNRENDERABLE`).
public enum RenderCheck {
    /// Returns nil when SwiftMath parses `latex` without error, else the parser's message.
    public static func parseError(latex: String) -> String? {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: latex, error: &error)
        return error?.localizedDescription
    }
}

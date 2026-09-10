import Testing

@testable import Rendering

/// `canRender(latex:)` is a thin wrapper over `parseError(latex:)`; this suite proves it is not vacuously
/// true by probing the actual SwiftMath parse boundary directly, on both sides.
///
/// The arbiter's finding (`tasks/blocked/RESOLVED-arbiter-01-06-latex-enumeration.md`, finding 7, citing
/// `Packages/Rendering/.build/checkouts/SwiftMath/Sources/SwiftMath/MathRender/MTMathListBuilder.swift:301-306`)
/// is that SwiftMath's builder silently SKIPS characters it does not recognise, and only calls `setError`
/// for a specific, narrower class of defects: unknown backslash commands, brace mismatch, `\left`/`\right`/
/// `\begin`/`\end` imbalance and invalid delimiters. This suite empirically confirms that boundary rather
/// than assuming it, and documents where `canRender` is weaker than a full LaTeX validator: prose
/// punctuation and unrecognised symbols pass silently rather than reporting anything wrong.
@Suite("canRender boundary probes (SwiftMath parse boundary, not vacuous)")
struct CanRenderBoundaryTests {
    // MARK: - Genuinely unrenderable: canRender must return false

    @Test("unknown backslash command is rejected")
    func unknownCommandIsRejected() {
        #expect(RenderCheck.canRender(latex: #"\unknowncmd{x}"#) == false)
    }

    @Test("mismatched / unclosed brace is rejected")
    func mismatchedBraceIsRejected() {
        #expect(RenderCheck.canRender(latex: #"\frac{1"#) == false)
    }

    @Test("\\left without a matching \\right is rejected")
    func leftWithoutRightIsRejected() {
        #expect(RenderCheck.canRender(latex: #"\left(x"#) == false)
    }

    // MARK: - Genuinely renderable: canRender must return true

    @Test("a well-formed quadratic-formula fragment is accepted")
    func wellFormedFragmentIsAccepted() {
        #expect(RenderCheck.canRender(latex: #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#) == true)
    }

    @Test("a simple polynomial expression is accepted")
    func simplePolynomialIsAccepted() {
        #expect(RenderCheck.canRender(latex: "x^2 + 1") == true)
    }

    // MARK: - Documented weakness: canRender does NOT catch nonsense prose / unrecognised symbols

    /// SwiftMath's builder skips characters it cannot classify rather than erroring on them, so ordinary
    /// English punctuation inside a `prompt_latex`/`latex`-named field is silently accepted. This is not a
    /// defect this task is asked to fix (the field-kind is still checked; the check is simply weaker than
    /// "this string is valid LaTeX") — but a test suite that assumed `canRender` catches this would be
    /// overclaiming what the spike actually guarantees, so it is asserted and documented here.
    @Test(
        "prose punctuation that is not valid LaTeX is silently accepted, not rejected (documented weakness)")
    func prosePunctuationIsNotRejected() {
        #expect(RenderCheck.canRender(latex: "it's fine, right?") == true)
        #expect(RenderCheck.canRender(latex: "2 + 3 x 4") == true)
        #expect(RenderCheck.canRender(latex: "x >= 3") == true)
    }

    /// `&` (a column-alignment character, only meaningful inside an environment) and `$` (not a SwiftMath
    /// escape character at all) are both accepted outside any environment context — further evidence that
    /// `canRender` verifies "SwiftMath's builder did not call `setError`", not "this is well-formed LaTeX".
    @Test("stray environment/delimiter-adjacent symbols outside their legal context are not rejected")
    func strayDelimiterAdjacentSymbolsAreNotRejected() {
        #expect(RenderCheck.canRender(latex: "a & b") == true)
        #expect(RenderCheck.canRender(latex: "$$$") == true)
    }
}

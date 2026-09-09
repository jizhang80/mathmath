import Testing

@testable import Rendering

@Suite("Rendering package")
struct RenderingTests {
    @Test("SwiftMath parses a quadratic-formula fragment")
    func parsesKnownGood() {
        #expect(RenderCheck.parseError(latex: #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#) == nil)
    }

    @Test("SwiftMath reports an unbalanced brace")
    func reportsError() {
        #expect(RenderCheck.parseError(latex: #"\frac{1"#) != nil)
    }
}

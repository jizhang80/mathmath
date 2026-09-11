import Foundation
import Testing

@testable import Rendering

/// Tester's addition to task 04.7 (`rendering-mathview`) — closes gaps left by the implementer's own
/// `MathViewTests` (T1-T6), per the task spec's §1 acceptance criteria and the arbiter-04 § Q-E ruling.
/// Does not modify `MathViewTests.swift`; every case here is additive.
@Suite("MathView — full-bundle agreement, AC4 body dispatch, boundary inputs")
struct MathViewConformanceAndBoundaryTests {
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // RenderingTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // Rendering/
            .deletingLastPathComponent()  // Packages/
            .deletingLastPathComponent()  // repo root
    }

    private static func nodesJSONURL() -> URL {
        repoRoot().appendingPathComponent("data/demo/nodes.json")
    }

    private static func mathViewSourceURL() -> URL {
        repoRoot().appendingPathComponent("Packages/Rendering/Sources/Rendering/MathView.swift")
    }

    private static func fullBundleReport() throws -> RenderCheckReport {
        let data = try Data(contentsOf: nodesJSONURL())
        return try RenderCheckReport.scanning(nodesJSON: data)
    }

    // MARK: - Agreement with RenderCheck's own notion of "resolved", over the whole bundle

    /// Pure predicate mirroring the guard below: `MathView.content(latex:)` must agree with
    /// `RenderCheckEntry.resolved` — `.rendered` iff resolved, `.fallback` iff not. Factored out so the
    /// negative control (below) can exercise the same comparison on a synthetic, manufactured mismatch
    /// without touching product code.
    private static func contentAgreesWithResolved(contentIsRendered: Bool, resolved: Bool) -> Bool {
        contentIsRendered == resolved
    }

    /// Contract: `contracts/data-model.md` § Text + `contracts/content-policy.md` § Generated content —
    /// `MathView` must never blank a string SwiftMath (or a `render_fallback` flag) resolves, and must never
    /// silently "render" one it does not. Extends the implementer's T4 (which only checked the 80-string
    /// `prompt_latex`/`choices[].latex` population plus one planted string) to EVERY LaTeX-bearing string in
    /// the real bundle, including `hint_tree` tiers, `explanation` and `worked_examples[].steps_latex[]` —
    /// `MathView.content(latex:)` is a general-purpose pure function of its `String` argument, not one
    /// special-cased to the fields it happens to be wired to today (arbiter-04 § Q-E item 4 restricts
    /// *call sites*, not the function's own correctness domain).
    @Test("MathView.content agrees with RenderCheck's resolved verdict over the entire real bundle")
    func contentAgreesWithResolvedOverWholeBundle() throws {
        let report = try Self.fullBundleReport()
        #expect(!report.entries.isEmpty)

        for entry in report.entries {
            let isRendered: Bool
            switch MathView.content(latex: entry.latex) {
            case .rendered: isRendered = true
            case .fallback: isRendered = false
            }
            let agrees = Self.contentAgreesWithResolved(
                contentIsRendered: isRendered, resolved: entry.resolved)
            #expect(
                agrees,
                "field \(entry.field) on \(entry.itemId): MathView.content disagreed with resolved")
        }
    }

    /// C2 negative control: proves `contentAgreesWithResolved` actually reds on a broken shape (a resolved
    /// entry MathView would fallback on, or vice versa) rather than being a predicate that can never fail.
    @Test("negative control: the agreement guard reds on a manufactured resolved/rendered mismatch")
    func agreementGuardRedsOnManufacturedMismatch() {
        #expect(!Self.contentAgreesWithResolved(contentIsRendered: true, resolved: false))
        #expect(!Self.contentAgreesWithResolved(contentIsRendered: false, resolved: true))
        // Positive control: the same predicate passes on the two consistent shapes.
        #expect(Self.contentAgreesWithResolved(contentIsRendered: true, resolved: true))
        #expect(Self.contentAgreesWithResolved(contentIsRendered: false, resolved: false))
    }

    // MARK: - AC4: body dispatches MathLabel only for .rendered, plain Text only for .fallback

    /// AC4: "`MathView`'s SwiftUI `body` uses the SwiftMath-backed `MTMathUILabel` wrapper only in the
    /// rendered branch, and plain `Text` in the fallback branch; no branch ever displays an empty string."
    /// Neither `MathViewTests.swift`'s T1-T6 nor any pre-existing suite instantiates the SwiftUI view body
    /// (there is no ViewInspector-style dependency in this package, and this test target builds for the
    /// host platform, where `#if canImport(UIKit)` is false, so `MathLabel` never even compiles here) — so
    /// this is checked structurally against the source text, the same technique the implementer's own T3/T5
    /// already use for AC5's "no student code" guard.
    @Test("AC4: body's .rendered case reaches MathLabel before .fallback reaches Text(text)")
    func bodyDispatchesMathLabelOnlyForRenderedAndTextOnlyForFallback() throws {
        let text = try String(contentsOf: Self.mathViewSourceURL(), encoding: .utf8)
        #expect(!text.isEmpty)

        guard let renderedRange = text.range(of: "case .rendered:"),
            let mathLabelRange = text.range(of: "MathLabel(latex:"),
            let fallbackRange = text.range(of: "case .fallback(let text):"),
            let textTextRange = text.range(of: "Text(text)")
        else {
            Issue.record(
                "expected body structure (case .rendered / MathLabel / case .fallback / Text(text)) not found"
            )
            return
        }

        // MathLabel is reached only inside the .rendered case, before the .fallback case begins.
        #expect(renderedRange.lowerBound < mathLabelRange.lowerBound)
        #expect(mathLabelRange.lowerBound < fallbackRange.lowerBound)
        // Text(text) — the fallback's own bound value, never the raw `latex` — is reached only after
        // .fallback begins.
        #expect(fallbackRange.lowerBound < textTextRange.lowerBound)

        // Neither branch ever hardcodes a blank literal (I3: never blank).
        #expect(!text.contains("Text(\"\")"))
        #expect(!text.contains("MathLabel(latex: \"\")"))
    }

    // MARK: - Boundary inputs: empty and whitespace-only strings

    /// Negative/boundary — invalid input class "empty": `MathView.content(latex:)` takes an untrusted plain
    /// `String`, not a schema-validated field, so there is no length/format precondition to violate; the
    /// function must still behave as a total, deterministic, side-effect-free mapping (never crash, never
    /// throw) and stay in lockstep with `RenderCheck.parseError` even at this boundary.
    @Test("boundary: empty and whitespace-only latex stay in lockstep with RenderCheck.parseError")
    func emptyAndWhitespaceLatexStayInLockstepWithParseError() {
        for candidate in ["", "   ", "\n\t"] {
            let expectedRendered = RenderCheck.parseError(latex: candidate) == nil
            switch MathView.content(latex: candidate) {
            case .rendered(let latex):
                #expect(expectedRendered)
                #expect(latex == candidate)
            case .fallback(let text):
                #expect(!expectedRendered)
                #expect(text == candidate)
            }
            // Idempotent even at this boundary (extends the implementer's T6 beyond its one renderable and
            // one planted-unparsable sample).
            #expect(MathView.content(latex: candidate) == MathView.content(latex: candidate))
        }
    }
}

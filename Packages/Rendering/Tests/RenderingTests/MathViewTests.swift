import Foundation
import Testing

@testable import Rendering

@Suite("MathView")
struct MathViewTests {
    /// Walks up from this test file to the repo root, then down to `data/demo/nodes.json`:
    /// `Tests/RenderingTests/MathViewTests.swift` -> `Tests/RenderingTests/` -> `Tests/` -> `Rendering/` ->
    /// `Packages/` -> repo root.
    private static func nodesJSONURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data/demo/nodes.json")
    }

    private static func mathViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Rendering/MathView.swift")
    }

    /// The 80-string population (40 `prompt_latex` + 40 `choices[].latex`) — no second bundle walk, no
    /// second parser.
    private static func promptAndChoiceLatexStrings() throws -> [String] {
        let data = try Data(contentsOf: nodesJSONURL())
        let report = try RenderCheckReport.scanning(nodesJSON: data)
        return report.entries
            .filter { $0.field == "prompt_latex" || $0.field.hasPrefix("choices[") }
            .map(\.latex)
    }

    private static let plantedUnparsable = #"\frac{1"#

    @Test("T1: every prompt/choice latex string in data/demo resolves .rendered")
    func allPromptAndChoiceStringsResolveRendered() throws {
        let strings = try Self.promptAndChoiceLatexStrings()

        #expect(!strings.isEmpty)
        #expect(strings.count == 80)

        for string in strings {
            #expect(MathView.content(latex: string) == .rendered(latex: string))
        }
    }

    @Test("T2: a planted unparsable string resolves .fallback with the unmodified source")
    func plantedUnparsableStringResolvesFallback() {
        let content = MathView.content(latex: Self.plantedUnparsable)

        #expect(content == .fallback(text: Self.plantedUnparsable))
        if case .fallback(let text) = content {
            #expect(text == Self.plantedUnparsable)
            #expect(!text.isEmpty)
        } else {
            Issue.record("expected .fallback")
        }
    }

    @Test("T3: MathView.swift never references LO_ITEM_UNRENDERABLE or RenderingError")
    func mathViewSourceCarriesNoStudentCode() throws {
        let text = try String(contentsOf: Self.mathViewSourceURL(), encoding: .utf8)

        #expect(!text.isEmpty)
        #expect(text.contains("func content(latex:"))

        #expect(!text.contains("LO_ITEM_UNRENDERABLE"))
        #expect(!text.contains("RenderingError"))
    }

    @Test("T4: MathView.content is a pure re-expression of RenderCheck.parseError; no import Core")
    func contentMatchesRenderCheckParseErrorExactly() throws {
        var population = try Self.promptAndChoiceLatexStrings()
        population.append(Self.plantedUnparsable)

        for string in population {
            let expectedRendered = RenderCheck.parseError(latex: string) == nil
            switch MathView.content(latex: string) {
            case .rendered:
                #expect(expectedRendered)
            case .fallback:
                #expect(!expectedRendered)
            }
        }

        let text = try String(contentsOf: Self.mathViewSourceURL(), encoding: .utf8)
        let importLines = text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        #expect(Set(importLines) == Set(["import SwiftUI", "import SwiftMath"]))
    }

    /// Returns `false` iff `source` contains `"MTMathListBuilder"` — the underlying SwiftMath parser
    /// `RenderCheck.parseError` itself wraps (`Rendering.swift:11`). Applied to `MathView.swift`'s real
    /// source, this must be `true`: no second, independent call to the underlying parser.
    private static func usesOnlyRenderCheckAsParser(_ source: String) -> Bool {
        !source.contains("MTMathListBuilder")
    }

    @Test("T5: MathView.swift calls no second parser; negative control detects a planted violation")
    func noSecondParserGuard() throws {
        let text = try String(contentsOf: Self.mathViewSourceURL(), encoding: .utf8)
        #expect(Self.usesOnlyRenderCheckAsParser(text))

        let synthetic = """
            var error: NSError?
            _ = MTMathListBuilder.build(fromString: latex, error: &error)
            """
        #expect(!Self.usesOnlyRenderCheckAsParser(synthetic))
    }

    @Test("T6: MathView.content(latex:) is a pure, idempotent derivation")
    func contentIsIdempotent() throws {
        let renderable = try Self.promptAndChoiceLatexStrings()[0]

        #expect(MathView.content(latex: renderable) == MathView.content(latex: renderable))
        #expect(
            MathView.content(latex: Self.plantedUnparsable)
                == MathView.content(latex: Self.plantedUnparsable))
    }
}

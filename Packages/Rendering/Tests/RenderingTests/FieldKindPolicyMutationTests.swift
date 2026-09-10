import Foundation
import Testing

@testable import Rendering

/// Deepens `BundleRenderCheckTests` (AC1/AC2/AC2b) with the per-field-kind proofs the spec's §5 demands:
/// - per-field-kind empty policy (FAIL for `prompt_latex` / `choices[].latex` / `hint_tree[]`, PASS for
///   `steps_latex[]` / `explanation`) proven independently, not via a blanket total count (T5b's own
///   lesson);
/// - one mutation proof per field kind, including the two kinds absent from real data (`steps_latex`,
///   `explanation`) that are otherwise dead code;
/// - `render_fallback` honoured only on `prompt_latex` / `choices[].latex` (the only field legally
///   inside the probe-item object per `nodes.schema.json:248`), never on `hint_tree` or `explanation`.
@Suite("Per-field-kind policy and mutation proofs")
struct FieldKindPolicyMutationTests {
    // MARK: - Per-field-kind empty policy (AC1's own field-kind assertions, proven independently)

    /// A node with `hint_tree` + `explanation` but a genuinely empty `probe_items` array is legal JSON
    /// under the private bundle mirror (the array is non-optional but may be empty). This proves an
    /// AC1-style blanket `entries.count > 0` check would PASS this fixture even though it carries zero
    /// `prompt_latex` and zero `choices[].latex` entries — exactly the gap T5b's own lesson warns about.
    /// The per-field assertions below are what actually catch it.
    @Test(
        "empty prompt_latex / choices[] set is distinguishable from a non-empty overall report (FAIL policy)")
    func emptyPromptLatexAndChoicesIsNotMaskedByOverallCount() throws {
        let json = """
            {
              "nodes": [
                {
                  "id": "no-probes-node",
                  "explanation": "x = 1",
                  "hint_tree": { "only-error": ["a", "b", "c"] },
                  "probe_items": []
                }
              ]
            }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))

        // A blanket count check would pass: the report is non-empty (explanation + hint_tree entries).
        #expect(report.entries.count > 0)
        // But the two FAIL-policy field kinds are genuinely absent — this is the assertion a blanket
        // total-count check cannot make, and it is what AC1's per-field-kind coverage lines actually prove.
        #expect(!report.entries.contains { $0.field == "prompt_latex" })
        #expect(!report.entries.contains { $0.field.hasPrefix("choices[") })
    }

    /// Isolates the `hint_tree[` FAIL policy: a node with probe items (so `prompt_latex`/`choices[` are
    /// present) but no `hint_tree` key at all in this synthetic node — the mirror's `hintTree` is optional.
    @Test("empty hint_tree set is distinguishable from a non-empty overall report (FAIL policy)")
    func emptyHintTreeIsNotMaskedByOverallCount() throws {
        let json = """
            {
              "nodes": [
                {
                  "id": "no-hints-node",
                  "probe_items": [
                    { "id": "item-1", "prompt_latex": "x = 1" }
                  ]
                }
              ]
            }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))

        #expect(report.entries.count > 0)
        #expect(!report.entries.contains { $0.field.hasPrefix("hint_tree[") })
    }

    /// `steps_latex[]` and `explanation` are PASS-policy when absent: a report with real `prompt_latex` /
    /// `choices[]` / `hint_tree[]` entries and zero `steps_latex[]` / `explanation` entries is fully
    /// resolved — their absence is not a failure, unlike the three FAIL-policy kinds above.
    @Test("empty steps_latex and explanation sets do not fail the report (PASS policy)")
    func emptyStepsLatexAndExplanationPassCleanly() throws {
        let json = """
            {
              "nodes": [
                {
                  "id": "no-worked-examples-node",
                  "hint_tree": { "only-error": ["a", "b", "c"] },
                  "probe_items": [
                    {
                      "id": "item-1",
                      "prompt_latex": "x = 1",
                      "choices": [ { "id": "a", "latex": "x = 2" } ]
                    }
                  ]
                }
              ]
            }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))

        #expect(report.entries.count > 0)
        #expect(!report.entries.contains { $0.field.hasPrefix("steps_latex[") })
        #expect(!report.entries.contains { $0.field == "explanation" })
        #expect(report.unresolvedCount == 0)
    }

    // MARK: - Mutation proofs: one unrenderable plant per field kind

    private func unrenderableFixture(field: String, latexKey: String) -> String {
        // A shared unbalanced-brace payload (`\frac{1`), the same unrenderable shape AC2 already proves
        // fails SwiftMath's parse, planted into a different field kind each time.
        switch field {
        case "prompt_latex":
            return """
                { "nodes": [ { "id": "mut-node", "probe_items": [
                  { "id": "mut-item", "prompt_latex": "\\\\frac{1" }
                ] } ] }
                """
        case "choices":
            return """
                { "nodes": [ { "id": "mut-node", "probe_items": [
                  { "id": "mut-item", "prompt_latex": "x = 1",
                    "choices": [ { "id": "a", "latex": "\\\\frac{1" } ] }
                ] } ] }
                """
        case "steps_latex":
            return """
                { "nodes": [ { "id": "mut-node",
                  "worked_examples": [ { "id": "mut-example", "steps_latex": ["\\\\frac{1"] } ],
                  "probe_items": [ { "id": "mut-item", "prompt_latex": "x = 1" } ] } ] }
                """
        case "hint_tree":
            return """
                { "nodes": [ { "id": "mut-node",
                  "hint_tree": { "only-error": ["\\\\frac{1", "b", "c"] },
                  "probe_items": [ { "id": "mut-item", "prompt_latex": "x = 1" } ] } ] }
                """
        case "explanation":
            return """
                { "nodes": [ { "id": "mut-node", "explanation": "\\\\frac{1",
                  "probe_items": [ { "id": "mut-item", "prompt_latex": "x = 1" } ] } ] }
                """
        default:
            fatalError("unhandled field kind in test fixture builder: \(field)")
        }
    }

    @Test("mutation proof: an unrenderable prompt_latex is reported unresolved with the right itemId")
    func mutationProofPromptLatex() throws {
        let report = try RenderCheckReport.scanning(
            nodesJSON: Data(unrenderableFixture(field: "prompt_latex", latexKey: "prompt_latex").utf8))
        let entry = try #require(report.entries.first { $0.field == "prompt_latex" })
        #expect(entry.parsed == false)
        #expect(entry.resolved == false)
        #expect(entry.itemId == "mut-node.probe_items.mut-item")
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "mut-node.probe_items.mut-item")) {
            try report.assertAllResolved()
        }
    }

    @Test("mutation proof: an unrenderable choices[].latex is reported unresolved with the right itemId")
    func mutationProofChoicesLatex() throws {
        let report = try RenderCheckReport.scanning(
            nodesJSON: Data(unrenderableFixture(field: "choices", latexKey: "latex").utf8))
        let entry = try #require(report.entries.first { $0.field.hasPrefix("choices[") })
        #expect(entry.parsed == false)
        #expect(entry.itemId == "mut-node.probe_items.mut-item")
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "mut-node.probe_items.mut-item")) {
            try report.assertAllResolved()
        }
    }

    /// `worked_examples[].steps_latex[]` is absent from every node in the landed bundle (§3's census: 0
    /// entries) — this is the proof it is wired, not dead code.
    @Test("mutation proof: an unrenderable steps_latex entry is reported unresolved with the right itemId")
    func mutationProofStepsLatex() throws {
        let report = try RenderCheckReport.scanning(
            nodesJSON: Data(unrenderableFixture(field: "steps_latex", latexKey: "steps_latex").utf8))
        let entry = try #require(report.entries.first { $0.field == "steps_latex[0]" })
        #expect(entry.parsed == false)
        #expect(entry.itemId == "mut-node.worked_examples.mut-example")
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "mut-node.worked_examples.mut-example")) {
            try report.assertAllResolved()
        }
    }

    /// `hint_tree` tier strings are 63/143 of the real scan and all parse clean — this fixture is the only
    /// proof the parse-failure path for this field kind is exercised at all.
    @Test("mutation proof: an unrenderable hint_tree tier is reported unresolved with the right itemId")
    func mutationProofHintTree() throws {
        let report = try RenderCheckReport.scanning(
            nodesJSON: Data(unrenderableFixture(field: "hint_tree", latexKey: "hint_tree").utf8))
        let entry = try #require(report.entries.first { $0.field == "hint_tree[0]" })
        #expect(entry.parsed == false)
        #expect(entry.itemId == "mut-node.hint_tree.only-error")
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "mut-node.hint_tree.only-error")) {
            try report.assertAllResolved()
        }
    }

    /// `explanation` is absent from every node in the landed bundle (§3's census: 0 entries) — this is the
    /// proof it is wired, not dead code.
    @Test("mutation proof: an unrenderable explanation is reported unresolved with the right itemId")
    func mutationProofExplanation() throws {
        let report = try RenderCheckReport.scanning(
            nodesJSON: Data(unrenderableFixture(field: "explanation", latexKey: "explanation").utf8))
        let entry = try #require(report.entries.first { $0.field == "explanation" })
        #expect(entry.parsed == false)
        #expect(entry.itemId == "mut-node.explanation")
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "mut-node.explanation")) {
            try report.assertAllResolved()
        }
    }

    // MARK: - render_fallback legality: excuses prompt_latex / choices[], excuses nothing else

    @Test("render_fallback: katex resolves an otherwise-unrenderable prompt_latex")
    func renderFallbackExcusesPromptLatex() throws {
        let json = """
            { "nodes": [ { "id": "fb-node", "probe_items": [
              { "id": "fb-item", "prompt_latex": "\\\\frac{1", "render_fallback": "katex" }
            ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let entry = try #require(report.entries.first { $0.field == "prompt_latex" })
        #expect(entry.parsed == false)
        #expect(entry.hasFallback == true)
        #expect(entry.resolved == true)
        #expect(report.unresolvedCount == 0)
        #expect(throws: Never.self) { try report.assertAllResolved() }
    }

    @Test("render_fallback: katex resolves an otherwise-unrenderable choices[].latex")
    func renderFallbackExcusesChoicesLatex() throws {
        let json = """
            { "nodes": [ { "id": "fb-node", "probe_items": [
              { "id": "fb-item", "prompt_latex": "x = 1", "render_fallback": "katex",
                "choices": [ { "id": "a", "latex": "\\\\frac{1" } ] }
            ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let entry = try #require(report.entries.first { $0.field.hasPrefix("choices[") })
        #expect(entry.parsed == false)
        #expect(entry.hasFallback == true)
        #expect(entry.resolved == true)
        #expect(report.unresolvedCount == 0)
    }

    /// A stray `render_fallback` key at NODE level (illegal per schema — `render_fallback` exists only
    /// inside the probe-item object, `nodes.schema.json:248`, and the node object is closed at `:375`) must
    /// not excuse an unrenderable `hint_tree` tier. The private mirror does not even declare a node-level
    /// `renderFallback` property, so `Decodable` silently ignores the stray key — this test proves the
    /// *effect* of that: the hint_tree entry stays unresolved regardless.
    @Test("render_fallback does NOT excuse an unrenderable hint_tree tier, even if the key is present nearby")
    func renderFallbackDoesNotExcuseHintTree() throws {
        let json = """
            { "nodes": [ { "id": "fb-node", "render_fallback": "katex",
              "hint_tree": { "only-error": ["\\\\frac{1", "b", "c"] },
              "probe_items": [ { "id": "fb-item", "prompt_latex": "x = 1" } ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let entry = try #require(report.entries.first { $0.field == "hint_tree[0]" })
        #expect(entry.parsed == false)
        #expect(entry.hasFallback == false)
        #expect(entry.resolved == false)
        #expect(report.unresolvedCount == 1)
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "fb-node.hint_tree.only-error")) {
            try report.assertAllResolved()
        }
    }

    /// Same proof for `explanation` — the field the STOP-and-report clause in §6 names alongside
    /// `hint_tree` as having no schema-legal fallback.
    @Test("render_fallback does NOT excuse an unrenderable explanation, even if the key is present nearby")
    func renderFallbackDoesNotExcuseExplanation() throws {
        let json = """
            { "nodes": [ { "id": "fb-node", "render_fallback": "katex", "explanation": "\\\\frac{1",
              "probe_items": [ { "id": "fb-item", "prompt_latex": "x = 1" } ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let entry = try #require(report.entries.first { $0.field == "explanation" })
        #expect(entry.hasFallback == false)
        #expect(entry.resolved == false)
        #expect(report.unresolvedCount == 1)
    }

    /// And for `steps_latex[]` — `render_fallback` is not schema-legal on a `worked_examples` entry either
    /// (§4 step 5: "`render_fallback` is not schema-legal on a `worked_examples` entry").
    @Test(
        "render_fallback does NOT excuse an unrenderable steps_latex entry, even if the key is present nearby"
    )
    func renderFallbackDoesNotExcuseStepsLatex() throws {
        let json = """
            { "nodes": [ { "id": "fb-node", "render_fallback": "katex",
              "worked_examples": [ { "id": "fb-example", "steps_latex": ["\\\\frac{1"] } ],
              "probe_items": [ { "id": "fb-item", "prompt_latex": "x = 1" } ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let entry = try #require(report.entries.first { $0.field == "steps_latex[0]" })
        #expect(entry.hasFallback == false)
        #expect(entry.resolved == false)
        #expect(report.unresolvedCount == 1)
    }

    // MARK: - hint_tree emission order: dictionary-key sort is deterministic, not incidental

    /// Keys deliberately chosen so literal JSON order ("zeta-error" before "alpha-error") differs from
    /// sorted order — proving the emitted order is the SORTED order, not whatever order the JSON happened
    /// to list the keys in (which is itself not preserved through `JSONDecoder`'s dictionary decode; a raw
    /// `Dictionary`'s natural iteration order is hash-seed dependent and unrelated to either).
    @Test("hint_tree entries emit in sorted key order, not literal JSON declaration order")
    func hintTreeEmitsInSortedOrderNotLiteralOrder() throws {
        let json = """
            { "nodes": [ { "id": "order-node",
              "hint_tree": { "zeta-error": ["z1", "z2", "z3"], "alpha-error": ["a1", "a2", "a3"] },
              "probe_items": [ { "id": "order-item", "prompt_latex": "x = 1" } ] } ] }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))
        let hintEntries = report.entries.filter { $0.field.hasPrefix("hint_tree[") }
        let errorTypeOrder = hintEntries.map { $0.itemId }
        let expectedSortedOrder = [
            "order-node.hint_tree.alpha-error", "order-node.hint_tree.alpha-error",
            "order-node.hint_tree.alpha-error", "order-node.hint_tree.zeta-error",
            "order-node.hint_tree.zeta-error", "order-node.hint_tree.zeta-error",
        ]
        #expect(errorTypeOrder == expectedSortedOrder)
        // The literal JSON order is the reverse of sorted order for these two keys — this is what proves
        // the assertion above is actually discriminating, not accidentally matching either order.
        #expect(["zeta-error", "alpha-error"].sorted() != ["zeta-error", "alpha-error"])
    }

    /// Re-decoding the same bytes repeatedly must produce byte-for-byte (structurally equal) identical
    /// `entries` arrays every time. `Dictionary` iteration order in Swift is not guaranteed stable across
    /// distinct `Dictionary` instances (each decode produces a fresh dictionary); `keys.sorted()` is what
    /// makes this hold. A high repeat count makes a regression to raw dictionary iteration order likely to
    /// surface as flakiness rather than passing by chance.
    @Test("re-scanning identical bytes many times yields identical entries every time (T6)")
    func repeatedScansAreOrderStable() throws {
        let json = """
            { "nodes": [
              { "id": "order-node-1",
                "hint_tree": { "zeta-error": ["z1", "z2", "z3"], "mid-error": ["m1", "m2", "m3"],
                                "alpha-error": ["a1", "a2", "a3"] },
                "probe_items": [ { "id": "order-item-1", "prompt_latex": "x = 1" } ] },
              { "id": "order-node-2",
                "hint_tree": { "yankee-error": ["y1", "y2", "y3"], "bravo-error": ["b1", "b2", "b3"] },
                "probe_items": [ { "id": "order-item-2", "prompt_latex": "x = 2" } ] }
            ] }
            """
        let data = Data(json.utf8)
        let first = try RenderCheckReport.scanning(nodesJSON: data)
        for _ in 0..<50 {
            let repeated = try RenderCheckReport.scanning(nodesJSON: data)
            #expect(repeated.entries == first.entries)
        }
    }
}

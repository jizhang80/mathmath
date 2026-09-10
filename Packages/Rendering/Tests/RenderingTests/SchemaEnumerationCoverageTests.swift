import Foundation
import Testing

@testable import Rendering

/// Proves `RenderCheckReport.scanning(nodesJSON:)` visits every LaTeX-bearing field the SCHEMA defines,
/// not merely the fields the implementer happened to wire. The field set is derived independently by
/// walking `contracts/schemas/nodes.schema.json` at runtime — never copied from `RenderCheckReport.swift`
/// or from `BundleRenderCheckTests.swift`. If a scanner change silently drops a schema-defined field kind,
/// this suite reds; a check that has never failed is indistinguishable from a check that cannot fail.
///
/// Contract basis: `contracts/data-model.md` § Text (`latex` / `prompt_latex`-named fields) +
/// `contracts/content-policy.md` § Generated content (hints render or carry the fallback) +
/// `docs/domains/learning-objects.md:81-82` (W1 5b — "every prompt, hint and explanation renders in
/// SwiftMath") reconciled by the broad enumeration fixed in
/// `tasks/blocked/RESOLVED-arbiter-01-06-latex-enumeration.md`.
@Suite("Schema-derived field enumeration coverage")
struct SchemaEnumerationCoverageTests {
    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // RenderingTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // Rendering/
            .deletingLastPathComponent()  // Packages/
            .deletingLastPathComponent()  // repo root
    }

    private static func nodesSchemaURL() -> URL {
        repoRoot().appendingPathComponent("contracts/schemas/nodes.schema.json")
    }

    /// Recursively collects every JSON Schema property name reachable from `properties` objects, anywhere
    /// in the document (nested through `items`, `additionalProperties`, `oneOf`, etc.) — a generic schema
    /// walk, not a hand-picked list.
    private static func collectPropertyNames(_ node: Any) -> Set<String> {
        if let dict = node as? [String: Any] {
            var found = Set<String>()
            if let props = dict["properties"] as? [String: Any] {
                for (name, sub) in props {
                    found.insert(name)
                    found.formUnion(collectPropertyNames(sub))
                }
            }
            for (_, value) in dict {
                found.formUnion(collectPropertyNames(value))
            }
            return found
        }
        if let array = node as? [Any] {
            var found = Set<String>()
            for element in array {
                found.formUnion(collectPropertyNames(element))
            }
            return found
        }
        return []
    }

    @Test("nodes.schema.json names exactly the latex-suffixed fields the narrow rule expects")
    func schemaLatexNamedFieldsMatchDataModelText() throws {
        let schemaData = try Data(contentsOf: Self.nodesSchemaURL())
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        let allProperties = Self.collectPropertyNames(schemaJSON)

        // Anti-vacuity: the schema walk must actually find properties, else this test is meaningless.
        #expect(allProperties.count > 10)

        let latexNamed = allProperties.filter { $0.lowercased().contains("latex") }
        // contracts/data-model.md § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`".
        // nodes.schema.json:170 (steps_latex), :240 (prompt_latex), :301 (latex, the mc choice field).
        #expect(latexNamed == ["prompt_latex", "steps_latex", "latex"])
    }

    /// The broad enumeration = schema-derived latex-named fields ∪ {hint_tree, explanation}, per
    /// `contracts/content-policy.md` § Generated content and `docs/domains/learning-objects.md:81-82`.
    /// A single synthetic fixture exercises every member of this independently-derived set; if the scanner
    /// silently skips any one of the five, its `field` prefix is simply absent from `report.entries` and
    /// this test reds.
    @Test("scanning visits every schema-derived LaTeX-bearing field kind")
    func scannerVisitsEverySchemaField() throws {
        let schemaData = try Data(contentsOf: Self.nodesSchemaURL())
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData)
        let latexNamed = Self.collectPropertyNames(schemaJSON).filter { $0.lowercased().contains("latex") }
        let broadFieldKinds = latexNamed.union(["hint_tree", "explanation"])
        #expect(broadFieldKinds.count == 5)

        let json = """
            {
              "nodes": [
                {
                  "id": "coverage-node",
                  "explanation": "x = 1",
                  "hint_tree": { "only-error": ["a", "b", "c"] },
                  "worked_examples": [
                    { "id": "coverage-example", "steps_latex": ["x = 2"] }
                  ],
                  "probe_items": [
                    {
                      "id": "coverage-item",
                      "prompt_latex": "x = 3",
                      "choices": [ { "id": "a", "latex": "x = 4" } ]
                    }
                  ]
                }
              ]
            }
            """
        let report = try RenderCheckReport.scanning(nodesJSON: Data(json.utf8))

        // Field-kind -> the entry.field prefix that proves the scanner actually visited it.
        let fieldPrefixByKind: [String: String] = [
            "prompt_latex": "prompt_latex",
            "latex": "choices[",
            "steps_latex": "steps_latex[",
            "hint_tree": "hint_tree[",
            "explanation": "explanation",
        ]
        for kind in broadFieldKinds {
            guard let prefix = fieldPrefixByKind[kind] else {
                Issue.record("no expected field-prefix mapping recorded for schema field kind '\(kind)'")
                continue
            }
            #expect(
                report.entries.contains { $0.field.hasPrefix(prefix) },
                "scanner produced no entry for schema-derived field kind '\(kind)' (expected field prefix '\(prefix)')"
            )
        }
    }
}

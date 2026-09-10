import Foundation
import Testing

@testable import Rendering

@Suite("Bundle render check")
struct BundleRenderCheckTests {
    /// Walks up from this test file to the repo root, then down to `data/demo/nodes.json`:
    /// `Tests/RenderingTests/BundleRenderCheckTests.swift` -> `Tests/RenderingTests/` -> `Tests/` ->
    /// `Rendering/` -> `Packages/` -> repo root.
    private static func nodesJSONURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("data/demo/nodes.json")
    }

    private static func outcomeRecordURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/epics/epic-01-rendering-spike-outcome.md")
    }

    @Test("AC1: the real bundle scans clean across the broad field set")
    func scansRealBundleClean() throws {
        let data = try Data(contentsOf: Self.nodesJSONURL())
        let report = try RenderCheckReport.scanning(nodesJSON: data)

        #expect(report.entries.count > 0)
        #expect(report.entries.contains { $0.field == "prompt_latex" })
        #expect(report.entries.contains { $0.field.hasPrefix("choices[") })
        #expect(report.entries.contains { $0.field.hasPrefix("hint_tree[") })
        #expect(report.unresolvedCount == 0)
    }

    @Test("AC2: an unresolved, un-flagged prompt is reported and throws LO_ITEM_UNRENDERABLE")
    func reportsUnresolvedFixture() throws {
        let json = """
            {
              "nodes": [
                {
                  "id": "fixture-node",
                  "probe_items": [
                    {
                      "id": "fixture-item",
                      "prompt_latex": "\\\\frac{1"
                    }
                  ]
                }
              ]
            }
            """
        let data = Data(json.utf8)
        let report = try RenderCheckReport.scanning(nodesJSON: data)

        #expect(report.unresolvedCount == 1)
        #expect(throws: RenderingError.loItemUnrenderable(itemId: "fixture-node.probe_items.fixture-item")) {
            try report.assertAllResolved()
        }
    }

    @Test("AC2b: explanation, hint_tree and worked_examples emit in the pinned order")
    func emitsFieldKindsRealDataDoesNotExercise() throws {
        let json = """
            {
              "nodes": [
                {
                  "id": "fixture-node",
                  "explanation": "x = 1",
                  "hint_tree": {
                    "sign-error": ["a", "b", "c"],
                    "no-error": ["d", "e", "f"]
                  },
                  "worked_examples": [
                    {
                      "id": "fixture-example",
                      "steps_latex": ["x = 1", "x = 2"]
                    }
                  ],
                  "probe_items": [
                    {
                      "id": "fixture-item",
                      "prompt_latex": "x = 1"
                    }
                  ]
                }
              ]
            }
            """
        let data = Data(json.utf8)
        let report = try RenderCheckReport.scanning(nodesJSON: data)

        let expected = [
            RenderCheckEntry(
                itemId: "fixture-node.explanation", field: "explanation", latex: "x = 1", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.no-error", field: "hint_tree[0]", latex: "d", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.no-error", field: "hint_tree[1]", latex: "e", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.no-error", field: "hint_tree[2]", latex: "f", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.sign-error", field: "hint_tree[0]", latex: "a", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.sign-error", field: "hint_tree[1]", latex: "b", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.hint_tree.sign-error", field: "hint_tree[2]", latex: "c", parsed: true,
                hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.worked_examples.fixture-example", field: "steps_latex[0]",
                latex: "x = 1", parsed: true, hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.worked_examples.fixture-example", field: "steps_latex[1]",
                latex: "x = 2", parsed: true, hasFallback: false),
            RenderCheckEntry(
                itemId: "fixture-node.probe_items.fixture-item", field: "prompt_latex", latex: "x = 1",
                parsed: true, hasFallback: false),
        ]

        #expect(report.entries == expected)
    }

    @Test("AC3: every item id in the outcome record's affected-items table is a real itemId")
    func outcomeRecordCitesOnlyRealIds() throws {
        let text = try String(contentsOf: Self.outcomeRecordURL(), encoding: .utf8)
        let data = try Data(contentsOf: Self.nodesJSONURL())
        let report = try RenderCheckReport.scanning(nodesJSON: data)
        let realIds = Set(report.entries.map(\.itemId))

        var inTable = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard line.hasPrefix("|") else { continue }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count > 1 else { continue }
            let firstCell = cells[1]

            if firstCell == "Item id" {
                inTable = true
                continue
            }
            guard inTable else { continue }
            if firstCell.hasPrefix("---") { continue }
            if firstCell.isEmpty { continue }

            let itemId = firstCell.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            #expect(realIds.contains(itemId))
        }
    }
}

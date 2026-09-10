import Foundation

/// Mirrors `LO_ITEM_UNRENDERABLE` (`contracts/error-codes.json:32`) for `Rendering`'s own surface, since
/// this package does not import `Core` and therefore cannot reuse `CoreError`.
public enum RenderingError: Error, Equatable {
    case loItemUnrenderable(itemId: String)
}

/// One scanned LaTeX-bearing string and whether it is resolved (parses, or carries a fallback flag).
public struct RenderCheckEntry: Equatable {
    public let itemId: String
    public let field: String
    public let latex: String
    public let parsed: Bool
    public let hasFallback: Bool

    public init(itemId: String, field: String, latex: String, parsed: Bool, hasFallback: Bool) {
        self.itemId = itemId
        self.field = field
        self.latex = latex
        self.parsed = parsed
        self.hasFallback = hasFallback
    }

    public var resolved: Bool { parsed || hasFallback }
}

/// The result of scanning a bundle (or a fixture) for every LaTeX-bearing string.
public struct RenderCheckReport: Equatable {
    public let entries: [RenderCheckEntry]

    public init(entries: [RenderCheckEntry]) {
        self.entries = entries
    }

    public var unresolvedEntries: [RenderCheckEntry] { entries.filter { !$0.resolved } }
    public var unresolvedCount: Int { unresolvedEntries.count }

    /// Throws `RenderingError.loItemUnrenderable(itemId:)` naming the first unresolved entry, else returns.
    public func assertAllResolved() throws {
        if let first = unresolvedEntries.first {
            throw RenderingError.loItemUnrenderable(itemId: first.itemId)
        }
    }
}

// MARK: - Private bundle-decoding mirror

/// A deliberately partial `Decodable` mirror of only the LaTeX-bearing fields `RenderCheckReport` scans.
/// This is not a second copy of `Core`'s `Node` model (I14) — `Rendering` must not depend on `Core`.
private struct BundleNodesFile: Decodable {
    let nodes: [BundleNode]
}

private struct BundleNode: Decodable {
    let id: String
    let explanation: String?
    let hintTree: [String: [String]]?
    let workedExamples: [BundleWorkedExample]?
    let probeItems: [BundleProbeItem]
}

private struct BundleWorkedExample: Decodable {
    let id: String
    let stepsLatex: [String]
}

private struct BundleProbeItem: Decodable {
    let id: String
    let promptLatex: String
    let renderFallback: String?
    let choices: [BundleChoice]?
}

private struct BundleChoice: Decodable {
    let id: String
    let latex: String
}

extension RenderCheckReport {
    /// Decodes `nodesJSON` and emits one `RenderCheckEntry` per LaTeX-bearing string across the broad
    /// five-field enumeration: `explanation`, `hint_tree` tiers, `worked_examples[].steps_latex[]`,
    /// `prompt_latex`, and `choices[].latex`. Emission order is pinned: nodes in array order; within each
    /// node, `explanation`, then `hint_tree` (keys sorted, then tier index), then `worked_examples` (array
    /// order, then step index), then `probe_items` (array order: `prompt_latex` then each `choices[]`).
    public static func scanning(nodesJSON data: Data) throws -> RenderCheckReport {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let file = try decoder.decode(BundleNodesFile.self, from: data)

        var entries: [RenderCheckEntry] = []

        for node in file.nodes {
            if let explanation = node.explanation {
                entries.append(
                    RenderCheckEntry(
                        itemId: "\(node.id).explanation",
                        field: "explanation",
                        latex: explanation,
                        parsed: RenderCheck.canRender(latex: explanation),
                        hasFallback: false
                    )
                )
            }

            if let hintTree = node.hintTree {
                for errorTypeId in hintTree.keys.sorted() {
                    let tiers = hintTree[errorTypeId] ?? []
                    for (index, tier) in tiers.enumerated() {
                        entries.append(
                            RenderCheckEntry(
                                itemId: "\(node.id).hint_tree.\(errorTypeId)",
                                field: "hint_tree[\(index)]",
                                latex: tier,
                                parsed: RenderCheck.canRender(latex: tier),
                                hasFallback: false
                            )
                        )
                    }
                }
            }

            for example in node.workedExamples ?? [] {
                for (index, step) in example.stepsLatex.enumerated() {
                    entries.append(
                        RenderCheckEntry(
                            itemId: "\(node.id).worked_examples.\(example.id)",
                            field: "steps_latex[\(index)]",
                            latex: step,
                            parsed: RenderCheck.canRender(latex: step),
                            hasFallback: false
                        )
                    )
                }
            }

            for item in node.probeItems {
                let hasFallback = item.renderFallback == "katex"
                let itemId = "\(node.id).probe_items.\(item.id)"

                entries.append(
                    RenderCheckEntry(
                        itemId: itemId,
                        field: "prompt_latex",
                        latex: item.promptLatex,
                        parsed: RenderCheck.canRender(latex: item.promptLatex),
                        hasFallback: hasFallback
                    )
                )

                for choice in item.choices ?? [] {
                    entries.append(
                        RenderCheckEntry(
                            itemId: itemId,
                            field: "choices[\(choice.id)].latex",
                            latex: choice.latex,
                            parsed: RenderCheck.canRender(latex: choice.latex),
                            hasFallback: hasFallback
                        )
                    )
                }
            }
        }

        return RenderCheckReport(entries: entries)
    }
}

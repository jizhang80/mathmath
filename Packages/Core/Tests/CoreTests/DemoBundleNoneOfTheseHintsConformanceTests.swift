import Foundation
import Testing

@testable import Core

/// Tester suite for task 04.1b (`tasks/epic-04-task-01b-data-demo-none-of-these-hints.md`), companion to
/// the implementer's smoke `DemoBundleNoneOfTheseHintsTests.swift` (AC1/AC2/AC6). Covers the AC/invariant
/// surfaces the smoke does not: I2 borrow-check against error-type labels and sibling tier text (not just
/// tier-1 duplicate literals), a committed in-memory negative control for the distinctness guard (C2 —
/// the smoke's own negative control was authored-then-reverted per §4 step 4, so it ships no red repro),
/// the domain-glossary banned-synonym list (Diagnosis/Expedition sections), plain-text-only tiers (no
/// LaTeX markup, per `contracts/data-model.md` § Text — `hint_tree` is not `latex`/`prompt_latex`), and the
/// manifest-untouched predicate (arbiter-04-hint-fallback-reconciliation Rule 4 cascade: "while they are
/// placeholders, leave them").
@Suite("Demo bundle hint_tree[\"none-of-these\"] — conformance")
struct DemoBundleNoneOfTheseHintsConformanceTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Packages/Core
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var nodesJSONURL: URL {
        repoRoot.appendingPathComponent("data/demo/nodes.json")
    }

    private static var manifestJSONURL: URL {
        repoRoot.appendingPathComponent("data/demo/manifest.json")
    }

    private static func loadNodesFile() throws -> NodesFile {
        let data = try Data(contentsOf: nodesJSONURL)
        return try CoreCoding.decoder.decode(NodesFile.self, from: data)
    }

    /// Every substring-containment check below excludes trivially short fragments (articles, prepositions)
    /// so a coincidental short overlap ("the", "a factor") is never mistaken for borrowing.
    private static let minimumMeaningfulOverlapLength = 12

    // MARK: - I2: the none-of-these fallback never borrows a sibling error type's hint

    /// Contract: `contracts/content-policy.md` § Voice + `docs/domains/learning-objects.md` HintTree
    /// ("never another ErrorType's hint (I2)"), quoted in the task spec §1 I2 line. The implementer's own
    /// smoke checks tier-1 literal inequality only; this test additionally checks (a) all three tiers, not
    /// just tier 1, for an exact duplicate, (b) substring "quoting" of a sibling's tier text, and (c)
    /// substring naming of a sibling `error_types[]` member's `label`.
    @Test("none-of-these tiers never duplicate or quote a sibling key's hint text, on any tier")
    func noneOfTheseNeverDuplicatesSiblingTierText() throws {
        let nodesFile = try Self.loadNodesFile()
        #expect(nodesFile.nodes.count > 0)

        for node in nodesFile.nodes {
            let noneTiers = try #require(node.hintTree["none-of-these"])
            for (key, siblingTiers) in node.hintTree where key != "none-of-these" {
                for siblingTier in siblingTiers {
                    #expect(
                        !noneTiers.contains(siblingTier),
                        "\(node.id): none-of-these duplicates sibling key \(key)'s tier text verbatim")
                    guard siblingTier.count >= Self.minimumMeaningfulOverlapLength else { continue }
                    for noneTier in noneTiers {
                        #expect(
                            !noneTier.localizedCaseInsensitiveContains(siblingTier),
                            "\(node.id): none-of-these tier quotes sibling key \(key)'s tier text")
                    }
                }
            }
        }
    }

    @Test("none-of-these tiers never name a sibling error type's label")
    func noneOfTheseNeverNamesSiblingErrorTypeLabel() throws {
        let nodesFile = try Self.loadNodesFile()
        #expect(nodesFile.nodes.count > 0)

        for node in nodesFile.nodes {
            let noneTiers = try #require(node.hintTree["none-of-these"])
            let siblingLabels = node.errorTypes.map(\.label)
                .filter { $0.count >= Self.minimumMeaningfulOverlapLength }
            for label in siblingLabels {
                for noneTier in noneTiers {
                    #expect(
                        !noneTier.localizedCaseInsensitiveContains(label),
                        "\(node.id): none-of-these tier names a sibling error type's label (\"\(label)\")")
                }
            }
        }
    }

    // MARK: - Distinctness negative control (C2) — a committed in-memory mutated bundle, never a file edit

    /// Reproduces the check the implementer's smoke performs (tier-1 distinctness against every sibling
    /// key on the same node), factored so it can be exercised against both the real bundle and a mutated
    /// in-memory copy — the negative control the task spec asks the implementer to "plant, confirm red,
    /// then revert" (§4 step 4), which by construction never ships a committed red repro on its own. This
    /// test builds the mutation in memory instead, so the guard's discriminating power is provable from the
    /// committed suite alone.
    private static func tier1DistinctnessViolations(in nodes: [Node]) -> [String] {
        var violatingNodeIds: [String] = []
        for node in nodes {
            guard let noneTier1 = node.hintTree["none-of-these"]?.first else { continue }
            for (key, tiers) in node.hintTree where key != "none-of-these" {
                if tiers.first == noneTier1 {
                    violatingNodeIds.append("\(node.id):\(key)")
                }
            }
        }
        return violatingNodeIds
    }

    @Test("distinctness guard: zero violations on the real, unmutated bundle")
    func distinctnessGuardGreenOnRealBundle() throws {
        let nodesFile = try Self.loadNodesFile()
        #expect(nodesFile.nodes.count > 0)
        #expect(Self.tier1DistinctnessViolations(in: nodesFile.nodes).isEmpty)
    }

    @Test("distinctness guard: reds on a mutated in-memory bundle with a planted sibling-tier-1 duplicate")
    func distinctnessGuardRedsOnMutatedInMemoryBundle() throws {
        let rawData = try Data(contentsOf: Self.nodesJSONURL)
        let json = try #require(
            try JSONSerialization.jsonObject(with: rawData) as? [String: Any])
        var nodes = try #require(json["nodes"] as? [[String: Any]])

        // `exponential-functions` is the two-sibling-key node the task spec calls out (§4 step 2); plant a
        // copy of `base-exponent-swapped`'s tier 1 into `none-of-these`'s tier 1, purely in memory.
        let targetIndex = try #require(nodes.firstIndex { ($0["id"] as? String) == "exponential-functions" })
        var hintTree = try #require(nodes[targetIndex]["hint_tree"] as? [String: [String]])
        let plantedDuplicate = try #require(hintTree["base-exponent-swapped"]?.first)
        var noneOfThese = try #require(hintTree["none-of-these"])
        noneOfThese[0] = plantedDuplicate
        hintTree["none-of-these"] = noneOfThese
        nodes[targetIndex]["hint_tree"] = hintTree

        var mutatedJSON = json
        mutatedJSON["nodes"] = nodes
        let mutatedData = try JSONSerialization.data(withJSONObject: mutatedJSON)
        let mutatedNodesFile = try CoreCoding.decoder.decode(NodesFile.self, from: mutatedData)

        let violations = Self.tier1DistinctnessViolations(in: mutatedNodesFile.nodes)
        #expect(violations == ["exponential-functions:base-exponent-swapped"])

        // Sanity: the mutation touched only the planted node, proving the guard is precise, not blanket-red.
        let otherNodes = mutatedNodesFile.nodes.filter { $0.id != "exponential-functions" }
        #expect(Self.tier1DistinctnessViolations(in: otherNodes).isEmpty)
    }

    // MARK: - Glossary: no banned synonym in the new student-facing strings

    /// `contracts/domain-glossary.md` Expedition entry bans "quiz", "session", "quest", "level" for an
    /// expedition/hint context; the Retry/Diagnosis-event entries ban "fail" for an item outcome and
    /// "attempt". None of these words has any legitimate use inside a none-of-these hint tier.
    @Test("none-of-these tiers carry no banned domain-glossary synonym")
    func noneOfTheseTiersAvoidBannedGlossarySynonyms() throws {
        let nodesFile = try Self.loadNodesFile()
        #expect(nodesFile.nodes.count > 0)

        let bannedWords = ["attempt", "fail", "level", "quiz", "session", "quest"]
        let wordBoundaryPattern = "\\b(%@)\\b"

        for node in nodesFile.nodes {
            let noneTiers = try #require(node.hintTree["none-of-these"])
            for tier in noneTiers {
                for banned in bannedWords {
                    let pattern = String(format: wordBoundaryPattern, banned)
                    let range = tier.range(
                        of: pattern, options: [.regularExpression, .caseInsensitive])
                    #expect(
                        range == nil,
                        "\(node.id): none-of-these tier uses banned word \"\(banned)\": \"\(tier)\"")
                }
            }
        }
    }

    // MARK: - Plain text only: no LaTeX markup in hint_tree (contracts/data-model.md § Text)

    /// `hint_tree` is not `latex` or `prompt_latex`, so per `contracts/data-model.md` § Text the field is
    /// plain English and never carries LaTeX markup or a `render_fallback`. `BundleRenderCheckTests`
    /// confirms the strings resolve cleanly through `RenderCheck`; this test independently confirms they
    /// contain none of the characters that would make LaTeX markup possible in the first place, so a
    /// future author cannot silently smuggle LaTeX into a field the renderer happens to tolerate.
    @Test("none-of-these tiers contain no LaTeX markup characters")
    func noneOfTheseTiersArePlainText() throws {
        let nodesFile = try Self.loadNodesFile()
        #expect(nodesFile.nodes.count > 0)

        let latexMarkupCharacters = CharacterSet(charactersIn: "\\${}")
        for node in nodesFile.nodes {
            let noneTiers = try #require(node.hintTree["none-of-these"])
            for tier in noneTiers {
                #expect(
                    tier.rangeOfCharacter(from: latexMarkupCharacters) == nil,
                    "\(node.id): none-of-these tier carries LaTeX-style markup: \"\(tier)\"")
            }
        }
    }

    // MARK: - Manifest untouched (arbiter-04-hint-fallback-reconciliation Rule 4 cascade)

    /// Rule 4's cascade instruction: "while they are placeholders, leave them." Confirms the predicate this
    /// task's Done gate relies on — all six `sha256` values are still the 64-hex-zero placeholder — stays
    /// true after this commit, i.e. `data/demo/manifest.json` was not touched by task 04.1b.
    @Test("manifest.json sha256 hashes remain the all-zero placeholder (unstamped, untouched by this task)")
    func manifestHashesRemainPlaceholders() throws {
        let data = try Data(contentsOf: Self.manifestJSONURL)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let files = try #require(json["files"] as? [[String: Any]])
        #expect(files.count == 6)

        let placeholder = String(repeating: "0", count: 64)
        for file in files {
            let sha256 = try #require(file["sha256"] as? String)
            #expect(
                sha256 == placeholder,
                "manifest entry \(file["name"] ?? "?") is no longer a placeholder hash")
        }
    }
}

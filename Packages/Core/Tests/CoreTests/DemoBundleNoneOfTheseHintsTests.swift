import Foundation
import Testing

@testable import Core

/// Companion test for task 04.1b (`tasks/epic-04-task-01b-data-demo-none-of-these-hints.md`, AC1/AC2/AC6/AC9):
/// every node in `data/demo` carries a `hint_tree["none-of-these"]` entry of exactly three non-empty tiers,
/// whose tier 1 never repeats a sibling key's tier 1 on that same node (AC1/AC2/AC6), and whose tiers pass the
/// I2 token check of `tasks/arbitration/arbiter-04-01b-generic-hint-i2.md` § The mechanical check (AC9).
@Suite("Demo bundle hint_tree[\"none-of-these\"]")
struct DemoBundleNoneOfTheseHintsTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var demoBundleDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    @Test("every data/demo node has a 3-tier none-of-these hint distinct from its sibling keys' tier 1")
    func noneOfTheseHintsPresentAndDistinct() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(bundle.nodes.nodes.count > 0)

        for node in bundle.nodes.nodes {
            let noneOfThese = node.hintTree["none-of-these"]
            let tiers = try #require(noneOfThese, "\(node.id) is missing hint_tree[\"none-of-these\"]")
            #expect(tiers.count == 3, "\(node.id) has \(tiers.count) none-of-these tiers, expected 3")
            #expect(
                tiers.allSatisfy { !$0.isEmpty },
                "\(node.id) has an empty none-of-these tier")

            for (key, siblingTiers) in node.hintTree where key != "none-of-these" {
                #expect(
                    siblingTiers.first != tiers.first,
                    "\(node.id): none-of-these tier 1 duplicates sibling key \(key)'s tier 1")
            }
        }
    }

    // MARK: - AC9: the I2 token check
    // (`tasks/arbitration/arbiter-04-01b-generic-hint-i2.md` § The mechanical check)

    /// Function words and generic nudge words only; never a mathematical word.
    private static let stoplist: Set<String> = [
        "again", "also", "been", "being", "does", "each", "from", "have", "into", "look",
        "that", "their", "them", "then", "there", "these", "they", "this", "those", "were",
        "what", "when", "where", "which", "while", "will", "with", "would",
    ]

    /// Evaluative qualifiers that imply which way the work went wrong.
    private static let qualifierList: Set<String> = [
        "correct", "correctly", "incorrect", "incorrectly", "wrong", "wrongly", "right",
        "mistake", "mistakes", "error", "errors", "fully", "truly", "actually", "properly",
        "only",
    ]

    /// Lowercase `s`, then split on every character that is not ASCII `a`-`z`.
    private static func rawTokens(_ s: String) -> [String] {
        let lowered = s.lowercased()
        var tokens: [String] = []
        var current = ""
        for scalar in lowered.unicodeScalars {
            if scalar.value >= 97 && scalar.value <= 122 {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }

    /// Raw tokens with tokens shorter than 4 characters and stoplist tokens dropped.
    private static func filteredTokens(_ s: String) -> [String] {
        rawTokens(s).filter { $0.count >= 4 && !stoplist.contains($0) }
    }

    private static func stem(_ t: String) -> String {
        String(t.prefix(4))
    }

    /// `U`: the sibling tokens (from each sibling's `id`, `label` and hint tiers), unstemmed.
    private static func siblingTokenSet(_ siblings: [(id: String, label: String, tiers: [String])]) -> Set<
        String
    > {
        var u: Set<String> = []
        for sibling in siblings {
            u.formUnion(filteredTokens(sibling.id))
            u.formUnion(filteredTokens(sibling.label))
            for tier in sibling.tiers {
                u.formUnion(filteredTokens(tier))
            }
        }
        return u
    }

    /// `A`: the per-node concept allowlist, the stems of `tokens(name)`.
    private static func nameAllowlist(_ name: String) -> Set<String> {
        Set(filteredTokens(name).map(stem))
    }

    static func i2Violations(
        name: String,
        siblings: [(id: String, label: String, tiers: [String])],
        noneTiers: [String]
    ) -> [String] {
        let u = siblingTokenSet(siblings)
        let allowlist = nameAllowlist(name)

        var violations: [String] = []
        for (index, tier) in noneTiers.enumerated() {
            for token in rawTokens(tier) {
                if qualifierList.contains(token) {
                    violations.append("\(index):\(token)")
                    continue
                }
                guard token.count >= 4, !stoplist.contains(token) else { continue }
                let tokenStem = stem(token)
                if !allowlist.contains(tokenStem) && u.contains(where: { $0.contains(tokenStem) }) {
                    violations.append("\(index):\(token)")
                }
            }
        }
        return violations
    }

    @Test("AC9: every data/demo node's none-of-these tiers pass the I2 token check")
    func i2ViolationsOnRealBundle() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(bundle.nodes.nodes.count > 0)

        for node in bundle.nodes.nodes {
            let siblings: [(id: String, label: String, tiers: [String])] =
                node.errorTypes
                .filter { $0.id != "none-of-these" }
                .map { ($0.id, $0.label, node.hintTree[$0.id] ?? []) }
            let noneTiers = node.hintTree["none-of-these"] ?? []

            #expect(!Self.siblingTokenSet(siblings).isEmpty, "\(node.id): U is empty")
            #expect(!Self.nameAllowlist(node.name).isEmpty, "\(node.id): A is empty")
            #expect(
                Self.i2Violations(name: node.name, siblings: siblings, noneTiers: noneTiers) == [],
                "\(node.id): I2 token check violation")
        }
    }

    @Test("AC9 NC1: S1 reds on sibling content (integer-operations)")
    func nc1SiblingContentViolation() {
        let siblings: [(id: String, label: String, tiers: [String])] = [
            (
                "sign-error", "Dropped or mishandled a negative sign",
                [
                    "Subtracting a negative is the same as adding its opposite.",
                    "-3 - (-7) becomes -3 + 7.",
                    "-3 + 7 = 4.",
                ]
            )
        ]
        let noneTiers = [
            "Look again at how the signs combine in this expression.",
            "Rewrite the expression one operation at a time before evaluating.",
            "Redo the calculation step by step, checking the sign at each step.",
        ]
        #expect(
            Self.i2Violations(name: "Integer operations", siblings: siblings, noneTiers: noneTiers)
                == ["0:signs", "2:sign"])
    }

    @Test("AC9 NC2: substring containment catches read against misread (function-notation)")
    func nc2SubstringContainmentViolation() {
        let siblings: [(id: String, label: String, tiers: [String])] = [
            (
                "notation-misread", "Misread the function rule when substituting the input",
                [
                    "Apply the rule to the input exactly as written.",
                    "g(x)=3x-2 at x=4 means 3(4)-2.",
                    "3(4)-2 = 10.",
                ]
            )
        ]
        let noneTiers = [
            "Look again at how the function notation was read.",
            "Check the answer by working the evaluation out one operation at a time.",
            "Redo the evaluation from the start, then check the result with a rough estimate.",
        ]
        #expect(
            Self.i2Violations(name: "Function notation", siblings: siblings, noneTiers: noneTiers)
                == ["0:read"])
    }

    @Test("AC9 NC3: S2 reds on a pointing qualifier; the name allowlist admits order/operations")
    func nc3QualifierViolation() {
        let siblings: [(id: String, label: String, tiers: [String])] = [
            (
                "wrong-order", "Evaluated operations left to right, ignoring precedence",
                [
                    "Multiplication and division come before addition and subtraction.",
                    "In 2 + 3 x 4, do the multiplication first.",
                    "3 x 4 = 12, then 2 + 12 = 14.",
                ]
            )
        ]
        let noneTiers = [
            "Reread the expression and list the operations it contains.",
            "Work through the expression one operation at a time, in the correct order.",
            "Redo the expression from the start, following the order of operations.",
        ]
        #expect(
            Self.i2Violations(name: "Order of operations", siblings: siblings, noneTiers: noneTiers)
                == ["1:correct"])
    }

    @Test("AC9 NC3b: an empty name allowlist is not blanket-green")
    func nc3bEmptyAllowlistIsLoadBearing() {
        let siblings: [(id: String, label: String, tiers: [String])] = [
            (
                "wrong-order", "Evaluated operations left to right, ignoring precedence",
                [
                    "Multiplication and division come before addition and subtraction.",
                    "In 2 + 3 x 4, do the multiplication first.",
                    "3 x 4 = 12, then 2 + 12 = 14.",
                ]
            )
        ]
        let noneTiers = [
            "Reread the expression and list the operations it contains.",
            "Work through the expression one operation at a time, in the correct order.",
            "Redo the expression from the start, following the order of operations.",
        ]
        #expect(
            Self.i2Violations(name: "", siblings: siblings, noneTiers: noneTiers)
                .contains("2:order"))
    }

    @Test("AC9 NC4: the stoplist admits the generic look, which the sibling's tier 1 also uses")
    func nc4StoplistAdmitsGenericWord() {
        let siblings: [(id: String, label: String, tiers: [String])] = [
            (
                "added-exponents-on-power",
                "Added the exponents instead of multiplying when raising a power to a power",
                [
                    "Look at what happens to the exponent when a power is raised to a power.",
                    "When you raise a power to a power, multiply the exponents.",
                    "(2^3)^2 = 2^(3x2) = 2^6, not 2^5.",
                ]
            )
        ]
        let noneTiers = [
            "Look again at which exponent rule applies here.",
            "Check the result on a simpler case, with small exponents written out.",
            "Redo the simplification, applying the matching exponent law one step at a time.",
        ]
        #expect(
            Self.i2Violations(name: "Exponent laws", siblings: siblings, noneTiers: noneTiers) == [])
    }
}

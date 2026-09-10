import Foundation
import Testing

@testable import Core

/// Tester's supplementary coverage for `ItemChecker` (`Sources/Core/ItemChecker.swift`), written against
/// `tasks/epic-02-task-07-item-checker-expedition-run.md`. This file does NOT re-verify AC1-AC4 (the
/// implementer's own `ItemCheckerTests.swift` already owns that ground, including the real `data/demo`
/// sweep and the core normalisation/malformed-input table) — it targets gaps the implementer's own suite
/// left open:
///  - the I10 "mc by choice id only, never by value" rule is asserted only indirectly (an unknown-id
///    check); this file adds the load-bearing negative control: a submission equal to the correct choice's
///    `latex` text, but not its `id`, must still be a miss;
///  - the exact-rational grammar's own mandatory-digit-group edges not in the implementer's malformed table
///    (`"+"`, `"-"`, `".5"`, `"5."`, `"1/2/3"`, a non-ASCII digit);
///  - `Rational.parse`'s overflow-safe arithmetic on a pathologically large digit string (never traps,
///    never silently wraps to a wrong value that could coincidentally check correct);
///  - a signature-level compile-time assertion that `ItemChecker.check` takes exactly `(ProbeItem, String)`
///    -> `Bool`, with no model/adapter parameter anywhere in its type (I1, I10, I2's "no model call exists
///    anywhere in this task's code").
@Suite("ItemChecker — boundary and gap coverage")
struct ItemCheckerBoundaryTests {
    private static func numericItem(
        id: String = "test-item", value: String, tolerance: Double? = nil
    ) -> ProbeItem {
        ProbeItem(
            id: id, type: .numeric, promptLatex: "x", why: "why", renderFallback: nil,
            answer: ProbeAnswer(value: value, tolerance: tolerance), wrongAnswers: nil, choices: nil,
            correctChoiceId: nil, check: nil)
    }

    private static func mcItem(correctChoiceId: String, choices: [ProbeChoice]) -> ProbeItem {
        ProbeItem(
            id: "test-mc-item", type: .mc, promptLatex: "x", why: "why", renderFallback: nil,
            answer: nil, wrongAnswers: nil, choices: choices, correctChoiceId: correctChoiceId,
            check: nil)
    }

    // MARK: - T5 negative control: mc comparison is by id, never by value (I10)

    @Test("Guard: mc comparison is by choices[].id, never by choices[].latex text")
    func guardMcComparisonByIdNotLatex() throws {
        // `contracts/interaction-contract.md` v0.9.1 § 2: "mc items are compared by choices[].id only,
        // never by value (I10)." A naive comparator that matched on `latex` would wrongly accept the
        // correct choice's display text submitted verbatim (a plausible bug: a UI layer that accidentally
        // sends the rendered label instead of the tapped choice's id). The real `check` must reject it.
        let item = Self.mcItem(
            correctChoiceId: "a",
            choices: [
                ProbeChoice(id: "a", latex: "x^7", errorTypeId: nil),
                ProbeChoice(id: "b", latex: "x^{12}", errorTypeId: "e1"),
            ])
        // The naive, wrong comparator this guards against.
        func naiveCheckByLatex(_ item: ProbeItem, submitted: String) -> Bool {
            item.choices?.first(where: { $0.latex == submitted })?.id == item.correctChoiceId
        }
        #expect(naiveCheckByLatex(item, submitted: "x^7") == true)
        // The real implementation: submitting the correct choice's `latex` text (not its `id`) is a miss.
        #expect(!ItemChecker.check(item: item, submitted: "x^7"))
        // Submitting the actual id still checks correct.
        #expect(ItemChecker.check(item: item, submitted: "a"))
    }

    // MARK: - T2 negative — additional grammar boundary cases

    @Test(
        "Additional malformed/edge submissions never crash and always check incorrect",
        arguments: [
            "+", "-", ".5", "5.", "1/2/3", "//1", "1.", "-.", "٤" /* Arabic-Indic digit 4, non-ASCII */,
        ])
    func additionalMalformedSubmissionsRejected(submitted: String) throws {
        let item = Self.numericItem(value: "4")
        #expect(!ItemChecker.check(item: item, submitted: submitted))
    }

    @Test("Overflow-scale digit strings never crash and never silently wrap to a false match")
    func overflowScaleDigitStringNeverCrashesOrWraps() throws {
        let hugeDigits = String(repeating: "9", count: 40)
        let item = Self.numericItem(value: "4")
        // Must not trap; an overflowing parse is unparseable, hence a miss (never coincidentally correct).
        #expect(!ItemChecker.check(item: item, submitted: hugeDigits))
        // A huge value submitted against an equally huge (but exactly matching) target must still not
        // trap, whichever way it resolves.
        let hugeItem = Self.numericItem(value: hugeDigits)
        let result = ItemChecker.check(item: hugeItem, submitted: hugeDigits)
        #expect(result == true || result == false)
    }

    @Test("A leading-plus zero-only submission (\"+0\") matches a zero-valued answer")
    func explicitPositiveZeroMatchesZero() throws {
        // Boundary of the sign grammar: "+0" and "-0" both reduce to the same 0/1 rational.
        let item = Self.numericItem(value: "0")
        #expect(ItemChecker.check(item: item, submitted: "+0"))
        #expect(ItemChecker.check(item: item, submitted: "-0"))
    }

    // MARK: - T4 conformance: I1/I10 signature-level assertion

    @Test("I1/I10: ItemChecker.check's type is exactly (ProbeItem, String) -> Bool, no model parameter")
    func checkSignatureHasNoModelParameter() throws {
        // Compiles iff `check(item:submitted:)`'s full type is exactly this — no adapter/model/confidence
        // parameter exists anywhere in the signature (a structural, compile-time proof of I1/I10/I2).
        let f: (ProbeItem, String) -> Bool = ItemChecker.check(item:submitted:)
        let item = Self.numericItem(value: "4")
        #expect(f(item, "4"))
    }
}

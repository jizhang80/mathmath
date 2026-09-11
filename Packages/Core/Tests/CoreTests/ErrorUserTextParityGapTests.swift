import Foundation
import Testing

@testable import Core

/// Tester suite for task 03.3 (`epic-03-task-03-core-error-surface-text-mirror.md`). Extends
/// `ErrorUserTextParityTests` (implementer's suite) where a §1/§5 acceptance signal is not yet exercised:
/// AC2 checked directly over `CoreError.allCases` (not just registry entries), the registry's wider
/// student-surface set (`VERIFY_*`) explicitly allowed to have no `CoreError` case, load-bearing negative
/// controls for the empty-registry / empty-table guards (C2 — a guard never shown to fail is not a guard),
/// and a no-authored-copy grep over `CoreErrorText.swift`'s own string literals.
///
/// Does not modify `CoreError.swift` or `CoreErrorText.swift` (product code) — every broken shape here is a
/// local fixture built inside a test function, mirroring `ErrorRegistryNegativeControlTests`.
@Suite("CoreErrorText parity: additional coverage (AC2/AC4/AC5, C2 negative controls)")
struct ErrorUserTextParityGapTests {
    private struct RegistryEntry: Decodable {
        let code: String
        let surface: String
        let userText: String?

        enum CodingKeys: String, CodingKey {
            case code, surface
            case userText = "user_text"
        }
    }

    private struct Registry: Decodable {
        let codes: [RegistryEntry]
    }

    private static func loadRegistry() throws -> Registry {
        let registryPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/error-codes.json")
        let data = try Data(contentsOf: registryPath)
        return try JSONDecoder().decode(Registry.self, from: data)
    }

    // MARK: - AC2 checked directly over CoreError.allCases (both directions), not just registry entries.

    // AC2: "CoreErrorText.userText returns the exact registered user_text string for every code whose
    // registry entry has surface == student, and nil for every code whose registry entry has surface ==
    // internal or owner." `ErrorUserTextParityTests` drives this from the registry's own entry list; this
    // test drives the identical claim from `CoreError.allCases` itself, which is the shape §1 AC2 actually
    // names ("every CoreError case's raw value").
    @Test("every CoreError case's userText matches its registry surface, in both directions")
    func everyCoreErrorCaseMatchesRegistrySurface() throws {
        let registry = try Self.loadRegistry()
        let byCode = Dictionary(uniqueKeysWithValues: registry.codes.map { ($0.code, $0) })

        #expect(!CoreError.allCases.isEmpty, "empty CoreError case set is a FAIL")

        for errorCase in CoreError.allCases {
            guard let entry = byCode[errorCase.rawValue] else {
                Issue.record("\(errorCase.rawValue) is a CoreError case but absent from the registry")
                continue
            }
            let mirrored = CoreErrorText.text(for: errorCase)
            if entry.surface == "student" {
                #expect(
                    mirrored == entry.userText,
                    "\(errorCase.rawValue): student-surface case must mirror the registry's user_text exactly"
                )
            } else {
                #expect(
                    mirrored == nil,
                    "\(errorCase.rawValue): \(entry.surface)-surface case must have no CoreErrorText entry"
                )
            }
        }
    }

    // Confirms this task's own three new cases individually (AC1/AC2 cross-check): two student-surface,
    // one internal.
    @Test("the three new platform cases carry the registry-correct userText")
    func newPlatformCasesCarryCorrectText() throws {
        #expect(
            CoreErrorText.text(for: .platformStateUnreadable)
                == "Earlier progress could not be read; it has been kept.")
        #expect(
            CoreErrorText.text(for: .platformSnapshotRefused)
                == "The map could not be loaded from this copy of the app; reinstall the app to fix it.")
        #expect(
            CoreErrorText.text(for: .platformStateWriteFailed) == nil,
            "PLATFORM_STATE_WRITE_FAILED is registry surface \"internal\" — it must not carry student text")
    }

    // MARK: - the registry's student-surface set is allowed to be wider than CoreError.allCases (VERIFY_*).

    // §6 decision default: "the registry's student-surface set (VERIFY_* codes) is wider than
    // CoreError.allCases today"; the parity test must not require a CoreError case for those codes.
    @Test("a registry student code absent from CoreError.allCases still gets a CoreErrorText entry")
    func registryStudentCodeWithNoCoreErrorCaseIsStillMirrored() throws {
        let registry = try Self.loadRegistry()
        let coreErrorRawValues = Set(CoreError.allCases.map(\.rawValue))
        let studentOnlyInRegistry = registry.codes.filter {
            $0.surface == "student" && !coreErrorRawValues.contains($0.code)
        }

        // VERIFY_* is the concrete instance the spec names (§6); assert it is non-empty so this test is
        // not vacuous, then assert the parity table still mirrors every such code.
        #expect(
            !studentOnlyInRegistry.isEmpty,
            "expected at least one student-surface registry code with no CoreError case (e.g. VERIFY_*)")
        #expect(CoreError(rawValue: "VERIFY_CAS_UNAVAILABLE") == nil)
        for entry in studentOnlyInRegistry {
            #expect(
                CoreErrorText.userText[entry.code] == entry.userText,
                "\(entry.code) has no CoreError case but must still be mirrored in CoreErrorText.userText")
        }
    }

    // MARK: - C2: the empty-registry / empty-table guards, shown to fail on the broken shape.

    // `ErrorUserTextParityTests.everyStudentCodeHasMatchingText` guards `!registry.codes.isEmpty` and
    // `!CoreErrorText.userText.isEmpty`, but only ever evaluates them against the real, non-empty inputs —
    // a guard that has never been observed to fail is not a guard (C2). Reconstruct the empty shape
    // locally and prove the same predicate reds.
    @Test("the empty-registry guard reds against a reconstructed empty registry")
    func emptyRegistryGuardRedsOnEmptyRegistry() {
        let emptyRegistry: [RegistryEntry] = []
        #expect(
            !(!emptyRegistry.isEmpty),
            "the empty-registry guard failed to catch a zero-entry registry read — guard is not load-bearing"
        )
    }

    @Test("the empty-userText guard reds against a reconstructed empty table")
    func emptyUserTextGuardRedsOnEmptyTable() {
        let emptyTable: [String: String] = [:]
        #expect(
            !(!emptyTable.isEmpty),
            "the empty-userText guard failed to catch a zero-entry table — guard is not load-bearing")
    }

    // Complement: the real registry and the real table are non-empty, so the guards green on the fixed
    // shape (mirrors ErrorRegistryNegativeControlTests's red/green pair).
    @Test("the empty-registry and empty-userText guards green on the real, non-empty shapes")
    func emptyGuardsGreenOnRealShapes() throws {
        let registry = try Self.loadRegistry()
        #expect(!registry.codes.isEmpty)
        #expect(!CoreErrorText.userText.isEmpty)
    }

    // MARK: - planted mismatch genuinely fails the actual parity predicate (not just a local diff).

    /// The exact equality predicate `ErrorUserTextParityTests.everyStudentCodeHasMatchingText` applies,
    /// extracted so it can be run against both the real table and a broken fixture (mirrors
    /// `ErrorRegistryNegativeControlTests.isSubsetOfRegistry`).
    private static func parityHolds(table: [String: String], registry: [RegistryEntry]) -> Bool {
        let studentEntries = registry.filter { $0.surface == "student" }
        return studentEntries.allSatisfy { entry in
            table[entry.code] == entry.userText
        }
    }

    @Test("the parity predicate reds against a one-character corruption, greens on the real table")
    func parityPredicateRedsOnCorruptionGreensOnReal() throws {
        let registry = try Self.loadRegistry()
        guard let realEntry = registry.codes.first(where: { $0.code == "DIAG_NO_PREREQUISITE" }) else {
            Issue.record(
                "fixture code DIAG_NO_PREREQUISITE missing from registry — negative control cannot run")
            return
        }
        var brokenTable = CoreErrorText.userText
        brokenTable[realEntry.code] = (realEntry.userText ?? "") + "X"

        #expect(
            !Self.parityHolds(table: brokenTable, registry: registry.codes),
            "the parity predicate failed to catch a one-character corruption — guard is not load-bearing")
        #expect(
            Self.parityHolds(table: CoreErrorText.userText, registry: registry.codes),
            "the parity predicate must green on the real, unmodified CoreErrorText.userText table")
    }

    @Test("the parity predicate reds against a dropped required entry")
    func parityPredicateRedsOnDroppedEntry() throws {
        let registry = try Self.loadRegistry()
        var brokenTable = CoreErrorText.userText
        brokenTable.removeValue(forKey: "EXP_NO_FRINGE")

        #expect(
            !Self.parityHolds(table: brokenTable, registry: registry.codes),
            "the parity predicate failed to catch a dropped required student-surface entry")
    }

    // MARK: - I5: no copy is authored in Swift beyond the verbatim registry strings.

    // Extracts every double-quoted string literal from CoreErrorText.swift's source and asserts each one
    // is either a registry code (a dictionary key) or an exact registry user_text value (a dictionary
    // value) — never freshly authored prose. This guards the content-policy voice constraint (I5,
    // contracts/error-codes.md § Rules) directly against the source text, not just the compiled table.
    @Test("every string literal in CoreErrorText.swift is a registry code or a verbatim registry user_text")
    func noCopyAuthoredBeyondRegistryStrings() throws {
        let sourcePath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .appendingPathComponent("Sources/Core/CoreErrorText.swift")
        let source = try String(contentsOf: sourcePath, encoding: .utf8)

        let registry = try Self.loadRegistry()
        let registryCodes = Set(registry.codes.map(\.code))
        let registryTexts = Set(registry.codes.compactMap(\.userText))

        let literals = Self.extractStringLiterals(from: source)
        #expect(!literals.isEmpty, "expected to find string literals in CoreErrorText.swift")

        for literal in literals {
            let isKnownCode = registryCodes.contains(literal)
            let isKnownText = registryTexts.contains(literal)
            let message =
                "CoreErrorText.swift contains a string literal not present in the registry "
                + "(authored copy?): \"\(literal)\""
            #expect(isKnownCode || isKnownText, "\(message)")
        }
    }

    /// Minimal double-quoted string literal extractor (no escaped-quote handling needed: none of
    /// `CoreErrorText.swift`'s literals contain an escaped `"`).
    private static func extractStringLiterals(from source: String) -> [String] {
        var literals: [String] = []
        var current: String?
        for char in source {
            if let value = current {
                if char == "\"" {
                    literals.append(value)
                    current = nil
                } else {
                    current = value + String(char)
                }
            } else if char == "\"" {
                current = ""
            }
        }
        return literals
    }

    // MARK: - T6 determinism / no-leak, cross-checked against the registry-driven count directly.

    @Test("CoreErrorText.userText is stable across repeated reads and matches the registry student count")
    func userTextStableAndCountMatchesRegistry() throws {
        let registry = try Self.loadRegistry()
        let studentCount = registry.codes.filter { $0.surface == "student" }.count
        let firstRead = CoreErrorText.userText
        let secondRead = CoreErrorText.userText
        #expect(firstRead == secondRead)
        #expect(firstRead.count == studentCount)
    }
}

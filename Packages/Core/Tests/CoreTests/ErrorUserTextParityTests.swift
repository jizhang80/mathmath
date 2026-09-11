import Foundation
import Testing

@testable import Core

@Suite("CoreErrorText parity with error-codes.json student-surface entries")
struct ErrorUserTextParityTests {
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

    @Test("every student-surface registry code has a matching, non-nil CoreErrorText entry")
    func everyStudentCodeHasMatchingText() throws {
        let registry = try Self.loadRegistry()
        let studentEntries = registry.codes.filter { $0.surface == "student" }

        #expect(!registry.codes.isEmpty, "empty registry read is a FAIL")
        #expect(!studentEntries.isEmpty, "no student-surface entries found — registry read is suspect")
        #expect(!CoreErrorText.userText.isEmpty, "empty CoreErrorText.userText is a FAIL")

        for entry in studentEntries {
            let mirrored = CoreErrorText.userText[entry.code]
            #expect(mirrored != nil, "\(entry.code) is student-surface but has no CoreErrorText entry")
            #expect(
                mirrored == entry.userText,
                "\(entry.code): CoreErrorText text does not match the registry's user_text")
        }
    }

    @Test("every CoreErrorText entry has a matching student-surface registry entry (no orphans)")
    func noOrphanTextEntries() throws {
        let registry = try Self.loadRegistry()
        let studentByCode = Dictionary(
            uniqueKeysWithValues: registry.codes.filter { $0.surface == "student" }.map {
                ($0.code, $0.userText)
            })

        for (code, text) in CoreErrorText.userText {
            #expect(
                studentByCode[code] != nil,
                "\(code) in CoreErrorText but not a student-surface registry entry")
            #expect(studentByCode[code] ?? nil == text, "\(code): orphan text does not match the registry")
        }
    }

    @Test("no internal or owner code carries a CoreErrorText entry")
    func noInternalOrOwnerTextEntries() throws {
        let registry = try Self.loadRegistry()
        let nonStudentCodes = Set(
            registry.codes.filter { $0.surface != "student" }.map(\.code))

        for code in CoreErrorText.userText.keys {
            #expect(
                !nonStudentCodes.contains(code),
                "\(code) is internal/owner surface but carries a CoreErrorText entry")
        }
    }

    // T4: the mirror is total, not just a non-empty subset — the entry count matches exactly.
    @Test("CoreErrorText.userText has exactly one entry per student-surface registry code")
    func mirrorIsTotal() throws {
        let registry = try Self.loadRegistry()
        let studentCount = registry.codes.filter { $0.surface == "student" }.count
        #expect(CoreErrorText.userText.count == studentCount)
    }

    // AC4: planted-mismatch negative control. Builds a local, broken copy of the parity check — never
    // touches product code — and proves the same equality assertion reds on it, then greens on the real
    // table. A guard never shown to fail is not a guard (C2, mirroring
    // ErrorRegistryNegativeControlTests's pattern).
    @Test("parity guard reds against a planted one-character text mismatch")
    func parityGuardRedsOnPlantedMismatch() throws {
        let registry = try Self.loadRegistry()
        guard let realEntry = registry.codes.first(where: { $0.code == "MAP_MARKER_OFF_TRAIL" }) else {
            Issue.record(
                "fixture code MAP_MARKER_OFF_TRAIL missing from registry — negative control cannot run")
            return
        }
        var brokenTable = CoreErrorText.userText
        brokenTable["MAP_MARKER_OFF_TRAIL"] = (realEntry.userText ?? "") + "X"

        #expect(
            brokenTable["MAP_MARKER_OFF_TRAIL"] != realEntry.userText,
            "the planted mismatch guard failed to differ from the registry — guard is not load-bearing"
        )
    }

    // AC4: planted-mismatch negative control, orphan-entry variant.
    @Test("parity guard reds against a planted registry-absent code")
    func parityGuardRedsOnPlantedOrphan() throws {
        let registry = try Self.loadRegistry()
        var brokenTable = CoreErrorText.userText
        brokenTable["CORE_MADE_UP_CODE_NOT_IN_REGISTRY"] = "This is a planted failure."

        let studentCodes = Set(registry.codes.filter { $0.surface == "student" }.map(\.code))
        let orphans = brokenTable.keys.filter { !studentCodes.contains($0) }

        #expect(
            !orphans.isEmpty,
            "the orphan guard failed to catch a code absent from the registry — guard is not load-bearing"
        )
    }
}

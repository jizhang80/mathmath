import Foundation
import Testing

@testable import Core

/// C2: negative control for `ErrorRegistryTests`'s subset guard. A guard never shown to fail is not a
/// guard — this reconstructs a `CoreError`-shaped code set that includes a rogue code absent from
/// `contracts/error-codes.json` and proves the same subset assertion reds on it, then greens on the
/// real `CoreError.allCases` (mirroring `contracts/error-codes.md` § Rules: "A code raised in code but
/// absent from the registry fails the round-trip test").
///
/// Does not modify `CoreError` (product code) — the broken shape is a local fixture, not the enum.
@Suite("CoreError registry: negative control (C2)")
struct ErrorRegistryNegativeControlTests {
    private struct RegistryEntry: Decodable {
        let code: String
    }

    private struct Registry: Decodable {
        let codes: [RegistryEntry]
    }

    private static func registryCodes() throws -> Set<String> {
        let registryPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/error-codes.json")
        let data = try Data(contentsOf: registryPath)
        let registry = try JSONDecoder().decode(Registry.self, from: data)
        return Set(registry.codes.map(\.code))
    }

    /// Same subset check `ErrorRegistryTests` performs, extracted so it can be applied to a broken
    /// fixture as well as the real enum.
    private static func isSubsetOfRegistry(_ codes: [String], registry: Set<String>) -> Bool {
        codes.allSatisfy { registry.contains($0) }
    }

    @Test("subset guard reds against a rogue code not present in the registry")
    func subsetGuardRedsOnRogueCode() throws {
        let registry = try Self.registryCodes()
        // Reconstruct the defect: a code set shaped like CoreError.allCases but carrying one code
        // that does not exist in the registry (as if a future case were added to CoreError without a
        // matching registry entry).
        let brokenCodes = CoreError.allCases.map(\.rawValue) + ["CORE_MADE_UP_CODE_NOT_IN_REGISTRY"]
        #expect(
            !Self.isSubsetOfRegistry(brokenCodes, registry: registry),
            "the subset guard failed to catch a code absent from the registry — guard is not load-bearing"
        )
    }

    @Test("subset guard greens against the real CoreError.allCases (fixed shape)")
    func subsetGuardGreensOnRealCoreError() throws {
        let registry = try Self.registryCodes()
        let realCodes = CoreError.allCases.map(\.rawValue)
        #expect(Self.isSubsetOfRegistry(realCodes, registry: registry))
    }
}

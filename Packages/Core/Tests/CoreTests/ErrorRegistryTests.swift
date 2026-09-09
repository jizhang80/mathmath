import Foundation
import Testing

@testable import Core

@Suite("CoreError registry (contracts/error-codes.json)")
struct ErrorRegistryTests {
    private struct RegistryEntry: Decodable {
        let code: String
    }

    private struct Registry: Decodable {
        let codes: [RegistryEntry]
    }

    // AC3: every case of `CoreError` is present in `contracts/error-codes.json`, read from disk at
    // test time; an empty `CoreError` case set or an empty registry read is a FAIL.
    @Test("CoreError.allCases is a subset of the error-codes.json registry")
    func coreErrorIsSubsetOfRegistry() throws {
        let registryPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/error-codes.json")

        let data = try Data(contentsOf: registryPath)
        let registry = try JSONDecoder().decode(Registry.self, from: data)
        let registryCodes = Set(registry.codes.map(\.code))

        #expect(!registryCodes.isEmpty, "empty registry read is a FAIL")
        #expect(!CoreError.allCases.isEmpty, "empty CoreError case set is a FAIL")

        for errorCase in CoreError.allCases {
            #expect(
                registryCodes.contains(errorCase.rawValue),
                "\(errorCase.rawValue) raised in Core but absent from the registry")
        }
    }
}

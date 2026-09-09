import Foundation
import Testing

@testable import Core

/// Negative decode coverage deepening `DecodeRoundTripTests`: `contracts/data-model.md` § Nulls says
/// "Optional means the key is absent, never null. Enums are closed; an unknown value fails decode."
/// and every object schema sets `additionalProperties: false`. This suite proves the untrusted-input
/// boundary — malformed document, missing required field, wrong-typed field, out-of-enum value — fails
/// with a diagnosable `DecodingError` rather than a silent default, for more than the one case the
/// implementer's smoke already covers (`unrecognizedEnumValueFailsDecode`, `nodes.json` only).
@Suite("Model decode: negative input (contracts/data-model.md § Nulls)")
struct ModelDecodeNegativeTests {
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/examples")
    }

    private static func loadJSONObject(_ file: String) throws -> [String: Any] {
        let data = try Data(contentsOf: examplesDir.appendingPathComponent(file))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // Malformed document: truncated / syntactically invalid JSON is not a valid document at all.
    @Test("truncated JSON fails decode with a diagnosable error, not a silent default")
    func malformedDocumentFailsDecode() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("manifest.json"))
        // Chop the document mid-stream — guaranteed-invalid JSON regardless of file contents.
        let truncated = data.prefix(data.count / 2)
        #expect(throws: (any Error).self) {
            try CoreCoding.decoder.decode(Manifest.self, from: Data(truncated))
        }
    }

    // Missing required field: `nodes.schema.json` requires `region_id` on every node.
    @Test("missing required field (Node.region_id) fails decode with keyNotFound")
    func missingRequiredFieldFailsDecode() throws {
        var json = try Self.loadJSONObject("nodes.json")
        var nodes = try #require(json["nodes"] as? [[String: Any]])
        nodes[0].removeValue(forKey: "region_id")
        json["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(NodesFile.self, from: mutated)
        }
    }

    // Wrong-typed field: `Manifest.formatVersion` is a String; feeding a number must fail, not coerce.
    @Test("wrong-typed field (Manifest.format_version as number) fails decode with typeMismatch")
    func wrongTypedFieldFailsDecode() throws {
        var json = try Self.loadJSONObject("manifest.json")
        json["format_version"] = 1
        let mutated = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(Manifest.self, from: mutated)
        }
    }

    // Wrong-typed field, second instance in a different file/type: `Region.horizon` is a Bool.
    @Test("wrong-typed field (Region.horizon as string) fails decode with typeMismatch")
    func wrongTypedBooleanFieldFailsDecode() throws {
        var json = try Self.loadJSONObject("regions.json")
        var regions = try #require(json["regions"] as? [[String: Any]])
        regions[0]["horizon"] = "not-a-bool"
        json["regions"] = regions
        let mutated = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(RegionsFile.self, from: mutated)
        }
    }

    // Out-of-enum value on a second, independent closed vocabulary: `ProbeItemType` (`numeric | mc`).
    // Deepens the implementer's single `region_id` case (T2) with a different enum, different file.
    @Test("out-of-enum ProbeItem.type value fails decode")
    func outOfEnumProbeItemTypeFailsDecode() throws {
        var json = try Self.loadJSONObject("nodes.json")
        var nodes = try #require(json["nodes"] as? [[String: Any]])
        var items = try #require(nodes[0]["probe_items"] as? [[String: Any]])
        items[0]["type"] = "free-text"
        nodes[0]["probe_items"] = items
        json["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(NodesFile.self, from: mutated)
        }
    }

    // Out-of-enum value inside `StudentState` (I5's own type): `Mastery ∈ {fog, cleared, blocked}`.
    @Test("out-of-enum StudentState mastery value fails decode")
    func outOfEnumMasteryFailsDecode() throws {
        var json = try Self.loadJSONObject("student-state.json")
        var nodes = try #require(json["nodes"] as? [String: [String: Any]])
        var node = try #require(nodes["exponent-laws"])
        node["mastery"] = "unknown"
        nodes["exponent-laws"] = node
        json["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json)

        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(StudentState.self, from: mutated)
        }
    }
}

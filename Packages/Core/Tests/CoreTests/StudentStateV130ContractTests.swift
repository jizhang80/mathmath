import Foundation
import Testing

@testable import Core

/// Tester-added coverage for contract v1.3.0 (task 02.2, arbiter rulings Q-A / Q-F,
/// `contracts/data-model.md` § StudentState) that the implementer's smoke
/// (`OptionalAbsentTests.markerAndNodeStateRoundTripNewOptionalFields`,
/// `DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode`) does not exercise: the symmetric
/// `Marker.pastLastUnit` boundary case (AC6 only literally names three negative controls, and the
/// third is `remediated`-only), and the identity-migration claim ("a version-1 document is a valid
/// version-2 document with every `remediated` absent", § StudentState) on the `Core` decode side.
@Suite("StudentState v1.3.0 contract (remediated / past_last_unit)")
struct StudentStateV130ContractTests {
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("contracts/examples")
    }

    // T2 boundary case AC6 does not literally instrument: a non-boolean `past_last_unit` fails Core
    // decode, mirroring `DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode` for the sibling
    // field (contracts/data-model.md § Nulls: closed shape, no silent widening).
    @Test("non-boolean past_last_unit value fails decode")
    func pastLastUnitNonBooleanValueFailsDecode() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        var marker = try #require(json?["marker"] as? [String: Any])
        marker["past_last_unit"] = "yes"
        json?["marker"] = marker
        let mutated = try JSONSerialization.data(withJSONObject: json as Any)
        #expect(throws: DecodingError.self) {
            try CoreCoding.decoder.decode(StudentState.self, from: mutated)
        }
    }

    // Migration identity (arbiter Q-A, contracts/data-model.md § StudentState): "a version-1 document
    // is a valid version-2 document with every `remediated` absent." Builds a v1-shaped document in
    // memory (schema_version 1, no `remediated` anywhere, no `past_last_unit`) and proves it decodes
    // cleanly with both new fields resolving to `nil` on every node/marker.
    @Test("a v1-shaped document (schema_version 1, both new fields absent) decodes cleanly")
    func schemaVersion1DocumentWithoutNewFieldsDecodes() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["schema_version"] = 1
        var nodes = try #require(json["nodes"] as? [String: [String: Any]])
        nodes["matrix-multiplication"]?.removeValue(forKey: "remediated")
        json["nodes"] = nodes
        var marker = try #require(json["marker"] as? [String: Any])
        marker.removeValue(forKey: "past_last_unit")
        json["marker"] = marker
        let mutated = try JSONSerialization.data(withJSONObject: json)

        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: mutated)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.marker.pastLastUnit == nil)
        for (_, node) in decoded.nodes {
            #expect(node.remediated == nil, "a v1-shaped document must decode every remediated as nil")
        }
    }

    // T5 negative control: proves `remediated`'s round-trip test really exercises the true case by
    // showing the fixture's declared value (not a hardcoded literal in the test) drives the assertion —
    // flipping the fixture value to false must decode to false, not to a test-hardcoded true.
    @Test("remediated: false on a node survives decode as false, not omitted or coerced to true")
    func remediatedFalseSurvivesDecodeDistinctFromAbsent() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var nodes = try #require(json["nodes"] as? [String: [String: Any]])
        nodes["matrix-multiplication"]?["remediated"] = false
        json["nodes"] = nodes
        let mutated = try JSONSerialization.data(withJSONObject: json)

        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: mutated)
        let node = try #require(decoded.nodes["matrix-multiplication"])
        #expect(node.remediated == false, "remediated: false must decode to Optional(false), not nil")

        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedNodes = try #require(reencodedJSON["nodes"] as? [String: [String: Any]])
        let reencodedNode = try #require(reencodedNodes["matrix-multiplication"])
        #expect(
            (reencodedNode["remediated"] as? Bool) == false,
            "re-encoded remediated:false must not be dropped or flipped")
    }
}

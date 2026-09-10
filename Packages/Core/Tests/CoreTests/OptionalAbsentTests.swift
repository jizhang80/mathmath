import Foundation
import Testing

@testable import Core

/// Deepens AC5 beyond the implicit structural-equality check in `DecodeRoundTripTests`: directly
/// asserts the re-encoded JSON object literally omits the key for an absent optional field, rather
/// than emitting `null` (`contracts/data-model.md` § Nulls: "Optional means the key is absent, never
/// null."). A regression that swapped `encodeIfPresent` semantics for `encode` on an `Optional` stored
/// property would emit `"layout_hint": null`, which `JSONSerialization` still parses — this test would
/// catch that case even if a future structural-equality comparator started normalising `NSNull` away.
@Suite("Optional-means-absent (contracts/data-model.md § Nulls, AC5)")
struct OptionalAbsentTests {
    private static var examplesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/examples")
    }

    // `contracts/examples/nodes.json`'s first node has no `layout_hint`, `source_ref`,
    // `explanation`, or `worked_examples` — all four are Optional on `Node`.
    @Test(
        "Node re-encodes without null for absent optional keys (layout_hint, source_ref, explanation, worked_examples)"
    )
    func nodeOmitsAbsentOptionalKeys() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("nodes.json"))
        let sourceJSON = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sourceNodes = try #require(sourceJSON["nodes"] as? [[String: Any]])
        // Precondition: the fixture really is missing these keys (guards this test against fixture drift).
        for key in ["layout_hint", "source_ref", "explanation", "worked_examples"] {
            #expect(
                sourceNodes[0][key] == nil, "fixture precondition failed: node[0] unexpectedly has \(key)")
        }

        let decoded = try CoreCoding.decoder.decode(NodesFile.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedNodes = try #require(reencodedJSON["nodes"] as? [[String: Any]])

        for key in ["layout_hint", "source_ref", "explanation", "worked_examples"] {
            #expect(
                reencodedNodes[0][key] == nil,
                "re-encoded node[0] emitted a key for absent optional \(key) (should be omitted, not null)")
        }
    }

    // `contracts/examples/courses.json`'s course has `unit_source` present, but this proves the same
    // guard on a different bundle file / different Optional field than the node case above.
    @Test("StudentState.NodeState re-encodes without null for absent last_probe/next_due")
    func nodeStateOmitsAbsentOptionalKeys() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let sourceJSON = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sourceNodes = try #require(sourceJSON["nodes"] as? [String: [String: Any]])
        let sourceExpFns = try #require(sourceNodes["exponential-functions"])
        for key in ["last_probe", "next_due"] {
            #expect(
                sourceExpFns[key] == nil,
                "fixture precondition failed: exponential-functions unexpectedly has \(key)")
        }

        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedNodes = try #require(reencodedJSON["nodes"] as? [String: [String: Any]])
        let reencodedExpFns = try #require(reencodedNodes["exponential-functions"])

        for key in ["last_probe", "next_due"] {
            #expect(
                reencodedExpFns[key] == nil,
                "re-encoded exponential-functions emitted a key for absent optional \(key)")
        }
    }

    @Test("StudentState.Marker/NodeState round-trip the new optional fields (past_last_unit, remediated)")
    func markerAndNodeStateRoundTripNewOptionalFields() throws {
        let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
        let sourceJSON = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sourceMarker = try #require(sourceJSON["marker"] as? [String: Any])
        #expect(
            sourceMarker["past_last_unit"] == nil,
            "fixture precondition failed: marker unexpectedly has past_last_unit")
        let sourceNodes = try #require(sourceJSON["nodes"] as? [String: [String: Any]])
        let sourceExponentLaws = try #require(sourceNodes["exponent-laws"])
        #expect(
            sourceExponentLaws["remediated"] == nil,
            "fixture precondition failed: exponent-laws unexpectedly has remediated")
        let sourceMatrixMultiplication = try #require(sourceNodes["matrix-multiplication"])
        let declaredRemediated = try #require(sourceMatrixMultiplication["remediated"] as? Bool)
        #expect(
            declaredRemediated == true,
            "fixture precondition failed: matrix-multiplication.remediated != true")

        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
        #expect(decoded.marker.pastLastUnit == nil)
        #expect(decoded.nodes["exponent-laws"]?.remediated == nil)
        #expect(decoded.nodes["matrix-multiplication"]?.remediated == true)

        let reencoded = try CoreCoding.encoder.encode(decoded)
        let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedMarker = try #require(reencodedJSON["marker"] as? [String: Any])
        #expect(
            reencodedMarker["past_last_unit"] == nil,
            "re-encoded marker emitted a key for absent optional past_last_unit")
        let reencodedNodes = try #require(reencodedJSON["nodes"] as? [String: [String: Any]])
        let reencodedExponentLaws = try #require(reencodedNodes["exponent-laws"])
        #expect(
            reencodedExponentLaws["remediated"] == nil,
            "re-encoded exponent-laws emitted a key for absent optional remediated")
        let reencodedMatrixMultiplication = try #require(reencodedNodes["matrix-multiplication"])
        #expect(
            (reencodedMatrixMultiplication["remediated"] as? Bool) == true,
            "re-encoded matrix-multiplication lost its remediated:true value")
    }
}

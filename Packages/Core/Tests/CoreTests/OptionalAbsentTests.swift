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

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
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

        let decoded = try Self.decoder.decode(NodesFile.self, from: data)
        let reencoded = try Self.encoder.encode(decoded)
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

        // `StudentState` requires `.useDefaultKeys` (see the BLOCK filed against this task).
        let decoded = try JSONDecoder().decode(StudentState.self, from: data)
        let reencoded = try Self.encoder.encode(decoded)
        let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
        let reencodedNodes = try #require(reencodedJSON["nodes"] as? [String: [String: Any]])
        let reencodedExpFns = try #require(reencodedNodes["exponential-functions"])

        for key in ["last_probe", "next_due"] {
            #expect(
                reencodedExpFns[key] == nil,
                "re-encoded exponential-functions emitted a key for absent optional \(key)")
        }
    }
}

import Foundation
import Testing

@testable import Core

/// I5: `studentStateWireKeysRejectIdentifierBlocklist()` (in `DecodeRoundTripTests.swift`) uses a
/// Swift-literal identifier blocklist that is supposed to mirror
/// `pipeline/tests/test_contracts.py::test_transmitted_shapes_reject_identifier_keys`'s
/// `IDENTIFIER_BLOCKLIST` exactly (task spec §3, verbatim quote). This suite parses the Python
/// source's `IDENTIFIER_BLOCKLIST` literal at test time and asserts it is exactly the same set — so a
/// future edit to either blocklist that silently drifts them apart is caught here, not just asserted
/// by comment.
@Suite("Identifier blocklist parity with pipeline/tests/test_contracts.py (I5)")
struct IdentifierBlocklistParityTests {
    /// The blocklist used by `StudentState`'s I5 guard test (task spec §3, verbatim from
    /// `pipeline/tests/test_contracts.py:26-36` read at task-write time).
    private static let swiftSideBlocklist: Set<String> = [
        "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
    ]

    private static func pipelineBlocklist() throws -> Set<String> {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("pipeline/tests/test_contracts.py")
        let text = try String(contentsOf: path, encoding: .utf8)

        // Extract the literal block between `IDENTIFIER_BLOCKLIST = {` and the matching `}`.
        guard let startRange = text.range(of: "IDENTIFIER_BLOCKLIST = {") else {
            Issue.record("IDENTIFIER_BLOCKLIST literal not found in pipeline/tests/test_contracts.py")
            return []
        }
        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: "}") else {
            Issue.record("IDENTIFIER_BLOCKLIST literal has no closing brace")
            return []
        }
        let body = afterStart[..<endRange.lowerBound]

        let regex = try NSRegularExpression(pattern: "\"([a-z_]+)\"")
        let bodyString = String(body)
        let nsBody = bodyString as NSString
        let matches = regex.matches(in: bodyString, range: NSRange(location: 0, length: nsBody.length))
        return Set(matches.map { nsBody.substring(with: $0.range(at: 1)) })
    }

    @Test("pipeline IDENTIFIER_BLOCKLIST is non-empty (anti-vacuity on the read side)")
    func pipelineBlocklistIsNonEmpty() throws {
        #expect(
            !(try Self.pipelineBlocklist()).isEmpty,
            "empty parse of pipeline/tests/test_contracts.py is a FAIL")
    }

    @Test("Swift-side blocklist is exactly the pipeline IDENTIFIER_BLOCKLIST")
    func blocklistsMatchExactly() throws {
        let pipeline = try Self.pipelineBlocklist()
        let extraInSwift = Self.swiftSideBlocklist.subtracting(pipeline)
        let extraInPipeline = pipeline.subtracting(Self.swiftSideBlocklist)
        let message =
            "blocklist drift: Swift has \(extraInSwift) extra, pipeline has \(extraInPipeline) extra"
        #expect(Self.swiftSideBlocklist == pipeline, "\(message)")
    }
}

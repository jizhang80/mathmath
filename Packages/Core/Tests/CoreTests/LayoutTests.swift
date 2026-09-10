import Foundation
import Testing

@testable import Core

@Suite("Layout (region-constrained force layout)")
struct LayoutTests {
    /// `Packages/Core/Tests/CoreTests/Fixtures/layout`, located the same way `L0CheckerTests` locates
    /// `Fixtures/l0`: from `#filePath`, one `.deletingLastPathComponent()` call reaches
    /// `Packages/Core/Tests/CoreTests`, then `.appendingPathComponent("Fixtures/layout")`.
    private static var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .appendingPathComponent("Fixtures/layout")
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static func loadRegions(_ name: String) throws -> RegionsFile {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent(name))
        return try decoder.decode(RegionsFile.self, from: data)
    }

    private static func loadNodes(_ name: String) throws -> NodesFile {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent(name))
        return try decoder.decode(NodesFile.self, from: data)
    }

    // AC1: every node lands inside its own region polygon, asserted per node.
    @Test("layout places every node inside its own region polygon")
    func layoutPlacesEveryNodeInsideItsRegion() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        let nodesFile = try Self.loadNodes("nodes-happy.json")

        // Anti-vacuity guard: an empty node set would make the per-node loop below vacuously pass.
        #expect(nodesFile.nodes.count == 10)

        let config = LayoutConfig()
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let result = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, config: config, rng: &rng
        )

        let polygonByRegion = Dictionary(uniqueKeysWithValues: regions.regions.map { ($0.id, $0.polygon) })
        for node in nodesFile.nodes {
            let position = try #require(result[node.id])
            let polygon = try #require(polygonByRegion[node.regionId])
            #expect(Polygon.contains(position, in: polygon, epsilon: config.boundaryEpsilon))
        }
    }

    // AC2: two calls with the same seed produce byte-identical encoded output.
    @Test("layout is deterministic for the same seed")
    func layoutIsDeterministicForTheSameSeed() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        let nodesFile = try Self.loadNodes("nodes-happy.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var rngA = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let resultA = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, rng: &rngA
        )
        var rngB = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let resultB = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, rng: &rngB
        )

        let dataA = try encoder.encode(resultA)
        let dataB = try encoder.encode(resultB)
        #expect(dataA == dataB)
    }

    // AC3: a differently-seeded call produces a different arrangement — the anti-vacuity guard on AC2.
    @Test("a different seed changes the arrangement")
    func aDifferentSeedChangesTheArrangement() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        let nodesFile = try Self.loadNodes("nodes-happy.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var rngA = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let resultA = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, rng: &rngA
        )
        var rngC = SeededGenerator(seed: LayoutConfig.defaultSeed &+ 1)
        let resultC = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, rng: &rngC
        )

        let dataA = try encoder.encode(resultA)
        let dataC = try encoder.encode(resultC)
        #expect(dataA != dataC)
    }

    // AC4: a node whose region_id names a wholly absent region throws mapRegionUnknown.
    @Test("a node in an unknown region throws mapRegionUnknown")
    func aNodeInAnUnknownRegionThrowsMapRegionUnknown() throws {
        let regions = try Self.loadRegions("regions-missing-discrete.json")
        let nodesFile = try Self.loadNodes("nodes-unknown-region.json")
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)

        #expect(throws: CoreError.mapRegionUnknown) {
            try LayoutEngine.layout(nodes: nodesFile.nodes, regions: regions.regions, rng: &rng)
        }
    }

    // AC5: a node whose region_id names a present-but-horizon region also throws mapRegionUnknown.
    @Test("a node in a horizon region throws mapRegionUnknown")
    func aNodeInAHorizonRegionThrowsMapRegionUnknown() throws {
        let regions = try Self.loadRegions("regions-ten-plus-horizon.json")
        let nodesFile = try Self.loadNodes("nodes-horizon-region.json")
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)

        #expect(throws: CoreError.mapRegionUnknown) {
            try LayoutEngine.layout(nodes: nodesFile.nodes, regions: regions.regions, rng: &rng)
        }
    }

    // AC6: every tuning constant lives in LayoutConfig, referenced by name; no bare numeric literal at a
    // call site in LayoutEngine.swift or Polygon.swift, other than 0, 1, loop indices, and array/tuple
    // indexing (AC6's exact allowlist). This is a text-level regression guard (not a semantic one): it
    // scans for ANY bare numeric literal (float or integer, including single digits) and flags every one
    // except a value-level allowlist of `0`/`1` — every loop index and array/tuple index in these two
    // files is itself always written as `0` or `1` (e.g. `polygon[0]`, `index + 1`, `polygon.count - 1`),
    // so that value-level allowlist alone already covers every indexing/loop-bound use here. The one
    // further, narrowly-scoped exception is the literal `3` where it appears directly compared against
    // `.count` (`polygon.count >= 3` / `region.polygon.count >= 3`) — the schema-mandated minimum vertex
    // count for a sequence of points to be a polygon at all (`regions.schema.json`'s `minItems: 3`), a
    // structural arity check, not a layout tuning knob, so not a `LayoutConfig` candidate; this exception
    // is matched by position (adjacency to `.count`), not by value, so a `3` appearing anywhere else would
    // still be flagged. A literal like `0.0005`, `42`, or a bare `5` typed directly into either file
    // (outside that one arity comparison) would make this test fail.
    @Test("LayoutConfig is the only source of tuning constants")
    func layoutConfigIsTheOnlySourceOfTuningConstants() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core/Layout")

        let filesToScan = ["LayoutEngine.swift", "Polygon.swift"]
        // Matches any bare numeric literal: a float (e.g. 0.0005) or a bare integer of any digit count,
        // including a single digit (e.g. 5) — AC6 permits only 0 and 1 among bare literals, so no digit
        // count is exempted by width alone.
        let literalPattern = try NSRegularExpression(pattern: #"\b\d+\.\d+\b|\b\d+\b"#)
        // The one position-based exception: `3` immediately compared against `.count` — the polygon
        // minimum-vertex arity check, not a tuning constant (comment above).
        let countArityPattern = try NSRegularExpression(
            pattern: #"\.count\s*(>=|<=|<|>)\s*3\b|\b3\s*(<=|>=|<|>)\s*\S*\.count\b"#
        )

        var violations: [String] = []
        for fileName in filesToScan {
            let url = sourcesDir.appendingPathComponent(fileName)
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (lineNumber, line) in lines.enumerated() {
                // A `//`/`///` doc comment is prose (e.g. "L0-6", "Step 3") and is not a call site AC6
                // governs — only code lines are scanned, same rule the I14 randomness-source scan in
                // `LayoutRegressionTests.swift` already applies.
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    continue
                }
                let stringLine = String(line)
                let nsLine = stringLine as NSString
                let searchRange = NSRange(location: 0, length: nsLine.length)
                let isArityLine =
                    countArityPattern.firstMatch(in: stringLine, range: searchRange) != nil
                let matches = literalPattern.matches(in: stringLine, range: searchRange)
                for match in matches {
                    let matchedText = nsLine.substring(with: match.range)
                    if matchedText == "0" || matchedText == "1" {
                        continue
                    }
                    if matchedText == "3" && isArityLine {
                        continue
                    }
                    violations.append("\(fileName):\(lineNumber + 1): \(matchedText)")
                }
            }
        }
        #expect(violations.isEmpty, "bare numeric literals found: \(violations)")
    }
}

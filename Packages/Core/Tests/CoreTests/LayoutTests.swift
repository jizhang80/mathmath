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
    // call site in LayoutEngine.swift or Polygon.swift. This is a text-level regression guard (not a
    // semantic one): it scans for numeric literals containing a decimal point, or bare integer literals
    // with more than one digit, and allows only `0`/`1`/loop-and-array-index usage by excluding lines
    // matched by common indexing/looping idioms. A literal like `0.0005` typed directly into either file
    // would make this test fail.
    @Test("LayoutConfig is the only source of tuning constants")
    func layoutConfigIsTheOnlySourceOfTuningConstants() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core/Layout")

        let filesToScan = ["LayoutEngine.swift", "Polygon.swift"]
        // Matches a float literal (e.g. 0.0005) or a bare integer literal of two or more digits
        // (e.g. 42), which would indicate a tuning constant typed directly at a call site instead of
        // read from `LayoutConfig`. Single-digit integers (0-9) are allowed: loop bounds, array
        // indices and the tolerated `0`/`1`.
        let literalPattern = try NSRegularExpression(pattern: #"\b\d+\.\d+\b|\b\d{2,}\b"#)

        var violations: [String] = []
        for fileName in filesToScan {
            let url = sourcesDir.appendingPathComponent(fileName)
            let text = try String(contentsOf: url, encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (lineNumber, line) in lines.enumerated() {
                let nsLine = line as NSString
                let searchRange = NSRange(location: 0, length: nsLine.length)
                let matches = literalPattern.matches(in: String(line), range: searchRange)
                for match in matches {
                    violations.append("\(fileName):\(lineNumber + 1): \(nsLine.substring(with: match.range))")
                }
            }
        }
        #expect(violations.isEmpty, "bare numeric literals found: \(violations)")
    }
}

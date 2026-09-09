import Foundation
import Testing

@testable import Core

/// Deepened coverage for `tasks/epic-01-task-03-region-constrained-layout.md`, beyond the AC1-AC7 smoke
/// the implementer shipped in `LayoutTests.swift`: purity/order-independence, non-convex containment,
/// clamp-in for an out-of-bounds `layout_hint`, the boundary-inclusive edge rule, the degenerate-polygon
/// throw, exact error-registry codes, anti-vacuity guards on every named fixture, a mutation test on the
/// I11 literal-scan guard, an I14 randomness-source scan, and independently-computed splitmix64
/// known-answer vectors.
@Suite("Layout regression (deepened coverage)")
struct LayoutRegressionTests {
    private static var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .appendingPathComponent("Fixtures/layout")
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static var layoutSourcesDir: URL {
        repoRoot
            .appendingPathComponent("Packages/Core/Sources/Core/Layout")
    }

    // `CoreCoding.decoder` (the single wire coder, per the task brief) — not a hand-built `JSONDecoder`.
    private static func loadRegions(_ name: String) throws -> RegionsFile {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent(name))
        return try CoreCoding.decoder.decode(RegionsFile.self, from: data)
    }

    private static func loadNodes(_ name: String) throws -> NodesFile {
        let data = try Data(contentsOf: fixturesDir.appendingPathComponent(name))
        return try CoreCoding.decoder.decode(NodesFile.self, from: data)
    }

    // MARK: - Anti-vacuity on every fixture the task's plan names

    // A missing fixture throws at `Data(contentsOf:)` and fails the test, per the harness's own rule — no
    // `try?` anywhere in this file lets a missing/unreadable fixture silently no-op.
    @Test("the ten-region fixture really has ten non-horizon regions")
    func tenRegionFixtureReallyHasTen() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        #expect(regions.regions.count == 10)
        #expect(regions.regions.allSatisfy { $0.horizon == false })
    }

    @Test("the missing-discrete fixture really has nine regions")
    func missingDiscreteFixtureReallyHasNine() throws {
        let regions = try Self.loadRegions("regions-missing-discrete.json")
        #expect(regions.regions.count == 9)
        #expect(!regions.regions.contains { $0.id == .discrete })
    }

    @Test("the ten-plus-horizon fixture really has eleven regions, one horizon")
    func tenPlusHorizonFixtureReallyHasEleven() throws {
        let regions = try Self.loadRegions("regions-ten-plus-horizon.json")
        #expect(regions.regions.count == 11)
        #expect(regions.regions.filter { $0.horizon }.count == 1)
    }

    // An empty node set must not vacuously "pass" a per-node containment loop; asserted directly here
    // rather than assumed — the pure function itself must not throw on empty input, and its empty result
    // must not be mistaken for "every node contained" by a loop that never runs.
    @Test("an empty node set returns an empty result, not a vacuous pass")
    func emptyNodeSetReturnsEmptyResult() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let result = try LayoutEngine.layout(nodes: [], regions: regions.regions, rng: &rng)
        #expect(result.isEmpty)
    }

    // MARK: - Containment on a non-convex region, per node, plus the layout_hint clamp-in

    @Test("layout places a node inside a non-convex (L-shaped) region")
    func layoutPlacesNodeInsideNonConvexRegion() throws {
        let regions = try Self.loadRegions("regions-concave.json")
        let nodesFile = try Self.loadNodes("nodes-concave.json")
        #expect(nodesFile.nodes.count == 2)

        // Sanity: the fixture's polygon really is non-convex (a reflex vertex at (0.3, 0.3), the
        // L-shape's inner corner) — otherwise this test would not exercise what it claims to.
        let lShape = try #require(regions.regions.first { $0.id == .geometryMeasurement }).polygon
        #expect(lShape.count == 6, "expected the six-vertex L-shape fixture polygon")

        let config = LayoutConfig()
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let result = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, config: config, rng: &rng
        )

        let polygonByRegion = Dictionary(uniqueKeysWithValues: regions.regions.map { ($0.id, $0.polygon) })
        for node in nodesFile.nodes {
            let position = try #require(result[node.id])
            let polygon = try #require(polygonByRegion[node.regionId])
            #expect(
                Polygon.contains(position, in: polygon, epsilon: config.boundaryEpsilon),
                "\(node.id) landed outside its own region's polygon"
            )
        }
    }

    // `node-concave-hint-outside` carries a layout_hint of (0.8, 0.2), which lies inside the adjacent
    // `algebra` rectangle, NOT inside its own `geometry-measurement` L-shape (max x = 0.6). Per §6's
    // decision default, an out-of-region layout_hint must be treated as absent — the clamp/fallback must
    // pull the node into its OWN region, never leave it in the hinted-but-wrong region.
    @Test("a layout_hint outside its own region is ignored; the node is clamped into its own region")
    func outOfBoundsLayoutHintIsClampedIntoOwnRegion() throws {
        let regions = try Self.loadRegions("regions-concave.json")
        let nodesFile = try Self.loadNodes("nodes-concave.json")
        let node = try #require(nodesFile.nodes.first { $0.id == "node-concave-hint-outside" })

        // The hint itself must indeed fall outside the node's own region and inside the neighbour's —
        // otherwise this is not testing the clamp path at all.
        let ownPolygon = try #require(regions.regions.first { $0.id == .geometryMeasurement }).polygon
        let neighbourPolygon = try #require(regions.regions.first { $0.id == .algebra }).polygon
        let hint = try #require(node.layoutHint)
        let epsilon = LayoutConfig().boundaryEpsilon
        #expect(!Polygon.contains(hint, in: ownPolygon, epsilon: epsilon))
        #expect(Polygon.contains(hint, in: neighbourPolygon, epsilon: epsilon))

        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let result = try LayoutEngine.layout(
            nodes: nodesFile.nodes, regions: regions.regions, rng: &rng
        )
        let finalPosition = try #require(result[node.id])
        #expect(Polygon.contains(finalPosition, in: ownPolygon, epsilon: epsilon))
    }

    // MARK: - Boundary case: a point exactly on a shared polygon edge

    // The spec (§4.3, quoted in the implementation's own doc comment) states the boundary rule
    // explicitly: "a point lying on an edge (within epsilon) counts as inside" — boundary-inclusive, not
    // boundary-exclusive. A point on the shared edge between `number-operations` and `algebra`
    // ((0.2, y) for 0 <= y <= 0.5) must therefore be `contains == true` for BOTH adjoining polygons.
    @Test("a point exactly on a polygon edge is contained, per the spec's boundary-inclusive rule")
    func pointOnEdgeIsContainedPerSpec() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        let numberOps = try #require(regions.regions.first { $0.id == .numberOperations }).polygon
        let algebra = try #require(regions.regions.first { $0.id == .algebra }).polygon
        let onSharedEdge = Point(x: 0.2, y: 0.25)
        let epsilon = LayoutConfig().boundaryEpsilon

        #expect(Polygon.contains(onSharedEdge, in: numberOps, epsilon: epsilon))
        #expect(Polygon.contains(onSharedEdge, in: algebra, epsilon: epsilon))

        // Off the edge by more than epsilon, on either side, must NOT be boundary-contained by the other
        // polygon — otherwise this test could pass on a `contains` that always returns `true`.
        #expect(!Polygon.contains(Point(x: 0.5, y: 0.25), in: numberOps, epsilon: epsilon))
    }

    // MARK: - Degenerate polygon (§6 decision default: < 3 vertices -> mapLayoutMissing)

    @Test("a region with a degenerate (< 3 vertex) polygon throws mapLayoutMissing")
    func degeneratePolygonThrowsMapLayoutMissing() throws {
        let regions = try Self.loadRegions("regions-degenerate.json")
        let nodesFile = try Self.loadNodes("nodes-degenerate.json")
        #expect(regions.regions.first?.polygon.count == 2, "fixture must decode with < 3 vertices")
        var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)

        #expect(throws: CoreError.mapLayoutMissing) {
            try LayoutEngine.layout(nodes: nodesFile.nodes, regions: regions.regions, rng: &rng)
        }
    }

    // MARK: - Exact error-registry codes (not "an error was thrown")

    @Test("mapRegionUnknown and mapLayoutMissing carry the exact registered codes")
    func errorCasesCarryExactRegisteredCodes() throws {
        #expect(CoreError.mapRegionUnknown.rawValue == "MAP_REGION_UNKNOWN")
        #expect(CoreError.mapLayoutMissing.rawValue == "MAP_LAYOUT_MISSING")

        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("contracts/error-codes.json"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let codes = try #require(json?["codes"] as? [[String: Any]])
        #expect(!codes.isEmpty, "empty registry parse is a FAIL, not a vacuous pass")

        for code in ["MAP_REGION_UNKNOWN", "MAP_LAYOUT_MISSING"] {
            let entry = try #require(codes.first { $0["code"] as? String == code })
            #expect(entry["surface"] as? String == "internal")
            #expect(entry["recoverable"] as? Bool == true)
        }
    }

    // MARK: - Purity: interleaving two independent layouts, and order-independence within one call

    // Two wholly independent (nodes, regions) datasets, called in alternating order, must each produce
    // the same result they would produce run in isolation — proof of no hidden global/static state
    // shared between calls (stronger than AC2's "repeat the same call twice").
    @Test("interleaving two independent layouts gives the same results as running them separately")
    func interleavingTwoLayoutsMatchesRunningSeparately() throws {
        let regionsA = try Self.loadRegions("regions-ten.json")
        let nodesA = try Self.loadNodes("nodes-happy.json")
        let regionsB = try Self.loadRegions("regions-concave.json")
        let nodesB = try Self.loadNodes("nodes-concave.json")

        func runA() throws -> [String: Point] {
            var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
            return try LayoutEngine.layout(nodes: nodesA.nodes, regions: regionsA.regions, rng: &rng)
        }
        func runB() throws -> [String: Point] {
            var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
            return try LayoutEngine.layout(nodes: nodesB.nodes, regions: regionsB.regions, rng: &rng)
        }

        let isolatedA = try runA()
        let isolatedB = try runB()

        // Interleaved: A, B, A, B — each call constructs its own fresh rng, so this only proves purity
        // if the *isolated* calls above match the corresponding interleaved calls below.
        let interleavedA1 = try runA()
        let interleavedB1 = try runB()
        let interleavedA2 = try runA()
        let interleavedB2 = try runB()

        let encoder = CoreCoding.encoder
        #expect(try encoder.encode(isolatedA) == encoder.encode(interleavedA1))
        #expect(try encoder.encode(isolatedA) == encoder.encode(interleavedA2))
        #expect(try encoder.encode(isolatedB) == encoder.encode(interleavedB1))
        #expect(try encoder.encode(isolatedB) == encoder.encode(interleavedB2))
    }

    // The algorithm's doc comment (§4.4, quoted in the implementation) claims a "Jacobi-style synchronous
    // update ... the result cannot depend on the order `nodes` is iterated in." Proven here directly: for
    // a fixture where every node carries a valid layout_hint (no rng draw, so shuffling cannot change the
    // result via a different rng-consumption order), shuffling the `nodes` array must not change the
    // per-id result at all.
    @Test("the result does not depend on the order of the nodes array (all hints valid, no rng draw)")
    func resultDoesNotDependOnNodeArrayOrder() throws {
        let regions = try Self.loadRegions("regions-ten.json")
        let nodesFile = try Self.loadNodes("nodes-order-independence.json")
        #expect(nodesFile.nodes.count == 3)
        #expect(nodesFile.nodes.allSatisfy { $0.layoutHint != nil })

        let inOrder = nodesFile.nodes
        let shuffled = [nodesFile.nodes[2], nodesFile.nodes[0], nodesFile.nodes[1]]

        var rngA = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let resultInOrder = try LayoutEngine.layout(nodes: inOrder, regions: regions.regions, rng: &rngA)
        var rngB = SeededGenerator(seed: LayoutConfig.defaultSeed)
        let resultShuffled = try LayoutEngine.layout(nodes: shuffled, regions: regions.regions, rng: &rngB)

        let encoder = CoreCoding.encoder
        #expect(try encoder.encode(resultInOrder) == encoder.encode(resultShuffled))
    }

    // No file I/O anywhere in the layout implementation — a text-level guard, same spirit as the I14
    // import-boundary scan: `FileManager`/`.write(to:` would indicate a side effect this pure function
    // must never have.
    @Test("the layout implementation performs no file I/O")
    func layoutImplementationHasNoFileIO() throws {
        let files = ["LayoutEngine.swift", "Polygon.swift", "SeededGenerator.swift", "LayoutConfig.swift"]
        for fileName in files {
            let text = try String(
                contentsOf: Self.layoutSourcesDir.appendingPathComponent(fileName), encoding: .utf8
            )
            #expect(!text.contains("FileManager"), "\(fileName) references FileManager")
            #expect(!text.contains(".write(to"), "\(fileName) writes to disk")
        }
    }

    // MARK: - I14: no randomness source but the injected SeededGenerator

    // `coreImportBoundary()` (CoreTests.swift) already forbids the platform-UI imports recursively over
    // all of `Sources/Core`, but names no randomness source. This scan closes that gap for `Layout/`
    // specifically: `SystemRandomNumberGenerator`, `arc4random`, a bare `Date()`-derived seed, and any
    // `.random(in:` call that does NOT thread an explicit `using:` generator are all forbidden — every
    // random draw in this module must go through the injected `SeededGenerator`.
    @Test("Layout/*.swift uses no randomness source but the injected SeededGenerator (I14)")
    func layoutUsesNoForbiddenRandomnessSource() throws {
        let files = ["LayoutEngine.swift", "Polygon.swift", "SeededGenerator.swift", "LayoutConfig.swift"]
        var violations: [String] = []
        for fileName in files {
            let text = try String(
                contentsOf: Self.layoutSourcesDir.appendingPathComponent(fileName), encoding: .utf8
            )
            // Only code lines are scanned — a `///` doc comment is allowed to MENTION the forbidden
            // names (as `SeededGenerator.swift`'s own header comment does, explaining why it hand-rolls
            // a PRNG instead of using them); only an actual token in code is a violation.
            let codeLines = text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .filter { !$1.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            for (lineNumber, line) in codeLines {
                for forbidden in ["SystemRandomNumberGenerator()", "arc4random(", "Date()"] {
                    if line.contains(forbidden) {
                        violations.append("\(fileName):\(lineNumber + 1): forbidden token \(forbidden)")
                    }
                }
                if line.contains(".random(in:") && !line.contains("using:") {
                    violations.append("\(fileName):\(lineNumber + 1): .random(in:) without using:")
                }
            }
        }
        #expect(violations.isEmpty, "forbidden randomness source(s): \(violations)")
    }

    // Negative control (C2) for the guard above: prove it reds on a planted violation of each of the
    // three shapes it claims to catch, against a TEMPORARY in-memory string — never the checked-in file.
    @Test("the I14 randomness-source guard reds on each planted forbidden pattern")
    func randomnessSourceGuardRedsOnPlantedViolations() {
        func violates(_ line: String) -> Bool {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                return false
            }
            for forbidden in ["SystemRandomNumberGenerator()", "arc4random(", "Date()"] {
                if line.contains(forbidden) {
                    return true
                }
            }
            return line.contains(".random(in:") && !line.contains("using:")
        }

        #expect(violates("var rng = SystemRandomNumberGenerator()"))
        #expect(violates("let seed = arc4random()"))
        #expect(violates("let seed = Date().timeIntervalSince1970"))
        #expect(violates("let x = Double.random(in: 0...1)"))
        // The real, compliant call site must NOT be flagged — otherwise the guard has no signal.
        #expect(!violates("Double.random(in: box.minX...box.maxX, using: &rng)"))
        #expect(!violates("// mentions SystemRandomNumberGenerator in prose only"))
    }

    // MARK: - I11 constant-discipline guard: mutation test (plant a literal, prove the scan reds)

    // Reproduces the exact pattern `LayoutTests.layoutConfigIsTheOnlySourceOfTuningConstants()` uses,
    // against a TEMPORARY mutated copy of the real source (never the checked-in file — product code is
    // never touched by this suite). If this mutation test cannot make the guard fail, the guard cannot be
    // trusted to catch a real regression either.
    @Test("the I11 literal-scan guard reds when a bare numeric literal is planted")
    func literalScanGuardRedsOnPlantedLiteral() throws {
        let literalPattern = try NSRegularExpression(pattern: #"\b\d+\.\d+\b|\b\d{2,}\b"#)

        func violationCount(in text: String) -> Int {
            var count = 0
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let nsLine = line as NSString
                count +=
                    literalPattern.matches(
                        in: String(line), range: NSRange(location: 0, length: nsLine.length)
                    ).count
            }
            return count
        }

        let originalText = try String(
            contentsOf: Self.layoutSourcesDir.appendingPathComponent("LayoutEngine.swift"), encoding: .utf8
        )
        #expect(violationCount(in: originalText) == 0, "the real file must be clean before mutation")

        // Plant exactly the kind of literal AC6 forbids: a bare multi-digit int and a bare float, typed
        // directly at a call site instead of read from `LayoutConfig`.
        let mutatedText = originalText + "\nlet plantedTuningConstant = 0.1234\nlet plantedCount = 777\n"
        #expect(
            violationCount(in: mutatedText) == 2,
            "the guard's own regex failed to catch a planted bare literal — the guard cannot be trusted"
        )

        // Looseness check: the shipped pattern requires >= 2 digits for a bare integer, so a single-digit
        // non-index/non-loop literal (e.g. `let extra = 5`) would slip past it undetected — looser than
        // AC6's stated rule ("no bare numeric literal ... other than 0, 1, loop indices, and array/tuple
        // indexing"), which permits only 0 and 1, not every single digit. Demonstrated, not asserted
        // against (the shipped guard is not modified by this suite): the shipped files currently contain
        // no such literal, so this looseness causes no missed regression today, but a future edit adding
        // e.g. `force * 5` at a call site would pass the shipped guard silently.
        let singleDigitPlant = originalText + "\nlet extra = 5\n"
        #expect(
            violationCount(in: singleDigitPlant) == 0,
            "documents the shipped regex's looseness: single-digit non-index literals are not caught"
        )
    }

    // MARK: - splitmix64 known-answer vectors (independently computed, not "against itself")

    // The three seeds' first three outputs below are the well-known public-domain splitmix64 reference
    // vectors (independently reproduced from the canonical `state += 0x9E3779B97F4A7C15; z = state; z =
    // (z ^ (z>>30)) * 0xBF58476D1CE4E5B9; z = (z ^ (z>>27)) * 0x94D049BB133111EB; return z ^ (z>>31)`
    // algorithm — the exact sequence `SeededGenerator.next()` implements). A PRNG that is deterministic
    // but wrong (e.g. a transposed constant, a missing XOR-shift) would still pass every determinism test
    // in this suite while failing these hard-coded vectors.
    @Test("SeededGenerator matches independently-computed splitmix64 known-answer vectors")
    func seededGeneratorMatchesKnownAnswerVectors() {
        let vectors: [(seed: UInt64, expected: [UInt64])] = [
            (0, [0xe220_a839_7b1d_cdaf, 0x6e78_9e6a_a1b9_65f4, 0x06c4_5d18_8009_454f]),
            (42, [0xbdd7_3226_2feb_6e95, 0x28ef_e333_b266_f103, 0x4752_6757_130f_9f52]),
            (1, [0x910a_2dec_8902_5cc1, 0xbeeb_8da1_658e_ec67, 0xf893_a2ee_fb32_555e]),
        ]
        for vector in vectors {
            var generator = SeededGenerator(seed: vector.seed)
            for expected in vector.expected {
                #expect(generator.next() == expected, "seed \(vector.seed)")
            }
        }
    }
}

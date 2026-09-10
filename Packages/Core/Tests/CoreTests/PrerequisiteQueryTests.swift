import Foundation
import Testing

@testable import Core

/// Task 02.10's own companion test suite for `PrerequisiteQuery.deepestUnmasteredPrerequisite`
/// (`Sources/Core/Graph/PrerequisiteQuery.swift`), written against
/// `tasks/epic-02-task-10-prerequisite-query-classify.md`.
@Suite("PrerequisiteQuery.deepestUnmasteredPrerequisite")
struct PrerequisiteQueryTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var demoBundleDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    /// A bundle identical to `base` except its `nodes`/`edges` files are replaced by the given synthetic
    /// graph — `PrerequisiteQuery` reads only `bundle.nodes.nodes` and `bundle.edges.edges`, so every
    /// other file (manifest, regions, courses, landmarks, sources) is carried over unchanged from a real,
    /// already-L0-passed bundle rather than hand-built (matching `ExpeditionRunBoundaryTests`'
    /// `bundleWithSingleItemNode` precedent).
    private static func bundle(_ base: ContentBundle, nodes: [Node], edges: [Edge]) -> ContentBundle {
        ContentBundle(
            manifest: base.manifest, regions: base.regions,
            nodes: NodesFile(formatVersion: base.nodes.formatVersion, nodes: nodes),
            edges: EdgesFile(formatVersion: base.edges.formatVersion, edges: edges), courses: base.courses,
            landmarks: base.landmarks, sources: base.sources)
    }

    private static func state(nodes: [String: NodeState]) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: [], installDay: "2026-01-01",
            consentOn: true)
    }

    private static func fogNode() -> NodeState {
        NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
    }

    private static func clearedNode() -> NodeState {
        NodeState(
            mastery: .cleared, correctCount: 2, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: nil)
    }

    private static func blockedNode() -> NodeState {
        NodeState(
            mastery: .blocked, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
            remediated: false)
    }

    /// A `Node` carrying one `ErrorType` with the given `impliesPrerequisite` — used by the bias tests.
    /// `PropertyGen.minimalNode` has no `errorTypes` parameter, so bias fixtures build the `Node` value
    /// directly rather than extending the shared generator for a single-task need.
    private static func nodeWithErrorType(id: String, errorTypeId: String, impliesPrerequisite: String?)
        -> Node
    {
        Node(
            id: id, name: id, regionId: .algebra, strand: nil, expectationCodes: nil, sourceRef: nil,
            courses: [], position: Point(x: 0, y: 0), layoutHint: nil, paraphrase: "generated node \(id)",
            explanation: nil, workedExamples: nil,
            errorTypes: [
                ErrorType(id: errorTypeId, label: "generated", impliesPrerequisite: impliesPrerequisite)
            ], hintTree: [:], probeItems: [])
    }

    // MARK: - T1 happy path

    @Test("a single unmastered prerequisite at depth 1 is returned when only one exists")
    func singleUnmasteredCandidateAtDepth1() throws {
        let base = try Self.loadDemoBundle()
        let nodes = [PropertyGen.minimalNode(id: "origin"), PropertyGen.minimalNode(id: "prereq")]
        let edges = [PropertyGen.minimalEdge(from: "prereq", to: "origin", confidence: 0.8)]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]), bundle: bundle,
            levelBudget: 2)
        #expect(result.candidate?.node.id == "prereq")
        #expect(result.candidate?.depth == 1)
        #expect(result.candidate?.edgeConfidence == 0.8)
        #expect(result.code == nil)
    }

    @Test(
        "AC2: on data/demo, polynomials picks exponent-laws (0.95) over simplifying-expressions (0.7) at levelBudget 1"
    )
    func demoBundleTieBreakByConfidence() throws {
        let bundle = try Self.loadDemoBundle()
        let nodes: [String: NodeState] = [
            "exponent-laws": Self.fogNode(), "simplifying-expressions": Self.fogNode(),
        ]
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "polynomials", biasErrorTypeId: nil, state: Self.state(nodes: nodes), bundle: bundle,
            levelBudget: 1)
        #expect(result.candidate?.node.id == "exponent-laws")
        #expect(result.candidate?.edgeConfidence == 0.95)
    }

    // MARK: - Q2 conformance: candidate set is every non-cleared node (fog AND blocked)

    @Test("Q2: a blocked-only prerequisite is a candidate, not excluded by mastery == .blocked")
    func blockedPrerequisiteIsCandidate() throws {
        let base = try Self.loadDemoBundle()
        let nodes = [PropertyGen.minimalNode(id: "origin"), PropertyGen.minimalNode(id: "prereq")]
        let edges = [PropertyGen.minimalEdge(from: "prereq", to: "origin", confidence: 0.8)]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil,
            state: Self.state(nodes: ["prereq": Self.blockedNode()]), bundle: bundle, levelBudget: 2)
        #expect(result.candidate?.node.id == "prereq")
        #expect(result.code == nil)
    }

    @Test(
        "negative control: reconstructing the bundle's wrong '.blocked does not satisfy' filter (spec §6) would red on this fixture"
    )
    func blockedExclusionRegressionGuardReds() throws {
        // Reconstruct the defect the spec's §6 explicitly rules out: the bundle's §D gloss said
        // "`blocked` does not satisfy", conflating this query's candidate filter with the `compose`
        // fringe guard `remediated(p)` (task 02.6). Under that buggy predicate the sole reachable node
        // ("prereq", `.blocked`) would NOT be a candidate.
        func buggyIsUnmastered(mastery: Mastery?) -> Bool {
            guard let mastery else { return true }
            return mastery == .fog  // BUG: omits `.blocked` (the bundle's wrong gloss)
        }
        #expect(buggyIsUnmastered(mastery: .blocked) == false, "sanity: buggy predicate excludes blocked")

        let base = try Self.loadDemoBundle()
        let nodes = [PropertyGen.minimalNode(id: "origin"), PropertyGen.minimalNode(id: "prereq")]
        let edges = [PropertyGen.minimalEdge(from: "prereq", to: "origin", confidence: 0.8)]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)
        let actual = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil,
            state: Self.state(nodes: ["prereq": Self.blockedNode()]), bundle: bundle, levelBudget: 2)
        // The buggy predicate predicts `candidate: nil` (GRAPH_NO_PREREQUISITE); the real implementation
        // must NOT match that prediction — proving the guard is load-bearing against this exact defect.
        #expect(actual.candidate != nil)
        #expect(actual.code == nil)
        #expect(actual.candidate?.node.id == "prereq")
    }

    // MARK: - hypothesise bias: implies_prerequisite

    @Test(
        "hypothesise bias: implies_prerequisite wins over the Q3 confidence tie-break when it names a deepest-stratum candidate"
    )
    func impliesPrerequisiteBiasWinsTie() throws {
        let base = try Self.loadDemoBundle()
        let origin = Self.nodeWithErrorType(
            id: "origin", errorTypeId: "wrong-sign", impliesPrerequisite: "b-node")
        let nodes = [origin, PropertyGen.minimalNode(id: "a-node"), PropertyGen.minimalNode(id: "b-node")]
        let edges = [
            PropertyGen.minimalEdge(from: "a-node", to: "origin", confidence: 0.9),
            PropertyGen.minimalEdge(from: "b-node", to: "origin", confidence: 0.3),
        ]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)

        // Without a bias, Q3 tie-break alone picks "a-node" (higher confidence).
        let unbiased = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]), bundle: bundle,
            levelBudget: 1)
        #expect(unbiased.candidate?.node.id == "a-node")

        // With biasErrorTypeId naming "wrong-sign" (implies "b-node"), the bias wins despite lower
        // confidence.
        let biased = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: "wrong-sign", state: Self.state(nodes: [:]),
            bundle: bundle, levelBudget: 1)
        #expect(biased.candidate?.node.id == "b-node")
    }

    @Test(
        "hypothesise bias: implies_prerequisite is ignored when the implied node is unreachable within levelBudget"
    )
    func impliesPrerequisiteBiasIgnoredWhenUnreachable() throws {
        let base = try Self.loadDemoBundle()
        let origin = Self.nodeWithErrorType(
            id: "origin", errorTypeId: "wrong-sign", impliesPrerequisite: "c-node")
        let nodes = [
            origin, PropertyGen.minimalNode(id: "a-node"), PropertyGen.minimalNode(id: "b-node"),
            PropertyGen.minimalNode(id: "c-node"),
        ]
        // "a-node" and "b-node" are direct prerequisites of "origin" (depth 1, within budget). "c-node"
        // is a prerequisite of "a-node" (depth 2), unreachable at levelBudget: 1 — the spec's §6 default
        // for "wrong depth ... or unreachable within budget" applies: the bias is ignored and Q3 decides.
        let edges = [
            PropertyGen.minimalEdge(from: "a-node", to: "origin", confidence: 0.3),
            PropertyGen.minimalEdge(from: "b-node", to: "origin", confidence: 0.9),
            PropertyGen.minimalEdge(from: "c-node", to: "a-node", confidence: 0.99),
        ]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: "wrong-sign", state: Self.state(nodes: [:]),
            bundle: bundle, levelBudget: 1)
        // The bias names "c-node", which is outside the deepest (and only reachable) stratum — the
        // normal Q3 tie-break must decide, picking "b-node" (higher confidence), never "c-node".
        #expect(result.candidate?.node.id == "b-node")
        #expect(result.candidate?.node.id != "c-node")
    }

    // MARK: - T3 error taxonomy

    @Test("AC3: no unmastered node within budget returns candidate: nil, code: .graphNoPrerequisite")
    func noCandidateWithinBudgetReturnsGraphNoPrerequisite() throws {
        let base = try Self.loadDemoBundle()
        let nodes = [PropertyGen.minimalNode(id: "origin"), PropertyGen.minimalNode(id: "prereq")]
        let edges = [PropertyGen.minimalEdge(from: "prereq", to: "origin", confidence: 0.8)]
        let bundle = Self.bundle(base, nodes: nodes, edges: edges)
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil,
            state: Self.state(nodes: ["prereq": Self.clearedNode()]),
            bundle: bundle, levelBudget: 2)
        #expect(result.candidate == nil)
        #expect(result.code == .graphNoPrerequisite)
    }

    @Test("origin with no incoming edges returns candidate: nil, code: .graphNoPrerequisite")
    func noIncomingEdgesReturnsGraphNoPrerequisite() throws {
        let base = try Self.loadDemoBundle()
        let nodes = [PropertyGen.minimalNode(id: "origin")]
        let bundle = Self.bundle(base, nodes: nodes, edges: [])
        let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]), bundle: bundle,
            levelBudget: 2)
        #expect(result.candidate == nil)
        #expect(result.code == .graphNoPrerequisite)
    }

    // MARK: - T4 property test (AC1, I4)

    @Test("AC1/I4: every returned candidate's depth never exceeds levelBudget, over 20 generated graphs")
    func depthNeverExceedsLevelBudget() throws {
        let base = try Self.loadDemoBundle()
        var gen = SeededGenerator(seed: 42)
        for iteration in 0..<20 {
            let graph = PropertyGen.smallLayeredGraph(&gen, maxLevels: 4, maxBranching: 3)
            let bundle = Self.bundle(base, nodes: graph.nodes, edges: graph.edges)
            for levelBudget in [1, 2] {
                let result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
                    originId: graph.originId, biasErrorTypeId: nil, state: Self.state(nodes: [:]),
                    bundle: bundle, levelBudget: levelBudget)
                if let depth = result.candidate?.depth {
                    #expect(
                        depth <= levelBudget,
                        "iteration \(iteration), levelBudget \(levelBudget): depth \(depth) exceeded budget"
                    )
                }
            }
        }
    }

    // MARK: - T5 negative control: tie-break is confidence-first, not id-first

    @Test("Q3 tie-break: highest edge confidence wins regardless of node id ordering")
    func tieBreakIsConfidenceFirst() throws {
        let base = try Self.loadDemoBundle()
        let nodes = [
            PropertyGen.minimalNode(id: "origin"), PropertyGen.minimalNode(id: "a-node"),
            PropertyGen.minimalNode(id: "b-node"),
        ]

        // Case 1: the higher-confidence candidate has the lexicographically higher id.
        let case1Edges = [
            PropertyGen.minimalEdge(from: "a-node", to: "origin", confidence: 0.3),
            PropertyGen.minimalEdge(from: "b-node", to: "origin", confidence: 0.9),
        ]
        let case1Result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]),
            bundle: Self.bundle(base, nodes: nodes, edges: case1Edges), levelBudget: 1)
        #expect(case1Result.candidate?.node.id == "b-node")

        // Case 2: the higher-confidence candidate has the lexicographically lower id.
        let case2Edges = [
            PropertyGen.minimalEdge(from: "a-node", to: "origin", confidence: 0.9),
            PropertyGen.minimalEdge(from: "b-node", to: "origin", confidence: 0.3),
        ]
        let case2Result = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]),
            bundle: Self.bundle(base, nodes: nodes, edges: case2Edges), levelBudget: 1)
        #expect(case2Result.candidate?.node.id == "a-node")

        // Load-bearing check: swapping the confidence values between case1's two candidates flips the
        // winner, proving the assertions above are sensitive to confidence, not a fixed fallback.
        let swappedEdges = [
            PropertyGen.minimalEdge(from: "a-node", to: "origin", confidence: 0.9),
            PropertyGen.minimalEdge(from: "b-node", to: "origin", confidence: 0.3),
        ]
        let swappedResult = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "origin", biasErrorTypeId: nil, state: Self.state(nodes: [:]),
            bundle: Self.bundle(base, nodes: nodes, edges: swappedEdges), levelBudget: 1)
        #expect(swappedResult.candidate?.node.id != case1Result.candidate?.node.id)
    }

    // MARK: - T6 idempotency

    @Test("calling twice with identical arguments returns Equatable-equal results")
    func idempotentOnRepeatedCall() throws {
        let bundle = try Self.loadDemoBundle()
        let state = Self.state(nodes: [
            "exponent-laws": Self.fogNode(), "simplifying-expressions": Self.fogNode(),
        ])
        let first = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "polynomials", biasErrorTypeId: nil, state: state, bundle: bundle, levelBudget: 1)
        let second = PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: "polynomials", biasErrorTypeId: nil, state: state, bundle: bundle, levelBudget: 1)
        #expect(first == second)
    }
}

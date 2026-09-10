import Foundation

/// One candidate returned by `PrerequisiteQuery.deepestUnmasteredPrerequisite`: the upstream `Node`
/// itself, its BFS depth from the origin, and the confidence of the edge the walk used to reach it
/// (the higher of any same-depth ties, per §4 step c).
public struct PrerequisiteCandidate: Equatable {
    public let node: Node
    public let depth: Int
    public let edgeConfidence: Double
}

/// The result of `deepestUnmasteredPrerequisite`. `code` is `nil` when `candidate` is non-nil, and
/// `.graphNoPrerequisite` when `candidate` is `nil` — "code as data", mirroring
/// `MarkerReconciliationResult` (`Sources/Core/State/MarkerTrailGeneration.swift`).
public struct PrerequisiteQueryResult: Equatable {
    public let candidate: PrerequisiteCandidate?
    public let code: CoreError?
}

/// Concept-graph W3: the deepest-unmastered-prerequisite query. A pure value transformation over its
/// arguments — no system clock read, no file I/O, no global mutable state, no model call (I14, I2).
public enum PrerequisiteQuery {
    /// Breadth-first walk over the graph's incoming edges from `originId`, at most `levelBudget` levels
    /// upward, returning the deepest unmastered candidate (ties broken per Q3, biased by
    /// `biasErrorTypeId`'s `implies_prerequisite` when it names a member of the deepest stratum).
    /// `state` supplies the mastery filter (Q2: absent/`.fog`/`.blocked` are candidates, `.cleared` is
    /// not); the walk itself passes through `.cleared` nodes to explore further upward.
    public static func deepestUnmasteredPrerequisite(
        originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle,
        levelBudget: Int
    ) -> PrerequisiteQueryResult {
        let edgesByTo = Dictionary(grouping: bundle.edges.edges, by: \.to)
        var visited: [String: Int] = [originId: 0]
        var confidenceByNode: [String: Double] = [:]
        var currentLayer = [originId]

        var depth = 1
        while depth <= levelBudget && !currentLayer.isEmpty {
            var nextLayer: [String] = []
            for node in currentLayer {
                for edge in edgesByTo[node] ?? [] {
                    if visited[edge.from] == nil {
                        visited[edge.from] = depth
                        confidenceByNode[edge.from] = edge.confidence
                        nextLayer.append(edge.from)
                    } else if visited[edge.from] == depth {
                        confidenceByNode[edge.from] = max(
                            confidenceByNode[edge.from] ?? edge.confidence, edge.confidence)
                    }
                }
            }
            currentLayer = nextLayer
            depth += 1
        }

        let candidateDepths: [(id: String, depth: Int)] = visited.keys.compactMap { id in
            guard id != originId, isUnmastered(id, state: state), let depth = visited[id] else {
                return nil
            }
            return (id, depth)
        }
        guard let deepest = candidateDepths.map(\.depth).max() else {
            return PrerequisiteQueryResult(candidate: nil, code: .graphNoPrerequisite)
        }
        let deepestCandidates = candidateDepths.filter { $0.depth == deepest }.map(\.id)

        let winnerId =
            biasedWinner(
                biasErrorTypeId: biasErrorTypeId, originId: originId, deepestCandidates: deepestCandidates,
                bundle: bundle)
            ?? tieBreakWinner(deepestCandidates, confidenceByNode: confidenceByNode)

        guard let winnerId, let node = bundle.nodes.nodes.first(where: { $0.id == winnerId }),
            let winnerDepth = visited[winnerId], let winnerConfidence = confidenceByNode[winnerId]
        else {
            return PrerequisiteQueryResult(candidate: nil, code: .graphNoPrerequisite)
        }
        return PrerequisiteQueryResult(
            candidate: PrerequisiteCandidate(
                node: node, depth: winnerDepth, edgeConfidence: winnerConfidence),
            code: nil)
    }

    /// Q2: unmastered iff `state.nodes[id]` is absent (unknown), or its `mastery` is `.fog` or
    /// `.blocked`. Only `.cleared` is excluded.
    private static func isUnmastered(_ id: String, state: StudentState) -> Bool {
        guard let nodeState = state.nodes[id] else { return true }
        return nodeState.mastery == .fog || nodeState.mastery == .blocked
    }

    /// `hypothesise` bullet: if `biasErrorTypeId` is non-nil and names an `ErrorType` of the origin node
    /// whose `impliesPrerequisite` is a member of `deepestCandidates`, that id wins outright. Otherwise
    /// `nil` — the caller falls through to the normal Q3 tie-break.
    private static func biasedWinner(
        biasErrorTypeId: String?, originId: String, deepestCandidates: [String], bundle: ContentBundle
    ) -> String? {
        guard let biasErrorTypeId,
            let originNode = bundle.nodes.nodes.first(where: { $0.id == originId }),
            let impliedId = originNode.errorTypes.first(where: { $0.id == biasErrorTypeId })?
                .impliesPrerequisite,
            deepestCandidates.contains(impliedId)
        else { return nil }
        return impliedId
    }

    /// Q3: highest edge confidence, then lowest node id (ascending, string order).
    private static func tieBreakWinner(
        _ deepestCandidates: [String], confidenceByNode: [String: Double]
    ) -> String? {
        deepestCandidates.sorted { lhs, rhs in
            let lhsConfidence = confidenceByNode[lhs] ?? 0
            let rhsConfidence = confidenceByNode[rhs] ?? 0
            if lhsConfidence != rhsConfidence { return lhsConfidence > rhsConfidence }
            return lhs < rhs
        }.first
    }
}

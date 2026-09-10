import Foundation

/// Adjacency/lookup structure built once from a `ContentBundle`, consumed by every L0 rule check.
/// Not `public` — an internal helper of `L0Checker`.
struct GraphIndex {
    let nodesById: [String: Node]
    let edges: [Edge]
    let edgesByFrom: [String: [Edge]]
    let regionsById: [RegionId: Region]
    let coursesByCode: [String: Course]
    let sortedNodeIds: [String]

    init(bundle: ContentBundle) {
        nodesById = Dictionary(uniqueKeysWithValues: bundle.nodes.nodes.map { ($0.id, $0) })
        edges = bundle.edges.edges
        edgesByFrom = Dictionary(grouping: edges, by: \.from)
        regionsById = Dictionary(uniqueKeysWithValues: bundle.regions.regions.map { ($0.id, $0) })
        coursesByCode = Dictionary(uniqueKeysWithValues: bundle.courses.courses.map { ($0.courseCode, $0) })
        sortedNodeIds = nodesById.keys.sorted()
    }
}

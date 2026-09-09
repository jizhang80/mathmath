import Foundation

/// The L0 validation report (`contracts/graph-constraints.md` § Report shape), byte-faithful to
/// `{ bundle_id, passed, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`.
/// `L0-4` (advisory) never appears in `checks[]`; it is represented only by `indegree`.
public struct L0Report: Codable, Equatable {
    public let bundleId: String
    public let passed: Bool
    public let checks: [L0Check]
    public let indegree: L0Indegree
}

public struct L0Check: Codable, Equatable {
    public let id: String
    public let passed: Bool
    public let violations: [String]
}

public struct L0Indegree: Codable, Equatable {
    public let threshold: Int
    public let outliers: [String]
}

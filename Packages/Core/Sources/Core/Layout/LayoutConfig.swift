import Foundation

/// Every tuning constant the force layout uses, collected in one place (brief §9 default) so no
/// numeric literal is re-typed at a call site in `LayoutEngine.swift` or `Polygon.swift` (AC6).
public struct LayoutConfig: Sendable, Equatable {
    /// Fixed iteration count for the Fruchterman–Reingold-style loop.
    public var iterationCount: Int = 300  // [ESTIMATE: 300 — epic brief §9]
    /// Repulsion force magnitude between any two node positions, scaled by 1/distance^2.
    public var repulsionStrength: Double = 0.0005  // [ESTIMATE]
    /// Spring force magnitude pulling a node back toward its anchor (its `layout_hint`, or its
    /// rejection-sampled initial point when `layout_hint` is absent or invalid).
    public var attractionStrength: Double = 0.02  // [ESTIMATE]
    /// Per-iteration multiplicative decay applied to the maximum step size (simulated-annealing cooling).
    public var coolingFactor: Double = 0.98  // [ESTIMATE]
    /// Initial per-iteration maximum displacement, as a fraction of the shared [0,1] coordinate space.
    public var maxStepFraction: Double = 0.05  // [ESTIMATE]
    /// Floor applied to inter-node distance before computing repulsion, avoiding division by zero when two
    /// nodes coincide.
    public var minimumDistance: Double = 0.000_001  // [ESTIMATE]
    /// Tolerance for the point-on-boundary check in `Polygon.contains`.
    public var boundaryEpsilon: Double = 0.000_000_001  // [ESTIMATE]
    /// Bounded retry count for rejection-sampling a random point inside a polygon's bounding box.
    public var maxRandomSamples: Int = 1000  // [ESTIMATE]
    /// The fixed seed used when a caller does not supply its own — the brief §9 "seeded RNG from a fixed
    /// constant" requirement.
    public static let defaultSeed: UInt64 = 42  // [ESTIMATE: 42 — arbitrary fixed constant, brief §9]

    public init() {}
}

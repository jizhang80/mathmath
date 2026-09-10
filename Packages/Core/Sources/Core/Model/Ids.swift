import Foundation

/// A normalised map coordinate in `[0, 1]` on each axis, shared by regions, nodes and landmarks.
public struct Point: Codable, Equatable {
    public let x: Double
    public let y: Double
}

/// The fixed region vocabulary: ten map regions, four horizon labels and the optional `shore`
/// (`contracts/data-model.md` § Identifiers; `contracts/schemas/regions.schema.json`).
public enum RegionId: String, Codable, CaseIterable {
    case numberOperations = "number-operations"
    case algebra = "algebra"
    case functions = "functions"
    case geometryMeasurement = "geometry-measurement"
    case trigonometry = "trigonometry"
    case calculus = "calculus"
    case linearAlgebra = "linear-algebra"
    case differentialEquations = "differential-equations"
    case probabilityStatistics = "probability-statistics"
    case discrete = "discrete"
    case analysis = "analysis"
    case topology = "topology"
    case numberTheory = "number-theory"
    case abstractAlgebra = "abstract-algebra"
    case shore = "shore"
}

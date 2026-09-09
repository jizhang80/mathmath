import Foundation

/// `Codable` types for `edges.json` (`contracts/schemas/edges.schema.json`).
public struct EdgesFile: Codable, Equatable {
    public let formatVersion: String
    public let edges: [Edge]
}

public struct Edge: Codable, Equatable {
    public let from: String
    public let to: String
    public let sources: [EdgeSource]
    public let generationAgreement: Int
    public let confidence: Double
    public let probeStats: ProbeStats
}

public struct EdgeSource: Codable, Equatable {
    public let tag: EdgeSourceTag
    public let origin: String
}

public enum EdgeSourceTag: String, Codable {
    case ministryPrereq = "ministry_prereq"
    case textbookOrder = "textbook_order"
    case thirdPartyStructure = "third_party_structure"
    case modelGenerated = "model_generated"
}

public struct ProbeStats: Codable, Equatable {
    public let probes: Int
    public let confirmed: Int
    public let downstreamFailGivenUpstreamFail: Double?
}

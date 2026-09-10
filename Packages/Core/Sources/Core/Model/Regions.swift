import Foundation

/// `Codable` types for `regions.json` (`contracts/schemas/regions.schema.json`).
public struct RegionsFile: Codable, Equatable {
    public let formatVersion: String
    public let regions: [Region]
}

public struct Region: Codable, Equatable {
    public let id: RegionId
    public let name: String
    public let about: String
    public let horizon: Bool
    public let polygon: [Point]
    public let neighbours: [RegionId]
}

import Foundation

/// `Codable` types for `landmarks.json` (`contracts/schemas/landmarks.schema.json`).
public struct LandmarksFile: Codable, Equatable {
    public let formatVersion: String
    public let landmarks: [Landmark]
}

/// `sourceUrl` is a required, non-optional `String`: I15's "a landmark that cannot be sourced is
/// dropped, never invented" is satisfied structurally — decode fails without a `source_url`.
public struct Landmark: Codable, Equatable {
    public let id: String
    public let name: String
    public let sourceTitle: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
    public let regionIds: [RegionId]
    public let position: Point
}

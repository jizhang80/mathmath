import Foundation

/// `Codable` types for `sources.json` (`contracts/schemas/sources.schema.json`).
public struct SourcesFile: Codable, Equatable {
    public let formatVersion: String
    public let sources: [UndergraduateSource]
}

public struct UndergraduateSource: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let title: String
    public let edition: String
    public let licence: Licence
    public let attribution: String
    public let url: String
}

public enum UndergraduateSourceName: String, Codable {
    case openstax
    case mitOcw = "mit-ocw"
}

public enum Licence: String, Codable {
    case ccBy4 = "CC BY 4.0"
    case ccByNcSa4 = "CC BY-NC-SA 4.0"
}

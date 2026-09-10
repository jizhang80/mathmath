import Foundation

/// `Codable` type for `manifest.json` (`contracts/schemas/manifest.schema.json`).
public struct Manifest: Codable, Equatable {
    public let formatVersion: String
    public let bundleId: String
    public let spineVersion: String
    public let graphVersion: String
    public let builtAt: String
    public let startingChain: [String]
    public let files: [ManifestFile]
}

public struct ManifestFile: Codable, Equatable {
    public let name: String
    public let assetVersion: String
    public let sha256: String
}

import Foundation

/// `Codable` type for `student-state.json` (`contracts/schemas/student-state.schema.json`).
///
/// Decoded and encoded through `CoreCoding.decoder`/`CoreCoding.encoder`, the same single wire-format
/// coder pair every bundle type uses (`Sources/Core/CoreCoding.swift`). No type below declares an
/// explicit `CodingKeys` — `.convertFromSnakeCase` rewrites the incoming key before Foundation matches
/// it against a `CodingKey` raw value, so an explicit snake_case `CodingKeys` layered on top of it can
/// never match (see `tasks/blocked/tester-blocked-01-01.md`).
public struct StudentState: Codable, Equatable {
    public let schemaVersion: Int
    public let formatVersionSeen: String
    public let syllabi: [String]
    public let marker: Marker
    public let nodes: [String: NodeState]
    public let trail: Trail
    public let expeditionLog: [ExpeditionLogEntry]
    public let probeLog: [ProbeLogEntry]
    public let installDay: String
    public let consentOn: Bool
}

public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String
}

public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
}

public enum Mastery: String, Codable {
    case fog
    case cleared
    case blocked
}

public struct Trail: Codable, Equatable {
    public let segments: [TrailSegment]
}

public struct TrailSegment: Codable, Equatable {
    public let kind: SegmentKind
    public let courseCode: String?
    public let nodeIds: [String]
}

public enum SegmentKind: String, Codable {
    case course
    case `extension`
}

public struct ExpeditionLogEntry: Codable, Equatable {
    public let day: String
    public let itemCount: Int
    public let cleared: Int
    public let blocked: Int
    public let abandoned: Bool
    public let diagnosisEvents: Int
}

public struct ProbeLogEntry: Codable, Equatable {
    public let day: String
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let retry: Bool
}

import Foundation

/// `Codable` type for `student-state.json` (`contracts/schemas/student-state.schema.json`).
///
/// Every nested type declares an explicit `CodingKeys: String, CodingKey, CaseIterable` (rather than
/// relying on `.convertFromSnakeCase`/`.convertToSnakeCase` implicitly) so the I5 identifier-blocklist
/// guard test can enumerate `Type.CodingKeys.allCases.map(\.rawValue)`.
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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion = "schema_version"
        case formatVersionSeen = "format_version_seen"
        case syllabi
        case marker
        case nodes
        case trail
        case expeditionLog = "expedition_log"
        case probeLog = "probe_log"
        case installDay = "install_day"
        case consentOn = "consent_on"
    }
}

public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case courseCode = "course_code"
        case unitId = "unit_id"
    }
}

public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int

    enum CodingKeys: String, CodingKey, CaseIterable {
        case mastery
        case correctCount = "correct_count"
        case lastProbe = "last_probe"
        case nextDue = "next_due"
        case ladderRung = "ladder_rung"
    }
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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case courseCode = "course_code"
        case nodeIds = "node_ids"
    }
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

    enum CodingKeys: String, CodingKey, CaseIterable {
        case day
        case itemCount = "item_count"
        case cleared
        case blocked
        case abandoned
        case diagnosisEvents = "diagnosis_events"
    }
}

public struct ProbeLogEntry: Codable, Equatable {
    public let day: String
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let retry: Bool

    enum CodingKeys: String, CodingKey, CaseIterable {
        case day
        case nodeId = "node_id"
        case itemId = "item_id"
        case correct
        case retry
    }
}

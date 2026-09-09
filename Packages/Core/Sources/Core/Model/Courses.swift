import Foundation

/// `Codable` types for `courses.json` (`contracts/schemas/courses.schema.json`).
public struct CoursesFile: Codable, Equatable {
    public let formatVersion: String
    public let courses: [Course]
}

public struct Course: Codable, Equatable {
    public let courseCode: String
    public let name: String
    public let vintage: String
    public let strands: [Strand]
    public let expectations: [Expectation]
    public let units: [Unit]
    public let unitSource: UnitSource?
    public let nextCourses: [String]
}

public struct Strand: Codable, Equatable {
    public let code: String
    public let name: String
}

public struct Expectation: Codable, Equatable {
    public let code: String
    public let kind: ExpectationKind
    public let paraphrase: String
    public let officialUrl: String
    public let unitId: String
}

public enum ExpectationKind: String, Codable {
    case overall
    case specific
}

public struct Unit: Codable, Equatable {
    public let unitId: String
    public let name: String
    public let expectationCodes: [String]
}

public struct UnitSource: Codable, Equatable {
    public let title: String
    public let edition: String
}

import Foundation

/// `Codable` types for `nodes.json` (`contracts/schemas/nodes.schema.json`).
public struct NodesFile: Codable, Equatable {
    public let formatVersion: String
    public let nodes: [Node]
}

public struct Node: Codable, Equatable {
    public let id: String
    public let name: String
    public let regionId: RegionId
    public let strand: String?
    public let expectationCodes: [NodeExpectationCode]?
    public let sourceRef: SourceRef?
    public let courses: [NodeCourse]
    public let position: Point
    public let layoutHint: Point?
    public let paraphrase: String
    public let explanation: String?
    public let workedExamples: [WorkedExample]?
    public let errorTypes: [ErrorType]
    public let hintTree: [String: [String]]
    public let probeItems: [ProbeItem]
}

public struct NodeExpectationCode: Codable, Equatable {
    public let courseCode: String
    public let code: String
}

public struct NodeCourse: Codable, Equatable {
    public let courseCode: String
    public let depth: Int
}

public struct SourceRef: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let edition: String
    public let locator: String
}

public struct WorkedExample: Codable, Equatable {
    public let id: String
    public let stepsLatex: [String]
}

public struct ErrorType: Codable, Equatable {
    public let id: String
    public let label: String
    public let impliesPrerequisite: String?
}

public struct ProbeItem: Codable, Equatable {
    public let id: String
    public let type: ProbeItemType
    public let promptLatex: String
    public let why: String
    public let renderFallback: RenderFallback?
    public let answer: ProbeAnswer?
    public let wrongAnswers: [WrongAnswer]?
    public let choices: [ProbeChoice]?
    public let correctChoiceId: String?
}

public enum ProbeItemType: String, Codable {
    case numeric
    case mc
}

public enum RenderFallback: String, Codable {
    case katex
}

public struct ProbeAnswer: Codable, Equatable {
    public let value: String
    public let tolerance: Double?
}

public struct WrongAnswer: Codable, Equatable {
    public let value: String
    public let errorTypeId: String
}

public struct ProbeChoice: Codable, Equatable {
    public let id: String
    public let latex: String
    public let errorTypeId: String?
}

import Foundation

/// Door A's fixed Door copy strings (`docs/domains/diagnosis.md` W1-W6; DEMO-BRIEF §3.6). Every other
/// string this file surfaces is a node's own `paraphrase`/`explanation`/`workedExamples`/`hint_tree`
/// content (I6).
public enum DoorADiagnosisCopy {
    public static let costLine = "Two quick checks, about a minute."
    public static let refutedLine = "Not the issue — back to where you were"
    public static let cappedLine = "further upstream — it's on your map"
    public static let furtherLevelQuestion = "want to look one step further upstream?"
    public static func hypothesisLine(candidateNodeName: String) -> String {
        "This may be blocked by **\(candidateNodeName)**"
    }
}

/// The hypothesis card (W1-W2).
public struct DoorAHypothesisContent: Equatable {
    public let line: String
    public let costLine: String
}

/// `internalCode` is data only (`LO_HINT_NOT_FOUND`); never rendered, never thrown
/// (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md` Rule 2).
public struct DoorAHintContent: Equatable {
    public let nodeId: String
    public let prose: String
    public let resolvedKey: String?
    public let internalCode: CoreError?
}

/// Priority order per the domain-glossary v1.0.1 Remediation sentence: explanation, else worked example,
/// else paraphrase with an optional hint. Never an empty case — `paraphrase` is schema-required.
public enum DoorARemediationContent: Equatable {
    case explanation(String)
    case workedExample(WorkedExample)
    case paraphrase(String, hint: String?)
}

/// W4 step 3 (Q3: "offered, never automatic").
public struct DoorAFurtherLevelOfferContent: Equatable {
    public let candidateNodeName: String
    public let question: String
}

/// `remediation` is non-nil iff this terminal followed a `confirmed` probe on the *same* façade call
/// (`.confirmed`/`.capped` reached from `answerProbeItem`); it is nil when reached from
/// `decideFurtherLevel`'s decline branch, where remediation was already shown on the preceding
/// `furtherLevelOffer` screen (never shown twice). `hint` is non-nil iff `outcome.hintNodeId != nil`
/// (`.refuted`, `.unconfirmed`, `.noPrerequisite`).
public struct DoorATerminalContent: Equatable {
    public let terminal: DiagnosisTerminal
    public let line: String?
    public let hint: DoorAHintContent?
    public let remediation: DoorARemediationContent?
    public let outcome: DiagnosisOutcome
}

/// The Door A screen a caller renders after one façade call. `probeItem`/`furtherLevelOffer`/`hypothesis`
/// carry the raw `DiagnosisRun` phase value the caller must pass, unmodified, into the matching
/// `DoorADiagnosisFlow` entry point — never constructed by the caller (no public initializer exists on any
/// of `ProbeOffer`/`ProbeInProgress`/`FurtherLevelOffer`, `tasks/arbitration/arbiter-02-11-stepwise-api.md`
/// Ruling 2).
public enum DoorADiagnosisScreen: Equatable {
    case hypothesis(content: DoorAHypothesisContent, offer: ProbeOffer)
    case probeItem(content: DoorItemContent, probe: ProbeInProgress)
    case furtherLevelOffer(
        remediation: DoorARemediationContent, offer: DoorAFurtherLevelOfferContent,
        decision: FurtherLevelOffer)
    case terminal(DoorATerminalContent)
}

/// The Door A hint resolver and remediation selector (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`
/// Rules 2-3). Declared at file scope with `internal` (default) access, not nested inside
/// `DoorADiagnosisFlow`, so 04.4's D27 hand-off code and this task's own tests can both reach it without a
/// second implementation.
enum DoorADiagnosisContentBuilder {
    /// Rule 2 of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`, verbatim. Calls
    /// `DiagnosisRun.hintKey` in-module (it is internal, not private) — nothing is reimplemented.
    static func resolveHint(node: Node, classifiedToken: String) -> DoorAHintContent {
        let key = DiagnosisRun.hintKey(originNode: node, errorTypeId: classifiedToken)
        let expected = classifiedToken == "none_of_these" ? "none-of-these" : classifiedToken
        switch key {
        case .some(let k) where k == expected:
            // `hintKey` only returns a key whose `hintTree` entry is non-empty, so this callee's own
            // contract guarantees a first tier; `preconditionFailure` documents that guarantee without a
            // force-unwrap.
            guard let tier1 = node.hintTree[k]?.first else {
                preconditionFailure("DiagnosisRun.hintKey returned a key with an empty hintTree entry")
            }
            return DoorAHintContent(nodeId: node.id, prose: tier1, resolvedKey: k, internalCode: nil)
        case .some(let k):
            guard let tier1 = node.hintTree[k]?.first else {
                preconditionFailure("DiagnosisRun.hintKey returned a key with an empty hintTree entry")
            }
            return DoorAHintContent(
                nodeId: node.id, prose: tier1, resolvedKey: k, internalCode: .loHintNotFound)
        case .none:
            return DoorAHintContent(
                nodeId: node.id, prose: node.paraphrase, resolvedKey: nil, internalCode: .loHintNotFound)
        }
    }

    /// Domain-glossary v1.0.1 Remediation. `misses` classifies the remediation's own hint, never the
    /// origin's.
    static func selectRemediation(candidate: Node, misses: [ItemMiss]) -> DoorARemediationContent {
        if let explanation = candidate.explanation, !explanation.isEmpty {
            return .explanation(explanation)
        }
        if let example = candidate.workedExamples?.first {
            return .workedExample(example)
        }
        let classifiedToken = Classify.classify(misses)
        let hint = resolveHint(node: candidate, classifiedToken: classifiedToken)
        return .paraphrase(candidate.paraphrase, hint: hint.resolvedKey != nil ? hint.prose : nil)
    }
}

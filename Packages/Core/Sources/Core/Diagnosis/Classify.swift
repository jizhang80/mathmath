import Foundation

/// One failed probe attempt: the `ProbeItem` the student got wrong, and the value they submitted for it
/// (a normalised numeric string for `.numeric` items, a choice id for `.mc` items — never free text,
/// I10). Normalisation of a numeric submission is the caller's responsibility (task 02.7's expedition run
/// machine); `Classify.classify` performs exact string equality only.
public struct FailedProbeAttempt: Equatable {
    public let item: ProbeItem
    public let submittedValue: String

    public init(item: ProbeItem, submittedValue: String) {
        self.item = item
        self.submittedValue = submittedValue
    }
}

/// Diagnosis W1 step 2: the Tier-0 distractor-tag classifier. A pure lookup over already-known-wrong
/// answers — it never decides correctness (I1) and never calls a model (I2).
public enum Classify {
    /// Returns the `errorTypeId` of the first attempt (in `attempts` order) whose submitted value matches
    /// a tagged `wrongAnswers[].value` (`.numeric` items) or a tagged `choices[].id` (`.mc` items) on that
    /// attempt's own item. `"none_of_these"` if no attempt matches.
    public static func classify(_ attempts: [FailedProbeAttempt]) -> String {
        for attempt in attempts {
            switch attempt.item.type {
            case .numeric:
                if let match = (attempt.item.wrongAnswers ?? []).first(where: {
                    $0.value == attempt.submittedValue
                }) {
                    return match.errorTypeId
                }
            case .mc:
                for choice in attempt.item.choices ?? [] {
                    guard choice.id == attempt.submittedValue, let errorTypeId = choice.errorTypeId else {
                        continue
                    }
                    return errorTypeId
                }
            }
        }
        return "none_of_these"
    }
}

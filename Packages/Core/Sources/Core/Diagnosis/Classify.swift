import Foundation

/// One miss (`contracts/domain-glossary.md`: "**Miss** — an incorrect answer"): the `ProbeItem` the
/// student answered incorrectly, and the value they submitted for it (a normalised numeric string for
/// `.numeric` items, a choice id for `.mc` items — never free text, I10). Normalisation of a numeric
/// submission is the caller's responsibility (task 02.7's expedition run machine); `Classify.classify`
/// performs exact string equality only.
public struct ItemMiss: Equatable {
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
    /// Returns the `errorTypeId` of the first miss (in `misses` order) whose submitted value matches a
    /// tagged `wrongAnswers[].value` (`.numeric` items) or a tagged `choices[].id` (`.mc` items) on that
    /// miss's own item. `"none_of_these"` if no miss matches.
    public static func classify(_ misses: [ItemMiss]) -> String {
        for miss in misses {
            switch miss.item.type {
            case .numeric:
                if let match = (miss.item.wrongAnswers ?? []).first(where: {
                    $0.value == miss.submittedValue
                }) {
                    return match.errorTypeId
                }
            case .mc:
                for choice in miss.item.choices ?? [] {
                    guard choice.id == miss.submittedValue, let errorTypeId = choice.errorTypeId else {
                        continue
                    }
                    return errorTypeId
                }
            }
        }
        return "none_of_these"
    }
}

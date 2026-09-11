import Foundation

/// The item view's screen content, shared by Door B (expedition/review items and retries) and Door A
/// (probe items). Carries no `answer` and no `correct_choice_id` — the render layer never sees a field
/// that would let it decide correctness (I1, I10); only `ItemChecker` decides that, elsewhere.
public struct DoorItemContent: Equatable {
    public let nodeId: String
    public let promptLatex: String
    public let inputKind: DoorItemInputKind
    public let choices: [DoorItemChoice]
    public let isRetry: Bool

    public init(nodeId: String, item: ProbeItem, isRetry: Bool) {
        self.nodeId = nodeId
        self.promptLatex = item.promptLatex
        switch item.type {
        case .numeric:
            self.inputKind = .numeric
            self.choices = []
        case .mc:
            self.inputKind = .multipleChoice
            self.choices = (item.choices ?? []).map { DoorItemChoice(id: $0.id, latex: $0.latex) }
        }
        self.isRetry = isRetry
    }

    /// Convenience for the Door B façade's `CurrentItem`.
    public init(from currentItem: CurrentItem) {
        self.init(nodeId: currentItem.nodeId, item: currentItem.item, isRetry: currentItem.isRetry)
    }
}

public enum DoorItemInputKind: Equatable {
    case numeric
    case multipleChoice
}

/// Only `id` and `latex` are carried — never `errorTypeId` (a diagnosis-time distractor tag with no
/// render-layer use) and never anything that identifies the correct choice.
public struct DoorItemChoice: Equatable {
    public let id: String
    public let latex: String
}

/// The answer card's screen content, built only from an already-checked `ItemResult` — never from a raw
/// submission or a `ProbeItem`'s answer field. Always carries the correct answer and the why (I3).
public struct DoorAnswerCardContent: Equatable {
    public let correct: Bool
    public let correctAnswerDisplay: String
    public let correctAnswerDisplayKind: DoorAnswerDisplayKind
    public let why: String
    public let extraLine: String?

    /// `itemType` is needed only to route `correctAnswerDisplayKind` (`ItemResult` itself carries no
    /// `type` field): `mc` renders through the LaTeX view, `numeric` as plain text (I14; `data-model.md`
    /// § Text).
    public init(result: ItemResult, itemType: ProbeItemType, extraLine: String? = nil) {
        self.correct = result.correct
        self.correctAnswerDisplay = result.correctAnswerDisplay
        self.correctAnswerDisplayKind = itemType == .mc ? .latex : .plain
        self.why = result.why
        self.extraLine = extraLine
    }
}

public enum DoorAnswerDisplayKind: Equatable {
    case latex
    case plain
}

/// The numeric keypad's key set — every character the numeric-normalisation grammar admits
/// (`contracts/interaction-contract.md` § 2 "Numeric normalisation"): an optional sign, digits, `.`, `/`.
public enum DoorKeypad {
    public static let numericKeypadKeys: [String] = [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ".", "/", "+", "-",
    ]
}

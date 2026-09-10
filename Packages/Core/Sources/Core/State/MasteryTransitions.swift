import Foundation

/// The result of applying a mastery transition: the resulting `NodeState` and the `CoreEvent` (if any)
/// the transition emits.
public struct MasteryTransitionResult: Equatable {
    public let nodeState: NodeState
    public let event: CoreEvent?
}

/// The mastery-transition state machine (`contracts/interaction-contract.md` § 1) — pure, deterministic,
/// no model call, no system clock read (I2, I14). `today` is always an injected `CalendarDay`.
public enum MasteryTransitions {
    public static let ladder: [Int] = [1, 3, 7, 14, 30]

    /// Dispatches on `current.mastery` per the contract's § 1 table:
    /// - `.fog`/`.blocked` → the "new-learning" rows (clear-rule guard on distinct items).
    /// - `.cleared` → the "review" row (ladder advance, no clear-rule guard, `itemId`/`correctItemIds`
    ///   are ignored).
    public static func itemCorrect(
        current: NodeState,
        itemId: String,
        correctItemIds: Set<String>,
        today: CalendarDay
    ) -> MasteryTransitionResult {
        switch current.mastery {
        case .fog, .blocked:
            let distinctCorrect = correctItemIds.union([itemId])
            let newCorrectCount = current.correctCount + 1
            if distinctCorrect.count >= 2 {
                let node = NodeState(
                    mastery: .cleared,
                    correctCount: newCorrectCount,
                    lastProbe: today.iso,
                    nextDue: today.adding(days: ladder[0]).iso,
                    ladderRung: 0,
                    remediated: nil
                )
                return MasteryTransitionResult(nodeState: node, event: .expeditionNodeCleared)
            }
            let node = NodeState(
                mastery: current.mastery,
                correctCount: newCorrectCount,
                lastProbe: today.iso,
                nextDue: current.nextDue,
                ladderRung: current.ladderRung,
                remediated: current.remediated
            )
            return MasteryTransitionResult(nodeState: node, event: nil)
        case .cleared:
            let newRung = min(current.ladderRung + 1, ladder.count - 1)
            let node = NodeState(
                mastery: .cleared,
                correctCount: current.correctCount,
                lastProbe: today.iso,
                nextDue: today.adding(days: ladder[newRung]).iso,
                ladderRung: newRung,
                remediated: current.remediated
            )
            return MasteryTransitionResult(nodeState: node, event: nil)
        }
    }

    /// The `cleared | item_miss(node) (review)` row only. Called on a node whose `mastery != .cleared`,
    /// this is a no-op (§6 default): returns `current` unchanged, `event: nil`.
    public static func itemMissReview(
        current: NodeState,
        today: CalendarDay
    ) -> MasteryTransitionResult {
        guard current.mastery == .cleared else {
            return MasteryTransitionResult(nodeState: current, event: nil)
        }
        let node = NodeState(
            mastery: .cleared,
            correctCount: current.correctCount,
            lastProbe: today.iso,
            nextDue: today.adding(days: ladder[0]).iso,
            ladderRung: 0,
            remediated: current.remediated
        )
        return MasteryTransitionResult(nodeState: node, event: nil)
    }

    /// The `fog | diagnosis_blocked(node) | — | blocked` row only. Called on a node whose
    /// `mastery != .fog`, this is a no-op (§6 default): returns `current` unchanged, `event: nil`.
    public static func diagnosisBlocked(current: NodeState) -> MasteryTransitionResult {
        guard current.mastery == .fog else {
            return MasteryTransitionResult(nodeState: current, event: nil)
        }
        let node = NodeState(
            mastery: .blocked,
            correctCount: current.correctCount,
            lastProbe: current.lastProbe,
            nextDue: current.nextDue,
            ladderRung: current.ladderRung,
            remediated: current.remediated
        )
        return MasteryTransitionResult(nodeState: node, event: .diagnosisNodeBlocked)
    }
}

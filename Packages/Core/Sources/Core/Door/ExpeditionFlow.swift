import Foundation

/// Door B's own run wrapper: `ExpeditionRun`'s value state plus the one piece of D27 hand-off bookkeeping
/// `ExpeditionRunState` itself does not carry — the first miss's `ItemMiss`, held only between a
/// first-miss retry and a possible second-miss hand-off on the SAME node. `pendingFirstMiss` carries no
/// `public` modifier: no caller constructs or inspects it (§6).
public struct DoorBRunState: Equatable {
    public let run: ExpeditionRunState
    let pendingFirstMiss: ItemMiss?
}

public struct DoorBStartAdvance: Equatable {
    public let runState: DoorBRunState
    public let screen: DoorBScreen
    public let event: CoreEvent
}

/// Returned by `answer` (I3): the just-answered item's card only. `pendingHandoffMisses`/`pendingEnd`
/// carry no `public` modifier — no field of this type yields the next `DoorBScreen`; only
/// `continueAfterAnswer` does.
public struct DoorBAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let result: ItemResult
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
    let pendingHandoffMisses: [ItemMiss]?
    let pendingEnd: EndOutcome?
}

public struct DoorBContinueAdvance: Equatable {
    public let screen: DoorBScreen
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
}

public struct DoorBResumeAdvance: Equatable {
    public let screen: DoorBScreen
    public let runState: DoorBRunState
    public let state: StudentState
    public let events: [CoreEvent]
}

public enum DoorBExpeditionFlow {
    public static func start(compose: ComposeResult) -> DoorBStartAdvance {
        let outcome = ExpeditionRun.start(compose: compose)
        guard let current = outcome.run.currentItem else {
            preconditionFailure("DoorBExpeditionFlow.start: compose produced no first item")
        }
        return DoorBStartAdvance(
            runState: DoorBRunState(run: outcome.run, pendingFirstMiss: nil),
            screen: .item(DoorBContent.itemScreen(current)), event: outcome.event)
    }

    public static func answer(
        _ runState: DoorBRunState, submitted: String, state: StudentState, bundle: ContentBundle,
        today: CalendarDay
    ) -> DoorBAnswerAdvance {
        guard let current = runState.run.currentItem else {
            preconditionFailure("DoorBExpeditionFlow.answer called with no currentItem (suspended or ended)")
        }
        let outcome = ExpeditionRun.answer(
            run: runState.run, state: state, bundle: bundle, submitted: submitted, today: today)

        // Q5 line / hand-off detection reads missCounts before/after — never blockedNodeIds (§3, §6).
        let priorMissCount = runState.run.missCounts[current.nodeId] ?? 0
        let newMissCount = outcome.run.missCounts[current.nodeId] ?? 0
        let openedDiagnosisHere = outcome.run.suspendedForDiagnosisNodeId == current.nodeId
        let isSecondMissThisCall =
            !outcome.result.correct && priorMissCount == 1 && newMissCount == 2
        let extraLine =
            (isSecondMissThisCall && !openedDiagnosisHere) ? DoorBSummaryCopy.secondMissLine : nil
        let answerCard = DoorAnswerCardContent(
            result: outcome.result, itemType: current.item.type, extraLine: extraLine)

        var newPendingFirstMiss: ItemMiss?
        var pendingHandoffMisses: [ItemMiss]?
        if !outcome.result.correct {
            let thisMiss = ItemMiss(item: current.item, submittedValue: submitted)
            let retryDrawnHere =
                outcome.run.currentItem?.isRetry == true
                && outcome.run.currentItem?.nodeId == current.nodeId
            if retryDrawnHere {
                newPendingFirstMiss = thisMiss
            } else if openedDiagnosisHere {
                pendingHandoffMisses = [runState.pendingFirstMiss, thisMiss].compactMap { $0 }
            }
            // else: block-after-diagnosisUsed (Q5) or an item-pool dead-end — no pending state kept.
        }

        var pendingEnd: EndOutcome?
        if outcome.run.currentItem == nil && outcome.run.suspendedForDiagnosisNodeId == nil {
            // Q-G: the natural end, computed here, revealed on continue.
            pendingEnd = ExpeditionRun.end(
                run: outcome.run, state: outcome.state, today: today, abandoned: false)
        }

        return DoorBAnswerAdvance(
            answerCard: answerCard, result: outcome.result,
            runState: DoorBRunState(run: outcome.run, pendingFirstMiss: newPendingFirstMiss),
            state: outcome.state, events: outcome.events,
            pendingHandoffMisses: pendingHandoffMisses, pendingEnd: pendingEnd)
    }

    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, bundle: ContentBundle)
        -> DoorBContinueAdvance
    {
        if let end = pending.pendingEnd {
            return DoorBContinueAdvance(
                screen: .summary(DoorBContent.summaryScreen(summary: end.summary, bundle: bundle)),
                runState: pending.runState, state: end.state, events: [end.event])
        }
        if let misses = pending.pendingHandoffMisses,
            let originNodeId = pending.runState.run.suspendedForDiagnosisNodeId
        {
            let event = DoorADiagnosisFlow.open(
                originNodeId: originNodeId, trigger: .expeditionSecondMiss, levelBudget: 1)
            let advance = DoorADiagnosisFlow.start(
                event: event, misses: misses,
                shownItemIdsInRun: pending.runState.run.shownItemIds, state: pending.state, bundle: bundle)
            return DoorBContinueAdvance(
                screen: .diagnosis(advance.screen), runState: pending.runState, state: advance.state,
                events: advance.events)
        }
        guard let current = pending.runState.run.currentItem else {
            preconditionFailure(
                "DoorBExpeditionFlow.continueAfterAnswer: no next item, no hand-off, no end pending")
        }
        return DoorBContinueAdvance(
            screen: .item(DoorBContent.itemScreen(current)), runState: pending.runState,
            state: pending.state, events: [])
    }

    public static func resumeAfterDiagnosis(
        _ runState: DoorBRunState, outcome: DiagnosisOutcome, bundle: ContentBundle, today: CalendarDay
    ) -> DoorBResumeAdvance {
        let resumedRun = ExpeditionRun.resume(run: runState.run)
        let resumedRunState = DoorBRunState(run: resumedRun, pendingFirstMiss: nil)
        if let current = resumedRun.currentItem {
            return DoorBResumeAdvance(
                screen: .item(DoorBContent.itemScreen(current)), runState: resumedRunState,
                state: outcome.state, events: [])
        }
        let end = ExpeditionRun.end(
            run: resumedRun, state: outcome.state, today: today, abandoned: false)
        return DoorBResumeAdvance(
            screen: .summary(DoorBContent.summaryScreen(summary: end.summary, bundle: bundle)),
            runState: resumedRunState, state: end.state, events: [end.event])
    }
}

/// Q-G write-ahead value: what task 04.5 persists after every state-changing Door B or Door A call during
/// a run, replaced by the natural end or "Back to the map" abandon. A pure computation — 04.5 performs the
/// write. `runState.run` stays unchanged across the whole Door A leg of a diagnosis (it is suspended), so
/// 04.5 calls this with the same `runState` and each successively newer `state` Door A's own steps thread.
public enum DoorBWriteAhead {
    public static func provisionalAbandonedState(
        runState: DoorBRunState, state: StudentState, today: CalendarDay
    ) -> StudentState {
        ExpeditionRun.end(run: runState.run, state: state, today: today, abandoned: true).state
    }
}

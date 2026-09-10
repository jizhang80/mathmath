import Foundation

/// Always shown to the student before any next-item state is reachable (I3).
public struct ItemResult: Equatable {
    public let nodeId: String
    public let itemId: String
    public let correct: Bool
    public let correctAnswerDisplay: String
    public let why: String
    public let isRetry: Bool
}

/// The item currently awaiting an answer. `kind` carries the slot's original `newLearning`/`review`
/// classification through a D27 retry (a retry re-tests the same node/kind with a different item).
public struct CurrentItem: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind
    public let isRetry: Bool
}

/// The run's own value state, threaded by the caller through every `answer`/`resume` call alongside its
/// own copy of `StudentState` (which this type never embeds — see the file-level hand-off note on
/// `ExpeditionRun`). A value type: every public function takes `run` by value and returns a new one; no
/// caller's value is ever mutated in place (§6 "Value-type mutation style").
public struct ExpeditionRunState: Equatable {
    public var queue: [ComposeSlot]
    public var currentItem: CurrentItem?
    public var diagnosisUsed: Bool
    public var missCounts: [String: Int]
    /// Items whose answer has been shown this run. Public because task 02.11 reads this exact set when
    /// computing the Q-G "available" probe-item definition for the `expedition_second_miss` trigger —
    /// `StudentState.probeLog` alone cannot answer "shown in the CURRENT run" because no run boundary is
    /// recorded there.
    public var shownItemIds: Set<String>
    public var itemPoolEmptyNodeIds: [String]
    public var results: [ItemResult]
    public var clearedNodeIds: [String]
    public var blockedNodeIds: [String]
    public var itemsAnswered: Int
    /// Non-nil exactly while the run is suspended waiting on a diagnosis event's `returned`. Non-nil
    /// implies `currentItem == nil`.
    public var suspendedForDiagnosisNodeId: String?
}

public struct StartOutcome: Equatable {
    public let run: ExpeditionRunState
    public let event: CoreEvent
}

public struct AnswerOutcome: Equatable {
    public let run: ExpeditionRunState
    public let state: StudentState
    public let result: ItemResult
    public let events: [CoreEvent]
}

public struct ExpeditionSummary: Equatable {
    public let itemCount: Int
    public let clearedNodeIds: [String]
    public let blockedNodeIds: [String]
    public let abandoned: Bool
}

public struct EndOutcome: Equatable {
    public let state: StudentState
    public let summary: ExpeditionSummary
    public let event: CoreEvent
}

/// The pure expedition-run state machine (`contracts/interaction-contract.md` v0.9.1 § 2:
/// `idle → composing → item → (retry | diagnosing | item) → summary → idle`). Consumes a `ComposeResult`
/// from `Expedition.compose`, drives items one at a time through `ItemChecker`, applies the D27 tolerance
/// rule (retry, then diagnosis-or-block), and ends with a summary plus `expedition_log`/`probe_log`
/// entries.
///
/// **Suspend/resume hand-off (owned here, never edited by task 02.11).** When the run's D27 rule opens a
/// diagnosis (second miss, `diagnosisUsed == false`), `answer` returns an `ExpeditionRunState` with
/// `currentItem == nil` and `suspendedForDiagnosisNodeId` set to the missed node's id — the entire signal
/// 02.11 needs to know a diagnosis should open, with that node id as `origin`. Diagnosis (02.11) runs its
/// own state machine entirely in its own file, over its own copy of `StudentState`, and — once it reaches
/// `returned` — calls `ExpeditionRun.resume(run:)` with nothing else: no diagnosis-outcome value, no
/// `StudentState`. `resume` only pops the run's own queue and clears the suspension flag; the diagnosis's
/// effect on mastery/`remediated` is already carried inside whatever `StudentState` the diagnosis
/// produced, which the caller threads into the next call to `ExpeditionRun.answer(run:, state:, ...)`.
public enum ExpeditionRun {
    public static func start(compose: ComposeResult) -> StartOutcome {
        let first = compose.slots.first
        let run = ExpeditionRunState(
            queue: Array(compose.slots.dropFirst()),
            currentItem: first.map {
                CurrentItem(nodeId: $0.nodeId, item: $0.item, kind: $0.kind, isRetry: false)
            },
            diagnosisUsed: false, missCounts: [:], shownItemIds: [], itemPoolEmptyNodeIds: [],
            results: [], clearedNodeIds: [], blockedNodeIds: [], itemsAnswered: 0,
            suspendedForDiagnosisNodeId: nil)
        return StartOutcome(run: run, event: .expeditionStarted)
    }

    public static func answer(
        run: ExpeditionRunState, state: StudentState, bundle: ContentBundle, submitted: String,
        today: CalendarDay
    ) -> AnswerOutcome {
        guard let current = run.currentItem else {
            preconditionFailure("ExpeditionRun.answer called with no currentItem (suspended or ended)")
        }
        let correct = ItemChecker.check(item: current.item, submitted: submitted)
        let display = ItemChecker.correctAnswerDisplay(for: current.item)
        let result = ItemResult(
            nodeId: current.nodeId, itemId: current.item.id, correct: correct,
            correctAnswerDisplay: display, why: current.item.why, isRetry: current.isRetry)

        var nodes = state.nodes
        let priorNodeState =
            nodes[current.nodeId]
            ?? NodeState(
                mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0,
                remediated: nil)
        let probeLog =
            state.probeLog
            + [
                ProbeLogEntry(
                    day: today.iso, nodeId: current.nodeId, itemId: current.item.id, correct: correct,
                    retry: current.isRetry)
            ]
        var events: [CoreEvent] = [.expeditionItemAnswered]
        var run = run
        // Local copy of a value type; see §6 "value-type mutation style".
        run.shownItemIds.insert(current.item.id)

        if correct {
            let correctItemIds = Set(
                state.probeLog.filter { $0.nodeId == current.nodeId && $0.correct }.map(\.itemId))
            let transition = MasteryTransitions.itemCorrect(
                current: priorNodeState, itemId: current.item.id, correctItemIds: correctItemIds,
                today: today)
            nodes[current.nodeId] = transition.nodeState
            if let event = transition.event {
                events.append(event)
                if event == .expeditionNodeCleared { run.clearedNodeIds.append(current.nodeId) }
            }
            run.currentItem = nextItem(from: &run)
        } else if priorNodeState.mastery == .cleared {
            let transition = MasteryTransitions.itemMissReview(current: priorNodeState, today: today)
            nodes[current.nodeId] = transition.nodeState
            applyMiss(
                nodeId: current.nodeId, kind: current.kind, run: &run, state: &nodes,
                priorNodeState: transition.nodeState, bundle: bundle, probeLog: probeLog,
                events: &events)
        } else {
            applyMiss(
                nodeId: current.nodeId, kind: current.kind, run: &run, state: &nodes,
                priorNodeState: priorNodeState, bundle: bundle, probeLog: probeLog, events: &events)
        }

        run.itemsAnswered += 1
        run.results.append(result)
        let newState = StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: nodes, trail: state.trail,
            expeditionLog: state.expeditionLog, probeLog: probeLog, installDay: state.installDay,
            consentOn: state.consentOn)
        return AnswerOutcome(run: run, state: newState, result: result, events: events)
    }

    public static func resume(run: ExpeditionRunState) -> ExpeditionRunState {
        guard run.suspendedForDiagnosisNodeId != nil else {
            preconditionFailure("ExpeditionRun.resume called with nothing suspended")
        }
        var run = run
        run.suspendedForDiagnosisNodeId = nil
        run.currentItem = nextItem(from: &run)
        return run
    }

    public static func end(
        run: ExpeditionRunState, state: StudentState, today: CalendarDay, abandoned: Bool
    ) -> EndOutcome {
        let entry = ExpeditionLogEntry(
            day: today.iso, itemCount: run.itemsAnswered, cleared: run.clearedNodeIds.count,
            blocked: run.blockedNodeIds.count, abandoned: abandoned,
            diagnosisEvents: run.diagnosisUsed ? 1 : 0)
        let newState = StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: state.nodes, trail: state.trail,
            expeditionLog: state.expeditionLog + [entry], probeLog: state.probeLog,
            installDay: state.installDay, consentOn: state.consentOn)
        let summary = ExpeditionSummary(
            itemCount: run.itemsAnswered, clearedNodeIds: run.clearedNodeIds,
            blockedNodeIds: run.blockedNodeIds, abandoned: abandoned)
        return EndOutcome(state: newState, summary: summary, event: .expeditionCompleted)
    }

    // MARK: - Private

    /// Pops `run.queue` into a `CurrentItem` (drawing that node's own item via the `ComposeSlot` it
    /// already carries — no re-draw here; `compose` already drew each slot's item). `nil` when the queue
    /// is empty (the run is naturally complete; the caller should call `end`).
    private static func nextItem(from run: inout ExpeditionRunState) -> CurrentItem? {
        guard !run.queue.isEmpty else { return nil }
        let slot = run.queue.removeFirst()
        return CurrentItem(nodeId: slot.nodeId, item: slot.item, kind: slot.kind, isRetry: false)
    }

    /// The D27 branch for a miss, shared by the fog/blocked path and the review path: increments
    /// `missCounts[nodeId]`; on the first miss, draws a retry item via
    /// `Expedition.selectItem(from:excluding:probeLog:)` excluding `run.shownItemIds` — if `nil` (no
    /// unused item), appends `nodeId` to `run.itemPoolEmptyNodeIds` and advances to the next queue item
    /// instead of retrying (the arbiter's technical default); on the second miss with
    /// `run.diagnosisUsed == false`, sets `run.suspendedForDiagnosisNodeId = nodeId`,
    /// `run.diagnosisUsed = true`, `run.currentItem = nil`, appends `.expeditionDiagnosisRequested` to
    /// `events`; on the second miss with `run.diagnosisUsed == true`, calls
    /// `MasteryTransitions.diagnosisBlocked(current: priorNodeState)`, writes the result into `state`,
    /// appends `nodeId` to `run.blockedNodeIds` and `.diagnosisNodeBlocked` to `events` when that call's
    /// `event` is non-nil, and advances `run.currentItem` to the next queue item.
    private static func applyMiss(
        nodeId: String, kind: SlotKind, run: inout ExpeditionRunState, state: inout [String: NodeState],
        priorNodeState: NodeState, bundle: ContentBundle, probeLog: [ProbeLogEntry],
        events: inout [CoreEvent]
    ) {
        let missCount = (run.missCounts[nodeId] ?? 0) + 1
        run.missCounts[nodeId] = missCount

        if missCount == 1 {
            guard let node = bundle.nodes.nodes.first(where: { $0.id == nodeId }),
                let retryItem = Expedition.selectItem(
                    from: node, excluding: run.shownItemIds, probeLog: probeLog)
            else {
                run.itemPoolEmptyNodeIds.append(nodeId)
                run.currentItem = nextItem(from: &run)
                return
            }
            run.currentItem = CurrentItem(nodeId: nodeId, item: retryItem, kind: kind, isRetry: true)
            return
        }

        if !run.diagnosisUsed {
            run.diagnosisUsed = true
            run.suspendedForDiagnosisNodeId = nodeId
            run.currentItem = nil
            events.append(.expeditionDiagnosisRequested)
            return
        }

        let transition = MasteryTransitions.diagnosisBlocked(current: priorNodeState)
        state[nodeId] = transition.nodeState
        if let event = transition.event {
            run.blockedNodeIds.append(nodeId)
            events.append(event)
        }
        run.currentItem = nextItem(from: &run)
    }
}

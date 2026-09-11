import Foundation

/// What opened the diagnosis (`contracts/interaction-contract.md` § 4 `open`).
public enum DiagnosisTrigger: String, Equatable {
    case expeditionSecondMiss = "expedition_second_miss"
    case mapCheckHere = "map_check_here"
}

/// The immutable event that opens a diagnosis: origin node, trigger and backtrack budget (D4, Q4).
public struct DiagnosisEvent: Equatable {
    public let originNodeId: String
    public let trigger: DiagnosisTrigger
    public let levelBudget: Int
}

/// The diagnosis's terminal outcomes. `refuted` = contract `pass`, `confirmed` = contract `fail`,
/// `unconfirmed` covers both `declined` and `DIAG_PROBE_UNAVAILABLE` (neither is a probe outcome that
/// reaches `.diagnosisProbeCompleted` on the `unavailable` branch — see `ProbeOutcome`), `capped` is the
/// W6 backtrack-cap branch, `noPrerequisite` is `DIAG_NO_PREREQUISITE`.
public enum DiagnosisTerminal: Equatable {
    case refuted, confirmed, unconfirmed, capped, noPrerequisite
}

/// The `diagnosis.probe_completed` payload value (`contracts/domain-glossary.md` § Probe: "pass / fail /
/// declined"), plus `unavailable` for `DIAG_PROBE_UNAVAILABLE`, which is not a probe outcome and never
/// accompanies `.diagnosisProbeCompleted` (`tasks/arbitration/arbiter-02-11-probe-completed.md`).
public enum ProbeOutcome: Equatable { case refuted, confirmed, declined, unavailable }

/// The result of a concluded (or declined/unavailable) probe at one level.
public struct DiagnosisProbeResult: Equatable {
    public let outcome: ProbeOutcome
    public let results: [ItemResult]
    public let misses: [ItemMiss]
    public let code: CoreError?
}

/// The terminal record of a whole diagnosis event, written into `StudentState` and handed back to the
/// caller (W5 "Return").
public struct DiagnosisOutcome: Equatable {
    public let state: StudentState
    public let terminal: DiagnosisTerminal
    public let depthReached: Int
    public let blockedNodeIds: [String]
    public let hintNodeId: String?
    public let hintErrorTypeId: String?
    public let probeResults: [ItemResult]
    public let events: [CoreEvent]
    public let code: CoreError?
}

/// The machine's accumulated, read-only context; embedded in every non-terminal phase value.
public struct DiagnosisContext: Equatable {
    public let event: DiagnosisEvent
    public let level: Int
    public let depthReached: Int
    public let originErrorTypeId: String
    public let shownItemIdsInRun: Set<String>
    public let blockedNodeIds: [String]
    public let probeResults: [ItemResult]
    public let events: [CoreEvent]
}

/// Hypothesis card (W1 step 3 / W2 Post; W3 step 1): accept or decline the probe.
public struct ProbeOffer: Equatable {
    public let context: DiagnosisContext
    public let candidateId: String
}

/// A probe with 2 drawn items; exactly `levelResults.count` (0 or 1) of them answered.
public struct ProbeInProgress: Equatable {
    public let context: DiagnosisContext
    public let candidateId: String
    public let items: [ProbeItem]
    public let levelResults: [ItemResult]
    let misses: [ItemMiss]
    public var currentItem: ProbeItem { items[levelResults.count] }
}

/// Remediation shown for `candidateId`; budget remains; accept or decline one more level (W4 step 3, Q3).
public struct FurtherLevelOffer: Equatable {
    public let context: DiagnosisContext
    public let candidateId: String
    let misses: [ItemMiss]
}

public enum DiagnosisStep: Equatable {
    case probeOffer(ProbeOffer)
    case probeItem(ProbeInProgress)
    case furtherLevelOffer(FurtherLevelOffer)
    case returned(DiagnosisOutcome)
}

/// The result of one step call: the next phase, the `StudentState` the caller threads into the next
/// call, this call's own `CoreEvent`s, and (when applicable) the item just checked or the probe just
/// concluded.
public struct DiagnosisAdvance: Equatable {
    public let step: DiagnosisStep
    public let state: StudentState
    public let events: [CoreEvent]
    public let itemResult: ItemResult?
    public let probeResult: DiagnosisProbeResult?
}

/// Input to the thin driver `run` only — one level's worth of decisions, taken up front. The step API
/// never uses this type; each of its calls takes its decision as an explicit argument instead.
public struct DiagnosisLevelDecision: Equatable {
    public let declineProbe: Bool
    public let submittedAnswers: [String]
    public let acceptFurtherLevel: Bool

    public init(declineProbe: Bool, submittedAnswers: [String], acceptFurtherLevel: Bool) {
        self.declineProbe = declineProbe
        self.submittedAnswers = submittedAnswers
        self.acceptFurtherLevel = acceptFurtherLevel
    }
}

/// The Door A diagnosis state machine (`contracts/interaction-contract.md` § 4;
/// `docs/domains/diagnosis.md` W1-W6), step-wise: one public function per student decision point, each
/// returning the next phase value, the threaded `StudentState` and that call's `CoreEvent`s
/// (`tasks/arbitration/arbiter-02-11-stepwise-api.md`). A pure value transformation over its arguments —
/// no I/O, no system-clock read except the caller's injected `CalendarDay`, no model call anywhere (I2,
/// I14). `level` is the cumulative graph depth from the origin; a hypothesis queries only
/// `levelBudget - priorLevel` levels, so `depthReached <= levelBudget <= 2` holds on every path.
public enum DiagnosisRun {
    /// Pure construction; emits nothing (`.diagnosisOpened` is emitted by `start`). This is the call
    /// EPIC 03's "Check me here" makes.
    public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int)
        -> DiagnosisEvent
    {
        DiagnosisEvent(originNodeId: originNodeId, trigger: trigger, levelBudget: levelBudget)
    }

    /// W1 + W2 at the first level. `originErrorTypeId = classify(misses)`; for `map_check_here`
    /// the caller passes `misses: []` (so `originErrorTypeId == "none_of_these"`) and
    /// `shownItemIdsInRun: []`.
    public static func start(
        event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
        state: StudentState, bundle: ContentBundle
    ) -> DiagnosisAdvance {
        let originErrorTypeId = classify(misses)
        let context = DiagnosisContext(
            event: event, level: 0, depthReached: 0, originErrorTypeId: originErrorTypeId,
            shownItemIdsInRun: shownItemIdsInRun, blockedNodeIds: [], probeResults: [],
            events: [.diagnosisOpened])
        let advance = formHypothesis(
            queryOriginId: event.originNodeId, biasErrorTypeId: originErrorTypeId, context: context,
            state: state, bundle: bundle)
        return DiagnosisAdvance(
            step: advance.step, state: advance.state, events: [.diagnosisOpened] + advance.events,
            itemResult: advance.itemResult, probeResult: advance.probeResult)
    }

    /// W3 steps 1-2: accept or decline the probe (Q2).
    public static func decideProbe(
        _ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DiagnosisAdvance {
        guard accept else {
            let probeResult = DiagnosisProbeResult(
                outcome: .declined, results: [], misses: [], code: nil)
            let finalContext = updatedContext(
                offer.context, appendingEvents: [.diagnosisProbeCompleted, .diagnosisReturned])
            let outcome = terminal(
                .unconfirmed, code: nil, hint: true, context: finalContext, state: state, bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: state,
                events: [.diagnosisProbeCompleted, .diagnosisReturned], itemResult: nil,
                probeResult: probeResult)
        }
        guard let candidate = bundle.nodes.nodes.first(where: { $0.id == offer.candidateId }) else {
            preconditionFailure(
                "DiagnosisRun.decideProbe: candidate \(offer.candidateId) not found in bundle")
        }
        guard
            let items = drawProbeItems(
                candidate: candidate, trigger: offer.context.event.trigger,
                shownItemIdsInRun: offer.context.shownItemIdsInRun, probeLog: state.probeLog)
        else {
            let probeResult = DiagnosisProbeResult(
                outcome: .unavailable, results: [], misses: [], code: .diagProbeUnavailable)
            let finalContext = updatedContext(offer.context, appendingEvents: [.diagnosisReturned])
            let outcome = terminal(
                .unconfirmed, code: .diagProbeUnavailable, hint: true, context: finalContext,
                state: state, bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: state, events: [.diagnosisReturned], itemResult: nil,
                probeResult: probeResult)
        }
        let probe = ProbeInProgress(
            context: offer.context, candidateId: offer.candidateId, items: items, levelResults: [],
            misses: [])
        return DiagnosisAdvance(
            step: .probeItem(probe), state: state, events: [], itemResult: nil, probeResult: nil)
    }

    /// W3 step 3 (I1, I3), then W3 step 4 / W4 / W6.
    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
        today: CalendarDay
    ) -> DiagnosisAdvance {
        let item = probe.currentItem
        let correct = ItemChecker.check(item: item, submitted: submitted)
        let result = ItemResult(
            nodeId: probe.candidateId, itemId: item.id, correct: correct,
            correctAnswerDisplay: ItemChecker.correctAnswerDisplay(for: item), why: item.why,
            isRetry: false)
        var misses = probe.misses
        if !correct {
            misses.append(ItemMiss(item: item, submittedValue: submitted))
        }
        let levelResults = probe.levelResults + [result]

        guard levelResults.count == 2 else {
            let updated = ProbeInProgress(
                context: probe.context, candidateId: probe.candidateId, items: probe.items,
                levelResults: levelResults, misses: misses)
            return DiagnosisAdvance(
                step: .probeItem(updated), state: state, events: [], itemResult: result,
                probeResult: nil)
        }

        guard !misses.isEmpty else {
            let probeResult = DiagnosisProbeResult(
                outcome: .refuted, results: levelResults, misses: [], code: nil)
            let finalContext = updatedContext(
                probe.context, depthReached: probe.context.level,
                probeResults: probe.context.probeResults + levelResults,
                appendingEvents: [.diagnosisProbeCompleted, .diagnosisReturned])
            let outcome = terminal(
                .refuted, code: nil, hint: true, context: finalContext, state: state, bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: state,
                events: [.diagnosisProbeCompleted, .diagnosisReturned], itemResult: result,
                probeResult: probeResult)
        }

        // W4: fail — candidate blocked, one remediation piece, `remediated = true`.
        let probeResult = DiagnosisProbeResult(
            outcome: .confirmed, results: levelResults, misses: misses, code: nil)
        let fogDefault = NodeState(
            mastery: .fog, correctCount: 0, lastProbe: nil, nextDue: nil, ladderRung: 0, remediated: nil)
        var nodes = state.nodes
        nodes[probe.candidateId] = remediate(current: nodes[probe.candidateId] ?? fogDefault)
        var probeLog = state.probeLog
        for r in levelResults {
            probeLog.append(
                ProbeLogEntry(
                    day: today.iso, nodeId: probe.candidateId, itemId: r.itemId, correct: r.correct,
                    retry: false))
        }
        let stateAfterRemediation = StudentState(
            schemaVersion: state.schemaVersion, formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi, marker: state.marker, nodes: nodes, trail: state.trail,
            expeditionLog: state.expeditionLog, probeLog: probeLog, installDay: state.installDay,
            consentOn: state.consentOn)
        let contextAfterRemediation = updatedContext(
            probe.context, depthReached: probe.context.level,
            blockedNodeIds: probe.context.blockedNodeIds + [probe.candidateId],
            probeResults: probe.context.probeResults + levelResults,
            appendingEvents: [
                .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
            ])

        if offered(levelReached: probe.context.level, levelBudget: probe.context.event.levelBudget) {
            let furtherOffer = FurtherLevelOffer(
                context: contextAfterRemediation, candidateId: probe.candidateId,
                misses: misses)
            return DiagnosisAdvance(
                step: .furtherLevelOffer(furtherOffer), state: stateAfterRemediation,
                events: [.diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown],
                itemResult: result, probeResult: probeResult)
        }

        // W6: budget exhausted — one query, singular deeper candidate, no probe, no remediation.
        let deeper = hypothesise(
            originId: probe.candidateId, biasErrorTypeId: classify(misses),
            state: stateAfterRemediation, bundle: bundle, levelBudget: 1)
        let contextAfterQuery = updatedContext(
            contextAfterRemediation, appendingEvents: [.graphPrerequisiteReturned])

        guard let deeperCandidate = deeper.candidate else {
            let finalContext = updatedContext(contextAfterQuery, appendingEvents: [.diagnosisReturned])
            let outcome = terminal(
                .confirmed, code: nil, hint: false, context: finalContext, state: stateAfterRemediation,
                bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: stateAfterRemediation,
                events: [
                    .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
                    .graphPrerequisiteReturned, .diagnosisReturned,
                ], itemResult: result, probeResult: probeResult)
        }

        let d = deeperCandidate.node.id
        var cappedNodes = stateAfterRemediation.nodes
        cappedNodes[d] = capped(current: cappedNodes[d] ?? fogDefault)
        let stateAfterCap = StudentState(
            schemaVersion: stateAfterRemediation.schemaVersion,
            formatVersionSeen: stateAfterRemediation.formatVersionSeen,
            syllabi: stateAfterRemediation.syllabi, marker: stateAfterRemediation.marker,
            nodes: cappedNodes, trail: stateAfterRemediation.trail,
            expeditionLog: stateAfterRemediation.expeditionLog, probeLog: stateAfterRemediation.probeLog,
            installDay: stateAfterRemediation.installDay, consentOn: stateAfterRemediation.consentOn)
        let finalContext = updatedContext(
            contextAfterQuery, blockedNodeIds: contextAfterQuery.blockedNodeIds + [d],
            appendingEvents: [.diagnosisNodeBlocked, .diagnosisCapped, .diagnosisReturned])
        let outcome = terminal(
            .capped, code: nil, hint: false, context: finalContext, state: stateAfterCap, bundle: bundle)
        return DiagnosisAdvance(
            step: .returned(outcome), state: stateAfterCap,
            events: [
                .diagnosisProbeCompleted, .diagnosisNodeBlocked, .diagnosisRemediationShown,
                .graphPrerequisiteReturned, .diagnosisNodeBlocked, .diagnosisCapped, .diagnosisReturned,
            ], itemResult: result, probeResult: probeResult)
    }

    /// W4 step 3 (Q3: "offered, never automatic").
    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DiagnosisAdvance {
        guard accept else {
            let finalContext = updatedContext(offer.context, appendingEvents: [.diagnosisReturned])
            let outcome = terminal(
                .confirmed, code: nil, hint: false, context: finalContext, state: state, bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: state, events: [.diagnosisReturned], itemResult: nil,
                probeResult: nil)
        }
        return formHypothesis(
            queryOriginId: offer.candidateId, biasErrorTypeId: classify(offer.misses),
            context: offer.context, state: state, bundle: bundle)
    }

    /// The thin batch driver, built only on the step functions above; carries no diagnosis logic of its
    /// own. `decisions.count <= k` at the k-th `ProbeOffer` uses the §6 fallback (decline, no answers, no
    /// further level) — the safest Tier-0 reading.
    public static func run(
        trigger: DiagnosisTrigger, originNodeId: String, misses: [ItemMiss],
        levelBudget: Int, decisions: [DiagnosisLevelDecision], shownItemIdsInRun: Set<String>,
        state: StudentState, bundle: ContentBundle, today: CalendarDay
    ) -> DiagnosisOutcome {
        let event = open(originNodeId: originNodeId, trigger: trigger, levelBudget: levelBudget)
        var advance = start(
            event: event, misses: misses, shownItemIdsInRun: shownItemIdsInRun,
            state: state, bundle: bundle)
        let fallback = DiagnosisLevelDecision(
            declineProbe: true, submittedAnswers: [], acceptFurtherLevel: false)
        var offerIndex = -1
        var currentDecision = fallback

        while true {
            switch advance.step {
            case .returned(let outcome):
                return outcome
            case .probeOffer(let offer):
                offerIndex += 1
                currentDecision = offerIndex < decisions.count ? decisions[offerIndex] : fallback
                advance = decideProbe(
                    offer, accept: !currentDecision.declineProbe, state: advance.state, bundle: bundle)
            case .probeItem(let probe):
                let idx = probe.levelResults.count
                let submitted =
                    idx < currentDecision.submittedAnswers.count
                    ? currentDecision.submittedAnswers[idx] : ""
                advance = answerProbeItem(
                    probe, submitted: submitted, state: advance.state, bundle: bundle, today: today)
            case .furtherLevelOffer(let offer):
                advance = decideFurtherLevel(
                    offer, accept: currentDecision.acceptFurtherLevel, state: advance.state,
                    bundle: bundle)
            }
        }
    }

    // MARK: - Internal helpers (unit-tested via @testable import Core; never public)

    static func classify(_ misses: [ItemMiss]) -> String {
        Classify.classify(misses)
    }

    static func hypothesise(
        originId: String, biasErrorTypeId: String?, state: StudentState, bundle: ContentBundle,
        levelBudget: Int
    ) -> PrerequisiteQueryResult {
        PrerequisiteQuery.deepestUnmasteredPrerequisite(
            originId: originId, biasErrorTypeId: biasErrorTypeId, state: state, bundle: bundle,
            levelBudget: levelBudget)
    }

    /// "Available" (Q-G): excludes items whose answer was already shown in the current run under
    /// `expedition_second_miss`; every item of the candidate is available under `map_check_here`.
    static func drawProbeItems(
        candidate: Node, trigger: DiagnosisTrigger, shownItemIdsInRun: Set<String>,
        probeLog: [ProbeLogEntry]
    ) -> [ProbeItem]? {
        let unavailableIds: Set<String> =
            trigger == .expeditionSecondMiss
            ? Set(candidate.probeItems.map(\.id)).intersection(shownItemIdsInRun) : []
        guard
            let item1 = Expedition.selectItem(
                from: candidate, excluding: unavailableIds, probeLog: probeLog)
        else { return nil }
        guard
            let item2 = Expedition.selectItem(
                from: candidate, excluding: unavailableIds.union([item1.id]), probeLog: probeLog)
        else { return nil }
        return [item1, item2]
    }

    /// A further level is offered iff the cumulative depth reached does not already meet the budget.
    static func offered(levelReached: Int, levelBudget: Int) -> Bool {
        levelReached < levelBudget
    }

    /// Called only on a probed candidate whose probe failed: `blocked`, `remediated = true` (a no-op
    /// block if already `.blocked`).
    static func remediate(current: NodeState) -> NodeState {
        let blocked = MasteryTransitions.diagnosisBlocked(current: current).nodeState
        return NodeState(
            mastery: blocked.mastery, correctCount: blocked.correctCount, lastProbe: blocked.lastProbe,
            nextDue: blocked.nextDue, ladderRung: blocked.ladderRung, remediated: true)
    }

    /// Called only on the W6 deeper candidate, never on a probed candidate. `remediated` passes through
    /// unchanged (`contracts/data-model.md` § StudentState: "A node blocked by `capped` ... does not
    /// carry it").
    static func capped(current: NodeState) -> NodeState {
        MasteryTransitions.diagnosisBlocked(current: current).nodeState
    }

    /// `errorTypeId`, when it resolves on the origin's `hintTree`; else the catalogue id
    /// `"none-of-these"`, when that resolves; else `nil`. Never returns the classify outcome token
    /// `"none_of_these"` and never substitutes another error type's key
    /// (`tasks/arbitration/arbiter-02-none-of-these.md`).
    static func hintKey(originNode: Node, errorTypeId: String) -> String? {
        let classifyAbstention = "none_of_these"
        let noneOfTheseCatalogueId = "none-of-these"
        func resolves(_ k: String) -> Bool { !(originNode.hintTree[k] ?? []).isEmpty }
        if errorTypeId != classifyAbstention, resolves(errorTypeId) {
            return errorTypeId
        }
        if resolves(noneOfTheseCatalogueId) {
            return noneOfTheseCatalogueId
        }
        return nil
    }

    /// Builds the `DiagnosisOutcome`. `context.events` must already be the full accumulated sequence
    /// through this advance (every call site appends its own final events before calling `terminal`).
    static func terminal(
        _ outcome: DiagnosisTerminal, code: CoreError?, hint: Bool, context: DiagnosisContext,
        state: StudentState, bundle: ContentBundle
    ) -> DiagnosisOutcome {
        var hintNodeId: String?
        var hintErrorTypeId: String?
        if hint {
            hintNodeId = context.event.originNodeId
            if let originNode = bundle.nodes.nodes.first(where: { $0.id == context.event.originNodeId }) {
                hintErrorTypeId = hintKey(originNode: originNode, errorTypeId: context.originErrorTypeId)
            }
        }
        return DiagnosisOutcome(
            state: state, terminal: outcome, depthReached: context.depthReached,
            blockedNodeIds: context.blockedNodeIds, hintNodeId: hintNodeId,
            hintErrorTypeId: hintErrorTypeId, probeResults: context.probeResults, events: context.events,
            code: code)
    }

    /// W2 at any level: queries the deepest unmastered prerequisite within the remaining budget, biased
    /// by `biasErrorTypeId`. No candidate -> `DIAG_NO_PREREQUISITE`, hint on the origin, returned.
    /// Candidate found -> `.probeOffer` at the new cumulative level.
    private static func formHypothesis(
        queryOriginId: String, biasErrorTypeId: String?, context: DiagnosisContext, state: StudentState,
        bundle: ContentBundle
    ) -> DiagnosisAdvance {
        let q = hypothesise(
            originId: queryOriginId, biasErrorTypeId: biasErrorTypeId, state: state, bundle: bundle,
            levelBudget: context.event.levelBudget - context.level)
        guard let candidate = q.candidate else {
            let finalContext = updatedContext(
                context, appendingEvents: [.graphPrerequisiteReturned, .diagnosisReturned])
            let outcome = terminal(
                .noPrerequisite, code: .diagNoPrerequisite, hint: true, context: finalContext,
                state: state, bundle: bundle)
            return DiagnosisAdvance(
                step: .returned(outcome), state: state,
                events: [.graphPrerequisiteReturned, .diagnosisReturned], itemResult: nil,
                probeResult: nil)
        }
        let newLevelContext = updatedContext(
            context, level: context.level + candidate.depth,
            appendingEvents: [.graphPrerequisiteReturned, .diagnosisHypothesisFormed])
        let offer = ProbeOffer(context: newLevelContext, candidateId: candidate.node.id)
        return DiagnosisAdvance(
            step: .probeOffer(offer), state: state,
            events: [.graphPrerequisiteReturned, .diagnosisHypothesisFormed], itemResult: nil,
            probeResult: nil)
    }

    /// A `DiagnosisContext` copy with the given fields overridden and `appendingEvents` appended to
    /// `events` — `DiagnosisContext` exposes no constructor outside the module, so every field must be
    /// threaded through explicitly on every change.
    private static func updatedContext(
        _ context: DiagnosisContext, level: Int? = nil, depthReached: Int? = nil,
        blockedNodeIds: [String]? = nil, probeResults: [ItemResult]? = nil,
        appendingEvents: [CoreEvent] = []
    ) -> DiagnosisContext {
        DiagnosisContext(
            event: context.event, level: level ?? context.level,
            depthReached: depthReached ?? context.depthReached,
            originErrorTypeId: context.originErrorTypeId, shownItemIdsInRun: context.shownItemIdsInRun,
            blockedNodeIds: blockedNodeIds ?? context.blockedNodeIds,
            probeResults: probeResults ?? context.probeResults, events: context.events + appendingEvents)
    }
}

import Foundation

/// Returned by every façade call except `answerProbeItem`/`continueAfterProbeAnswer`.
public struct DoorADiagnosisAdvance: Equatable {
    public let screen: DoorADiagnosisScreen
    public let state: StudentState
    public let events: [CoreEvent]
}

/// Returned by `answerProbeItem` (I3): the just-answered item's card only. `pendingAdvance` and
/// `classifiedToken` carry no `public` modifier, so no field of this type yields the next screen — only
/// `DoorADiagnosisFlow.continueAfterProbeAnswer` does, and it changes no `StudentState`.
public struct DoorAProbeAnswerAdvance: Equatable {
    public let answerCard: DoorAnswerCardContent
    public let itemResult: ItemResult
    public let state: StudentState
    public let events: [CoreEvent]
    let pendingAdvance: DiagnosisAdvance
    let classifiedToken: String
}

/// The Door A façade over `DiagnosisRun`'s public step API (`contracts/interaction-contract.md` § 4).
/// Every function is a pure value transformation over `DiagnosisRun`'s already-Tier-0 output plus bundle
/// lookups — no adapter type, no confidence threshold, no Tier-1 fallback applies here (I2, I14).
public enum DoorADiagnosisFlow {
    public static func open(originNodeId: String, trigger: DiagnosisTrigger, levelBudget: Int)
        -> DiagnosisEvent
    {
        DiagnosisRun.open(originNodeId: originNodeId, trigger: trigger, levelBudget: levelBudget)
    }

    public static func start(
        event: DiagnosisEvent, misses: [ItemMiss], shownItemIdsInRun: Set<String>,
        state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance {
        let advance = DiagnosisRun.start(
            event: event, misses: misses, shownItemIdsInRun: shownItemIdsInRun, state: state,
            bundle: bundle)
        let classifiedToken = Classify.classify(misses)
        return DoorADiagnosisAdvance(
            screen: screen(for: advance, classifiedToken: classifiedToken, bundle: bundle),
            state: advance.state, events: advance.events)
    }

    public static func decideProbe(
        _ offer: ProbeOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance {
        let advance = DiagnosisRun.decideProbe(offer, accept: accept, state: state, bundle: bundle)
        return DoorADiagnosisAdvance(
            screen: screen(for: advance, classifiedToken: offer.context.originErrorTypeId, bundle: bundle),
            state: advance.state, events: advance.events)
    }

    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, state: StudentState, bundle: ContentBundle,
        today: CalendarDay
    ) -> DoorAProbeAnswerAdvance {
        let advance = DiagnosisRun.answerProbeItem(
            probe, submitted: submitted, state: state, bundle: bundle, today: today)
        guard let itemResult = advance.itemResult else {
            preconditionFailure(
                "DoorADiagnosisFlow.answerProbeItem: DiagnosisRun.answerProbeItem returned no itemResult")
        }
        let answerCard = DoorAnswerCardContent(result: itemResult, itemType: probe.currentItem.type)
        return DoorAProbeAnswerAdvance(
            answerCard: answerCard, itemResult: itemResult, state: advance.state, events: advance.events,
            pendingAdvance: advance, classifiedToken: probe.context.originErrorTypeId)
    }

    public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, bundle: ContentBundle)
        -> DoorADiagnosisScreen
    {
        screen(for: pending.pendingAdvance, classifiedToken: pending.classifiedToken, bundle: bundle)
    }

    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, state: StudentState, bundle: ContentBundle
    ) -> DoorADiagnosisAdvance {
        let advance = DiagnosisRun.decideFurtherLevel(offer, accept: accept, state: state, bundle: bundle)
        return DoorADiagnosisAdvance(
            screen: screen(for: advance, classifiedToken: offer.context.originErrorTypeId, bundle: bundle),
            state: advance.state, events: advance.events)
    }

    // MARK: - Screen derivation (private: never called except from the entry points above)

    private static func screen(
        for advance: DiagnosisAdvance, classifiedToken: String, bundle: ContentBundle
    ) -> DoorADiagnosisScreen {
        switch advance.step {
        case .probeOffer(let offer):
            let name = nodeName(offer.candidateId, bundle: bundle)
            return .hypothesis(
                content: DoorAHypothesisContent(
                    line: DoorADiagnosisCopy.hypothesisLine(candidateNodeName: name),
                    costLine: DoorADiagnosisCopy.costLine),
                offer: offer)
        case .probeItem(let probe):
            let content = DoorItemContent(nodeId: probe.candidateId, item: probe.currentItem, isRetry: false)
            return .probeItem(content: content, probe: probe)
        case .furtherLevelOffer(let offer):
            let candidate = node(offer.candidateId, bundle: bundle)
            let remediation = DoorADiagnosisContentBuilder.selectRemediation(
                candidate: candidate, misses: offer.misses)
            let offerContent = DoorAFurtherLevelOfferContent(
                candidateNodeName: candidate.name, question: DoorADiagnosisCopy.furtherLevelQuestion)
            return .furtherLevelOffer(remediation: remediation, offer: offerContent, decision: offer)
        case .returned(let outcome):
            return .terminal(
                terminalContent(
                    outcome: outcome, advance: advance, classifiedToken: classifiedToken, bundle: bundle))
        }
    }

    private static func terminalContent(
        outcome: DiagnosisOutcome, advance: DiagnosisAdvance, classifiedToken: String,
        bundle: ContentBundle
    ) -> DoorATerminalContent {
        let hint: DoorAHintContent? = outcome.hintNodeId.map {
            DoorADiagnosisContentBuilder.resolveHint(
                node: node($0, bundle: bundle), classifiedToken: classifiedToken)
        }
        let remediation: DoorARemediationContent? = {
            guard let probeResult = advance.probeResult, probeResult.outcome == .confirmed,
                let candidateId = probeResult.results.first?.nodeId
            else { return nil }
            return DoorADiagnosisContentBuilder.selectRemediation(
                candidate: node(candidateId, bundle: bundle), misses: probeResult.misses)
        }()
        let line: String? = {
            switch outcome.terminal {
            case .refuted: return DoorADiagnosisCopy.refutedLine
            case .capped: return DoorADiagnosisCopy.cappedLine
            case .noPrerequisite: return CoreErrorText.text(for: .diagNoPrerequisite)
            case .unconfirmed: return outcome.code.flatMap { CoreErrorText.text(for: $0) }
            case .confirmed: return nil
            }
        }()
        return DoorATerminalContent(
            terminal: outcome.terminal, line: line, hint: hint, remediation: remediation, outcome: outcome)
    }

    private static func node(_ id: String, bundle: ContentBundle) -> Node {
        guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
            preconditionFailure("DoorADiagnosisFlow: node \(id) not found in bundle")
        }
        return match
    }

    private static func nodeName(_ id: String, bundle: ContentBundle) -> String {
        node(id, bundle: bundle).name
    }
}

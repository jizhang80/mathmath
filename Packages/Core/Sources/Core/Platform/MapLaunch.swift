import Foundation

/// The App's one handle onto a live map: everything a façade action needs, and everything the render layer may
/// read. Never called "session" (glossary rule, `docs/plans/epic-03-plan.md` planner note). Replaced wholesale
/// by the App's `@Observable` holder after every façade call — never partially mutated by App code.
public struct MapState {
    public let bundle: ContentBundle
    public let stateURL: URL
    public let state: StudentState
    public let viewModel: MapViewModel
    /// Q-D: the one in-memory "Include" queue slot. Never written to `stateURL`; absent from every
    /// `StudentState` field (`StudentState`'s schema has no queue key — adding one would be a data-model BUMP).
    public let queuedNodeId: String?
}

/// `MapLaunch.open`'s result. `messages` are registry code strings (e.g. `"PLATFORM_STATE_UNREADABLE"`), never
/// resolved text — 03.11's later call to `CoreErrorText.userText` resolves them (arbiter-03 § Q-F: "computed
/// here, as registry codes").
public enum LaunchOutcome {
    case ready(map: MapState, messages: [String], events: [CoreEvent])
    case courseSelectionNeeded(bundle: ContentBundle, messages: [String], events: [CoreEvent])
    case refused(BundleRefusal)
}

/// The App-launch entry point (map W1, expedition W7). Composes `BundleLoader.load` (03.4),
/// `StudentStateStore.read` (03.5), W7 reconciliation (`MarkerTrail.reconcileMarker` /
/// `.reconcileNodeIds`) and `MapViewModel.derive` (03.6) into one of three `LaunchOutcome`s. No graph,
/// layout, L0 or marker logic of its own (I14).
public enum MapLaunch {
    public static func open(snapshotDir: URL, stateURL: URL, today: CalendarDay) -> LaunchOutcome {
        let bundle: ContentBundle
        do {
            (bundle, _) = try BundleLoader.load(from: snapshotDir)
        } catch let refusal as BundleRefusal {
            return .refused(refusal)
        } catch {
            // BundleLoader.load's only documented throw type is BundleRefusal (03.4 §3); this branch exists
            // only as a defensive, never-exercised fallback and is asserted unreachable by §5 T2.
            return .refused(BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil))
        }

        let readResult: StudentStateStore.ReadResult
        var events: [CoreEvent] = [.platformLaunched]
        do {
            let (result, readEvents) = try StudentStateStore.read(at: stateURL)
            readResult = result
            events += readEvents
        } catch {
            return .courseSelectionNeeded(
                bundle: bundle, messages: ["PLATFORM_STATE_UNREADABLE"], events: events)
        }

        guard case .loaded(let loadedState, _) = readResult else {
            return .courseSelectionNeeded(bundle: bundle, messages: [], events: events)
        }

        let markerRecon = MarkerTrail.reconcileMarker(
            loadedState.marker, syllabi: loadedState.syllabi, bundle: bundle)
        if markerRecon.code == .mapMarkerOffTrail && markerRecon.marker == loadedState.marker {
            // Q-A precision 2: no course in syllabi[] resolves — no default marker to fall back to.
            return .courseSelectionNeeded(bundle: bundle, messages: [], events: events)
        }

        var effectiveState = loadedState
        if markerRecon.marker != loadedState.marker {
            // Q-A precision 3: in-memory only — never written back to stateURL by this function.
            if let report = try? MarkerTrail.generateTrail(
                syllabi: loadedState.syllabi, marker: markerRecon.marker, bundle: bundle)
            {
                effectiveState = StudentState(
                    schemaVersion: loadedState.schemaVersion,
                    formatVersionSeen: loadedState.formatVersionSeen,
                    syllabi: loadedState.syllabi, marker: markerRecon.marker, nodes: loadedState.nodes,
                    trail: report.trail, expeditionLog: loadedState.expeditionLog,
                    probeLog: loadedState.probeLog, installDay: loadedState.installDay,
                    consentOn: loadedState.consentOn)
            }
        }
        // reconcileNodeIds: ignored ids stay in effectiveState.nodes unchanged (W7: "kept … never deleted");
        // its .expNodeNotInGraph code, like .mapMarkerOffTrail, never enters `messages` on the load path
        // (§6 decision default — the same silent-load-path treatment, since W7 names no student-facing text
        // for it either).
        _ = MarkerTrail.reconcileNodeIds(nodes: effectiveState.nodes, bundle: bundle)

        let viewModel = MapViewModel.derive(bundle: bundle, state: effectiveState, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: effectiveState, viewModel: viewModel,
            queuedNodeId: nil)
        return .ready(map: map, messages: [], events: events + [.mapOpened])
    }
}

// MARK: - Panel content (map W2, W3, W4; no state mutation, no persistence)

public struct ExpectationCodeLink: Equatable {
    public let courseCode: String
    public let code: String
    public let officialUrl: String
}
public struct NodePanelContent: Equatable {
    public let nodeId: String
    public let name: String
    public let paraphrase: String
    public let expectationCodeLinks: [ExpectationCodeLink]
    public let masteryLabel: String
    public let courseCodesCrossingHere: [String]
    public let landmarkIds: [String]
}
public struct RegionPanelContent: Equatable {
    public let regionId: RegionId
    public let name: String
    public let about: String
    public let clearedFraction: Double?
    public let courseCodesCrossingHere: [String]
}
public struct LandmarkPanelContent: Equatable {
    public let landmarkId: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
}

/// The map-actions façade: panel content (map W2/W3/W4), `selectCourse`/`setMarker` (state-changing,
/// persisted after every call), and the hand-off actions `include`/`unitExpedition`/`checkHere`
/// (no persistence). Every entry point takes values and returns (new value, `[CoreEvent]`) or throws a
/// `CoreError` (arbiter-03 § Q-F). No graph, layout, L0, marker, fringe or diagnosis logic of its own —
/// every value comes from `BundleLoader`/`StudentStateStore`/`MapViewModel`/`MarkerTrail`/`Expedition`/
/// `DiagnosisRun`'s already-public entry points.
public enum MapFacade {
    public static func nodePanelContent(
        nodeId: String, mapState: MapState
    ) -> (content: NodePanelContent, events: [CoreEvent])? {
        guard let node = mapState.bundle.nodes.nodes.first(where: { $0.id == nodeId }),
            let nodeView = mapState.viewModel.nodes.first(where: { $0.id == nodeId })
        else { return nil }

        let links = (node.expectationCodes ?? []).compactMap { entry -> ExpectationCodeLink? in
            guard
                let course = mapState.bundle.courses.courses.first(where: {
                    $0.courseCode == entry.courseCode
                }),
                let expectation = course.expectations.first(where: { $0.code == entry.code })
            else { return nil }
            return ExpectationCodeLink(
                courseCode: entry.courseCode, code: entry.code, officialUrl: expectation.officialUrl)
        }
        let masteryLabel: String
        switch nodeView.fogLevel {
        case .fog: masteryLabel = "under fog"
        case .cleared: masteryLabel = "cleared"
        case .blocked: masteryLabel = "blocked — something upstream is in the way"
        }
        let courseCodes = mapState.state.trail.segments
            .filter { $0.kind == .course && $0.nodeIds.contains(nodeId) }
            .compactMap(\.courseCode)
        let landmarkIds = mapState.bundle.landmarks.landmarks
            .filter { $0.nodeIds.contains(nodeId) }.map(\.id)

        let content = NodePanelContent(
            nodeId: nodeId, name: node.name, paraphrase: node.paraphrase, expectationCodeLinks: links,
            masteryLabel: masteryLabel, courseCodesCrossingHere: courseCodes, landmarkIds: landmarkIds)
        return (content, [.mapNodeOpened])
    }

    public static func regionPanelContent(
        regionId: RegionId, mapState: MapState
    ) -> (content: RegionPanelContent, events: [CoreEvent])? {
        guard let region = mapState.bundle.regions.regions.first(where: { $0.id == regionId }),
            !region.horizon,
            let regionView = mapState.viewModel.regions.first(where: { $0.id == regionId })
        else { return nil }

        let regionNodeIds = Set(mapState.bundle.nodes.nodes.filter { $0.regionId == regionId }.map(\.id))
        let courseCodes = mapState.state.trail.segments
            .filter { $0.kind == .course && !Set($0.nodeIds).isDisjoint(with: regionNodeIds) }
            .compactMap(\.courseCode)

        let content = RegionPanelContent(
            regionId: regionId, name: region.name, about: region.about,
            clearedFraction: regionView.clearedFraction, courseCodesCrossingHere: courseCodes)
        return (content, [.mapRegionOpened])
    }

    public static func landmarkPanelContent(
        landmarkId: String, mapState: MapState
    ) -> (content: LandmarkPanelContent, events: [CoreEvent])? {
        guard let landmark = mapState.bundle.landmarks.landmarks.first(where: { $0.id == landmarkId }) else {
            return nil
        }
        let content = LandmarkPanelContent(
            landmarkId: landmark.id, name: landmark.name, whatItIs: landmark.whatItIs,
            sourceUrl: landmark.sourceUrl, nodeIds: landmark.nodeIds)
        return (content, [.mapLandmarkOpened])
    }

    // MARK: - selectCourse / setMarker (state-changing, persist every call)

    /// Q-E: `previousState == nil` builds the first `StudentState`; non-nil replaces `syllabi`/`marker`
    /// together and keeps `nodes` (mastery). Throws whatever `MarkerTrail.generateTrail` or
    /// `StudentStateStore.write` throws — on any throw, no `MapState` is returned (§6 decision default:
    /// atomic, all-or-nothing).
    public static func selectCourse(
        courseCode: String, bundle: ContentBundle, stateURL: URL, previousState: StudentState?,
        today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent]) {
        guard let marker = MarkerTrail.defaultMarker(syllabi: [courseCode], bundle: bundle) else {
            // Never reached in the Demo: the App's course picker only offers courses present in `bundle
            // .courses.courses` (§6 decision default — a programmer-error precondition, not a student path).
            throw CoreError.expTrailInvalid
        }
        let report = try MarkerTrail.generateTrail(syllabi: [courseCode], marker: marker, bundle: bundle)
        let newState = StudentState(
            schemaVersion: 2, formatVersionSeen: bundle.manifest.formatVersion, syllabi: [courseCode],
            marker: marker, nodes: previousState?.nodes ?? [:], trail: report.trail,
            expeditionLog: previousState?.expeditionLog ?? [], probeLog: previousState?.probeLog ?? [],
            installDay: previousState?.installDay ?? today.iso, consentOn: previousState?.consentOn ?? true)
        let writeEvents = try StudentStateStore.write(newState, to: stateURL)
        let viewModel = MapViewModel.derive(bundle: bundle, state: newState, today: today)
        let map = MapState(
            bundle: bundle, stateURL: stateURL, state: newState, viewModel: viewModel, queuedNodeId: nil)
        return (map, writeEvents)
    }

    /// D45, map W5 / expedition W6. `unitId` is passed to `MarkerTrail.setMarker` unchanged. When
    /// `pastLastUnit` is `true`, `MarkerTrail.setMarker` (as corrected by task 02.5b) writes the course's last
    /// unit as `unit_id` (interaction-contract § 3). This façade never computes the last unit itself: one
    /// source, in expedition's `Core` function. Throws whatever `MarkerTrail.setMarker` or
    /// `StudentStateStore.write` throws; no `MapState` returned on failure.
    public static func setMarker(
        unitId: String, pastLastUnit: Bool, mapState: MapState, today: CalendarDay
    ) throws -> (map: MapState, events: [CoreEvent]) {
        let result = try MarkerTrail.setMarker(
            courseCode: mapState.state.marker.courseCode, unitId: unitId, pastLastUnit: pastLastUnit,
            syllabi: mapState.state.syllabi, bundle: mapState.bundle)
        let newState = StudentState(
            schemaVersion: mapState.state.schemaVersion, formatVersionSeen: mapState.state.formatVersionSeen,
            syllabi: mapState.state.syllabi, marker: result.marker, nodes: mapState.state.nodes,
            trail: result.trail, expeditionLog: mapState.state.expeditionLog,
            probeLog: mapState.state.probeLog, installDay: mapState.state.installDay,
            consentOn: mapState.state.consentOn)
        let writeEvents = try StudentStateStore.write(newState, to: mapState.stateURL)
        let viewModel = MapViewModel.derive(bundle: mapState.bundle, state: newState, today: today)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: newState, viewModel: viewModel,
            queuedNodeId: mapState.queuedNodeId)
        // Event order follows map W5's own sentence order: regenerate → persist → notify (§6 decision default).
        return (newMap, result.events + writeEvents + [.mapMarkerMoved])
    }

    // MARK: - include / unitExpedition / checkHere (hand-off actions, no persistence)

    public enum IncludeOutcome: Equatable { case queued, ignored }

    /// Q-D. Not persisted — `queuedNodeId` lives only on `MapState`, never in `StudentState`.
    public static func include(
        nodeId: String, mapState: MapState
    ) -> (map: MapState, outcome: IncludeOutcome, events: [CoreEvent]) {
        guard mapState.viewModel.nodes.first(where: { $0.id == nodeId })?.action == .include else {
            return (mapState, .ignored, [])
        }
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: mapState.state,
            viewModel: mapState.viewModel, queuedNodeId: nodeId)
        return (newMap, .queued, [.mapIncludeRequested])
    }

    /// D46. Delegates verbatim to `Expedition.compose(unitExpeditionUnitId:)` — no fringe/window logic of its
    /// own. Throws `CoreError.expNoFringe` when `compose` does.
    public static func unitExpedition(
        unitId: String, mapState: MapState, today: CalendarDay
    ) throws -> (result: ComposeResult, events: [CoreEvent]) {
        let result = try Expedition.compose(
            state: mapState.state, bundle: mapState.bundle, trail: mapState.state.trail,
            marker: mapState.state.marker, today: today, queuedNodeId: nil, unitExpeditionUnitId: unitId)
        return (result, [.mapUnitExpeditionRequested])
    }

    /// The Demo budget of 1 (interaction-contract § 4). `DiagnosisRun.open` is pure construction and never
    /// throws (arbiter-02-11 Ruling 1, 3) — this task calls no later step function.
    public static func checkHere(
        nodeId: String, mapState: MapState
    ) -> (event: DiagnosisEvent, events: [CoreEvent]) {
        let event = DiagnosisRun.open(originNodeId: nodeId, trigger: .mapCheckHere, levelBudget: 1)
        return (event, [.mapCheckHereRequested])
    }
}

// MARK: - Door entry points (task 04.5): the only surface 04b's screens call for Door B/A actions.

/// The App's one handle onto a live Door B expedition or Door A diagnosis, layered over `MapState`. Replaced
/// wholesale by the App's `@Observable` holder after every `DoorFacade` call (same discipline as `MapState`,
/// arbiter-03 § Q-F). `expedition` carries no `public` modifier: only `Core` code (this file, and this task's
/// own tests) inspects or constructs it directly — the App holds it opaquely and passes it back unmodified,
/// mirroring 04.3's/04.4's own "no field yields a screen" discipline applied here at the run-state level.
public struct DoorRunState {
    public let map: MapState
    let expedition: DoorBRunState?
}

public enum DoorFacade {
    // MARK: Persistence helpers (private)

    private static func persistExpeditionWrite(_ state: StudentState, to url: URL) -> String? {
        do {
            _ = try StudentStateStore.write(state, to: url)
            return nil
        } catch {
            return CoreError.expStateWriteFailed.rawValue
        }
    }

    private static func persistDiagnosisWrite(_ state: StudentState, to url: URL) -> String? {
        do {
            _ = try StudentStateStore.write(state, to: url)
            return nil
        } catch {
            return CoreError.diagStateWriteFailed.rawValue
        }
    }

    /// Q-G branch: write-ahead when a `DoorBRunState` is active, plain otherwise (`map_check_here` outside a
    /// run).
    private static func persistDoorA(
        _ state: StudentState, expedition: DoorBRunState?, url: URL, today: CalendarDay
    ) -> String? {
        let toWrite =
            expedition.map {
                DoorBWriteAhead.provisionalAbandonedState(runState: $0, state: state, today: today)
            } ?? state
        return persistDiagnosisWrite(toWrite, to: url)
    }

    private static func rebuiltMap(_ map: MapState, state: StudentState, today: CalendarDay) -> MapState {
        MapState(
            bundle: map.bundle, stateURL: map.stateURL, state: state,
            viewModel: MapViewModel.derive(bundle: map.bundle, state: state, today: today),
            queuedNodeId: map.queuedNodeId)
    }

    // MARK: Door B (expedition) entries

    /// AC1. Consumes and empties the Include queue.
    public static func startExpedition(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        let compose = try Expedition.compose(
            state: mapState.state, bundle: mapState.bundle, trail: mapState.state.trail,
            marker: mapState.state.marker, today: today, queuedNodeId: mapState.queuedNodeId,
            unitExpeditionUnitId: nil)
        let advance = DoorBExpeditionFlow.start(compose: compose)
        let ahead = DoorBWriteAhead.provisionalAbandonedState(
            runState: advance.runState, state: mapState.state, today: today)
        let failure = persistExpeditionWrite(ahead, to: mapState.stateURL)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: mapState.state,
            viewModel: mapState.viewModel, queuedNodeId: nil)
        let events = failure == nil ? [advance.event, .platformStateWritten] : [advance.event]
        return (
            DoorRunState(map: newMap, expedition: advance.runState), advance.screen, failure, events
        )
    }

    /// AC2. Delegates fringe scoping verbatim to `MapFacade.unitExpedition`; never touches `queuedNodeId`.
    public static func startUnitExpedition(unitId: String, mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        let (compose, composeEvents) = try MapFacade.unitExpedition(
            unitId: unitId, mapState: mapState, today: today)
        let advance = DoorBExpeditionFlow.start(compose: compose)
        let ahead = DoorBWriteAhead.provisionalAbandonedState(
            runState: advance.runState, state: mapState.state, today: today)
        let failure = persistExpeditionWrite(ahead, to: mapState.stateURL)
        let events =
            composeEvents + (failure == nil ? [advance.event, .platformStateWritten] : [advance.event])
        return (DoorRunState(map: mapState, expedition: advance.runState), advance.screen, failure, events)
    }

    /// AC4. Persists the final entry when the run naturally ends in this call, else the write-ahead value.
    public static func answer(_ runState: DoorRunState, submitted: String, today: CalendarDay)
        -> (advance: DoorBAnswerAdvance, runState: DoorRunState, writeFailureCode: String?)
    {
        guard let expedition = runState.expedition else {
            preconditionFailure("DoorFacade.answer called with no active expedition")
        }
        let advance = DoorBExpeditionFlow.answer(
            expedition, submitted: submitted, state: runState.map.state, bundle: runState.map.bundle,
            today: today)
        let toWrite =
            advance.pendingEnd?.state
            ?? DoorBWriteAhead.provisionalAbandonedState(
                runState: advance.runState, state: advance.state, today: today)
        let failure = persistExpeditionWrite(toWrite, to: runState.map.stateURL)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: advance.runState), failure)
    }

    /// AC4/AC5. No write — arbiter-04 § Q-A.
    public static func continueAfterAnswer(_ pending: DoorBAnswerAdvance, runState: DoorRunState)
        -> (screen: DoorBScreen, runState: DoorRunState)
    {
        let advance = DoorBExpeditionFlow.continueAfterAnswer(pending, bundle: runState.map.bundle)
        let newMap = MapState(
            bundle: runState.map.bundle, stateURL: runState.map.stateURL, state: advance.state,
            viewModel: runState.map.viewModel, queuedNodeId: runState.map.queuedNodeId)
        return (advance.screen, DoorRunState(map: newMap, expedition: advance.runState))
    }

    /// AC7. `resumeAfterDiagnosis` requires an in-run `DoorRunState` — never called for `map_check_here`.
    public static func resumeAfterDiagnosis(
        _ runState: DoorRunState, outcome: DiagnosisOutcome, today: CalendarDay
    ) -> (advance: DoorBResumeAdvance, runState: DoorRunState, writeFailureCode: String?) {
        guard let expedition = runState.expedition else {
            preconditionFailure("DoorFacade.resumeAfterDiagnosis called with no active expedition")
        }
        let advance = DoorBExpeditionFlow.resumeAfterDiagnosis(
            expedition, outcome: outcome, bundle: runState.map.bundle, today: today)
        let toWrite: StudentState
        if case .summary = advance.screen {
            toWrite = advance.state  // already final (abandoned: false), computed inside resumeAfterDiagnosis
        } else {
            toWrite = DoorBWriteAhead.provisionalAbandonedState(
                runState: advance.runState, state: advance.state, today: today)
        }
        let failure = persistExpeditionWrite(toWrite, to: runState.map.stateURL)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: advance.runState), failure)
    }

    /// AC9. Identical to `startExpedition`, applied to the post-run `mapState` (§6).
    public static func startAnother(mapState: MapState, today: CalendarDay) throws
        -> (runState: DoorRunState, screen: DoorBScreen, writeFailureCode: String?, events: [CoreEvent])
    {
        try startExpedition(mapState: mapState, today: today)
    }

    /// AC10. Persists the final `abandoned: true` entry; ends the Door B run.
    public static func backToMap(_ runState: DoorRunState, today: CalendarDay)
        -> (mapState: MapState, writeFailureCode: String?)
    {
        guard let expedition = runState.expedition else { return (runState.map, nil) }
        let end = ExpeditionRun.end(
            run: expedition.run, state: runState.map.state, today: today, abandoned: true)
        let failure = persistExpeditionWrite(end.state, to: runState.map.stateURL)
        return (rebuiltMap(runState.map, state: end.state, today: today), failure)
    }
}

// MARK: - Door A (diagnosis) entries

extension DoorFacade {
    /// AC8. Opens a standalone diagnosis event (no expedition run). `runState.expedition` stays `nil` for this
    /// event's whole life. `today` is used only by `persistDoorA` (§4.2) — `MapFacade.checkHere` itself takes
    /// no `today` parameter.
    public static func checkHere(nodeId: String, mapState: MapState, today: CalendarDay)
        -> (
            runState: DoorRunState, screen: DoorADiagnosisScreen, writeFailureCode: String?,
            events: [CoreEvent]
        )
    {
        let (event, mapEvents) = MapFacade.checkHere(nodeId: nodeId, mapState: mapState)
        let advance = DoorADiagnosisFlow.start(
            event: event, misses: [], shownItemIdsInRun: [], state: mapState.state, bundle: mapState.bundle)
        let failure = persistDoorA(advance.state, expedition: nil, url: mapState.stateURL, today: today)
        let newMap = MapState(
            bundle: mapState.bundle, stateURL: mapState.stateURL, state: advance.state,
            viewModel: mapState.viewModel, queuedNodeId: mapState.queuedNodeId)
        return (
            DoorRunState(map: newMap, expedition: nil), advance.screen, failure, mapEvents + advance.events
        )
    }

    /// AC6. Write-ahead-wrapped when in-run, plain otherwise.
    public static func decideProbe(
        _ offer: ProbeOffer, accept: Bool, runState: DoorRunState, today: CalendarDay
    )
        -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?)
    {
        let advance = DoorADiagnosisFlow.decideProbe(
            offer, accept: accept, state: runState.map.state, bundle: runState.map.bundle)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }

    public static func answerProbeItem(
        _ probe: ProbeInProgress, submitted: String, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorAProbeAnswerAdvance, runState: DoorRunState, writeFailureCode: String?) {
        let advance = DoorADiagnosisFlow.answerProbeItem(
            probe, submitted: submitted, state: runState.map.state, bundle: runState.map.bundle, today: today)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }

    /// No write — mirrors `continueAfterAnswer` (04.3 AC3: "changes no `StudentState`").
    public static func continueAfterProbeAnswer(_ pending: DoorAProbeAnswerAdvance, runState: DoorRunState)
        -> DoorADiagnosisScreen
    {
        DoorADiagnosisFlow.continueAfterProbeAnswer(pending, bundle: runState.map.bundle)
    }

    public static func decideFurtherLevel(
        _ offer: FurtherLevelOffer, accept: Bool, runState: DoorRunState, today: CalendarDay
    ) -> (advance: DoorADiagnosisAdvance, runState: DoorRunState, writeFailureCode: String?) {
        let advance = DoorADiagnosisFlow.decideFurtherLevel(
            offer, accept: accept, state: runState.map.state, bundle: runState.map.bundle)
        let failure = persistDoorA(
            advance.state, expedition: runState.expedition, url: runState.map.stateURL, today: today)
        let newMap = rebuiltMap(runState.map, state: advance.state, today: today)
        return (advance, DoorRunState(map: newMap, expedition: runState.expedition), failure)
    }
}

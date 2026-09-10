import Foundation
import Testing

@testable import Core

/// Tester's supplementary coverage for `ExpeditionRun` (`Sources/Core/State/ExpeditionRun.swift`), written
/// against `tasks/epic-02-task-07-item-checker-expedition-run.md`. This file does NOT re-verify AC5-AC13
/// (the implementer's own `ExpeditionRunTests.swift` already owns that ground) — it targets gaps left
/// open:
///  - `EXP_ITEM_POOL_EMPTY` retry skip-and-continue (`docs/epics/epic-02-core-behaviour.md` § 9 technical
///    default: "No unused item for a D27 retry -> skip the retry, log EXP_ITEM_POOL_EMPTY, continue the
///    run") — untested by the implementer's own suite, which never drives a node down to an empty retry
///    pool;
///  - `probe_log` entries' own field-level content (day/node/item/correct/retry), asserted directly rather
///    than only through downstream mastery-transition effects;
///  - the resume hand-off's full contract: `resume(run:)` takes no `StudentState`, and a diagnosis's own
///    effect on `StudentState` (simulating what 02.11 would produce) survives, unmodified by
///    `ExpeditionRun`, into the very next `answer` call — the "post-diagnosis mastery reaches the run via
///    the StudentState threaded into the next answer call" contract text;
///  - the missing T5 regression guard named explicitly in this task's own § 5 ("Guard: diagnosisUsed is
///    monotone... reconstruct a variant that resets it to false after resume and show a second diagnosis
///    event becomes reachable") — absent from the implementer's `ExpeditionRunTests.swift`;
///  - a `missCounts` property bound reinforcing "never more than one retry outstanding" (AC12's own text)
///    across a full generated run.
@Suite("ExpeditionRun — boundary and gap coverage")
struct ExpeditionRunBoundaryTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var demoBundleDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    private static func today(_ iso: String = "2026-09-10") -> CalendarDay {
        guard let day = CalendarDay(iso: iso) else {
            preconditionFailure("\(iso) must be a valid CalendarDay")
        }
        return day
    }

    private static func state(nodes: [String: NodeState], probeLog: [ProbeLogEntry] = []) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: "0.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: false), nodes: nodes,
            trail: Trail(segments: []), expeditionLog: [], probeLog: probeLog, installDay: "2026-01-01",
            consentOn: true)
    }

    private static func probeItem(bundle: ContentBundle, nodeId: String, itemId: String) throws
        -> ProbeItem
    {
        let node = try #require(bundle.nodes.nodes.first(where: { $0.id == nodeId }))
        return try #require(node.probeItems.first(where: { $0.id == itemId }))
    }

    /// A bundle identical to real `data/demo` except that `nodeId`'s node carries only its first
    /// `probeItems` entry — a legitimate (if artificial) bundle shape used solely to force `selectItem`'s
    /// candidate pool to empty on a D27 retry, since every real `data/demo` node ships exactly 2 items
    /// (never an empty retry pool on its own).
    private static func bundleWithSingleItemNode(_ bundle: ContentBundle, nodeId: String) throws
        -> ContentBundle
    {
        let original = try #require(bundle.nodes.nodes.first(where: { $0.id == nodeId }))
        let trimmed = Node(
            id: original.id, name: original.name, regionId: original.regionId, strand: original.strand,
            expectationCodes: original.expectationCodes, sourceRef: original.sourceRef,
            courses: original.courses, position: original.position, layoutHint: original.layoutHint,
            paraphrase: original.paraphrase, explanation: original.explanation,
            workedExamples: original.workedExamples, errorTypes: original.errorTypes,
            hintTree: original.hintTree, probeItems: [try #require(original.probeItems.first)])
        let trimmedNodesFile = NodesFile(
            formatVersion: bundle.nodes.formatVersion,
            nodes: bundle.nodes.nodes.map { $0.id == nodeId ? trimmed : $0 })
        return ContentBundle(
            manifest: bundle.manifest, regions: bundle.regions, nodes: trimmedNodesFile,
            edges: bundle.edges, courses: bundle.courses, landmarks: bundle.landmarks,
            sources: bundle.sources)
    }

    // MARK: - T1 gap: EXP_ITEM_POOL_EMPTY skip-and-continue

    @Test("A first miss with no unused retry item records EXP_ITEM_POOL_EMPTY and continues the run")
    func firstMissWithEmptyRetryPoolSkipsAndContinues() throws {
        let bundle = try Self.loadDemoBundle()
        let trimmedBundle = try Self.bundleWithSingleItemNode(bundle, nodeId: "exponent-laws")
        let onlyItem = try Self.probeItem(
            bundle: trimmedBundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let compose = ComposeResult(
            slots: [ComposeSlot(nodeId: "exponent-laws", item: onlyItem, kind: .newLearning)],
            skippedNodeIds: [])
        let run0 = ExpeditionRun.start(compose: compose).run
        let state0 = Self.state(nodes: [:])

        let outcome = ExpeditionRun.answer(
            run: run0, state: state0, bundle: trimmedBundle, submitted: "5", today: Self.today())

        // No unused item exists for a retry (the trimmed node has exactly one item, now `shownItemIds`),
        // so the run skips the retry rather than opening a diagnosis or crashing.
        #expect(outcome.run.itemPoolEmptyNodeIds == ["exponent-laws"])
        #expect(outcome.run.missCounts["exponent-laws"] == 1)
        #expect(outcome.run.currentItem == nil)  // queue was empty; the run naturally ends
        #expect(outcome.run.suspendedForDiagnosisNodeId == nil)
        #expect(outcome.run.diagnosisUsed == false)
        #expect(outcome.events == [.expeditionItemAnswered])
    }

    @Test("EXP_ITEM_POOL_EMPTY skip advances to the next queued item rather than stalling the run")
    func emptyRetryPoolAdvancesQueue() throws {
        let bundle = try Self.loadDemoBundle()
        let trimmedBundle = try Self.bundleWithSingleItemNode(bundle, nodeId: "exponent-laws")
        let onlyItem = try Self.probeItem(
            bundle: trimmedBundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let polynomialsItem = try Self.probeItem(
            bundle: trimmedBundle, nodeId: "polynomials", itemId: "polynomials-1")
        let compose = ComposeResult(
            slots: [
                ComposeSlot(nodeId: "exponent-laws", item: onlyItem, kind: .newLearning),
                ComposeSlot(nodeId: "polynomials", item: polynomialsItem, kind: .newLearning),
            ], skippedNodeIds: [])
        let run0 = ExpeditionRun.start(compose: compose).run
        let state0 = Self.state(nodes: [:])

        let outcome = ExpeditionRun.answer(
            run: run0, state: state0, bundle: trimmedBundle, submitted: "5", today: Self.today())

        #expect(outcome.run.itemPoolEmptyNodeIds == ["exponent-laws"])
        #expect(outcome.run.currentItem?.nodeId == "polynomials")
        #expect(outcome.run.currentItem?.isRetry == false)
    }

    // MARK: - T1 gap: probe_log field-level content

    @Test("Every answer appends a ProbeLogEntry with the exact day/node/item/correct/retry it was shown with")
    func probeLogEntriesCarryExactFields() throws {
        let bundle = try Self.loadDemoBundle()
        let today = Self.today("2026-09-11")
        let item1 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let item2 = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-2")
        let compose = ComposeResult(
            slots: [ComposeSlot(nodeId: "exponent-laws", item: item1, kind: .newLearning)],
            skippedNodeIds: [])
        let run0 = ExpeditionRun.start(compose: compose).run
        let state0 = Self.state(nodes: [:])

        let missOutcome = ExpeditionRun.answer(
            run: run0, state: state0, bundle: bundle, submitted: "5", today: today)
        let missEntry = try #require(missOutcome.state.probeLog.last)
        #expect(missEntry.day == today.iso)
        #expect(missEntry.nodeId == "exponent-laws")
        #expect(missEntry.itemId == item1.id)
        #expect(missEntry.correct == false)
        #expect(missEntry.retry == false)

        // `exponent-laws-2` (the item `selectItem` draws for the retry) is the node's `mc` item; its
        // correct choice id is `"a"` (`data/demo/nodes.json`).
        let retryOutcome = ExpeditionRun.answer(
            run: missOutcome.run, state: missOutcome.state, bundle: bundle, submitted: "a", today: today)
        let retryEntry = try #require(retryOutcome.state.probeLog.last)
        #expect(retryEntry.day == today.iso)
        #expect(retryEntry.nodeId == "exponent-laws")
        #expect(retryEntry.itemId == item2.id)
        #expect(retryEntry.correct == true)
        #expect(retryEntry.retry == true)
        // The miss entry from the first item is preserved unmodified (append-only).
        #expect(retryOutcome.state.probeLog.count == 2)
        #expect(retryOutcome.state.probeLog.first == missEntry)
    }

    // MARK: - T1 gap: resume hand-off / post-diagnosis StudentState threading

    @Test(
        "resume(run:) takes no StudentState; a diagnosis's own StudentState effect survives into the next answer call"
    )
    func diagnosisEffectOnStudentStateThreadsThroughResume() throws {
        let bundle = try Self.loadDemoBundle()
        let today = Self.today()
        let fogItem = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let retryItem = try Self.probeItem(
            bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-2")
        let polynomialsItem = try Self.probeItem(
            bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1")
        let compose = ComposeResult(
            slots: [
                ComposeSlot(nodeId: "exponent-laws", item: fogItem, kind: .newLearning),
                ComposeSlot(nodeId: "polynomials", item: polynomialsItem, kind: .newLearning),
            ], skippedNodeIds: [])
        let run0 = ExpeditionRun.start(compose: compose).run
        let state0 = Self.state(nodes: [:])

        let firstMiss = ExpeditionRun.answer(
            run: run0, state: state0, bundle: bundle, submitted: "5", today: today)
        #expect(firstMiss.run.currentItem?.item.id == retryItem.id)
        let secondMiss = ExpeditionRun.answer(
            run: firstMiss.run, state: firstMiss.state, bundle: bundle, submitted: "b", today: today)
        #expect(secondMiss.run.suspendedForDiagnosisNodeId == "exponent-laws")

        // Simulate 02.11's own effect: diagnosis marks `exponent-laws` remediated (its own state-machine
        // output), producing a NEW StudentState value this run's own code never sees or mutates.
        let remediatedNode = NodeState(
            mastery: .fog, correctCount: 0, lastProbe: today.iso, nextDue: nil, ladderRung: 0,
            remediated: true)
        var diagnosisNodes = secondMiss.state.nodes
        diagnosisNodes["exponent-laws"] = remediatedNode
        let diagnosisState = StudentState(
            schemaVersion: secondMiss.state.schemaVersion,
            formatVersionSeen: secondMiss.state.formatVersionSeen, syllabi: secondMiss.state.syllabi,
            marker: secondMiss.state.marker, nodes: diagnosisNodes, trail: secondMiss.state.trail,
            expeditionLog: secondMiss.state.expeditionLog, probeLog: secondMiss.state.probeLog,
            installDay: secondMiss.state.installDay, consentOn: secondMiss.state.consentOn)

        // `resume` takes only `run:` — no StudentState parameter exists to thread the diagnosis's effect
        // through directly; the caller must carry `diagnosisState` itself into the next `answer` call.
        let resumed = ExpeditionRun.resume(run: secondMiss.run)
        #expect(resumed.currentItem?.nodeId == "polynomials")

        let next = ExpeditionRun.answer(
            run: resumed, state: diagnosisState, bundle: bundle, submitted: "3", today: today)
        // The diagnosis's own effect on `exponent-laws` is untouched by this run's own `answer` call
        // (which only ever writes `nodes[current.nodeId]`, here "polynomials") — it survives into the next
        // returned StudentState exactly as the diagnosis produced it.
        #expect(next.state.nodes["exponent-laws"]?.remediated == true)
        #expect(next.state.nodes["exponent-laws"]?.mastery == .fog)
    }

    // MARK: - T5 negative control: diagnosisUsed monotonicity (required by this task's own § 5)

    @Test("Guard: diagnosisUsed must never reset to false, or a second diagnosis becomes reachable")
    func guardDiagnosisUsedMonotonicity() throws {
        let bundle = try Self.loadDemoBundle()
        let today = Self.today()
        let expItem = try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1")
        let polyItem = try Self.probeItem(bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1")
        let compose = ComposeResult(
            slots: [
                ComposeSlot(nodeId: "exponent-laws", item: expItem, kind: .newLearning),
                ComposeSlot(nodeId: "polynomials", item: polyItem, kind: .newLearning),
            ], skippedNodeIds: [])
        let run0 = ExpeditionRun.start(compose: compose).run
        let state0 = Self.state(nodes: [:])

        let firstMiss = ExpeditionRun.answer(
            run: run0, state: state0, bundle: bundle, submitted: "5", today: today)
        let secondMiss = ExpeditionRun.answer(
            run: firstMiss.run, state: firstMiss.state, bundle: bundle, submitted: "b", today: today)
        #expect(secondMiss.run.diagnosisUsed == true)
        let resumed = ExpeditionRun.resume(run: secondMiss.run)

        // The real, unbroken flow: a second node's second miss, with diagnosisUsed genuinely true, blocks
        // rather than opening a second diagnosis (AC9's own ground, re-confirmed here as the "fixed shape"
        // half of this guard's negative control).
        let realFirstMiss = ExpeditionRun.answer(
            run: resumed, state: secondMiss.state, bundle: bundle, submitted: "3", today: today)
        let realSecondMiss = ExpeditionRun.answer(
            run: realFirstMiss.run, state: realFirstMiss.state, bundle: bundle, submitted: "b",
            today: today)
        #expect(realSecondMiss.run.suspendedForDiagnosisNodeId == nil)
        #expect(!realSecondMiss.events.contains(.expeditionDiagnosisRequested))

        // The "broken shape": a variant that resets `diagnosisUsed` to false right after `resume` (exactly
        // the defect this guard exists to catch — e.g. a caller bug or a future edit that mishandles the
        // suspend/resume hand-off). Because `ExpeditionRunState`'s fields are `public var` (§6 "Value-type
        // mutation style"), this reconstruction is possible in test code even though the real production
        // code path never performs it.
        var brokenResumed = resumed
        brokenResumed.diagnosisUsed = false

        let brokenFirstMiss = ExpeditionRun.answer(
            run: brokenResumed, state: secondMiss.state, bundle: bundle, submitted: "3", today: today)
        let brokenSecondMiss = ExpeditionRun.answer(
            run: brokenFirstMiss.run, state: brokenFirstMiss.state, bundle: bundle, submitted: "b",
            today: today)
        // Under the broken (reset) shape, a second diagnosis wrongly becomes reachable — proving the real
        // implementation's monotonicity (never resetting `diagnosisUsed`) is load-bearing for "at most one
        // diagnosis per run".
        #expect(brokenSecondMiss.run.suspendedForDiagnosisNodeId == "polynomials")
        #expect(brokenSecondMiss.events.contains(.expeditionDiagnosisRequested))
    }

    // MARK: - T4 conformance: missCounts property bound (AC12's "never more than one retry outstanding")

    @Test("Property: no node's missCounts ever exceeds 2 across a full generated run (at most one retry)")
    func missCountsNeverExceedTwo() throws {
        let bundle = try Self.loadDemoBundle()
        let today = Self.today()
        let items = [
            try Self.probeItem(bundle: bundle, nodeId: "exponent-laws", itemId: "exponent-laws-1"),
            try Self.probeItem(bundle: bundle, nodeId: "polynomials", itemId: "polynomials-1"),
            try Self.probeItem(
                bundle: bundle, nodeId: "simplifying-expressions", itemId: "simplifying-expressions-1"),
        ]
        let nodeIds = ["exponent-laws", "polynomials", "simplifying-expressions"]
        let compose = ComposeResult(
            slots: zip(nodeIds, items).map { ComposeSlot(nodeId: $0, item: $1, kind: .newLearning) },
            skippedNodeIds: [])

        var gen = SeededGenerator(seed: 314)
        for _ in 0..<100 {
            let outcomes = PropertyGen.outcomeSequence(&gen, count: 8, correctWeight: 0.3)
            var run = ExpeditionRun.start(compose: compose).run
            var state = Self.state(nodes: [:])
            var outcomeIndex = 0
            var steps = 0
            while (run.currentItem != nil || run.suspendedForDiagnosisNodeId != nil), steps < 100 {
                steps += 1
                if let current = run.currentItem {
                    let correct = outcomeIndex < outcomes.count ? outcomes[outcomeIndex] : true
                    outcomeIndex += 1
                    let submitted: String
                    if correct {
                        submitted =
                            current.item.type == .numeric
                            ? (current.item.answer?.value ?? "0") : (current.item.correctChoiceId ?? "")
                    } else {
                        submitted =
                            current.item.type == .numeric
                            ? (current.item.wrongAnswers?.first?.value ?? "no-such-value")
                            : (current.item.choices?.first(where: { $0.id != current.item.correctChoiceId })?
                                .id ?? "no-such-choice")
                    }
                    let outcome = ExpeditionRun.answer(
                        run: run, state: state, bundle: bundle, submitted: submitted, today: today)
                    run = outcome.run
                    state = outcome.state
                } else {
                    run = ExpeditionRun.resume(run: run)
                }
                for (_, count) in run.missCounts {
                    #expect(count <= 2, "no node should accumulate more than one retry (missCount <= 2)")
                }
            }
        }
    }
}

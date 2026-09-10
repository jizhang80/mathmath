import Foundation
import Testing

@testable import Core

/// `StateMerge.merge`/`canonicalise` (`contracts/data-model.md` v1.4.0 § StudentState merge (platform Q3)).
/// AC1-AC12, the algebraic-law property tests and every negative control (T1-T6).
@Suite("StateMerge")
struct StateMergeTests {
    private static let nodeIdPool = ["alpha-node", "beta-node", "gamma-node"]

    private static func today() -> CalendarDay {
        guard let day = CalendarDay(iso: "2026-09-10") else {
            preconditionFailure("2026-09-10 must be a valid CalendarDay")
        }
        return day
    }

    private static func node(
        mastery: Mastery,
        correctCount: Int = 0,
        lastProbe: String? = nil,
        nextDue: String? = nil,
        ladderRung: Int = 0,
        remediated: Bool? = nil
    ) -> NodeState {
        NodeState(
            mastery: mastery, correctCount: correctCount, lastProbe: lastProbe, nextDue: nextDue,
            ladderRung: ladderRung, remediated: remediated)
    }

    private static func trail(courseCode: String = "MTH1W", nodeIds: [String] = []) -> Trail {
        Trail(segments: [TrailSegment(kind: .course, courseCode: courseCode, nodeIds: nodeIds)])
    }

    private static func expLog(day: String) -> ExpeditionLogEntry {
        ExpeditionLogEntry(
            day: day, itemCount: 1, cleared: 0, blocked: 0, abandoned: false, diagnosisEvents: 0)
    }

    private static func state(
        marker: Marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil),
        nodes: [String: NodeState] = [:],
        trail: Trail = Trail(segments: [TrailSegment(kind: .course, courseCode: "MTH1W", nodeIds: [])]),
        expeditionLog: [ExpeditionLogEntry] = [],
        probeLog: [ProbeLogEntry] = [],
        installDay: String = "2026-01-01",
        formatVersionSeen: String = "1.0.0",
        consentOn: Bool = true
    ) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: formatVersionSeen, syllabi: [marker.courseCode],
            marker: marker, nodes: nodes, trail: trail, expeditionLog: expeditionLog, probeLog: probeLog,
            installDay: installDay, consentOn: consentOn)
    }

    /// Local copy of the merge rule's mastery rank (`cleared` > `blocked` > `fog`), for test-side
    /// assertions only — never used by product code.
    private static func masteryRank(_ mastery: Mastery) -> Int {
        switch mastery {
        case .fog: return 0
        case .blocked: return 1
        case .cleared: return 2
        }
    }

    private static func semverComponents(_ semver: String) -> [Int] {
        semver.split(separator: ".").map { Int($0) ?? 0 }
    }

    private static func semverGreaterOrEqual(_ lhs: String, _ rhs: String) -> Bool {
        !Self.semverComponents(lhs).lexicographicallyPrecedes(Self.semverComponents(rhs))
    }

    private static func expectedMultisetCount<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        var distinct: [T] = []
        for value in a + b where !distinct.contains(value) { distinct.append(value) }
        return distinct.reduce(0) { total, value in
            total + max(a.filter { $0 == value }.count, b.filter { $0 == value }.count)
        }
    }

    /// Identifier blocklist (mirrors `pipeline/tests/test_contracts.py::IDENTIFIER_BLOCKLIST`, per
    /// `DecodeRoundTripTests.swift`'s own file-local copy — neither file exports a public one).
    private static let identifierBlocklist: Set<String> = [
        "id", "install_id", "device_id", "session_id", "user_id", "ip", "timestamp", "email", "name",
    ]

    /// Collects every object key at every nesting level of a `JSONSerialization` object graph (mirrors
    /// `DecodeRoundTripTests.swift`'s own file-local copy).
    private static func collectKeys(_ value: Any) -> Set<String> {
        var keys: Set<String> = []
        if let dict = value as? [String: Any] {
            for (key, nested) in dict {
                keys.insert(key)
                keys.formUnion(collectKeys(nested))
            }
        } else if let array = value as? [Any] {
            for element in array {
                keys.formUnion(collectKeys(element))
            }
        }
        return keys
    }

    // MARK: - T1 happy path / explicit scenarios

    @Test("correct_count/ladder_rung take max, last_probe/next_due take latest day (AC5 explicit)")
    func mergeNodeTakesMaxAndLatest() {
        let a = Self.node(
            mastery: .fog, correctCount: 1, lastProbe: "2026-01-01", nextDue: "2026-01-10", ladderRung: 2)
        let b = Self.node(
            mastery: .fog, correctCount: 3, lastProbe: "2026-01-05", nextDue: "2026-01-02", ladderRung: 1)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(merged.correctCount == 3)
        #expect(merged.ladderRung == 2)
        #expect(merged.lastProbe == "2026-01-05")
        #expect(merged.nextDue == "2026-01-10")
    }

    @Test("last_probe/next_due absent iff both inputs absent (AC5)")
    func mergeNodeAbsentDayOnlyWhenBothAbsent() {
        let onlyA = Self.node(mastery: .fog, lastProbe: "2026-01-01", nextDue: nil)
        let onlyB = Self.node(mastery: .fog, lastProbe: nil, nextDue: nil)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": onlyA]), Self.state(nodes: ["alpha-node": onlyB])
        ).nodes["alpha-node"]!
        #expect(merged.lastProbe == "2026-01-01")
        #expect(merged.nextDue == nil)
    }

    @Test("remediated: OR when merged mastery is blocked and one side true (AC6a)")
    func mergeNodeRemediatedOrWhenBlocked() {
        let a = Self.node(mastery: .blocked, remediated: true)
        let b = Self.node(mastery: .blocked, remediated: false)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(merged.mastery == .blocked)
        #expect(merged.remediated == true)
    }

    @Test("remediated: false (present) when both blocked and both false/absent (AC6b)")
    func mergeNodeRemediatedFalseWhenBothBlockedAbsent() {
        let a = Self.node(mastery: .blocked, remediated: false)
        let b = Self.node(mastery: .blocked, remediated: nil)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(merged.mastery == .blocked)
        #expect(merged.remediated == false)
    }

    @Test("remediated: nil when merged mastery is cleared regardless of inputs (AC6c)")
    func mergeNodeRemediatedNilWhenCleared() {
        let a = Self.node(mastery: .cleared, remediated: nil)
        let b = Self.node(mastery: .blocked, remediated: true)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(merged.mastery == .cleared)
        #expect(merged.remediated == nil)
    }

    @Test("probe_log multiset union: max multiplicity, canonical order (AC7 explicit)")
    func mergeProbeLogMultisetUnion() {
        let x = ProbeLogEntry(
            day: "2026-01-01", nodeId: "alpha-node", itemId: "item-a", correct: true, retry: false)
        let y = ProbeLogEntry(
            day: "2026-01-02", nodeId: "beta-node", itemId: "item-b", correct: false, retry: true)
        let a = Self.state(probeLog: [x, x])
        let b = Self.state(probeLog: [x, y])
        let merged = StateMerge.merge(a, b)
        #expect(merged.probeLog.filter { $0 == x }.count == 2)
        #expect(merged.probeLog.filter { $0 == y }.count == 1)
        #expect(merged.probeLog == [x, x, y])
    }

    @Test("winning side: later latest-day wins (AC8a)")
    func mergeWinningSideLaterDayWins() {
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil)
        let markerB = Marker(courseCode: "MCR3U", unitId: "MCR3U.u3", pastLastUnit: true)
        let a = Self.state(marker: markerA, expeditionLog: [Self.expLog(day: "2026-02-01")])
        let b = Self.state(marker: markerB, expeditionLog: [Self.expLog(day: "2026-01-01")])
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerA)
        #expect(merged.syllabi == a.syllabi)
    }

    @Test("winning side tie: past_last_unit true ranks above any unit (AC8b)")
    func mergeWinningSideTieBreakPastLastUnit() {
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: true)
        let markerB = Marker(courseCode: "MTH1W", unitId: "MTH1W.u5", pastLastUnit: false)
        let a = Self.state(marker: markerA)
        let b = Self.state(marker: markerB)
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerA)
    }

    @Test("winning side tie: greater unit ordinal wins when neither is past last unit (AC8c)")
    func mergeWinningSideTieBreakUnitOrdinal() {
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: nil)
        let markerB = Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: false)
        let a = Self.state(marker: markerA)
        let b = Self.state(marker: markerB)
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerA)
    }

    @Test("winning side tie: lexicographically greater course_code wins (AC8d)")
    func mergeWinningSideTieBreakCourseCode() {
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: nil)
        let markerB = Marker(courseCode: "MCR3U", unitId: "MCR3U.u2", pastLastUnit: nil)
        let a = Self.state(marker: markerA)
        let b = Self.state(marker: markerB)
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerA)
    }

    @Test("install_day earlier, format_version_seen higher semver, consent_on AND (AC9 explicit)")
    func mergeInstallDayFormatVersionConsent() {
        let a = Self.state(installDay: "2026-02-01", formatVersionSeen: "1.2.3", consentOn: true)
        let b = Self.state(installDay: "2026-01-01", formatVersionSeen: "1.10.0", consentOn: false)
        let merged = StateMerge.merge(a, b)
        #expect(merged.installDay == "2026-01-01")
        #expect(merged.formatVersionSeen == "1.10.0")
        #expect(merged.consentOn == false)
    }

    @Test("schema_version is pinned to 2 regardless of input values (AC10)")
    func mergeSchemaVersionPinned() {
        let aState = StudentState(
            schemaVersion: 1, formatVersionSeen: "1.0.0", syllabi: ["MTH1W"],
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil), nodes: [:],
            trail: Self.trail(), expeditionLog: [], probeLog: [], installDay: "2026-01-01", consentOn: true)
        let bState = Self.state()
        let merged = StateMerge.merge(aState, bState)
        #expect(merged.schemaVersion == 2)
    }

    @Test("merged StudentState round-trips through CoreCoding and carries no identifier key (AC11)")
    func mergeRoundTripAndIdentifierBlocklistParity() throws {
        let a = Self.state(
            marker: Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: nil),
            nodes: ["alpha-node": Self.node(mastery: .blocked, correctCount: 1, remediated: true)],
            expeditionLog: [Self.expLog(day: "2026-01-01")],
            probeLog: [
                ProbeLogEntry(
                    day: "2026-01-01", nodeId: "alpha-node", itemId: "item-a", correct: true, retry: false)
            ])
        let b = Self.state(
            marker: Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: nil),
            nodes: ["beta-node": Self.node(mastery: .cleared, correctCount: 2)],
            expeditionLog: [Self.expLog(day: "2026-01-02")])
        let merged = StateMerge.merge(a, b)

        let encoded = try CoreCoding.encoder.encode(merged)
        let decoded = try CoreCoding.decoder.decode(StudentState.self, from: encoded)
        #expect(decoded == merged)

        let reencodedObject = try JSONSerialization.jsonObject(with: encoded)
        let collected = Self.collectKeys(reencodedObject)
        #expect(collected.isDisjoint(with: Self.identifierBlocklist))
    }

    // MARK: - T2 negative — asymmetric key sets

    @Test(
        "single-side node keys carry the owning side's value byte-identical, not run through mergeNode (T2)")
    func mergeNodesSingleSideKeysUnchanged() {
        let onlyA = Self.node(mastery: .fog, correctCount: 5, ladderRung: 3)
        let onlyB = Self.node(mastery: .cleared, correctCount: 7, ladderRung: 1)
        let a = Self.state(nodes: ["solo-a": onlyA])
        let b = Self.state(nodes: ["solo-b": onlyB])
        let merged = StateMerge.merge(a, b)
        #expect(merged.nodes["solo-a"] == onlyA)
        #expect(merged.nodes["solo-b"] == onlyB)
    }

    // MARK: - T4 conformance — algebraic-law property tests (AC2, AC3, AC4), plus AC5/AC7/AC9/I5 property variants

    @Test("merge is commutative over 200 generated pairs (AC2)")
    func mergeIsCommutative() {
        var gen = SeededGenerator(seed: 1)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            #expect(StateMerge.merge(a, b) == StateMerge.merge(b, a))
        }
    }

    @Test("merge(a, a) equals canonicalise(a) over 200 generated values (AC3)")
    func mergeIsIdempotentUnderCanonicalise() {
        var gen = SeededGenerator(seed: 2)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            #expect(StateMerge.merge(a, a) == StateMerge.canonicalise(a))
        }
    }

    @Test("merged node mastery rank is never lower than either input's for every surviving key (AC4)")
    func mergeNeverLowersMastery() {
        var gen = SeededGenerator(seed: 3)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let merged = StateMerge.merge(a, b)
            for (key, nodeA) in a.nodes {
                #expect(Self.masteryRank(merged.nodes[key]!.mastery) >= Self.masteryRank(nodeA.mastery))
            }
            for (key, nodeB) in b.nodes {
                #expect(Self.masteryRank(merged.nodes[key]!.mastery) >= Self.masteryRank(nodeB.mastery))
            }
        }
    }

    @Test("merged correct_count and ladder_rung equal max of both inputs for shared keys (AC5 property)")
    func mergeNodeMaxPropertyTest() {
        var gen = SeededGenerator(seed: 4)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let merged = StateMerge.merge(a, b)
            for key in Set(a.nodes.keys).intersection(b.nodes.keys) {
                let nodeA = a.nodes[key]!
                let nodeB = b.nodes[key]!
                let mergedNode = merged.nodes[key]!
                #expect(mergedNode.correctCount == max(nodeA.correctCount, nodeB.correctCount))
                #expect(mergedNode.ladderRung == max(nodeA.ladderRung, nodeB.ladderRung))
            }
        }
    }

    @Test("merged log count equals sum over distinct values of max multiplicity (AC7 property)")
    func mergeLogMultisetMaxMultiplicityProperty() {
        var gen = SeededGenerator(seed: 5)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let merged = StateMerge.merge(a, b)
            #expect(
                merged.expeditionLog.count == Self.expectedMultisetCount(a.expeditionLog, b.expeditionLog))
            #expect(merged.probeLog.count == Self.expectedMultisetCount(a.probeLog, b.probeLog))
        }
    }

    @Test("install_day/format_version_seen/consent_on hold over 200 generated pairs (AC9 property)")
    func mergeInstallFormatConsentProperty() {
        var gen = SeededGenerator(seed: 6)
        let today = Self.today()
        for _ in 0..<200 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let merged = StateMerge.merge(a, b)
            #expect(merged.installDay == min(a.installDay, b.installDay))
            #expect(merged.consentOn == (a.consentOn && b.consentOn))
            #expect(Self.semverGreaterOrEqual(merged.formatVersionSeen, a.formatVersionSeen))
            #expect(Self.semverGreaterOrEqual(merged.formatVersionSeen, b.formatVersionSeen))
        }
    }

    @Test(
        "no generated merge ever produces a wire key in the identifier blocklist (I5 property, 20 iterations)"
    )
    func mergeNeverProducesIdentifierKeyProperty() throws {
        var gen = SeededGenerator(seed: 7)
        let today = Self.today()
        for _ in 0..<20 {
            let a = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let b = PropertyGen.studentState(&gen, nodeIds: Self.nodeIdPool, today: today)
            let merged = StateMerge.merge(a, b)
            let encoded = try CoreCoding.encoder.encode(merged)
            let object = try JSONSerialization.jsonObject(with: encoded)
            let collected = Self.collectKeys(object)
            #expect(collected.isDisjoint(with: Self.identifierBlocklist))
        }
    }

    // MARK: - T5 negative control for every regression guard (AC12)

    @Test("negative control: sum-multiplicity logs would break idempotence (AC12)")
    func negativeControlSumMultiplicityBreaksIdempotence() {
        let entry = Self.expLog(day: "2026-01-01")
        let a = Self.state(expeditionLog: [entry, entry])
        func wrongMergeLogsCount(_ lhs: [ExpeditionLogEntry], _ rhs: [ExpeditionLogEntry]) -> Int {
            (lhs + rhs).count
        }
        let wrongIdempotentCount = wrongMergeLogsCount(a.expeditionLog, a.expeditionLog)
        let realMergedCount = StateMerge.merge(a, a).expeditionLog.count
        #expect(wrongIdempotentCount != realMergedCount)
        #expect(wrongIdempotentCount == 4)
        #expect(realMergedCount == 2)
    }

    @Test("negative control: lower-mastery-wins variant diverges from the real rule (AC12)")
    func negativeControlLowerMasteryWins() {
        func wrongMasteryRank(_ mastery: Mastery) -> Int {
            switch mastery {
            case .fog: return 2
            case .blocked: return 1
            case .cleared: return 0
            }
        }
        let a = Self.node(mastery: .cleared)
        let b = Self.node(mastery: .fog)
        let wrongResult = wrongMasteryRank(a.mastery) >= wrongMasteryRank(b.mastery) ? a.mastery : b.mastery
        let realResult = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!.mastery
        #expect(wrongResult == .fog)
        #expect(realResult == .cleared)
        #expect(wrongResult != realResult)
    }

    @Test("negative control: min instead of max for correct_count/ladder_rung diverges (AC12)")
    func negativeControlMinInsteadOfMax() {
        let a = Self.node(mastery: .fog, correctCount: 1, ladderRung: 1)
        let b = Self.node(mastery: .fog, correctCount: 4, ladderRung: 3)
        let wrongCorrectCount = min(a.correctCount, b.correctCount)
        let wrongLadderRung = min(a.ladderRung, b.ladderRung)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(wrongCorrectCount != merged.correctCount)
        #expect(wrongLadderRung != merged.ladderRung)
        #expect(merged.correctCount == 4)
        #expect(merged.ladderRung == 3)
    }

    @Test("negative control: earlier-day-wins diverges from the real rule on present values (AC12)")
    func negativeControlEarlierDayWins() {
        let a = Self.node(mastery: .fog, lastProbe: "2026-01-01", nextDue: nil)
        let b = Self.node(mastery: .fog, lastProbe: "2026-01-05", nextDue: nil)
        let wrongLastProbe = min(a.lastProbe!, b.lastProbe!)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(wrongLastProbe != merged.lastProbe)
        #expect(merged.lastProbe == "2026-01-05")
    }

    @Test("negative control: AND instead of OR for remediated diverges on AC6a's scenario (AC12)")
    func negativeControlRemediatedAnd() {
        let a = Self.node(mastery: .blocked, remediated: true)
        let b = Self.node(mastery: .blocked, remediated: false)
        let wrongRemediated = (a.remediated ?? false) && (b.remediated ?? false)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": a]), Self.state(nodes: ["alpha-node": b])
        ).nodes["alpha-node"]!
        #expect(wrongRemediated == false)
        #expect(merged.remediated == true)
    }

    @Test("negative control: course_code-first tie-break diverges from the real rule (AC12)")
    func negativeControlMarkerTieBreakOrder() {
        let markerA = Marker(courseCode: "MCR3U", unitId: "MCR3U.u4", pastLastUnit: nil)
        let markerB = Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: nil)
        let a = Self.state(marker: markerA)
        let b = Self.state(marker: markerB)
        let wrongWinnerIsA = markerA.courseCode > markerB.courseCode
        let merged = StateMerge.merge(a, b)
        #expect(wrongWinnerIsA == false)
        #expect(merged.marker == markerA)
    }

    @Test("negative control: later install_day wins diverges from the real rule (AC12)")
    func negativeControlInstallDayLater() {
        let a = Self.state(installDay: "2026-02-01")
        let b = Self.state(installDay: "2026-01-01")
        let wrongInstallDay = max(a.installDay, b.installDay)
        let merged = StateMerge.merge(a, b)
        #expect(wrongInstallDay != merged.installDay)
        #expect(merged.installDay == "2026-01-01")
    }

    @Test("negative control: lower semver wins diverges from the real rule (AC12)")
    func negativeControlFormatVersionLower() {
        let a = Self.state(formatVersionSeen: "2.0.0")
        let b = Self.state(formatVersionSeen: "1.5.0")
        let merged = StateMerge.merge(a, b)
        #expect(merged.formatVersionSeen == "2.0.0")
        #expect(merged.formatVersionSeen != "1.5.0")
    }

    @Test("negative control: OR instead of AND for consent_on diverges from the real rule (AC12)")
    func negativeControlConsentOr() {
        let a = Self.state(consentOn: true)
        let b = Self.state(consentOn: false)
        let wrongConsent = a.consentOn || b.consentOn
        let merged = StateMerge.merge(a, b)
        #expect(wrongConsent == true)
        #expect(merged.consentOn == false)
    }

    // MARK: - T6 idempotency / no-leak

    @Test("merge/canonicalise are pure — repeated calls on identical inputs return equal results (T6)")
    func mergeAndCanonicaliseArePure() {
        let a = Self.state(nodes: ["alpha-node": Self.node(mastery: .blocked, remediated: true)])
        let b = Self.state(marker: Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: nil))
        let firstMerge = StateMerge.merge(a, b)
        let secondMerge = StateMerge.merge(a, b)
        #expect(firstMerge == secondMerge)

        let firstCanonicalise = StateMerge.canonicalise(a)
        let secondCanonicalise = StateMerge.canonicalise(a)
        #expect(firstCanonicalise == secondCanonicalise)
    }
}

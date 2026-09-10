import Foundation
import Testing

@testable import Core

/// Tester's supplementary coverage for `StateMerge` (`Sources/Core/State/StateMerge.swift`), written
/// against `tasks/epic-02-task-12-state-merge.md` §5. This file does NOT re-verify what the implementer's
/// own `StateMergeTests.swift` already owns (AC1-AC12, T1-T2, T4-T6 explicit/property coverage) — it
/// targets gaps left open:
///  - T3's own mandatory mechanical grep check ("no `throw`/`CoreError` in `StateMerge.swift`"), never
///    written by the implementer's suite (§5 T3: "A grep assertion ... confirms zero matches, as a
///    mechanical check that this stays true").
///  - I14's own mandatory mechanical grep check ("zero occurrences of `Date()` in `StateMerge.swift`"),
///    also named in §5 T4 but never written.
///  - the "Winning side W" branch "a side with both logs empty loses to a side with any entry" (contract
///    text, `merge` rule quoted §3) — exercised only incidentally, never asserted directly; AC8's four
///    explicit scenarios (a-d) all give both sides at least one log entry.
///  - the "Winning side W" branch where the deciding latest day comes from `probe_log` rather than
///    `expedition_log` — `latestDay` unions both arrays' `day` values, but every AC8 scenario decides via
///    `expedition_log` only.
///  - `remediated` dropped even when an input's own value is `true` on a node whose own mastery is not
///    `blocked` (a shape the type system permits but the field's semantics forbid — "stored state is
///    untrusted input too").
///  - AC12's `format_version_seen` negative control, strengthened to actually construct the wrong
///    (lower-semver) variant and compare it against `StateMerge.merge`'s real result on a concrete
///    scenario, matching the pattern every other AC12 case in the implementer's suite already uses (the
///    implementer's own `negativeControlFormatVersionLower` only asserts the real result, never
///    reconstructs the wrong variant).
///  - AC12's `last_probe`/`next_due` negative control's second half — "treats absent as *later* than any
///    day" — untested by the implementer's suite, which only covers the both-present case.
@Suite("StateMerge — boundary and gap coverage")
struct StateMergeBoundaryTests {
    private static var stateMergeSourceText: String {
        get throws {
            let sourceFile = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // CoreTests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // package root
                .appendingPathComponent("Sources/Core/State/StateMerge.swift")
            return try String(contentsOf: sourceFile, encoding: .utf8)
        }
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

    private static func state(
        marker: Marker = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil),
        nodes: [String: NodeState] = [:],
        expeditionLog: [ExpeditionLogEntry] = [],
        probeLog: [ProbeLogEntry] = [],
        installDay: String = "2026-01-01",
        formatVersionSeen: String = "1.0.0",
        consentOn: Bool = true
    ) -> StudentState {
        StudentState(
            schemaVersion: 2, formatVersionSeen: formatVersionSeen, syllabi: [marker.courseCode],
            marker: marker, nodes: nodes,
            trail: Trail(segments: [TrailSegment(kind: .course, courseCode: marker.courseCode, nodeIds: [])]),
            expeditionLog: expeditionLog, probeLog: probeLog, installDay: installDay, consentOn: consentOn)
    }

    // MARK: - T3 mechanical check (no error code registered or thrown by this task)

    @Test("StateMerge.swift throws no error and references no CoreError (T3)")
    func stateMergeThrowsNoErrorCode() throws {
        let text = try Self.stateMergeSourceText
        #expect(!text.contains("throw"))
        #expect(!text.contains("CoreError"))
    }

    // MARK: - I14 mechanical check (no wall-clock read anywhere in this task's code)

    @Test("StateMerge.swift contains no Date() literal (I14)")
    func stateMergeContainsNoDateLiteral() throws {
        let text = try Self.stateMergeSourceText
        #expect(!text.contains("Date()"))
    }

    // MARK: - Winning side W — branches AC8's four explicit scenarios never exercise

    @Test(
        "winning side: a side with both logs empty loses to a side with any entry, even against a marker that would otherwise rank higher (contract text, quoted §3)"
    )
    func mergeWinningSideEmptyLogsLosesRegardlessOfMarkerRank() {
        // `a`'s marker outranks `b`'s on every tie-break field (past_last_unit, unit ordinal, course_code),
        // but `a` has no log entries at all while `b` has one — the day comparison must still decide first.
        let markerA = Marker(courseCode: "MTH1W", unitId: "MTH1W.u5", pastLastUnit: true)
        let markerB = Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: false)
        let a = Self.state(marker: markerA)
        let b = Self.state(
            marker: markerB,
            expeditionLog: [
                ExpeditionLogEntry(
                    day: "2020-01-01", itemCount: 1, cleared: 0, blocked: 0, abandoned: false,
                    diagnosisEvents: 0)
            ])
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerB)
    }

    @Test("winning side: the deciding latest day may come from probe_log alone, not just expedition_log")
    func mergeWinningSideDecidedByProbeLogAlone() {
        let markerA = Marker(courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: nil)
        let markerB = Marker(courseCode: "MTH1W", unitId: "MTH1W.u1", pastLastUnit: nil)
        let a = Self.state(
            marker: markerA,
            probeLog: [
                ProbeLogEntry(
                    day: "2026-01-01", nodeId: "alpha-node", itemId: "item-a", correct: true, retry: false)
            ])
        let b = Self.state(
            marker: markerB,
            probeLog: [
                ProbeLogEntry(
                    day: "2026-02-01", nodeId: "alpha-node", itemId: "item-a", correct: true, retry: false)
            ])
        let merged = StateMerge.merge(a, b)
        #expect(merged.marker == markerB)
    }

    // MARK: - remediated: stored state is untrusted input too

    @Test(
        "remediated is dropped whenever merged mastery is not blocked, even if an input carries remediated == true on a node whose own mastery is not blocked (untrusted stored state)"
    )
    func mergeRemediatedDroppedEvenWhenInputIllegallySetOnNonBlockedNode() {
        // NodeState's type does not forbid `remediated: true` alongside `mastery: .fog` — a real device
        // could in principle write this (a corrupted or hand-edited document); the merge rule's own text
        // says `remediated` is "removed unless the merged mastery is blocked", with no exception for an
        // input value already carrying the field illegally.
        let illegallyRemediatedFog = Self.node(mastery: .fog, remediated: true)
        let cleared = Self.node(mastery: .cleared, remediated: nil)
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": illegallyRemediatedFog]),
            Self.state(nodes: ["alpha-node": cleared])
        ).nodes["alpha-node"]!
        #expect(merged.mastery == .cleared)
        #expect(merged.remediated == nil)
    }

    // MARK: - AC12 negative controls, strengthened

    @Test(
        "negative control: an explicitly reconstructed lower-semver-wins variant diverges from the real rule on a concrete scenario (AC12, format_version_seen)"
    )
    func negativeControlFormatVersionLowerReconstructed() {
        func wrongLowerSemver(_ a: String, _ b: String) -> String {
            func components(_ semver: String) -> [Int] { semver.split(separator: ".").map { Int($0) ?? 0 } }
            return components(a).lexicographicallyPrecedes(components(b)) ? a : b
        }
        let a = Self.state(formatVersionSeen: "2.0.0")
        let b = Self.state(formatVersionSeen: "1.5.0")
        let wrongResult = wrongLowerSemver(a.formatVersionSeen, b.formatVersionSeen)
        let merged = StateMerge.merge(a, b)
        #expect(wrongResult == "1.5.0")
        #expect(merged.formatVersionSeen == "2.0.0")
        #expect(wrongResult != merged.formatVersionSeen)
    }

    @Test(
        "negative control: treating absent last_probe as later than any present day diverges from the real rule (AC12, last_probe/next_due, the absent-handling half, untested by the implementer's own suite)"
    )
    func negativeControlAbsentTreatedAsLaterDiverges() {
        let present = Self.node(mastery: .fog, lastProbe: "2026-01-01")
        let absent = Self.node(mastery: .fog, lastProbe: nil)
        // Wrong variant: absent ranks later than any present day, so it always wins over a present value.
        let wrongLastProbe: String? = absent.lastProbe  // nil — the wrong variant's chosen "later" value
        let merged = StateMerge.merge(
            Self.state(nodes: ["alpha-node": present]), Self.state(nodes: ["alpha-node": absent])
        ).nodes["alpha-node"]!
        #expect(wrongLastProbe == nil)
        #expect(merged.lastProbe == "2026-01-01")
        #expect(wrongLastProbe != merged.lastProbe)
    }
}

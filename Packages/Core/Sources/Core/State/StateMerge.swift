import Foundation

/// State merge on iCloud sync conflict (`contracts/data-model.md` v1.4.0 § StudentState merge (platform
/// Q3), landed by task 02.9 from the arbiter's Q-B ruling,
/// `tasks/arbitration/arbiter-02-predispatch.md:83-111`). A pure `Core` function over two already-migrated
/// `StudentState` values (I14) — no bundle, no I/O, no clock read, no new field (I5).
public enum StateMerge {
    /// `merge(a, b)` per the contract's normative rule (quoted in full, §3). Commutative and idempotent
    /// under `canonicalise` (below); no merged node's `mastery` is lower than either input's.
    public static func merge(_ a: StudentState, _ b: StudentState) -> StudentState {
        let aWins = winningSideIsA(a, b)
        let winner = aWins ? a : b
        return StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: higherSemver(a.formatVersionSeen, b.formatVersionSeen),
            syllabi: winner.syllabi,
            marker: winner.marker,
            nodes: mergeNodes(a.nodes, b.nodes),
            trail: winner.trail,
            expeditionLog: mergeLogs(a.expeditionLog, b.expeditionLog, precedes: expeditionLogPrecedes),
            probeLog: mergeLogs(a.probeLog, b.probeLog, precedes: probeLogPrecedes),
            installDay: min(a.installDay, b.installDay),
            consentOn: a.consentOn && b.consentOn
        )
    }

    /// `merge(a, a)`'s expected value: `a` with `expeditionLog`/`probeLog` reordered into the merge rule's
    /// canonical order. Every other field degenerates to `a`'s own value when both merge sides are `a`
    /// (max/min/OR/AND of a value with itself is itself; `nodes` merging `a.nodes` with itself keeps every
    /// entry unchanged; the winning-side computation, given two structurally identical inputs, picks a
    /// side whose fields equal `a`'s own regardless of which one it names). `schemaVersion` is re-pinned to
    /// `currentSchemaVersion`, matching `merge`'s own behaviour, so this is not simply "`a` unchanged."
    public static func canonicalise(_ state: StudentState) -> StudentState {
        StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: state.formatVersionSeen,
            syllabi: state.syllabi,
            marker: state.marker,
            nodes: state.nodes,
            trail: state.trail,
            expeditionLog: state.expeditionLog.sorted(by: expeditionLogPrecedes),
            probeLog: state.probeLog.sorted(by: probeLogPrecedes),
            installDay: state.installDay,
            consentOn: state.consentOn
        )
    }

    /// `contracts/data-model.md:149`: "`schema_version` is **2**." Re-pinned rather than propagated from
    /// either input so the function's output does not silently depend on both inputs already being 2 (§6
    /// default 1).
    private static let currentSchemaVersion = 2
}

// MARK: - nodes — key union, per-key merge

extension StateMerge {
    private static func mergeNodes(_ a: [String: NodeState], _ b: [String: NodeState]) -> [String: NodeState]
    {
        var result: [String: NodeState] = [:]
        for key in Set(a.keys).union(b.keys) {
            switch (a[key], b[key]) {
            case let (.some(onlyA), nil): result[key] = onlyA
            case let (nil, .some(onlyB)): result[key] = onlyB
            case let (.some(left), .some(right)): result[key] = mergeNode(left, right)
            case (nil, nil): break  // unreachable — key drawn from the union of both key sets
            }
        }
        return result
    }

    private static func mergeNode(_ a: NodeState, _ b: NodeState) -> NodeState {
        let mastery = higherMastery(a.mastery, b.mastery)
        let orRemediated = (a.remediated ?? false) || (b.remediated ?? false)
        return NodeState(
            mastery: mastery,
            correctCount: max(a.correctCount, b.correctCount),
            lastProbe: laterDay(a.lastProbe, b.lastProbe),
            nextDue: laterDay(a.nextDue, b.nextDue),
            ladderRung: max(a.ladderRung, b.ladderRung),
            remediated: mastery == .blocked ? orRemediated : nil
        )
    }

    /// `cleared` > `blocked` > `fog` (contract, quoted §3).
    private static func masteryRank(_ mastery: Mastery) -> Int {
        switch mastery {
        case .fog: return 0
        case .blocked: return 1
        case .cleared: return 2
        }
    }

    private static func higherMastery(_ a: Mastery, _ b: Mastery) -> Mastery {
        masteryRank(a) >= masteryRank(b) ? a : b
    }

    /// "absent is earlier than any day" (contract, quoted §3). String comparison of `YYYY-MM-DD` values is
    /// chronological order — the same fact `CalendarDay.Comparable` relies on
    /// (`Time/CalendarDay.swift:36-38`).
    private static func laterDay(_ a: String?, _ b: String?) -> String? {
        switch (a, b) {
        case (nil, nil): return nil
        case let (.some(onlyA), nil): return onlyA
        case let (nil, .some(onlyB)): return onlyB
        case let (.some(dayA), .some(dayB)): return dayA >= dayB ? dayA : dayB
        }
    }
}

// MARK: - expedition_log, probe_log — multiset union, max multiplicity, canonical order

extension StateMerge {
    /// Log arrays are small (a handful of entries per sync); an `O(n²)` dedup-and-count is the simplest
    /// correct implementation and is not a performance concern here (RULE 2, Simplicity First — §6
    /// default 2).
    private static func mergeLogs<T: Equatable>(_ a: [T], _ b: [T], precedes: (T, T) -> Bool) -> [T] {
        var distinctValues: [T] = []
        for value in a + b where !distinctValues.contains(value) {
            distinctValues.append(value)
        }
        var result: [T] = []
        for value in distinctValues {
            let countA = a.filter { $0 == value }.count
            let countB = b.filter { $0 == value }.count
            result.append(contentsOf: Array(repeating: value, count: max(countA, countB)))
        }
        return result.sorted(by: precedes)
    }

    /// Canonical order for `expedition_log`: ascending `day`, then `item_count`, `cleared`, `blocked`,
    /// `abandoned` (`false` before `true`), `diagnosis_events` — the contract's stated field order, which
    /// matches `ExpeditionLogEntry`'s own declared field order (`Model/StudentState.swift:59-66`, re-read
    /// in this run).
    private static func expeditionLogPrecedes(_ lhs: ExpeditionLogEntry, _ rhs: ExpeditionLogEntry) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.itemCount != rhs.itemCount { return lhs.itemCount < rhs.itemCount }
        if lhs.cleared != rhs.cleared { return lhs.cleared < rhs.cleared }
        if lhs.blocked != rhs.blocked { return lhs.blocked < rhs.blocked }
        if lhs.abandoned != rhs.abandoned { return !lhs.abandoned }
        return lhs.diagnosisEvents < rhs.diagnosisEvents
    }

    /// Canonical order for `probe_log`: ascending `day`, then `node_id`, `item_id`, `correct` (`false`
    /// before `true`), `retry` — matching `ProbeLogEntry`'s own declared field order
    /// (`Model/StudentState.swift:68-74`, re-read in this run).
    private static func probeLogPrecedes(_ lhs: ProbeLogEntry, _ rhs: ProbeLogEntry) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        if lhs.nodeId != rhs.nodeId { return lhs.nodeId < rhs.nodeId }
        if lhs.itemId != rhs.itemId { return lhs.itemId < rhs.itemId }
        if lhs.correct != rhs.correct { return !lhs.correct }
        return !lhs.retry && rhs.retry
    }
}

// MARK: - Winning side W — marker tie-break, final canonical-JSON tie-break

extension StateMerge {
    /// `true` selects `a` as the winning side, `false` selects `b` (contract's "Winning side W", quoted
    /// §3).
    private static func winningSideIsA(_ a: StudentState, _ b: StudentState) -> Bool {
        switch (latestDay(a), latestDay(b)) {
        case (nil, nil): break
        case (nil, .some): return false
        case (.some, nil): return true
        case let (.some(dayA), .some(dayB)):
            if dayA != dayB { return dayA > dayB }
        }
        let rankA = markerRank(a.marker)
        let rankB = markerRank(b.marker)
        if rankA.0 != rankB.0 { return rankA.0 > rankB.0 }
        if rankA.1 != rankB.1 { return rankA.1 > rankB.1 }
        if a.marker.courseCode != b.marker.courseCode { return a.marker.courseCode > b.marker.courseCode }
        // Final tie-break: canonical JSON encodings (CoreCoding — the one JSON coder configuration,
        // `.sortedKeys`), byte-wise, greater wins (§6 default 3).
        let encodedA = (try? CoreCoding.encoder.encode(a)) ?? Data()
        let encodedB = (try? CoreCoding.encoder.encode(b)) ?? Data()
        if encodedA == encodedB { return true }  // structurally identical for ranking purposes
        return encodedB.lexicographicallyPrecedes(encodedA)
    }

    private static func latestDay(_ state: StudentState) -> String? {
        (state.expeditionLog.map(\.day) + state.probeLog.map(\.day)).max()
    }

    /// `(pastLastUnitFlag, unitOrdinal)`, compared lexicographically: `past_last_unit: true` ranks above
    /// any unit (flag 1 > flag 0); `nil`/`false` both rank as "not past last unit" (§6 default 4).
    private static func markerRank(_ marker: Marker) -> (Int, Int) {
        (marker.pastLastUnit == true ? 1 : 0, unitOrdinal(marker.unitId))
    }

    /// `unit_id` = `<course_code>.u<n>` (§ Identifiers, quoted §3); `n` is the substring after the last
    /// `.u`.
    private static func unitOrdinal(_ unitId: String) -> Int {
        guard let range = unitId.range(of: ".u", options: .backwards) else { return 0 }
        return Int(unitId[range.upperBound...]) ?? 0
    }
}

// MARK: - install_day, format_version_seen, consent_on

extension StateMerge {
    private static func higherSemver(_ a: String, _ b: String) -> String {
        semverComponents(a).lexicographicallyPrecedes(semverComponents(b)) ? b : a
    }

    private static func semverComponents(_ semver: String) -> [Int] {
        semver.split(separator: ".").map { Int($0) ?? 0 }
    }
}

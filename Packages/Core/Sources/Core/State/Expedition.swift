import Foundation

/// One of the ≈ 5 places in an expedition (`contracts/domain-glossary.md` § Slot). Never call this
/// "frontier" — that name is explicitly banned by the same glossary entry.
public enum SlotKind: String, Equatable {
    case newLearning
    case review
}

/// One filled slot: the node it targets, the drawn `ProbeItem`, and whether it is new-learning (from the
/// fringe) or review (a due `cleared` node).
public struct ComposeSlot: Equatable {
    public let nodeId: String
    public let item: ProbeItem
    public let kind: SlotKind
}

/// The result of `Expedition.compose`. `skippedNodeIds` are fringe/due candidates whose item pool was
/// empty (`selectItem` returned `nil`) — logged, not thrown (`EXP_ITEM_POOL_EMPTY` is "Node skipped this
/// run; internal count", `docs/domains/expedition.md` § error codes), in the order they were skipped.
public struct ComposeResult: Equatable {
    public let slots: [ComposeSlot]
    public let skippedNodeIds: [String]
}

/// Expedition W1 (`compose`, D48/D45/D46) and the single-item variant of learning-objects W3
/// (`selectItem`). Every function is a pure value transformation over its arguments — no system clock
/// read, no file I/O, no global mutable state (I14). `Core` boundary: Foundation only.
public enum Expedition {
    /// D48 fringe + slot fill (`contracts/interaction-contract.md` § 2 `compose`). `trail` is always the
    /// caller's own, already-generated `Trail` (e.g. `MarkerTrail.setMarker`'s result) — this function
    /// never regenerates a trail and never reads `state.trail` (§6 decision default). `today` is always
    /// the caller's injected `CalendarDay` (I14). Throws `CoreError.expNoFringe` iff both the fringe node
    /// set and the due node set are empty.
    public static func compose(
        state: StudentState,
        bundle: ContentBundle,
        trail: Trail,
        marker: Marker,
        today: CalendarDay,
        queuedNodeId: String? = nil,
        unitExpeditionUnitId: String? = nil
    ) throws -> ComposeResult {
        let index = GraphIndex(bundle: bundle)
        let edgesByTo = Dictionary(grouping: index.edges, by: \.to)
        let fringe = fringeNodeIds(
            state: state, bundle: bundle, index: index, edgesByTo: edgesByTo, marker: marker, trail: trail,
            unitExpeditionUnitId: unitExpeditionUnitId)
        let due = dueNodeIds(state: state, today: today)
        guard !(fringe.isEmpty && due.isEmpty) else { throw CoreError.expNoFringe }

        let reviewSlotsCount = min(2, due.count)
        let newLearningCap = 5 - reviewSlotsCount

        var newLearningOrder: [String] = []
        if let queued = queuedNodeId, fringe.contains(queued) { newLearningOrder.append(queued) }
        newLearningOrder += trailOrder(trail).filter { fringe.contains($0) && $0 != queuedNodeId }
        newLearningOrder += fringe.subtracting(Set(newLearningOrder)).sorted()

        var slots: [ComposeSlot] = []
        var skipped: [String] = []

        for nodeId in newLearningOrder {
            guard slots.filter({ $0.kind == .newLearning }).count < newLearningCap else { break }
            guard let node = index.nodesById[nodeId] else { continue }
            if let item = selectItem(from: node, excluding: [], probeLog: state.probeLog) {
                slots.append(ComposeSlot(nodeId: nodeId, item: item, kind: .newLearning))
            } else {
                skipped.append(nodeId)
            }
        }

        for nodeId in due {
            guard slots.filter({ $0.kind == .review }).count < reviewSlotsCount else { break }
            guard let node = index.nodesById[nodeId] else { continue }
            if let item = selectItem(from: node, excluding: [], probeLog: state.probeLog) {
                slots.append(ComposeSlot(nodeId: nodeId, item: item, kind: .review))
            } else {
                skipped.append(nodeId)
            }
        }

        return ComposeResult(slots: slots, skippedNodeIds: skipped)
    }

    /// The single-item draw (learning-objects W3, single-item variant), reused by 02.7 (excludes items
    /// already answered in the current run, for D27's retry) and 02.11 (excludes items already answered in
    /// the current run, for the Q-G "available" probe-item definition). `excludedItemIds` is always empty
    /// at `compose` time — nothing has been shown yet in a run that has not started. Among the remaining
    /// candidates, prefers an item with no `probeLog` entry, then the item whose most-recent `probeLog` day
    /// is earliest ("least recently used"), then the lower item id (brief §9 technical default). Returns
    /// `nil` iff every item of `node` is excluded or `node.probeItems` is empty.
    public static func selectItem(
        from node: Node, excluding excludedItemIds: Set<String>, probeLog: [ProbeLogEntry]
    ) -> ProbeItem? {
        let candidates = node.probeItems.filter { !excludedItemIds.contains($0.id) }
        guard !candidates.isEmpty else { return nil }

        var lastUsed: [String: String] = [:]
        for entry in probeLog {
            if let existing = lastUsed[entry.itemId] {
                if entry.day > existing { lastUsed[entry.itemId] = entry.day }
            } else {
                lastUsed[entry.itemId] = entry.day
            }
        }

        return candidates.min { lhs, rhs in
            switch (lastUsed[lhs.id], lastUsed[rhs.id]) {
            case (nil, nil): return lhs.id < rhs.id
            case (nil, .some): return true
            case (.some, nil): return false
            case let (.some(lDay), .some(rDay)):
                if lDay != rDay { return lDay < rDay }
                return lhs.id < rhs.id
            }
        }
    }

    // MARK: - Private fringe/window helpers

    /// A node is resident in course `X` iff its `expectationCodes` array (may be `nil`) contains ≥ 1
    /// entry whose `courseCode == X`. A second, independent implementation of the same rule 02.5's own
    /// (private, hence not importable) `MarkerTrailGeneration.swift` helper uses.
    private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> {
        Set(
            index.nodesById.values
                .filter { node in
                    (node.expectationCodes ?? []).contains { $0.courseCode == course.courseCode }
                }
                .map(\.id))
    }

    /// A node's unit index within course `X` is the 0-based index into `course.units` of the unit named
    /// by the node's lowest-ordered expectation code for `X` (`contracts/graph-constraints.md` v1.1.0
    /// L0-T).
    private static func unitIndex(nodeId: String, course: Course, index: GraphIndex) -> Int? {
        guard let node = index.nodesById[nodeId] else { return nil }
        let entries = (node.expectationCodes ?? []).filter { $0.courseCode == course.courseCode }
        let ordinals: [Int] = entries.compactMap { entry in
            guard let unitId = course.expectations.first(where: { $0.code == entry.code })?.unitId else {
                return nil
            }
            return course.units.firstIndex(where: { $0.unitId == unitId })
        }
        return ordinals.min()
    }

    /// The three readings of "`marker.unit ∪ next(marker.unit)`, or the requested unit only" (compose
    /// bullet), in priority order — unit expedition first, then past-last-unit (Q-F), then the ordinary
    /// current+next-unit window.
    private static func scopeWindow(
        marker: Marker, trail: Trail, index: GraphIndex, unitExpeditionUnitId: String?
    ) -> Set<String> {
        if let requestedUnit = unitExpeditionUnitId {
            guard let courseCode = requestedUnit.split(separator: ".").first.map(String.init),
                let course = index.coursesByCode[courseCode]
            else { return [] }
            return residentNodeIds(course: course, index: index).filter { nodeId in
                guard let idx = unitIndex(nodeId: nodeId, course: course, index: index),
                    idx < course.units.count
                else { return false }
                return course.units[idx].unitId == requestedUnit
            }
        }
        if marker.pastLastUnit == true {
            return Set(trail.segments.first(where: { $0.kind == .extension })?.nodeIds ?? [])
        }
        guard let course = index.coursesByCode[marker.courseCode],
            let markerUnitIdx = course.units.firstIndex(where: { $0.unitId == marker.unitId })
        else { return [] }
        return Set(
            residentNodeIds(course: course, index: index).filter { nodeId in
                guard let idx = unitIndex(nodeId: nodeId, course: course, index: index) else { return false }
                return idx == markerUnitIdx || idx == markerUnitIdx + 1
            })
    }

    private static func mastery(of nodeId: String, in state: StudentState) -> Mastery {
        state.nodes[nodeId]?.mastery ?? .fog
    }

    private static func isRemediated(_ nodeId: String, in state: StudentState) -> Bool {
        state.nodes[nodeId]?.remediated ?? false
    }

    private static func prerequisiteGuardSatisfied(
        _ nodeId: String, state: StudentState, edgesByTo: [String: [Edge]]
    ) -> Bool {
        (edgesByTo[nodeId] ?? []).allSatisfy { edge in
            let p = edge.from
            return mastery(of: p, in: state) == .cleared
                || (mastery(of: p, in: state) == .blocked && isRemediated(p, in: state))
        }
    }

    /// The guard-eligible-and-in-window set unioned with the unconditional `blocked` set (the compose
    /// formula's `∪ {n : mastery(n) = blocked}`; the Q-A cascade note: "It is always fringe-eligible
    /// itself as `blocked`"). A `blocked` node outside every trail segment (no course, or a course not in
    /// `syllabi[]`) is still fringe-eligible — the union has no course/trail restriction on the `blocked`
    /// term.
    private static func fringeNodeIds(
        state: StudentState, bundle: ContentBundle, index: GraphIndex, edgesByTo: [String: [Edge]],
        marker: Marker, trail: Trail, unitExpeditionUnitId: String?
    ) -> Set<String> {
        let window = scopeWindow(
            marker: marker, trail: trail, index: index, unitExpeditionUnitId: unitExpeditionUnitId)
        let guardEligible = bundle.nodes.nodes.map(\.id).filter { nodeId in
            mastery(of: nodeId, in: state) != .cleared && window.contains(nodeId)
                && prerequisiteGuardSatisfied(nodeId, state: state, edgesByTo: edgesByTo)
        }
        let blocked = bundle.nodes.nodes.map(\.id).filter { mastery(of: $0, in: state) == .blocked }
        return Set(guardEligible).union(blocked)
    }

    // MARK: - Private due-node and trail-order helpers

    /// `CalendarDay.iso` string comparison is valid here for the same reason `CalendarDay.Comparable`
    /// uses it: two zero-padded `"YYYY-MM-DD"` strings of equal length sort lexicographically in
    /// chronological order.
    private static func dueNodeIds(state: StudentState, today: CalendarDay) -> [String] {
        let due = state.nodes.filter { _, ns in
            ns.mastery == .cleared && (ns.nextDue.map { $0 <= today.iso } ?? false)
        }
        return due.keys.sorted { lhs, rhs in
            let l = state.nodes[lhs]?.lastProbe
            let r = state.nodes[rhs]?.lastProbe
            switch (l, r) {
            case (nil, nil): return lhs < rhs
            case (nil, .some): return true
            case (.some, nil): return false
            case let (.some(ld), .some(rd)):
                if ld != rd { return ld < rd }
                return lhs < rhs
            }
        }
    }

    private static func trailOrder(_ trail: Trail) -> [String] {
        trail.segments.flatMap(\.nodeIds)
    }
}

import Foundation

/// An edge inside one course segment that runs against that course's unit order — reported, never a
/// failure (L0-T, `contracts/graph-constraints.md` v1.1.0).
public struct TrailWarning: Equatable {
    public let courseCode: String
    public let from: String
    public let to: String
}

/// The result of `MarkerTrail.generateTrail`. `event` is always `.expeditionTrailGenerated` — callers
/// that also changed the marker in the same operation (`setMarker`) get `.expeditionMarkerChanged` too,
/// via `SetMarkerResult.events`, rather than this type growing a second event slot.
public struct TrailGenerationReport: Equatable {
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let event: CoreEvent
}

/// The result of `MarkerTrail.setMarker`.
public struct SetMarkerResult: Equatable {
    public let marker: Marker
    public let trail: Trail
    public let warnings: [TrailWarning]
    public let events: [CoreEvent]
}

/// The result of `MarkerTrail.reconcileMarker` (W7). `code` is `.mapMarkerOffTrail` when the persisted
/// marker did not resolve; `Core` returns this as data only and surfaces no text (I14, Q-D ruling).
public struct MarkerReconciliationResult: Equatable {
    public let marker: Marker
    public let code: CoreError?
}

/// The result of `MarkerTrail.reconcileNodeIds` (W7). `ignoredNodeIds` are node ids present in the
/// caller's `nodes` dict but absent from the installed bundle — the caller keeps them in `StudentState`
/// unchanged (never deletes) and simply excludes them from any bundle-dependent computation.
public struct NodeIdReconciliationResult: Equatable {
    public let ignoredNodeIds: [String]
    public let code: CoreError?
}

/// Expedition W6 (set the course-progress marker), W8 (generate the trail, D47) and the `Core` half of
/// W7 (load-time reconciliation of a persisted marker and persisted node ids against the installed
/// bundle). Every function is a pure value transformation over its arguments — no system clock read, no
/// file I/O, no global mutable state (I14).
public enum MarkerTrail {
    /// W8 (D47), pure. Constructs one `course` segment per entry of `syllabi[]` that resolves to a
    /// course with ≥ 1 resident node in `bundle`, in `syllabi[]`'s own order, each ordered by unit order
    /// then topologically within each unit (ties by node id — step 3). If `marker.pastLastUnit == true`
    /// and the marker's own course produced a segment, appends one `extension` segment (step 6) when a
    /// downstream node exists. Throws `CoreError.expTrailInvalid` if any constructed segment fails this
    /// task's own re-derivation of L0-T (steps 3–4) — a defensive check, since construction is designed
    /// to always satisfy L0-T on an already-L0-passed bundle (§6 default).
    public static func generateTrail(
        syllabi: [String], marker: Marker, bundle: ContentBundle
    ) throws -> TrailGenerationReport {
        let index = GraphIndex(bundle: bundle)
        var segments: [TrailSegment] = []
        var warnings: [TrailWarning] = []
        for courseCode in syllabi {
            guard let built = buildCourseSegment(courseCode: courseCode, index: index) else { continue }
            guard courseSegmentViolations(built.segment, index: index).isEmpty else {
                throw CoreError.expTrailInvalid
            }
            segments.append(built.segment)
            warnings += built.warnings
        }
        if marker.pastLastUnit == true,
            let markerSegment = segments.first(where: {
                $0.kind == .course && $0.courseCode == marker.courseCode
            }),
            let extensionSegment = buildExtensionSegment(
                afterCourseCode: marker.courseCode, precedingNodeIds: markerSegment.nodeIds, index: index)
        {
            guard
                extensionSegmentViolations(
                    extensionSegment, precedingNodeIds: markerSegment.nodeIds, index: index
                ).isEmpty
            else { throw CoreError.expTrailInvalid }
            segments.append(extensionSegment)
        }
        return TrailGenerationReport(
            trail: Trail(segments: segments), warnings: warnings, event: .expeditionTrailGenerated)
    }

    /// W6. Builds the new `Marker` from the given course/unit/`pastLastUnit`, then calls
    /// `generateTrail(syllabi:marker:bundle:)` with it. When `pastLastUnit` is `true`, the marker's
    /// `unitId` is the course's last unit in `bundle` whatever `unitId` the caller passed
    /// (`contracts/interaction-contract.md` § 3: "setting it writes the course's last unit as
    /// `unit_id`"); if the course is absent from `bundle` or has no units, the caller's `unitId` is kept
    /// and W7's `reconcileMarker` classifies the marker. Throws (and returns nothing) if trail generation
    /// throws — the caller's previously-held marker AND trail both stay untouched on failure (this
    /// function does not partially apply the marker change).
    public static func setMarker(
        courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
    ) throws -> SetMarkerResult {
        var resolvedUnitId = unitId
        if pastLastUnit,
            let lastUnit = bundle.courses.courses.first(where: { $0.courseCode == courseCode })?.units.last
        {
            resolvedUnitId = lastUnit.unitId
        }
        let marker = Marker(courseCode: courseCode, unitId: resolvedUnitId, pastLastUnit: pastLastUnit)
        let report = try generateTrail(syllabi: syllabi, marker: marker, bundle: bundle)
        return SetMarkerResult(
            marker: marker, trail: report.trail, warnings: report.warnings,
            events: [.expeditionMarkerChanged, .expeditionTrailGenerated])
    }

    /// Q-D default: the first unit of the first course in `syllabi[]` present in `bundle`, with
    /// `pastLastUnit: false`. `nil` if no course in `syllabi[]` resolves.
    public static func defaultMarker(syllabi: [String], bundle: ContentBundle) -> Marker? {
        for courseCode in syllabi {
            guard let course = bundle.courses.courses.first(where: { $0.courseCode == courseCode }),
                let firstUnit = course.units.first
            else { continue }
            return Marker(courseCode: courseCode, unitId: firstUnit.unitId, pastLastUnit: false)
        }
        return nil
    }

    /// W7 (Q-D). Off-trail iff `marker.courseCode ∉ syllabi`, or the course is absent from `bundle`, or
    /// `marker.unitId` is not one of that course's `units[]`. On-trail: returns `marker` unchanged,
    /// `code: nil`. Off-trail: returns `defaultMarker(syllabi:bundle:)` with `code: .mapMarkerOffTrail`
    /// when that resolves, else the **unchanged input marker** with `code: .mapMarkerOffTrail` (no
    /// resolvable course — Q-D's "keep the stored marker" branch).
    public static func reconcileMarker(
        _ marker: Marker, syllabi: [String], bundle: ContentBundle
    ) -> MarkerReconciliationResult {
        guard isMarkerOffTrail(marker, syllabi: syllabi, bundle: bundle) else {
            return MarkerReconciliationResult(marker: marker, code: nil)
        }
        if let fallback = defaultMarker(syllabi: syllabi, bundle: bundle) {
            return MarkerReconciliationResult(marker: fallback, code: .mapMarkerOffTrail)
        }
        return MarkerReconciliationResult(marker: marker, code: .mapMarkerOffTrail)
    }

    /// W7. `ignoredNodeIds` = the keys of `nodes` absent from `bundle`'s node set, sorted ascending for
    /// determinism. `code: .expNodeNotInGraph` iff non-empty.
    public static func reconcileNodeIds(
        nodes: [String: NodeState], bundle: ContentBundle
    ) -> NodeIdReconciliationResult {
        let known = Set(bundle.nodes.nodes.map(\.id))
        let ignored = nodes.keys.filter { !known.contains($0) }.sorted()
        return NodeIdReconciliationResult(
            ignoredNodeIds: ignored, code: ignored.isEmpty ? nil : .expNodeNotInGraph)
    }

    // MARK: - Private construction helpers (step 3)

    /// A node is resident in course `X` iff its `expectationCodes` array (may be `nil`) contains ≥ 1
    /// entry whose `courseCode == X`.
    private static func residentNodeIds(course: Course, index: GraphIndex) -> Set<String> {
        Set(
            index.nodesById.values
                .filter { node in
                    (node.expectationCodes ?? []).contains { $0.courseCode == course.courseCode }
                }
                .map(\.id))
    }

    /// A node's unit index within course `X` is the 0-based index into `course.units` of the unit named
    /// by the node's lowest-ordered expectation code for `X` (02.3's own decision default).
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

    /// Kahn's algorithm with id-ordered tie-break among zero-indegree candidates (02.3 §6) — NOT a
    /// whole-list sort by id.
    private static func topoOrder(_ nodeIds: Set<String>, edges: [Edge]) -> [String] {
        var indegree: [String: Int] = Dictionary(uniqueKeysWithValues: nodeIds.map { ($0, 0) })
        var adjacency: [String: [String]] = [:]
        for edge in edges where nodeIds.contains(edge.from) && nodeIds.contains(edge.to) {
            adjacency[edge.from, default: []].append(edge.to)
            indegree[edge.to, default: 0] += 1
        }
        var result: [String] = []
        var available = Set(nodeIds.filter { indegree[$0] == 0 })
        while let next = available.sorted().first {
            available.remove(next)
            result.append(next)
            for successor in adjacency[next] ?? [] {
                indegree[successor, default: 0] -= 1
                if indegree[successor] == 0 { available.insert(successor) }
            }
        }
        // result.count < nodeIds.count only if a cycle exists in this induced subgraph — impossible on
        // an already-L0-passed bundle, but the caller does not assume this: it simply returns whatever
        // partial order results, and courseSegmentViolations / extensionSegmentViolations (step 4)
        // independently catch the inconsistency and raise EXP_TRAIL_INVALID.
        return result
    }

    /// Group `nodeIds` by unit index, emit each unit's nodes (topologically ordered) in unit-index
    /// order.
    private static func orderedNodes(_ nodeIds: Set<String>, course: Course, index: GraphIndex) -> [String] {
        var byUnit: [Int: [String]] = [:]
        for nodeId in nodeIds {
            guard let idx = unitIndex(nodeId: nodeId, course: course, index: index) else { continue }
            byUnit[idx, default: []].append(nodeId)
        }
        var ordered: [String] = []
        for unitIdx in course.units.indices {
            guard let inUnit = byUnit[unitIdx] else { continue }
            ordered += topoOrder(Set(inUnit), edges: index.edges)
        }
        return ordered
    }

    /// Build one course segment plus its against-unit-order warnings — a warning fires for any edge
    /// inside the resident set (any two units, not just adjacent) whose target's unit index is strictly
    /// less than its source's.
    private static func buildCourseSegment(
        courseCode: String, index: GraphIndex
    ) -> (segment: TrailSegment, warnings: [TrailWarning])? {
        guard let course = index.coursesByCode[courseCode] else { return nil }
        let resident = residentNodeIds(course: course, index: index)
        guard !resident.isEmpty else { return nil }
        let ordered = orderedNodes(resident, course: course, index: index)
        var warnings: [TrailWarning] = []
        for edge in index.edges where resident.contains(edge.from) && resident.contains(edge.to) {
            guard let fromIdx = unitIndex(nodeId: edge.from, course: course, index: index),
                let toIdx = unitIndex(nodeId: edge.to, course: course, index: index)
            else { continue }
            if toIdx < fromIdx {
                warnings.append(TrailWarning(courseCode: courseCode, from: edge.from, to: edge.to))
            }
        }
        return (TrailSegment(kind: .course, courseCode: courseCode, nodeIds: ordered), warnings)
    }

    // MARK: - Private validation helpers (step 4)

    /// Re-derives L0-T from the constructed segment alone, without reusing any intermediate value from
    /// step 3 (defense in depth, matching `L0Checker`'s own style of computing each rule fresh from
    /// `GraphIndex`).
    private static func courseSegmentViolations(_ segment: TrailSegment, index: GraphIndex) -> [String] {
        guard let courseCode = segment.courseCode, let course = index.coursesByCode[courseCode] else {
            return ["segment names an unknown course"]
        }
        var position: [String: Int] = [:]
        for (i, id) in segment.nodeIds.enumerated() { position[id] = i }
        var violations: [String] = []
        // A course segment is exactly that course's nodes resident in the bundle
        // (`contracts/interaction-contract.md` §3, quoted §3 of this task's spec) — a segment missing a
        // resident node (e.g. a Kahn's-algorithm topological sort truncated by an undetected cycle in
        // the induced subgraph) is itself a violation, independent of any single edge's ordering.
        let resident = residentNodeIds(course: course, index: index)
        if Set(segment.nodeIds) != resident {
            violations.append("segment node set does not match the course's resident nodes")
        }
        for edge in index.edges {
            guard let fromPos = position[edge.from], let toPos = position[edge.to] else { continue }
            guard let fromIdx = unitIndex(nodeId: edge.from, course: course, index: index),
                let toIdx = unitIndex(nodeId: edge.to, course: course, index: index),
                fromIdx == toIdx
            else { continue }  // cross-unit edges are never a within-unit-topological-order violation
            if fromPos > toPos {
                violations.append("\(edge.from)-->-\(edge.to) violates within-unit topological order")
            }
        }
        return violations
    }

    private static func extensionSegmentViolations(
        _ segment: TrailSegment, precedingNodeIds: [String], index: GraphIndex
    ) -> [String] {
        var reachable = Set(precedingNodeIds)
        var queue = precedingNodeIds
        while let current = queue.popLast() {
            for edge in index.edgesByFrom[current] ?? [] where !reachable.contains(edge.to) {
                reachable.insert(edge.to)
                queue.append(edge.to)
            }
        }
        return segment.nodeIds.filter { !reachable.contains($0) }
            .map { "\($0) not reachable from the preceding segment" }
    }

    // MARK: - Private extension-building helpers (step 6)

    /// Terminal nodes of the preceding segment = its own nodes with no outgoing edge to another node of
    /// that same segment.
    private static func buildExtensionSegment(
        afterCourseCode: String, precedingNodeIds: [String], index: GraphIndex
    ) -> TrailSegment? {
        guard let course = index.coursesByCode[afterCourseCode] else { return nil }
        let precedingSet = Set(precedingNodeIds)
        let terminals = precedingNodeIds.filter { nodeId in
            !(index.edgesByFrom[nodeId] ?? []).contains { precedingSet.contains($0.to) }
        }

        var reachable: Set<String> = []
        var visited = Set(terminals)
        var queue = terminals
        while let current = queue.popLast() {
            for edge in index.edgesByFrom[current] ?? [] where !visited.contains(edge.to) {
                visited.insert(edge.to)
                if !precedingSet.contains(edge.to) { reachable.insert(edge.to) }
                queue.append(edge.to)
            }
        }

        for nextCode in course.nextCourses {
            guard let nextCourse = index.coursesByCode[nextCode] else { continue }
            let resident = residentNodeIds(course: nextCourse, index: index)
            let hit = reachable.intersection(resident)
            guard !hit.isEmpty else { continue }
            return TrailSegment(
                kind: .extension, courseCode: nextCode,
                nodeIds: orderedNodes(hit, course: nextCourse, index: index))
        }

        let undergraduate = reachable.filter { nodeId in
            (index.nodesById[nodeId]?.expectationCodes ?? []).isEmpty
        }
        guard !undergraduate.isEmpty else { return nil }
        return TrailSegment(
            kind: .extension, courseCode: nil, nodeIds: topoOrder(undergraduate, edges: index.edges))
    }

    // MARK: - Private reconciliation helpers (step 7)

    private static func isMarkerOffTrail(_ marker: Marker, syllabi: [String], bundle: ContentBundle) -> Bool {
        guard syllabi.contains(marker.courseCode) else { return true }
        guard let course = bundle.courses.courses.first(where: { $0.courseCode == marker.courseCode }) else {
            return true
        }
        return !course.units.contains { $0.unitId == marker.unitId }
    }
}

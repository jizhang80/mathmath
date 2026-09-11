import Foundation

/// The pure derivation rendered each frame (`docs/domains/map.md` § Core entities `MapViewModel`):
/// regions with a tint from the fraction of their trail-resident nodes cleared, rivers, trail segments
/// with the position indicator, landmarks, horizon regions and the focus frame. Derived in `Core` from
/// a `ContentBundle` and a `StudentState`; never persisted; the renderer holds nothing this model does
/// not (I14). No I/O, no clock read, no model call (I2) — `today` is always the caller's injected
/// `CalendarDay`.
public struct MapViewModel: Equatable {
    public let regions: [RegionView]
    public let nodes: [NodeView]
    public let rivers: [River]
    public let trailSegments: [TrailSegmentView]
    public let positionIndicatorNodeId: String?
    public let landmarks: [LandmarkView]
    public let focusFrame: FocusFrame
}

/// A map region as drawn (`contracts/domain-glossary.md` § Region). `clearedFraction == nil` is pure
/// fog — an empty region, a horizon region, or a populated region with no trail-resident nodes (map Q2).
public struct RegionView: Equatable {
    public let id: RegionId
    public let horizon: Bool
    public let clearedFraction: Double?
}

/// The single action offered on a node's panel (`docs/domains/map.md` § W2 step 2).
public enum NodeAction: Equatable {
    case checkHere
    case include
}

/// A node as drawn (`docs/domains/map.md` § Core entities `NodeView`): its coordinates, its region, its
/// mastery state projected to a fog level (never overridden for an upstream node,
/// `contracts/interaction-contract.md` § 3 "keep their mastery"), a due ring, whether it lies upstream
/// of the marker, and the single offered action.
public struct NodeView: Equatable {
    public let id: String
    public let regionId: RegionId
    public let position: Point
    public let fogLevel: Mastery
    public let due: Bool
    public let upstream: Bool
    public let action: NodeAction?
}

/// One edge rendered as a river (`contracts/domain-glossary.md` § Edge).
public struct River: Equatable {
    public let from: String
    public let to: String
}

/// One trail segment as drawn — a course segment (solid) or an extension (dashed).
public struct TrailSegmentView: Equatable {
    public let courseCode: String?
    public let nodeIds: [String]
    public let dashed: Bool
}

/// One landmark as drawn (`docs/domains/map.md`; D22).
public struct LandmarkView: Equatable {
    public let id: String
    public let position: Point
    public let nodeIds: [String]
}

/// The trail-first (D44) camera frame: the bounding box of the marker's-unit-∪-next-unit window (or,
/// past the last unit, the extension segment's nodes).
public struct FocusFrame: Equatable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double
}

/// What `labelSet(atZoom:)` shows at a given zoom scale (map Q4).
public struct LabelSet: Equatable {
    public let regionNames: Bool
    public let nodeNames: Bool
    public let landmarkNames: Bool
}

extension MapViewModel {
    /// [ESTIMATE: the zoom multiple, relative to a whole-continent overview of 1.0, at which a node's
    /// drawn diameter is judged to exceed the ~44 pt minimum tap target (map Q4); no on-screen diameter
    /// model exists yet at this layer, so this is a placeholder the rendering task (03.10) may tune].
    public static let nodeNameZoomThreshold: Double = 3.0

    /// The single public entry point: a pure derivation from `(bundle, state, today)`. Builds one
    /// `GraphIndex` and one `edgesByTo` grouping, then computes the window and the fringe by calling
    /// `Expedition.scopeWindow`/`Expedition.fringeNodeIds` directly (I14 single-source, AC14) — this
    /// file contains no second implementation of either. Never throws, never reads the clock.
    public static func derive(bundle: ContentBundle, state: StudentState, today: CalendarDay)
        -> MapViewModel
    {
        let index = GraphIndex(bundle: bundle)
        let edgesByTo = Dictionary(grouping: index.edges, by: \.to)

        let window = Expedition.scopeWindow(
            marker: state.marker, trail: state.trail, index: index, unitExpeditionUnitId: nil)
        let upstream = upstreamNodeIds(marker: state.marker, bundle: bundle, index: index)
        let fringe = Expedition.fringeNodeIds(
            state: state, bundle: bundle, index: index, edgesByTo: edgesByTo, marker: state.marker,
            trail: state.trail, unitExpeditionUnitId: nil)

        let trailNodeIds = Set(state.trail.segments.flatMap(\.nodeIds))

        let regions = bundle.regions.regions.map { region -> RegionView in
            let regionNodeIds = bundle.nodes.nodes
                .filter { $0.regionId == region.id && trailNodeIds.contains($0.id) }
                .map(\.id)
            let total = regionNodeIds.count
            let clearedCount = regionNodeIds.filter { state.nodes[$0]?.mastery == .cleared }.count
            let clearedFraction: Double? =
                total == 0 ? nil : Double(clearedCount) / Double(total)
            return RegionView(id: region.id, horizon: region.horizon, clearedFraction: clearedFraction)
        }

        let nodes = bundle.nodes.nodes.map { node -> NodeView in
            let mastery = state.nodes[node.id]?.mastery ?? .fog
            let isUpstream = upstream.contains(node.id)
            let due =
                mastery == .cleared
                && (state.nodes[node.id]?.nextDue.map { $0 <= today.iso } ?? false)
            let action: NodeAction?
            if mastery == .cleared {
                action = nil
            } else if mastery == .blocked {
                action = .checkHere
            } else if isUpstream {
                action = .checkHere
            } else if fringe.contains(node.id) {
                action = .include
            } else {
                action = nil
            }
            return NodeView(
                id: node.id, regionId: node.regionId, position: node.position, fogLevel: mastery,
                due: due, upstream: isUpstream, action: action)
        }

        let rivers = bundle.edges.edges.map { River(from: $0.from, to: $0.to) }

        let trailSegments = state.trail.segments.map { segment in
            TrailSegmentView(
                courseCode: segment.courseCode, nodeIds: segment.nodeIds,
                dashed: segment.kind == .extension)
        }

        let positionIndicatorNodeId = state.trail.segments.flatMap(\.nodeIds).first { id in
            !upstream.contains(id) && (state.nodes[id]?.mastery ?? .fog) != .cleared
        }

        let landmarks = bundle.landmarks.landmarks.map { landmark in
            LandmarkView(id: landmark.id, position: landmark.position, nodeIds: landmark.nodeIds)
        }

        let positions = window.compactMap { index.nodesById[$0]?.position }
        let focusFrame: FocusFrame
        if positions.isEmpty {
            focusFrame = FocusFrame(minX: 0, minY: 0, maxX: 1, maxY: 1)
        } else {
            focusFrame = FocusFrame(
                minX: positions.map(\.x).min() ?? 0, minY: positions.map(\.y).min() ?? 0,
                maxX: positions.map(\.x).max() ?? 1, maxY: positions.map(\.y).max() ?? 1)
        }

        return MapViewModel(
            regions: regions, nodes: nodes, rivers: rivers, trailSegments: trailSegments,
            positionIndicatorNodeId: positionIndicatorNodeId, landmarks: landmarks,
            focusFrame: focusFrame)
    }

    /// The label set for a given zoom scale (map Q4): landmark names always, node names at or above the
    /// threshold, region names otherwise.
    public func labelSet(atZoom zoomScale: Double) -> LabelSet {
        let nodeNames = zoomScale >= MapViewModel.nodeNameZoomThreshold
        return LabelSet(regionNames: !nodeNames, nodeNames: nodeNames, landmarkNames: true)
    }

    /// `contracts/interaction-contract.md` § 3 "nodes of the course are then upstream of the marker"
    /// (past the last unit) / "upstream of the marker" (ordinary case) — a concept `Expedition.swift`
    /// does not itself compute, since `compose` never needs it. Calls `Expedition.residentNodeIds` /
    /// `Expedition.unitIndex` directly rather than restating either body (I14 single-source, AC14).
    private static func upstreamNodeIds(marker: Marker, bundle: ContentBundle, index: GraphIndex)
        -> Set<String>
    {
        guard let course = index.coursesByCode[marker.courseCode] else { return [] }
        let resident = Expedition.residentNodeIds(course: course, index: index)
        if marker.pastLastUnit == true { return resident }
        guard let markerUnitIdx = course.units.firstIndex(where: { $0.unitId == marker.unitId }) else {
            return []
        }
        return Set(
            resident.filter { id in
                guard let idx = Expedition.unitIndex(nodeId: id, course: course, index: index) else {
                    return false
                }
                return idx < markerUnitIdx
            })
    }
}

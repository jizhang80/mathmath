import Core
import Foundation
import SwiftUI

/// The map (`docs/domains/map.md` § UI surfaces): a `Canvas` rendering of a `MapViewModel` value already
/// fully derived in `Core`. Draws regions, rivers, trail segments, nodes (fog/blocked/cleared, due ring),
/// the position indicator, landmarks and the greyed horizon labels; resolves a tap to the id of the
/// `NodeView` placed there. Computes no domain state of its own (I14) — every fog, due, upstream, action
/// and label-set decision is read from `mapViewModel`, never re-derived here. The only state is the
/// ephemeral pan/zoom camera (D24: a basic SwiftUI transition, never a game-style mechanic).
struct MapCanvasView: View {
    let mapViewModel: MapViewModel
    let onNodeTap: (String) -> Void

    @State private var camera = MapCamera(pan: .zero, zoomScale: 1.0)
    @State private var hasFramedInitialCamera = false

    // [ESTIMATE: half of Apple's ~44 pt minimum tap target (map Q4's own estimate), tunable]
    private static let nodeTapRadius: CGFloat = 22
    // [ESTIMATE: dash pattern for an extension trail segment, tunable during simulator review]
    private static let extensionDashPattern: [CGFloat] = [6, 4]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                draw(mapViewModel: mapViewModel, camera: camera, canvasSize: size, into: &context)
            }
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    handleTap(at: value.location, canvasSize: geometry.size)
                }
            )
            .onAppear {
                guard !hasFramedInitialCamera else { return }
                camera = MapCamera.initial(focusFrame: mapViewModel.focusFrame, canvasSize: geometry.size)
                hasFramedInitialCamera = true
            }
            .animation(.easeInOut, value: mapViewModel)
        }
    }

    /// Updates `camera` live on every drag frame (§4 step 5) via `MapCamera.applyDrag(translation:)`, which
    /// carries the in-flight gesture baseline itself — no stored property beyond `camera`/
    /// `hasFramedInitialCamera` (AC1).
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                camera.applyDrag(translation: value.translation)
            }
            .onEnded { _ in
                camera.endGesture()
            }
    }

    /// Updates `camera` live on every magnification frame via `MapCamera.applyMagnification(_:)`, which
    /// clamps to `minZoomScale`/`maxZoomScale` and carries the in-flight gesture baseline itself.
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                camera.applyMagnification(Double(value))
            }
            .onEnded { _ in
                camera.endGesture()
            }
    }

    // MARK: - Tap resolution (AC5)

    private func handleTap(at location: CGPoint, canvasSize: CGSize) {
        let bundleTapPoint = camera.bundlePoint(for: location, canvasSize: canvasSize)
        let tapScreenPoint = camera.screenPoint(
            forBundleX: bundleTapPoint.x, y: bundleTapPoint.y, canvasSize: canvasSize)

        var nearest: NodeView?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for node in mapViewModel.nodes {
            let nodeScreenPoint = camera.screenPoint(for: node.position, canvasSize: canvasSize)
            let distance = hypot(nodeScreenPoint.x - tapScreenPoint.x, nodeScreenPoint.y - tapScreenPoint.y)
            if distance < nearestDistance {
                nearestDistance = distance
                nearest = node
            }
        }

        if let nearest, nearestDistance <= Self.nodeTapRadius {
            onNodeTap(nearest.id)
        }
    }

    // MARK: - Drawing (§4 step 7, back-to-front)

    private func draw(
        mapViewModel: MapViewModel, camera: MapCamera, canvasSize: CGSize, into context: inout GraphicsContext
    ) {
        let nodesById = Dictionary(uniqueKeysWithValues: mapViewModel.nodes.map { ($0.id, $0) })
        let labelSet = mapViewModel.labelSet(atZoom: camera.zoomScale)

        drawRegions(
            mapViewModel.regions, nodesById: nodesById, labelSet: labelSet, camera: camera,
            canvasSize: canvasSize, into: &context)
        drawHorizonRegions(mapViewModel.regions, labelSet: labelSet, canvasSize: canvasSize, into: &context)
        drawRivers(
            mapViewModel.rivers, nodesById: nodesById, camera: camera, canvasSize: canvasSize, into: &context)
        drawTrailSegments(
            mapViewModel.trailSegments, nodesById: nodesById, camera: camera, canvasSize: canvasSize,
            into: &context)
        drawNodes(
            mapViewModel.nodes, labelSet: labelSet, camera: camera, canvasSize: canvasSize, into: &context)
        drawPositionIndicator(
            mapViewModel.positionIndicatorNodeId, nodesById: nodesById, camera: camera,
            canvasSize: canvasSize,
            into: &context)
        drawLandmarks(
            mapViewModel.landmarks, labelSet: labelSet, camera: camera, canvasSize: canvasSize, into: &context
        )
    }

    private func drawRegions(
        _ regions: [RegionView], nodesById: [String: NodeView], labelSet: LabelSet, camera: MapCamera,
        canvasSize: CGSize, into context: inout GraphicsContext
    ) {
        for region in regions where !region.horizon {
            let memberPositions = nodesById.values
                .filter { $0.regionId == region.id }
                .map { camera.screenPoint(for: $0.position, canvasSize: canvasSize) }
            guard let minX = memberPositions.map(\.x).min(), let maxX = memberPositions.map(\.x).max(),
                let minY = memberPositions.map(\.y).min(), let maxY = memberPositions.map(\.y).max()
            else { continue }

            let rect = CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
            let tint: Color =
                region.clearedFraction.map { Color.green.opacity(0.15 + 0.5 * $0) }
                ?? Color.gray.opacity(0.15)
            context.fill(Path(rect), with: .color(tint))

            if labelSet.regionNames {
                context.draw(
                    Text(region.id.rawValue).font(.caption).foregroundColor(.secondary),
                    at: CGPoint(x: rect.midX, y: rect.minY))
            }
        }
    }

    private func drawHorizonRegions(
        _ regions: [RegionView], labelSet: LabelSet, canvasSize: CGSize, into context: inout GraphicsContext
    ) {
        guard labelSet.regionNames else { return }
        let horizonRegions = regions.filter(\.horizon)
        for (index, region) in horizonRegions.enumerated() {
            let position = CGPoint(x: 16 + CGFloat(index) * 90, y: 16)
            context.draw(
                Text(region.id.rawValue).font(.caption2).foregroundColor(Color.gray.opacity(0.6)),
                at: position)
        }
    }

    private func drawRivers(
        _ rivers: [River], nodesById: [String: NodeView], camera: MapCamera, canvasSize: CGSize,
        into context: inout GraphicsContext
    ) {
        for river in rivers {
            guard let from = nodesById[river.from], let to = nodesById[river.to] else { continue }
            var path = Path()
            path.move(to: camera.screenPoint(for: from.position, canvasSize: canvasSize))
            path.addLine(to: camera.screenPoint(for: to.position, canvasSize: canvasSize))
            context.stroke(path, with: .color(Color.gray.opacity(0.4)), lineWidth: 1)
        }
    }

    private func drawTrailSegments(
        _ segments: [TrailSegmentView], nodesById: [String: NodeView], camera: MapCamera, canvasSize: CGSize,
        into context: inout GraphicsContext
    ) {
        for segment in segments {
            let points = segment.nodeIds.compactMap { nodesById[$0]?.position }
                .map { camera.screenPoint(for: $0, canvasSize: canvasSize) }
            guard points.count > 1 else { continue }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
            let style: StrokeStyle =
                segment.dashed
                ? StrokeStyle(lineWidth: 2, dash: Self.extensionDashPattern) : StrokeStyle(lineWidth: 2)
            context.stroke(path, with: .color(.blue), style: style)
        }
    }

    private func drawNodes(
        _ nodes: [NodeView], labelSet: LabelSet, camera: MapCamera, canvasSize: CGSize,
        into context: inout GraphicsContext
    ) {
        // [ESTIMATE: fixed on-screen node radius regardless of zoom, tunable during simulator review]
        let nodeRadius: CGFloat = 7
        for node in nodes {
            let point = camera.screenPoint(for: node.position, canvasSize: canvasSize)
            let rect = CGRect(
                x: point.x - nodeRadius, y: point.y - nodeRadius, width: nodeRadius * 2,
                height: nodeRadius * 2)
            let fill: Color
            switch node.fogLevel {
            case .fog: fill = Color.gray.opacity(0.4)
            case .blocked: fill = Color.red
            case .cleared: fill = Color.green
            }
            context.fill(Path(ellipseIn: rect), with: .color(fill))

            if node.due {
                let ringRect = rect.insetBy(dx: -3, dy: -3)
                context.stroke(Path(ellipseIn: ringRect), with: .color(.orange), lineWidth: 2)
            }

            if labelSet.nodeNames {
                context.draw(
                    Text(node.id).font(.caption2),
                    at: CGPoint(x: point.x, y: point.y + nodeRadius + 8))
            }
        }
    }

    private func drawPositionIndicator(
        _ positionIndicatorNodeId: String?, nodesById: [String: NodeView], camera: MapCamera,
        canvasSize: CGSize,
        into context: inout GraphicsContext
    ) {
        guard let id = positionIndicatorNodeId, let node = nodesById[id] else { return }
        let point = camera.screenPoint(for: node.position, canvasSize: canvasSize)
        let rect = CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24)
        context.stroke(Path(ellipseIn: rect), with: .color(.purple), lineWidth: 3)
    }

    private func drawLandmarks(
        _ landmarks: [LandmarkView], labelSet: LabelSet, camera: MapCamera, canvasSize: CGSize,
        into context: inout GraphicsContext
    ) {
        for landmark in landmarks {
            let point = camera.screenPoint(for: landmark.position, canvasSize: canvasSize)
            let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fill(Path(rect), with: .color(.orange))

            if labelSet.landmarkNames {
                context.draw(
                    Text(landmark.id).font(.caption2).foregroundColor(.orange),
                    at: CGPoint(x: point.x, y: point.y - 12))
            }
        }
    }
}

import Foundation

/// Deterministic, region-constrained force layout (I14/D33 — pure function, no ambient state, no
/// global RNG).
public enum LayoutEngine {
    /// Every returned position lies inside its own node's region polygon (L0-7). A node whose
    /// `region_id` cannot be resolved to a non-horizon `Region` in `regions` throws `mapRegionUnknown`
    /// (L0-6) rather than being clamped to a guessed position. `rng` is injected: callers control
    /// determinism directly — two calls seeded identically produce byte-identical results; two calls
    /// seeded differently produce different results for any node lacking a valid `layout_hint`.
    public static func layout(
        nodes: [Node],
        regions: [Region],
        config: LayoutConfig = LayoutConfig(),
        rng: inout SeededGenerator
    ) throws -> [String: Point] {
        let regionsById = Dictionary(uniqueKeysWithValues: regions.map { ($0.id, $0) })

        var polygonByNodeId: [String: [Point]] = [:]
        for node in nodes {
            guard let region = regionsById[node.regionId], region.horizon == false else {
                throw CoreError.mapRegionUnknown
            }
            guard region.polygon.count >= 3 else {
                throw CoreError.mapLayoutMissing
            }
            polygonByNodeId[node.id] = region.polygon
        }

        var current: [String: Point] = [:]
        var anchor: [String: Point] = [:]
        for node in nodes {
            let polygon = polygonByNodeId[node.id, default: []]
            let initial = try initialPosition(
                for: node, polygon: polygon, config: config, rng: &rng
            )
            current[node.id] = initial
            anchor[node.id] = initial
        }

        for iteration in 0..<config.iterationCount {
            let step = config.maxStepFraction * pow(config.coolingFactor, Double(iteration))
            var next: [String: Point] = [:]
            for node in nodes {
                let polygon = polygonByNodeId[node.id, default: []]
                let position = current[node.id, default: Point(x: 0, y: 0)]
                var force = attractionForce(
                    from: position, toward: anchor[node.id, default: position], config: config
                )
                for other in nodes where other.id != node.id {
                    let otherPosition = current[other.id, default: Point(x: 0, y: 0)]
                    force = add(force, repulsionForce(from: otherPosition, to: position, config: config))
                }
                let clamped = clampMagnitude(force, to: step)
                let proposal = add(position, clamped)
                if Polygon.contains(proposal, in: polygon, epsilon: config.boundaryEpsilon) {
                    next[node.id] = proposal
                } else {
                    next[node.id] = position
                }
            }
            current = next
        }

        for node in nodes {
            let polygon = polygonByNodeId[node.id, default: []]
            let position = current[node.id, default: Point(x: 0, y: 0)]
            guard Polygon.contains(position, in: polygon, epsilon: config.boundaryEpsilon) else {
                throw CoreError.mapLayoutMissing
            }
        }

        return current
    }

    /// Step 3 of the algorithm: the initial position (and anchor) for a single node — its `layout_hint`
    /// if present and contained in its region's polygon, otherwise a rejection-sampled point inside the
    /// polygon's bounding box, falling back to the centroid (if contained) or the polygon's first vertex.
    private static func initialPosition(
        for node: Node, polygon: [Point], config: LayoutConfig, rng: inout SeededGenerator
    ) throws -> Point {
        if let hint = node.layoutHint,
            Polygon.contains(hint, in: polygon, epsilon: config.boundaryEpsilon)
        {
            return hint
        }

        let box = boundingBox(of: polygon)
        for _ in 0..<config.maxRandomSamples {
            let candidate = Point(
                x: Double.random(in: box.minX...box.maxX, using: &rng),
                y: Double.random(in: box.minY...box.maxY, using: &rng)
            )
            if Polygon.contains(candidate, in: polygon, epsilon: config.boundaryEpsilon) {
                return candidate
            }
        }

        let centroid = Polygon.centroid(of: polygon)
        if Polygon.contains(centroid, in: polygon, epsilon: config.boundaryEpsilon) {
            return centroid
        }
        guard let firstVertex = polygon.first else {
            throw CoreError.mapLayoutMissing
        }
        return firstVertex
    }

    private static func boundingBox(
        of polygon: [Point]
    ) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        var minX = polygon[0].x
        var maxX = polygon[0].x
        var minY = polygon[0].y
        var maxY = polygon[0].y
        for point in polygon {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return (minX, maxX, minY, maxY)
    }

    private static func add(_ a: Point, _ b: Point) -> Point {
        Point(x: a.x + b.x, y: a.y + b.y)
    }

    private static func attractionForce(
        from position: Point, toward anchor: Point, config: LayoutConfig
    ) -> Point {
        Point(
            x: config.attractionStrength * (anchor.x - position.x),
            y: config.attractionStrength * (anchor.y - position.y)
        )
    }

    /// The force `to` experiences, pushing it away from `from`.
    private static func repulsionForce(from: Point, to: Point, config: LayoutConfig) -> Point {
        let deltaX = to.x - from.x
        let deltaY = to.y - from.y
        let rawDistance = (deltaX * deltaX + deltaY * deltaY).squareRoot()
        let distance = max(rawDistance, config.minimumDistance)
        let magnitude = config.repulsionStrength / (distance * distance)
        return Point(x: magnitude * deltaX / distance, y: magnitude * deltaY / distance)
    }

    private static func clampMagnitude(_ point: Point, to maxMagnitude: Double) -> Point {
        let magnitude = (point.x * point.x + point.y * point.y).squareRoot()
        guard magnitude > maxMagnitude, magnitude > 0 else {
            return point
        }
        let scale = maxMagnitude / magnitude
        return Point(x: point.x * scale, y: point.y * scale)
    }
}

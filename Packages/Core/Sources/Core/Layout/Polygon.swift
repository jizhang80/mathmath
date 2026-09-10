import Foundation

/// Point-in-polygon containment and centroid for a closed ring of ordered vertices (`contracts/schemas/
/// regions.schema.json`'s `polygon` array shape — the edge from the last vertex back to the first is
/// implicit).
public enum Polygon {
    /// Even-odd (ray-casting) point-in-polygon test, boundary-inclusive: a point lying on an edge (within
    /// `epsilon`) counts as inside.
    public static func contains(_ point: Point, in polygon: [Point], epsilon: Double) -> Bool {
        guard polygon.count >= 3 else {
            return false
        }
        if isOnBoundary(point, of: polygon, epsilon: epsilon) {
            return true
        }
        return rayCastInside(point, polygon)
    }

    /// Arithmetic-mean centroid of the polygon's vertices. Not guaranteed to lie inside a concave polygon —
    /// callers verify with `contains` before relying on it.
    public static func centroid(of polygon: [Point]) -> Point {
        guard !polygon.isEmpty else {
            return Point(x: 0, y: 0)
        }
        let sumX = polygon.reduce(0) { $0 + $1.x }
        let sumY = polygon.reduce(0) { $0 + $1.y }
        let count = Double(polygon.count)
        return Point(x: sumX / count, y: sumY / count)
    }

    private static func isOnBoundary(_ point: Point, of polygon: [Point], epsilon: Double) -> Bool {
        for index in 0..<polygon.count {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            if distanceToSegment(point, a, b) <= epsilon {
                return true
            }
        }
        return false
    }

    private static func distanceToSegment(_ point: Point, _ a: Point, _ b: Point) -> Double {
        let deltaX = b.x - a.x
        let deltaY = b.y - a.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0 else {
            return distance(point, a)
        }
        var t = ((point.x - a.x) * deltaX + (point.y - a.y) * deltaY) / lengthSquared
        t = min(max(t, 0), 1)
        let projected = Point(x: a.x + t * deltaX, y: a.y + t * deltaY)
        return distance(point, projected)
    }

    private static func distance(_ p: Point, _ q: Point) -> Double {
        let deltaX = p.x - q.x
        let deltaY = p.y - q.y
        return (deltaX * deltaX + deltaY * deltaY).squareRoot()
    }

    private static func rayCastInside(_ point: Point, _ polygon: [Point]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let vi = polygon[i]
            let vj = polygon[j]
            let crosses = (vi.y > point.y) != (vj.y > point.y)
            if crosses {
                let slopeX = (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x
                if point.x < slopeX {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }
}

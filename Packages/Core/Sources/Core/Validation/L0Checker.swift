import Foundation

/// `Core`'s single implementation of the L0 structural checks (`contracts/graph-constraints.md`,
/// L0-1 … L0-10; L0-T is EPIC 02's). Run by the pipeline at build time and by the app at load time
/// (I8) — never reimplemented by either caller.
public enum L0Checker {
    /// Reads a bundle directory via `BundleIO.read` (manifest-completeness refusal happens there —
    /// this function never re-implements it), refuses a `format_version` major mismatch, then runs
    /// `validate(bundle:)`.
    public static func validate(bundleDir: URL) throws -> L0Report {
        let bundle = try BundleIO.read(from: bundleDir)
        let bundleMajor = bundle.manifest.formatVersion.split(separator: ".").first
        let coreMajor = CoreInfo.dataFormatVersion.split(separator: ".").first
        guard bundleMajor == coreMajor else { throw CoreError.platformBundleIntegrityFailed }
        return validate(bundle: bundle)
    }

    /// Runs every L0 rule over an already-decoded bundle. Never throws — a failing rule is a
    /// `passed: false` entry in the report, not a thrown error.
    public static func validate(bundle: ContentBundle) -> L0Report {
        let index = GraphIndex(bundle: bundle)
        let checks = [
            checkAcyclic(index),
            checkCourseOrder(index),
            checkSpineCoverage(bundle, index),
            checkSourcePresence(bundle, index),
            checkStartingChain(bundle, index),
            checkRegionKnown(index),
            checkPositionInPolygon(index),
            checkUnitCoverage(bundle),
            checkCourseSuccession(bundle),
            checkLandmarkIntegrity(bundle, index),
        ]
        return L0Report(
            bundleId: bundle.manifest.bundleId,
            passed: checks.allSatisfy(\.passed),
            checks: checks,
            indegree: indegreeReport(index)
        )
    }

    /// The rule id -> `CoreError` mapping the contract's "Fails with" column states in prose (§4.3
    /// decision defaults on L0-3b and L0-8).
    public static func errorCode(forRuleId ruleId: String) -> CoreError? {
        let table: [String: CoreError] = [
            "L0-1": .graphL0Failed, "L0-2": .graphL0Failed, "L0-3a": .graphL0Failed,
            "L0-3b": .graphL0Failed, "L0-5": .graphL0Failed, "L0-6": .mapRegionUnknown,
            "L0-7": .mapLayoutMissing, "L0-8": .spineUnitEmpty, "L0-9": .graphL0Failed,
            "L0-10": .mapLandmarkUnsourced,
        ]
        return table[ruleId]
    }

    // MARK: - L0-1 acyclic

    private enum DFSColour {
        case gray
        case black
    }

    private static func checkAcyclic(_ index: GraphIndex) -> L0Check {
        var colour: [String: DFSColour] = [:]
        var stack: [String] = []
        var cycle: [String]?

        func visit(_ nodeId: String) {
            if cycle != nil { return }
            colour[nodeId] = .gray
            stack.append(nodeId)
            for edge in index.edgesByFrom[nodeId] ?? [] {
                if cycle != nil { return }
                switch colour[edge.to] {
                case .gray:
                    if let breakIndex = stack.firstIndex(of: edge.to) {
                        cycle = Array(stack[breakIndex...]) + [edge.to]
                    }
                    return
                case .black:
                    continue
                case nil:
                    visit(edge.to)
                }
            }
            stack.removeLast()
            colour[nodeId] = .black
        }

        for nodeId in index.sortedNodeIds where colour[nodeId] == nil {
            visit(nodeId)
            if cycle != nil { break }
        }

        return L0Check(id: "L0-1", passed: cycle == nil, violations: cycle ?? [])
    }

    // MARK: - L0-2 course order

    private static func checkCourseOrder(_ index: GraphIndex) -> L0Check {
        var violations: [String] = []
        for edge in index.edges {
            guard let from = index.nodesById[edge.from], let to = index.nodesById[edge.to] else { continue }
            let depthFrom = from.courses.isEmpty ? Int.max : (from.courses.map(\.depth).min() ?? Int.max)
            let depthTo = to.courses.isEmpty ? Int.max : (to.courses.map(\.depth).max() ?? Int.max)
            if depthFrom > depthTo {
                violations.append("\(edge.from)-->-\(edge.to)")
            }
        }
        return L0Check(id: "L0-2", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-3a spine coverage

    private static func checkSpineCoverage(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check {
        var violations: [String] = []

        for nodeId in index.sortedNodeIds {
            guard let node = index.nodesById[nodeId], let codes = node.expectationCodes, !codes.isEmpty else {
                continue
            }
            for entry in codes {
                let known =
                    index.coursesByCode[entry.courseCode]?.expectations.contains { $0.code == entry.code }
                    ?? false
                if !known {
                    violations.append("\(node.id):\(entry.courseCode).\(entry.code)")
                }
            }
        }

        for course in bundle.courses.courses.sorted(by: { $0.courseCode < $1.courseCode }) {
            for expectation in course.expectations {
                let covered = index.sortedNodeIds.contains { nodeId in
                    (index.nodesById[nodeId]?.expectationCodes ?? []).contains {
                        $0.courseCode == course.courseCode && $0.code == expectation.code
                    }
                }
                if !covered {
                    violations.append("\(course.courseCode).\(expectation.code)")
                }
            }
        }

        return L0Check(id: "L0-3a", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-3b source presence

    private static func checkSourcePresence(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check {
        var violations: [String] = []
        for nodeId in index.sortedNodeIds {
            guard let node = index.nodesById[nodeId] else { continue }
            if let codes = node.expectationCodes, !codes.isEmpty { continue }
            let hasSource: Bool
            if let sourceRef = node.sourceRef, !sourceRef.locator.isEmpty {
                hasSource = bundle.sources.sources.contains { $0.source == sourceRef.source }
            } else {
                hasSource = false
            }
            if !hasSource {
                violations.append(node.id)
            }
        }
        return L0Check(id: "L0-3b", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-5 starting chain connected

    private static func checkStartingChain(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check {
        let chain = bundle.manifest.startingChain
        guard chain.count > 1 else { return L0Check(id: "L0-5", passed: true, violations: []) }

        for i in 0..<(chain.count - 1) {
            let from = chain[i]
            let to = chain[i + 1]
            if !reachable(from: from, to: to, in: index) {
                return L0Check(id: "L0-5", passed: false, violations: ["\(from)-->-\(to) unreachable"])
            }
        }
        return L0Check(id: "L0-5", passed: true, violations: [])
    }

    private static func reachable(from: String, to: String, in index: GraphIndex) -> Bool {
        var visited: Set<String> = [from]
        var queue: [String] = [from]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current == to { return true }
            for edge in index.edgesByFrom[current] ?? [] where !visited.contains(edge.to) {
                visited.insert(edge.to)
                queue.append(edge.to)
            }
        }
        return false
    }

    // MARK: - L0-6 region known, non-horizon

    private static func checkRegionKnown(_ index: GraphIndex) -> L0Check {
        var violations: [String] = []
        for nodeId in index.sortedNodeIds {
            guard let node = index.nodesById[nodeId] else { continue }
            if let region = index.regionsById[node.regionId], !region.horizon {
                continue
            }
            violations.append(node.id)
        }
        return L0Check(id: "L0-6", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-7 position inside region polygon

    private static func checkPositionInPolygon(_ index: GraphIndex) -> L0Check {
        var violations: [String] = []
        for nodeId in index.sortedNodeIds {
            guard let node = index.nodesById[nodeId], let region = index.regionsById[node.regionId] else {
                continue
            }
            if !pointInPolygon(node.position, polygon: region.polygon) {
                violations.append(node.id)
            }
        }
        return L0Check(id: "L0-7", passed: violations.isEmpty, violations: violations)
    }

    private static func pointInPolygon(_ point: Point, polygon: [Point]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            if (pi.y > point.y) != (pj.y > point.y),
                point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x
            {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    // MARK: - L0-8 unit coverage

    private static func checkUnitCoverage(_ bundle: ContentBundle) -> L0Check {
        var violations: [String] = []
        for course in bundle.courses.courses.sorted(by: { $0.courseCode < $1.courseCode }) {
            for unit in course.units where unit.expectationCodes.isEmpty {
                violations.append(unit.unitId)
            }
            for expectation in course.expectations {
                let unitCount = course.units.filter { $0.expectationCodes.contains(expectation.code) }.count
                if unitCount != 1 {
                    violations.append("\(course.courseCode).\(expectation.code)")
                }
            }
        }
        return L0Check(id: "L0-8", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-9 course succession

    private static func checkCourseSuccession(_ bundle: ContentBundle) -> L0Check {
        var violations: [String] = []
        let coursesByCode = Dictionary(
            uniqueKeysWithValues: bundle.courses.courses.map { ($0.courseCode, $0) })
        let sortedCodes = coursesByCode.keys.sorted()

        for code in sortedCodes {
            for next in coursesByCode[code]?.nextCourses ?? [] where coursesByCode[next] == nil {
                violations.append(next)
            }
        }

        var colour: [String: DFSColour] = [:]
        var stack: [String] = []
        var cycle: [String]?

        func visit(_ code: String) {
            if cycle != nil { return }
            colour[code] = .gray
            stack.append(code)
            for next in coursesByCode[code]?.nextCourses ?? [] {
                if cycle != nil { return }
                guard coursesByCode[next] != nil else { continue }
                switch colour[next] {
                case .gray:
                    if let breakIndex = stack.firstIndex(of: next) {
                        cycle = Array(stack[breakIndex...]) + [next]
                    }
                    return
                case .black:
                    continue
                case nil:
                    visit(next)
                }
            }
            stack.removeLast()
            colour[code] = .black
        }

        for code in sortedCodes where colour[code] == nil {
            visit(code)
            if cycle != nil { break }
        }
        if let cycle {
            violations.append(contentsOf: cycle)
        }

        return L0Check(id: "L0-9", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-10 landmark referential integrity + https

    private static func checkLandmarkIntegrity(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check {
        var violations: [String] = []
        for landmark in bundle.landmarks.landmarks {
            let hasUnknownNode = landmark.nodeIds.contains { index.nodesById[$0] == nil }
            let notHttps = !landmark.sourceUrl.hasPrefix("https://")
            if hasUnknownNode || notHttps {
                violations.append(landmark.id)
            }
        }
        return L0Check(id: "L0-10", passed: violations.isEmpty, violations: violations)
    }

    // MARK: - L0-4 in-degree (advisory, report only)

    private static func indegreeReport(_ index: GraphIndex) -> L0Indegree {
        var inDegree: [String: Int] = [:]
        for nodeId in index.sortedNodeIds { inDegree[nodeId] = 0 }
        for edge in index.edges {
            inDegree[edge.to, default: 0] += 1
        }
        let sorted = index.sortedNodeIds.map { inDegree[$0] ?? 0 }.sorted()
        let threshold: Int
        if sorted.isEmpty {
            threshold = 0
        } else {
            let idx = max(0, Int((0.95 * Double(sorted.count)).rounded(.up)) - 1)
            threshold = sorted[idx]
        }
        let outliers = index.sortedNodeIds.filter { (inDegree[$0] ?? 0) > threshold }
        return L0Indegree(threshold: threshold, outliers: outliers)
    }
}

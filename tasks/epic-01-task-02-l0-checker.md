# Epic 01 · Task 02: `Core` L0 checker (`validate`, `L0Report`, `GraphIndex`)

---
epic: 01
task: 02
slug: l0-checker
kind: feat
risk: seam
depends_on: [01.1]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `Core` gains one deterministic, Tier-0 validation surface — `L0Checker.validate` — that checks a decoded
`ContentBundle` (task 01.1) against every L0 rule of `contracts/graph-constraints.md` (L0-1 … L0-10; L0-T is
EPIC 02's) and returns the report shape the contract fixes. A directory-taking overload performs the
manifest-completeness refusal ahead of L0 checking, reusing `BundleIO.read` rather than reimplementing it.
Every rule ships with one negative-control fixture (two for L0-3a, one per direction) proving the rule
actually detects its violation, plus a known-good fixture proving the happy path reports `passed: true` with
every non-advisory rule listed and empty violation lists present, never omitted.

Invariants in play:

- **I1** — `L0Checker` makes no correctness determination via a model; every rule is a deterministic
  structural/graph check written in Swift over already-decoded `Core` types. Nothing here lets a model output
  decide whether a bundle, node or probe item is valid.
- **I2** — `L0Checker` calls no model and is itself a Tier-0 mechanism: `core-cli validate` (task 01.4) is
  usable with zero model availability, by construction.
- **I6** — the report never carries Ministry prose: `L0Check.violations` entries are ids (node id, edge id,
  unit id, course code) only, never `paraphrase`/`explanation`/prompt text.
- **I8** — this task IS the L0 mechanism the invariant names: "every accepted graph passes the L0 checks."
  `validate` is the single implementation the pipeline (build time, task 01.4) and the app (load time, EPIC 03)
  both call — never reimplemented.
- **I9** — `validate` is fully mechanical; no human-review step is introduced; a failing rule is reported, not
  waived.
- **I14** — every new file lives under `Packages/Core/Sources/Core/Validation/`, imports `Foundation` only,
  and is covered by the existing recursive import-boundary test (`CoreTests.swift`, made recursive by task
  01.1) without further change to that test.
- **I15** — L0-10 enforces, structurally, that every landmark's `node_ids[]` resolve to existing nodes and
  `source_url` is `https`; HTTP resolution stays the pipeline's job (task 01.7).

Acceptance criteria:

- AC1: `L0Checker.validate(bundle:)` over the known-good fixture (`Fixtures/l0/valid/`) returns an `L0Report`
  with `passed == true`, `checks.count == 10` (one entry for every non-advisory rule id, `L0-4` excluded from
  `checks[]` per the contract's report shape), every `L0Check.violations == []` present (not a missing key —
  `Codable`'s synthesized encoding always emits a non-optional `[String]`, so this is structural), and an
  `indegree` block with a non-negative `threshold` and an `outliers` array (possibly empty).
- AC2: for each of the eleven mutations below, `L0Checker.validate(bundleDir:)` (or `validate(bundle:)` where
  no manifest mutation is involved) returns a report whose `checks[id]` for the named rule id has
  `passed == false` and a non-empty `violations`, AND `L0Checker.errorCode(forRuleId:)` for that same rule id
  equals the named `CoreError` case — both assertions in the same test, never `passed == false` alone: L0-1
  (`.graphL0Failed`), L0-2 (`.graphL0Failed`), L0-3a × 2 directions (`.graphL0Failed`), L0-3b
  (`.graphL0Failed`), L0-5 (`.graphL0Failed`), L0-6 (`.mapRegionUnknown`), L0-7 (`.mapLayoutMissing`), L0-8
  (`.spineUnitEmpty`), L0-9 (`.graphL0Failed`), L0-10 (`.mapLandmarkUnsourced`).
- AC3: a bundle directory whose `manifest.json` names a file absent from the directory makes
  `L0Checker.validate(bundleDir:)` throw `CoreError.platformBundleIntegrityFailed` before any `L0Report` is
  constructed (brief §3 R-6).
- AC4: L0-4 never appears in `checks[]` and never affects `passed`; its data lives only in the top-level
  `indegree` block (advisory, per the contract's "report only" note).
- AC5: the fixture scan in `L0CheckerTests` enumerates the fixture directories it reads from a fixed list (not
  a directory glob) and asserts the count before running any case — an empty or partial list is a FAIL (C3).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Validation/L0Report.swift` — `L0Report`, `L0Check`, `L0Indegree` `Codable`
  types, byte-faithful to the contract's report shape.
- `Packages/Core/Sources/Core/Validation/GraphIndex.swift` — internal adjacency/lookup structure built once
  from a `ContentBundle`, consumed by every rule check.
- `Packages/Core/Sources/Core/Validation/L0Checker.swift` — `L0Checker.validate(bundle:)`,
  `L0Checker.validate(bundleDir:)`, `L0Checker.errorCode(forRuleId:)`, and the ten rule-check functions.
- `Packages/Core/Tests/CoreTests/L0CheckerTests.swift` — the full test suite (§5).
- `Packages/Core/Tests/CoreTests/Fixtures/l0/**` — the fixture bundle directories (§4.5).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Model/**`, `BundleIO.swift`, `CoreError.swift` — task 01.1's; this task
  consumes them unmodified. If a required `CoreError` case or `Model` field is missing, that is a BLOCK on
  task 01.1 being incomplete, not something this task patches.
- `Packages/Core/Sources/Core/Layout*.swift` — task 01.3 (region-constrained force layout, `core-cli layout`).
  L0-7 in this task reads `position`; it never writes one.
- `Packages/Core/Sources/CoreCLI/**` — task 01.4 (`core-cli validate` subcommand, stdout JSON printing).
- `Packages/Core/Package.swift` — not touched (§6 default: no `resources:` declaration is needed).
- `data/demo/**`, `Packages/Rendering/**`, `pipeline/**`, `contracts/**`, `App/Sources/**` — other tasks/other
  EPICs, or read-only ground truth.
- L0-T (trail segments) — EPIC 02's; no trail-segment code or type in this task.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/graph-constraints.md` — the full rule table and report shape (lines 10–27, re-read and
  byte-compared in this run):
  > | L0-1 | The edge set is acyclic. | `GRAPH_L0_FAILED{L0-1, cycle[]}` | — |
  > | L0-2 | No edge goes from a later course to an earlier one: for every edge, `min depth(from) ≤ max
  > depth(to)` over `courses[]`; nodes without `courses[]` (undergraduate) are treated as deeper than every
  > course. | `GRAPH_L0_FAILED{L0-2, edge}` | depth = the course's position in the Ministry succession, from
  > `courses.json` |
  > | L0-3a | Every Ministry expectation in the spine maps to ≥ 1 node, and every node carrying
  > `expectation_codes` maps to ≥ 1 existing code. | `GRAPH_L0_FAILED{L0-3a, codes[]}` | applies only to
  > code-bearing nodes (v2.7 §1) |
  > | L0-3b | Every node without `expectation_codes` carries a `source_ref` whose `source` exists in
  > `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves
  > (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` /
  > `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only |
  > | L0-4 | In-degree outliers are **flagged, not failed**: nodes whose in-degree exceeds the threshold
  > (default: 95th percentile of the bundle [ESTIMATE: set empirically at M2, concept-graph Q1]) are listed in
  > the report. | report only | advisory |
  > | L0-5 | The D14 starting chain is connected end-to-end: a directed path exists through the chain's nodes
  > in order. | `GRAPH_L0_FAILED{L0-5, break}` | chain node ids are data in the bundle
  > (`manifest.starting_chain[]`) |
  > | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. |
  > `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |
  > | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by
  > `core-cli layout`; checked after it |
  > | L0-8 | Every unit of every course references only expectations of that course, every expectation is in
  > exactly one unit, no unit is empty. | `SPINE_UNIT_EMPTY` / `GRAPH_L0_FAILED{L0-8}` | D45 |
  > | L0-9 | Every course's `next_courses[]` names existing courses and contains no cycle. |
  > `GRAPH_L0_FAILED{L0-9}` | D47 succession is data |
  > | L0-10 | Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). |
  > `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15) |
  >
  > **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
  > violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
  > passed. Empty violation lists are printed, never omitted (C3).

- `contracts/data-model.md` — heading `### Identifiers` (re-read, byte-compared in this run):
  > `edge_id` is `<from>-->-<to>` (derived, never stored on the edge)

- `contracts/data-model.md` — heading `### Versioning` (re-read, byte-compared in this run):
  > Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  > `Core` needs a migration; the app refuses a bundle whose major differs from its own.

- `docs/domains/platform.md` — Errors table (re-read in this run):
  > | `PLATFORM_BUNDLE_INTEGRITY_FAILED` | Hash mismatch or a bundle failing load-time validation
  > (`MAP_LAYOUT_MISSING`, I8) | Same message; the snapshot or installed set stays | Yes, never tolerated |

- `docs/plans/epic-01-task-plan.md` planner note 2 (re-read in this run):
  > `core-cli validate` cannot verify SHA-256 without importing CryptoKit into `Core` (breaks D33/I14) or
  > hand-rolling it (breaks RULE 2). Default adopted: `core-cli validate` enforces manifest *completeness and
  > file presence* (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, exactly what the brief's R-6 line requires); hash
  > *computation* is a Python `hashlib` helper in the pipeline; hash *verification at load* defers to EPIC 03's
  > App-side loader.

  **Consequence for this task, settled — supersedes the context bundle's `tasks/context/epic-01-task-02-
  context.md:293`, which is WRONG and must not be followed:** `validate` never computes or checks a SHA-256.
  `Core` has no CryptoKit import (I14) and hand-rolls no hash algorithm (RULE 2). Manifest-completeness
  refusal is file-presence only, and it is not new code in this task — `BundleIO.read` (task 01.1) already
  throws `CoreError.platformBundleIntegrityFailed` on a missing listed file (its AC7). This task's
  `L0Checker.validate(bundleDir:)` calls `BundleIO.read` and lets that error propagate; it does not
  re-implement the check.

- `docs/plans/epic-01-task-plan.md` planner note 4 (re-read in this run):
  > `Core`'s `validate` stays exactly L0-1 … L0-10 — no LO-prefixed checks are bolted into the L0 report.
  > Renderability (`LO_ITEM_UNRENDERABLE`) goes to 01.6 (`Rendering`); distractor tags, SymPy re-derivation and
  > landmark resolution go to 01.7 (pipeline), per `docs/tech-stack.md` §2 ownership.

Prior signatures this task builds on (from `tasks/epic-01-task-01-core-bundle-types.md`, task 01.1's spec — use
these exact names; do not invent parallel ones):

```swift
public struct ContentBundle {
    public let manifest: Manifest
    public let regions: RegionsFile
    public let nodes: NodesFile
    public let edges: EdgesFile
    public let courses: CoursesFile
    public let landmarks: LandmarksFile
    public let sources: SourcesFile
}

public enum BundleIO {
    public static func read(from directory: URL) throws -> ContentBundle { ... }
    public static func write(_ bundle: ContentBundle, to directory: URL) throws { ... }
}

public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
}

public struct Point: Codable, Equatable { public let x: Double; public let y: Double }
public enum RegionId: String, Codable, CaseIterable {
    case numberOperations = "number-operations"
    case algebra = "algebra"
    case functions = "functions"
    case geometryMeasurement = "geometry-measurement"
    case trigonometry = "trigonometry"
    case calculus = "calculus"
    case linearAlgebra = "linear-algebra"
    case differentialEquations = "differential-equations"
    case probabilityStatistics = "probability-statistics"
    case discrete = "discrete"
    case analysis = "analysis"
    case topology = "topology"
    case numberTheory = "number-theory"
    case abstractAlgebra = "abstract-algebra"
    case shore = "shore"
}

public struct Manifest: Codable, Equatable {
    public let formatVersion: String
    public let bundleId: String
    public let spineVersion: String
    public let graphVersion: String
    public let builtAt: String
    public let startingChain: [String]
    public let files: [ManifestFile]
}

public struct Node: Codable, Equatable {
    public let id: String
    public let name: String
    public let regionId: RegionId
    public let strand: String?
    public let expectationCodes: [NodeExpectationCode]?
    public let sourceRef: SourceRef?
    public let courses: [NodeCourse]
    public let position: Point
    public let layoutHint: Point?
    public let paraphrase: String
    public let explanation: String?
    public let workedExamples: [WorkedExample]?
    public let errorTypes: [ErrorType]
    public let hintTree: [String: [String]]
    public let probeItems: [ProbeItem]
}
public struct NodeExpectationCode: Codable, Equatable { public let courseCode: String; public let code: String }
public struct NodeCourse: Codable, Equatable { public let courseCode: String; public let depth: Int }
public struct SourceRef: Codable, Equatable {
    public let source: UndergraduateSourceName
    public let edition: String
    public let locator: String
}

public struct Edge: Codable, Equatable {
    public let from: String
    public let to: String
    public let sources: [EdgeSource]
    public let generationAgreement: Int
    public let confidence: Double
    public let probeStats: ProbeStats
}

public struct Region: Codable, Equatable {
    public let id: RegionId
    public let name: String
    public let about: String
    public let horizon: Bool
    public let polygon: [Point]
    public let neighbours: [RegionId]
}

public struct Course: Codable, Equatable {
    public let courseCode: String
    public let name: String
    public let vintage: String
    public let strands: [Strand]
    public let expectations: [Expectation]
    public let units: [Unit]
    public let unitSource: UnitSource?
    public let nextCourses: [String]
}
public struct Expectation: Codable, Equatable {
    public let code: String
    public let kind: ExpectationKind
    public let paraphrase: String
    public let officialUrl: String
    public let unitId: String
}
public struct Unit: Codable, Equatable {
    public let unitId: String
    public let name: String
    public let expectationCodes: [String]
}

public struct Landmark: Codable, Equatable {
    public let id: String
    public let name: String
    public let whatItIs: String
    public let sourceUrl: String
    public let nodeIds: [String]
    public let regionIds: [RegionId]
    public let position: Point
}
```

Gate commands (verbatim, from `scripts/gate.sh`, re-read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (confirmed by `Packages/Core/Tests/CoreTests/CoreTests.swift:1–2`, re-read in this run): Swift
Testing (`import Testing`, `@Suite`, `@Test`, `#expect`) — not XCTest.

`CoreInfo.dataFormatVersion` (verbatim, from `Packages/Core/Sources/Core/Core.swift`, re-read in this run):

```swift
public enum CoreInfo {
    public static let dataFormatVersion = "0.0.0"
}
```

## §4 Implementation outline

Layer placement: L0 is layer ②'s acceptance gate over layers ①–③'s shapes (spine coverage, graph structure,
region/landmark/learning-object presence). `Core` is its only implementation (I14, D42); the pipeline (task
01.4) and the app's loader (EPIC 03) both call `L0Checker.validate`, never reimplement a rule.

### 4.1 `Packages/Core/Sources/Core/Validation/L0Report.swift`

```swift
public struct L0Report: Codable, Equatable {
    public let bundleId: String
    public let passed: Bool
    public let checks: [L0Check]
    public let indegree: L0Indegree
}

public struct L0Check: Codable, Equatable {
    public let id: String
    public let passed: Bool
    public let violations: [String]
}

public struct L0Indegree: Codable, Equatable {
    public let threshold: Int
    public let outliers: [String]
}
```

Uses the shared decode/encode convention from task 01.1 (`camelCase` Swift ↔ `snake_case` JSON via
`.convertToSnakeCase`; compiler-synthesized `Codable`, no manual `CodingKeys`) — `bundleId` → `bundle_id`
round-trips correctly. This is the **entire** report shape; it is byte-faithful to `contracts/graph-
constraints.md` § Report shape and gains no extra field (no embedded error code — see §6 default on
`errorCode(forRuleId:)`).

### 4.2 `Packages/Core/Sources/Core/Validation/GraphIndex.swift`

Not `public` — an internal helper consumed only by `L0Checker` in this task. Built once per `validate(bundle:)`
call from the six content collections:

```swift
struct GraphIndex {
    let nodesById: [String: Node]
    let edges: [Edge]
    let edgesByFrom: [String: [Edge]]
    let regionsById: [RegionId: Region]
    let coursesByCode: [String: Course]
    let sortedNodeIds: [String]

    init(bundle: ContentBundle) {
        nodesById = Dictionary(uniqueKeysWithValues: bundle.nodes.nodes.map { ($0.id, $0) })
        edges = bundle.edges.edges
        edgesByFrom = Dictionary(grouping: edges, by: \.from)
        regionsById = Dictionary(uniqueKeysWithValues: bundle.regions.regions.map { ($0.id, $0) })
        coursesByCode = Dictionary(uniqueKeysWithValues: bundle.courses.courses.map { ($0.courseCode, $0) })
        sortedNodeIds = nodesById.keys.sorted()
    }
}
```

`sortedNodeIds` exists because `Dictionary` iteration order is not guaranteed in Swift; every rule that walks
all nodes iterates `sortedNodeIds`, not `nodesById.keys` directly, so the report (and any cycle/first-violation
it names) is deterministic across runs — required because the same function "runs again at load on the
device" (`docs/domains/concept-graph.md` W1) and must agree with the pipeline's run byte-for-byte.

`Dictionary(uniqueKeysWithValues:)` traps on a duplicate key (e.g. two nodes sharing an id). This task does not
guard against that case: id uniqueness within a collection is `contracts/data-model.md` § Identifiers'
"unique within their collection," enforced by the pipeline's schema/id-uniqueness checks upstream of `Core`
(`pipeline/tests/test_contracts.py`), not by L0. Do not add a uniqueness check here — out of this task's rule
set (RULE 2: no rule beyond L0-1 … L0-10).

### 4.3 `Packages/Core/Sources/Core/Validation/L0Checker.swift`

```swift
public enum L0Checker {
    public static func validate(bundleDir: URL) throws -> L0Report {
        let bundle = try BundleIO.read(from: bundleDir)
        let bundleMajor = bundle.manifest.formatVersion.split(separator: ".").first
        let coreMajor = CoreInfo.dataFormatVersion.split(separator: ".").first
        guard bundleMajor == coreMajor else { throw CoreError.platformBundleIntegrityFailed }
        return validate(bundle: bundle)
    }

    public static func validate(bundle: ContentBundle) -> L0Report {
        let index = GraphIndex(bundle: bundle)
        let checks = [
            checkL0_1(index), checkL0_2(index), checkL0_3a(bundle, index), checkL0_3b(bundle, index),
            checkL0_5(bundle, index), checkL0_6(index), checkL0_7(index), checkL0_8(bundle),
            checkL0_9(bundle), checkL0_10(bundle, index),
        ]
        return L0Report(
            bundleId: bundle.manifest.bundleId,
            passed: checks.allSatisfy(\.passed),
            checks: checks,
            indegree: indegreeReport(index)
        )
    }

    public static func errorCode(forRuleId ruleId: String) -> CoreError? {
        let table: [String: CoreError] = [
            "L0-1": .graphL0Failed, "L0-2": .graphL0Failed, "L0-3a": .graphL0Failed,
            "L0-3b": .graphL0Failed, "L0-5": .graphL0Failed, "L0-6": .mapRegionUnknown,
            "L0-7": .mapLayoutMissing, "L0-8": .spineUnitEmpty, "L0-9": .graphL0Failed,
            "L0-10": .mapLandmarkUnsourced,
        ]
        return table[ruleId]
    }
}
```

`validate(bundle:)` never throws — a failing rule is a `passed: false` entry in the report, not a thrown
error; only `validate(bundleDir:)`'s pre-report refusal (manifest incompleteness, `format_version` major
mismatch) throws, because those conditions mean no `ContentBundle` could be constructed at all. `checks` is
built in the fixed order `[L0-1, L0-2, L0-3a, L0-3b, L0-5, L0-6, L0-7, L0-8, L0-9, L0-10]` — ten entries; `L0-4`
is never one of them (§6 default on why).

`errorCode(forRuleId:)` is the mapping the "Fails with" column of the contract's rule table already states in
prose; it exists so a caller (the pipeline wrapper in task 01.4, the app's bundle loader in EPIC 03) can turn a
`checks[]` entry into the `CoreError` case it should surface, without the report itself carrying a redundant
field (keeps `L0Report` byte-faithful — §6 default).

Each `checkL0_*` function returns an `L0Check`; signatures:

```swift
private static func checkL0_1(_ index: GraphIndex) -> L0Check
private static func checkL0_2(_ index: GraphIndex) -> L0Check
private static func checkL0_3a(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check
private static func checkL0_3b(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check
private static func checkL0_5(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check
private static func checkL0_6(_ index: GraphIndex) -> L0Check
private static func checkL0_7(_ index: GraphIndex) -> L0Check
private static func checkL0_8(_ bundle: ContentBundle) -> L0Check
private static func checkL0_9(_ bundle: ContentBundle) -> L0Check
private static func checkL0_10(_ bundle: ContentBundle, _ index: GraphIndex) -> L0Check
private static func indegreeReport(_ index: GraphIndex) -> L0Indegree
```

Algorithm per rule (all iterate `index.sortedNodeIds` / a stably-sorted collection where the contract does not
otherwise fix an order, so the report is deterministic across runs):

- **L0-1 (acyclic).** Depth-first search over `edgesByFrom`, visiting `sortedNodeIds` in order, using a
  white/gray/black colour map. On finding a back edge (target already gray), reconstruct the cycle from the
  current DFS stack and stop — this task reports the **first** cycle found under the deterministic traversal
  order, not every cycle (§6 default: the contract's `cycle[]` names one violation list, and finding all
  cycles in a general digraph is unbounded work outside this task's scope). `violations` = the cycle's node
  ids in order, e.g. `["a", "b", "c", "a"]`. `passed` = no cycle found.
- **L0-2 (course order).** For each edge in `index.edges` (iterated in file order — edges have no natural sort
  key besides that): `depth(from) = from.courses.isEmpty ? Int.max : from.courses.map(\.depth).min()!`;
  `depth(to) = to.courses.isEmpty ? Int.max : to.courses.map(\.depth).max()!`. Violates if
  `depth(from) > depth(to)`. `violations` = one entry per violating edge, formatted as the `edge_id` the data-
  model contract defines: `"\(edge.from)-->-\(edge.to)"`.
- **L0-3a (spine coverage, both directions).** Direction A — for every node with a non-nil, non-empty
  `expectationCodes`, for every `NodeExpectationCode{courseCode, code}`, look up `index.coursesByCode
  [courseCode]?.expectations` and check some entry has `.code == code`; if not, append
  `"\(node.id):\(courseCode).\(code)"` to violations. Direction B — for every course in `bundle.courses.courses`
  (iterated by `courseCode` sorted), for every `Expectation` in that course, check some node's
  `expectationCodes` contains a matching `{courseCode, code}` pair; if not, append `"\(course.courseCode).
  \(expectation.code)"`. Both directions accumulate into the same `violations` array (order: all direction-A
  violations first by node id, then all direction-B violations by course code then expectation code).
  `passed` = violations is empty.
- **L0-3b (source presence).** For every node whose `expectationCodes` is nil or empty: fail unless
  `sourceRef` is non-nil AND `index bundle.sources.sources` contains an entry whose `source ==
  sourceRef!.source` AND `sourceRef!.locator` is non-empty. Append the node id to `violations` on failure.
  (Structural check only — HTTP resolution of `locator` is task 01.7's, per the contract's own "resolution is
  a build-time check; the app checks presence only.")
- **L0-5 (starting chain connected).** For each consecutive pair `(chain[i], chain[i+1])` in
  `bundle.manifest.startingChain`, breadth-first search over `edgesByFrom` from `chain[i]`; if `chain[i+1]` is
  not reached, append `"\(chain[i])-->-\(chain[i+1]) unreachable"` to `violations` and stop at the first break
  (§6 default, matching L0-1's "first violation" policy for consistency). An empty or single-element
  `startingChain` trivially passes (no consecutive pair to check).
- **L0-6 (region known, non-horizon).** For every node, look up `index.regionsById[node.regionId]`; fail if
  absent (impossible given `RegionId`'s closed enum decodes every case, so this branch never fires — kept for
  totality) or if `.horizon == true`. Append the node id to `violations` on failure.
- **L0-7 (position inside region polygon).** For every node, look up its region's `polygon` and run
  `pointInPolygon(node.position, polygon: region.polygon)` (ray-casting / PNPOLY, §4.4). Append the node id to
  `violations` if the point is outside.
- **L0-8 (unit coverage).** For every course, for every unit: fail (append `unit.unitId`) if
  `unit.expectationCodes.isEmpty`. Separately, for every course, for every expectation: fail (append
  `"\(unit_id_actually_containing_it_or_none):\(expectation.code)"` — more precisely, append
  `"\(course.courseCode).\(expectation.code)"`) if `expectation.code` is not named by **exactly one**
  `unit.expectationCodes` among that course's `units` (covers both "references only expectations of that
  course" and "exactly one unit" sub-conditions structurally, since a code appearing in a unit of a *different*
  course cannot be reached from that course's own `units` iteration). `passed` = violations is empty. (§6
  default on why `errorCode(forRuleId: "L0-8")` maps uniformly to `.spineUnitEmpty` regardless of which
  sub-condition fired.)
- **L0-9 (course succession).** Build an adjacency map `courseCode → nextCourses` from `bundle.courses.courses`.
  For every course, for every entry in `nextCourses`, fail (append the unknown code) if it does not name an
  existing `courseCode`. Then run the same DFS cycle detection as L0-1 (white/gray/black, visiting course codes
  sorted) over this adjacency map; on a cycle, append the cycle's course codes in order. `violations` accumulates
  both kinds (unknown-target violations first, then a cycle if any).
- **L0-10 (landmark referential integrity + https).** For every landmark, fail (append the landmark id) if any
  `nodeIds` entry is absent from `index.nodesById`, OR `sourceUrl` does not start with `"https://"`. (`Landmark.
  sourceUrl` is non-optional per task 01.1 — see §6 default on why "missing `source_url`" cannot be a fixture
  at this layer.)
- **`indegreeReport` (L0-4, advisory, never in `checks[]`).** Compute in-degree per node id from
  `index.edges` (count of edges with that `to`); nodes with in-degree 0 are included. `threshold` = the 95th
  percentile by the nearest-rank method: sort in-degrees ascending, `idx = max(0, Int((0.95 *
  Double(sorted.count)).rounded(.up)) - 1)`, `threshold = sorted.isEmpty ? 0 : sorted[idx]`. `outliers` = the
  sorted node ids whose in-degree **strictly exceeds** `threshold`. This never affects `passed` (I8 / L0-4:
  "report only").

### 4.4 Point-in-polygon helper (inside `L0Checker.swift`, private)

Standard even-odd ray-casting (PNPOLY, W. Randolph Franklin) over `Point`/`[Point]` — deterministic, pure
`Double` arithmetic, no external dependency:

```swift
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
```

A point exactly on the polygon boundary may register as inside or outside depending on which edge it lies on
(a known property of this algorithm); this task does not special-case the boundary (§6 default) — every
fixture's mutated position is placed unambiguously outside its region's bounding area, never on an edge.

### 4.5 Fixture inventory — `Packages/Core/Tests/CoreTests/Fixtures/l0/`

Every fixture is a full bundle directory of seven files (`manifest.json`, `regions.json`, `nodes.json`,
`edges.json`, `courses.json`, `landmarks.json`, `sources.json`). `Fixtures/l0/valid/` is the baseline every
other fixture copies verbatim except for the one named mutation.

**`Fixtures/l0/valid/`** — built from `contracts/examples/{manifest,regions,nodes,edges,courses,landmarks,
sources}.json` (all seven read and confirmed L0-clean in this run for every rule except L0-9, where
`courses.json`'s `next_courses` name `MPM2D`/`MHF4U`, courses this minimal example set does not define) with
exactly one deviation: `courses.json`'s `MTH1W.next_courses` and `MCR3U.next_courses` are both set to `[]`
(instead of `["MPM2D"]` / `["MHF4U"]`) so the fixture is self-contained and L0-9-clean without inventing course
stubs. `manifest.json` is `contracts/examples/manifest.json` unchanged (its `starting_chain` —
`["exponent-laws", "exponential-functions"]` — is already connected via the single edge in `edges.json`). This
fixture must decode and `validate(bundle:)` to `passed: true` with all ten `checks[]` entries `passed: true`
and empty `violations`.

Per-fixture mutations (each is a full copy of `valid/`'s seven files with exactly the listed single-file
change; everything else byte-identical to `valid/`):

| Fixture dir | File mutated | Mutation | Rule | Violates because |
|---|---|---|---|---|
| `l0-1-cycle/` | `edges.json` | add edge `{from: "exponential-functions", to: "exponent-laws", ...}` (reuse `valid/`'s edge shape) | L0-1 | 2-cycle `exponent-laws ↔ exponential-functions` |
| `l0-2-course-order/` | `nodes.json` | `exponential-functions.courses[0].depth`: `3` → `0` | L0-2 | edge `exponent-laws(depth 1) → exponential-functions(depth 0)` now goes to a shallower course |
| `l0-3a-unknown-code/` | `nodes.json` | `exponent-laws.expectation_codes[0].code`: `"B3.4"` → `"B9.9"` | L0-3a (direction A: node → code) | `B9.9` is not in MTH1W's `expectations[]` |
| `l0-3a-uncovered-expectation/` | `courses.json` | add `{code: "B3.5", kind: "specific", paraphrase: "...", official_url: "...", unit_id: "MTH1W.u1"}` to MTH1W's `expectations[]` and `"B3.5"` to `MTH1W.u1`'s `expectation_codes[]` | L0-3a (direction B: code → node) | no node's `expectation_codes` names `{MTH1W, B3.5}` |
| `l0-3b-no-source/` | `nodes.json` | delete `matrix-multiplication.source_ref` entirely (it already has no `expectation_codes`) | L0-3b | node has neither codes nor a source |
| `l0-5-broken-chain/` | `manifest.json` | `starting_chain`: `["exponent-laws", "exponential-functions"]` → `["exponent-laws", "exponential-functions", "matrix-multiplication"]` | L0-5 | no edge/path from `exponential-functions` to the isolated `matrix-multiplication` |
| `l0-6-unknown-region/` | `nodes.json` | `exponent-laws.region_id`: `"number-operations"` → `"topology"` | L0-6 | `topology` is a horizon region (`horizon: true` in `regions.json`) |
| `l0-7-position-outside/` | `nodes.json` | `exponent-laws.position`: `{x: 0.08, y: 0.12}` → `{x: 0.9, y: 0.9}` | L0-7 | `(0.9, 0.9)` is outside `number-operations`'s polygon (`x ∈ [0, 0.19], y ∈ [0, 0.3]`) |
| `l0-8-empty-unit/` | `courses.json` | add a unit `{unit_id: "MTH1W.u2", name: "Empty unit", expectation_codes: []}` to MTH1W's `units[]` | L0-8 | `expectation_codes` is empty |
| `l0-9-next-courses-cycle/` | `courses.json` | `MTH1W.next_courses`: `[]` → `["MCR3U"]`; `MCR3U.next_courses`: `[]` → `["MTH1W"]` | L0-9 | 2-cycle `MTH1W ↔ MCR3U` |
| `l0-10-not-https/` | `landmarks.json` | `source_url`: `"https://laws-lois.justice.gc.ca/eng/acts/I-15/"` → `"http://laws-lois.justice.gc.ca/eng/acts/I-15/"` | L0-10 | not https |
| `manifest-missing-file/` | (directory) | copy `valid/`'s `manifest.json` (lists `sources.json` in `files[]`) but omit `sources.json` from the directory | R-6 / `PLATFORM_BUNDLE_INTEGRITY_FAILED` | `BundleIO.read` finds a listed file absent |
| `manifest-version-mismatch/` | `manifest.json` | `format_version`: `"0.0.0"` → `"1.0.0"` | `PLATFORM_BUNDLE_INTEGRITY_FAILED` | major component differs from `CoreInfo.dataFormatVersion` (`"0.0.0"`) |

13 fixture directories total (`valid/` + 12 mutations; L0-3a has two). Fixture JSON content for the unmutated
six files in each directory is `valid/`'s content unchanged; the implementer copies rather than re-derives it,
so every fixture decodes with the same `Core` types task 01.1 ships.

### 4.6 `Packages/Core/Tests/CoreTests/L0CheckerTests.swift`

Locate `Fixtures/l0/` the same way task 01.1's `DecodeRoundTripTests` locates `contracts/examples/`: from
`#filePath` (`Packages/Core/Tests/CoreTests/L0CheckerTests.swift`), two `.deletingLastPathComponent()` calls
reach `Packages/Core/Tests/CoreTests`, then `.appendingPathComponent("Fixtures/l0")`. No `resources:` entry is
added to `Package.swift` (§6 default) — fixtures are read via `FileManager`/`Data(contentsOf:)` from that
resolved path, mirroring the precedent `DecodeRoundTripTests` and `coreImportBoundary()` already set.

### 4.7 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles `Core`'s new
`Validation/*.swift` files even though `CoreCLI`'s `main.swift` does not yet call `L0Checker` — task 01.4's
job).

## §5 Test plan (risk: seam — full plan)

- T1 happy path: `validate(bundleDir: .../Fixtures/l0/valid)` returns `passed == true`; `checks.count == 10`;
  every `checks[i].id` is one of the ten non-advisory rule ids with no duplicates and no omission (assert the
  set equality against `["L0-1","L0-2","L0-3a","L0-3b","L0-5","L0-6","L0-7","L0-8","L0-9","L0-10"]`); every
  `checks[i].violations == []` (present, not a missing/omitted key — this is a structural guarantee of
  `L0Check`'s non-optional `[String]`, verified by decoding the re-encoded report and checking the key exists
  with an empty array, not merely checking the Swift value); `indegree.threshold >= 0` (AC1).
- T2 negative — invalid input rejected at the boundary: each of the 12 mutated fixtures makes `validate`
  produce a report with the corresponding `checks[]` entry `passed == false` and non-empty `violations`, or
  (for the two `manifest-*` fixtures) makes `validate(bundleDir:)` throw `CoreError
  .platformBundleIntegrityFailed` before returning any report (AC2, AC3).
- T3 error-taxonomy: for every one of the ten non-advisory rule ids, `L0Checker.errorCode(forRuleId:)` returns
  the `CoreError` case named in AC2's list; assert this as a table-driven test independent of any fixture (a
  pure lookup, not requiring a bundle) so a rule-id/error-code drift is caught even if the corresponding
  fixture is accidentally deleted.
- T4 conformance per requirements §B.1 (epic brief §5 — "concept-graph: I7/I8 mechanisms... L0 as build test
  and at load"; "map: I8 region/coordinates refusal (`MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`)"; "curriculum-
  spine: L0-8 unit coverage and L0-9 succession"): covered jointly by T1 (happy path over all ten rules) and T2
  (one negative control per rule, including the two directions of L0-3a and the curriculum-spine rules L0-8/
  L0-9) — no separate test needed; this line records the mapping so the wrap-gate ledger can trace it.
- T5 negative control for every regression guard:
  - the fixture-count anti-vacuity guard (AC5): assert the fixed fixture-directory list used by the test suite
    has exactly 13 entries before running any case; a test that iterated a directory glob instead (silently
    tolerating a deleted fixture) is exactly what this guards against.
  - L0-4 never appears in `checks[]` (AC4): assert `!report.checks.map(\.id).contains("L0-4")` on the `valid/`
    report, and that `report.indegree` is present and typed (not absorbed into `checks[]`) — this is the
    negative control for a regression that folds the advisory rule into the pass/fail set.
  - `passed` derivation: construct a report by hand (not via `validate`) with nine `passed: true` checks and
    one `passed: false` check and assert `checks.allSatisfy(\.passed) == false` reflects into a `passed ==
    false` bundle-level verdict when fed back through the same predicate `L0Checker.validate` uses — or,
    simpler and sufficient: assert directly on the `l0-1-cycle/` fixture's report that `report.passed == false`
    even though nine of its ten checks still pass (proving `passed` is an AND over all ten, not e.g. only the
    first failing check).
  - the manifest-completeness reuse (I14/RULE 2): assert `L0Checker.validate(bundleDir:)` over
    `manifest-missing-file/` throws the exact same `CoreError.platformBundleIntegrityFailed` case
    `BundleIO.read` throws directly (call `BundleIO.read` on the same fixture path in the same test and assert
    both throw the identical case) — the negative control against a regression that reimplements the check
    with a different/looser condition inside `L0Checker` instead of delegating to `BundleIO`.
- T6 idempotency / no-leak: `validate(bundle:)` is a pure function of its input — call it twice on the same
  decoded `valid/` bundle and assert the two `L0Report` values are `Equatable`-equal (byte-for-byte
  determinism, required because the same function "runs again at load on the device" and must agree with the
  pipeline's run); additionally, `validate(bundleDir:)` on `manifest-missing-file/` never constructs a partial
  `L0Report` — the `throws` signature makes this structurally impossible, and the test documents the assertion
  at the contract level (no `L0Report` value is observable from a failed call).

## §6 Decision defaults

- IF the contract's report shape lists `checks[]` and a separate `indegree` block as siblings THEN `L0-4`
  (advisory, "report only") is represented **only** by `indegree`, never as a `checks[]` entry, and `checks[]`
  contains exactly the ten non-advisory rule ids — per `contracts/graph-constraints.md` § Report shape (quoted
  in §3) read together with the L0-4 row's "Fails with: report only | advisory" (also quoted in §3): a rule
  with no failure code and no pass/fail semantics of its own does not belong in a `{id, passed, violations}`
  array whose `passed` field the contract defines as meaningful ("A bundle is accepted iff every non-advisory
  check passed").
- IF a rule's "Fails with" column names two codes (`GRAPH_L0_FAILED{...}` / a more specific domain code, e.g.
  L0-6's `MAP_REGION_UNKNOWN`, L0-7's `MAP_LAYOUT_MISSING`, L0-8's `SPINE_UNIT_EMPTY`, L0-3b's
  `SPINE_SOURCE_REF_UNRESOLVED`) THEN the specific domain code is what `errorCode(forRuleId:)` returns for that
  rule (it is the more precise signal a caller would want to surface), **except** L0-3b, where the second code
  (`SPINE_SOURCE_REF_UNRESOLVED`) is explicitly the *pipeline's* HTTP-resolution failure per the contract's own
  note "resolution is a build-time check; the app checks presence only" (quoted in §3) — `Core`'s structural
  check (this task) can only ever raise the generic `GRAPH_L0_FAILED{L0-3b}` side, so `errorCode(forRuleId:
  "L0-3b")` returns `.graphL0Failed`, and `CoreError.spineSourceRefUnresolved` (declared in the enum by task
  01.1 for registry completeness) is never returned by this task's code and never thrown by `Core`.
- IF `L0Report` were extended with a per-check error-code field to make error-code assertions easier THEN
  reject that design: the task prompt requires "the report shape stays byte-faithful to the contract," so the
  rule-id ↔ error-code mapping lives in the separate, testable `L0Checker.errorCode(forRuleId:)` function
  instead (§4.3).
- IF the contract's AC language ("unknown or second region") suggests testing a node with two `region_id`
  values THEN that mutation is not constructible: `Node.regionId` (task 01.1) is a single non-optional
  `RegionId`, not an array — "exactly one `region_id`" is already a structural guarantee of the Swift type.
  The only reachable L0-6 violation is an unknown-for-nodes region (a horizon label or `shore`, which decodes
  fine against `RegionId`'s 15-case superset but is invalid for a node per `nodes.schema.json`'s narrower
  10-value enum — task 01.1 §6 already made this the intended division of labour between `Core`'s `Codable`
  layer and this task's L0-6). `l0-6-unknown-region/` uses that construction.
- IF the AC language ("node without `position`" for L0-7, "landmark without `source_url`" for L0-10) suggests
  testing an omitted required field THEN that mutation is not constructible either: `Node.position` and
  `Landmark.sourceUrl` are both non-optional in task 01.1's types, so omitting the JSON key makes the fixture
  fail to decode entirely (a `DecodingError`, before `L0Checker` ever runs) rather than reaching L0 as a
  `passed: false` report entry. The fixtures instead exercise what the rule text actually checks once decode
  has succeeded: L0-7 via a `position` present but outside the region polygon; L0-10 via a `source_url` present
  but not `https`. Both still raise the named codes (`MAP_LAYOUT_MISSING`, `MAP_LANDMARK_UNSOURCED`) for the
  named rule ids.
- IF fixture loading needs an SPM `resources:` entry THEN it does not: task 01.1's `DecodeRoundTripTests` and
  the existing `coreImportBoundary()` test both already resolve repo-relative paths via `#filePath` +
  `FileManager`, with no `resources:` declaration in `Package.swift` (confirmed absent, re-read in this run).
  This task follows the same, already-precedented pattern for `Fixtures/l0/`, keeping `Package.swift`
  out of this task's file scope.
- IF a rule's violation-first-vs-all policy is unstated by the contract (true of L0-1's cycle and L0-5's chain
  break) THEN report the first violation found under the deterministic `sortedNodeIds` traversal order, not
  every possible one — the contract fixes only the failure shape (`cycle[]`, `break`), not an exhaustiveness
  requirement, and finding all cycles in a general digraph is unbounded extra work this task does not need
  (RULE 2).
- Standing defaults: identifiers are stable lowercase kebab-case slugs, never parsed for meaning
  (`contracts/data-model.md` § Identifiers); `edge_id` formatting is always `<from>-->-<to>` (same section);
  telemetry is out of scope entirely for this task; no model call exists anywhere in this task's code (I2).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the new `Packages/Core/Sources/Core/Validation/*.swift` and `Packages/Core/Tests/CoreTests/
  L0CheckerTests.swift` files.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6) pass.
- Conforms to every contract section cited in §3 and §4 (`contracts/graph-constraints.md` full rule table and
  § Report shape; `contracts/data-model.md` § Identifiers, § Versioning; `docs/domains/platform.md` Errors
  table) and to every invariant listed in §1 (I1, I2, I6, I8, I9, I14, I15).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and are unaffected by
  this task's file scope).

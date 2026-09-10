# Epic 01 · Task 03: Region-constrained deterministic layout

---
epic: 01
task: 03
slug: region-constrained-layout
kind: feat
risk: seam
depends_on: [01.1]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `Core` gains a deterministic, region-constrained force layout: a pure function over the value types
task 01.1 shipped (`Node`, `Region`, `Point`), with an injected seeded RNG (`SeededGenerator`), every tuning
constant collected in one `LayoutConfig`, and point-in-polygon clamping applied on every simulation step so
every returned position lands inside its own node's region polygon. `core-cli layout` (task 01.4) will call
this function and write the results into `nodes.json`; this task ships the function and its tests only.

Invariants in play:

- **I2** — layout is Tier 0: a pure deterministic function, no model call anywhere in this task's code; the
  system never "guesses" a position — a node whose region cannot be resolved throws rather than being
  silently clamped to an arbitrary point.
- **I8** — the function is exactly what L0-6 (`contracts/graph-constraints.md`) and L0-7 defend: L0-6's
  "non-horizon region in `regions.json`" clause is enforced here as `CoreError.mapRegionUnknown`; L0-7's
  "position inside its region's polygon" is the postcondition this task's determinism/containment tests
  assert directly (the L0 *checker* that re-verifies this from a written bundle is task 01.2's).
- **I11** — every constant in `LayoutConfig` (iteration count, force constants, tolerances, the default seed)
  carries an `[ESTIMATE: …]` tag in its doc comment; no time estimate appears anywhere.
- **I14** — `Layout/*.swift` imports `Foundation` only (same boundary the existing `CoreTests.coreImportBoundary()`
  test already enforces recursively once task 01.1 lands); the RNG is a hand-written seeded
  `RandomNumberGenerator` (`SeededGenerator`, a splitmix64 generator), never `SystemRandomNumberGenerator` or
  any platform-random source — determinism is the point; layout exists once, in `Core`, and nowhere else.

Acceptance criteria:

- AC1: given a fixture of ten non-horizon region polygons and ten nodes (one per region, mixing nodes with
  and without `layout_hint`), `LayoutEngine.layout` returns a position for every node, and
  `Polygon.contains` is true for every returned position against its own node's region polygon — asserted
  per node, not in aggregate; the fixture's node count is asserted non-zero before the per-node check runs
  (an empty node set is a FAIL for this test, per the task instructions' anti-vacuity requirement).
- AC2: two calls to `LayoutEngine.layout` over the same fixture, each with a freshly constructed
  `SeededGenerator(seed: LayoutConfig.defaultSeed)`, produce `[String: Point]` results whose
  `JSONEncoder(outputFormatting: [.sortedKeys])`-encoded `Data` are byte-identical.
- AC3: a third call over the same fixture with `SeededGenerator(seed: LayoutConfig.defaultSeed &+ 1)`
  produces encoded `Data` that differs from AC2's result — the anti-vacuity guard on AC2: a layout function
  that ignored its injected `rng` (e.g. always returned the same positions regardless of seed) would fail
  this criterion, so AC2 cannot pass "by the function being constant."
- AC4: a node whose `region_id` names a region entirely absent from the regions fixture throws
  `CoreError.mapRegionUnknown` rather than being clamped to a guessed position.
- AC5: a node whose `region_id` names a region that IS present in the fixture but carries `horizon: true`
  also throws `CoreError.mapRegionUnknown` — a horizon region is never assigned nodes
  (`docs/domains/map.md` — "A `horizon` region is a label with no nodes and is not tappable", and
  `contracts/graph-constraints.md` L0-6, quoted in §3).
- AC6: every tuning constant used by `LayoutEngine.swift` and `Polygon.swift` is a named `LayoutConfig`
  field, referenced by name at its call site; no bare numeric literal (other than `0`, `1`, loop indices, and
  array/tuple indexing) appears in either file outside `LayoutConfig.swift` itself.
- AC7: `scripts/gate.sh` gate 1 (format+lint) and gate 3 (`Core` build+test) are green with the new files
  included.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Layout/LayoutEngine.swift` — the layout function.
- `Packages/Core/Sources/Core/Layout/LayoutConfig.swift` — the tuning-constant struct.
- `Packages/Core/Sources/Core/Layout/SeededGenerator.swift` — hand-written seeded `RandomNumberGenerator`.
- `Packages/Core/Sources/Core/Layout/Polygon.swift` — point-in-polygon containment + centroid.
- `Packages/Core/Tests/CoreTests/LayoutTests.swift` — AC1–AC7 tests.
- `Packages/Core/Tests/CoreTests/Fixtures/layout/regions-ten.json` — ten non-horizon region polygons.
- `Packages/Core/Tests/CoreTests/Fixtures/layout/regions-ten-plus-horizon.json` — the same ten plus one
  horizon region (`analysis`, `horizon: true`).
- `Packages/Core/Tests/CoreTests/Fixtures/layout/regions-missing-discrete.json` — nine of the ten regions
  (omits `discrete`).
- `Packages/Core/Tests/CoreTests/Fixtures/layout/nodes-happy.json` — ten nodes, one per region, mixing
  `layout_hint` present/absent.
- `Packages/Core/Tests/CoreTests/Fixtures/layout/nodes-unknown-region.json` — one node whose `region_id` is
  `discrete`, paired with `regions-missing-discrete.json` (AC4).
- `Packages/Core/Tests/CoreTests/Fixtures/layout/nodes-horizon-region.json` — one node whose `region_id` is
  `analysis`, paired with `regions-ten-plus-horizon.json` (AC5).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/Model/*.swift`, `Packages/Core/Sources/Core/CoreError.swift`,
  `Packages/Core/Sources/Core/BundleIO.swift`, `Packages/Core/Sources/Core/Core.swift` — task 01.1's files;
  `Node`, `Region`, `Point`, `RegionId`, `CoreError.mapLayoutMissing`/`.mapRegionUnknown` already exist there
  and are consumed, not redefined, by this task.
- `Packages/Core/Sources/Core/L0*.swift`, any `validate` function — task 01.2.
- `Packages/Core/Sources/CoreCLI/**` — task 01.4; this task ships the function `core-cli layout` will call,
  not the subcommand itself.
- `Packages/Core/Package.swift` — not touched by this task; see §6 default on why no `resources:` clause is
  needed.
- `Packages/Core/Tests/CoreTests/CoreTests.swift`, `DecodeRoundTripTests.swift`, `ErrorRegistryTests.swift` —
  task 01.1's test files.
- `data/demo/**`, `Packages/Rendering/**`, `pipeline/**`, `contracts/**`, `App/Sources/**` — other tasks /
  read-only ground truth.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/graph-constraints.md` — table rows `L0-6` and `L0-7`:
  > | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. |
  > `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |
  > | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by
  > `core-cli layout`; checked after it |

- `docs/domains/map.md` — heading `## Errors produced`:
  > | `MAP_LAYOUT_MISSING` | A node in the bundle has no coordinates | Internal; bundle refused at load
  > (platform) | Yes — re-run the pipeline build step (D33) |
  > | `MAP_REGION_UNKNOWN` | A node names a region absent from the bundle | Internal; bundle refused (I8) |
  > Yes — pipeline |

- `docs/domains/map.md` — Core entities, `Region`:
  > **Region** — one of the ten D21 (revised) territories — Number & Operations · Algebra · Functions ·
  > Geometry & Measurement · Trigonometry · Calculus · Linear Algebra · Differential Equations · Probability
  > & Statistics · Discrete Mathematics — or a horizon label (Analysis, Topology, Number Theory, Abstract
  > Algebra), or the optional "shore" (grade 7–8; drawn, no content, no fog; not in the Demo — decided at
  > M5): `id`, `name`, `polygon` (normalised coordinates, hand-authored for the Demo, pipeline-authored
  > later), `horizon: bool`, `neighbours[]`, and one sentence on what the territory is about (project's own
  > words, I6). A `horizon` region is a label with no nodes and is not tappable. Every `Node`
  > (**concept-graph**) has exactly one region (I8).

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` — §9 open question 1 (FULL, the locked default for
  this task's algorithm):
  > Layout algorithm details (repulsion/attraction constants, iteration count, polygon containment method) —
  > **default:** a simple Fruchterman–Reingold-style loop with a fixed iteration count [ESTIMATE: 300] and
  > point-in-polygon clamping each step, seeded RNG from a fixed constant; any constants live in one
  > `LayoutConfig`. Revisit at M2 when the real graph exists (a few hundred nodes).

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` — §3, MANDATORY invariant line (the determinism
  test this task ships):
  > I14 — `Core` gains no import beyond Foundation (existing boundary test); layout is a pure function with
  > an injected seeded RNG (determinism test: two runs, byte-equal positions).

- `contracts/error-codes.json` — the two entries this task's `LayoutEngine` raises (full file read in this
  run; showing exactly these two of its 51 entries):
  > `{"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null},`
  > `{"code": "MAP_REGION_UNKNOWN", "recoverable": true, "surface": "internal", "user_text": null},`

Prior signatures (verbatim, from `tasks/epic-01-task-01-core-bundle-types.md` §4.2/§4.4/§4.5/§4.11 — the
exact types and error cases this task consumes; task 01.1 ships them, this task does not redefine them):

```swift
public struct Point: Codable, Equatable {
    public let x: Double
    public let y: Double
}

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

public struct Region: Codable, Equatable {
    public let id: RegionId
    public let name: String
    public let about: String
    public let horizon: Bool
    public let polygon: [Point]
    public let neighbours: [RegionId]
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

public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
}
```

Coordinate bounds (verbatim, from `contracts/schemas/nodes.schema.json:112–150`, `position`/`layout_hint`,
read in this run):

```json
"position": {
  "type": "object",
  "properties": {
    "x": { "type": "number", "minimum": 0, "maximum": 1 },
    "y": { "type": "number", "minimum": 0, "maximum": 1 }
  },
  "required": ["x", "y"],
  "additionalProperties": false
},
"layout_hint": {
  "type": "object",
  "properties": {
    "x": { "type": "number", "minimum": 0, "maximum": 1 },
    "y": { "type": "number", "minimum": 0, "maximum": 1 }
  },
  "required": ["x", "y"],
  "additionalProperties": false
}
```

Polygon bounds (verbatim, from `contracts/schemas/regions.schema.json:47–70`, read in this run):

```json
"polygon": {
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "x": { "type": "number", "minimum": 0, "maximum": 1 },
      "y": { "type": "number", "minimum": 0, "maximum": 1 }
    },
    "required": ["x", "y"],
    "additionalProperties": false
  },
  "minItems": 3
}
```

Coordinate space this task's code must assume (derived from the two normative schema fragments above, not
elsewhere stated): `x` and `y` are each a closed range `[0, 1]`, shared by every region's polygon and every
node's `position`/`layout_hint` — one common unit square, not a per-region local space. `regions.schema.json`
requires `minItems: 3` on `polygon`; `Core`'s `Codable` layer (task 01.1) does not enforce `minItems` at
decode time, so `LayoutEngine` must defend against a decoded polygon with fewer than 3 points itself (§4.3
step 2).

Gate commands (verbatim, from `scripts/gate.sh`, read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
```

Test framework (verbatim, from `docs/tech-stack.md:22`, read in this run):

> | Swift tests | **Swift Testing** (`import Testing`) for `Core`; XCTest only where UI testing needs it |
> Xcode-bundled | first-party; expressive `#expect` | `Testing.framework` present in the iOS platform of
> Xcode 26.6 (local `ls`) |

Fixture-location precedent (verbatim, from `Packages/Core/Tests/CoreTests/CoreTests.swift:22–26`, read in
this run — the exact `#filePath`-relative pattern this task's fixture loading follows, with the directory
depth adjusted per §6):

```swift
let sourcesDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // CoreTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // package root
    .appendingPathComponent("Sources/Core")
```

## §4 Implementation outline

Layer placement: layout is the ②→④ map projection (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md`
§2, "MANDATORY placement line"). `Core` is its only implementation (I14, D42).

### 4.1 `Packages/Core/Sources/Core/Layout/LayoutConfig.swift`

```swift
import Foundation

/// Every tuning constant the force layout uses, collected in one place (brief §9 default, quoted in §3) so
/// no numeric literal is re-typed at a call site in `LayoutEngine.swift` or `Polygon.swift` (AC6).
public struct LayoutConfig: Sendable, Equatable {
    /// Fixed iteration count for the Fruchterman–Reingold-style loop.
    public var iterationCount: Int = 300  // [ESTIMATE: 300 — epic brief §9, quoted in §3]
    /// Repulsion force magnitude between any two node positions, scaled by 1/distance^2.
    public var repulsionStrength: Double = 0.0005  // [ESTIMATE]
    /// Spring force magnitude pulling a node back toward its anchor (its `layout_hint`, or its
    /// rejection-sampled initial point when `layout_hint` is absent or invalid).
    public var attractionStrength: Double = 0.02  // [ESTIMATE]
    /// Per-iteration multiplicative decay applied to the maximum step size (simulated-annealing cooling).
    public var coolingFactor: Double = 0.98  // [ESTIMATE]
    /// Initial per-iteration maximum displacement, as a fraction of the shared [0,1] coordinate space.
    public var maxStepFraction: Double = 0.05  // [ESTIMATE]
    /// Floor applied to inter-node distance before computing repulsion, avoiding division by zero when two
    /// nodes coincide.
    public var minimumDistance: Double = 0.000_001  // [ESTIMATE]
    /// Tolerance for the point-on-boundary check in `Polygon.contains`.
    public var boundaryEpsilon: Double = 0.000_000_001  // [ESTIMATE]
    /// Bounded retry count for rejection-sampling a random point inside a polygon's bounding box.
    public var maxRandomSamples: Int = 1000  // [ESTIMATE]
    /// The fixed seed used when a caller does not supply its own — the brief §9 "seeded RNG from a fixed
    /// constant" requirement.
    public static let defaultSeed: UInt64 = 42  // [ESTIMATE: 42 — arbitrary fixed constant, brief §9]

    public init() {}
}
```

### 4.2 `Packages/Core/Sources/Core/Layout/SeededGenerator.swift`

A hand-written deterministic PRNG conforming to the standard library's `RandomNumberGenerator` protocol —
splitmix64, public-domain algorithm, no third-party import (I14: the RNG must not be
`SystemRandomNumberGenerator` or any platform-random source; determinism is the point):

```swift
import Foundation

public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

### 4.3 `Packages/Core/Sources/Core/Layout/Polygon.swift`

```swift
import Foundation

public enum Polygon {
    /// Even-odd (ray-casting) point-in-polygon test, boundary-inclusive: a point lying on an edge (within
    /// `epsilon`) counts as inside. `polygon` is a closed ring of ordered vertices — the edge from the last
    /// vertex back to the first is implicit, matching `contracts/schemas/regions.schema.json`'s `polygon`
    /// array shape.
    public static func contains(_ point: Point, in polygon: [Point], epsilon: Double) -> Bool

    /// Arithmetic-mean centroid of the polygon's vertices. Not guaranteed to lie inside a concave polygon —
    /// callers verify with `contains` before relying on it.
    public static func centroid(of polygon: [Point]) -> Point
}
```

Implementation shape:
- `contains`: if `polygon.count < 3`, return `false`. First run a boundary check — for each edge (wrapping
  from the last vertex to the first), compute the point's distance to the segment; if any distance is `≤
  epsilon`, return `true`. Otherwise run the standard even-odd ray-casting test (cast a ray in the `+x`
  direction from `point`, count edge crossings, odd count = inside).
- `centroid`: arithmetic mean of `polygon`'s `x` and `y` values.
- Both functions are pure, take only their parameters, hold no state.

### 4.4 `Packages/Core/Sources/Core/Layout/LayoutEngine.swift`

```swift
import Foundation

public enum LayoutEngine {
    /// Deterministic region-constrained force layout (I14/D33 — pure function, no ambient state, no
    /// global RNG). Every returned position lies inside its own node's region polygon (L0-7). A node whose
    /// `region_id` cannot be resolved to a non-horizon `Region` in `regions` throws `mapRegionUnknown`
    /// (L0-6) rather than being clamped to a guessed position. `rng` is injected: callers control
    /// determinism directly — two calls seeded identically produce byte-identical results (AC2); two calls
    /// seeded differently produce different results for any node lacking a valid `layout_hint` (AC3, §6).
    public static func layout(
        nodes: [Node],
        regions: [Region],
        config: LayoutConfig = LayoutConfig(),
        rng: inout SeededGenerator
    ) throws -> [String: Point]
}
```

Algorithm (Jacobi-style synchronous update — every node's iteration-`i` displacement is computed from the
full position set frozen at the end of iteration `i-1`; no node's move within an iteration depends on
another node's move computed in that same iteration, so the result cannot depend on the order `nodes` is
iterated in — this is what makes AC2 hold regardless of array ordering):

1. Build `regionsById: [RegionId: Region]` from `regions` (`Dictionary(uniqueKeysWithValues:)`).
2. For every `node` in `nodes`: look up `regionsById[node.regionId]`. If it is `nil`, **or** if found but
   `region.horizon == true`, throw `CoreError.mapRegionUnknown` (AC4, AC5 — both cases raise the same code,
   per L0-6's `GRAPH_L0_FAILED{L0-6, node} / MAP_REGION_UNKNOWN` alternative and §6's default). If found and
   non-horizon but `region.polygon.count < 3`, throw `CoreError.mapLayoutMissing` (a degenerate polygon
   cannot host a valid position — §6 default). Record `polygon[node.id] = region.polygon` for every node
   that passes.
3. For every `node`, compute its initial position and anchor:
   - if `node.layoutHint` is present and `Polygon.contains(layoutHint, in: polygon, epsilon:
     config.boundaryEpsilon)` is `true`, the initial position **and** the anchor are `layoutHint` — no `rng`
     draw for this node.
   - otherwise, rejection-sample a random point inside the polygon's axis-aligned bounding box using `rng`
     (`Double.random(in:using:)` against each of the box's `x`/`y` ranges), retrying up to
     `config.maxRandomSamples` times until `Polygon.contains` accepts one; if every sample is rejected, fall
     back to `Polygon.centroid(of: polygon)` if it is contained, else `polygon[0]` (a vertex, always
     boundary-contained). This is the initial position **and** the anchor for this node — this is the RNG's
     load-bearing use (§6 default; the source of AC3's divergence).
4. For `iteration` in `0..<config.iterationCount`:
   - `step = config.maxStepFraction * pow(config.coolingFactor, Double(iteration))`.
   - For every node (using the position set from the end of the previous iteration, or step 3's initial
     set on the first iteration): sum a repulsion vector from every other node
     (`config.repulsionStrength / max(distance, config.minimumDistance)^2`, directed away from the other
     node) with an attraction vector toward its own anchor (`config.attractionStrength * (anchor -
     current)`); clamp the combined force vector's magnitude to `step`; propose `current + clampedForce`.
   - If `Polygon.contains(proposal, in: polygon, epsilon: config.boundaryEpsilon)`, the node's new position
     is `proposal`; otherwise the node keeps its pre-iteration position (reject-and-retain clamping — the
     brief's "point-in-polygon clamping each step", §3).
5. After the loop, for every node assert `Polygon.contains(finalPosition, in: polygon, epsilon:
   config.boundaryEpsilon)`; if any node fails this, throw `CoreError.mapLayoutMissing` (defensive
   postcondition guard — step 4's reject-and-retain clamping should make this unreachable, but the throw
   exists so a future algorithm change cannot silently violate L0-7).
6. Return the final `[String: Point]`, keyed by `node.id`.

Vector arithmetic (`add`, `repulsion`, `attraction`, `clampedStep`, `boundingBox`) is written as `private
static` free functions inside `LayoutEngine.swift`, not as operator overloads or extensions on `Point` — per
§6's default, `Point` is task 01.1's type and out of this task's file scope.

Error codes thrown: `CoreError.mapRegionUnknown` (step 2, region absent or horizon), `CoreError.mapLayoutMissing`
(step 2, degenerate polygon; step 5, postcondition violation) — both already registered in
`contracts/error-codes.json` and already cases of `CoreError` (task 01.1 ships the enum; this task adds no
new case).

No model-calling path exists in this task (I2): `LayoutEngine`, `Polygon` and `SeededGenerator` call no
network, no Foundation Models, no Claude API — layout is Tier 0 deterministic geometry end to end.

### 4.5 Fixtures

All fixture files are `RegionsFile`/`NodesFile`-shaped JSON (task 01.1 §4.4/§4.5's Codable shapes), decoded
in `LayoutTests.swift` with `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`.

`regions-ten.json` — ten non-horizon regions tiling the unit square as a 5×2 grid of axis-aligned rectangles
(each `[x0,y0]`–`[x1,y1]`, vertices ordered `(x0,y0),(x1,y0),(x1,y1),(x0,y1)`, matching
`contracts/examples/regions.json`'s vertex ordering convention):

| `id` | rectangle |
|---|---|
| `number-operations` | (0.0,0.0)–(0.2,0.5) |
| `algebra` | (0.2,0.0)–(0.4,0.5) |
| `functions` | (0.4,0.0)–(0.6,0.5) |
| `geometry-measurement` | (0.6,0.0)–(0.8,0.5) |
| `trigonometry` | (0.8,0.0)–(1.0,0.5) |
| `calculus` | (0.0,0.5)–(0.2,1.0) |
| `linear-algebra` | (0.2,0.5)–(0.4,1.0) |
| `differential-equations` | (0.4,0.5)–(0.6,1.0) |
| `probability-statistics` | (0.6,0.5)–(0.8,1.0) |
| `discrete` | (0.8,0.5)–(1.0,1.0) |

Every region: `horizon: false`, a non-empty `about` sentence in the project's own words (I6 — never Ministry
prose), `neighbours: []` (not exercised by this task). One worked entry:

```json
{
  "id": "number-operations",
  "name": "Number & Operations",
  "about": "Numbers, operations and the laws that govern them.",
  "horizon": false,
  "polygon": [
    { "x": 0.0, "y": 0.0 },
    { "x": 0.2, "y": 0.0 },
    { "x": 0.2, "y": 0.5 },
    { "x": 0.0, "y": 0.5 }
  ],
  "neighbours": []
}
```

`regions-ten-plus-horizon.json` — the same ten entries plus one horizon region:

```json
{
  "id": "analysis",
  "name": "Analysis",
  "about": "The horizon beyond the ten territories — not yet mapped.",
  "horizon": true,
  "polygon": [
    { "x": 0.8, "y": 0.5 },
    { "x": 1.0, "y": 0.5 },
    { "x": 1.0, "y": 0.6 },
    { "x": 0.8, "y": 0.6 }
  ],
  "neighbours": []
}
```

`regions-missing-discrete.json` — `regions-ten.json`'s ten entries minus `discrete` (nine regions).

`nodes-happy.json` — ten `Node` objects, one per `regions-ten.json` region, using the minimal required-field
set task 01.1 §4.5 establishes (`id, name, region_id, courses, position, paraphrase, error_types, hint_tree,
probe_items` required; `layout_hint` optional). Five carry a `layout_hint` inside their region's rectangle;
five omit it (to exercise the RNG path, AC3):

| `id` | `region_id` | `layout_hint` |
|---|---|---|
| `node-a1` | `number-operations` | absent |
| `node-a2` | `algebra` | `{"x":0.3,"y":0.25}` |
| `node-a3` | `functions` | absent |
| `node-a4` | `geometry-measurement` | `{"x":0.7,"y":0.25}` |
| `node-a5` | `trigonometry` | absent |
| `node-a6` | `calculus` | `{"x":0.1,"y":0.75}` |
| `node-a7` | `linear-algebra` | absent |
| `node-a8` | `differential-equations` | `{"x":0.5,"y":0.75}` |
| `node-a9` | `probability-statistics` | absent |
| `node-a10` | `discrete` | `{"x":0.9,"y":0.75}` |

`position` on every node is a placeholder (`{"x":0,"y":0}`) — it is the field `LayoutEngine` computes; the
fixture's stored value is never read by the function under test (the function takes `[Node]`/`[Region]` and
returns `[String: Point]`; it does not read `node.position`). One worked entry:

```json
{
  "id": "node-a1",
  "name": "Node A1",
  "region_id": "number-operations",
  "courses": [],
  "position": { "x": 0, "y": 0 },
  "paraphrase": "Placeholder node for the layout fixture.",
  "error_types": [],
  "hint_tree": {},
  "probe_items": []
}
```

`nodes-unknown-region.json` — one node, `id: "node-b1"`, `region_id: "discrete"`, no `layout_hint`, otherwise
the same minimal shape — paired with `regions-missing-discrete.json` for AC4.

`nodes-horizon-region.json` — one node, `id: "node-c1"`, `region_id: "analysis"`, no `layout_hint`, otherwise
the same minimal shape — paired with `regions-ten-plus-horizon.json` for AC5.

### 4.6 `Packages/Core/Tests/CoreTests/LayoutTests.swift`

Locate `Packages/Core/Tests/CoreTests/Fixtures/layout/` from `#filePath` the same way
`CoreTests.swift:coreImportBoundary()` (§3) locates `Sources/Core`: `URL(fileURLWithPath: #filePath)` for
`LayoutTests.swift` lives at `Packages/Core/Tests/CoreTests/LayoutTests.swift`, so exactly one
`.deletingLastPathComponent()` reaches the containing `CoreTests/` directory; append
`"Fixtures/layout/<name>.json"` from there. Decode each fixture pair with
`JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase` into `RegionsFile`/`NodesFile`, then pass
`.regions`/`.nodes` to `LayoutEngine.layout`.

- `@Test("layout places every node inside its own region polygon")` — AC1: load `regions-ten.json` +
  `nodes-happy.json`; assert `nodesFile.nodes.count == 10` before checking anything (anti-vacuity); call
  `LayoutEngine.layout(nodes:regions:rng:)` with `var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)`;
  for every node, assert `Polygon.contains(result[node.id]!, in: <that node's region polygon>, epsilon:
  LayoutConfig().boundaryEpsilon)`.
- `@Test("layout is deterministic for the same seed")` — AC2: call `layout` twice over the same fixture,
  each with its own fresh `SeededGenerator(seed: LayoutConfig.defaultSeed)`; encode both `[String: Point]`
  results with `JSONEncoder(outputFormatting: [.sortedKeys])`; assert the two `Data` values are `==`.
- `@Test("a different seed changes the arrangement")` — AC3: call `layout` a third time with
  `SeededGenerator(seed: LayoutConfig.defaultSeed &+ 1)`; assert its encoded `Data` differs from the AC2
  result's encoded `Data`.
- `@Test("a node in an unknown region throws mapRegionUnknown")` — AC4: load `regions-missing-discrete.json`
  + `nodes-unknown-region.json`; assert `LayoutEngine.layout` throws, and the thrown error, cast to
  `CoreError`, is `.mapRegionUnknown`.
- `@Test("a node in a horizon region throws mapRegionUnknown")` — AC5: load
  `regions-ten-plus-horizon.json` + `nodes-horizon-region.json`; assert the same throw/cast pattern.
- `@Test("LayoutConfig is the only source of tuning constants")` — AC6: read
  `Packages/Core/Sources/Core/Layout/LayoutEngine.swift` and `Polygon.swift` as text (same `#filePath`-derived
  path pattern); assert (by a narrow regex or manual scan documented in a comment) that no bare
  floating-point or multi-digit integer literal appears outside `LayoutConfig.swift`, `0`, `1`, and loop/array
  indices; this is a text-level regression guard, not a semantic one — document that limitation in the test's
  comment.

### 4.7 Smoke check

`( cd Packages/Core && swift build -c release --product core-cli )` — must be green (compiles `Core`,
including the new `Layout/*.swift` files, even though `CoreCLI` does not reference them yet — task 01.4's
job).

## §5 Test plan (risk: seam — full plan)

- T1 happy path: `LayoutTests`'s AC1 case — every node lands inside its own polygon over the ten-region
  fixture, with the fixture-count anti-vacuity guard as part of the same test (§4.6).
- T2 negative — invalid input rejected at the boundary: AC4's case — a node naming a region wholly absent
  from the regions fixture throws rather than producing a clamped guess.
- T3 error-taxonomy: both AC4 and AC5 assert the thrown error, cast to `CoreError`, equals exactly
  `.mapRegionUnknown` (the registry code `MAP_REGION_UNKNOWN`) — not merely "an error was thrown."
- T4 conformance per requirements §B.1 (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §5 — "map:
  I8 region/coordinates refusal (`MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`); layout determinism."): T1
  (containment / L0-7), T2+T3 (`MAP_REGION_UNKNOWN` / L0-6) and AC2/AC3 (determinism) together are this
  rung; no separate test is needed.
- T5 negative control for every regression guard:
  - the horizon-rejection guard (AC5): distinguishing it from AC4 by using a region that IS present in the
    fixture (unlike AC4's genuinely-absent region) is the negative control — before the `region.horizon ==
    true` check exists in step 2, this fixture's node would resolve to a real `Region` and layout would
    proceed to clamp it into the horizon region's polygon instead of throwing; the test as written would
    catch that regression because it asserts the throw, not merely that a position was returned.
  - the RNG load-bearing guard (AC3): a `LayoutEngine` that computed the hint-less nodes' initial positions
    from, e.g., a fixed formula instead of `rng` would make AC2's two calls still pass (same seed, same
    result) but AC3's differently-seeded call would produce byte-identical `Data` to AC2's — AC3 is the
    negative control that catches an `rng` parameter that is accepted but never actually consulted.
  - the `LayoutConfig`-only-constants guard (AC6): the text-scan test itself is the negative control — it is
    written to fail loudly (non-empty violation list in its `#expect` message) the moment a literal like
    `0.0005` is typed directly into `LayoutEngine.swift` instead of read from `config.repulsionStrength`.
- T6 idempotency / no-leak:
  - AC2's two-call determinism test is this task's idempotency case: two independent calls to the pure
    `LayoutEngine.layout` function, each with its own freshly constructed `SeededGenerator`, over the same
    `[Node]`/`[Region]` input, produce byte-identical output — no hidden state carries over between calls
    (the function takes no global/static mutable state; `nodes` and `regions` are `Equatable` value-type
    array parameters, immutable to the callee by Swift's value semantics, so a throw partway through step 2
    cannot have mutated the caller's arrays — this is a structural guarantee from Swift's type system, stated
    here as the contract-level assertion rather than a runtime check, matching how task 01.1's `BundleIO.read`
    no-leak case is framed).

## §6 Decision defaults

- IF a node's `layout_hint` is present but not inside its region's polygon (`Polygon.contains` returns
  `false` for it) THEN treat it as absent — fall back to rejection-sampled initial placement (§4.4 step 3).
  Rationale: the postcondition (every returned position inside its own polygon) must hold regardless of bad
  `layout_hint` data; `Core`'s `Codable` layer does not validate that `layout_hint` lies inside its node's
  region at decode time (task 01.1 §4.1 — pattern/range conformance beyond the schema's own `minimum`/
  `maximum` is not a decode-time concern), so `LayoutEngine` defends the postcondition itself.
- IF a region's polygon decodes with fewer than 3 vertices THEN `LayoutEngine.layout` throws
  `CoreError.mapLayoutMissing` before running any simulation iteration (§4.4 step 2) — `regions.schema.json`'s
  `minItems: 3` (quoted in §3) is a schema-level constraint task 01.1's `Codable` layer does not re-enforce at
  decode time, so a malformed regions file could otherwise reach this function; `MAP_LAYOUT_MISSING`'s
  registered meaning ("a node ... has no [valid] coordinates", `docs/domains/map.md`, quoted in §3) is the
  closest fit among the two codes this task raises.
- IF a node's `region_id` resolves to a `Region` entry that exists but has `horizon == true` THEN
  `LayoutEngine.layout` throws `CoreError.mapRegionUnknown` — the same code as a wholly absent region — per
  `contracts/graph-constraints.md` L0-6's `GRAPH_L0_FAILED{L0-6, node} / MAP_REGION_UNKNOWN` alternative
  (quoted in §3): `Core`'s layout function is the `MAP`-prefixed consumer of this rule, so it raises
  `MAP_REGION_UNKNOWN`; `GRAPH_L0_FAILED{L0-6}` is task 01.2's L0 checker's own code for the same underlying
  condition when it re-checks a written bundle.
- IF the implementer needs vector arithmetic on `Point` (addition, magnitude, scaling) THEN write `private
  static` free functions inside `LayoutEngine.swift`, never operator overloads or methods added to the
  `Point` type itself — `Model/Ids.swift`, where `Point` is declared, is task 01.1's file and is not in this
  task's file scope (§2); this task must not modify it.
- IF a future fixture introduces a non-convex (concave) region polygon THEN `Polygon.centroid` may fall
  outside it; the rejection-sampling fallback chain in §4.4 step 3 (bounding-box samples → centroid, if
  contained → `polygon[0]`, always boundary-contained) already covers this without special-casing convexity.
  Every polygon this task's own fixtures ship (§4.5) is an axis-aligned rectangle — convex by construction —
  so this branch is not exercised by this task's own tests; it exists for forward robustness.
- IF fixture loading appears to need a `resources:` clause in `Package.swift` THEN it does not: `LayoutTests`
  locates `Fixtures/layout/` the same way task 01.1's `DecodeRoundTripTests.swift` locates
  `contracts/examples/` — an absolute path derived from `#filePath` at test-run time, read directly off disk
  via `FileManager`/`String(contentsOf:)`, not through SPM's bundled-resource mechanism. `Package.swift` is
  therefore outside this task's file scope, and this task does not need to coordinate with task 01.1 over
  it — the ambiguity the planner flagged does not arise because neither task touches the file.
- Standing defaults: identifiers/timestamps are out of scope for this task (no identifier or date field is
  introduced by `LayoutEngine`, `LayoutConfig`, `SeededGenerator` or `Polygon`); layout is Tier 0 with no
  model call anywhere (I2); the function introduces no identifying field; the returned `[String: Point]` is
  not itself persisted by this task — writing it into `nodes.json` is `core-cli layout`'s job (task 01.4).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean
  over the four new `Layout/*.swift` files and `LayoutTests.swift`.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3, `$SIM` from `scripts/pick-simulator.sh`).
- All cases in §5 (T1–T6) pass, including every `@Test` in §4.6.
- Conforms to every contract section cited in §3 (`contracts/graph-constraints.md` L0-6/L0-7,
  `contracts/error-codes.json`'s `MAP_LAYOUT_MISSING`/`MAP_REGION_UNKNOWN` entries,
  `contracts/schemas/nodes.schema.json` and `regions.schema.json` coordinate bounds) and to every invariant
  listed in §1 (I2, I8, I11, I14).
- `scripts/gate.sh` gates 1 and 3 green in full (gates 2 and 4 are pipeline/App-scoped and unaffected by this
  task's file scope).

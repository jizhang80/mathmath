# Task 01.03 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: region-constrained-layout
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 01
- Task: 03
- Slug: region-constrained-layout
- Summary: A deterministic region-constrained force layout in `Core` — a pure function over value types with an injected seeded RNG, all tuning constants in one `LayoutConfig`, point-in-polygon clamping each step, seeded from a fixed constant so two runs are byte-identical.
- Invariants in play: I1 (CAS-only step verification), I2 (Tier 0 alone usable), I6 (no Ministry prose), I8 (L0 checks), I11 (quantitative claims tagged), I14 (`Core` Foundation-only, layout once, test asserts import boundary)

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md — §Collections — position and layout_hint coordinate space
> | File | Schema | Notes |
> |---|---|---|
> | `nodes.json` | `nodes.schema.json` | `id`, `name`, `region_id`, `strand?`, `expectation_codes[]?`, `source_ref?` (**at least one**), `courses[] {course_code, depth}`, `position {x,y}` (from `core-cli layout`), `layout_hint?`, `paraphrase`, `explanation?`, `worked_examples[]?`, `error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` |
> | `regions.json` | `regions.schema.json` | ten regions + horizon labels (+ shore); normalised polygon, `neighbours[]`, `about` (one sentence) |

Source: `contracts/data-model.md:45-52`
Binds this task: `position` is the output of layout; `layout_hint` is the input seed; both are `{x,y}` with range [0,1] (normalised coordinates within the region polygon).

### contracts/data-model.md — §Collections — coordinate bounds and normalization
> Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means `Core` needs a migration; the app refuses a bundle whose major differs from its own.

Source: `contracts/data-model.md:25-26`
Binds this task: layout must respect format versioning; layout output is part of the bundle and carries the same version contract.

### contracts/graph-constraints.md — L0-7 rule (position inside region polygon)
> | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by `core-cli layout`; checked after it |

Source: `contracts/graph-constraints.md:19`
Binds this task: this is the acceptance criterion for layout; every positioned node must fall strictly inside (or on the boundary of) its region's polygon, or L0 fails with `MAP_LAYOUT_MISSING`.

### contracts/graph-constraints.md — L0-6 rule (region validity)
> | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. | `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |

Source: `contracts/graph-constraints.md:18`
Binds this task: layout must reject nodes with invalid region ids; `MAP_REGION_UNKNOWN` is raised if the region does not exist.

### contracts/error-codes.md — error code registry rules
> Codes are stable strings `<DOMAINPREFIX>_<REASON>`; a change is a versioned change. Additive registration (a new code with its domain doc row) is allowed without a version bump.

Source: `contracts/error-codes.md:8-9`
Binds this task: layout errors must use codes from the registry; two codes are in scope: `MAP_LAYOUT_MISSING` and `MAP_REGION_UNKNOWN`.

### contracts/error-codes.md — error code definition
> `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG` codes; the App and the pipeline each map their own. A code raised in code but absent from the registry fails the round-trip test.

Source: `contracts/error-codes.md:15-17`
Binds this task: layout errors are raised as `CoreError` cases; the registry must include `MAP_LAYOUT_MISSING` and `MAP_REGION_UNKNOWN`.

### contracts/error-codes.json — full registry
> ```json
> {
>   "contract_version": "1.0.0",
>   "prefixes": {
>     "MAP": "map", "EXP": "expedition", "DIAG": "diagnosis", "GRAPH": "concept-graph", "LO": "learning-objects",
>     "SPINE": "curriculum-spine", "GEN": "content-generation", "PLATFORM": "platform", "TELEM": "telemetry",
>     "TIER": "runtime-tiers", "VERIFY": "verification"
>   },
>   "codes": [
>     {"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "MAP_REGION_UNKNOWN", "recoverable": true, "surface": "internal", "user_text": null},
>     ...
>   ]
> }
> ```

Source: `contracts/error-codes.json:1-24` (full file; excerpt shows the two relevant codes at lines 9-10)
Binds this task: both `MAP_LAYOUT_MISSING` and `MAP_REGION_UNKNOWN` are in the registry as internal, recoverable errors.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — Core entities: Region
> **Region** — one of the ten D21 (revised) territories — Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus · Linear Algebra · Differential Equations · Probability & Statistics · Discrete Mathematics — or a horizon label (Analysis, Topology, Number Theory, Abstract Algebra), or the optional "shore" (grade 7–8; drawn, no content, no fog; not in the Demo — decided at M5): `id`, `name`, `polygon` (normalised coordinates, hand-authored for the Demo, pipeline-authored later), `horizon: bool`, `neighbours[]`, and one sentence on what the territory is about (project's own words, I6). A `horizon` region is a label with no nodes and is not tappable. Every `Node` (**concept-graph**) has exactly one region (I8).

Source: `docs/domains/map.md:29-36`

### docs/domains/map.md — Core entities: NodeView (as drawn, with coordinates from bundle)
> **NodeView** — a node as drawn: its coordinates (from the bundle, D42), its region, its mastery state from `StudentState` (**expedition**) projected to a fog level — `fog` (full), `blocked` (fog with a marker), `cleared` (lifted), plus a `due` ring when spaced repetition has come round (Q1) — and whether it lies upstream of the current trail's marker.

Source: `docs/domains/map.md:49-52`

### docs/domains/map.md — Invariants enforced: I14 and I8 region/coordinates
> - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).
> - **I8** — L0 lives in `Core` and is the only acceptance path; the pipeline wrapper refuses to emit a bundle whose report has `passed: false` (test). I14 — `Core` gains no import beyond Foundation (existing boundary test); layout is a pure function with an injected seeded RNG (determinism test: two runs, byte-equal positions).

Source: `docs/domains/map.md:131-132, 136-139` (from EPIC 01 brief equivalently: line 43-47)

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §2 Goal & scope: layout requirement
> Give the product its data spine: `Core` can decode every bundle file of `contracts/data-model.md`, validate a bundle against every L0 rule of `contracts/graph-constraints.md`, and **lay nodes out deterministically inside their regions**; the pipeline can invoke both through `core-cli`; and the Demo's hand-written bundle exists, passes L0, and every piece of math in it is known to render. In scope: concept-graph W1 (L0 checker, in `Core`, `core-cli validate`) and **the layout function** (`core-cli layout`, **region-constrained force layout seeded by `layout_hint`, deterministic across runs** — `map.md` Core entities, D33);

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:9-14`

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §3 Contracts: I8 layout is the map projection
> **MANDATORY (R-6) brief-checklist line:** config/registry-bearing modules in scope: the error registry (`error-codes.json` — `CoreError` must fail its build-time test if a case is off-registry: covered by the registry round-trip, `READ-ONLY`); the bundle manifest (`PLATFORM_BUNDLE_INTEGRITY_FAILED` on a partial or hash-mismatched manifest — registered, `READ-ONLY`; exercised by `core-cli validate` refusing a bundle whose manifest names a missing file); the region vocabulary (`MAP_REGION_UNKNOWN`, registered, `READ-ONLY`). No BUMP needed.
>
> **MANDATORY invariant line:** I8 — L0 lives in `Core` and is the only acceptance path; the pipeline wrapper refuses to emit a bundle whose report has `passed: false` (test). **I14 — `Core` gains no import beyond Foundation (existing boundary test); layout is a pure function with an injected seeded RNG (determinism test: two runs, byte-equal positions).** I6 — the demo bundle's paraphrases are the project's own words; the `verbatim` grep and the 140-char schema bound apply; no Ministry prose is pasted (the author of the bundle writes from the codes, not from the document). I15 — the landmark's `source_url` is fetched by the pipeline test (HTTP 2xx, page text contains "Interest Act"); on failure the landmark is dropped, never edited into truth. I9 — no review step: the bundle is hand-written *data* (D26 allows it for the Demo), validated by machine; a failing item is rewritten, not approved. I1 / I10 — every item is `numeric` or `mc` with a checked `answer`/`correct_choice_id`; the pipeline re-derives every numeric answer with SymPy where the prompt is expressible (a test lists the items it could not express, empty = FAIL for this bundle since all are simple). I11 — the rendering-spike outcome and the L0 report carry no untagged numbers.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:36-54`

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §4 Acceptance criteria, criterion 3: layout determinism
> 3. `core-cli layout data/demo` writes `position` for every node inside its region polygon; running it twice yields byte-identical `nodes.json`.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:69`

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §5 Conformance tests: map.md I8 region/coordinates and layout determinism
> - map: I8 region/coordinates refusal (`MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`); layout determinism.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:86`

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §7 Out of scope: layout is not from generation or pipeline extraction
> 1. Student state transitions, fringe, scheduler, trail generation, diagnosis machine — EPIC 02.
> 2. Any rendering of the map or screens — EPIC 03/04. `Rendering` ships only `RenderCheck` here; `MathView` is EPIC 03's.
> 3. Pipeline generation of content (Claude API), spine extraction — EPICs 05–09; the Demo bundle is hand-written by design (D26).

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:96-100`

### docs/epics/epic-01-core-data-l0-layout-demo-bundle.md — §9 Open question 1: layout algorithm (FULL)
> - Layout algorithm details (repulsion/attraction constants, iteration count, polygon containment method) — **default:** a simple Fruchterman–Reingold-style loop with a fixed iteration count [ESTIMATE: 300] and point-in-polygon clamping each step, seeded RNG from a fixed constant; any constants live in one `LayoutConfig`. Revisit at M2 when the real graph exists (a few hundred nodes).

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:113-116`

### contracts/schemas/nodes.schema.json — position and layout_hint coordinate fields (normative)
> ```json
>           "position": {
>             "type": "object",
>             "properties": {
>               "x": {
>                 "type": "number",
>                 "minimum": 0,
>                 "maximum": 1
>               },
>               "y": {
>                 "type": "number",
>                 "minimum": 0,
>                 "maximum": 1
>               }
>             },
>             "required": [
>               "x",
>               "y"
>             ],
>             "additionalProperties": false
>           },
>           "layout_hint": {
>             "type": "object",
>             "properties": {
>               "x": {
>                 "type": "number",
>                 "minimum": 0,
>                 "maximum": 1
>               },
>               "y": {
>                 "type": "number",
>                 "minimum": 0,
>                 "maximum": 1
>               }
>             },
>             "required": [
>               "x",
>               "y"
>             ],
>             "additionalProperties": false
>           },
> ```

Source: `contracts/schemas/nodes.schema.json:112-150`

### contracts/schemas/regions.schema.json — polygon coordinate field (normative)
> ```json
>           "polygon": {
>             "type": "array",
>             "items": {
>               "type": "object",
>               "properties": {
>                 "x": {
>                   "type": "number",
>                   "minimum": 0,
>                   "maximum": 1
>                 },
>                 "y": {
>                   "type": "number",
>                   "minimum": 0,
>                   "maximum": 1
>                 }
>               },
>               "required": [
>                 "x",
>                 "y"
>               ],
>               "additionalProperties": false
>             },
>             "minItems": 3
>           },
> ```

Source: `contracts/schemas/regions.schema.json:47-70`

### contracts/examples/nodes.json — position and layout_hint in use (excerpt)
> ```json
> {
>   "id": "exponent-laws",
>   "name": "Exponent laws",
>   "region_id": "number-operations",
>   ...
>   "position": {
>     "x": 0.08,
>     "y": 0.12
>   },
>   ...
> }
> ```

Source: `contracts/examples/nodes.json:1-24` (full file shown; excerpt shows the position field in context)

### contracts/examples/regions.json — polygon in use (excerpt)
> ```json
> {
>   "id": "number-operations",
>   "name": "Number & Operations",
>   "about": "Numbers, operations and the laws that govern them.",
>   "horizon": false,
>   "polygon": [
>     {
>       "x": 0.0,
>       "y": 0.0
>     },
>     {
>       "x": 0.19,
>       "y": 0.0
>     },
>     {
>       "x": 0.19,
>       "y": 0.3
>     },
>     {
>       "x": 0.0,
>       "y": 0.3
>     }
>   ],
>   "neighbours": []
> }
> ```

Source: `contracts/examples/regions.json:4-28` (full file shown; excerpt shows one complete region with its polygon)

### CLAUDE.md — Invariant I14 (Core imports Foundation only, layout once)
> | I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42 |

Source: `CLAUDE.md:37-38`
Binds this task: layout function must be in `Core` only; no SwiftUI, UIKit, SpriteKit, or any other framework beyond Foundation; the test that asserts this boundary already exists and will be extended.

### CLAUDE.md — Invariant I11 (quantitative claims tagged)
> | I11 | Docs: every quantitative claim tagged `[SOURCED]`/`[ESTIMATE]`; **no time estimates**. | §12 |

Source: `CLAUDE.md:34-35`
Binds this task: any numeric constant in code or test (iteration count, tolerance, etc.) must be documented with a source or estimate tag; no time estimates in docs.

### docs/tech-stack.md — §1 Choices: Swift Testing framework and version
> | Swift tests | **Swift Testing** (`import Testing`) for `Core`; XCTest only where UI testing needs it | Xcode-bundled | first-party; expressive `#expect` | `Testing.framework` present in the iOS platform of Xcode 26.6 (local `ls`) |

Source: `docs/tech-stack.md:22`
Binds this task: tests must use `import Testing` and `#expect`, not XCTest assertions, for the `Core` test target.

### docs/tech-stack.md — §1 Choices: Swift 6 and toolchain version
> | Student app language | **Swift 6** (language mode 6, strict concurrency `complete`) | toolchain: Swift 6.3.3 (Xcode 26.6, 17F113) on this Mac; package `swift-tools-version: 6.2` so any Xcode 26.x builds it | D32; strict typing + compile-time failure surface (preferences meta-principle) | Local: `swift --version`, `xcodebuild -version` 2026-09-09. Xcode 26.6 ships Swift 6.3 and iOS 26.5 SDK |

Source: `docs/tech-stack.md:14`
Binds this task: `swift-tools-version: 6.2` in `Package.swift`; Swift 6 language mode with strict concurrency enabled.

### docs/tech-stack.md — §2 Repository layout: Core ownership and test location
> Ownership by domain (a spec's §2 file scope is authoritative): `Packages/Core` — concept-graph (types, L0, query), map (layout, `MapViewModel`), expedition (`StudentState`, scheduler, transitions), diagnosis (hypothesis machine), platform (state merge);

Source: `docs/tech-stack.md:63-67`
Binds this task: layout lives in `Packages/Core/Sources/Core/`; tests in `Packages/Core/Tests/CoreTests/`.

### docs/tech-stack.md — §3 Gates: Core build and test command
> echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
> ( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
> ( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
> ( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )

Source: `docs/tech-stack.md:75-79` (quoted from `scripts/gate.sh` lines 16-19, which is the authoritative gate definition)

### scripts/gate.sh — full gate script (normative)
> ```sh
> #!/bin/sh
> # The four gates (R-1) for mathmath, as locked in docs/tech-stack.md. Agents run this before every commit;
> # CI runs the same steps. Exit non-zero on the first failure.
> set -eu
> ROOT="$(cd "$(dirname "$0")/.." && pwd)"
> SIM="$("$ROOT/scripts/pick-simulator.sh")"
> echo "simulator destination: $SIM"
> 
> echo "== 1/4 format + lint =="
> xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
> ( cd "$ROOT/pipeline" && uv run ruff check . && uv run ruff format --check . )
> 
> echo "== 2/4 typecheck =="
> ( cd "$ROOT/pipeline" && uv run pyright )
> 
> echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
> ( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
> ( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
> ( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
> 
> echo "== 4/4 App build on the simulator + pipeline tests =="
> xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
> ( cd "$ROOT/pipeline" && uv run pytest -q )
> 
> echo "gates green"
> ```

Source: `scripts/gate.sh:1-26` (full file)

## §D. Prior task outputs this task depends on

**INCOMPLETE — Task 01.1 has not been authored yet.** The spec for task 01.1 will produce `Core` `Codable` bundle types (manifest, regions, nodes, edges, courses, landmarks, sources, student-state) under `Packages/Core/Sources/Core/Model/`. This task (01.3) will:
- Consume the `Node` type with `region_id`, `position`, `layout_hint` fields
- Consume the `Region` type with `id`, `polygon` field
- Consume the data-loading infrastructure to read bundles
- Use `CoreError` enum to raise `MAP_LAYOUT_MISSING` and `MAP_REGION_UNKNOWN` errors

These types must exist for task 01.3 to compile.

## §E. Negative facts (confirmed ABSENT)

- **No layout modules exist yet.** Grep `Packages/Core/Sources/Core` for `Layout`, `Polygon`, `SeededGenerator`, `LayoutConfig`: no matches. Source: `Glob pattern "Packages/Core/Sources/Core/**/*.swift"` returned only `Core.swift`.
- **No fixtures directory under CoreTests.** Glob `Packages/Core/Tests/CoreTests/Fixtures/**` returned empty. The directory must be created.
- **No `resources:` parameter in Core Package.swift.** Read `Packages/Core/Package.swift`: lines 18-29 define targets; no `.resources` specified. If fixtures are JSON files, `Package.swift` may need a resources clause.
- **No third-party layout or polygon library imported.** Core `Package.swift` declares no dependencies beyond Foundation. `Packages/Rendering` imports only SwiftMath; neither imports a spatial-math or force-layout library. Polygon clamping and FR loop are hand-written.
- **No time estimates in stack.** Grep `docs/tech-stack.md` for `[ESTIMATE:` returns one match: "iteration count [ESTIMATE: 300]" on `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:115`. All other numerics carry `[SOURCED: …]` tags. The iteration count is the only estimate.

## §F. File scope

- CREATE `Packages/Core/Sources/Core/Layout/LayoutEngine.swift` — core force-layout algorithm function.
- CREATE `Packages/Core/Sources/Core/Layout/LayoutConfig.swift` — tuning constants (repulsion, attraction, iteration count, etc.).
- CREATE `Packages/Core/Sources/Core/Layout/SeededGenerator.swift` — seeded random number generator wrapper.
- CREATE `Packages/Core/Sources/Core/Layout/Polygon.swift` — point-in-polygon collision detection and clamping.
- CREATE `Packages/Core/Tests/CoreTests/LayoutTests.swift` — determinism, region-boundary, error-code, and contract tests.
- CREATE `Packages/Core/Tests/CoreTests/Fixtures/layout/**/*.json` — hand-written test bundles (or references to `contracts/examples/`).
- MODIFY `Packages/Core/Sources/Core/Core.swift` — if new public types are added.
- MODIFY `Packages/Core/Tests/CoreTests/CoreTests.swift` — import-boundary test may be extended if new forbidden imports are discovered.
- MODIFY `Packages/Core/Package.swift` — may need `resources:` if fixtures are bundled; currently no resources declared (line 26 test target has no resources).

## §G. Stack constraints relevant here

### Boundary validation
The import-boundary test at `Packages/Core/Tests/CoreTests/CoreTests.swift:17-39` asserts that `Core` has no SwiftUI, UIKit, AppKit, SpriteKit, SwiftData, FoundationModels, CoreData, or Combine imports. Layout code must import Foundation only.

Source: `Packages/Core/Tests/CoreTests/CoreTests.swift:19-21` (the forbidden list).

Specifically for this task: layout must not import FoundationModels (Tier 1 would belong in App/Sources adapters, not Core). The seeded RNG and point-in-polygon math come from Foundation or are hand-written.

### Random number generator availability
Foundation exposes `RandomNumberGenerator` protocol and `SystemRandomNumberGenerator` struct via the Swift standard library (imported through Foundation). Both are available on iOS 18+. The layout engine will inject a seeded generator conforming to `RandomNumberGenerator` to enable determinism.

Source: Swift stdlib docs; verified in Foundation docs [SOURCED: https://developer.apple.com/documentation/foundation]. The seeded generator takes a fixed seed constant so two runs produce byte-identical layouts.

### Polygon containment method
Point-in-polygon test is hand-written (ray-casting or winding-number algorithm, no third-party library). Clamping pushes a node inside the region polygon if it falls outside. All arithmetic is Double (matching the schema's number type).

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:115` — "point-in-polygon clamping each step".

### Error codes to use
- `MAP_LAYOUT_MISSING` (internal, recoverable) — a node has no valid `position` or falls outside its region polygon after layout.
- `MAP_REGION_UNKNOWN` (internal, recoverable) — a node names a region that does not exist in `regions.json`.

Source: `contracts/error-codes.json:9-10`; both must be cases in the `CoreError` enum.

### Determinism requirement
Running layout twice on the same bundle with the same seeded RNG produces byte-identical JSON positions for every node.

Test: `core-cli layout data/demo` run twice; `diff` the resulting `nodes.json` files; must be identical.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:69` and CLAUDE.md I14 — "determinism test: two runs, byte-equal positions".

### Configuration constants in one place
All tuning constants (repulsion, attraction, iteration count, damping, tolerance for point-in-polygon, clamping velocity) live in a single `LayoutConfig` struct, not scattered in the algorithm code.

Iteration count: [ESTIMATE: 300] per the epic brief.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:115-116`.

### Tooling constraints
- Swift compiler: Swift 6.2 / Xcode 26.6, strict concurrency enabled.
- Test runner: Swift Testing (`import Testing`, `@Test`, `#expect`).
- Build gate: `swift build -c release --product core-cli` and `xcodebuild test -scheme Core-Package -destination <iOS sim>`.

Source: `scripts/gate.sh:16-18`; `docs/tech-stack.md:22`.

### No model calls
Layout is Tier 0 (deterministic, no model). No `FoundationModels`, no Claude API, no Tier 1/2 paths.

Source: CLAUDE.md I2 — "Tier 0 alone must be a usable product"; I1 — "step correctness is decided by CAS, never by a language model" (layout is deterministic geometry, not step verification, but the principle holds: no models).

### Quantitative claims must be tagged
Any magic number in code (e.g., repulsion constant, iteration count) or in a doc/comment must carry `[SOURCED: …]` or `[ESTIMATE: …]`.

Source: CLAUDE.md I11; `contracts/content-policy.md` (implied in the registry of claims).

---

## Q-protocol notes

**Q1 (information — answered from contracts/docs):**
- Coordinate space: [0, 1] normalized within each region. ✓
- Iteration count: [ESTIMATE: 300]. ✓
- Algorithm: Fruchterman–Reingold-style with point-in-polygon clamping each step, seeded RNG. ✓
- Error codes: `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`. ✓

**Q2 (retry with different query):**
- Polygon coordinate type: Double, from schema. ✓
- Test framework: Swift Testing. ✓
- Import boundary: Foundation only (I14 asserted by existing test). ✓

**No Q3 (bypass), Q4 (spec drift), or Q5 (owner decision) issued during compilation.**

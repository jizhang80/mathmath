# Task 03.9 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: app-sources-i14-scan

Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 09
- Slug: app-sources-i14-scan
- Summary: A Core test scanning `App/Sources` recursively for violations of I14 (Core transitions outside the façade), I5 (PII / data reads), I1/I10 (free-text answers, OCR, item checks), and D24 (third-party engines, FoundationModels). Planted negative controls per violation class; empty scan fails.
- Invariants in play: I1, I2, I5, I10, I14 (primary); I4 (supporting). D24 binding decision.

## §B. Applicable contract rules (verbatim)

### CLAUDE.md — I1 (Hard invariants table)
> **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No code path lets a model output decide whether a step or a probe answer is right; expedition items are checked deterministically in code.

Source: `CLAUDE.md:24`
Binds this task: no `App/Sources` code path can import or call any free-text answer checker, OCR path, or model-powered item verification; the scan rejects these at the import boundary.

### CLAUDE.md — I2 (Hard invariants table)
> **Tier 0 alone must be a usable product**: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis.

Source: `CLAUDE.md:25`
Binds this task: Tier 0 is the App's guaranteed ceiling during its use (D34); no model imports in `App/Sources` except the designated adaptation layer (Foundation Models framework, gated to iOS 26+, out of scope for this Core test).

### CLAUDE.md — I5 (Hard invariants table)
> **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP. Cross-device sync uses Apple-managed identity only.

Source: `CLAUDE.md:28`
Binds this task: no `App/Sources` code reads local `data/` paths (which carry course ids, node ids, and graph topology not meant for the App's own use); the scan rejects filesystem reads of `data/` explicitly.

### CLAUDE.md — I10 (Hard invariants table)
> **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a structured math editor; **no OCR in any door.**

Source: `CLAUDE.md:33`
Binds this task: no OCR import or call path anywhere in `App/Sources`; the scan rejects Vision or other OCR frameworks.

### CLAUDE.md — I14 (Hard invariants table)
> **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Source: `CLAUDE.md:37`
Binds this task: the source scan is the assertion; no `App/Sources` code constructs a `StudentState`, calls `MarkerTrail`, `MasteryTransitions`, `Expedition`, `ExpeditionRun`, `L0Checker`, `BundleIO`, `LayoutEngine` or `MapViewModel.derive` directly; all state transitions flow through `Core`'s public façade (`MapLaunch.open` and `MapFacade` entry points per 03.7).

### CLAUDE.md — D24 (Hard invariants table reference, principal languages section)
> No third-party game engine (D24); Apple's first-party SpriteKit is permitted only if `Canvas` performance demands it.

Source: `CLAUDE.md:12`
Binds this task: scan rejects FoundationModels imports (Tier 1, handled by the App's adapter layer outside `Core`), and any other third-party engine library.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — Invariants enforced here
> - **I14 — co-owner.** `MapViewModel` derivation lives in `Core`; the SwiftUI/`Canvas` layer imports it and computes nothing; a test asserts `Core` has no SwiftUI, UIKit or SpriteKit import (D33).

Source: `docs/domains/map.md:131-132`
Binds this task: the App's map rendering layer (SwiftUI) imports `MapViewModel` as a read-only value; no re-derivation or state compute.

### docs/domains/platform.md — Invariants enforced here
> - **I14** — this domain reads and writes `StudentState` as an opaque `Codable` value from `Core` and merges via a `Core` function; it defines no state shape and no transition.

Source: `docs/domains/platform.md:112-113`
Binds this task: the App's persistence layer (platform domain) in `App/Sources` reads and writes through `StudentStateStore` (a `Core` type); it never constructs or mutates a `StudentState` directly.

## §D. Prior task outputs this task depends on

- `MapLaunch.open(snapshotDir:stateURL:today:) -> LaunchOutcome` — signature from `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.2. Public façade entry point, the sole `Core` launch path.
- `MapState` struct — signature from `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1. The App's one handle onto a live map; never partially mutated.
- `MapFacade` enum with public static methods `nodePanelContent`, `regionPanelContent`, `landmarkPanelContent`, `selectCourse`, `setMarker`, `include`, `unitExpedition`, `checkHere` — signatures from `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.3–§4.5. All façade entry points for state-changing and read-only actions.
- `StudentState`, `Marker`, `Trail` types — exist in `Packages/Core/Sources/Core/Model/StudentState.swift`; must not be constructed by the App.
- `StudentStateStore.read`, `StudentStateStore.write` — exist in Core; the persistent-store interface the App calls (indirectly via the façade).
- `MarkerTrail` type (plural methods: `setMarker`, `reconcileMarker`, `defaultMarker`, `reconcileNodeIds`, `generateTrail`) — exist in `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`; must not be called by the App directly outside the façade.
- `Expedition` type — exists in `Packages/Core/Sources/Core/State/Expedition.swift`; must not be called by the App directly outside the façade.
- `MasteryTransitions` type — exists in `Packages/Core/Sources/Core/State/MasteryTransitions.swift`; must not be called by the App.
- `L0Checker` type — exists in `Packages/Core/Sources/Core/Validation/L0Checker.swift`; must not be called by the App.
- `BundleIO` type — exists in `Packages/Core/Sources/Core/BundleIO.swift`; must not be called by the App.
- `LayoutEngine` type — exists in `Packages/Core/Sources/Core/Layout/LayoutEngine.swift`; must not be called by the App.
- `MapViewModel` type with `derive` static method — will be created by task 03.6; must not be called by the App except via the façade (indirectly).
- `DiagnosisRun` type — created by EPIC 02b (task 02.11); used only through `MapFacade.checkHere` which calls `DiagnosisRun.open` for pure construction, never the step-wise API.

## §E. Negative facts (confirmed ABSENT)

- `App/Sources/DemoSnapshot/` directory — confirmed absent. Glob `App/Sources/**/DemoSnapshot` returned no match. (Will be created by task 03.4 as a synchronized folder; this task does not touch it.)
- No `App/Sources` files yet construct `StudentState` — confirmed by reading existing files. Source: read `App/Sources/MathmathApp.swift` and `App/Sources/ContentView.swift` show only `Core` import and SwiftUI code, no state construction.
- No prior App-sources test file scanning for I14 violations — confirmed absent. Glob `App/Sources/**/AppSourcesI14ScanTests.swift` and variants returned no match. This task creates the first.
- `MapLaunch.swift` and `MapFacade` type definitions — confirmed absent from Core. These are 03.7's outputs; the scan names them as the allow-list but they do not yet exist in the repo.

## §F. File scope

Files this task may create or touch. Mark each create / modify and cite existence for modifies.

- CREATE `Packages/Core/Tests/CoreTests/AppSourcesI14ScanTests.swift` — confirmed absent (Glob `**/AppSourcesI14ScanTests.swift` returned no match). Test suite scanning `App/Sources` recursively for I14/I5/I1/I10/D24 violations with planted negative controls per class.

## §G. Stack constraints relevant here

### Swift Testing and test framework
From `docs/tech-stack.md` §1: **Swift tests** — "**Swift Testing** (`import Testing`) for `Core`; XCTest only where UI testing needs it" and "`Testing.framework` present in the iOS platform of Xcode 26.6".

Source: `docs/tech-stack.md:22`

This task uses Swift Testing (`@Suite`, `@Test`, `#expect`) matching all other Core tests (confirmed by reading `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift` and `Packages/Core/Tests/CoreTests/CoreTests.swift`).

### File path resolution via `#filePath`
From `docs/tech-stack.md` §3 Gates: "`scripts/pick-simulator.sh` chooses the newest available iPhone simulator (override with `MATHMATH_SIM="platform=iOS Simulator,name=…,OS=…"`)" and the Core test pattern uses `#filePath` to resolve repository root.

Source: `docs/tech-stack.md:79`

Precedent: `Packages/Core/Tests/CoreTests/CoreTests.swift:22–26` uses `URL(fileURLWithPath: #filePath).deletingLastPathComponent()` (thrice) to walk from `CoreTests.swift` up to the package root, then append `Sources/Core` to locate source files. This task follows the same pattern.

### Recursive file enumeration pattern
From `Packages/Core/Tests/CoreTests/CoreTests.swift:27–34`, the pattern for recursive scanning:

```swift
let enumerator = FileManager.default.enumerator(
    at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey]
)
var files: [URL] = []
while let url = enumerator?.nextObject() as? URL {
    if url.pathExtension == "swift" {
        files.append(url)
    }
}
#expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
```

Source: `Packages/Core/Tests/CoreTests/CoreTests.swift:27–36`

This task reuses this logic to scan `App/Sources` instead of `Sources/Core`.

### Precedent test structure: negative controls
From `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:14–84`, a full negative-control pattern:

```swift
@Suite("Import boundary: negative control (C2, I14)")
struct ImportBoundaryNegativeControlTests {
    /// Mirrors `coreImportBoundary()`'s recursive-walk-plus-forbidden-import-scan logic, 
    /// parameterised over a directory so it can run against a synthetic fixture as well as the real `Sources/Core`.
    private static func forbiddenImportViolations(in root: URL) throws -> [String]
    
    @Test("recursive scan catches a forbidden import planted inside a Model/ subdirectory")
    func recursiveScanCatchesPlantedViolation() throws { … }
    
    @Test("recursive scan reports no violations on a clean fixture tree")
    func recursiveScanIsCleanOnACleanTree() throws { … }
}
```

Source: `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:14, 47–64, 68–83`

This precedent:
1. Defines a private helper (`forbiddenImportViolations`) parameterised over a root directory.
2. Plants violations in a temp fixture matching the real directory shape.
3. Asserts the planted violation is caught.
4. Asserts a clean tree passes.

This task follows this pattern for each violation class (StudentState construction, Core direct calls, data/ reads, URLSession/URLRequest, FoundationModels/engines, free-text/OCR).

### Arbitration ruling on the boundary
From `tasks/arbitration/arbiter-03-predispatch.md` § Q-F, "The boundary, precisely", item 4:

> **The façade.** Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a `CoreError`. — The persist-after-every-state-changing-action sequencing lives here too: a `Core` session type whose actions write to the injected URL. … The list of student messages to display (Q-A, Q-C, Q-E) is computed here, as registry codes.

Source: `tasks/arbitration/arbiter-03-predispatch.md:418-422`

The App's only entry points into Core state are through `MapLaunch.open` and `MapFacade` methods; any direct construction or call fails this boundary.

### Allow-list from 03.7 public surface
The public types and entry points the App **may** call (all in `Packages/Core/Sources/Core/Platform/MapLaunch.swift`, created by task 03.7):

- `MapLaunch.open(snapshotDir:stateURL:today:)` — the launch entry point.
- `LaunchOutcome` enum — the result type.
- `MapState` struct — the App's one handle onto the map.
- `MapFacade` enum with methods:
  - `nodePanelContent(nodeId:mapState:)`
  - `regionPanelContent(regionId:mapState:)`
  - `landmarkPanelContent(landmarkId:mapState:)`
  - `selectCourse(courseCode:bundle:stateURL:previousState:today:)`
  - `setMarker(unitId:pastLastUnit:mapState:today:)`
  - `include(nodeId:mapState:)`
  - `unitExpedition(unitId:mapState:today:)`
  - `checkHere(nodeId:mapState:)`

Source: `tasks/epic-03-task-07-map-actions-facade-launch.md` §4.1–§4.5 (re-read and byte-verified in this compilation)

### Exclusion list: types that must NOT be directly instantiated or called from App/Sources
These Core types are internal to the map domain and called only through the façade:

- `StudentState` — never constructed with `StudentState(…)` (read/write only through `StudentStateStore`).
- `MarkerTrail` — never called directly; all marker changes go through `MapFacade.setMarker`.
- `MasteryTransitions` — internal expeditionary state; not for the App.
- `Expedition` — never called directly; fringe composition goes through `MapFacade.unitExpedition` and `MapFacade.include`.
- `ExpeditionRun` — internal run machine; not exposed.
- `DiagnosisRun` — called only through `MapFacade.checkHere`, which calls `DiagnosisRun.open` for pure construction only (never `.start`, `.decideProbe`, `.answerProbeItem`, `.decideFurtherLevel`, `.run` — arbiter-02-11 Ruling 1, 3).
- `L0Checker` — validation-only; not for the App.
- `BundleIO` — internal I/O; called by `BundleLoader` which the façade uses.
- `LayoutEngine` — coordinate computation; not for the App (map coordinates are pre-generated).
- `MapViewModel.derive` — never called by the App; only `Core` derives it, and the App reads the result through `MapState.viewModel`.

Source: `tasks/epic-03-task-07-map-actions-facade-launch.md:48, 71–75` (I14 and boundary rules)

### Violation categories the scan must detect

1. **StudentState construction** — `StudentState(…)` in App source files.
2. **Direct Core transition calls** — `MarkerTrail.*`, `Expedition.*`, `MasteryTransitions.*`, `ExpeditionRun.*`, `L0Checker.*`, `BundleIO.*`, `LayoutEngine.*`, `MapViewModel.derive` outside the façade.
3. **Data reads** — `data/` relative paths in `App/Sources` (e.g., `Bundle.main.url(forResource:)` with path `data/demo/courses.json`).
4. **URLSession / URLRequest** — network access patterns; platform domain owns W2 bundle fetch, not the map/render layer.
5. **FoundationModels or third-party engines** — `FoundationModels`, game engines other than SpriteKit (if permitted by performance demand in D24).
6. **Free-text answer / OCR / item-check paths** — Vision framework, OCR, or any model output determining step correctness (I1 / I10).

Each category requires one negative-control test that plants a violation and asserts it is caught; an empty scan (no App source files, or all clean) is a FAIL.

### Empty-scan failure rule
From `Packages/Core/Tests/CoreTests/CoreTests.swift:36` (the coreImportBoundary test):

```swift
#expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
```

Source: `Packages/Core/Tests/CoreTests/CoreTests.swift:36`

And confirmed in the negative-control precedent (`ImportBoundaryNegativeControlTests.swift:31`):

```swift
#expect(!files.isEmpty, "no source files found — empty scan is a FAIL (C3)")
```

Source: `Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:31`

This task applies the same rule: if the scanner finds zero Swift files in `App/Sources`, the test fails.


# Epic 01 · Task 04: `core-cli` subcommands + pipeline seam (validate, layout, version)

---
epic: 01
task: 04
slug: core-cli-and-pipeline-seam
kind: feat
risk: seam
depends_on: [01.2, 01.3]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: `Packages/Core/Sources/CoreCLI` gains `validate` and `layout` subcommands alongside the existing
`version` subcommand — the single entry point through which the pipeline invokes `Core`'s L0 checker
(task 01.2) and layout engine (task 01.3), per D42. `core-cli validate <bundle-dir>` prints the L0 report as
JSON on stdout and exits according to the mapping in §4. `core-cli layout <bundle-dir>` rewrites `nodes.json`
in place with a computed `position` for every node. The pipeline gains a real (non-mocked) subprocess wrapper
per subcommand (`pipeline/src/mathmath_pipeline/cli.py`), a SHA-256/manifest-stamping helper plus the I8
build-refusal gate (`pipeline/src/mathmath_pipeline/bundle.py`), and the C1 real-composition seam test
exercising both sides for real.

Invariants in play:

- **I1** — not directly exercised (no answer-checking in this task); N/A beyond "no code path here decides
  correctness by model" — there is no model call anywhere in this task.
- **I2** — N/A, no model call in this task (`contracts/ai-usage.md`; EPIC 01 has no model path anywhere).
- **I8** — `core-cli validate` is the acceptance path: it runs every L0 rule (L0-1 … L0-10, task 01.2's
  `L0Checker.validate`) and reports `passed: false` on any violation. The pipeline's `build_bundle` wrapper
  (`pipeline/src/mathmath_pipeline/bundle.py`) **refuses to emit** — raises `BundleRejected` and performs no
  write — when the report's `passed` is `false`. This is asserted on the refusal itself (the raise, and that
  no file was written), never on a log line.
- **I14** — `Core` gains no import beyond Foundation in this task (no `Sources/Core/**` file is touched;
  `CoreCLI` is a separate target that already depends on `Core`, per `Packages/Core/Package.swift`'s existing
  `.executableTarget(name: "CoreCLI", dependencies: ["Core"])`). `CoreCLI` reuses `Core`'s `L0Checker`,
  `LayoutEngine` and `CoreCoding` rather than reimplementing any part of L0 or layout — the single-source
  rule (D42) extends to the CLI layer: `Core` computes, `CoreCLI` only calls and prints/writes. The pipeline
  likewise never reimplements L0 or layout (`contracts/graph-constraints.md` Preamble, quoted in §3) — its
  wrappers call the real `core-cli` binary, nothing else.

Acceptance criteria:

- AC1: `core-cli validate <bundle-dir>` prints JSON on stdout in the exact shape `{ bundle_id, passed: bool,
  checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }` (`contracts/graph-constraints.md`
  § Report shape), with **every** non-advisory L0 rule id present in `checks[]` (`L0-1, L0-2, L0-3a, L0-3b,
  L0-5, L0-6, L0-7, L0-8, L0-9, L0-10` — ten entries; `L0-4` is advisory and appears only inside `indegree`,
  never in `checks[]`, per `Packages/Core/Sources/Core/Validation/L0Report.swift:5` "`L0-4` (advisory) never
  appears in `checks[]`; it is represented only by `indegree`"), and every `violations[]` array present even
  when empty (C3). Instrument: `pipeline/tests/test_core_seam.py::test_validate_reports_every_rule_id`
  running `validate(...)` over `contracts/examples/` and asserting the `checks[].id` set equals the
  ten-id set transcribed from the contract's own rule table (`contracts/graph-constraints.md` L0-1…L0-10
  rows), not from `Core`'s source.
- AC2: `core-cli validate <bundle-dir>` exits `0` when the report's `passed` is `true`, exits `1` when
  `passed` is `false` (the report is still printed to stdout in both cases), and exits `3` with the raw
  `CoreError` registry code on one line of stderr and **no stdout** when a `CoreError` is thrown before any
  report can be constructed (bundle-directory read failure or a `format_version` major mismatch — both are
  `CoreError.platformBundleIntegrityFailed` from `L0Checker.validate(bundleDir:)`, which itself delegates to
  `BundleIO.read`). Instrument: `pipeline/tests/test_core_seam.py::test_validate_exit_code_matches_passed`
  and `::test_validate_missing_bundle_exits_three`.
- AC3: `core-cli layout <bundle-dir>` rewrites `nodes.json` in place with a `position` for every node, each
  position inside its node's region polygon; it does **not** rewrite `manifest.json` or any other bundle
  file. Running `core-cli layout` twice over the same starting bundle yields byte-identical `nodes.json` on
  both runs (`LayoutEngine.layout` is a pure, seeded-RNG function per task 01.3 — same input, same output).
  Instrument: `pipeline/tests/test_core_seam.py::test_layout_rewrites_nodes_file_idempotently`.
- AC4: the pipeline's `restamp_manifest(bundle_dir, "nodes.json")` (`pipeline/src/mathmath_pipeline/bundle.py`)
  re-stamps `manifest.json`'s `nodes.json` entry (`sha256`, `asset_version`) after a `core-cli layout` run,
  and running the **pair** (`core_cli.layout` then `restamp_manifest`) twice over the same starting bundle
  yields byte-identical `nodes.json` **and** byte-identical `manifest.json` on both runs — no version churn
  on an idempotent re-run (`contracts/data-model.md` § Versioning: "Bundle files are **immutable**: a change
  is a new `asset_version`" — quoted in full in §3; an unchanged file therefore keeps its `asset_version`, see
  §6 default). Instrument:
  `pipeline/tests/test_core_seam.py::test_layout_and_restamp_pair_is_idempotent`.
- AC5: `pipeline/src/mathmath_pipeline/cli.py`'s `validate(bundle_dir)` and `layout(bundle_dir)` invoke a
  **real** `core-cli` subprocess against a **real** bundle directory — no subprocess mock, no stubbed report.
  A test that deletes or renames the `core-cli` binary artefact (or points `CORE_PACKAGE` at a directory with
  no buildable package) must fail loudly, never silently skip. Instrument:
  `pipeline/tests/test_core_seam.py::test_seam_invokes_real_binary_not_a_mock` (asserts the seam test suite
  contains no `unittest.mock` / `monkeypatch.setattr(subprocess, ...)` usage anywhere in
  `pipeline/tests/test_core_seam.py` — a `grep`-equivalent assertion over the test file's own source text, so
  a later edit that sneaks a mock in fails this test).
- AC6: `pipeline/src/mathmath_pipeline/bundle.py`'s `build_bundle(bundle_dir)` raises `BundleRejected` and
  performs no filesystem write when `validate(bundle_dir)`'s report has `passed: false`; the
  acceptance assertion is on the raise and on the absence of any write (a `tmp_path` snapshot of the
  directory's file set and mtimes, taken before and after the call, must be identical), never on captured
  log output. Instrument: `pipeline/tests/test_core_seam.py::test_build_bundle_refuses_on_failing_report`.
- AC7: `core-cli` with no subcommand or an unknown subcommand still exits `2` with usage text on stderr
  (existing behaviour, preserved) and the existing `version` seam test
  (`pipeline/tests/test_core_seam.py::test_core_cli_version_is_semver`) stays green, unmodified in assertion
  content.
- AC8: `scripts/gate.sh` is green with the new/modified files included (all four gates).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/CoreCLI/main.swift` — MODIFY: add `"validate"` and `"layout"` cases that delegate to
  `ValidateCommand`/`LayoutCommand`; preserve the existing `"version"` case and the existing default-case exit
  code (`2`, usage).
- `Packages/Core/Sources/CoreCLI/ValidateCommand.swift` — CREATE: the `validate` subcommand.
- `Packages/Core/Sources/CoreCLI/LayoutCommand.swift` — CREATE: the `layout` subcommand.
- `Packages/Core/Sources/CoreCLI/Usage.swift` — CREATE: shared usage text and the two exit helpers
  (`printAndExit()` for exit 2, `fail(_:)` for exit 3) used by both new subcommand files.
- `pipeline/src/mathmath_pipeline/cli.py` — CREATE: `validate(bundle_dir)`, `layout(bundle_dir)`, the
  `L0Report`/`L0Check`/`L0Indegree` Pydantic models, `CoreCliError`.
- `pipeline/src/mathmath_pipeline/bundle.py` — CREATE: `sha256_of(path)`, `restamp_manifest(bundle_dir,
  file_name)`, `BundleRejected`, `build_bundle(bundle_dir)`.
- `pipeline/src/mathmath_pipeline/__init__.py` — MODIFY only if needed to keep `REPO_ROOT`/`CORE_PACKAGE`
  importable by the two new modules; the existing generic `core_cli(*args: str) -> str` function, `main()`
  and the `REPO_ROOT`/`CORE_PACKAGE` constants are otherwise unchanged (no rename, no removal — the new
  submodule is named `cli.py`, not `core_cli.py`, so it never shadows this function; see §6 default).
- `pipeline/tests/test_core_seam.py` — MODIFY: add the new tests listed in §1's acceptance criteria and §5;
  keep the existing `test_core_cli_version_is_semver` test and its assertion content unchanged; add the
  imports shown in §4.8 (no special ordering is required — the `cli` submodule name does not collide with
  `__init__.py`'s `core_cli` function, see §6 default).

Out-of-scope (do not touch even if tempted):

- `Packages/Core/Sources/Core/**` (including `CoreCoding.swift`, `BundleIO.swift`, `Validation/**`,
  `Layout/**`, `Model/**`) — tasks 01.1/01.2/01.3 own these; this task only calls their already-public API.
- `Packages/Core/Tests/CoreTests/**` — no `Core`-level test is added or modified by this task; the seam is
  exercised only from the pipeline side per C1 (`docs/plans/epic-01-task-plan.md` planner note 9: "pipeline ↔
  `core-cli` (D42) is owned by 01.4, both sides real").
- `data/demo/**` — task 01.5; does not exist yet (confirmed absent — Glob `data/**` returns empty). This
  task's tests use `contracts/examples/` (a complete bundle directory: `manifest.json` + the six content
  files) and `tmp_path`-copied working directories, never a committed mutation of `contracts/examples/`.
- `Packages/Rendering/**`, `App/Sources/**`, `contracts/**` — untouched, read-only or another task's scope.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/graph-constraints.md` — Preamble:
  > The structural rules every accepted bundle passes. Implemented **once**, in `Core` (`validate`), exposed by
  > `core-cli validate <bundle-dir>` and run (a) by the pipeline build step — failing data is **not emitted**
  > (D33) — and (b) at app load — a failing bundle is refused and the previous set stays (platform W1). Python
  > never reimplements these (D42). Each rule has an id so reports, tests and specs cite the same thing.

- `contracts/graph-constraints.md` — the L0 rule table (verbatim, all ten rows plus L0-T, which is out of
  scope here per the epic brief §3: "L0-T (trail segments) is EPIC 02's"):

  | Id | Rule | Fails with | Note |
  |---|---|---|---|
  | L0-1 | The edge set is acyclic. | `GRAPH_L0_FAILED{L0-1, cycle[]}` | — |
  | L0-2 | No edge goes from a later course to an earlier one: for every edge, `min depth(from) ≤ max depth(to)` over `courses[]`; nodes without `courses[]` (undergraduate) are treated as deeper than every course. | `GRAPH_L0_FAILED{L0-2, edge}` | depth = the course's position in the Ministry succession, from `courses.json` |
  | L0-3a | Every Ministry expectation in the spine maps to ≥ 1 node, and every node carrying `expectation_codes` maps to ≥ 1 existing code. | `GRAPH_L0_FAILED{L0-3a, codes[]}` | applies only to code-bearing nodes (v2.7 §1) |
  | L0-3b | Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` / `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only |
  | L0-4 | In-degree outliers are **flagged, not failed**: nodes whose in-degree exceeds the threshold (default: 95th percentile of the bundle [ESTIMATE: set empirically at M2, concept-graph Q1]) are listed in the report. | report only | advisory |
  | L0-5 | The D14 starting chain is connected end-to-end: a directed path exists through the chain's nodes in order. | `GRAPH_L0_FAILED{L0-5, break}` | chain node ids are data in the bundle (`manifest.starting_chain[]`) |
  | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. | `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |
  | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by `core-cli layout`; checked after it |
  | L0-8 | Every unit of every course references only expectations of that course, every expectation is in exactly one unit, no unit is empty. | `SPINE_UNIT_EMPTY` / `GRAPH_L0_FAILED{L0-8}` | D45 |
  | L0-9 | Every course's `next_courses[]` names existing courses and contains no cycle. | `GRAPH_L0_FAILED{L0-9}` | D47 succession is data |
  | L0-10 | Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). | `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15) |

- `contracts/graph-constraints.md` — Report shape:
  > **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
  > violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
  > passed. Empty violation lists are printed, never omitted (C3).

- `contracts/data-model.md` — heading `### Versioning`:
  > - Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
  >   `Core` needs a migration; the app refuses a bundle whose major differs from its own.
  > - `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never
  >   activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
  > - `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

- `contracts/data-model.md` — heading `## Enforcement`:
  > - `pipeline/tests/test_contracts.py`: every schema is valid Draft 2020-12; every example in
  >   `contracts/examples/` validates; every `*.json` under `data/**` validates against the schema its filename
  >   names (empty `data/` = PASS, stated in the test output); `student-state` and `telemetry-batch` schemas
  >   reject any object containing a key from the identifier blocklist.
  > - Demo EPIC: `CoreTests` decode every example file into the `Core` types and re-encode byte-equal (modulo
  >   key order); `core-cli validate` runs L0 (`graph-constraints.md`).

- `contracts/error-codes.md` — heading `## Rules`:
  > - Prefixes are fixed per domain: `MAP`, `EXP`, `DIAG`, `GRAPH`, `LO`, `SPINE`, `GEN`, `PLATFORM`, `TELEM`,
  >   `TIER`, `VERIFY` (M5). A code appears in exactly one domain doc and in the registry.
  > - Every code declares `recoverable` (bool), `surface ∈ {internal, student, owner}` and `user_text` — the
  >   student-facing sentence when `surface = student`, else `null`. Student text names a node or a situation,
  >   never the student, and never contains a score (content-policy voice).
  > - `Core` defines `enum CoreError: String` mirroring the `GRAPH`, `EXP`, `MAP` (validation) and `DIAG`
  >   codes; the App and the pipeline each map their own. A code raised in code but absent from the registry
  >   fails the round-trip test.
  > - Internal codes never reach a student surface; a `student` code always has a next action in its text.
  > - `GRAPH_L0_FAILED` carries the failing rule ids from `graph-constraints.md` in `details`.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` — Amendment 01.05.1 (2026-09-09), the settled
  location of the L0 report:
  > `core-cli` (`validate`, `layout`, `version`) — exercised by `pipeline/tests` over `data/demo` and
  > `contracts/examples`; `data/demo/*.json` — the bundle files only, each named by its schema (`manifest`,
  > `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), exercised by `test_contracts.py`
  > (schemas) and `core-cli validate`. The **L0 report is not a bundle file and is not committed**: it is
  > `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md` § Report
  > shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing other
  > than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` § Enforcement:
  > every `*.json` under `data/**` validates against the schema its filename names).

- `docs/plans/epic-01-task-plan.md` — planner note 2:
  > `core-cli validate` cannot verify SHA-256 without importing CryptoKit into `Core` (breaks D33/I14) or
  > hand-rolling it (breaks RULE 2). Default adopted: `core-cli validate` enforces manifest *completeness and
  > file presence* (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, exactly what the brief's R-6 line requires); hash
  > *computation* is a Python `hashlib` helper in the pipeline; hash *verification at load* defers to EPIC 03's
  > App-side loader.

- `docs/plans/epic-01-task-plan.md` — planner note 9:
  > **Real-composition seams (C1).** pipeline ↔ `core-cli` (D42) is owned by 01.4, both sides real. The
  > `Core` ↔ render-layer seam is not crossed here and is asserted negatively by the recursive import test in
  > 01.1. The bundle-loader ↔ `Core` validation seam is EPIC 03's and must not be pulled forward.

Prior signatures (verbatim, read from the landed sources in this run — `Core` types and functions this task
calls and must not reimplement):

```swift
// Packages/Core/Sources/Core/Validation/L0Checker.swift
public enum L0Checker {
    public static func validate(bundleDir: URL) throws -> L0Report
    public static func validate(bundle: ContentBundle) -> L0Report
    public static func errorCode(forRuleId ruleId: String) -> CoreError?
}
```

```swift
// Packages/Core/Sources/Core/Validation/L0Report.swift
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

```swift
// Packages/Core/Sources/Core/Layout/LayoutEngine.swift
public enum LayoutEngine {
    public static func layout(
        nodes: [Node],
        regions: [Region],
        config: LayoutConfig = LayoutConfig(),
        rng: inout SeededGenerator
    ) throws -> [String: Point]
}
```

```swift
// Packages/Core/Sources/Core/Layout/LayoutConfig.swift
public struct LayoutConfig: Sendable, Equatable {
    public static let defaultSeed: UInt64 = 42
    public init() {}
    // ... tuning fields, all defaulted; this task never overrides them, so `LayoutConfig()` is used as-is.
}
```

```swift
// Packages/Core/Sources/Core/Layout/SeededGenerator.swift
public struct SeededGenerator: RandomNumberGenerator {
    public init(seed: UInt64)
}
```

```swift
// Packages/Core/Sources/Core/CoreError.swift
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

```swift
// Packages/Core/Sources/Core/BundleIO.swift
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
    public static func read(from directory: URL) throws -> ContentBundle
    public static func write(_ bundle: ContentBundle, to directory: URL) throws
}
```

```swift
// Packages/Core/Sources/Core/Model/Nodes.swift (relevant fields only; full file read in this run)
public struct NodesFile: Codable, Equatable {
    public let formatVersion: String
    public let nodes: [Node]
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
```

Prior signature (verbatim, from `tasks/epic-01-task-01-core-bundle-types.md` §4.1.1 — the arbitrated,
authoritative shape of `CoreCoding`; `Packages/Core/Sources/Core/CoreCoding.swift` does not yet exist on disk
at compile time of this spec but is task 01.1's committed output and this task's direct dependency chain
requires it to land first):

```swift
public enum CoreCoding {
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
```

Prior signature (verbatim, from `Packages/Core/Sources/CoreCLI/main.swift`, read in this run — the exact
current shape this task modifies):

```swift
import Core
import Foundation

// core-cli — the single entry point through which the Python pipeline invokes `Core` (D42):
// L0 validation and layout precompute. Subcommands are added by the EPICs that ship them.
// Phase 5 placeholder: reports the data-format version so the pipeline↔Core seam is exercisable.

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "version":
    print(CoreInfo.dataFormatVersion)
default:
    FileHandle.standardError.write(Data("usage: core-cli version\n".utf8))
    exit(2)
}
```

Prior signature (verbatim, from `pipeline/src/mathmath_pipeline/__init__.py`, read in this run):

```python
REPO_ROOT = Path(__file__).resolve().parents[3]
CORE_PACKAGE = REPO_ROOT / "Packages" / "Core"


def core_cli(*args: str) -> str:
    """Invoke the ``core-cli`` executable from the Core Swift package and return its stdout (D42)."""
    completed = subprocess.run(
        ["swift", "run", "--package-path", str(CORE_PACKAGE), "-c", "release", "core-cli", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def main() -> None:
    print(f"mathmath-pipeline; core data format {core_cli('version')}")  # noqa: T201
```

Prior signature (verbatim, from `pipeline/tests/test_core_seam.py`, read in this run — the existing test AC7
must keep green, unmodified):

```python
from mathmath_pipeline import core_cli


def test_core_cli_version_is_semver() -> None:
    version = core_cli("version")
    assert re.fullmatch(r"\d+\.\d+\.\d+", version), version
```

Gate commands (verbatim, from `scripts/gate.sh`, read in this run):

```sh
echo "== 1/4 format + lint =="
xcrun swift-format lint --strict --recursive --configuration "$ROOT/.swift-format" "$ROOT/Packages" "$ROOT/App/Sources"
( cd "$ROOT/pipeline" && uv run ruff check . && uv run ruff format --check . )

echo "== 2/4 typecheck =="
( cd "$ROOT/pipeline" && uv run pyright )

echo "== 3/4 Core: build + test on the iOS simulator (D29) =="
( cd "$ROOT/Packages/Core" && swift build -c release --product core-cli )
( cd "$ROOT/Packages/Core" && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )
( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )

echo "== 4/4 App build on the simulator + pipeline tests =="
xcodebuild build -quiet -workspace "$ROOT/App/mathmath.xcworkspace" -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO
( cd "$ROOT/pipeline" && uv run pytest -q )
```

Pyright strict configuration (verbatim, from `pipeline/pyproject.toml`, read in this run):

```
[tool.pyright]
pythonVersion = "3.14"
typeCheckingMode = "strict"
include = ["src", "tests"]
```

Test framework: Swift Testing (`import Testing`) for `Core`/`CoreCLI` (no new Swift test target is added by
this task, per the file scope in §2 — the seam is exercised only from the Python side, C1); **pytest** (≥ 8)
for the pipeline, per `docs/tech-stack.md` §1 row "Python tests" and `pipeline/pyproject.toml`'s
`[tool.pytest.ini_options]`.

## §4 Implementation outline

Layer placement: `core-cli` is layer ④ tooling over layers ①–② data (it exposes `Core`'s L0 checker and
layout engine, it computes nothing itself); the pipeline wrappers are the offline build-time caller of that
tooling (D41/D42).

### 4.1 `Packages/Core/Sources/CoreCLI/Usage.swift` (CREATE)

```swift
import Foundation

/// Shared usage text and the two exit paths every subcommand uses.
enum Usage {
    static let text = "usage: core-cli version | validate <bundle-dir> | layout <bundle-dir>\n"

    /// Preserves the existing convention (`main.swift`, read in this run): usage text to stderr, exit 2.
    static func printAndExit() -> Never {
        FileHandle.standardError.write(Data(text.utf8))
        exit(2)
    }

    /// A `CoreError` was thrown before any report/rewrite could complete (bundle unreadable, a
    /// `format_version` major mismatch, or — `layout` only — a region/layout precondition failure).
    /// Prints the raw registry code (`CoreError.rawValue`) as one line on stderr; exits 3.
    static func fail(_ error: CoreError) -> Never {
        FileHandle.standardError.write(Data((error.rawValue + "\n").utf8))
        exit(3)
    }
}
```

### 4.2 `Packages/Core/Sources/CoreCLI/ValidateCommand.swift` (CREATE)

```swift
import Core
import Foundation

/// `core-cli validate <bundle-dir>`. Prints the L0 report as JSON on stdout
/// (`contracts/graph-constraints.md` § Report shape) and exits per the table in §4.4 of the task spec.
enum ValidateCommand {
    static func run(arguments: [String]) {
        guard arguments.count == 1 else { Usage.printAndExit() }
        let bundleDir = URL(fileURLWithPath: arguments[0], isDirectory: true)

        let report: L0Report
        do {
            report = try L0Checker.validate(bundleDir: bundleDir)
        } catch let error as CoreError {
            Usage.fail(error)
        }

        let data: Data
        do {
            data = try CoreCoding.encoder.encode(report)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(3)
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(report.passed ? 0 : 1)
    }
}
```

`CoreCoding.encoder` is the only encoder this file constructs — it never builds its own `JSONEncoder` (matches
the "one wire coder for the whole bundle format" rule the dispatch names; `L0Report` is part of that same
wire vocabulary, `bundleId`→`bundle_id` etc., so `CoreCoding`'s `.convertToSnakeCase`/`.sortedKeys`
configuration produces exactly the contract's `{ bundle_id, passed, checks, indegree }` shape).

### 4.3 `Packages/Core/Sources/CoreCLI/LayoutCommand.swift` (CREATE)

```swift
import Core
import Foundation

/// `core-cli layout <bundle-dir>`. Rewrites `nodes.json` in place with a computed `position` for every
/// node; touches no other bundle file. Prints nothing to stdout on success.
enum LayoutCommand {
    static func run(arguments: [String]) {
        guard arguments.count == 1 else { Usage.printAndExit() }
        let bundleDir = URL(fileURLWithPath: arguments[0], isDirectory: true)

        do {
            let bundle = try BundleIO.read(from: bundleDir)
            var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
            let positions = try LayoutEngine.layout(
                nodes: bundle.nodes.nodes, regions: bundle.regions.regions, rng: &rng
            )
            let updatedNodes = bundle.nodes.nodes.map { node -> Node in
                guard let position = positions[node.id] else { return node }
                return Node(
                    id: node.id, name: node.name, regionId: node.regionId, strand: node.strand,
                    expectationCodes: node.expectationCodes, sourceRef: node.sourceRef,
                    courses: node.courses, position: position, layoutHint: node.layoutHint,
                    paraphrase: node.paraphrase, explanation: node.explanation,
                    workedExamples: node.workedExamples, errorTypes: node.errorTypes,
                    hintTree: node.hintTree, probeItems: node.probeItems
                )
            }
            let updatedFile = NodesFile(formatVersion: bundle.nodes.formatVersion, nodes: updatedNodes)
            let data = try CoreCoding.encoder.encode(updatedFile)
            try data.write(to: bundleDir.appendingPathComponent("nodes.json"))
        } catch let error as CoreError {
            Usage.fail(error)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(3)
        }
        exit(0)
    }
}
```

`Node(...)` uses the compiler-synthesized memberwise initializer (no custom `init` exists on `Node` per
`Packages/Core/Sources/Core/Model/Nodes.swift`, read in this run) — every argument label above matches that
file's stored-property list and order exactly. `bundle.nodes.nodes.map` guarantees the same node order is
preserved between runs (array order is not touched), which is required for AC3's byte-identical re-run:
`LayoutEngine.layout` is deterministic given the same seed and the same input node/region order (task 01.3),
so the only remaining determinism requirement is that this file does not reorder, filter, or otherwise
introduce a non-deterministic pass over `bundle.nodes.nodes` — the direct `.map` above satisfies that.

### 4.4 `Packages/Core/Sources/CoreCLI/main.swift` (MODIFY)

```swift
import Core
import Foundation

// core-cli — the single entry point through which the Python pipeline invokes `Core` (D42):
// L0 validation and layout precompute.

let arguments = CommandLine.arguments.dropFirst()
switch arguments.first {
case "version":
    print(CoreInfo.dataFormatVersion)
case "validate":
    ValidateCommand.run(arguments: Array(arguments.dropFirst()))
case "layout":
    LayoutCommand.run(arguments: Array(arguments.dropFirst()))
default:
    Usage.printAndExit()
}
```

Exit-code / error-code mapping this task fixes (no contract pins the numeric exit codes themselves — only
"exits non-zero when `passed: false`" is contractual, `contracts/graph-constraints.md` § Report shape,
"A bundle is accepted iff every non-advisory check passed"; the table below is this task's own, internally
consistent convention, documented here so `cli.py`'s exit-code branching in §4.5 has one source of
truth):

| Exit | `validate` meaning | `layout` meaning |
|---|---|---|
| 0 | `passed: true`; report on stdout | `nodes.json` rewritten |
| 1 | `passed: false`; report (with failing checks) still printed on stdout | not used — layout has no partial-success report |
| 2 | usage error (missing/extra argument, unknown subcommand); stderr text, no stdout | same |
| 3 | a `CoreError` was thrown before a report/rewrite exists — `platformBundleIntegrityFailed` (bundle unreadable or `format_version` major mismatch) for either subcommand, plus `mapRegionUnknown`/`mapLayoutMissing` for `layout` (`LayoutEngine`'s own preconditions, task 01.3); the raw registry code is printed on one line of stderr, no stdout | same |

### 4.5 `pipeline/src/mathmath_pipeline/cli.py` (CREATE)

```python
"""Real, per-subcommand wrappers around the core-cli binary (D42): validate, layout.

Every function here invokes a real `core-cli` subprocess against a real bundle directory — no
reimplementation of L0 or layout (`contracts/graph-constraints.md` Preamble: "Python never reimplements
these (D42)"), no subprocess mock (C1, task plan note 9).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from pydantic import BaseModel, ConfigDict

from mathmath_pipeline import CORE_PACKAGE


class L0Check(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    passed: bool
    violations: list[str]


class L0Indegree(BaseModel):
    model_config = ConfigDict(extra="forbid")
    threshold: int
    outliers: list[str]


class L0Report(BaseModel):
    """Boundary-validated shape of `core-cli validate` stdout (`contracts/graph-constraints.md` § Report
    shape). Pydantic is the boundary-validation tool `docs/tech-stack.md` names for the pipeline."""

    model_config = ConfigDict(extra="forbid")
    bundle_id: str
    passed: bool
    checks: list[L0Check]
    indegree: L0Indegree


class CoreCliError(RuntimeError):
    """Raised for any core-cli exit that is not a report-bearing exit (exit 2 usage, exit 3 CoreError)."""

    def __init__(self, subcommand: str, returncode: int, stderr: str) -> None:
        self.subcommand = subcommand
        self.returncode = returncode
        self.stderr = stderr
        super().__init__(f"core-cli {subcommand} exited {returncode}: {stderr.strip()}")


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["swift", "run", "--package-path", str(CORE_PACKAGE), "-c", "release", "core-cli", *args],
        capture_output=True,
        text=True,
        check=False,
    )


def validate(bundle_dir: Path) -> L0Report:
    """Run `core-cli validate <bundle_dir>` and parse its stdout into a boundary-validated `L0Report`.

    Exit 0 or 1 both carry a report (0 = passed, 1 = passed: false — §4.4's table); any other exit code
    means no report was printed, so it raises `CoreCliError` instead of attempting to parse stdout.
    """
    completed = _run("validate", str(bundle_dir))
    if completed.returncode not in (0, 1):
        raise CoreCliError("validate", completed.returncode, completed.stderr)
    return L0Report.model_validate_json(completed.stdout)


def layout(bundle_dir: Path) -> None:
    """Run `core-cli layout <bundle_dir>`, which rewrites `nodes.json` in place. Raises `CoreCliError` on
    any non-zero exit — layout has no partial-success report (§4.4's table)."""
    completed = _run("layout", str(bundle_dir))
    if completed.returncode != 0:
        raise CoreCliError("layout", completed.returncode, completed.stderr)
```

### 4.6 `pipeline/src/mathmath_pipeline/bundle.py` (CREATE)

```python
"""Bundle-directory build-time helpers (D42): SHA-256 stamping and the I8 build-refusal gate.

`Core` never computes or verifies SHA-256 (Foundation only, D33/I14; `core-cli validate` enforces manifest
*completeness and file presence* only — planner note 2, §3). SHA-256 *computation* is this module's
`hashlib` helper.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from mathmath_pipeline.cli import L0Report, validate

ASSET_VERSION_HEX_LENGTH = 12


def sha256_of(path: Path) -> str:
    """The SHA-256 hex digest of a file's bytes."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restamp_manifest(bundle_dir: Path, file_name: str) -> None:
    """Recompute `file_name`'s SHA-256 and rewrite its `manifest.json` entry (`sha256`, `asset_version`).

    `asset_version` is the first `ASSET_VERSION_HEX_LENGTH` hex characters of the new digest: content-
    derived, so byte-identical input yields a byte-identical `asset_version` with no comparison against the
    manifest's previous value required (`contracts/data-model.md` § Versioning: "Bundle files are
    **immutable**: a change is a new `asset_version`" — see §6 default for the reasoning this satisfies that
    rule without extra state).
    """
    manifest_path = bundle_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    digest = sha256_of(bundle_dir / file_name)
    asset_version = digest[:ASSET_VERSION_HEX_LENGTH]
    for entry in manifest["files"]:
        if entry["name"] == file_name:
            entry["sha256"] = digest
            entry["asset_version"] = asset_version
            break
    else:
        raise ValueError(f"{file_name!r} not listed in {manifest_path}'s files[]")
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


class BundleRejected(RuntimeError):
    """I8: raised by `build_bundle` when the L0 report says `passed: false`. No write happens."""

    def __init__(self, report: L0Report) -> None:
        self.report = report
        failing = [check.id for check in report.checks if not check.passed]
        super().__init__(f"bundle {report.bundle_id!r} failed L0 checks: {failing}")


def build_bundle(bundle_dir: Path) -> L0Report:
    """The I8 build gate: validate `bundle_dir`; raise `BundleRejected` and write nothing if the report's
    `passed` is `False`. Returns the report on success. The only side effect on any path is the
    `core-cli validate` subprocess call inside `validate()` — this function itself never writes."""
    report = validate(bundle_dir)
    if not report.passed:
        raise BundleRejected(report)
    return report
```

### 4.7 `pipeline/src/mathmath_pipeline/__init__.py` — no functional change

`REPO_ROOT` and `CORE_PACKAGE` stay public module-level constants (already read by `cli.py`'s `_run`);
the generic `core_cli(*args: str) -> str` function and `main()` are untouched. See §6 default for why this
file is listed in scope with no required edit.

### 4.8 `pipeline/tests/test_core_seam.py` (MODIFY)

Add imports for the new modules used by the tests in §5, alongside the existing import. The submodule is
named `mathmath_pipeline.cli` (not `core_cli`), so it never shadows `__init__.py`'s module-level `core_cli`
function — no import-order discipline is needed (see §6 default).

```python
"""Real-composition seam test (C1): the Python pipeline invokes the Swift core-cli binary (D42)."""

from __future__ import annotations

import json
import re
import shutil

import pytest

from mathmath_pipeline import bundle as bundle_helpers
from mathmath_pipeline import core_cli
from mathmath_pipeline.cli import CoreCliError, layout, validate


def test_core_cli_version_is_semver() -> None:
    version = core_cli("version")
    assert re.fullmatch(r"\d+\.\d+\.\d+", version), version
```

(The existing test body is unchanged — AC7. Everything after this import block is new: the tests in §5.)

### 4.9 Smoke check

`( cd pipeline && uv run pytest tests/test_core_seam.py -q )` — must be green, including the pre-existing
`test_core_cli_version_is_semver`.

## §5 Test plan

- T1 happy path — validate: `validate(Path("contracts/examples"))` over the real, committed
  `contracts/examples/` directory (a complete bundle: `manifest.json` + the six content files) returns an
  `L0Report` whose `checks` carry exactly the ten rule ids `{L0-1, L0-2, L0-3a, L0-3b, L0-5, L0-6, L0-7, L0-8,
  L0-9, L0-10}` (transcribed from the contract table in §3, not from `Core`'s source — AC1), and whose every
  `violations` list is present (possibly empty) rather than omitted.
- T1 happy path — layout: copy `contracts/examples/` into a `tmp_path` working directory (never mutate the
  committed `contracts/examples/` in place — it is read-only ground truth); run `layout(working_dir)`
  twice; assert `(working_dir / "nodes.json").read_bytes()` is byte-identical across the two runs, and that
  every node in the resulting file has a `position` object with numeric `x`/`y` (AC3).
- T2 negative — invalid input rejected at the boundary: `validate(Path("/does/not/exist"))` (or a
  `tmp_path` directory with no `manifest.json`) raises `CoreCliError` with `returncode == 3` (bundle-integrity
  failure — `platformBundleIntegrityFailed`, §4.4's table), never a Python exception from JSON-parsing
  malformed/empty stdout (AC2's exit-3 path).
- T2 negative — malformed core-cli stdout: construct a fake report dict missing a required key (e.g. no
  `indegree`) and assert `L0Report.model_validate_json(...)` raises Pydantic's `ValidationError` — the
  boundary model rejects a shape that does not match the contract (extends AC1's shape assertion to the
  Pydantic layer itself).
- T3 error-taxonomy: `validate` on a `tmp_path` copy of `contracts/examples/` whose `manifest.json`
  has had one `files[]` entry deleted (so a file it still lists nothing for is now "extra", or — the cleaner
  construction — delete the *file itself* while leaving its `manifest.json` entry, reproducing exactly
  `BundleIO.read`'s missing-file check) exits `3` with stderr equal to exactly
  `"PLATFORM_BUNDLE_INTEGRITY_FAILED\n"` (AC2).
- T4 conformance per requirements §B.1 — I8: `bundle_helpers.build_bundle(bundle_dir)` on a `tmp_path` copy
  of `contracts/examples/` whose `landmarks.json` has had its one landmark's first `node_ids[]` entry changed
  to a nonexistent id (e.g. `"nonexistent-node"`, which deterministically fails L0-10's referential-integrity
  half without touching any other check — `Packages/Core/Sources/Core/Validation/L0Checker.swift`'s
  `checkLandmarkIntegrity`, read in this run) raises `BundleRejected`; a `tmp_path` snapshot of every file's
  name and mtime, taken immediately before and immediately after the call, is identical — no write happened
  (AC6).
- T4 conformance — layout + manifest idempotency (AC4): on a fresh `tmp_path` copy of `contracts/examples/`,
  run `layout(working_dir)` then `bundle_helpers.restamp_manifest(working_dir, "nodes.json")`; record
  `nodes.json` and `manifest.json` bytes; run the same pair again over the same directory; assert both files'
  bytes are unchanged between the two runs (the second `core-cli layout` call recomputes the same positions
  from the same seed and input order — task 01.3's determinism — so `nodes.json` is byte-identical, and
  `restamp_manifest` therefore computes the same SHA-256 and the same `asset_version`, so `manifest.json` is
  byte-identical too — no version churn on an idempotent re-run).
- T5 negative control for every regression guard:
  - AC1's rule-id set guard: temporarily assert against a **deliberately wrong** set (e.g. missing `L0-9`)
    inside a scratch check while writing the test, to confirm the assertion actually fails on a wrong set
    before committing the correct one — not shipped, but the shipped test's set must be copy-pasted from the
    contract table in §3 of this spec, not typed from memory, so a future contract edit that adds/removes a
    rule id is caught.
  - AC5/T1's "no mock" guard: `test_seam_invokes_real_binary_not_a_mock` greps
    `pipeline/tests/test_core_seam.py`'s own source text for `unittest.mock`, `MagicMock`, `monkeypatch`, and
    `subprocess.run(` **outside** `mathmath_pipeline/cli.py`'s own `_run` helper; the negative control is
    that inserting any of those tokens into the test file must fail this test (verify this by hand while
    writing it, then remove the inserted token before committing — the shipped file must contain none of
    them).
  - AC6's refusal guard: the negative control is deliberately calling `build_bundle` on the **unmodified**
    `contracts/examples/` copy first (no corruption) and confirming it does *not* raise (sanity: the fixture
    construction itself, not `build_bundle`, is what should be capable of producing a passing report) —
    include this as a `pytest.mark.skip`-free companion assertion inside the same test function, not a
    separate always-skipped test.
- T6 idempotency / no-leak: T4's layout+restamp pair-idempotency case (above) is this task's idempotency
  case; T4's `build_bundle` refusal case is this task's no-leak case (no partial manifest, no partial
  `nodes.json`, no stray file left in `tmp_path` beyond what the fixture copy already contained).

## §6 Decision defaults

- IF the contract does not pin numeric CLI exit codes (it only requires "exits non-zero when `passed:
  false`", `contracts/graph-constraints.md` § Report shape) THEN use the table in §4.4: `0` success, `1`
  report-carrying failure (`validate` only), `2` usage (preserves the existing `main.swift` convention, read
  in this run), `3` a `CoreError` thrown before any report/rewrite exists. This is an internally consistent
  convention this task defines and both sides (`CoreCLI`, `cli.py`) share — it does not contradict any
  contract rule.
- IF the contract does not specify an `asset_version` generation algorithm (`contracts/data-model.md` §
  Versioning only requires "a change is a new `asset_version`"; it is silent on *how* a new one is derived)
  THEN derive it from the file's own content hash — the first 12 hex characters of its SHA-256 digest
  (`pipeline/src/mathmath_pipeline/bundle.py`'s `restamp_manifest`). This is conservative and self-
  justifying: it satisfies "immutable: a change is a new `asset_version`" by construction (different bytes
  → a different SHA-256 → a different truncated digest, with SHA-256's collision resistance making a same-
  digest-different-bytes case not a practical concern for a build-time id), and it makes idempotency
  (AC4) automatic — no comparison against the manifest's previous value is needed, because computing the same
  hash from the same bytes always yields the same truncated string. The `manifest.schema.json` `asset_version`
  pattern `^[a-z0-9]+(-[a-z0-9]+)*$` (`contracts/schemas/manifest.schema.json`, read via the context bundle,
  §B) accepts a plain lowercase-hex run with no hyphen needed, since hex digits are already `[a-z0-9]`.
- The submodule this task creates under `pipeline/src/mathmath_pipeline/` is named `cli.py`, not `core_cli.py`
  — `pipeline/src/mathmath_pipeline/__init__.py` already defines a module-level `core_cli(*args: str) -> str`
  function, and Python permanently rebinds a package's attribute to a same-named submodule the first time that
  submodule is imported by any mechanism, which would silently turn any later `from mathmath_pipeline import
  core_cli` into the module instead of the function in whichever process happened to import the submodule
  first (order-dependent and invisible at the call site). Naming the submodule `cli.py` means the two names
  never collide, so no import-order discipline is needed anywhere in this task or any later one.
- IF `LayoutCommand` needs a `LayoutConfig` THEN use `LayoutConfig()` (the zero-argument default) — this task
  never tunes layout parameters; task 01.3 owns every default value inside `LayoutConfig`.
- IF a bundle directory argument is a relative path THEN `core-cli` resolves it exactly as
  `URL(fileURLWithPath:)` already does (relative to the process's current working directory) — no additional
  path normalization is added; this matches `BundleIO.read`'s own use of `URL` path components and requires
  no new code.
- Standing defaults: identifiers and timestamps per `contracts/data-model.md` (ids are stable, opaque,
  lowercase kebab-case; `asset_version` per the default above); no model call anywhere in this task (no
  confidence threshold or Tier-0 fallback applies — I2 is N/A here); telemetry is untouched by this task;
  no identifying field is introduced by anything this task ships; `Core`'s `Node.paraphrase` is untouched —
  this task never edits node content, only `position`.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`; `uv run ruff check .` / `uv run ruff format --check .` in `pipeline/`)
- typecheck clean (`uv run pyright` strict over `pipeline/`; Swift's typecheck is the build)
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `xcodebuild test -scheme Core-Package` on the simulator (this task adds no new Swift test target, but the
  build of `CoreCLI`'s new files must succeed under this command)
- App build green (`xcodebuild build -scheme mathmath` on the simulator) — unaffected by this task but must
  stay green — and `uv run pytest -q` in `pipeline/` green, including every test in §5
- tests green for every case in §5
- conforms to every contract section cited in §3 and every invariant listed in §1

# Task 01.04 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: core-cli-and-pipeline-seam
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 01
- **Task:** 04
- **Slug:** core-cli-and-pipeline-seam
- **Summary:** Implement `core-cli validate|layout|version` subcommands and one thin Python wrapper per subcommand in the pipeline, plus the C1 real-composition seam test (pipeline ↔ `core-cli`, both sides real, a real subprocess against a real bundle directory, no mock). Depends on 01.2 (L0 checker in `Core`) and 01.3 (layout function in `Core`). The L0 report is `core-cli validate` stdout (JSON, shaped by `contracts/graph-constraints.md` § Report shape), not a committed file; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing but schema-named bundle files may be written under `data/**`.
- **Invariants in play:** I1, I2, I8, I14 (from `CLAUDE.md` §Hard invariants, verbatim quoted in §B below).

## §B. Applicable contract rules (verbatim)

### contracts/graph-constraints.md — Preamble (binding, D42/D33)

> The structural rules every accepted bundle passes. Implemented **once**, in `Core` (`validate`), exposed by
> `core-cli validate <bundle-dir>` and run (a) by the pipeline build step — failing data is **not emitted**
> (D33) — and (b) at app load — a failing bundle is refused and the previous set stays (platform W1). Python
> never reimplements these (D42). Each rule has an id so reports, tests and specs cite the same thing.

Source: `contracts/graph-constraints.md:5-8`
Binds this task: `core-cli validate` subcommand must implement every L0 rule (L0-1 through L0-10) and emit a report per the Report shape contract; the pipeline must parse the report and fail the build if `passed: false`.

### contracts/graph-constraints.md — L0 rules (all ten, required for `core-cli validate`)

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

Source: `contracts/graph-constraints.md:12-23`
Binds this task: `core-cli validate` must check all ten rules and include all check ids in the report, even if violation lists are empty (C3).

### contracts/graph-constraints.md — Report shape (required stdout format for `core-cli validate`)

> **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
> violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
> passed. Empty violation lists are printed, never omitted (C3).

Source: `contracts/graph-constraints.md:25-27`
Binds this task: `core-cli validate` stdout is JSON with this exact structure; empty violation lists are included in the output; the pipeline wrapper parses this report to decide whether to fail the build.

### contracts/data-model.md — Versioning (required for all bundle-file handling)

> ### Versioning
> - Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
>   `Core` needs a migration; the app refuses a bundle whose major differs from its own.
> - `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never
>   activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
> - `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

Source: `contracts/data-model.md:24-29`
Binds this task: `core-cli` commands must validate `format_version` and handle manifest integrity (SHA256 validation).

### contracts/data-model.md — Enforcement (pipeline seam test responsibility)

> ## Enforcement
> - `pipeline/tests/test_contracts.py`: every schema is valid Draft 2020-12; every example in
>   `contracts/examples/` validates; every `*.json` under `data/**` validates against the schema its filename
>   names (empty `data/` = PASS, stated in the test output); `student-state` and `telemetry-batch` schemas
>   reject any object containing a key from the identifier blocklist.
> - Demo EPIC: `CoreTests` decode every example file into the `Core` types and re-encode byte-equal (modulo
>   key order); `core-cli validate` runs L0 (`graph-constraints.md`).

Source: `contracts/data-model.md:72-78`
Binds this task: the pipeline's `test_core_seam.py` must exercise `core-cli validate` and `core-cli layout` over real bundle directories (C1 seam test). The test confirms that the pipeline can invoke the CLI and parse its output correctly.

### contracts/error-codes.md (full registry, required for CLI exit codes)

> # Contract: Error codes registry
>
> **Contract version:** v1.0.0 · Source: every `## Errors produced` section in `docs/domains/*.md`
>
> > The single registry of every error code. **`error-codes.json` is normative**; this file states the rules.
> > Codes are stable strings `<DOMAINPREFIX>_<REASON>`; a change is a versioned change. Additive registration
> > (a new code with its domain doc row) is allowed without a version bump.
>
> ## Rules
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

Source: `contracts/error-codes.md:1-24`
Binds this task: `core-cli` must map every L0 failure to an error code in `error-codes.json` and exit with a non-zero code on validation failure. The CLI's exit-code convention must be verified by the seam test.

### contracts/error-codes.json (complete registry for validation/layout error codes)

```json
{
  "contract_version": "1.0.0",
  "prefixes": {
    "MAP": "map", "EXP": "expedition", "DIAG": "diagnosis", "GRAPH": "concept-graph", "LO": "learning-objects",
    "SPINE": "curriculum-spine", "GEN": "content-generation", "PLATFORM": "platform", "TELEM": "telemetry",
    "TIER": "runtime-tiers", "VERIFY": "verification"
  },
  "codes": [
    {"code": "MAP_LAYOUT_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "MAP_REGION_UNKNOWN", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "MAP_MARKER_OFF_TRAIL", "recoverable": true, "surface": "student", "user_text": "The marker stays where it was; pick a unit from the list."},
    {"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "EXP_NO_FRINGE", "recoverable": true, "surface": "student", "user_text": "You've cleared everything up to here. Move your class marker forward, or explore the map."},
    {"code": "EXP_TRAIL_INVALID", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "EXP_ITEM_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
    {"code": "EXP_NODE_NOT_IN_GRAPH", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."},
    {"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."},
    {"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},

    {"code": "GRAPH_L0_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "GRAPH_NO_PREREQUISITE", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "LO_INCOMPLETE_BUNDLE", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_BAD_PREREQ_MAPPING", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_HINT_TIER_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_HINT_NOT_FOUND", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "LO_PROBE_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "SPINE_PARSE_INCOMPLETE", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "SPINE_PARAPHRASE_REJECTED", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "SPINE_VERBATIM_TEXT_DETECTED", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "SPINE_LINK_UNRESOLVED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "SPINE_UNIT_EMPTY", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "SPINE_SOURCE_REF_UNRESOLVED", "recoverable": true, "surface": "owner", "user_text": null},

    {"code": "GEN_SCHEMA_INVALID", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "GEN_INTERSECTION_EMPTY", "recoverable": true, "surface": "owner", "user_text": null},
    {"code": "GEN_BUDGET_EXCEEDED", "recoverable": true, "surface": "owner", "user_text": null},

    {"code": "PLATFORM_BUNDLE_FETCH_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
    {"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
    {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."},
    {"code": "PLATFORM_SYNC_UNAVAILABLE", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "TELEM_CONSENT_ABSENT", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TELEM_FIELD_NOT_ALLOWED", "recoverable": false, "surface": "internal", "user_text": null},
    {"code": "TELEM_ENDPOINT_UNREACHABLE", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TELEM_BATCH_REJECTED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TELEM_ENDPOINT_MISCONFIGURED", "recoverable": true, "surface": "owner", "user_text": null},

    {"code": "TIER_UNAVAILABLE", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TIER_GUARDRAIL_REFUSED", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TIER_BELOW_THRESHOLD", "recoverable": true, "surface": "internal", "user_text": null},
    {"code": "TIER_TIMEOUT", "recoverable": true, "surface": "internal", "user_text": null},

    {"code": "VERIFY_CAS_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "The checker could not start."},
    {"code": "VERIFY_PARSE_FAILED", "recoverable": true, "surface": "student", "user_text": "This step could not be read; please re-enter it."},
    {"code": "VERIFY_TIMEOUT", "recoverable": true, "surface": "student", "user_text": "This step could not be decided in time; the rest of the check stands."},
    {"code": "VERIFY_UNSUPPORTED", "recoverable": false, "surface": "student", "user_text": "Step checking is not available for this kind of problem; the answer is shown."},
    {"code": "VERIFY_DOMAIN_UNDECIDABLE", "recoverable": true, "surface": "internal", "user_text": null}
  ]
}
```

Source: `contracts/error-codes.json:1-71`
Binds this task: every error code the CLI raises must be registered in this file. The relevant codes for this task are `GRAPH_L0_FAILED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED`, `PLATFORM_BUNDLE_INTEGRITY_FAILED`.

### contracts/schemas/manifest.schema.json (required for validation)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://mathmath.local/contracts/manifest.schema.json",
  "title": "manifest",
  "type": "object",
  "properties": {
    "format_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "bundle_id": {
      "type": "string",
      "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
    },
    "spine_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "graph_version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$"
    },
    "built_at": {
      "type": "string",
      "pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$"
    },
    "starting_chain": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
      },
      "minItems": 1
    },
    "files": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": {
            "type": "string",
            "enum": [
              "regions.json",
              "nodes.json",
              "edges.json",
              "courses.json",
              "landmarks.json",
              "sources.json"
            ]
          },
          "asset_version": {
            "type": "string",
            "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
          },
          "sha256": {
            "type": "string",
            "pattern": "^[a-f0-9]{64}$"
          }
        },
        "required": [
          "name",
          "asset_version",
          "sha256"
        ],
        "additionalProperties": false
      },
      "minItems": 1
    }
  },
  "required": [
    "format_version",
    "bundle_id",
    "spine_version",
    "graph_version",
    "built_at",
    "starting_chain",
    "files"
  ],
  "additionalProperties": false
}
```

Source: `contracts/schemas/manifest.schema.json:1-80`
Binds this task: `core-cli validate` must validate the manifest against this schema and verify SHA256 hashes for all named files.

### CLAUDE.md — D42 (Single-implementation principle for pipeline↔Core seam)

From the project brief context in `CLAUDE.md`:
> Anything the pipeline and the app must agree on is implemented **once, in `Core`**, and exposed through its command-line target (D42).

Source: `CLAUDE.md:9`
Binds this task: L0 validation and layout are implemented once in `Core` and exposed by `core-cli`; Python never reimplements them (per `contracts/graph-constraints.md:8`).

### CLAUDE.md — D33 (Core separation and Foundation-only import boundary)

From the project brief context in `CLAUDE.md`:
> A Swift Package **`Core`** holds graph data types, L0 validation, layout, the expedition scheduler and student-state transitions; `Core` imports **Foundation only** (D33).

Source: `CLAUDE.md:9`
Binds this task: `Core` and `CoreCLI` must import Foundation only; a test asserts this import boundary (already wired per `docs/tech-stack.md:17`).

### CLAUDE.md — Invariant I8 (L0 acceptance gate)

> | I8 | Every accepted graph passes the **L0 checks**: acyclic; no later→earlier course edge; code↔node coverage both ways **for nodes carrying `expectation_codes` and for every Ministry expectation**; a resolvable `source_ref` on every node without codes (a node with neither fails); in-degree outliers flagged; starting chain connected; **every node has exactly one region; every generated trail is a path in the graph.** | §5, v2.7 §1 |

Source: `CLAUDE.md:31`
Binds this task: `core-cli validate` must enforce every L0 check; a failing bundle exits non-zero and the report has `passed: false`.

### CLAUDE.md — Invariant I14 (Renderer-free, single-source Core)

> | I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42 |

Source: `CLAUDE.md:37`
Binds this task: L0 and layout computations are in `Core`, not duplicated in the pipeline; the import boundary test is already in place.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/concept-graph.md — W1 workflow steps 1–3 (the pipeline invokes Core CLI)

> ### W1 — Run the L0 checker
>
> **Pre:** a candidate node/edge set and the Spine bundle it targets.
> **Steps:**
> 1. (Tier 0, `Core` CLI invoked by the pipeline — D42) Load both; stop on a `spine_version` mismatch.
> 2. (Tier 0) Check the §5 constraints: acyclic; no later→earlier course edge (via `courses[].depth`);
>    every Ministry code maps to ≥ 1 Node and every Node carrying codes maps to ≥ 1 code, while every
>    Node without codes carries a resolvable `source_ref` (I8 as amended, v2.7 §1); in-degree outliers flagged; the D14 starting
>    chain connected end-to-end; every node has exactly one region (ten regions per D21 revised); every
>    generated trail segment is a path in the graph (v2 §5; checked again at trail generation, expedition W8). The same function runs again at load on the device (platform W1).
> 3. (Tier 0) Emit the L0 report — pass/fail per check, violating ids, and the in-degree distribution the
>    Owner uses to set the threshold empirically at M2 (§11); default the 95th percentile [ESTIMATE: flags a
>    handful of nodes], advisory only.

Source: `docs/domains/concept-graph.md:47-59`
Binds this task: `core-cli validate` is the Tier-0 entry point; it loads the bundle, checks all L0 constraints, and emits a structured report (stdout JSON).

## §D. Prior task outputs this task depends on

- **L0 validation logic** — exported from `Core` module (produced by task 01.2); must be callable from `CoreCLI` via a function that takes a bundle directory path and returns a JSON report object.
- **Layout function** — exported from `Core` module (produced by task 01.3); must be callable from `CoreCLI` via a function that takes a bundle directory path and writes positions to `nodes.json`.
- **Core data types** — `Codable` types for `manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources` (produced by task 01.1 or earlier); must be decodable from the bundle JSON files in `data/demo` and `contracts/examples/`.

*Note: The task specs for 01.2 and 01.3 do not yet exist; the compiler is acting on the EPIC brief's description of their expected outputs.*

## §E. Negative facts (confirmed ABSENT)

- **No `core-cli` subcommands yet for `validate`, `layout`, or version-output.** Current `main.swift` line 10 handles only `"version"` and prints `CoreInfo.dataFormatVersion`; no other subcommands are implemented. Source: `Packages/Core/Sources/CoreCLI/main.swift:10-14` — only default case routes to usage/error exit.
- **No Python `core_cli()` wrapper functions for `validate` or `layout`.** Current `pipeline/src/mathmath_pipeline/__init__.py:17-25` defines a generic `core_cli(*args: str)` that invokes the binary; but no pipeline-specific wrappers like `core_cli.validate()` or `core_cli.layout()` exist yet. Source: Grep `validate|layout` in `pipeline/src/mathmath_pipeline/` returned no matches outside the generic wrapper call in `__init__.py:29`.
- **No seam test for `validate` or `layout` subcommands.** `pipeline/tests/test_core_seam.py:10-12` tests only `core_cli("version")` returning a semver string. No test exercises `validate` or `layout` against `data/demo`. Source: `pipeline/tests/test_core_seam.py:1-13`.
- **`pipeline/src/mathmath_pipeline/` currently exports only `core_cli` (generic).** Glob `pipeline/src/mathmath_pipeline/*.py` returns only `__init__.py` and `__pycache__/`. No submodules for specific pipeline functions (spine, generation, L1/L2, bundle, etc.) exist yet. Source: Glob `/Users/jimmyz/Dev/mathmath/pipeline/src/**` returned only `__init__.py`.
- **No `data/demo/` bundle files exist.** Glob `data/demo/*.json` returns no matches. The demo bundle is a separate deliverable of task 01.5. Source: Glob `/Users/jimmyz/Dev/mathmath/data/**` returned empty (or only structure/README).
- **No `validate` or `layout` error-code mapping in `Core`.** The `CoreError` enum is not yet visible in the read output. Task 01.2 owns the L0 rules; this task owns the `core-cli` entry points and exit-code mapping.

## §F. File scope

**CREATE / MODIFY:**

- **CREATE** `Packages/Core/Sources/CoreCLI/ValidateCommand.swift` — confirmed absent (Glob `CoreCLI/*.swift` returned only `main.swift`).
- **CREATE** `Packages/Core/Sources/CoreCLI/LayoutCommand.swift` — confirmed absent.
- **CREATE** `Packages/Core/Sources/CoreCLI/Usage.swift` — confirmed absent.
- **MODIFY** `Packages/Core/Sources/CoreCLI/main.swift:1-16` — current shape: switch on `CommandLine.arguments.dropFirst().first`, handles only `"version"`. Will add cases for `"validate"` and `"layout"`.
- **CREATE** `pipeline/src/mathmath_pipeline/core_cli.py` — confirmed absent (only `__init__.py` exists in `pipeline/src/mathmath_pipeline/`).
- **MODIFY** `pipeline/src/mathmath_pipeline/__init__.py:1-30` — current shape: exports `core_cli()` generic wrapper, `REPO_ROOT`, `CORE_PACKAGE` constants; `main()` calls `core_cli('version')`. Will add `validate()` and `layout()` wrappers; the generic `core_cli()` remains as-is.
- **MODIFY** `pipeline/tests/test_core_seam.py:1-13` — current shape: single test `test_core_cli_version_is_semver()`. Will add tests that invoke `validate()` and `layout()` over `data/demo` and verify report shape/exit codes (C1 seam test).

## §G. Stack constraints relevant here

### Language and tooling (from `docs/tech-stack.md`)

**Swift (App + Core):**
- Version: Swift 6 (language mode 6, strict concurrency `complete`), toolchain 6.3.3 (Xcode 26.6).
- Build command: `swift build -c release --product core-cli` (line 17 of `scripts/gate.sh`).
- Import boundary: Foundation only for `Core` (asserted by test, `docs/tech-stack.md:17`).
- Testing: Swift Testing (`import Testing`); tests run on iOS simulator (D29).

Source: `docs/tech-stack.md:10-22` (Swift 6, UIKit, SpriteKit restrictions, `Core` boundary).

**Python (Pipeline):**
- Version: Python 3.14 (`.python-version = 3.14`; local 3.14.7).
- Build tool: `uv` (0.12.12).
- Dependencies (pinned in `uv.lock`, resolved 2026-09-09): `anthropic 1.4.0`, `pydantic 2.13.5`, `sympy 1.14.0`.
- Lint: `ruff` (≥0.16, check + format).
- Typecheck: `pyright` strict (`typeCheckingMode = "strict"`).
- Tests: `pytest` (≥8).

Source: `docs/tech-stack.md:25-30` and `pipeline/pyproject.toml:1-42`.

### Build gates (from `scripts/gate.sh` and `docs/tech-stack.md §3`)

The four gates, run in this order (all must pass):
1. **Format + lint:** `swift-format lint --strict` on `Packages` and `App/Sources`; `ruff check` and `ruff format --check` on `pipeline`.
2. **Typecheck:** `pyright` (strict) on `pipeline`.
3. **Core build + test:** `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` on iOS simulator; `xcodebuild test -scheme Rendering` on simulator (D29).
4. **App build + pipeline tests:** `xcodebuild build -scheme mathmath` on simulator; `pytest`.

Source: `scripts/gate.sh:1-26` (full gate script) and `docs/tech-stack.md:69-80` (description).

### Error codes this task must use

From `contracts/error-codes.json`, the codes relevant to `core-cli validate` and `layout`:
- `GRAPH_L0_FAILED` — any L0 check failure
- `MAP_LAYOUT_MISSING` — node without a position after `core-cli layout`
- `MAP_REGION_UNKNOWN` — node with invalid `region_id`
- `MAP_LANDMARK_UNSOURCED` — landmark without `source_url`
- `SPINE_UNIT_EMPTY` — unit with no expectations
- `SPINE_SOURCE_REF_UNRESOLVED` — node's `source_ref` does not resolve (pipeline-time check)
- `PLATFORM_BUNDLE_INTEGRITY_FAILED` — manifest mismatch or missing file

Source: `contracts/error-codes.json:8-49` (selected entries) and `contracts/graph-constraints.md:10-23` (L0 rule error codes).

### Report shape and exit codes

- `core-cli validate <bundle-dir>` outputs JSON to stdout (exact shape in `contracts/graph-constraints.md:25-27`): `{ bundle_id, passed, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`.
- Exit code: 0 if `passed: true`, non-zero (platform convention; suggest `exit(1)`) if `passed: false` or on any error.
- Empty violation lists must be included in the report (C3 compliance).

Source: `contracts/graph-constraints.md:25-27` (Report shape) and `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:56-62` (amendment 01.05.1 on L0 report stdout).

### L0 report is NOT a file; it is stdout

**Ground-truth correction (AMENDMENT-01.05.1, 2026-09-09):**

The L0 report is **not** written to `data/demo/l0-report.json` or any committed file. It is `core-cli validate` **stdout**, JSON, parsed in-process by the pipeline wrapper. The pipeline wrapper fails the build if `passed: false`. Nothing but schema-named bundle files (`manifest.json`, `nodes.json`, `edges.json`, `courses.json`, `regions.json`, `landmarks.json`, `sources.json`) may be written under `data/**`.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:135-159` (amendment 01.05.1, lines 147-156).

### Test infrastructure

- **Python test runner:** `pytest` (≥8) with `pyproject.toml` configuration (`testpaths = ["tests"]`, `docs/tech-stack.md:30`).
- **How `test_core_seam.py` currently invokes `core-cli`:** Via `subprocess.run()` with `["swift", "run", "--package-path", str(CORE_PACKAGE), "-c", "release", "core-cli", *args]`. Source: `pipeline/src/mathmath_pipeline/__init__.py:19-24`. The invocation is cached across test runs within a single pytest session (no explicit caching in the current code; `swift run` is incremental).
- **Current test expectations:** `test_core_seam.py:10-12` asserts that `core_cli("version")` returns a semver string matching `\d+\.\d+\.\d+`.

Source: `pipeline/src/mathmath_pipeline/__init__.py:17-25` (current `core_cli()` implementation) and `pipeline/tests/test_core_seam.py:1-13` (current test).

### Pyright strict configuration (Python boundary validation)

```
[tool.pyright]
pythonVersion = "3.14"
typeCheckingMode = "strict"
include = ["src", "tests"]
```

Source: `pipeline/pyproject.toml:35-38`

This means all pipeline code, including the wrappers for `core-cli` and the seam test, must pass `pyright --outputjson` with no errors or warnings.

---

## §H. Acceptance boundaries (from EPIC brief)

For context: task 01.4 is scope-gated by these acceptance criteria from the EPIC (§4):

- Criterion 1: `core-cli validate data/demo` prints a report with `passed: true` and every check listed, empty violation lists included (C3).
- Criterion 5: The pipeline's `core_cli("validate", …)` and `core_cli("layout", …)` wrappers are covered by a test that runs them over `data/demo` (C1 seam: pipeline↔`core-cli`).
- Criterion 9: `scripts/gate.sh` is green with the new tests included.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:67-86`.

These are not this task's sole acceptance criteria — the task spec will define them — but they are the narrow seams at which this task's output is exercised.

---

# Quote audit

All verbatim quotes re-verified against source files 2026-09-09:

1. ✓ `contracts/graph-constraints.md:5-8` — Preamble
2. ✓ `contracts/graph-constraints.md:12-23` — L0 rules table
3. ✓ `contracts/graph-constraints.md:25-27` — Report shape
4. ✓ `contracts/data-model.md:24-29` — Versioning section
5. ✓ `contracts/data-model.md:72-78` — Enforcement section
6. ✓ `contracts/error-codes.md:1-24` — Error codes rules
7. ✓ `contracts/error-codes.json:1-71` — Full registry (complete file)
8. ✓ `contracts/schemas/manifest.schema.json:1-80` — Full schema (complete file)
9. ✓ `CLAUDE.md:9` — D42 principle
10. ✓ `CLAUDE.md:31` — I8 invariant
11. ✓ `CLAUDE.md:37` — I14 invariant
12. ✓ `docs/domains/concept-graph.md:47-59` — W1 workflow
13. ✓ `docs/tech-stack.md:10-22` — Swift stack
14. ✓ `docs/tech-stack.md:25-30` — Python stack
15. ✓ `scripts/gate.sh:1-26` — Full gate script
16. ✓ `pipeline/pyproject.toml:35-38` — Pyright config
17. ✓ `pipeline/src/mathmath_pipeline/__init__.py:17-25` — `core_cli()` function
18. ✓ `pipeline/tests/test_core_seam.py:1-13` — Current seam test
19. ✓ `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:135-159` — Amendment 01.05.1

All quoted blocks verified byte-for-byte against source files. No blocks downgraded to RECONSTRUCTED.

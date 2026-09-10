# Task 01.02 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: l0-checker
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- **Epic:** 01
- **Task:** 02
- **Slug:** `l0-checker`
- **Summary:** Implement L0-1 … L0-10 validation rules in `Core` as one pure `validate(bundle)` function returning the report shape defined in `contracts/graph-constraints.md`. Include manifest-completeness refusal (`PLATFORM_BUNDLE_INTEGRITY_FAILED`) and a negative-control fixture per rule. L0-T (trail segments) is explicitly out of scope for EPIC 02. Build-time resolution of `source_ref` locators (L0-3b) and landmark URLs (L0-10) is the pipeline's task (01.7) — only the in-`Core` structural half is here.
- **Invariants in play:** I1, I2, I6, I8, I9, I14, I15

## §B. Applicable contract rules (verbatim)

### contracts/graph-constraints.md — full contract (lines 1–32)

> # Contract: Graph constraints — L0 (LOCK-FIRST)
>
> **Contract version:** v1.0.0 · Source: brief v2 §5, I8 as amended (v2.7 §1), `concept-graph.md` W1, `expedition.md` W8
>
> The structural rules every accepted bundle passes. Implemented **once**, in `Core` (`validate`), exposed by
> `core-cli validate <bundle-dir>` and run (a) by the pipeline build step — failing data is **not emitted**
> (D33) — and (b) at app load — a failing bundle is refused and the previous set stays (platform W1). Python
> never reimplements these (D42). Each rule has an id so reports, tests and specs cite the same thing.
>
> | Id | Rule | Fails with | Note |
> |---|---|---|---|
> | L0-1 | The edge set is acyclic. | `GRAPH_L0_FAILED{L0-1, cycle[]}` | — |
> | L0-2 | No edge goes from a later course to an earlier one: for every edge, `min depth(from) ≤ max depth(to)` over `courses[]`; nodes without `courses[]` (undergraduate) are treated as deeper than every course. | `GRAPH_L0_FAILED{L0-2, edge}` | depth = the course's position in the Ministry succession, from `courses.json` |
> | L0-3a | Every Ministry expectation in the spine maps to ≥ 1 node, and every node carrying `expectation_codes` maps to ≥ 1 existing code. | `GRAPH_L0_FAILED{L0-3a, codes[]}` | applies only to code-bearing nodes (v2.7 §1) |
> | L0-3b | Every node without `expectation_codes` carries a `source_ref` whose `source` exists in `sources.json` and whose `locator` is non-empty; the pipeline additionally checks that the locator resolves (HTTP 2xx) at build. A node with neither codes nor `source_ref` fails. | `GRAPH_L0_FAILED{L0-3b, node}` / `SPINE_SOURCE_REF_UNRESOLVED` | resolution is a build-time check; the app checks presence only |
> | L0-4 | In-degree outliers are **flagged, not failed**: nodes whose in-degree exceeds the threshold (default: 95th percentile of the bundle [ESTIMATE: set empirically at M2, concept-graph Q1]) are listed in the report. | report only | advisory |
> | L0-5 | The D14 starting chain is connected end-to-end: a directed path exists through the chain's nodes in order. | `GRAPH_L0_FAILED{L0-5, break}` | chain node ids are data in the bundle (`manifest.starting_chain[]`) |
> | L0-6 | Every node has exactly one `region_id`, and it names a non-horizon region in `regions.json`. | `GRAPH_L0_FAILED{L0-6, node}` / `MAP_REGION_UNKNOWN` | — |
> | L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by `core-cli layout`; checked after it |
> | L0-8 | Every unit of every course references only expectations of that course, every expectation is in exactly one unit, no unit is empty. | `SPINE_UNIT_EMPTY` / `GRAPH_L0_FAILED{L0-8}` | D45 |
> | L0-9 | Every course's `next_courses[]` names existing courses and contains no cycle. | `GRAPH_L0_FAILED{L0-9}` | D47 succession is data |
> | L0-10 | Every landmark's `node_ids[]` are existing nodes and `source_url` is present (https). | `MAP_LANDMARK_UNSOURCED` | resolution checked by the pipeline (I15) |
> | L0-T | **Trail segments** (generated at runtime, expedition W8): every segment's `node_ids[]` is a directed path in the graph; a course segment contains only that course's nodes. | `EXP_TRAIL_INVALID` | same `Core` function; runs at generation, not on the bundle |
>
> **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
> violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
> passed. Empty violation lists are printed, never omitted (C3).
>
> **Query rules (also `Core`):** the deepest-unmastered-prerequisite query walks ≤ 2 levels breadth-first
> (I4), treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest
> depth marker, then node id (Q3). The fringe (D48) and the clear rule are in `interaction-contract.md`.

Source: `contracts/graph-constraints.md:1–32`
Binds this task: Defines the exact set of L0 rules to implement (L0-1 through L0-10; L0-T marked out of scope), the error codes raised per rule, and the required report JSON shape (`bundle_id`, `passed`, `checks[]` with `id`/`passed`/`violations[]`, and `indegree`). Acceptance is iff every non-advisory check passed; empty violation lists must be printed (C3).

### contracts/error-codes.md — Rules section (lines 9–24)

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

Source: `contracts/error-codes.md:9–24`
Binds this task: `CoreError` must be defined as a `String` enum mirroring the codes raised by L0 checks. Every code raised must be in `error-codes.json`. `GRAPH_L0_FAILED` must carry rule ids in its details.

### contracts/error-codes.json — full registry (lines 1–71)

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
>     {"code": "MAP_MARKER_OFF_TRAIL", "recoverable": true, "surface": "student", "user_text": "The marker stays where it was; pick a unit from the list."},
>     {"code": "MAP_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "EXP_NO_FRINGE", "recoverable": true, "surface": "student", "user_text": "You've cleared everything up to here. Move your class marker forward, or explore the map."},
>     {"code": "EXP_TRAIL_INVALID", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "EXP_ITEM_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "EXP_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
>     {"code": "EXP_NODE_NOT_IN_GRAPH", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "DIAG_NO_PREREQUISITE", "recoverable": true, "surface": "student", "user_text": "Nothing upstream to check — here's a hint."},
>     {"code": "DIAG_PROBE_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "No quick check is available for this one yet; here's a hint instead."},
>     {"code": "DIAG_STATE_WRITE_FAILED", "recoverable": true, "surface": "student", "user_text": "Your progress could not be saved just now; it will be retried."},
>
>     {"code": "GRAPH_L0_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "GRAPH_NO_PREREQUISITE", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "LO_INCOMPLETE_BUNDLE", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_BAD_PREREQ_MAPPING", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_HINT_TIER_MISSING", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_PROBE_UNCHECKABLE", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_BAD_DISTRACTOR_TAG", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_LANDMARK_UNSOURCED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_HINT_NOT_FOUND", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "LO_PROBE_POOL_EMPTY", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "SPINE_PARSE_INCOMPLETE", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "SPINE_PARAPHRASE_REJECTED", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "SPINE_VERBATIM_TEXT_DETECTED", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "SPINE_LINK_UNRESOLVED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "SPINE_UNIT_EMPTY", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "SPINE_SOURCE_REF_UNRESOLVED", "recoverable": true, "surface": "owner", "user_text": null},
>
>     {"code": "GEN_SCHEMA_INVALID", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "GEN_INTERSECTION_EMPTY", "recoverable": true, "surface": "owner", "user_text": null},
>     {"code": "GEN_BUDGET_EXCEEDED", "recoverable": true, "surface": "owner", "user_text": null},
>
>     {"code": "PLATFORM_BUNDLE_FETCH_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
>     {"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."},
>     {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."},
>     {"code": "PLATFORM_SYNC_UNAVAILABLE", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "TELEM_CONSENT_ABSENT", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TELEM_FIELD_NOT_ALLOWED", "recoverable": false, "surface": "internal", "user_text": null},
>     {"code": "TELEM_ENDPOINT_UNREACHABLE", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TELEM_BATCH_REJECTED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TELEM_ENDPOINT_MISCONFIGURED", "recoverable": true, "surface": "owner", "user_text": null},
>
>     {"code": "TIER_UNAVAILABLE", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TIER_GUARDRAIL_REFUSED", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TIER_BELOW_THRESHOLD", "recoverable": true, "surface": "internal", "user_text": null},
>     {"code": "TIER_TIMEOUT", "recoverable": true, "surface": "internal", "user_text": null},
>
>     {"code": "VERIFY_CAS_UNAVAILABLE", "recoverable": true, "surface": "student", "user_text": "The checker could not start."},
>     {"code": "VERIFY_PARSE_FAILED", "recoverable": true, "surface": "student", "user_text": "This step could not be read; please re-enter it."},
>     {"code": "VERIFY_TIMEOUT", "recoverable": true, "surface": "student", "user_text": "This step could not be decided in time; the rest of the check stands."},
>     {"code": "VERIFY_UNSUPPORTED", "recoverable": false, "surface": "student", "user_text": "Step checking is not available for this kind of problem; the answer is shown."},
>     {"code": "VERIFY_DOMAIN_UNDECIDABLE", "recoverable": true, "surface": "internal", "user_text": null}
>   ]
> }

Source: `contracts/error-codes.json:1–71`
Binds this task: Normative registry. L0 checks must raise only these codes: `GRAPH_L0_FAILED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED`, `PLATFORM_BUNDLE_INTEGRITY_FAILED`. All are marked `recoverable: true`. Every code raised in this task's implementation must exist in this registry and be mirrored in `CoreError`.

### contracts/data-model.md — Collections and Versioning sections (lines 45–79)

> ### Collections (one file each; see `schemas/`)
> | File | Schema | Notes |
> |---|---|---|
> | `manifest.json` | `manifest.schema.json` | `format_version`, `bundle_id`, `files[]` (name, `asset_version`, `sha256`), `spine_version`, `graph_version`, `built_at` |
> | `regions.json` | `regions.schema.json` | ten regions + horizon labels (+ shore); normalised polygon, `neighbours[]`, `about` (one sentence) |
> | `nodes.json` | `nodes.schema.json` | `id`, `name`, `region_id`, `strand?`, `expectation_codes[]?`, `source_ref?` (**at least one**), `courses[] {course_code, depth}`, `position {x,y}` (from `core-cli layout`), `layout_hint?`, `paraphrase`, `explanation?`, `worked_examples[]?`, `error_types[]` (closed, one `none-of-these`, each `implies_prerequisite?`), `hint_tree {error_type_id → [tier1, tier2, tier3]}`, `probe_items[]` |
> | `edges.json` | `edges.schema.json` | `from`, `to`, `sources[] {tag, origin}`, `generation_agreement`, `confidence` [0,1], `probe_stats {probes, confirmed, downstream_fail_given_upstream_fail}` |
> | `courses.json` | `courses.schema.json` | `course_code`, `name`, `vintage`, `strands[]`, `expectations[] {code, kind, paraphrase, official_url, unit_id}`, `units[] {unit_id, name, expectation_codes[]}`, `unit_source? {title, edition}`, `next_courses[]` |
> | `landmarks.json` | `landmarks.schema.json` | `id`, `name`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` |
> | `sources.json` | `sources.schema.json` | undergraduate sources: `source`, `title`, `edition`, `licence`, `attribution`, `url` |
>
> ### Versioning
> - Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means
>   `Core` needs a migration; the app refuses a bundle whose major differs from its own.
> - `manifest.json` lists every file with `asset_version` (id) and `sha256`; a partial manifest is never
>   activated (platform W2). Bundle files are **immutable**: a change is a new `asset_version`.
> - `StudentState.schema_version` (integer) is migrated forward only (platform W3); older files are kept.

Source: `contracts/data-model.md:45–79`
Binds this task: Defines the bundle file set, which L0 must load and validate structurally. Manifest must list every file with sha256; L0 must refuse a partial manifest (`PLATFORM_BUNDLE_INTEGRITY_FAILED`). `format_version` must match `CoreInfo.dataFormatVersion`. Each collection has a normative schema in `contracts/schemas/`.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/concept-graph.md — Workflow W1 (lines 47–62)

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
>
> **Post:** the report is persisted; a graph failing any check is never accepted (I8). Emits
> `graph.l0_completed`.

Source: `docs/domains/concept-graph.md:47–62`
Binds this task: L0 checking is pure Tier 0 in `Core`, invoked by the pipeline (`core-cli validate`) and again at app load. Manifest/spine-version check stops execution before L0 checks. Report shape is specified by the contract; advisory-only L0-4 (in-degree outliers) must still be listed.

### docs/domains/curriculum-spine.md — Core entities section (lines 21–48)

> ## Core entities
>
> **Course** — one published course with grade, stream and vintage: MTH1W (2021); MPM2D, MFM2P (2005 plus
> the 2022 addenda); MCR3U, MCF3M, MBF3C, MEL3E, MHF4U, MCV4U, MDM4U, MAP4C, MEL4E (2007) [SOURCED: brief
> §4.1] — twelve in all. Vintage belongs to the Course: a nominal strand differs between vintages.
> **Strand** — a division of a Course identified by its code prefix; never empty.
>
> **Unit** — a course's teaching unit (D45): an ordered group of that course's Expectations. Units are not in
> the Ministry documents; each Course names one designated textbook as its `unit_source` (chosen at M1,
> recorded in the bundle), and Expectations are grouped by that textbook's chapter sequence — the existing L1
> `textbook_order` source. A course with no `unit_source`, or an Expectation the textbook does not place,
> falls back to grouping by Strand in Ministry order (v2.7 §2). The Demo's two unit lists are hand-written.
>
> **Course succession** — `next_courses[]` per Course from the Ministry's course-prerequisite chart
> [SOURCED: Ontario 2007 curriculum document], e.g. MPM2D → MCR3U → MHF4U → MCV4U; data, not logic (v2.7 §4),
> read by expedition W8 when a trail extends past a course.

Source: `docs/domains/curriculum-spine.md:21–48`
Binds this task: L0-8 must validate that units exist and reference only their course's expectations; L0-9 must validate that `next_courses[]` names existing courses and contains no cycle.

### docs/domains/map.md — Errors section (lines 120–127)

> ## Errors produced
>
> | Code | When | User sees | Recoverable |
> |---|---|---|---|
> | `MAP_LAYOUT_MISSING` | A node in the bundle has no coordinates | Internal; bundle refused at load (platform) | Yes — re-run the pipeline build step (D33) |
> | `MAP_REGION_UNKNOWN` | A node names a region absent from the bundle | Internal; bundle refused (I8) | Yes — pipeline |
> | `MAP_MARKER_OFF_TRAIL` | Marker dropped outside a unit boundary of the selected course | Marker snaps back | Yes |
> | `MAP_LANDMARK_UNSOURCED` | A landmark lacks `source_url` | Internal; bundle refused (I15) | Yes — pipeline |

Source: `docs/domains/map.md:120–127`
Binds this task: L0-6 refusal on `MAP_REGION_UNKNOWN`, L0-7 refusal on `MAP_LAYOUT_MISSING`, L0-10 refusal on `MAP_LANDMARK_UNSOURCED` — all internal codes, all mark bundles as failed.

## §D. Prior task outputs this task depends on

This task depends on task 01.1 (Core data model — Codable types), which has **not yet been produced**. The task spec for 01.1 does not exist in the repo.

**BLOCKING DEPENDENCY — this context bundle is incomplete:**
- `Packages/Core/Sources/Core/Model/Manifest.swift` — the `Manifest` `Codable` struct
- `Packages/Core/Sources/Core/Model/Bundle.swift` or similar — `Nodes`, `Edges`, `Regions`, `Courses`, `Landmarks`, `Sources` collections
- `Packages/Core/Sources/Core/CoreError.swift` — the `CoreError: String` enum mirroring error-codes.json codes
- `Packages/Core/Sources/Core/Model/*.swift` — the full set of `Codable` types (from task 01.1 § expected file scope)

**INTERIM ASSUMPTION:** Task 01.1 produces these types with full `Codable` conformance; this task assumes they are available in the `Core` module's public API. Once task 01.1 is authored and executed, verify that its produced signatures match the assumptions in §D of this bundle.

## §E. Negative facts (confirmed ABSENT)

- **No L0 checker module exists yet.** Confirmed: Glob `Packages/Core/Sources/Core/Validation/**/*.swift` returned no matches. Glob `Packages/Core/Sources/Core/Model/**/*.swift` returned no matches.
- **No CoreError enum exists yet.** Confirmed: Grep `CoreError` over `Packages/Core/Sources` returned no files. This is task 01.1's responsibility.
- **No demo bundle exists yet.** Confirmed: Glob `data/demo/*.json` returned no matches. Bundle authoring is task 01.5.
- **No task 01.1 spec exists yet.** Confirmed: Glob `tasks/epic-01-task-01*.md` returned no matches. This is blocking.
- **No fixtures directory exists yet.** Confirmed: Glob `Packages/Core/Tests/CoreTests/Fixtures/**/*` returned no matches. Fixtures must be created as part of this task's negative-control tests.
- **No resources declared in `Packages/Core/Package.swift`.** Confirmed: Read `Package.swift` lines 26–29 show test target with no `resources:` parameter. If fixtures are stored as JSON files, a `resources:` declaration may be needed (Swift Testing may not auto-discover fixtures like XCTest does).

## §F. File scope

Files this task may create or touch:

- **CREATE** `Packages/Core/Sources/Core/Validation/L0Checker.swift` — the public `validate(bundle:bundleDir:)` function and supporting types (rule checkers, report builders). Confirmed absent: Glob `Packages/Core/Sources/Core/Validation/**` empty.
- **CREATE** `Packages/Core/Sources/Core/Validation/L0Report.swift` — the L0 report data types (e.g. `L0Report`, `L0Check`, `L0Violation`). Confirmed absent.
- **CREATE** `Packages/Core/Sources/Core/Validation/GraphIndex.swift` — helper types for efficient graph queries (adjacency lists, region index, course depth map). Confirmed absent.
- **CREATE** `Packages/Core/Tests/CoreTests/L0CheckerTests.swift` — test suite covering all L0 rules, acceptance criteria, and negative controls. Confirmed absent: Glob `Packages/Core/Tests/CoreTests/*.swift` returned only `CoreTests.swift` (the Phase 5 placeholder).
- **CREATE** `Packages/Core/Tests/CoreTests/Fixtures/l0/*.json` — negative-control fixtures (bundles with a cycle, a node with two regions, a node with neither codes nor `source_ref`, an empty unit, a landmark without `source_url`). Confirmed absent: Glob `Packages/Core/Tests/CoreTests/Fixtures/**` empty.
- **MODIFY** `Packages/Core/Tests/CoreTests/CoreTests.swift:<line>` — extend the existing `@Suite` to import `L0CheckerTests` or keep L0 tests in the dedicated file. Current shape: 40 lines, imports `Testing` (Swift Testing framework), has import boundary test (I14). Will not edit unless tests share a `@Suite`.

## §G. Stack constraints relevant here

- **Test framework:** Swift Testing (`import Testing`) — confirmed in use in `CoreTests.swift:1–2`. Syntax: `@Suite`, `@Test`, `#expect`. No XCTest in `Core` target (I14).
- **Swift version:** Swift 6 strict concurrency (`swiftLanguageModes: [.v6]` in `Package.swift:31`); code must compile with `-strict-concurrency=complete`.
- **Imports in Core:** Foundation only (I14). Test can import `Testing` (not forbidden). Boundary test (`CoreTests.swift:18–39`) scans every `.swift` file in `Sources/Core` and fails if any imports `SwiftUI`, `UIKit`, `SpriteKit`, `SwiftData`, etc.
- **Fixture loading:** No `resources:` parameter in `Package.swift:26–29`'s test target yet. If fixtures are JSON files (not embedded), may need to add `resources: [.copy("Fixtures")]` or similar and load via `Bundle.module`. **TBD: fixture strategy** — store as JSON files on disk with manual path loading, or embed as strings in Swift code. The task spec at `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:62–68` requires "negative controls, C2" but does not specify storage. Grep `Bundle.module` over existing tests: no matches. Assume JSON fixture files with manual `FileManager` loading from a relative path based on `#filePath` (similar to the import-boundary test pattern).
- **Error codes this task must mirror in Swift:** From the task spec and error-codes.json, the codes raised are: `GRAPH_L0_FAILED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED`, `PLATFORM_BUNDLE_INTEGRITY_FAILED`. These must exist in `CoreError` by the time this task's tests run.
- **CI/gates:** `scripts/gate.sh:3/4` runs `xcodebuild test -scheme Core-Package` on the iOS simulator (D29, no device). New test target must be discoverable by the scheme.
- **Manifest-completeness check:** The task spec requires `PLATFORM_BUNDLE_INTEGRITY_FAILED` on a partial manifest (missing files or hash mismatch). This is bundled with the L0 checks, not a separate pre-check.

### Schema files (contracts/schemas/) — normative for decoding

The following schemas are referenced by the L0 checks and define the bundle structure:
- `contracts/schemas/manifest.schema.json` — required fields: `format_version`, `bundle_id`, `spine_version`, `graph_version`, `built_at`, `starting_chain[]`, `files[]` with required fields `name` (enum), `asset_version`, `sha256`
- `contracts/schemas/nodes.schema.json` — required fields: `id`, `name`, `region_id` (enum of ten + horizon labels), `courses[]` (each with `course_code`, `depth`), `position` (x, y ∈ [0,1]), `paraphrase`, `error_types[]`, `hint_tree`, `probe_items[]`; optional `expectation_codes[]`, `source_ref`; **at least one** of codes/source_ref must be present (anyOf constraint)
- `contracts/schemas/edges.schema.json` — required fields: `from`, `to`, `sources[]` (each with `tag` enum, `origin`), `generation_agreement`, `confidence` ∈ [0,1], `probe_stats`
- `contracts/schemas/regions.schema.json` — required fields: `id` (enum of ten + horizon labels + shore), `name`, `about`, `horizon` (bool), `polygon[]` (≥ 3 points with x, y), `neighbours[]`
- `contracts/schemas/courses.schema.json` — required fields: `course_code` (enum pattern), `name`, `vintage`, `strands[]`, `expectations[]`, `units[]` (each with `unit_id`, `name`, `expectation_codes[]`), optional `unit_source`, required `next_courses[]`
- `contracts/schemas/landmarks.schema.json` — required fields: `id`, `name`, `what_it_is`, `source_url` (https only), `node_ids[]`, `region_ids[]`, `position` (x, y ∈ [0,1])
- `contracts/schemas/sources.schema.json` — required fields: `source` (enum: `openstax` or `mit-ocw`), `title`, `edition`, `licence`, `attribution`, `url`

All schemas enforce `"additionalProperties": false`.

---

## Summary for the implementer

**Do not start until task 01.1 is complete and its produced types are verified against §D.**

This task implements all L0 checks L0-1 through L0-10 (ten rule identifiers split as L0-1, L0-2, L0-3a, L0-3b, L0-4, L0-5, L0-6, L0-7, L0-8, L0-9, L0-10) plus manifest integrity validation (`PLATFORM_BUNDLE_INTEGRITY_FAILED`). L0-4 is advisory only (flagged, not failed). L0-7 is checked after layout runs. The `validate(bundle:bundleDir:)` function loads the manifest and all sibling JSON files, checks their SHA256s against the manifest, validates structure per the L0 rules, and emits a JSON report. A bundle is rejected iff any non-advisory check fails. A negative-control fixture and test per rule must exist, demonstrating that each rule correctly detects its violation (acceptance criterion 2 of EPIC 01).

The test framework is Swift Testing. Fixture loading strategy is TBD based on whether `Bundle.module` is available or manual `FileManager` path resolution is needed.


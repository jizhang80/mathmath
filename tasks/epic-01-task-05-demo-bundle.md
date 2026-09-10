# Epic 01 · Task 05: Demo bundle

---
epic: 01
task: 05
slug: demo-bundle
kind: feat
risk: seam
depends_on: [01.4, 02b]
model: opus
---

**Amendment 01.05.2 (spec-architect, 2026-09-09) — unblocked.** This task was blocked
(`tasks/blocked/blocked-arbiter-01-05.md`) because AC1 (`passed: true` on all ten L0 checks) appeared to
contradict AC2 (`MTH1W.next_courses == ["MPM2D"]`, `MCR3U.next_courses == ["MHF4U"]`), the landed L0-9
implementation treating a non-resident successor as a violation. That implementation misread the contract:
under its reading `contracts/examples/courses.json` — the contract set's own normative worked example, which
declares exactly those two non-resident successors — fails its own contract. The corrected L0-9 (cycle check
only; non-resident targets legal) is specified in `tasks/epic-01-task-02-l0-checker.md` amendment 01.02.1 and
implemented by task 02b, which this task now depends on. **AC1 and AC2 are compatible and both stand
unchanged: the Demo keeps exactly two courses, MTH1W → MPM2D and MCR3U → MHF4U.** This amendment also applies
the arbiter's Finding 2 ruling on the companion-test path (§2, §5, §6, §7): task 01.7 keeps
`pipeline/tests/test_demo_bundle.py`; this task ships `pipeline/tests/test_demo_bundle_shape.py`. No contract
text changes; no decision D1–D49 changes.

## §1 Goal & acceptance criteria

Goal: author the Demo's hand-written content bundle — exactly seven JSON files under `data/demo/` — so that `core-cli validate data/demo` (the real `Core` L0 checker, invoked through task 01.4's pipeline wrapper) reports `passed: true` on every check, and every file decodes into the landed `Core` `Codable` types and re-encodes JSON-equal. This is data authoring plus one companion test asserting the bundle's shape: no product code changes.

Invariants in play:

- **I1** — every probe item's correctness is a checked `answer`/`correct_choice_id`, never a model judgement; this task writes only checkable items.
- **I5** — no identifying field exists in any of the seven files; none of the schemas expose one, so conformance is automatic if the implementer adds no ad-hoc keys.
- **I6** — every node `paraphrase` and every course `expectations[].paraphrase` is the project's own words, verb-initial, ≤ 140 characters, written FROM the expectation code, never pasted from a Ministry document; no `verbatim` key anywhere.
- **I8** — the bundle passes every L0 rule (`contracts/graph-constraints.md`): acyclic, correct depth ordering, code/source coverage, connected D14 chain, one region per node, in-polygon position, non-empty units, acyclic course succession, sourced landmark.
- **I9** — zero human review step: a failing item is rewritten by the implementer and re-validated, never "approved as-is".
- **I10** — every probe item is `numeric` or `mc`; no other input shape appears.
- **I14** — this task touches no `Core` source; it only feeds data into the existing `Core` decode/validate path.
- **I15** — the one landmark carries a `source_url` (`https://laws-lois.justice.gc.ca/eng/acts/I-15/`) and links ≥ 2 nodes in different regions; its resolution is verified in task 01.7, not here — this task only ensures the field is present and well-formed.

Acceptance criteria (each independently verifiable):

- AC1 (brief §4.1): `core-cli validate data/demo`, run through task 01.4's pipeline wrapper, prints a report with `bundle_id`, `passed: true`, and all ten L0 checks listed (`L0-1` … `L0-10`), each with its (possibly empty) `violations[]` printed, never omitted.
- AC2 (brief §4.8): the bundle contains ≥ 18 and ≤ 24 nodes; `manifest.starting_chain` is a connected directed path (L0-5); exactly two courses (`MTH1W`, `MCR3U`) each with ≥ 3 units; `MTH1W.next_courses == ["MPM2D"]`; `MCR3U.next_courses == ["MHF4U"]`; every `mc` probe item's every `choices[]` entry beyond the correct one carries an `error_type_id` drawn from its node's own `error_types[]`. Asserted by a test, not eyeballed.
- AC3: `pytest pipeline/tests/test_contracts.py` is green: all seven files validate against their schema (`test_data_bundles_validate`), no `verbatim` key (`test_no_verbatim_key_in_examples_or_data`), and the seven-files-only constraint holds (no eighth file under `data/**` — see §2).
- AC4: every one of the seven files, loaded through `Core.BundleIO`/`CoreCoding.decoder`, decodes into its `Core` type and re-encodes to a JSON-equal document (`CoreCoding.encoder`), matching the round-trip test shape already exercised over `contracts/examples/` in task 01.1.
- AC5: exactly one landmark, `canadian-mortgage-compounding`-style id, `source_url` `https://laws-lois.justice.gc.ca/eng/acts/I-15/`, `node_ids[]` naming ≥ 2 nodes whose `region_id`s differ.
- AC6: ten regions total in `regions.json`: `number-operations`, `algebra`, `functions`, `geometry-measurement`, `trigonometry`, `calculus`, `linear-algebra`, `differential-equations`, `probability-statistics`, `discrete` — all `horizon: false`; plus four horizon labels `analysis`, `topology`, `number-theory`, `abstract-algebra` — all `horizon: true`. `shore` is NOT included (out of scope, DEFERRED). Every node's `region_id` is one of `number-operations`, `algebra`, `functions` only.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `data/demo/manifest.json` — CREATE. Bundle manifest: `format_version`, `bundle_id`, `spine_version`, `graph_version`, `built_at`, `starting_chain[]`, `files[]` (six entries: regions, nodes, edges, courses, landmarks, sources — `manifest.json` never lists itself).
- `data/demo/regions.json` — CREATE. Ten regions + four horizon labels, per AC6.
- `data/demo/nodes.json` — CREATE. 18–24 nodes on/adjacent to the D14 chain, in `number-operations` / `algebra` / `functions` only. **Note (task-plan.md note [3]):** this file is later amended in place by task 01.6 (render fallback / notation fixes) and task 01.7 (answer/tag corrections) — this task owns its initial authoring only; do not treat it as permanently frozen after this task, but this task's own Done gate covers only the state it leaves it in.
- `data/demo/edges.json` — CREATE. Edges realising the D14 chain plus a few side dependencies among the authored nodes.
- `data/demo/courses.json` — CREATE. `MTH1W` and `MCR3U`, each with `strands[]`, `expectations[]`, `units[]` (≥ 3 each), `unit_source`, `next_courses`.
- `data/demo/landmarks.json` — CREATE. Exactly one landmark.
- `data/demo/sources.json` — CREATE. May be an empty `sources: []` array if the Demo's nodes carry no `source_ref` (see §6); the file itself must still exist and validate, since `manifest.files[]` lists it.
- `pipeline/tests/test_demo_bundle_shape.py` — CREATE. The companion test asserting AC2's counts, `next_courses` values, region confinement, distractor tags and landmark shape over `data/demo/` only. **This is the single Python file this task writes**, and its path is fixed by this spec, not chosen by the implementer (amendment 01.05.2).

Out-of-scope (do not touch even if tempted):

- Any file under `Packages/Core/**`, and any file under `pipeline/**` **other than the one companion test named in the in-scope list** — this task ships bundle data plus its own companion test, no product code. If `core-cli validate` or the pipeline wrapper do not yet exist/work as task 01.4 specifies, that is a blocking dependency gap, not something this task patches.
- `pipeline/tests/test_demo_bundle.py` — **reserved for task 01.7** (`tasks/context/epic-01-task-07-context.md:123`: "CREATE `pipeline/tests/test_demo_bundle.py` — integration test over `data/demo`"). `docs/plans/epic-01-task-plan.md:22-23` forbids two tasks owning the same file for writes. Never create, extend or rename that file from this task.
- `data/README.md` — already describes `data/demo/` correctly; no edit needed.
- Any eighth file under `data/demo/` (e.g. a committed L0 report, a `trails.json`, an `l0-report.json`). **Hard constraint:** `pipeline/tests/test_contracts.py::test_data_bundles_validate` resolves a schema by filename stem (`Path.stem`) for every `*.json` under `data/**` and fails if no schema of that name exists. Only `manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources` have schemas. Writing any other filename under `data/**` fails the gate. The L0 report is `core-cli validate` **stdout**, never written to disk (amendment 01.05.1).
- `contracts/**` — read-only ground truth; this task must never edit a contract or a schema.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/graph-constraints.md` heading `# Contract: Graph constraints — L0 (LOCK-FIRST)`:
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
  >
  > **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check passed. Empty violation lists are printed, never omitted (C3).

  **How L0-9 reads (settled, amendment 01.05.2):** "names existing courses" means *courses that exist in the Ministry's prerequisite chart*, not *courses resident in this bundle*. `contracts/schemas/courses.schema.json:142-145` constrains a `next_courses[]` entry to the course-code pattern `^[A-Z]{3}[1-4][A-Z]$` and nothing more, and `contracts/examples/courses.json:36-38,68-70` — the normative example — ships exactly the two non-resident successors this bundle also carries. The enforceable L0-9 obligation is the cycle clause over resident courses. See `tasks/epic-01-task-02-l0-checker.md` §4.3 (amendment 01.02.1) for the full four-part derivation, and task 02b for the implementation.

- `contracts/content-policy.md` heading `## Grade 9–12 tier (Ministry authority)`:
  > - A node or expectation carries **codes + the project's own `paraphrase` + an `official_url`**. No field anywhere holds Ministry prose; the key `verbatim` is banned repo-wide (grep gate). Paraphrase rule (curriculum-spine Q1): one verb-initial plain sentence, no LaTeX, ≤ 140 characters, rejected on a shared 6-gram with the source outside the technical-term allow-list. Ministry source text lives in pipeline memory only and never in a kept RunOutput, fixture or test.
  > - Codes, course names, strand names and structure are facts and may be stored freely (§10).
  > - `official_url` hosts are allow-listed (`dcp.edu.gov.on.ca`, `edu.gov.on.ca`); anything else fails the cut.

- `contracts/content-policy.md` heading `## Generated content (all tiers)`:
  > - Distractor tags: every `mc` distractor and every anticipated numeric wrong answer names an `ErrorType` of its node (diagnosis Q1); `none-of-these` is never a tag.

- `contracts/content-policy.md` heading `## Landmarks (I15, D22)`:
  > - Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never "hypothetical".

- `contracts/data-model.md` heading `### Identifiers`:
  > - Ids are **stable, opaque, lowercase kebab-case slugs** matching `^[a-z0-9]+(-[a-z0-9]+)*$`, unique within their collection. Never parse meaning from an id; never renumber. A renamed concept keeps its id.
  > - Fixed vocabularies: `region_id ∈ {number-operations, algebra, functions, geometry-measurement, trigonometry, calculus, linear-algebra, differential-equations, probability-statistics, discrete}` plus horizon labels `{analysis, topology, number-theory, abstract-algebra}` (flag `horizon: true`) and optional `shore`.
  > - `course_code` is the Ministry code verbatim in upper case (`MTH1W`, `MCR3U`); `unit_id` is `<course_code>.u<n>` (1-based, in unit order); `edge_id` is `<from>-->-<to>` (derived, never stored on the edge); `expectation_code` is the Ministry code verbatim (e.g. `B2.3`), scoped by course.

- `contracts/data-model.md` heading `## Enforcement`:
  > - `pipeline/tests/test_contracts.py`: every schema is valid Draft 2020-12; every example in `contracts/examples/` validates; every `*.json` under `data/**` validates against the schema its filename names (empty `data/` = PASS, stated in the test output); `student-state` and `telemetry-batch` schemas reject any object containing a key from the identifier blocklist.
  > - Demo EPIC: `CoreTests` decode every example file into the `Core` types and re-encode byte-equal (modulo key order); `core-cli validate` runs L0 (`graph-constraints.md`).

- `PROJECT-BRIEF-v2.md:68` (D14, verbatim):
  > **D14 | Starting chain: MTH1W linear relations/equations → exponent laws → polynomials/factoring → quadratics → function concept/transformations → exponential functions → logarithms & advanced functions.**

- `PROJECT-BRIEF-v2.md:80` (D26, verbatim):
  > **D26 | A Demo that tests the *form* (does a student want to click in and come back?) is built first, on hand-written data, fully decoupled from M1/M2 content pipelines.**

- `AMENDMENT-v2.6.md` § D (Demo brief deltas), verbatim:
  > - §3.1: initial camera on the tester's selected course trail (MTH1W or MCR3U), continent visible around it; zoom-out available. Ten regions drawn as outlines per revised D21; nodes still only in Number, Algebra, Functions.
  > - §3.3: the start marker is presented as "we are here in class" chosen from a short unit list for the course (hand-written for the two demo trails).

- `docs/domains/curriculum-spine.md:28–32` (Unit, verbatim):
  > **Unit** — a course's teaching unit (D45): an ordered group of that course's Expectations. Units are not in the Ministry documents; each Course names one designated textbook as its `unit_source` (chosen at M1, recorded in the bundle), and Expectations are grouped by that textbook's chapter sequence — the existing L1 `textbook_order` source. A course with no `unit_source`, or an Expectation the textbook does not place, falls back to grouping by Strand in Ministry order (v2.7 §2). The Demo's two unit lists are hand-written.

- `docs/domains/curriculum-spine.md:34–36` (Course succession, verbatim):
  > **Course succession** — `next_courses[]` per Course from the Ministry's course-prerequisite chart [SOURCED: Ontario 2007 curriculum document], e.g. MPM2D → MCR3U → MHF4U → MCV4U; data, not logic (v2.7 §4), read by expedition W8 when a trail extends past a course.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §4 criterion 8, verbatim:
  > 8. The bundle contains ≥ 18 and ≤ 24 nodes, all on or adjacent to the D14 chain, with `starting_chain` in the manifest connected (L0-5), two courses with ≥ 3 units each, `next_courses` MTH1W → MPM2D and MCR3U → MHF4U, and every `mc` distractor tagged.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` § Amendment 01.05.1, amended text, verbatim:
  > **MANDATORY artifact line (P4/C4):** `core-cli` (`validate`, `layout`, `version`) — exercised by `pipeline/tests` over `data/demo` and `contracts/examples`; `data/demo/*.json` — the bundle files only, each named by its schema (`manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), exercised by `test_contracts.py` (schemas) and `core-cli validate`. The **L0 report is not a bundle file and is not committed**: it is `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md` § Report shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing other than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` § Enforcement: every `*.json` under `data/**` validates against the schema its filename names).

- `docs/plans/epic-01-task-plan.md` planner note [3], verbatim:
  > **Shared-file ordering.** `data/demo/nodes.json` is written by 01.5, then amended by 01.6 (notation / `render_fallback`) and 01.7 (answer or tag corrections). These three are strictly sequential and must never be dispatched concurrently. This is the plan's only shared-write path.

- `docs/plans/epic-01-task-plan.md:22-23`, verbatim — the rule fixing this task's companion-test path:
  > The rule the plan enforces: **no two tasks own the same file for writes**, with one deliberate exception, note [3].

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` §9 open question 2, verbatim:
  > Unit lists for MTH1W and MCR3U — **default:** hand-written by the implementer from the Ministry strand structure in unit order (3–5 units per course), recorded in the bundle's `unit_source` as "Demo hand-written unit list" (v2.7 §2 says the Demo's lists stand). Revisit at M1 (EPIC 07).

The seven full JSON Schemas (`manifest.schema.json`, `regions.schema.json`, `nodes.schema.json`, `edges.schema.json`, `courses.schema.json`, `landmarks.schema.json`, `sources.schema.json`) are quoted in full, verbatim, in the context bundle `tasks/context/epic-01-task-05-context.md` §B — the implementer MUST open and re-read the live files at `contracts/schemas/*.schema.json` before authoring each corresponding file; the bundle's copies are the authoritative field lists but the live schema file is the actual validation gate.

Prior signatures / Core types this task's output must decode into (verbatim from `Packages/Core/Sources/Core/Model/*.swift`, confirmed by direct read):

```swift
// Ids.swift
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
```

```swift
// Nodes.swift
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

Note (verified by direct read of `Packages/Core/Sources/Core/CoreCoding.swift`): no `Core` model type declares an explicit `CodingKeys`; `CoreCoding.decoder` sets `decoder.keyDecodingStrategy = .convertFromSnakeCase`, so every JSON key the implementer writes MUST be exactly the snake_case key the schema names (e.g. `region_id`, `expectation_codes`, `error_types`, `hint_tree`, `probe_items`, `layout_hint`, `worked_examples`, `error_type_id`, `correct_choice_id`, `render_fallback`) — the schema's own property names ARE the wire format; do not invent alternate casing.

## §4 Implementation outline

1. **Layer placement.** This task authors layer ① (curriculum spine: `courses.json`) and layer ② (concept graph: `regions.json`, `nodes.json`, `edges.json`, `manifest.json`) data, plus layer ③ static learning-object shapes embedded in `nodes.json` (`probe_items[]`, `error_types[]`, `hint_tree`) and one landmark (`landmarks.json`). No layer ④ (interaction/runtime) code is touched.

2. **Author `regions.json` first.** Ten non-horizon regions with `horizon: false` — ids exactly `number-operations`, `algebra`, `functions`, `geometry-measurement`, `trigonometry`, `calculus`, `linear-algebra`, `differential-equations`, `probability-statistics`, `discrete` — plus four horizon labels with `horizon: true` — ids exactly `analysis`, `topology`, `number-theory`, `abstract-algebra`. Do NOT include `shore` (out of scope per EPIC §7 item 5, DEFERRED D-10). Each region: `id`, `name`, `about` (one sentence, project's own words, not Ministry text — I6 spirit even though `about` has no schema length bound), `horizon`, `polygon` (≥ 3 points, each `x`/`y` in `[0,1]`, forming a simple, non-self-intersecting outline distinct from every other region's outline so regions do not overlap on the map), `neighbours[]` (region ids that are geographically adjacent on the authored layout — may be empty but the key is required by the schema). Only `number-operations`, `algebra`, `functions` will receive nodes; the other seven regions are outlines only (no node in this task references them via `region_id`).

3. **Author `nodes.json`.** Quote the D14 chain (§3 above) and place each of its named stages as one or more nodes:
   - `linear relations/equations` → e.g. `linear-relations`, `solving-linear-equations` (region `algebra`)
   - `exponent laws` → e.g. `exponent-laws` (region `number-operations`)
   - `polynomials/factoring` → e.g. `polynomials`, `factoring` (region `algebra`)
   - `quadratics` → e.g. `solving-quadratics` (region `algebra`) and/or `quadratic-functions` (region `functions`)
   - `function concept/transformations` → e.g. `function-concept`, `function-transformations` (region `functions`)
   - `exponential functions` → e.g. `exponential-functions` (region `functions`)
   - `logarithms & advanced functions` → e.g. `logarithms` (region `functions`) — may be the Demo's one "fogged, far" node per `DEMO-BRIEF.md` §3.2
   Add adjacent supporting nodes (e.g. integer/rational operations, powers of ten / scientific notation in `number-operations`) to reach 18–24 total, staying strictly within `number-operations` / `algebra` / `functions`. Record every planned node's id and its D14-chain stage (or "adjacent, supports node X") in a comment-free authoring note is NOT required in the JSON — the mapping only needs to be evident from `manifest.starting_chain` (§4.4) and the edges that connect the chain nodes end-to-end (L0-5).
   For every node: `id` (kebab-case), `name`, `region_id` (one of the three populated regions), `courses[]` (`{course_code, depth}` — `depth` is the course's 0-based or 1-based position in its own succession chain, consistent for L0-2; e.g. MTH1W nodes get `depth: 0`, MCR3U-only nodes `depth: 1`, matching `next_courses` order), `position` (see step 8 below for whether to hand-write it now), `paraphrase` (≤ 140 chars, verb-initial, project's own words — write it FROM the node's concept, never copy Ministry text), `error_types[]` (≥ 1, each `{id, label, implies_prerequisite?}` — include one `none-of-these` entry per node's `error_types[]` since the nodes.json example does, but never TAG a distractor with `none-of-these`, per content-policy `## Generated content (all tiers)`), `hint_tree` (a map from each `error_type_id` the node's items actually use to an array of EXACTLY 3 hint strings — schema `minItems`/`maxItems` 3), `probe_items[]` (2–3 per node — see step 3a), and EITHER `expectation_codes[]` (grade 9–12 nodes — `{course_code, code}`, code = a real Ministry expectation code for that strand, e.g. `B2.3`) OR `source_ref` (undergraduate nodes — not expected for this Demo; every Demo node should carry `expectation_codes` since Demo content is grade 9–12 only, per `DEMO-BRIEF.md` §3.1–3.2 and D14). `strand`, `explanation`, `worked_examples[]` are optional — omit unless they add clarity; do not add them merely to fill the file out (RULE 2).

3a. **Probe items.** 2–3 per node, `type` = `numeric` or `mc` only (I10). Every item: `id`, `type`, `prompt_latex` (SwiftMath-renderable subset — this task does not need to run the rendering spike, but avoid exotic LaTeX; task 01.6 will fix any residual issue), `why` (one line, shown with the answer per I3). `numeric` items require `answer.value` matching pattern `^-?[0-9]+(\.[0-9]+)?(/[1-9][0-9]*)?$` (integer, decimal, or a `p/q` fraction with `q` a positive integer with no leading zero) and MAY carry `tolerance`; `wrong_answers[]` is optional but if present each entry needs `error_type_id` naming one of the node's own `error_types[].id`. `mc` items require `choices[]` (≥ 2, each `{id, latex, error_type_id?}`) and `correct_choice_id` naming one choice's `id`; every choice that is NOT the correct one MUST carry `error_type_id` naming one of the node's own `error_types[].id` (AC2/content-policy `## Generated content (all tiers)`) — `none-of-these` is never used as an `error_type_id` value on a choice or wrong answer. The correct choice's `error_type_id` is optional (it names no error) — leave it absent, not a fabricated non-error tag.

4. **Author `manifest.json`.** `format_version` = `"0.0.0"` (matching `contracts/examples/manifest.json`; do not invent a different value — no other value is attested anywhere in the bundle). `bundle_id` = a kebab-case slug for the Demo bundle (e.g. `demo`). `spine_version` / `graph_version` = `"0.0.0"`. `built_at` = an ISO-8601 UTC timestamp matching pattern `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$` (e.g. `2026-09-09T00:00:00Z`). `starting_chain[]` = the ordered list of node ids that realises the D14 chain end-to-end — this array, together with `edges.json`, is what L0-5 checks for a connected directed path; every id in it must exist in `nodes.json` and consecutive ids must be connected by a directed edge (or a directed path through other chain-adjacent nodes) in `edges.json`. `files[]` = exactly six entries (`regions.json`, `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json` — `manifest.json` is never self-listed, matching the schema's `name` enum and `contracts/examples/manifest.json`), each with `asset_version` (kebab-case, e.g. `nodes-v0`) and `sha256` (64 lowercase hex chars — task-plan note [2] establishes that `core-cli validate` does not verify these hashes at this stage; a syntactically valid but not-yet-recomputed placeholder value, e.g. all zeros matching the schema pattern, satisfies the schema and L0; do not attempt to compute a real SHA-256 by hand — that is out of scope and belongs to the pipeline's `hashlib` helper per task-plan note [2]).

5. **Author `edges.json`.** `from`/`to` name existing node ids. `sources[]` — at least one entry per edge, `tag` one of `ministry_prereq` | `textbook_order` | `third_party_structure` | `model_generated` with a non-empty `origin` (e.g. `"MCR3U-2007"` for a Ministry-sourced edge, or a textbook/curriculum name). `generation_agreement` — a non-negative integer (e.g. `1` for a hand-written edge — this is Demo data, not a multi-generation-run pipeline output; a small honest number, not a fabricated large one). `confidence` in `[0,1]` (a hand-authored edge asserted from the Ministry prerequisite chart can carry a high confidence, e.g. `0.9`–`1.0`; a side-dependency the implementer infers can carry a lower value). `probe_stats` — `{probes: 0, confirmed: 0}` (the Demo has run no probes yet; `downstream_fail_given_upstream_fail` is optional, omit it). Edges must realise the D14 chain (consecutive stage nodes connected, in dependency direction, satisfying L0-5 via `manifest.starting_chain`) plus "a few sensible side dependencies" (`DEMO-BRIEF.md` §3.2) among the 18–24 nodes. No cycle (L0-1). No edge may violate L0-2 (course depth ordering) — since both courses are MTH1W/MCR3U grade 9–12 with `depth` values you assign in step 3, keep edges consistent with your own depth assignment.

6. **Author `courses.json`.** Exactly two courses, `MTH1W` and `MCR3U`. For each: `course_code`, `name` (the Ministry course name, a fact — freely stored per content-policy `## Grade 9–12 tier`), `vintage` matching `^[0-9]{4}(\+[0-9]{4})?$` (e.g. `"2007"` or `"2005+2007"` — Ontario's course codes as revised), `strands[]` (≥ 1, `{code, name}` — the Ministry's own strand codes/names, facts, freely stored), `expectations[]` (≥ 1 — **this is the critical L0-8/L0-3a constraint, spelled out in step 6a below**), `units[]` (≥ 3, hand-written per open question 2's default, `{unit_id, name, expectation_codes[]}` — `unit_id` matches `^[A-Z]{3}[1-4][A-Z]\.u[1-9][0-9]*$`, e.g. `MTH1W.u1`, in unit order), `unit_source: {title: "Demo hand-written unit list", edition: "0.0.0"}` (per EPIC §9 open question 2's recorded default — quote this exact `title` string), `next_courses` — `MTH1W: ["MPM2D"]`, `MCR3U: ["MHF4U"]` (brief §4.8 / EPIC §4 criterion 8).

   **`MPM2D` and `MHF4U` are NOT authored as `Course` entries in this bundle, and this is correct** (amendment 01.05.2, settled — no longer a Q4). Exactly two courses ship. Succession is Ministry-chart data, not a residency claim (`AMENDMENT-v2.7.md:25`, D47: "data in the spine … not logic"); `contracts/schemas/courses.schema.json:142-145` constrains a `next_courses[]` entry to the course-code pattern only; `contracts/examples/courses.json:36-38,68-70` ships exactly this shape; and expedition W8 (`docs/domains/expedition.md:112-114`) reads "the first `next_courses[]` entry whose nodes exist", presupposing entries whose nodes are absent. Corrected L0-9 (task 02b, this task's dependency) reports no violation for them. Two further reasons never to author stubs: `courses.schema.json` requires `strands`, `expectations` and `units` at `minItems: 1` with each unit's `expectation_codes` at `minItems: 1`, so a zero-unit stub is not schema-expressible at all; and L0-3a would then require ≥ 1 node carrying each stub's expectation code, turning the Demo into a four-course bundle and contradicting `AMENDMENT-v2.6.md` §3.1's two-trail tester flow. If `core-cli validate data/demo` nonetheless reports an L0-9 violation naming `MPM2D` or `MHF4U`, task 02b has not landed — that is a blocking dependency gap to report, never a reason to blank `next_courses` to `[]` or to invent a stub course.

6a. **The L0-8/L0-3a coverage constraint (the one most likely to be got wrong).** `courses.json`'s `expectations[]` for each course MUST be EXACTLY the set of expectation codes that `nodes.json`'s nodes actually carry in their `expectation_codes[]` for that `course_code` — no more, no fewer. Concretely:
   - Every `{course_code, code}` pair present in any node's `expectation_codes[]` MUST appear as one `expectations[]` entry in that course, with a matching `code`.
   - Every `expectations[]` entry MUST be placed in exactly one `units[].expectation_codes[]` (L0-8: "every expectation is in exactly one unit, no unit is empty").
   - Do NOT add extra `expectations[]` entries that no node references — L0-3a requires every code the graph claims to map to ≥ 1 node; an expectation with no node satisfies neither side of a real "both-ways coverage" check honestly and risks the report failing or (worse) passing vacuously on an uninspected code. Author `nodes.json`'s `expectation_codes[]` and `courses.json`'s `expectations[]`/`units[]` together, from the same list, not independently.
   - Each `expectations[]` entry additionally needs `kind` (`overall` | `specific`), `paraphrase` (≤ 140 chars, project's own words), `official_url` matching `^https://(dcp\.edu\.gov\.on\.ca|www\.edu\.gov\.on\.ca|edu\.gov\.on\.ca)/` (the schema's actual pattern — note this is WIDER than `content-policy.md`'s prose, which names only `dcp.edu.gov.on.ca` and `edu.gov.on.ca`; per §6 decision-default below, use only those two hosts so both the schema and the content-policy prose are satisfied), `unit_id` (naming the unit this expectation sits in, consistent with `units[]`).

7. **Author `landmarks.json`.** Exactly one landmark. `id` kebab-case (e.g. `canadian-mortgage-compounding`). `name`, `what_it_is` (one plain-language paragraph, project's own words). `source_url`: `https://laws-lois.justice.gc.ca/eng/acts/I-15/` (matches pattern `^https://`). `node_ids[]` — ≥ 2 node ids from `nodes.json`, in different `region_id`s (e.g. one `number-operations` node, one `functions` node — per `DEMO-BRIEF.md` §3.7's suggested linking of `exponent-laws` and `exponential-functions`, or the equivalent ids chosen in step 3). `region_ids[]` — the distinct regions those nodes sit in (subset of the 10-region non-horizon enum — note this schema's `region_ids` enum has NO `shore`/horizon entries, matching the nodes populated regions). `position` — a `{x,y}` in `[0,1]`, placed sensibly near the linked nodes. This task does NOT verify `source_url` resolution (HTTP 2xx) — that is task 01.7's job; this task only ensures the field is present, well-formed, and factually the Interest Act URL from `DEMO-BRIEF.md` §3.7 / the EPIC brief.

8. **`position` — decide the ordering explicitly.** `nodes.schema.json` requires `position` on every node (it is in the schema's `required[]` list) and `landmarks.schema.json` requires it too. L0-7 (`Every node has a `position` inside its region's polygon`) is normally satisfied by `core-cli layout` (task 01.3/01.4), and the EPIC brief's §4.3 has `core-cli layout data/demo` writing `position` for every node and being idempotent. Since `position` is schema-REQUIRED, this task MUST hand-write a syntactically valid `{x,y}` (in `[0,1]`) for every node and for the landmark so the file validates and decodes at all — but per §6 decision-default below, the implementer is NOT required to hand-place these positions so that they already satisfy L0-7's in-polygon geometric containment; running `core-cli layout data/demo` (task 01.4's CLI, invoked as part of getting the bundle to a fully L0-green state) is the authoritative step that overwrites every node's `position` with a layout-computed, in-polygon value, and this task's AC1 ("L0-green") is satisfied only after that step has been run — whether by this task's own implementer as the last authoring step, or as a follow-on invocation. State in the PR/commit which was done. If `core-cli layout` is not yet operative when this task executes (a task 01.4 gap), that is a blocking dependency, not something to work around with hand-computed polygon geometry.

9. **`sources.json`.** If no node in this Demo carries a `source_ref` (expected, since the Demo is entirely grade 9–12 per D14/DEMO-BRIEF §3.1), `sources.json` is `{"format_version": "0.0.0", "sources": []}` — the schema's `sources` array has no `minItems`, so empty is valid, and the file still must exist because `manifest.files[]` names it.

10. **Author the companion test** at `pipeline/tests/test_demo_bundle_shape.py` (§5's companion-test list). Its path is fixed by this spec.

11. Smoke check: from the repo root, `pytest pipeline/tests/test_contracts.py -k "data_bundles or verbatim"` — must be green before proceeding to the full gate.

## §5 Test plan (seam risk — full plan)

- T1 happy path: `core-cli validate data/demo` (through task 01.4's `core_cli("validate", …)` Python wrapper, exercised by a pipeline test added or already present per task 01.4) prints `passed: true` with all ten checks (`L0-1` … `L0-10`) present, each `passed: true`, each `violations: []` printed (not omitted). Asserted by parsing the stdout JSON in a test, not by eyeballing a manual run.
- T2 negative — invalid input rejected at the boundary: `pytest pipeline/tests/test_contracts.py::test_data_bundles_validate` fails loudly (non-green) if any of the seven files is malformed against its schema; this task's Done gate requires this specific test to be green, so any schema violation the implementer introduces surfaces here before merge.
- T3 error-taxonomy: no error code is thrown by this task's own work (it ships data, not code raising errors), but the implementer verifies via task 01.4's `core-cli validate` output that a DELIBERATE transient mistake (e.g. temporarily typo a `region_id`) produces `MAP_REGION_UNKNOWN` in the report before fixing it — a self-check the implementer runs once during authoring, not a shipped test artifact.
- T4 conformance per requirements §B.1 (EPIC §5): the implementer confirms, as part of finishing this task, that the following EPIC-level conformance points are true of the authored bundle (these are asserted by tests in tasks 01.1–01.4, already landed, run here as regression evidence, not re-written by this task): (a) `Core`'s decode round-trip test, extended in task 01.1 to include `data/demo/*.json` if that task's scope covers it, OR run manually via `CoreCoding.decoder`/`CoreCoding.encoder` against each of the seven files and confirmed JSON-equal on re-encode; (b) `MAP_REGION_UNKNOWN` / `MAP_LAYOUT_MISSING` fire correctly against this bundle's shape (already covered by task 01.2's negative-control fixtures — this task's bundle is a NEW positive instance of the same checker, not a new test); (c) I10 — every `probe_items[].type` is `numeric` or `mc`, asserted by a test scanning `data/demo/nodes.json`; (d) I15 — every landmark has `source_url`, schema-enforced and additionally scanned.
- T5 negative control for every regression guard: for AC2's distractor-tag guard, the implementer PROVES the guard is load-bearing by temporarily planting one `mc` choice with a missing/`none-of-these` `error_type_id` in a scratch copy of `nodes.json` and confirming the guard test reds, then reverting — this red/green pair is recorded in the PR description, not shipped as a permanent fixture (per RULE `docs/lessons.md` §22's guard-test discipline, adapted: since this task ships DATA not a hardcoded literal-scan guard, the "guard" is the schema/test combination in §4's step 3a plus the companion test asserting it over `data/demo/nodes.json` specifically).
- T6 idempotency / no-leak: `core-cli layout data/demo` (if run as part of step 8) is idempotent — running it twice yields byte-identical `nodes.json` (task 01.3's determinism guarantee, exercised here as a regression check over this specific bundle, not a new implementation).

**Companion test this task ships** (per "Companion tests belong to the task that ships the code"): add `pipeline/tests/test_demo_bundle_shape.py` — this exact path, fixed by this spec and not the implementer's choice (amendment 01.05.2), because `pipeline/tests/test_demo_bundle.py` is reserved for task 01.7 (`tasks/context/epic-01-task-07-context.md:123`) and `docs/plans/epic-01-task-plan.md:22-23` forbids two tasks owning one file for writes. Do not instead extend `test_contracts.py`. The test asserts, over `data/demo/` specifically and scoped to `data/demo/`'s own files (not a whole-repo scan, so a later task's `data/<other-bundle>/` cannot falsify it):
- node count `18 <= len(nodes) <= 24`;
- `manifest["starting_chain"]` is non-empty and every id in it exists in `nodes.json`;
- exactly two courses with `course_code` in `{"MTH1W", "MCR3U"}`, each with `len(units) >= 3`;
- `MTH1W`'s `next_courses == ["MPM2D"]` and `MCR3U`'s `next_courses == ["MHF4U"]` — asserted as literal values, and NOT cross-checked for residency in `courses.json`: a residency assertion here would re-enshrine the misreading task 02b removes;
- every node's `region_id` is in `{"number-operations", "algebra", "functions"}`;
- for every `mc` probe item, every `choices[]` entry whose `id` is not the item's `correct_choice_id` has a non-null `error_type_id`, and that `error_type_id` is a member of the owning node's OWN `error_types[].id` list (derive the allowlist from each node's own `error_types[]`, per the guard-test discipline in the task-writer's governing instructions — never a hand-maintained literal list) — and `error_type_id` is never the string `"none-of-these"`;
- exactly one landmark, `source_url == "https://laws-lois.justice.gc.ca/eng/acts/I-15/"`, `len(node_ids) >= 2`, and the `region_id`s of those nodes (looked up in `nodes.json`) contain ≥ 2 distinct values.

## §6 Decision defaults

- IF the implementer is unsure how many nodes to place per D14 chain stage THEN default to 1 node per named stage plus enough adjacent supporting nodes (e.g. integer/rational operations, scientific notation) to land in the 18–24 range, all confined to `number-operations`/`algebra`/`functions` (per `contracts/schemas/nodes.schema.json` `region_id` restricted enum quoted in §3, and `DEMO-BRIEF.md` §3.1/§3.2 quoted in the context bundle).
- IF `official_url` host choice is ambiguous (the schema pattern additionally allows `www.edu.gov.on.ca`, but `contracts/content-policy.md` § Grade 9–12 tier's prose names only `dcp.edu.gov.on.ca` and `edu.gov.on.ca`) THEN use only `edu.gov.on.ca` or `dcp.edu.gov.on.ca` hosts, never `www.edu.gov.on.ca`, so the bundle satisfies both the schema (which is the actual validation gate) and the narrower prose allow-list without relying on the wider pattern (conservative default; no contract change needed since the narrower choice is a subset of what the schema already permits).
- IF `position` cannot yet be run through `core-cli layout` (task 01.4 not fully operative at authoring time) THEN hand-write a placeholder `{x,y}` inside each node's region polygon by visual/arithmetic estimate so the schema and decode round-trip pass, and explicitly flag in the PR that L0-7's exact in-polygon check has not been layout-verified — do NOT claim AC1 ("L0-green") is met until `core-cli layout data/demo` has actually been run and re-validated (`contracts/graph-constraints.md` L0-7 quoted in §3; task-plan.md confirms `core-cli layout` is task 01.4's deliverable, a prerequisite dependency of this task).
- IF a course's `next_courses[]` target (`MPM2D`, `MHF4U`) does not exist as a `Course` entry in `courses.json` THEN that is the intended, correct shape — leave it as a bare string (§4 step 6, amendment 01.05.2). Never invent a stub `Course` for it (schema-inexpressible: `strands`/`expectations`/`units` are all `minItems: 1`), and never blank `next_courses` to `[]` to make a check pass (that contradicts EPIC §4 criterion 8 and hides the rule rather than satisfying it).
- IF the companion test's path seems to duplicate task 01.7's `pipeline/tests/test_demo_bundle.py` THEN keep them separate files: 01.5 ships `test_demo_bundle_shape.py` (bundle shape and counts), 01.7 ships `test_demo_bundle.py` (SymPy re-derivation, tag enum, live landmark resolution) — per `docs/plans/epic-01-task-plan.md:22-23`'s rule that no two tasks own the same file for writes.
- IF an `expectation_codes[]` entry's Ministry code is uncertain (the implementer is not a Ministry curriculum expert) THEN choose a plausible, well-formed code consistent with the course's strand structure (e.g. `B2.3` under a Number strand) and record it — L0-3a only checks referential consistency within THIS bundle (every code a node claims must be listed in `courses.json`'s `expectations[]`, and vice versa per §6a), not fidelity to the real 2007/2020 Ontario curriculum document; getting the exact real-world code right is EPIC 05+'s spine-extraction concern, out of scope here.
- IF the implementer is unsure whether `strand`, `explanation`, or `worked_examples[]` should be included on a node THEN omit them (RULE 2, Simplicity First) — they are optional in the schema and the EPIC brief does not require them.
- IF a course's `depth` values for L0-2 are ambiguous THEN assign `depth: 0` to every node whose `courses[]` entry names `MTH1W` and `depth: 1` to every node whose entry names `MCR3U` (consistent with MTH1W preceding MCR3U in Ontario's actual course succession, and sufficient to make every edge honor `min depth(from) ≤ max depth(to)` as long as edges run from earlier- to later-taught concepts); a node on both courses' trails may carry both `{course_code: "MTH1W", depth: 0}` and `{course_code: "MCR3U", depth: 1}` in its `courses[]` array.

Standing defaults: identifiers are stable, opaque, lowercase kebab-case slugs per `contracts/data-model.md` § Identifiers (quoted in §3); every JSON key is exactly the schema's snake_case property name (`CoreCoding.decoder`'s `.convertFromSnakeCase`, verified in §3); telemetry is not touched by this task (no telemetry field exists in any of the seven schemas); no identifying field is ever added — none of the seven schemas expose one, so simply not inventing new keys keeps I5 satisfied; nodes carry `paraphrase`, never verbatim Ministry text (I6, enforced by the repo-wide `verbatim`-key grep gate this task's bundle must pass).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`ruff check` / `ruff format --check` over `pipeline/`, covering the new companion test file; no Swift files are touched by this task so `swift-format lint --strict` is unaffected)
- typecheck clean (`pyright` strict over `pipeline/`, covering the new companion test file)
- `pytest pipeline/tests/test_contracts.py` green (schema validation, no `verbatim` key, identifier-blocklist tests unaffected since this task adds no `student-state`/`telemetry-batch` data)
- `pytest pipeline/tests/test_demo_bundle_shape.py` green, covering every bullet in §5's companion-test list
- `pipeline/tests/test_demo_bundle.py` does not exist in this task's diff (it is task 01.7's file)
- `core-cli validate data/demo`, run through task 01.4's pipeline wrapper, prints `passed: true` with all ten checks listed and their violation lists (possibly empty) printed
- `core-cli layout data/demo` has been run at least once against this bundle and re-running it is byte-identical (T6)
- every one of the seven files decodes into its `Core` type via `CoreCoding.decoder` and re-encodes JSON-equal via `CoreCoding.encoder`
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1

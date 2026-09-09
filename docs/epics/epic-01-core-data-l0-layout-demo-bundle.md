# EPIC 01: Core data + L0 + layout + demo bundle + rendering spike

> Status: brief authored 2026-09-09 by the owner's planning session (Fable, Phase 7a). Owner decides dispatch; planner decomposes.

## 1. EPIC id, title, category
EPIC 01 — Core data + L0 + layout + demo bundle + rendering spike. Category: Foundation.

## 2. Goal & scope
Give the product its data spine: `Core` can decode every bundle file of `contracts/data-model.md`, validate a
bundle against every L0 rule of `contracts/graph-constraints.md`, and lay nodes out deterministically inside
their regions; the pipeline can invoke both through `core-cli`; and the Demo's hand-written bundle exists,
passes L0, and every piece of math in it is known to render. In scope: concept-graph W1 (L0 checker, in
`Core`, `core-cli validate`) and the layout function (`core-cli layout`, region-constrained force layout
seeded by `layout_hint`, deterministic across runs — `map.md` Core entities, D33); `Core` `Codable` types
for `manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources` and `StudentState`; the
`data/demo/` bundle per `DEMO-BRIEF.md` §3.1–§3.3, §3.7, §5 as amended (v2.6 §D: ten region outlines + four
horizon labels, nodes only in Number / Algebra / Functions, ~20 nodes along the D14 chain with 2–3 items
each and distractor tags, MTH1W and MCR3U courses with hand-written unit lists and `next_courses`, one
landmark — the Canadian mortgage semi-annual compounding, source `laws-lois.justice.gc.ca/eng/acts/I-15/`
— verified to resolve); the **rendering spike** (v2.2 §B): `Rendering.RenderCheck` over every
`prompt_latex`, hint, explanation and choice in the bundle, failures listed, each resolved by rewriting the
notation or setting `render_fallback: "katex"`, outcome recorded. The pipeline gains one thin wrapper per
`core-cli` subcommand and a test that runs both over `data/demo`.

**MANDATORY placement line:** milestone **Demo**; layers **① spine data shapes, ② concept graph, ③ learning
objects (static shapes + validation)**; layout is the ②→④ map projection.

## 3. Contracts it must conform to
- `contracts/data-model.md` — every section; the JSON Schemas in `contracts/schemas/` are normative. `READ-ONLY`. The `Core` decode round-trip over `contracts/examples/` is the *EPIC-time* rung this EPIC wires.
- `contracts/graph-constraints.md` — L0-1 … L0-10 and the report shape. `READ-ONLY`. L0-T (trail segments) is EPIC 02's.
- `contracts/content-policy.md` — § Landmarks, § Generated content (distractor tags), § Documentation claims. `READ-ONLY`.
- `contracts/error-codes.md` + `error-codes.json` — `GRAPH_L0_FAILED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED`, `SPINE_UNIT_EMPTY`, `SPINE_SOURCE_REF_UNRESOLVED`, `LO_ITEM_UNRENDERABLE`, `LO_BAD_DISTRACTOR_TAG`. `READ-ONLY`. `CoreError` mirrors these (registry ⊇ enum test).
- `contracts/domain-glossary.md` — names for every type. `READ-ONLY`.
- `contracts/ai-usage.md` — no model anywhere in this EPIC. `READ-ONLY`.

**MANDATORY (R-6) brief-checklist line:** config/registry-bearing modules in scope: the error registry
(`error-codes.json` — `CoreError` must fail its build-time test if a case is off-registry: covered by the
registry round-trip, `READ-ONLY`); the bundle manifest (`PLATFORM_BUNDLE_INTEGRITY_FAILED` on a partial or
hash-mismatched manifest — registered, `READ-ONLY`; exercised by `core-cli validate` refusing a bundle whose
manifest names a missing file); the region vocabulary (`MAP_REGION_UNKNOWN`, registered, `READ-ONLY`). No
BUMP needed.

**MANDATORY invariant line:** I8 — L0 lives in `Core` and is the only acceptance path; the pipeline wrapper
refuses to emit a bundle whose report has `passed: false` (test). I14 — `Core` gains no import beyond
Foundation (existing boundary test); layout is a pure function with an injected seeded RNG (determinism
test: two runs, byte-equal positions). I6 — the demo bundle's paraphrases are the project's own words; the
`verbatim` grep and the 140-char schema bound apply; no Ministry prose is pasted (the author of the bundle
writes from the codes, not from the document). I15 — the landmark's `source_url` is fetched by the pipeline
test (HTTP 2xx, page text contains "Interest Act"); on failure the landmark is dropped, never edited into
truth. I9 — no review step: the bundle is hand-written *data* (D26 allows it for the Demo), validated by
machine; a failing item is rewritten, not approved. I1 / I10 — every item is `numeric` or `mc` with a
checked `answer`/`correct_choice_id`; the pipeline re-derives every numeric answer with SymPy where the
prompt is expressible (a test lists the items it could not express, empty = FAIL for this bundle since all
are simple). I11 — the rendering-spike outcome and the L0 report carry no untagged numbers.

**MANDATORY artifact line (P4/C4):** `core-cli` (`validate`, `layout`, `version`) — exercised by
`pipeline/tests` over `data/demo` and `contracts/examples`; `data/demo/*.json` — the bundle files only, each
named by its schema (`manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), exercised
by `test_contracts.py` (schemas) and `core-cli validate`. The **L0 report is not a bundle file and is not
committed**: it is `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md`
§ Report shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing
other than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` §
Enforcement: every `*.json` under `data/**` validates against the schema its filename names).
`Rendering.RenderCheck` — exercised by the spike test over the bundle and by `RenderingTests`; the `Core`
`Codable` types — exercised by the decode round-trip test.

## 4. Acceptance criteria
1. `core-cli validate data/demo` prints a report with `passed: true` and every check listed, empty
   violation lists included (C3).
2. Mutating the demo bundle to introduce a cycle, a node with two regions, a node with neither codes nor
   `source_ref`, an empty unit, and a landmark without `source_url` each yields the named rule id / code in
   the report (negative controls, C2).
3. `core-cli layout data/demo` writes `position` for every node inside its region polygon; running it twice
   yields byte-identical `nodes.json`.
4. Every file in `contracts/examples/` and `data/demo/` decodes into the `Core` types and re-encodes to a
   JSON-equal document.
5. The pipeline's `core_cli("validate", …)` and `core_cli("layout", …)` wrappers are covered by a test that
   runs them over `data/demo` (C1 seam: pipeline↔`core-cli`).
6. The rendering spike reports zero unresolved items: every LaTeX string in `data/demo` parses in SwiftMath
   or carries `render_fallback`; the outcome file lists what was rewritten.
7. The landmark's `source_url` resolves (2xx) and the fetched text contains the landmark's name (I15).
8. The bundle contains ≥ 18 and ≤ 24 nodes, all on or adjacent to the D14 chain, with `starting_chain` in
   the manifest connected (L0-5), two courses with ≥ 3 units each, `next_courses` MTH1W → MPM2D and MCR3U
   → MHF4U, and every `mc` distractor tagged.
9. `scripts/gate.sh` is green with the new tests included.

## 5. Conformance tests it must ship (B.1)
- concept-graph: I7/I8 mechanisms — one node set, one edge set; L0 as build test and at load (the load half
  is EPIC 03's, but the function and its tests are here); I14 — `Core` boundary test extended to the new
  files.
- map: I8 region/coordinates refusal (`MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`); layout determinism.
- learning-objects: schema-level I10 (item types), I15 (landmark `source_url`), distractor tags present and
  on-enum (`LO_BAD_DISTRACTOR_TAG`), renderability (`LO_ITEM_UNRENDERABLE` via `RenderCheck`).
- curriculum-spine: L0-8 unit coverage and L0-9 succession on the demo courses.
- contracts: decode round-trip (data-model EPIC-time rung); `CoreError` ⊆ registry (error-codes rung).

## 6. Dependencies on prior EPICs
none — this is first. It consumes only Phase 5/6 outputs (`Packages/Core` scaffold, `Packages/Rendering`
scaffold, `contracts/schemas`, `pipeline/`).

## 7. Out of scope
1. Student state transitions, fringe, scheduler, trail generation, diagnosis machine — EPIC 02.
2. Any rendering of the map or screens — EPIC 03/04. `Rendering` ships only `RenderCheck` here; `MathView`
   is EPIC 03's.
3. Pipeline generation of content (Claude API), spine extraction — EPICs 05–09; the Demo bundle is hand-written by design (D26).
4. Hosting, sync, telemetry — EPICs 10–11 (D36; telemetry off in the Demo, DEMO-BRIEF §2).
5. Shore region (DEFERRED D-10), ideas layer (D-9), extra syllabi (D-11).
6. Nodes outside Number / Algebra / Functions (DEMO-BRIEF §3.1); the other seven regions are outlines only.

## 8. Size estimate
Within the cap at 7 tasks: (1) `Core` types + decode round-trip; (2) L0 validate + report + negative
controls; (3) layout + determinism; (4) `core-cli` subcommands + pipeline wrappers + seam test; (5) demo
bundle authoring (regions/courses/units/nodes/edges/landmark) + L0 green; (6) rendering spike + fixes +
outcome record; (7) SymPy answer re-derivation test + landmark resolution test. Seams if a split is
needed: after task 4 (Core/CLI) vs tasks 5–7 (bundle + spike).

## 9. Open questions
- Layout algorithm details (repulsion/attraction constants, iteration count, polygon containment method) —
  **default:** a simple Fruchterman–Reingold-style loop with a fixed iteration count [ESTIMATE: 300] and
  point-in-polygon clamping each step, seeded RNG from a fixed constant; any constants live in one
  `LayoutConfig`. Revisit at M2 when the real graph exists (a few hundred nodes).
- Unit lists for MTH1W and MCR3U — **default:** hand-written by the implementer from the Ministry strand
  structure in unit order (3–5 units per course), recorded in the bundle's `unit_source` as "Demo
  hand-written unit list" (v2.7 §2 says the Demo's lists stand). Revisit at M1 (EPIC 07).
- none otherwise — all decisions taken from the project brief, domains, and contracts.

## 10. Change log
| Date | Author | Change |
|------|--------|--------|
| 2026-09-09 | owner planning session (Fable) | Initial brief. |
| 2026-09-09 | brief-amender (Q4 from EPIC 01 planning) | §3 artifact line: the L0 report is `core-cli validate` stdout, not a committed `data/demo/l0-report.json`; `data/**` holds schema-named bundle files only. Source: `contracts/graph-constraints.md` § Report shape, `contracts/data-model.md` § Enforcement. |

## Amendment log

### Amendment 01.05.1 — 2026-09-09

**Trigger**: tier-6 brief-amender, invoked after a Q4 escalation raised in EPIC 01 planning, ahead of task 01.5 dispatch.
**Architect escalation**: none on disk — the conflict was raised and verified by the orchestrating planning session (no `tasks/blocked/architect-escalation-01-05.md` was written).
**Original brief text**:
> **MANDATORY artifact line (P4/C4):** `core-cli` (`validate`, `layout`, `version`) — exercised by
> `pipeline/tests` over `data/demo` and `contracts/examples`; `data/demo/*.json` + `data/demo/l0-report.json`
> — exercised by `test_contracts.py` (schemas) and `core-cli validate`; `Rendering.RenderCheck` — exercised by
> the spike test over the bundle and by `RenderingTests`; the `Core` `Codable` types — exercised by the
> decode round-trip test.

**Amended brief text**:
> **MANDATORY artifact line (P4/C4):** `core-cli` (`validate`, `layout`, `version`) — exercised by
> `pipeline/tests` over `data/demo` and `contracts/examples`; `data/demo/*.json` — the bundle files only, each
> named by its schema (`manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), exercised
> by `test_contracts.py` (schemas) and `core-cli validate`. The **L0 report is not a bundle file and is not
> committed**: it is `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md`
> § Report shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing
> other than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` §
> Enforcement: every `*.json` under `data/**` validates against the schema its filename names).
> `Rendering.RenderCheck` — exercised by the spike test over the bundle and by `RenderingTests`; the `Core`
> `Codable` types — exercised by the decode round-trip test.

**Source**: `contracts/graph-constraints.md` § *Report shape* — "**Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [...], indegree: {...} }`"; `contracts/data-model.md` § *Enforcement* — "every `*.json` under `data/**` validates against the schema its filename names"; `contracts/README.md` § *The set* (data-model row) — schemas are "per bundle file". `contracts/schemas/` defines no `l0-report` schema, so a committed `data/demo/l0-report.json` would fail `pipeline/tests/test_contracts.py::test_data_bundles_validate`.
**Effect on deliverables**: NONE (specificity added). The L0 report is still produced, still shaped by the contract, still the acceptance path for the bundle and still parsed by the pipeline wrapper (I8); only its location is pinned — stdout rather than a committed file. No new directory convention is introduced.
**Effect on owner-facing acceptance**: NONE. Acceptance criteria 1 and 2 already read "prints a report" / "in the report" and are unchanged in wording and substance; §5 is unchanged.

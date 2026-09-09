# EPIC 01 — task plan

Source brief: [`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md`](../epics/epic-01-core-data-l0-layout-demo-bundle.md).
Produced by the `planner` agent, Phase 7 A2, 2026-09-09. Size verdict: the brief's §8 count of **7 tasks**
is confirmed, and the seam it names (after task 4: `Core`/CLI vs bundle + spike) is confirmed as the
dependency waist. No EPIC split: the second half is unusable without the first.

## Task list

| id | spec id | goal | depends on |
|----|---------|------|-----------|
| 01.1 | `epic-01-task-01-core-bundle-types` | `Core` `Codable` types for every bundle file + `StudentState` + `CoreError` + bundle-directory I/O; decode round-trip over `contracts/examples/`. | — |
| 01.2 | `epic-01-task-02-l0-checker` | L0-1 … L0-10 in `Core` as one pure `validate(bundle)` returning the contract report shape, with manifest-completeness refusal and negative-control fixtures. | 01.1 |
| 01.3 | `epic-01-task-03-region-constrained-layout` | Deterministic region-constrained force layout in `Core`: pure function, injected seeded RNG, one `LayoutConfig`, point-in-polygon clamping. | 01.1 |
| 01.4 | `epic-01-task-04-core-cli-and-pipeline-seam` | `core-cli validate\|layout\|version` + one thin Python wrapper per subcommand + the C1 real-composition seam test. | 01.2, 01.3 |
| 01.5 | `epic-01-task-05-demo-bundle` | Author `data/demo/` (ten region outlines + four horizon labels, ~20 D14-chain nodes, edges, MTH1W/MCR3U, the mortgage landmark) and get it L0-green. | 01.4 |
| 01.6 | `epic-01-task-06-rendering-spike` | `Rendering.RenderCheck` over every LaTeX string in `data/demo`; each failure rewritten or given `render_fallback`; outcome recorded. | 01.5 |
| 01.7 | `epic-01-task-07-pipeline-content-verification` | SymPy re-derivation of every numeric answer, distractor tags on-enum, landmark `source_url` resolution. | 01.5, 01.6 |
| 01.8 | `epic-01-task-08-epic-wrap` | Wrap-gates, artifact ledger, contract-rung ledger, acceptance report. | 01.1 … 01.7 |

File scope, conformance targets and per-task acceptance criteria (each traced to the brief's §4/§5
numbers) are carried into each task spec under `tasks/`. The rule the plan enforces: **no two tasks own the
same file for writes**, with one deliberate exception, note [3].

## Planner notes carried forward

1. **Q4 raised and RESOLVED — `l0-report.json` path.** The brief's §3 artifact line named
   `data/demo/l0-report.json`, but `contracts/data-model.md` §Enforcement (wired in
   `pipeline/tests/test_contracts.py::test_data_bundles_validate`) requires every `*.json` under `data/**` to
   validate against the schema its filename names, and there is no `l0-report.schema.json`. Routed to
   `brief-amender`, resolved as Q1 (amendable from existing ground truth, no owner decision):
   `contracts/graph-constraints.md` §Report shape already defines the report as **`core-cli validate`
   stdout**, not a bundle file. The brief was amended in place (amendment 01.05.1). **The L0 report is never
   written to disk and never committed**: `core-cli validate data/demo` prints it as JSON on stdout, the
   pipeline wrapper parses it in-process and fails the build on `passed: false`. `data/demo/` holds exactly
   the seven schema-named bundle files. The planner's `reports/demo/l0-report.json` recommendation is
   REJECTED — it invents a directory convention no contract names. Task 01.5's file scope drops that path.
   The same rule forecloses the drift elsewhere: the rendering-spike outcome record of 01.6 lives at
   `docs/epics/epic-01-rendering-spike-outcome.md`, outside `data/**`.
2. **Manifest `sha256`.** `core-cli validate` cannot verify SHA-256 without importing CryptoKit into `Core`
   (breaks D33/I14) or hand-rolling it (breaks RULE 2). Default adopted: `core-cli validate` enforces manifest
   *completeness and file presence* (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, exactly what the brief's R-6 line
   requires); hash *computation* is a Python `hashlib` helper in the pipeline; hash *verification at load*
   defers to EPIC 03's App-side loader. Record the deferral in `docs/DEFERRED.md` at wrap.
3. **Shared-file ordering.** `data/demo/nodes.json` is written by 01.5, then amended by 01.6 (notation /
   `render_fallback`) and 01.7 (answer or tag corrections). These three are strictly sequential and must never
   be dispatched concurrently. This is the plan's only shared-write path.
4. **Scope redistribution vs §8.** `Core`'s `validate` stays exactly L0-1 … L0-10 — no LO-prefixed checks are
   bolted into the L0 report. Renderability (`LO_ITEM_UNRENDERABLE`) goes to 01.6 (`Rendering`); distractor
   tags, SymPy re-derivation and landmark resolution go to 01.7 (pipeline), per `docs/tech-stack.md` §2
   ownership.
5. **`CoreError` membership.** `contracts/error-codes.md` §Rules names the GRAPH/EXP/MAP/DIAG prefixes, but
   L0-8 fails with `SPINE_UNIT_EMPTY` and manifest refusal uses `PLATFORM_BUNDLE_INTEGRITY_FAILED`. The
   enforced rule is `CoreError` ⊆ registry, which both satisfy; 01.1 includes the SPINE/PLATFORM cases it
   actually raises.
6. **Network in CI.** 01.7's landmark fetch makes a live HTTPS request inside `pytest`, which gate 4 and CI
   both run. The spec marks it `@pytest.mark.network`, runs it in the gate, and treats a network failure as a
   genuine blocking signal (I15). No mock may make the assertion vacuous.
7. **Size flag.** 01.1 is the largest single-implementer task and is kept whole because it defines the
   interface every other task consumes. If the implementer reports overrun, the only sanctioned split line is
   01.1a (bundle types + `BundleIO` + round-trip) / 01.1b (`StudentState` + `CoreError` + registry test).
8. **Shell-then-fill watch.** `StudentState` lands with no consumer until EPIC 02, so its guard tests ship in
   01.1: the round-trip over `contracts/examples/student-state.json` plus an assertion that the type exposes
   no identifying field (I5).
9. **Real-composition seams (C1).** pipeline ↔ `core-cli` (D42) is owned by 01.4, both sides real. The
   `Core` ↔ render-layer seam is not crossed here and is asserted negatively by the recursive import test in
   01.1. The bundle-loader ↔ `Core` validation seam is EPIC 03's and must not be pulled forward.
10. **No model path.** No task in EPIC 01 calls a model (`contracts/ai-usage.md`); 01.7 states the absence as
    an acceptance line so it cannot drift.

## Wrap-gate ledger items raised during spec review

Two checks that a reader might expect `Core`/L0 to perform are enforced by a **different layer**. Task 01.8
must name them in the artifact ledger as such, so neither is later mistaken for an L0 responsibility or
re-implemented in `Core` (RULE 2).

- `manifest.files[].name` is a closed 6-value enum in `contracts/schemas/manifest.schema.json`. `Core` models
  it as `String` and no L0-1 … L0-10 rule covers manifest filenames. **Enforced by** pipeline JSON-Schema
  validation (`contracts/data-model.md` § Enforcement, wired in
  `pipeline/tests/test_contracts.py::test_data_bundles_validate`).
- `landmarks.json` `region_ids` is the narrower 10-value **non-horizon** enum, while `Core`'s `RegionId`
  is the 15-case superset. L0-10 checks `node_ids[]` referential integrity and `source_url` presence only —
  it does not check a landmark's regions against the horizon set. **Enforced by** the same pipeline schema
  validation: a landmark tagged to a horizon region fails `test_data_bundles_validate` on `data/demo`.
  Verified against `contracts/schemas/landmarks.schema.json` and `pipeline/tests/test_contracts.py` by the
  orchestrating session, 2026-09-09 — no contract gap, no Q5, no new L0 rule.

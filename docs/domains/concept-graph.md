# Domain — concept-graph

## Purpose

The core asset: one cross-grade prerequisite graph with per-edge sources, confidence and probe statistics
(§5). It answers the defining question — given a node the student just failed, which upstream node is the
deepest unmastered prerequisite? A course is a node subset plus a depth marker (I7, D3), drawn as a trail over the map (D20). The graph
also carries the map projection: each node's `region` (D21) and its precomputed coordinates; the L0
checker lives in `Core` and the pipeline invokes it through the `Core` CLI (D33, D42). Milestones **M1**
(schema + L0 checker), **M2** (starting-chain graph v0, region assignment), **M5** (coverage).

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Owner | Run the L0 checker, read its report, accept or reject a bundle | Hand-author or approve edges (I9, D13) |
| System | Read the bundle, run the query, update Confidence | Create nodes or edges; judge a step (I1) |
| Generation model | Propose nodes and edges offline via `content-generation` | Write into an accepted bundle; bypass L0/L1 |

## Core entities

**Node** — `id`, `name`, `strand`, `expectation_codes[]` (owned by `curriculum-spine`), `courses[]` each
with a `depth` marker, `region` (exactly one, D21, I8), `position` (written by the layout build step, D33;
an optional `layout_hint` seeds it), and per-node content owned by `learning-objects` (ErrorType, HintTree, ProbeItem),
referenced by id. **Edge** — "A is prerequisite of B": `from`, `to`, `sources[]`, `generation_agreement`,
`confidence`, `probe_stats` (§5); directed, and the set is acyclic (I8).

**Source tag** — an entry in `sources[]`: `ministry_prereq | textbook_order | third_party_structure |
model_generated`. The L1 rule is fixed by the brief: an edge with **≥ 2 independent sources is accepted**
(§6). Independence is by tag *and* origin: chapter orders from one publisher count once, as does
`model_generated` however many runs agreed.

**Confidence** — a 0–1 scalar per Edge, from `sources[]` plus `generation_agreement`, updated from
**ProbeStats** `{ probes, confirmed, downstream_fail_given_upstream_fail }` as L3 data arrives. Disputed
edges ship low-confidence rather than dropped, settled by probe data (D13, I9). Inputs are per-batch-capped
by telemetry (one observation per edge per batch).

**Graph bundle** — the immutable artifact: nodes, edges, the `spine_version` validated against, and the
passing **L0 report** listing every violation and in-degree outlier. Referenced: **Spine bundle**
(curriculum-spine); **HintTree**, **ProbeItem**, **ErrorType** (learning-objects); **Diagnosis**,
**ProbeRun** (diagnosis); **Region**, **Trail** (map); **Landmark** (learning-objects);
**IntersectionResult** (content-generation); **ContentBundle** (platform).

## Workflows

### W1 — Run the L0 checker

**Pre:** a candidate node/edge set and the Spine bundle it targets.
**Steps:**
1. (Tier 0, `Core` CLI invoked by the pipeline — D42) Load both; stop on a `spine_version` mismatch.
2. (Tier 0) Check the §5 constraints: acyclic; no later→earlier course edge (via `courses[].depth`);
   every code maps to ≥ 1 Node and every Node to ≥ 1 code; in-degree outliers flagged; the D14 starting
   chain connected end-to-end; every node has exactly one region; every trail is a path in the graph
   (v2 §5). The same function runs again at load on the device (platform W1).
3. (Tier 0) Emit the L0 report — pass/fail per check, violating ids, and the in-degree distribution the
   Owner uses to set the threshold empirically at M2 (§11); default the 95th percentile [ESTIMATE: flags a
   handful of nodes], advisory only.

**Post:** the report is persisted; a graph failing any check is never accepted (I8). Emits
`graph.l0_completed`.

### W2 — Tag sources and accept edges (L1)

**Pre:** an L0-passing candidate with an `IntersectionResult` (content-generation).
**Steps:**
1. (Tier 0) Attach each Source tag with its origin id, collapsing same-origin duplicates.
2. (Tier 0) Accept edges with ≥ 2 independent sources; mark the rest **disputed** — kept, not deleted (D13).
3. (Tier 0) Initialise Confidence (Q1), zero `probe_stats`, emit the disputed-edge list (M2 deliverable),
   and freeze the bundle with its `spine_version` and report.

**Post:** every edge has sources, a marker and an initial confidence. Emits `graph.bundle_published`.

### W3 — Query the deepest unmastered prerequisite

**Pre:** a Node id (from the Diagnosis in `diagnosis`) and that student's local mastery state
(`StudentState`, expedition).
**Steps:**
1. (Tier 0) Read the Node's incoming edges; no model runs here, the query is deterministic (I2).
2. (Tier 0) Filter to unmastered prerequisites; with no prior data a node is **unknown**, and unknown is a
   candidate (Q2) — the probe, not the graph, decides.
3. (Tier 0) Walk upward breadth-first, **at most 2 levels** (I4, D4), returning the deepest unmastered
   candidate, ties broken per Q3. If none is found, return "none within reach"; deeper gaps are marked
   `blocked` on the map only (D4, v2.5 §3).

**Post:** one candidate Node (or none) with its edge confidence, ready to be presented as a hypothesis and
probed. The walk terminates: acyclic graph, hard cap. Emits `graph.prerequisite_returned`.


### W4 — Update confidence from probe data (L3)

**Pre:** a completed ProbeRun (diagnosis) naming the edge behind the hypothesis.
**Steps:**
1. (Tier 0) Increment `probe_stats.probes`, and `confirmed` when the probe failed as predicted; maintain
   `downstream_fail_given_upstream_fail`.
2. (Tier 0) Recompute Confidence (Q1); edges below the disputed floor are re-marked disputed (Q4).
   Cross-student correction arrives only via `telemetry`, under consent (D17).

**Post:** confidence and statistics are persisted in the Store. Emits `graph.edge_confidence_updated`.

## UI surfaces

- **Node panel** (map W2) — node name, paraphrase, "what this builds on" (accepted edges), courses
  walking through it. The map itself is this domain's rendering (map W1).
- Owner's local L0 report and disputed-edge list — a written report from the `Core` CLI, not shipped.

## Notifications produced

- `graph.l0_completed` — `{ candidate_id, passed, violations[], indegree_outliers[] }`. Consumer:
  Owner (reads the L0 report; sets the in-degree threshold at M2).
- `graph.prerequisite_returned` — `{ node_id, candidate_id|null, levels_walked, edge_confidence }`.
  Consumer: `diagnosis`.
- `graph.bundle_published` — `{ graph_version, spine_version, node_count, edge_count, disputed_count }`.
  Consumers: `platform`, `learning-objects`, `map`.
- `graph.edge_confidence_updated` — `{ edge_id, confidence, probes }`. Consumer: the Owner's report
  (offline); nothing at runtime.

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `GRAPH_L0_FAILED` | Any §5 constraint fails: cycle, backward edge, coverage gap, broken chain, node without exactly one region, trail not a path | Internal; bundle refused | Yes — regenerate, never patch (I9) |
| `GRAPH_NO_PREREQUISITE` | W3 finds no unmastered candidate within 2 levels | "Nothing upstream to check." | Yes — normal |

## Invariants enforced here

- **I7 — primary owner.** One node set, one edge set; a course is a `courses[]` membership with a depth
  marker, so eleven separate syllabi are unrepresentable.
- **I8 — primary owner.** W1 runs all five checks; acceptance is gated on a passing L0 report, as a build
  test and again at load.
- **I4 — co-owner with diagnosis.** The 2-level cap is a parameter of W3, not of the caller.
- **I14** — W1 and W3 are pure functions in `Core`; the pipeline and the app call the same code (D42).
- **I9** — no approval state on an Edge; disputed edges ship, settled by probe data (D13). **I2** — every
  workflow here is Tier 0, so no model sits in the query path.

Seams: concept-graph ↔ `diagnosis` (W3 query; ProbeRun feeding W4); `content-generation` →
concept-graph (IntersectionResult must pass W1 and W2, invoked through the `Core` CLI); `curriculum-spine`
(coverage); `map` (regions, coordinates, trails as read-only projection); `telemetry` (statistics under
consent); `platform` (loading).

## Open questions

**Q1 — Shape of the confidence formula.** **Default:** a bounded additive prior — a fixed weight per
independent source tag plus a smaller one for `generation_agreement`, clamped to [ESTIMATE: 0.1, 0.9] — then a
Beta-style update from `probe_stats`. **Trade-off:** transparent, but the weights are arbitrary until L3
data exists.
**Ratified 2026-09-08:** default accepted.

**Q2 — What "unmastered" means with no prior data.** **Default:** unknown counts as a candidate, so a
fresh student can be probed on any prerequisite. **Trade-off:** diagnostic reach and early L3 data against
probing nodes the student already knows — bounded by the ~60 s probe.
**Ratified 2026-09-08:** default accepted.

**Q3 — Tie-breaking among equally deep prerequisites.** **Default:** highest edge confidence, then lowest
depth marker, then node id. **Trade-off:** deterministic and testable, but biases probing toward confident
edges, starving disputed ones.
**Ratified 2026-09-08:** default accepted.

**Q4 — How disputed edges surface in the product.** **Default:** invisible to Student and Parent — still
walked and probed, listed only in the Owner's report. **Trade-off:** keeps the product's voice confident
(§7) but gives no in-product signal that a weak edge drives wrong hypotheses.
**Ratified 2026-09-08:** default accepted.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). ProbeStats/Confidence inputs noted as per-batch-capped by telemetry (one observation per edge per batch). |
| 2026-09-09 | v2 re-cut: `region` and `position` on Node; two new L0 rules; L0 and the query live in `Core` and are invoked by the pipeline (D33, D42); consumers renamed (`diagnosis`, `map`); deeper gaps marked on the map (v2.5 §3); milestone M6 → M5. No open-question changes. |

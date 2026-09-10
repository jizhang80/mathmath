# Contract: Graph constraints — L0 (LOCK-FIRST)

**Contract version:** v1.1.0 · Source: brief v2 §5, I8 as amended (v2.7 §1), `concept-graph.md` W1, `expedition.md` W8; v1.1.0 rewrites L0-T's trail-segment definition — a course segment is ordered by unit then topological within unit (ties by node id), an edge against unit order is a warning not a failure, and every extension-segment node must be reachable from the segment before it (owner Q5 ruling 02-QE, 2026-09-10, `tasks/blocked/Q5-RULING-02-QE.md`)

> The structural rules every accepted bundle passes. Implemented **once**, in `Core` (`validate`), exposed by
> `core-cli validate <bundle-dir>` and run (a) by the pipeline build step — failing data is **not emitted**
> (D33) — and (b) at app load — a failing bundle is refused and the previous set stays (platform W1). Python
> never reimplements these (D42). Each rule has an id so reports, tests and specs cite the same thing.

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
| L0-T | **Trail segments** (generated at runtime, expedition W8, never over the bundle): a course segment is exactly that course's nodes resident in the bundle — a node's unit is the unit of its lowest-ordered expectation code of that course — ordered by unit order, then topologically by the edge set within each unit, ties broken by node id (ascending); an edge between two nodes of the same course segment that runs against unit order is listed as a warning in the trail generation's own report, never a failure; every node of an extension segment is reachable along directed edges from some node of the segment placed before it. | `EXP_TRAIL_INVALID` | same `Core` function family as L0-1…L0-10 conceptually, but runs at trail generation (expedition W8), never via `core-cli validate`; the warning list's concrete shape is fixed by the implementing task (02.5), not by this contract |

**Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed,
violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check
passed. Empty violation lists are printed, never omitted (C3).

**Query rules (also `Core`):** the deepest-unmastered-prerequisite query walks ≤ 2 levels breadth-first
(I4), treats `fog` as a candidate (concept-graph Q2), breaks ties by highest edge confidence, then lowest
depth marker, then node id (Q3). The fringe (D48) and the clear rule are in `interaction-contract.md`.

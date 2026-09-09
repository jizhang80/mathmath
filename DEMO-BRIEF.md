# Demo Brief — Map Form Test

Date: 2026-09-09
Parent: PROJECT-BRIEF-v2.md (D24, D26)
Status: scoped; ready for execution.

## 1. The one question this demo answers

**Does a grade 9–12 student, shown this map, want to click in — and after one expedition, want to do another?**

It does not test content correctness, graph validity, CAS verification, or local-model accuracy. Those belong to M1–M4′. Anything that serves a different question is out of scope here.

## 2. Hard constraints

- ⛔ No dependency on the curriculum spine, the concept-graph pipeline, Pyodide, MathLive, or the Prompt API. All data is hand-written JSON.
- ⛔ No game engine (D24). SVG + D3 + React + TypeScript. KaTeX for any math display.
- ⛔ Graph data, layout, and student state live in plain data structures and pure functions with no reference to rendering. The renderer consumes them; it does not own them.
- ⛔ No accounts, no network writes, no telemetry. State in memory (and optionally IndexedDB so a refresh does not lose it).
- ⛔ Runs in a desktop Chrome browser; must also be usable on a phone browser (touch pan/zoom, readable at ~380 px). Not required to be polished on phone.
- ⛔ Landmark content must be a real, named, verifiable thing with a source URL (D22). If a real one cannot be sourced, ship the demo without a landmark rather than invent one.

## 3. Scope

### 3.1 Map
- All eight regions from D21 drawn as hand-authored polygons with names: Number & Operations, Algebra, Functions, Geometry & Measurement, Trigonometry, Calculus, Probability & Statistics, Discrete.
- A horizon band beyond the continent with greyed labels only: e.g. Linear Algebra, Number Theory, Analysis. Not clickable.
- Only three regions are populated with nodes: Number & Operations, Algebra, Functions. The other five show as territory under fog with no nodes.
- Zoom and pan (D3). Region names visible at overview zoom; node names at closer zoom.

### 3.2 Nodes and edges (hand-written)
- ~20 nodes along the D14 starting chain, distributed across the three populated regions, e.g.:
  - Number & Operations: integer/rational operations, exponent laws, powers of ten / scientific notation
  - Algebra: linear relations, solving linear equations, polynomials, factoring, solving quadratics
  - Functions: function concept, transformations, quadratic functions, exponential functions, (logarithms may appear as a far, fogged node)
- Edges follow the chain and a few sensible side dependencies. Rendered as rivers flowing in dependency direction (from → to).
- Node placement: force layout constrained inside the region polygon, seeded from an optional `layout_hint`. Deterministic across reloads.
- Each node has a `paraphrase` (one plain-language sentence, the project's own words) and 2–3 probe items.

### 3.3 Trail
- One trail: MCR3U, as an ordered subset of the ~20 nodes. Drawn as a path over the map, visually distinct from rivers. A "you are here" marker on the trail's current node.

### 3.4 Fog and state
- All nodes start under fog. States: `fog` → `cleared` (via expedition) → `blocked` (when an item fails and an upstream node is implicated).
- Fog lifts per node; region tint changes with the fraction cleared.

### 3.5 Expedition (Door B)
- Button: "Start expedition". Selects ~5 items from nodes on the fog frontier (nodes whose prerequisites are cleared or which are chain roots). Simple scheduler: frontier first, then oldest `last_probe`.
- Items are numeric-answer or multiple-choice, checked deterministically in code. No CAS.
- Correct → node progresses toward `cleared` (2 correct probes clears it). Incorrect → Door A event (3.6).
- End screen: nodes cleared this run, fog lifted, "Start another" button. Session length target ≈ 3 minutes.

### 3.6 Diagnosis event (Door A, minimal)
- On a failed item: show a hypothesis card — "This may be blocked by **X**" where X is the node's nearest upstream neighbour (hand-specified in the data, not computed by inference).
- Probe X with 2 items.
  - Pass → "Not the issue." Show the original node's hint (hand-written, one level). Return to expedition.
  - Fail → mark X `blocked`, show X's paraphrase and one hint, then return.
- No further backtracking in the demo (cap = 1 level).

### 3.7 Landmark (one)
- One landmark placed on the map, linked to at least two nodes in different regions. Clickable: name, one-paragraph plain-language description, source URL, "which parts of the map this touches" with jump links.
- Suggested subject (must be verified and sourced before use, otherwise replace): Canadian mortgage interest — why fixed-rate mortgages in Canada compound semi-annually, and how that turns into a monthly rate. Links: exponent laws (Number), exponential functions (Functions), and the fogged logarithm node (solving for time). Any real, sourced landmark on the chain is acceptable.

### 3.8 Panels
- Node panel: name, paraphrase, state, "which courses walk through here" (from trail data), linked landmarks.
- Region panel: name, one sentence on what the territory is about, fraction cleared.

## 4. Out of scope for the demo

Parent view · homework/structured-input mode · CAS · any model · spaced-repetition beyond the simple scheduler · streaks/badges · animation beyond basic transitions · multiple trails · more than one landmark · accessibility polish · localisation.

## 5. Data files (hand-written)

- `regions.json` — id, name, polygon (normalised coordinates), horizon flag, neighbours
- `nodes.json` — id, name, region, paraphrase, layout_hint?, probe_items[] (`prompt`, `type` numeric|mc, `answer`, `choices?`), hint (one string), upstream_hint (node id for the diagnosis card)
- `edges.json` — from, to
- `trails.json` — course_code, node_ids[]
- `landmarks.json` — id, name, what_it_is, source_url, node_ids[], region_ids[], position

## 6. Architecture rule (enforced)

```
data/    → JSON files above
core/    → pure functions: load, validate (acyclic; nodes have one region; trail is a path),
           layout (region-constrained force), scheduler (frontier selection),
           state transitions (fog/cleared/blocked)
render/  → React + D3 + SVG; reads core outputs; emits user events to core
```

`render/` must not import from `data/` directly and must not compute state. A test asserts `core/` has no rendering imports.

## 7. Acceptance

Owner runs the demo with the two target-age testers. Record, per tester:

1. Did they click into the map before being told to?
2. Did they finish one expedition? Did they start a second unprompted?
3. Afterwards, can they say in their own words what a trail is?
4. Did the landmark make any node feel concrete (ask them to name which)?
5. When the diagnosis card appeared, did it read as help or as accusation?

No numeric pass threshold. The output of the demo is these five observations plus whatever the testers say unprompted. That record decides whether the map form proceeds to M3 or is revised.

## 8. Verification for the implementer

- `core/` validation passes on the shipped data; the L0 checks in §6 all pass.
- Layout is deterministic: same data → same positions across reloads.
- One full expedition and one diagnosis event can be completed by clicking, with no console errors.
- Landmark `source_url` resolves and supports the description.
- The demo loads and is operable on a phone browser (pan, zoom, tap a node, run an expedition).

# Project Brief v2 — Ontario Grade 9–12 Math Learning System

Date: 2026-09-09
Supersedes: PROJECT-BRIEF-v1.md (2026-09-08)
Status: base unchanged; front end redesigned. This is the idea-capture input for `bootstrap.md`. Self-contained — v1 need not be read.

Owner: Jimmy (product owner, product tester, delivery verifier — not content reviewer)
Ownership: personal project, non-profit intent, no legal entity
Working name: TBD (candidate: Upstream; do not use `mathpath`)

## 0. What changed from v1 and why

Feedback from two target-age students (grade 9, grade 11): the diagnostic "bring your homework" entry will not attract struggling students — those students are not focused on math, and their families respond by switching schools or buying tutoring. A fragmented-time, level-by-level form could attract students who like math or like learning with AI.

Conclusion: the base was never rejected; the front door was. **v1's entry assumed motivation. v2 removes that assumption.**

| Area | v1 | v2 |
|---|---|---|
| Entry | Student pastes a homework problem | Student opens a map; short expeditions; diagnosis is an in-map event |
| Organising view | Course codes | Math's natural taxonomy (regions); courses are trails drawn over the map |
| Diagnosis (D4/D5) | The main flow | Unchanged mechanics, now triggered when a node is blocked |
| Applications | Not present | Landmarks: real, named, verifiable real-world things linked to nodes |
| Platform (D8) | Desktop-only | Split: map + expeditions are Tier 0 and mobile-capable; diagnostic free-text entry stays desktop (Tier 1) |
| Milestones | M1 first | A form-testing Demo runs first, decoupled from M1/M2 |
| Interaction contract (§7) | Diagnostic flow | Three doors over one base |

Everything in §3 marked **unchanged** carries over verbatim in meaning.

## 1. Purpose

Help Ontario grade 9–12 students see mathematics as one continent, move across it in small daily steps, and — when they get stuck — find that the block is upstream and clear it with the minimum necessary backfill. Parents see the same map from above.

Core belief: any student who wants to learn can master the material with the right method. v2 adds: the product must also create the wanting, in small doses, rather than presuppose it.

Differentiator over generic AI: **it knows which concept node a student is weak on, why, and which downstream territory that node feeds.**

## 2. Product definition — one base, three doors

**Base** (unchanged): cross-grade concept graph with prerequisite edges; deterministic CAS step verification; per-node error catalogues; tiered hint trees; 60-second probes that both confirm a diagnosis and validate the graph; pre-generated content.

**Door C — Map.** The concept graph rendered as a continent organised by math's own taxonomy. Regions are territories; edges are rivers flowing from grade-9 land toward grade-12 land; unmastered nodes sit under fog; courses are trails drawn across the map; beyond grade 12 lies a greyed horizon (labels only). Landmarks — real-world things — sit on the map and link into nodes across regions.

**Door B — Expeditions.** Fragmented-time progression. One expedition ≈ 3 minutes: ~5 probe items drawn from the fog frontier, scheduled with spaced repetition over the graph. Clearing items lifts fog. Streaks, region completion, trail progress emerge from this without extra design.

**Door A — Diagnosis.** v1's flow, unchanged in mechanics, now an in-map event: an expedition item fails → "this node is blocked by something upstream" → hypothesis → probe → minimal remediation → return. Homework entry (structured editor, CAS step verification) remains available as a desktop feature inside Door A.

Doors feed each other: the map gives orientation, expeditions give daily movement, diagnosis appears when movement is blocked. Parent view = the same map from above with the child's trail and blocked nodes marked.

## 3. Locked decisions

Unchanged from v1: **D1, D2, D3, D6, D7, D9, D10, D11, D12, D13, D14, D15, D16, D17, D18, D19.**

| ID | Decision |
|---|---|
| D1 | Scope: Ontario grades 9–12 only. |
| D2 | Sole authoritative content source: Ontario Ministry of Education curriculum documents. |
| D3 | One cross-grade concept graph; each course is a node subset + depth marker. |
| D4 | *(amended)* Just-in-time remediation, backtrack ≤ 2 levels per session, deeper gaps to record and parent view — now triggered as an in-map event, not as the main flow. |
| D5 | *(amended)* Answers are not blocked; diagnosis accompanies answers. Applies wherever an answer is shown (expedition items, homework mode). |
| D6 | Step correctness decided by CAS, never by a language model. |
| D7 | Three-tier runtime; Tier 0 alone is a usable product. |
| D8 | *(amended)* Platform baseline is per door. Doors B and C are Tier 0 and must run on phones and the desktop baseline. Door A's free-text entry and error classification (Tier 1) keep the v1 desktop baseline: non-Chromebook, ≥16 GB RAM, ≥20 GB free, Chrome 148+, WebGPU. |
| D9 | Structured math editor input; no OCR. |
| D10 | Graph verified by structure, source agreement, probe data — not human review. |
| D11 | Diagnoses are hypotheses confirmed by probes; probes double as validation data. |
| D12 | Content is batch-generated; owner defines structure and rules only. |
| D13 | Zero human pre-review; disputed edges ship at low confidence. |
| D14 | Starting chain: MTH1W linear relations/equations → exponent laws → polynomials/factoring → quadratics → function concept/transformations → exponential functions → logarithms & advanced functions. |
| D15 | Tier 2 queued; if Tier 1 fails, architecture is revisited, not patched. |
| D16 | Parent view built at M5; release only after all milestones. |
| D17 | Telemetry anonymous, aggregate, opt-in, account-less. |
| D18 | No Crown-copyright permission needed: codes + own paraphrase, link out for verbatim text. |
| D19 | No legal entity, domain, or compliance work until money is charged or identifiable data is collected. |
| **D20** | The map is organised by math's natural taxonomy, not course codes. Courses are an overlay (trails). |
| **D21** | Region taxonomy (initial, may be refined at M2): Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus · Probability & Statistics · Discrete (sequences, counting). Horizon labels beyond grade 12 (e.g. Linear Algebra, Number Theory, Analysis) are names only, no content. |
| **D22** | Landmarks are real, named, verifiable real-world things (with a source link), each linked to one or more nodes, often across regions. Fabricated or hypothetical "applications" are not landmarks. |
| **D23** | The expedition is built from the existing probe mechanism (≈5 items, ≈3 minutes) with spaced-repetition scheduling over the graph. No separate "game content" is authored. |
| **D24** | No game engine. Rendering is SVG + D3 + React; math via KaTeX/MathLive. Graph data, layout, and state are strictly separated from rendering so the renderer can be replaced later without touching the base. |
| **D25** | Math only. Cross-subject reuse is recorded as a demand signal, not a design input. |
| **D26** | A Demo that tests the *form* (does a student want to click in and come back?) is built first, on hand-written data, fully decoupled from M1/M2 content pipelines. |

## 4. Architecture

### 4.1 Logical layers (unchanged, with map vocabulary)

```
① Curriculum Spine — official expectation nodes keyed by Ministry codes
   [SOURCED: dcp.edu.gov.on.ca; edu.gov.on.ca/eng/curriculum/secondary/math1112currb.pdf]
② Concept Graph — nodes + prerequisite DAG; each edge carries source, confidence, probe stats
   Map projection: node → position within its region; edge → river; course → trail
③ Learning Objects — per node: explanation, examples, error catalogue, hint tree, probe items
   New: Landmarks (real-world things) linked to nodes
④ Interaction — three doors (§2); parent view
```

### 4.2 Runtime tiers (unchanged)

| Tier | Components | Covers |
|---|---|---|
| 0 | MathLive; Pyodide + SymPy; graph queries; hint trees; probes; **map render; expedition scheduler** | Doors B and C entirely; Door A menu entry |
| 1 | Chrome Prompt API; fallback WebLLM 3B | Door A free-text mapping, error classification, hint wording |
| 2 | Cloud | Queued |

### 4.3 Client stack

- PWA + Service Worker; IndexedDB
- **Map:** React + TypeScript, D3 (zoom/pan, force layout constrained to region polygons), SVG; fog and terrain via SVG filters/patterns
- **Math:** KaTeX (display), MathLive (input, Door A)
- **Verification:** Pyodide + SymPy (Door A; not loaded for Doors B/C unless an item needs it)
- Static hosting; the opt-in telemetry endpoint is the only write path

## 5. Data model

**Node** — as v1 (`id`, `name`, `strand`, `expectation_codes[]`, `courses[]` with depth, `error_catalogue[]`, `hint_tree`, `probe_items[]`, `paraphrase`) plus `region` (D21) and `layout_hint` (optional).

**Edge** — as v1 (`from`, `to`, `sources[]`, `generation_agreement`, `confidence`, `probe_stats`).

**Region** — `id`, `name`, `polygon`, `horizon: bool`, `neighbours[]`.

**Trail** — `course_code`, ordered `node_ids[]`.

**Landmark** — `id`, `name`, `what_it_is` (one paragraph, plain language), `source_url` (required, D22), `node_ids[]`, `region_ids[]`.

**Student state** (local) — per node: `mastery` (unknown / fog / cleared / blocked), `last_probe`, `next_due` (spaced repetition); per trail: progress; expedition log; probe log (for opt-in telemetry).

**L0 structural constraints** — unchanged from v1 (acyclic; no later→earlier course edge; expectation↔node coverage; in-degree outliers flagged; starting chain connected). Added: every node has exactly one region; every trail is a path in the graph.

## 6. Verification method (unchanged)

L0 structural · L1 multi-source agreement (≥ 2 independent sources) · L2 multi-run generation intersection, disputed edges at low confidence · L3 probe-data prediction test. Basis: Knowledge Space Theory (Doignon & Falmagne 1985); ALEKS [SOURCED: aleks.com; Cosyn et al. 2021].

## 7. Interaction contract — three doors over one base

```
Door C  open map → see regions, fog, own trail, landmarks, horizon
        click region/node → knowledge panel (paraphrase, examples, linked landmarks)
        click landmark → what it is, which nodes it touches → jump to node

Door B  start expedition → ~5 probe items from fog frontier (spaced repetition)
        pass → fog lifts on that node; log
        fail → Door A event

Door A  failed node → hypothesis: "blocked upstream at X" → probe on X (2 items, ~60 s)
        pass → "not the issue" → tiered hint on original node; log
        fail → minimal remediation on X → back to original node; log
        (desktop) homework mode: structured input → CAS step check → same diagnosis path
```

Owner's product-test criteria: a student wants to click into the map unprompted; finishes one expedition and starts a second; can explain "my course is a trail across this" afterward; a landmark makes at least one node feel concrete; a wrong hypothesis costs one minute and no trust.

## 8. Milestones (ordered; no time estimates)

**M0 — Baseline** ✅
**Demo — Map form test** (D26; see DEMO-BRIEF.md). Runs first. Hand-written data; no M1/M2 dependency.
**M4′ — Tier 1 spike** (parallel with M1; unchanged from v1: log-equation node, 6-way error enum, synthetic round-trip, top-1 ≥ 80% go line [ESTIMATE: owner-set threshold])
**M1 — Spine + data model** (unchanged; add Region/Trail/Landmark schemas and the two new L0 rules)
**M2 — Concept graph, starting chain v0** (unchanged; also assign regions and confirm D21 taxonomy against the real graph)
**M3 — Tier 0 end-to-end** — *two* flows must pass: one expedition end-to-end (Door B→A) and one homework problem end-to-end (Door A). Map render from real M2 data replaces demo data. L3 telemetry in.
**M4 — Tier 1 integration** (if M4′ passed)
**M5 — Parent view** (bird's-eye of the same map)
**M6 — Coverage expansion** (remaining strands/courses; landmarks across all regions)
**Release** — after M6.

## 9. Out of scope (queued)

Chromebook for Door A · Safari/Firefox · OCR · Tier 2 · accounts/payments/entity · other subjects (D25) · social/leaderboards · real-time/animated game mechanics (D24 keeps the door open, nothing is built).

## 10. Content licensing position (unchanged from v1 §10)

## 11. Residual unknowns (experiments, not decisions)

- Does the map form make a student click in and come back? — Demo
- Gemini Nano enum-classification accuracy; Pyodide first-load feel — M4′
- Whether D21's eight regions survive contact with the real graph — M2
- What a landmark needs to contain to make a node feel concrete — Demo (one landmark), refined at M6

## 12. Working conventions (unchanged)

Owner: product testing at Demo and M3; delivery verification at every wrap-gate; no content review. `[SOURCED]`/`[ESTIMATE]` tags. No time estimates. English docs, Chinese conversation. Quality > tokens > speed.

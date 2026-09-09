# EPIC plan (bootstrap Phase 7a)

Date: 2026-09-09. Inputs: `docs/idea.md` (D1–D49, milestones), `docs/domains/*.md`, `contracts/*`
(signed off 2026-09-09), `docs/tech-stack.md`, `DEMO-BRIEF.md` as amended (v2.1 §D surviving parts, v2.2
§B, v2.6 §D). **Status: signed off by the owner 2026-09-09.** Auto-execute (7b) runs from an Opus session via `/run-epic 01`.

**EPIC size cap:** 8 tasks [ESTIMATE: owner-set at Phase 7a; a planner that exceeds it splits at the brief's
seams]. **Conformance tests (B.1)** for an EPIC are the "Invariants enforced here" mechanisms of its domain
docs plus the contract enforcement rungs marked *EPIC-time* in `contracts/README.md`. **Every EPIC ships a
C1 real-composition seam test for each seam it adds** and lists its shipped artifacts (C4).

**Execution:** `/run-epic <NN>` from an **Opus** session (owner switches the model; CLAUDE.md model policy).
Each EPIC on its own branch; merge through PR with both CI jobs green (`wrap-epic`). Physical-device
verification is the owner's at the wrap-gate (D29). Q5 is the only owner stop.

## Demo — Map form test (D26; four EPICs, run first)

| EPIC | Category | Title | Domains | Depends | Seams (C1) | Ships (C4) |
|---|---|---|---|---|---|---|
| 01 | Foundation | **Core data + L0 + layout + demo bundle + rendering spike** — `Core` `Codable` types for every schema; `core-cli validate` (L0-1…L0-10) and `core-cli layout` (deterministic region-constrained force layout); the hand-written Demo bundle under `data/demo/` (10 regions + 4 horizon, ~20 nodes on the D14 chain across Number / Algebra / Functions with 2–3 items each and distractor tags, edges, MTH1W + MCR3U courses with hand-written unit lists and `next_courses`, one sourced landmark); `Rendering` spike: every prompt/hint/explanation in the bundle parsed by SwiftMath, failures listed and each resolved by rewriting or `render_fallback` | concept-graph, curriculum-spine (data), learning-objects (static validation), map (layout) | none | pipeline↔`core-cli` (validate + layout over `data/demo`); bundle loader↔`Core` decode | `core-cli`, `data/demo/*.json` + L0 report, `Rendering.RenderCheck`, decode round-trip test |
| 02 | Feature | **Core behaviour** — `StudentState` + transitions (interaction-contract §1), trail generation with D47 extension (§3), fringe + scheduler with D27 tolerance, unit expeditions and review slots (§2), diagnosis machine (§4), state merge (platform Q3), `CoreError` mirroring `error-codes.json` | expedition, diagnosis, platform (merge) | 01 | expedition↔diagnosis hand-off (`diagnosis_requested` → `returned`); marker→trail→fringe | property tests for every §1–§4 property; `CoreError` ⊆ registry test |
| 03 | Feature | **App: Map (Door C) + shell** — snapshot bundle load and L0 at launch, JSON persistence of `StudentState` (Application Support, atomic), `MapViewModel` → `Canvas` render (regions, rivers, fog, due ring, blocked marker, trail solid/dashed, horizon, landmark), trail-first camera (D44), pan/zoom, node / region / landmark panels, unit-list marker picker (D45), "Check me here" / "Include" / "Unit expedition" actions | map, platform (launch, persistence) | 02 | `Core`↔render layer (I14 boundary; view computes nothing); bundle loader↔`Core` validation at load | App build; launch on simulator with the demo bundle; persistence survives relaunch |
| 04 | Feature | **App: Expedition (Door B) + Diagnosis (Door A) + acceptance instrument** — item view (numeric keypad / choices), answer card with `why`, retry, hypothesis card, probe, remediation, return, summary; unit expedition entry; the owner's acceptance record template for DEMO-BRIEF §7 items 1–7 and the §8 verification checklist (simulator half by agents, device half by owner) | expedition, diagnosis (UI) | 03 | App↔`Core` state transitions (every screen action is a `Core` call) | App build; one full expedition + one diagnosis completable by touch on the simulator (§8); `docs/epics/demo-acceptance-record.md` template |

Demo wrap = owner installs on the two testers' devices (D35) and records the seven observations; that
record decides whether the map form proceeds to M3 or is revised (DEMO-BRIEF §7) — a Q5 checkpoint by
design, not a stop.

## M4′ — Tier 1 spike (parallel with M1)

| EPIC | Category | Title | Domains | Depends | Seams | Ships |
|---|---|---|---|---|---|---|
| 05 | Foundation | **Pipeline generation base + synthetic set** — `PromptVersion`, `GenerationRun`/`RunOutput` with schema validation and budget ceiling (content-generation W1), `gen-*.schema.json` for the synthetic task, the M4′ `SyntheticSolutionSet` with round-trip (W3) | content-generation | none (pipeline only) | pipeline↔Claude API (recorded run; replayable fixture for CI) | generation CLI, synthetic set artefact + report |
| 06 | Feature | **Foundation Models spike harness** — `classify` adapter with `@Generable` result, availability gating, threshold/fallback (`runtime-tiers.md`), the M4′ evaluation runner on macOS/iOS 26 simulator producing top-1 / confusion / misuse / abstention report; go/no-go against ≥ 80 % [ESTIMATE] | runtime-tiers | 05 | adapter↔Tier-0 fallback (adapter-absent suite) | spike report `docs/epics/m4-prime-report.md`; adapter module (off by default) |

## M1 — Spine + data model

| EPIC | Category | Title | Domains | Depends | Seams | Ships |
|---|---|---|---|---|---|---|
| 07 | Feature | **Spine extraction** — per-vintage parsers (2021 / 2005+2022 / 2007), paraphrase generation + I6 overlap gate, official links, units from `unit_source` with strand fallback, `next_courses[]`, bundle cut and versioning (curriculum-spine W1–W3) | curriculum-spine, content-generation (paraphrase task) | 05 | pipeline↔`core-cli validate` (L0-3a, L0-8, L0-9 on the cut) | spine bundle for the D14 courses + report |

## M2 — Concept graph, starting chain v0

| EPIC | Category | Title | Domains | Depends | Seams | Ships |
|---|---|---|---|---|---|---|
| 08 | Feature | **Edge generation + L1/L2** — multi-run edge candidates, intersection (W2), source tagging and acceptance, confidence init (concept-graph W2), region assignment and D21 confirmation report, layout precompute via `core-cli` | content-generation, concept-graph | 07 | pipeline↔`core-cli` (validate + layout on a real graph) | graph bundle v0 + L0 report + disputed-edge list |
| 09 | Feature | **Learning objects + landmarks generation** — explanations, error catalogues with distractor tags, hint trees, probe items with SymPy re-derivation and SwiftMath renderability, landmarks with source resolution (learning-objects W1; content-generation LO + landmark variants) | learning-objects, content-generation | 08 | pipeline↔`Rendering.RenderCheck` (via a small CLI) ; SymPy verification | learning-object bundle for the chain + report |

## M3 — Native Tier 0 end-to-end

| EPIC | Category | Title | Domains | Depends | Seams | Ships |
|---|---|---|---|---|---|---|
| 10 | Feature | **Hosted content + sync** — Cloudflare Pages publishing script, manifest/asset versions, background refresh with atomic swap (platform W2), iCloud state sync with `Core` merge (platform W4, Q1 decided here), network allowlist test (`deployment-model.md`) | platform | 04, 09 | app↔content host (integrity failure path); sync↔merge | publish runbook (gated), app with refresh + sync |
| 11 | Feature | **Telemetry** — on-device event derivation (edge observations, day-N), consent switch, batch + send, Cloudflare Worker + R2 endpoint with the no-IP configuration (telemetry W1–W3, W5), owner aggregation → `ProbeStats` (W4) | telemetry, concept-graph (W4) | 10 | client↔endpoint (schema round-trip); aggregation↔`ProbeStats` | Worker deploy runbook (gated), aggregation CLI, W5 verification record |
| 12 | Feature | **M3 acceptance** — replace `data/demo` with the M2 bundle as the snapshot, run one expedition with a Door A event on real data, owner product test | map, expedition, diagnosis | 11 | — | acceptance report; snapshot bundle in the build |

## M4 — Tier 1 integration (if M4′ passed)

| 13 | Feature | **Tier 1 in the app** — optional "what did you do?" line on the hypothesis card, `classify` suggestion with confirm, `reword` behind its switch, Settings › Intelligence, fallback telemetry (runtime-tiers W1–W4; diagnosis Q1 Tier 1 half) | runtime-tiers, diagnosis | 06, 12 | adapter↔diagnosis (suggestion never becomes a Diagnosis) | app with Tier 1 off by default; adapter-absent suite |

## M5 — Coverage expansion (sequenced later; briefs synthesized at dispatch)

14+ Remaining grade 9–12 strands and courses (repeat 07–09 per course group) → undergraduate tier
(sources.json, `source_ref` nodes; D1 order) → landmarks across all regions → shore-region decision
(DEFERRED D-10) → additional syllabi as trails (D-11) → **Door A homework mode as desktop web** (D-4;
`verification` domain; its own stack lock addendum) → Android port planning (D-3).

## Cascade and stop rules
- Two consecutive EPICs with hotfix count > 2 or wrap-gate retries > 2 [ESTIMATE: bootstrap default] → Q5.
- Any brief needing a decision outside D1–D49 and the contracts → Q5 before dispatch, never a speculative brief.

## Sign-off

| Date | Owner |
|---|---|
| 2026-09-09 | signed off (owner, in conversation) — auto-execute may begin with EPIC 01 |

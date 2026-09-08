# Phase 3a — Domain decomposition (proposal for owner ratification)

Status: RATIFIED by owner 2026-09-08 (ten domains, as proposed).
Source: `PROJECT-BRIEF-v1.md` §4.1 layers ①–④, §4.2 tiers, §5 data model, §7 interaction contract, §8 milestones.

## Decomposition rule
A domain is a unit that (a) has its own actors/entities/workflows, (b) can be designed and contract-locked
independently, and (c) maps to at least one milestone. Cross-cutting concerns with their own hard invariant
(I1 CAS-only correctness, I5 no PII, I2 tier fallback) get their own domain so the invariant has one owner.

## Proposed domains

| # | Domain | Layer | Purpose (one line) | Milestones |
|---|---|---|---|---|
| 1 | `curriculum-spine` | ① | Ministry courses, strands, expectation codes; own paraphrase per code; spine JSON + extraction tooling. No verbatim text (I6). | M1, M6 |
| 2 | `concept-graph` | ② | Node/edge schema (§5), L0 structural checker, L1 source tagging, confidence, `probe_stats`; graph queries (deepest unmastered prerequisite, ≤2 levels). The core asset. | M1, M2, M6 |
| 3 | `learning-objects` | ③ | Per-node explanation, worked examples, error catalogue (closed enum + "none of these"), tiered hint tree, probe items. Static, versioned assets. | M2, M3, M6 |
| 4 | `content-generation` | offline | The batch pipeline (D12, L2): multi-run LLM generation → intersection, schema validation, versioned prompts, synthetic wrong-solution sets for M4′. Runs on the owner's machine with the Claude API; never in the product. | M4′, M2, M6 |
| 5 | `verification` | ④ | MathLive → LaTeX → SymPy (Pyodide worker): step-by-step equivalence, first failing step, domain checks. The only authority on correctness (I1). | M3 |
| 6 | `tutoring-session` | ④ | The §7 flow: problem entry, node mapping, error classification (Tier 0 candidates / Tier 1 enum), hint delivery, hypothesis, probe, minimal remediation, return; session record. | M3, M4 |
| 7 | `runtime-tiers` | ④ | Tier-1 adapters (Chrome Prompt API, WebLLM fallback), JSON-schema-constrained outputs, confidence gating and Tier-0 fallback (I2), model availability/download/storage budget. | M4′, M4 |
| 8 | `parent-view` | ④ | Read-only view over session records: node-level status, gaps, trend, suggested actions. | M5 |
| 9 | `telemetry` | cross | Opt-in, anonymous, aggregate probe/diagnosis events (D17); the single write endpoint; L3 validation statistics feeding edge confidence. | M3 |
| 10 | `platform` | cross | PWA shell: offline/service worker, asset loading + versioning, IndexedDB persistence, baseline-environment detection and the "unsupported environment" page (D8, §9). | M3 |

## Alternatives considered
- Merge `verification` into `tutoring-session`: rejected — I1 needs a single owner with no model code in its file scope.
- Merge `telemetry` into `platform`: rejected — D17 compliance and the only server-side write path deserve a dedicated contract.
- Merge `content-generation` into `concept-graph` + `learning-objects`: rejected — different runtime (offline scripts + cloud API), different actor (owner runs it), own `ai-usage` contract.
- Fewer domains would make M3's design doc unreadably large; more would fragment the §7 flow.

## Build sequencing (informs Phase 7a; not time estimates)
platform → curriculum-spine → concept-graph → content-generation → learning-objects → verification →
tutoring-session (Tier 0) → telemetry → runtime-tiers (gated by M4′) → parent-view → coverage expansion.
M4′ (the Tier-1 spike) runs in parallel with curriculum-spine, using `content-generation` + `runtime-tiers` only.

## Change log
| Date | Change |
|---|---|
| 2026-09-08 | Proposed (10 domains). |
| 2026-09-08 | Ratified by owner as-is. |
| 2026-09-08 | Phase 3b complete: ten domain docs drafted, cross-checked, open questions ratified. |

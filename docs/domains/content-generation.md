# Domain — content-generation

## Purpose

The offline batch pipeline behind D12: the Owner runs it on their own machine against the Claude API for
candidate graph edges, per-node learning objects, expectation paraphrases and the M4′ synthetic
wrong-solution set. It is **not Tier 2** — Tier 2 is in-product cloud inference and stays queued (D15, §9).
Nothing here executes in the browser; only validated outputs ship. Milestones **M4′**, **M2**, **M6**.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Owner | Start a batch, choose run count and PromptVersion, read cost and rejection reports | Edit generated content, or approve it (I9) |
| System | Nothing at runtime — it consumes only validated bundles | Call this pipeline from the product |
| Generation model | Produce structured candidates offline via the Claude API | Reach a student device; judge correctness (I1) |
| Local model (Tier 1) | None here. The Local model consumes the SyntheticSolutionSet only in runtime-tiers W7 (the M4′ evaluation). | Generate content |

## Core entities

- **PromptVersion** — an immutable versioned prompt template with a content hash; every output traces to
  one, and templates are never edited in place.
- **GenerationRun** — one execution: PromptVersion, model id, temperature, seed, scope, tokens in and out,
  computed cost; that record is what re-runnability rests on (Q4). Its **RunOutput** is the structured
  result, schema-validated before persistence — a failing output is discarded, never hand-repaired (I9).
- **IntersectionResult** — the L2 artifact (§6): items in ≥ k independent RunOutputs, each with the count
  that becomes `generation_agreement` on an Edge (concept-graph). Items below k go to a disagreement list,
  not the bin — they ship as low-confidence edges (D13).
- **SyntheticSolutionSet** — the M4′ dataset: ~30 wrong solutions per error type across the 6 error types
  of the logarithmic-equation node, each labelled by the type that generated it and surviving the W3
  round-trip. Synthetic errors are cleaner than real ones, so accuracy on it is an upper bound
  [SOURCED: brief §8 M4′].

Referenced elsewhere: **Node**, **Edge** (concept-graph); **Expectation** (curriculum-spine); **ErrorType**,
**HintTree**, **ProbeItem**, **LearningObject bundle** (learning-objects); **ClassificationResult**
(runtime-tiers).

## Workflows

### W1 — Execute a generation batch

**Pre:** a PromptVersion, an input scope, and a run count (Q1).
**Steps:**
1. (Tier 0) Record the batch configuration — PromptVersion hash, model id, temperature, per-run seed,
   scope — before any call, so the batch is describable even when it fails midway.
2. (Generation model, offline) Execute N independent runs: no run sees another's output, each varied per Q2.
3. (Tier 0) Validate each RunOutput against its schema, discarding failures (`GEN_SCHEMA_INVALID`), and
   accumulate tokens and cost, halting at the ceiling (Q4) rather than spending silently.

**Post:** N RunOutputs persist with their GenerationRun records, re-runnable from the recorded
configuration at known cost. Emits `gen.run_completed`.

**Learning-object variant.** Over an accepted Node (concept-graph), the same batch produces the
Explanation, WorkedExamples, the ErrorType enum (closed, always including "none of these"), a HintTree
tiered per ErrorType, and ProbeItems, then validates structurally — enum closed and non-empty, a hint tier
per ErrorType, probe items fitting the two-item ~60 s budget [SOURCED: brief §2, §7], LaTeX parsable
(I10) — regenerating whatever fails, with no edit step and no review queue (I9). The stamped bundle goes to
`learning-objects`, which accepts or refuses it on its own schema checks (`gen.objects_ready`).

### W2 — Intersect runs into a candidate set (L2)

**Pre:** a completed batch of ≥ 2 RunOutputs over one scope.
**Steps:**
1. (Tier 0) Normalise items to comparable keys — `(from, to)` after node-identity resolution for edges,
   `(node, object type)` for learning objects — and count agreement per item.
2. (Tier 0) Take the intersection at threshold k (Q1), write the count as `generation_agreement`, and emit
   the disagreement list separately: those items ship as low-confidence edges (D13, I9). Where a node's
   intersection is empty, apply Q3 rather than inventing an item.

**Post:** an IntersectionResult and disagreement list, stamped with provenance (PromptVersion, run ids,
agreement counts, model id) and handed to `concept-graph`. Nothing is accepted here: the consumer's
validators decide, and a refusal is regenerated, never hand-patched (I9). Emits `gen.intersection_ready`
and, on refusal, `gen.bundle_rejected`.

### W3 — Build the M4′ synthetic wrong-solution set

**Pre:** the logarithmic-equation node with its 6-value enum — missed domain restriction, log-combination
rule misapplied, exponent–log inverse not internalised, quadratic solved incorrectly, arithmetic slip,
none of these [SOURCED: brief §8 M4′].
**Steps:**
1. (Generation model, offline) Generate ~30 wrong solutions per error type, each produced *from* a named
   type so the label holds by construction, not by later annotation.
2. (Generation model + Tier 0) Round-trip test: a separate run, blind to the generating label, re-labels
   each item; disagreeing items are dropped and per-type survival counts recorded, so a type that cannot be
   synthesised cleanly is visible before the spike.

**Post:** a labelled, round-tripped SyntheticSolutionSet goes to `runtime-tiers` for the M4′ top-1,
confusion-matrix and abstention measurements; nothing here judges mathematics (I1). Emits
`gen.synthetic_set_ready`.

## UI surfaces

None. This is an offline, Owner-run pipeline: a CLI plus written run reports (configuration, agreement
statistics, rejections, tokens, cost). No `/student/...` or `/parent/...` route touches it.

## Notifications produced

- `gen.run_completed` — `{ batch_id, prompt_version, model_id, runs, items, tokens_in, tokens_out, cost }`
  and `gen.bundle_rejected` — `{ batch_id, consumer, reason_codes[] }`. Consumer: the Owner run report.
- `gen.intersection_ready` — `{ batch_id, scope, agreed_items, disagreed_items, k }` → `concept-graph`;
  `gen.objects_ready` — `{ batch_id, node_ids[], object_counts }` → `learning-objects`.
- `gen.synthetic_set_ready` — `{ node_id, per_type_counts, round_trip_survival }` → `runtime-tiers` (M4′).

## Errors produced

| Code | When | User sees | Recoverable |
|---|---|---|---|
| `GEN_SCHEMA_INVALID` | A RunOutput item fails its boundary schema | Internal (run report) | Yes — discard, re-run |
| `GEN_INTERSECTION_EMPTY` | No item for a node appears in ≥ k runs | Internal, with the node listed | Yes — apply Q3 |
| `GEN_BUDGET_EXCEEDED` | Accumulated cost passes the batch ceiling, or the API fails mid-batch | Internal; the batch halts, partial output kept | Yes — resume, raise the ceiling, or narrow scope |

## Invariants enforced here

- **I9 — primary owner.** No review, approval or edit state exists: every failure path ends in
  *regenerate* or *discard*. A spec adding "owner reviews the content" is BLOCKed.
- **I1** — nothing generated is consulted about step correctness; this domain produces candidate structure
  and wrong-solution *data*, and `verification` alone decides correctness. **I6** — expectation text
  reaches prompts in memory only, and paraphrases clear the `curriculum-spine` overlap check, so no source
  prose survives in a kept RunOutput.
- **I13 / I11** — quality over token conservation: independent runs beat one cheap run; counts are tagged.
  **D15 boundary** — the Claude API here is offline and Owner-run, never a runtime dependency, so a failure
  costs content freshness, not product function.

Seams: → `concept-graph` (IntersectionResult accepted only after L0 and L1); → `learning-objects` (bundle
accepted only after schema validation); → `curriculum-spine` (paraphrases); → `runtime-tiers`
(SyntheticSolutionSet for M4′).

## Open questions

**Q1 — How many independent runs, and what k?** **Default:** 3 runs, intersection at k = 2 for edges, so a
majority carries an item while `generation_agreement` still separates 2 from 3. **Trade-off:** cheap but a
weak independence signal; 5 runs would sharpen the statistics at proportional cost.
**Ratified 2026-09-08:** default accepted.

**Q2 — Vary prompts, models, or neither across runs?** **Default:** vary prompt phrasing (distinct
PromptVersions) at a fixed model, recording both. **Trade-off:** cheap and comparable, but shared priors
make "independent" generous; varying models is more independent and harder to reproduce.
**Ratified 2026-09-08:** default accepted.

**Q3 — When a node's intersection is empty.** **Default:** emit nothing for it and list it in the report,
letting `concept-graph`'s connectivity check catch the isolated node. **Trade-off:** honest, but can block
the D14 starting chain until the node is re-run under a different PromptVersion.
**Ratified 2026-09-08:** default accepted.

**Q4 — Reproducibility and cost ceiling.** **Default:** record seed, model id, temperature and
PromptVersion, claiming *re-runnability* rather than bit-exact reproduction, and cap each batch with an
Owner-set token ceiling. **Trade-off:** honest about sampling drift and safe against a runaway batch, but
weakens the audit story for an older bundle.
**Ratified 2026-09-08:** default accepted.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |

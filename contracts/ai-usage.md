# Contract: AI usage

**Contract version:** v1.0.0 · Source: D12, D13, D15, D41, v2.1 A3; I1, I2, I9; `content-generation.md`, `runtime-tiers.md`, `docs/tech-stack.md`

> Where a language model may run, which one, and what must be true of its output before anything keeps it.

## Two places, and only two
1. **Offline generation (pipeline, owner-run, Claude API)** — graph edge candidates, learning objects,
   paraphrases, landmarks, the M4′ synthetic set. Never on a device, never at runtime.
2. **On-device Tier 1 (Foundation Models)** — `classify` and `reword` only (`runtime-tiers.md`).

No third place. A spec that calls a model from `Core`, from the App outside the Tier 1 adapter, from the
telemetry path, or from any server is BLOCKed (D36, I14).

## Offline generation rules
- **Model ids** (only these strings; never date-suffixed): `claude-opus-5` for every generation task;
  `claude-haiku-4-5` only where a spec names a mechanical extraction task. Requests use adaptive thinking
  and streaming for long outputs; `max_tokens` is set per task, never left at a low default.
- **SDK:** `anthropic` (Python) as pinned in `pipeline/pyproject.toml`; raw HTTP is not used.
- **PromptVersion:** every prompt template is a versioned file with a content hash; templates are never
  edited in place; every RunOutput records `prompt_version`, `model_id`, `temperature`, `seed`, `scope`,
  tokens in/out and computed cost (content-generation Q4). Re-runnability, not bit-exact reproduction.
- **Independence (L2):** 3 runs, intersection at k = 2 for edges (Q1); runs vary prompt phrasing at a fixed
  model (Q2); no run sees another's output; agreement count → `generation_agreement`; disagreements ship as
  low-confidence edges, never discarded (D13).
- **Schema before persistence:** every RunOutput is validated against its task's JSON Schema
  (`contracts/schemas/gen-*.schema.json`, authored by the EPIC that adds the task) — a failing item is
  discarded and regenerated, never hand-repaired (I9). Structured outputs (`output_config.format`) are used
  so the model returns the schema shape directly.
- **Verification before shipping:** probe answers re-derived by SymPy (I1); paraphrases pass the 6-gram
  overlap check (I6); landmarks resolve (I15); items render in SwiftMath; all before a bundle is cut.
- **Budget:** each batch has an owner-set token ceiling; the batch halts at the ceiling with partial output
  kept (`GEN_BUDGET_EXCEEDED`), never spends silently.
- **Content of prompts:** Ministry text may be passed to the model in memory during paraphrase generation and
  is never persisted in any output, log or fixture (I6). No student data ever reaches the pipeline (I5) —
  telemetry aggregates are counts.

## On-device rules
See `runtime-tiers.md`: typed `@Generable` outputs, thresholds, fallbacks, off by default until M4, never
correctness (I1), never a diagnosis without a probe (I2), the typed line never leaves the call (I5).

## Enforcement
- lint (wrap-epic (f)): any string matching `claude-[a-z0-9-]+` in `pipeline/` or `App/` must be one of the
  two ids above; no `openai|gemini|ollama|webllm` imports anywhere.
- schema: RunOutput schemas per task (EPIC-time); test: a fixture RunOutput missing `prompt_version` fails.

# Domain — runtime-tiers

## Purpose

Owns Tier 1: every language-model call the product makes, and the confidence gating that keeps Tier 0 a
complete product on its own (D7 / I2). It detects what the machine can run, exposes one `ModelAdapter` over
the Chrome Prompt API (Gemini Nano) and a WebLLM 3B q4 fallback, constrains every call to a JSON schema and
decides when to fall back — never deciding correctness (I1) or guessing (I2). Milestones **M4′**, **M4**
[SOURCED: brief §8].

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | Opt into a fallback download; see availability and cost; turn Tier 1 off | Raise a `Threshold`; make an adapter authoritative |
| Owner | Run the M4′ spike offline; set thresholds; read the matrix | Change a locked decision (D7, D15) |
| System | Detect `TierCapability`; call adapters under schema; gate on `Threshold`; log fallbacks | Use adapter output for correctness (I1) or an unconfirmed diagnosis (I2) |
| Local model (Tier 1) | Return `{error_type ∈ enum, confidence}`, `{node_id, confidence}`, reworded hints | Emit free text, out-of-enum values, new mathematics |
| Generation model | Supply the `SyntheticSolutionSet` M4′ scores against | Run in the product (offline only, D12) |

## Core entities

- **TierCapability** — the startup verdict: Prompt API and model available, WebGPU present, headroom
  adequate. On the ≥ 20 GB baseline (D8): Nano ≈ 4 GB [SOURCED: press reporting, medium confidence] + assets
  < 100 MB [ESTIMATE] + optional fallback ≈ 2 GB [ESTIMATE: 3B × 4-bit], leaving > 13 GB, above Chrome's
  10 GB eviction threshold [SOURCED: developer.chrome.com/docs/ai/prompt-api].
- **ModelAdapter** — one interface, two implementations (Prompt API — Gemini Nano; WebLLM 3B q4 on WebGPU),
  three calls: classification and free-text mapping, both schema-constrained, and wording adaptation, which
  may only rephrase a hint whose semantics `learning-objects` fixes.
- **ClassificationResult** — `{error_type ∈ enum, confidence}` over the node's `ErrorType` catalogue
  (learning-objects), "none of these" included; mapping gives `{node_id, confidence}`.
- **Threshold** — one value per task; below it Tier 0 behaviour is the answer.
- **FallbackDecision** — task, reason (`below_threshold`, `unavailable`, `schema_violation`, `timeout`) and
  the confidence seen; persisted locally, emitted under consent.

## Workflows

### W1 — Detect capability at startup
**Pre:** `platform` has run its `EnvironmentCheck` (D8). **Steps:** probe Prompt API and model state,
WebGPU, and headroom against the §4.3 budget; a machine failing any check runs Tier 0 silently.
**Post:** `TierCapability` cached; `tier.capability_detected`.

### W2 — Classify an error (Tier 1 path of tutoring-session W3)
**Pre:** Tier 1 available; a node with a loaded `ErrorType` enum. **Steps:** call under a schema fixing
`{error_type ∈ enum, confidence}`; discard output off-schema or out of enum; gate on the `Threshold`.
**Post:** a `ClassificationResult` for the student to confirm, else a `FallbackDecision` to the Tier 0
candidates (I2).

### W3 — Map free text to a node (Tier 1 path of tutoring-session W1)
**Pre:** Tier 1 available; the student typed a description instead of using the menu. **Steps:** call under
`{node_id, confidence}`; verify the id exists in the graph; above `Threshold` return it for pre-selection in
the menu, never as a commitment, below it the menu stands (I2, brief §4.2). **Post:** a suggestion, else a
`FallbackDecision`.

### W4 — Adapt hint wording
**Pre:** Tier 1 available, the feature enabled (Q4), a hint from the `HintTree`. **Steps:** ask for a
rephrase only; reject output changing numbers, symbols or the step described; on rejection or timeout return
the original. **Post:** `tier.wording_adapted`.

### W5 — Decide and log a fallback
**Pre:** a call that returned late, off-schema, or below `Threshold`. **Steps:** construct a
`FallbackDecision`, hand the caller Tier 0 behaviour, persist it locally and emit under consent (I5); no
retry loop. **Post:** `tier.fallback_decided`.

### W6 — Offer and manage the fallback model download
**Pre:** WebGPU present, Prompt API or its model absent, headroom sufficient. **Steps:** present the ≈ 2 GB
cost [ESTIMATE] and let the student opt in (Q2), never downloading unprompted; show progress, allow
cancellation, re-check headroom first — dropping below the 10 GB threshold risks evicting the on-device
model. **Post:** `tier.model_download_finished`.

### W7 — Run the M4′ spike evaluation (offline, Owner)
**Pre:** the `SyntheticSolutionSet` (content-generation) for the logarithmic-equation node and its 6-value
enum [SOURCED: brief §8]. **Steps:** run the Prompt API over the set under the classification schema;
compute top-1 accuracy, confusion matrix, "none of these" misuse rate and abstention at low confidence; also
measure Pyodide + SymPy first-load latency; compare against top-1 ≥ 80 % [SOURCED: brief §8], an upper bound
since synthetic errors are cleaner. **Post:** a report fixing initial `Threshold`s; below the bar D15
triggers an architecture revisit, not a patch.

## UI surfaces

`/student/settings/models` — availability, the download opt-in with its cost, a Tier 1 switch. Fallbacks are
silent by design; W7 is Owner-run offline, no route.

## Notifications produced

- `tier.capability_detected` (Prompt API, WebGPU, headroom) → platform, telemetry (consented, aggregate only)
- `tier.classification_returned` (task, confidence, above/below threshold) → tutoring-session
- `tier.fallback_decided` (task, reason, confidence), `tier.wording_adapted` (hint) → tutoring-session,
  telemetry
- `tier.model_download_finished` (adapter, bytes, outcome) → platform

## Errors produced

All are recoverable and end in Tier 0 behaviour.

- `TIER_ADAPTER_UNAVAILABLE` — no adapter for the task; internal.
- `TIER_SCHEMA_VIOLATION` — output off-schema or out of enum; discarded, fallback logged.
- `TIER_BELOW_THRESHOLD` — confidence under `Threshold`; Tier 0 candidates offered (I2).
- `TIER_STORAGE_INSUFFICIENT` — headroom below the §4.3 budget; the student sees why.

## Invariants enforced here

- **I2**, primary owner — every call is threshold-gated with a named Tier 0 fallback; a suite runs the
  product with adapters forced unavailable, and no path turns an unconfirmed `ClassificationResult` into a
  `Diagnosis`.
- **I1**, co-owner with `verification` — the interface exposes no correctness call, so no model output can
  reach a `StepVerdict`; enforced by the interface type and a seam test.
- **I5**/**I11** — fallback and evaluation records carry ids, enums and confidences only, no student text;
  storage figures and the 80 % bar ship with their `[SOURCED]`/`[ESTIMATE]` tags.

**Seams:** ↔tutoring-session (`ClassificationResult` + `FallbackDecision`, W2/W3/W4); learning-objects↔
(`ErrorType` enum, `HintTree` text as fixed input, W2/W4); concept-graph↔ (`Node` id check, W3);
content-generation↔ (`SyntheticSolutionSet`, W7); platform↔ (`EnvironmentCheck`, storage, W1/W6);
↔telemetry (fallbacks under consent).

## Open questions

**Q1 — What are the `Threshold` values?** **Default:** 0.7 for classification and mapping [ESTIMATE], tuned
by M4′. **Trade-off:** higher means more Tier 0, safe but less helpful; lower risks confident wrong guesses.
**Ratified 2026-09-08:** default accepted.

**Q2 — Is the WebLLM fallback automatic or opt-in?** **Default:** opt-in, given the ≈ 2 GB download
[ESTIMATE]. **Trade-off:** fewer students reach Tier 1; automatic spends their disk unasked and can trip
eviction.
**Ratified 2026-09-08:** default accepted.

**Q3 — What if the model returns "none of these" with high confidence?** **Default:** treat it as
abstention — generic hint, no hypothesis — counted separately in M4′ misuse. **Trade-off:** a novel error
looks like model failure; trusting it hides a gap in the enum.
**Ratified 2026-09-08:** default accepted.

**Q4 — Is wording adaptation on by default?** **Default:** off until M4 passes acceptance.
**Trade-off:** loses the one Tier 1 feature a student notices; on, it risks drift in exactly the sentences
`learning-objects` was written to fix.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
